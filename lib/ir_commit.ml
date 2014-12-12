(*
 * Copyright (c) 2013-2014 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Ir_misc.OP
open Lwt
open Ir_merge.OP
open Printf

module Log = Log.Make(struct let section = "COMMIT" end)

module type S = sig
  include Tc.S0
  type commit
  type node
  val create: Ir_task.t -> ?node:node -> parents:commit list -> t
  val node: t -> node option
  val parents: t -> commit list
  val task: t -> Ir_task.t
end

module Make (C: Tc.S0) (N: Tc.S0) = struct

  module T = Ir_task
  type node = N.t

  type t = {
    node   : N.t option;
    parents: C.t list;
    task : Ir_task.t;
  }

  let parents t = t.parents
  let node t = t.node
  let task t = t.task
  let create task ?node ~parents = { node; parents; task }

  let to_sexp t =
    let open Sexplib.Type in
    let open Sexplib.Conv in
    List [
      List [ Atom "node"   ; sexp_of_option N.to_sexp t.node ];
      List [ Atom "parents"; sexp_of_list C.to_sexp t.parents ];
      List [ Atom "task"   ; T.to_sexp t.task ]
    ]

  let to_json t =
    `O [
      ("node"   , Ezjsonm.option N.to_json t.node);
      ("parents", Ezjsonm.list C.to_json t.parents);
      ("task"   , T.to_json t.task);
    ]

  let of_json j =
    let node    = Ezjsonm.find j ["node"]    |> Ezjsonm.get_option N.of_json in
    let parents = Ezjsonm.find j ["parents"] |> Ezjsonm.get_list C.of_json in
    let task    = Ezjsonm.find j ["task"]    |> T.of_json in
    { node; parents; task }

  module X = Tc.Triple(Tc.Option(N))(Tc.List(C))(T)

  let explode t = t.node, t.parents, t.task
  let implode (node, parents, task) = { node; parents; task }

  let hash t = X.hash (explode t)
  let compare x y = X.compare (explode x) (explode y)
  let equal x y = X.equal (explode x) (explode y)
  let size_of t = X.size_of (explode t)
  let write t b = X.write (explode t) b
  let read b = implode (X.read b)

end

module type STORE = sig

  include Ir_ao.STORE

  module Key: Ir_hash.S with type t = key
  (** Base functions over keys. *)

  module Val: S
    with type t = value
     and type commit := key
  (** Base functions over values. *)

end

module type HISTORY = sig
  type t
  type node
  type commit
  val commit: t -> ?node:node -> parents:commit list -> commit Lwt.t
  val node: t -> commit -> node option Lwt.t
  val parents: t -> commit -> commit list Lwt.t
  val merge: t -> commit Ir_merge.t
  val find_common_ancestor: t -> commit -> commit -> commit option Lwt.t
  val find_common_ancestor_exn: t -> commit -> commit -> commit Lwt.t
  val closure: t -> min:commit list -> max:commit list -> commit list Lwt.t
  module Store: Ir_contents.STORE with type t = t and type key = commit
end

module History (N: Ir_contents.STORE) (S: STORE with type Val.node = N.key) =
struct

  type commit = S.key
  type node = N.key

  module Store = struct

    type t = N.t * S.t
    type key = S.key
    type value = S.value

    let create config task =
      N.create config task >>= fun n ->
      S.create config task >>= fun s ->
      return (fun a -> (n a, s a))

    let task (_, t) = S.task t
    let config (_, t) = S.config t
    let add (_, t) = S.add t
    let mem (_, t) = S.mem t
    let read (_, t) = S.read t
    let read_exn (_, t) = S.read_exn t
    let merge_node (n, _) = Ir_merge.some (module N.Key) (N.merge n)

    let merge t ~old k1 k2 =
      read_exn t old >>= fun vold ->
      read_exn t k1  >>= fun v1   ->
      read_exn t k2  >>= fun v2   ->
      merge_node t ~old:(S.Val.node vold) (S.Val.node v1) (S.Val.node v2) >>|
      fun node ->
      let parents = [k1; k2] in
      let commit = S.Val.create ?node ~parents (task t) in
      add t commit >>= fun key ->
      ok key

    module Key = S.Key
    module Val = S.Val
  end

  type t = Store.t
  let merge = Store.merge

  let node t c =
    Log.debugf "node %a" force (show (module S.Key) c);
    Store.read t c >>= function
    | None   -> return_none
    | Some n -> return (S.Val.node n)

  let commit (_, t) ?node ~parents =
    let commit = S.Val.create ?node ~parents (S.task t) in
    S.add t commit >>= fun key ->
    return key

  let parents t c =
    Log.debugf "parents %a" force (show (module S.Key) c);
    Store.read t c >>= function
    | None   -> return_nil
    | Some c -> return (S.Val.parents c)

  module Graph = Ir_graph.Make(Tc.Unit)(N.Key)(S.Key)(Tc.Unit)

  let edges t =
    Log.debugf "edges";
    (match S.Val.node t with
      | None   -> []
      | Some k -> [`Node k])
    @ List.map (fun k -> `Commit k) (S.Val.parents t)

  let closure t ~min ~max =
    Log.debugf "closure";
    let pred = function
      | `Commit k -> Store.read_exn t k >>= fun r -> return (edges r)
      | _         -> return_nil in
    let min = List.map (fun k -> `Commit k) min in
    let max = List.map (fun k -> `Commit k) max in
    Graph.closure ~pred ~min ~max () >>= fun g ->
    let keys =
      Ir_misc.list_filter_map
        (function `Commit k -> Some k | _ -> None)
        (Graph.vertex g)
    in
    return keys

  module KSet = Ir_misc.Set(S.Key)

  let find_common_ancestor t c1 c2 =
    Log.debugf "find_common_ancestor %a %a"
      force (show (module S.Key) c1)
      force (show (module S.Key) c2);
    let rec aux (seen1, todo1) (seen2, todo2) =
      if KSet.is_empty todo1 && KSet.is_empty todo2 then
        return_none
      else
        let seen1' = KSet.union seen1 todo1 in
        let seen2' = KSet.union seen2 todo2 in
        match KSet.to_list (KSet.inter seen1' seen2') with
        | []  ->
          (* Compute the immediate parents *)
          let parents todo =
            let parents_of_commit seen c =
              Store.read_exn t c >>= fun v ->
              let parents = KSet.of_list (S.Val.parents v) in
              return (KSet.diff parents seen) in
            Lwt_list.fold_left_s parents_of_commit todo (KSet.to_list todo)
          in
          parents todo1 >>= fun todo1' ->
          parents todo2 >>= fun todo2' ->
          aux (seen1', todo1') (seen2', todo2')
        | [r] -> return (Some r)
        | rs  -> fail (Failure (sprintf "Multiple common ancestor: %s"
                                  (Tc.shows (module S.Key) rs))) in
    aux
      (KSet.empty, KSet.singleton c1)
      (KSet.empty, KSet.singleton c2)

  let find_common_ancestor_exn t c1 c2 =
    find_common_ancestor t c1 c2 >>= function
    | Some r -> return r
    | None   -> fail Not_found

end

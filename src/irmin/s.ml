(*
 * Copyright (c) 2013-2017 Thomas Gazagnaire <thomas@gazagnaire.org>
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

(** Irmin signatures *)

module type PATH = sig
  (** {1 Path} *)

  type t
  (** The type for path values. *)

  type step
  (** Type type for path's steps. *)

  val empty : t
  (** The empty path. *)

  val v : step list -> t
  (** Create a path from a list of steps. *)

  val is_empty : t -> bool
  (** Check if the path is empty. *)

  val cons : step -> t -> t
  (** Prepend a step to the path. *)

  val rcons : t -> step -> t
  (** Append a step to the path. *)

  val decons : t -> (step * t) option
  (** Deconstruct the first element of the path. Return [None] if the path is
      empty. *)

  val rdecons : t -> (t * step) option
  (** Deconstruct the last element of the path. Return [None] if the path is
      empty. *)

  val map : t -> (step -> 'a) -> 'a list
  (** [map t f] maps [f] over all steps of [t]. *)

  (** {1 Value Types} *)

  val t : t Type.t
  (** [t] is the value type for {!t}. *)

  val step_t : step Type.t
  (** [step_t] is the value type for {!step}. *)
end

module type HASH = sig
  (** Signature for digest hashes, inspired by Digestif. *)

  type t
  (** The type for digest hashes. *)

  val hash : ((string -> unit) -> unit) -> t
  (** Compute a deterministic store key from a sequence of strings. *)

  val short_hash : t -> int
  (** [short_hash h] is a small hash of [h], to be used for instance as the
      `hash` function of an OCaml [Hashtbl]. *)

  val hash_size : int
  (** [hash_size] is the size of hash results, in bytes. *)

  (** {1 Value Types} *)

  val t : t Type.t
  (** [t] is the value type for {!t}. *)
end

module type TYPED_HASH = sig
  type t
  type value

  val hash : value -> t
  (** Compute a deterministic store key from a string. *)

  val short_hash : t -> int
  (** [short_hash h] is a small hash of [h], to be used for instance as the
      `hash` function of an OCaml [Hashtbl]. *)

  val hash_size : int
  (** [hash_size] is the size of hash results, in bytes. *)

  (** {1 Value Types} *)

  val t : t Type.t
  (** [t] is the value type for {!t}. *)
end

module type CONTENT_ADDRESSABLE_STORE = sig
  (** {1 Content-addressable stores}

      Content-addressable stores are store where it is possible to read and add
      new values. Keys are derived from the values raw contents and hence are
      deterministic. *)

  type 'a t
  (** The type for content-addressable backend stores. The ['a] phantom type
      carries information about the store mutability. *)

  type key
  (** The type for keys. *)

  type value
  (** The type for raw values. *)

  val mem : [> `Read ] t -> key -> bool Lwt.t
  (** [mem t k] is true iff [k] is present in [t]. *)

  val find : [> `Read ] t -> key -> value option Lwt.t
  (** [find t k] is [Some v] if [k] is associated to [v] in [t] and [None] is
      [k] is not present in [t]. *)

  val add : [> `Write ] t -> value -> key Lwt.t
  (** Write the contents of a value to the store. It's the responsibility of the
      content-addressable store to generate a consistent key. *)

  val unsafe_add : [> `Write ] t -> key -> value -> unit Lwt.t
  (** Same as {!add} but allows to specify the key directly. The backend might
      choose to discared that key and/or can be corrupt if the key scheme is not
      consistent. *)

  val clear : 'a t -> unit Lwt.t
  (** Clear the store. This operation is expected to be slow. *)
end

module type CONTENT_ADDRESSABLE_STORE_MAKER = functor
  (K : HASH)
  (V : Type.S)
  -> sig
  include CONTENT_ADDRESSABLE_STORE with type key = K.t and type value = V.t

  val batch : [ `Read ] t -> ([ `Read | `Write ] t -> 'a Lwt.t) -> 'a Lwt.t
  val v : Conf.t -> [ `Read ] t Lwt.t
  val close : 'a t -> unit Lwt.t
end

module type APPEND_ONLY_STORE = sig
  (** {1 Append-only stores}

      Append-onlye stores are store where it is possible to read and add new
      values. *)

  type 'a t
  (** The type for append-only backend stores. The ['a] phantom type carries
      information about the store mutability. *)

  type key
  (** The type for keys. *)

  type value
  (** The type for raw values. *)

  val mem : [> `Read ] t -> key -> bool Lwt.t
  (** [mem t k] is true iff [k] is present in [t]. *)

  val find : [> `Read ] t -> key -> value option Lwt.t
  (** [find t k] is [Some v] if [k] is associated to [v] in [t] and [None] is
      [k] is not present in [t]. *)

  val add : [> `Write ] t -> key -> value -> unit Lwt.t
  (** Write the contents of a value to the store. *)

  val clear : 'a t -> unit Lwt.t
  (** Clear the store. This operation is expected to be slow. *)
end

module type APPEND_ONLY_STORE_MAKER = functor (K : Type.S) (V : Type.S) -> sig
  include APPEND_ONLY_STORE with type key = K.t and type value = V.t

  val batch : [ `Read ] t -> ([ `Read | `Write ] t -> 'a Lwt.t) -> 'a Lwt.t
  val v : Conf.t -> [ `Read ] t Lwt.t
  val close : 'a t -> unit Lwt.t
end

module type METADATA = sig
  type t [@@deriving irmin]
  (** The type for metadata. *)

  val merge : t Merge.t
  (** [merge] is the merge function for metadata. *)

  val default : t
  (** The default metadata to attach, for APIs that don't care about metadata. *)
end

type config = Conf.t
type 'a diff = 'a Diff.t

module type BRANCH = sig
  (** {1 Signature for Branches} *)

  type t [@@deriving irmin]
  (** The type for branches. *)

  val master : t
  (** The name of the master branch. *)

  val is_valid : t -> bool
  (** Check if the branch is valid. *)
end

module type ATOMIC_WRITE_STORE = sig
  (** {1 Atomic write stores}

      Atomic-write stores are stores where it is possible to read, update and
      remove elements, with atomically guarantees. *)

  type t
  (** The type for atomic-write backend stores. *)

  type key
  (** The type for keys. *)

  type value
  (** The type for raw values. *)

  val mem : t -> key -> bool Lwt.t
  (** [mem t k] is true iff [k] is present in [t]. *)

  val find : t -> key -> value option Lwt.t
  (** [find t k] is [Some v] if [k] is associated to [v] in [t] and [None] is
      [k] is not present in [t]. *)

  val set : t -> key -> value -> unit Lwt.t
  (** [set t k v] replaces the contents of [k] by [v] in [t]. If [k] is not
      already defined in [t], create a fresh binding. Raise [Invalid_argument]
      if [k] is the {{!Path.empty} empty path}. *)

  val test_and_set :
    t -> key -> test:value option -> set:value option -> bool Lwt.t
  (** [test_and_set t key ~test ~set] sets [key] to [set] only if the current
      value of [key] is [test] and in that case returns [true]. If the current
      value of [key] is different, it returns [false]. [None] means that the
      value does not have to exist or is removed.

      {b Note:} The operation is guaranteed to be atomic. *)

  val remove : t -> key -> unit Lwt.t
  (** [remove t k] remove the key [k] in [t]. *)

  val list : t -> key list Lwt.t
  (** [list t] it the list of keys in [t]. *)

  type watch
  (** The type of watch handlers. *)

  val watch :
    t ->
    ?init:(key * value) list ->
    (key -> value diff -> unit Lwt.t) ->
    watch Lwt.t
  (** [watch t ?init f] adds [f] to the list of [t]'s watch handlers and returns
      the watch handler to be used with {!unwatch}. [init] is the optional
      initial values. It is more efficient to use {!watch_key} to watch only a
      single given key.*)

  val watch_key :
    t -> key -> ?init:value -> (value diff -> unit Lwt.t) -> watch Lwt.t
  (** [watch_key t k ?init f] adds [f] to the list of [t]'s watch handlers for
      the key [k] and returns the watch handler to be used with {!unwatch}.
      [init] is the optional initial value of the key. *)

  val unwatch : t -> watch -> unit Lwt.t
  (** [unwatch t w] removes [w] from [t]'s watch handlers. *)

  val close : t -> unit Lwt.t
  (** [close t] frees up all the resources associated to [t]. Any operations run
      on a closed store will raise {!Closed}. *)

  val clear : t -> unit Lwt.t
  (** [clear t] clears the store. This operation is expected to be slow. *)
end

module type ATOMIC_WRITE_STORE_MAKER = functor (K : Type.S) (V : Type.S) -> sig
  include ATOMIC_WRITE_STORE with type key = K.t and type value = V.t

  val v : Conf.t -> t Lwt.t
end

module type BRANCH_STORE = sig
  (** {1 Branch Store} *)

  include ATOMIC_WRITE_STORE

  module Key : BRANCH with type t = key
  (** Base functions on keys. *)

  module Val : HASH with type t = value
  (** Base functions on values. *)
end

type remote = ..

module type SYNC = sig
  (** {1 Remote synchronization} *)

  type t
  (** The type for store handles. *)

  type commit
  (** The type for store heads. *)

  type branch
  (** The type for branch IDs. *)

  type endpoint
  (** The type for sync endpoints. *)

  val fetch :
    t ->
    ?depth:int ->
    endpoint ->
    branch ->
    (commit option, [ `Msg of string ]) result Lwt.t
  (** [fetch t uri] fetches the contents of the remote store located at [uri]
      into the local store [t]. Return the head of the remote branch with the
      same name, which is now in the local store. [No_head] means no such branch
      exists. *)

  val push :
    t ->
    ?depth:int ->
    endpoint ->
    branch ->
    (unit, [ `Msg of string | `Detached_head ]) result Lwt.t
  (** [push t uri] pushes the contents of the local store [t] into the remote
      store located at [uri]. *)
end

module type SYNC_STORE = sig
  (** {1 Native Synchronization} *)

  type db
  (** Type type for store handles. *)

  type commit
  (** The type for store heads. *)

  type status = [ `Empty | `Head of commit ]
  (** The type for remote status. *)

  val status_t : db -> status Type.t
  (** [status_t db] is the value type for {!status} of remote [db]. *)

  val pp_status : status Fmt.t
  (** [pp_status] pretty-prints return statuses. *)

  val fetch :
    db -> ?depth:int -> remote -> (status, [ `Msg of string ]) result Lwt.t
  (** [fetch t ?depth r] populate the local store [t] with objects for the
      remote store [r], using [t]'s current branch. The [depth] parameter limits
      the history depth. Return [`Empty] if either the local or remote store do
      not have a valid head. *)

  val fetch_exn : db -> ?depth:int -> remote -> status Lwt.t
  (** Same as {!fetch} but raise [Invalid_argument] if either the local or
      remote store do not have a valid head. *)

  type pull_error = [ `Msg of string | Merge.conflict ]
  (** The type for pull errors. *)

  val pp_pull_error : pull_error Fmt.t
  (** [pp_push_error] pretty-prints pull errors. *)

  val pull :
    db ->
    ?depth:int ->
    remote ->
    [ `Merge of Info.f | `Set ] ->
    (status, pull_error) result Lwt.t
  (** [pull t ?depth r s] is similar to {{!Sync.fetch} fetch} but it also
      updates [t]'s current branch. [s] is the update strategy:

      - [`Merge] uses [Head.merge]. Can return a conflict.
      - [`Set] uses [S.Head.set]. *)

  val pull_exn :
    db -> ?depth:int -> remote -> [ `Merge of Info.f | `Set ] -> status Lwt.t
  (** Same as {!pull} but raise [Invalid_arg] in case of conflict. *)

  type push_error = [ `Msg of string | `Detached_head ]
  (** The type for push errors. *)

  val pp_push_error : push_error Fmt.t
  (** [pp_push_error] pretty-prints push errors. *)

  val push : db -> ?depth:int -> remote -> (status, push_error) result Lwt.t
  (** [push t ?depth r] populates the remote store [r] with objects from the
      current store [t], using [t]'s current branch. If [b] is [t]'s current
      branch, [push] also updates the head of [b] in [r] to be the same as in
      [t].

      {b Note:} {e Git} semantics is to update [b] only if the new head if more
      recent. This is not the case in {e Irmin}. *)

  val push_exn : db -> ?depth:int -> remote -> status Lwt.t
  (** Same as {!push} but raise [Invalid_argument] if an error happens. *)
end

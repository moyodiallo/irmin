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

(** Irmin public API.

    Irmin is a library for persistent stores following the same
    design principle as Git.

    Irmin is a distributed and history-preserving library for
    persistent stores with built-in snapshot, branching and reverting
    mechanisms. It is designed to use a large variety of
    backends. Irmin is written in pure OCaml and does not depend on
    external C stubs; it aims is to run everywhere, from Linux to Xen
    unikernels -- and can be be compiled to JavaScipt to run in a
    browser.

    FIXME
*)

val version: string
(** The version of the library. *)

(** {1 Preliminaries} *)

(** Serializable data with reversible human-readable
    representations. *)
module Hum: sig

  (** {1 Human-representable values} *)

  module type S = sig

    include Tc.S0

    val to_hum: t -> string
    (** Display a value using its human readable representation. *)

    val of_hum: string -> t
    (** Convert an human readable representation of a value into its
        abstract value.

        @raise Invalid_argument if the string does not represent
        anything meaningful. *)

  end

  type 'a t = (module S with type t = 'a)
  (** Type for implementation of [S] for values of type ['a]. *)

end

(** Hashing functions.

    [Hash] provides user-defined hash function to digest serialized
    contents. Some {{!backend}backends} might be parameterize by such
    a hash functions, other might work with a fixed one (for instance,
    the Git format use only SHA1).

    An {{!Hash.SHA1}SHA1} implementation is available to pass to the
    backends. *)
module Hash: sig

  (** {1 Contents Hashing} *)

  exception Invalid of string
  (** Exception raised when parsing a human-readable representation of
      a hash. *)

  module type S = sig

    (** Signature for unique identifiers. *)

    include Hum.S

    val digest: Cstruct.t -> t
    (** Compute a deterministic store key from a cstruct value. *)

    val has_kind: [> `SHA1] -> bool
    (** The kind of generated hash. *)

    val to_raw: t -> Cstruct.t
    (** The raw hash value. *)

    val of_raw: Cstruct.t -> t
    (** Abstract an hash value. *)

  end
  (** Signature for hash values. *)

  module SHA1: S
  (** SHA1 digests *)

end

(** Backend configuration.

    A backend configuration is a set of {{!keys}keys} mapping to
    typed values. Backends define their own keys. *)
module Conf: sig

  (** {1 Configuration converters}

      A configuration converter transforms a string value to an OCaml
      value and vice-versa. There are a few
      {{!builtin_converters}built-in converters}. *)

  type 'a parser = string -> [ `Error of string | `Ok of 'a ]
  (** The type for configuration converter parsers. *)

  type 'a printer = Format.formatter -> 'a -> unit
  (** The type for configuration converter printers. *)

  type 'a converter = 'a parser * 'a printer
  (** The type for configuration converters. *)

  val parser: 'a converter -> 'a parser
  (** [parser c] is [c]'s parser. *)

  val printer: 'a converter -> 'a printer
  (** [converter c] is [c]'s printer. *)

  (** {1:keys Keys} *)

  type 'a key
  (** The type for configuration keys whose lookup value is ['a]. *)

  val key: ?docs:string -> ?docv:string -> ?doc:string ->
    string -> 'a converter -> 'a -> 'a key
  (** [key docs docv doc name conv default] is a configuration key named
      [name] that maps to value [v] by default. [converter] is
      used to convert key values provided by end users.

      [docs] is the title of a documentation section under which the
      key is documented. [doc] is a short documentation string for the
      key, this should be a single sentence or paragraph starting with
      a capital letter and ending with a dot.  [docv] is a
      meta-variable for representing the values of the key
      (e.g. ["BOOL"] for a boolean).

      @raise Invalid_argument if the key name is not made of a
      sequence of ASCII lowercase letter, digit, dash or underscore.
      FIXME not implemented.

      {b Warning.} No two keys should share the same [name] as this
      may lead to difficulties in the UI. *)

  val name: 'a key -> string
  (** The key name. *)

  val conv: 'a key -> 'a converter
  (** [tc k] is [k]'s converter. *)

  val default: 'a key -> 'a
  (** [default k] is [k]'s default value. *)

  val doc: 'a key -> string option
  (** [doc k] is [k]'s documentation string (if any). *)

  val docv: 'a key -> string option
  (** [docv k] is [k]'s value documentation meta-variable (if any). *)

  val docs: 'a key -> string option
  (** [docs k] is [k]'s documentation section (if any). *)

  val root: string option key
  (** Default [--root=ROOT] argument. *)

  (** {1:conf Configurations} *)

  type t
  (** The type for configurations. *)

  val empty: t
  (** [empty] is the empty configuration. *)

  val singleton: 'a key -> 'a -> t
  (** [singletong k v] is the configuration where [k] maps to [v]. *)

  val is_empty: t -> bool
  (** [is_empty c] is [true] iff [c] is empty. *)

  val mem: t -> 'a key -> bool
  (** [mem c k] is [true] iff [k] has a mapping in [c]. *)

  val add: t -> 'a key -> 'a -> t
  (** [add c k v] is [c] with [k] mapping to [v]. *)

  val rem: t -> 'a key -> t
  (** [rem c k] is [c] with [k] unbound. *)

  val find: t -> 'a key -> 'a option
  (** [find c k] is [k]'s mapping in [c], if any. *)

  val get: t -> 'a key -> 'a
  (** [get c k] is [k]'s mapping in [c].

      {b Raises.} [Not_found] if [k] is not bound in [d]. *)

  (** {1:builtin_converters Built-in value converters}  *)

  val bool: bool converter
  (** [bool] converts values with [bool_of_string].  *)

  val int: int converter
  (** [int] converts values with [int_of_string]. *)

  val string: string converter
  (** [string] converts values with the indentity function. *)

  val uri: Uri.t converter
  (** [uri] converts values with [Uri.of_string]. *)

  val some: 'a converter -> 'a option converter
  (** [string] converts values with the indentity function. *)

end

(** Tasks are used to keep track of the origin of reads and writes in
    the store. Every high-level operation is expected to have its own
    task, which is passed to every low-level calls. *)
module Task: sig

  (** {1 Task} *)

  include Tc.S0

  val create: date:int64 -> owner:string -> string -> t
  (** Create a new task. *)

  val date: t -> int64
  (** Get the task date.

      The date is computed by the user user when calling the
      {{!Task.create}create} function. When available,
      [Unix.gettimeofday ()] is a good value for such date. On more
      esoteric platforms, any monotonic counter is a fine value as
      well. On the Git backend, the date will be translated into the
      commit {e Date} field. *)

  val owner: t -> string
  (** Get the task owner.

      The owner identifies the entity (human, unikernel, process,
      thread, etc) performing an operation. For the Git backend, this
      will be directly translated into the {e Author} field. *)

  val uid: t -> int64
  (** Get the task unique identifier.

      The user does not have control over the generation of that
      unique identifier. That identifier is useful for debugging
      purposes, for instance to relate debug lines to the tasks which
      cause them, and might appear in one line of the commit message
      for the Git backend. *)

  val messages: t -> string list
  (** Get the messages associated to the task.

      Text messages can be added to a task either at creation time,
      using {{!Task.create}create}, or can be appended on already
      created tasks using the {{!Task.fprintf}fprintf} function. For
      the Git backend, this will be translated to the commit
      message.  *)

  val add: t -> string -> unit
  (** Add a message to the task messages list. See
      {{!Task.messages}messages} for more details. *)

end

(** [Merge] provides functions to build custom 3-way merge operators
    for various user-defined contents. *)
module Merge: sig

  (** {1 Merge Results} *)

  type 'a result = [ `Ok of 'a | `Conflict of string ]
  (** Type for merge results. *)

  module Result: Tc.S1 with type 'a t = 'a result
  (** Base functions over results. *)

  val bind: 'a result Lwt.t -> ('a -> 'b result Lwt.t) -> 'b result Lwt.t
  (** Monadic bind over Result. *)

  exception Conflict of string
  (** Exception which might be raised when merging.  *)

  val exn: 'a result -> 'a Lwt.t
  (** Convert [`Conflict] results to [Conflict] exceptions. *)

  (** {1 Merge Combinators} *)

  type 'a t = old:'a -> 'a -> 'a -> 'a result Lwt.t
  (** Signature of a merge function.

      {v
              /----> t1 ----\
      ----> old              |--> result
              \----> t2 ----/
      v}
  *)

  val default: 'a Tc.t -> 'a t
  (** Create a default merge function. This is a simple merge
      functions which support changes in one branch at the time:

      {ul
        {- if [t1=t2] then the result of the merge is [`OK t1];}
        {- if [t1=old] then the result of the merge is [`OK t2];}
        {- if [t2=old] then return [`OK t1];}
        {- otherwise the result is [`Conflict].}
      }
  *)

  val string: string t
  (** The default string merge function. Do not anything clever, just
      compare the strings using the [default] merge function. *)

  val counter: int t
  (** The merge function for mergeable counters. *)

  val seq: 'a t list -> 'a t
  (** Try the merge functions in sequence until one does not raise a conflict. *)

  val some: 'a Tc.t -> 'a t -> 'a option t
  (** Lift a merge function to optional values of the same type. If all
      the provided values are inhabited, then call the provided merge
      function, otherwise use the same behavior as [create]. *)

  val alist: 'a Tc.t -> 'b Tc.t -> 'b t -> ('a * 'b) list t
  (** List to association lists. *)

  (** Lift to maps. *)
  module Map (M: Map.S) (X: Tc.S0 with type t = M.key): sig

    (** {1 Merging Maps} *)

    val merge: 'a Tc.t -> 'a t -> 'a M.t t
    (** Lift to [X.t] maps. *)

  end

  val pair: 'a Tc.t -> 'b Tc.t -> 'a t -> 'b t -> ('a * 'b) t
  (** Lift to pairs. *)

  val biject: 'a Tc.t -> 'b Tc.t -> 'a t -> ('a -> 'b) -> ('b -> 'a) -> 'b t
  (** Use the merge function defined in another domain. If the
      functions given in argument are partial (i.e. returning
      [Not_found] on some entries), the exception is caught and
      [Conflict] is returned instead. *)

  val biject':
    'a Tc.t -> 'b Tc.t -> 'a t -> ('a -> 'b Lwt.t) -> ('b -> 'a Lwt.t) -> 'b t
  (** Same as [map] but with potentially blocking converting
      functions. *)

  val apply: ('a -> 'b t) -> 'a -> 'b t
  (** The [apply] combinator is useful to untie recursive loops. *)

  (** Useful merge operators.

      Use [open Irmin.Merge.OP] at the top of your file to use
      them. *)
  module OP: sig

    (** {1 Useful operators} *)

    val ok: 'a -> 'a result Lwt.t
    (** Return [`Ok x]. *)

    val conflict: ('a, unit, string, 'b result Lwt.t) format4 -> 'a
    (** Return [`Conflict str]. *)

    val (>>|): 'a result Lwt.t -> ('a -> 'b result Lwt.t) -> 'b result Lwt.t
    (** Same as [bind]. *)

  end

end

(** {1 Stores} *)

type task = Task.t
(** The type for user-defined tasks. See {{!Task}Task}. *)

type config = Conf.t
(** The type for backend-specific configuration values. See {{!Conf}Conf}.

    Every backend has different configuration options, which are kept
    abstract to the user. *)

(** An Irmin store is automatically built from a number of lower-level
    stores, implementing fewer operations, such as {{!AO}append-only}
    and {{!RW}read-write} stores. These low-level stores are provided
    by various backends. *)


(** Read-only stores. *)
module type RO = sig

  (** {1 Read-only stores} *)

  type t
  (** Type for stores. *)

  type key
  (** Type for keys. *)

  type value
  (** Type for values. *)

  val create: config -> ('a -> task) -> ('a -> t) Lwt.t
  (** [create config task] is a function returning fresh store
      handles, with the configuration [config] and fresh tasks
      computed using [task]. [config] is provided by the backend and
      [task] is the provided by the user. The operation might be
      blocking, depending on the backend. *)

  val config: t -> config
  (** [config t] is the list of configurations keys for the store
      handle [t]. *)

  val task: t -> task
  (** [task t] is the task associated to the store handle [t]. *)

  val read: t -> key -> value option Lwt.t
  (** Read a value from the store. *)

  val read_exn: t -> key -> value Lwt.t
  (** Same as [read] but raise [Not_found] if the key does not
      exist. *)

  val mem: t -> key -> bool Lwt.t
  (** Check if a key exists. *)

  val list: t -> key -> key list Lwt.t
  (** [list t key] is the list of sub-keys that the key [keys] is
      allowed to access. *)

  val dump: t -> (key * value) list Lwt.t
  (** [dump t] is a dump of the store contents. *)

end

(** Append-only store. *)
module type AO = sig

  (** {1 Append-only stores} *)

  include RO

  val add: t -> value -> key Lwt.t
  (** Write the contents of a value to the store. That's the
      responsibility of the append-only store to generate a
      consistent key. *)

end

(** Read-write stores. *)
module type RW = sig

  (** {1 Read-write stores} *)

  include RO

  val update: t -> key -> value -> unit Lwt.t
  (** Replace the contents of [key] by [value] if [key] is already
      defined and create it otherwise. *)

  val remove: t -> key -> unit Lwt.t
  (** Remove the given key. *)

  val watch: t -> key -> value option Lwt_stream.t
  (** Watch the stream of values associated to a given key. Return
      [None] if the value is removed. *)

end

(** Branch-consistent stores. *)
module type BC = sig

  (** {1 Branch-consistent Store}

      They are two kinds of branch consistent stores: the
      {{!persistent}persistent} and the {{!temporary}temporary} ones.

      {2:persistent Persistent Stores}

      The persistent stores are associated to a branch name, or
      {{!BC.tag}tag}. The tag value is updated every time the
      store is updated, so every handle connected or which will be
      connected to the same tag will see the changes.

      These stores can be created using the
      {{!BC.of_tag}of_tag} functions. *)

  include RW
  (** A branch-consistent store is read-write.

      [create config task] is a persistent store handle on the
      [master] branch. This operation is cheap, can be repeated
      multiple times and is expected to be done for every new user
      task. *)

  type tag
  (** Type for branch names, or tags. Tags usually share a common
      global namespace and that's the user responsibility to avoid
      name-clashes. *)

  val of_tag: config -> ('a -> task) -> tag -> ('a -> t) Lwt.t
  (** [create t tag] is a persistent store handle. Similar to
      [create], but use the [tag] branch instead of the [master]
      one. *)

  val tag: t -> tag option
  (** [tag t] is the tag associated to the store handle [t]. [None]
      means that the branch is not persistent. *)

  val tag_exn: t -> tag
  (** Same as [tag] but raise [Not_found] if the store handle is not
      persistent. *)

  val tags: t -> tag list Lwt.t
  (** The list of all the tags of the store. *)

  val update_tag: t -> tag -> [`Ok | `Duplicated_tag] Lwt.t
  (** Change the current tag name. Fail if a tag with the same name
      already exists. The head is unchanged. *)

  val update_tag_force: t -> tag -> unit Lwt.t
  (** Same as [update_tag] but delete and update the tag if it already
      exists. *)

  val switch: t -> tag -> unit Lwt.t
  (** Switch the store contents the be same as the contents of the
      given branch name. The two branches are still independent. *)

  (** {2:temporary Temporary Stores}

      The temporary stores do not use global branch names. Instead,
      the operations are relative to a given store revision: a
      {{!BC.head}head}. Every operation updates the store as a
      normal persistent store, but the value of head is only kept
      into the local store handle and it is not persisted into the
      store -- this means it cannot be easily shared by concurrent
      processes or loaded back in the future. In the Git
      terminology, these store handle are said to be {i detached
      heads}. *)

  type head
  (** Type for head values. *)

  val of_head: config -> ('a -> task) -> head -> ('a -> t) Lwt.t
  (** Create a temporary store handle, which will not persist as it
      has no associated to any persistent tag name. *)

  val head: t -> head option Lwt.t
  (** Return the head commit. This works for both persistent and
      temporary stores. In the case of a persistent store, this
      involves looking into the value associated to the branch tag,
      so this might blocks. In the case of a temporary store, it is
      a simple (non-blocking) look-up in the store handle local
      state. *)

  val head_exn: t -> head Lwt.t
  (** Same as [read_head] but raise [Not_found] if the commit does
      not exist. *)

  val branch: t -> [`Tag of tag | `Head of head]
  (** [branch t] is the current branch of the store [t]. Can either be
      a persistent store with a [tag] name or a detached [head]. *)

  val heads: t -> head list Lwt.t
  (** The list of all the heads of the store. *)

  val detach: t -> unit Lwt.t
  (** Detach the current branch (i.e. it is not associated to a tag
      anymore). *)

  val update_head: t -> head -> unit Lwt.t
  (** Set the commit head. *)

  val merge_head: t -> head -> unit Merge.result Lwt.t
  (** Merge a commit with the current branch. *)

  val merge_head_exn: t -> head -> unit Lwt.t
  (** FIXME *)

  val watch_head: t -> key -> (key * head) Lwt_stream.t
  (** Watch changes for a given collection of keys and the ones they
      have recursive access. Return the stream of heads corresponding
      to the modified keys. *)

  (** {2 Clones and Merges} *)

  val clone: t -> ('a -> task) -> tag -> [`Ok of ('a -> t) | `Duplicated_tag] Lwt.t
  (** Fork the store, using the given branch name. Return [None] if
      the branch already exists. *)

  val clone_force: t -> ('a -> task) -> tag -> ('a -> t) Lwt.t
  (** Same as [clone] but delete and update the existing branch if a
      branch with the same name already exists. *)

  val merge: t -> tag -> unit Merge.result Lwt.t
  (** [merge db t] merges the branch [t] into the current store
      branch. The two branches are still independent. *)

  val merge_exn: t -> tag -> unit Lwt.t
  (** FIXME *)

  (** {2 Slices} *)

  type slice
  (** Type for store slices. *)

  val export: ?full:bool -> ?depth:int -> ?min:head list -> ?max:head list ->
    t -> slice Lwt.t
  (** [export t ~depth ~min ~max] exports the store slice between
      [min] and [max], using at most [depth] history depth (starting
      from the max).

      If [max] is not specified, use the current [heads]. If [min] is
      not specified, use an unbound past (but can be still limited by
      [depth]).

      [depth] is used to limit the depth of the commit history. [None]
      here means no limitation.

      If [full] is set (default is true) the full graph, including the
      commits, nodes and contents, is exported, otherwise it is the
      commit history graph only. *)

  val import: t -> slice -> [`Ok | `Duplicated_tags of tag list] Lwt.t
  (** Import a store slide. Do not modify existing tags. FIXME: do not modify tags at all. *)

  val import_force: t -> slice -> unit Lwt.t
  (** Same as [import] but delete and update the tags they already
      exist in the store. *)

end

(** {1 User-Defined Contents} *)

(** [Contents] specifies how user-defined contents need to be {e
    serializable} and {e mergeable}.

    The user need to provide:

    {ul
    {- a [to_sexp] function for debugging purposes (that might expose
      the internal state of abstract values)}
    {- a pair of [to_json] and [of_json] functions, to be used by the
    REST interface.}
    {- a triple of [size_of], [write] and [read] functions, to
    serialize data on disk or to send it over the network.}
    {- a 3-way [merge] function, to handle conflicts between multiple
    versions of the same contents.}
    }

    Default contents for {{!Contents.String}string},
    {{!Contents.Json}JSON} and {{!Contents.Cstruct}C-buffers like}
    values are provided. *)
module Contents: sig

  module type S = sig

    (** {1 Signature for store contents} *)

    include Tc.S0
    (** Base functions over contents. *)

    val merge: t Merge.t
    (** Merge function. Evaluates to [`Conflict] if the values cannot be
        merged properly. *)

  end

  module String: S with type t = string
  (** String values where only the last modified value is kept on
      merge. If the value has been modified concurrently, the [merge]
      function raises [Conflict]. *)

  module Json: S with type t = Ezjsonm.t
  (** JSON values where only the last modified value is kept on
      merge. If the value has been modified concurrently, the [merge]
      function raises [Conflict]. *)

  module Cstruct: S with type t = Cstruct.t
  (** Cstruct values where only the last modified value is kept on
      merge. If the value has been modified concurrently, then this is a
      conflict. *)

  (** Contents store. *)
  module type STORE = sig

      include AO

      val merge: t -> key Merge.t
      (** [merge t] lifts the merge functions defined over contents
          values to contents key. The merge functio will: {e (i)} read
          the values associated with the given keys, {e (ii)} use the
          merge function defined over values and {e (iii)} write the
          resulting values into the store to get the resulting key.

          If any of these operation fails, return [`Conflict]. *)

      module Key: Hash.S with type t = key
      (** [Key] provides base functions for user-defined contents keys. *)

      module Val: Tc.S0 with type t = value
      (** [Val] provides base function for user-defined contents values. *)

    end

  (** [Make] builds a contents store. *)
  module Make (S: sig
                 include AO
                 module Key: Hash.S with type t = key
                 module Val: S with type t = value
               end):
    STORE with type t = S.t and type key = S.key and type value = S.value

end

(** User-defined tags. Tags are used to specify branch names in an
    Irmin store. *)
module Tag: sig

  (** {1 Tags} *)

  (** A tag implementations specifies base functions over abstract
      tags and define a default value for denoting the
      {{!Tag.S.master}master} branch name. *)
  module type S = sig

    (** {1 Signature for tags implementations} *)

    (** Signature for tags (i.e. branch names). *)

    include Hum.S

    val master: t
    (** The name of the master branch. *)

  end

  module String_list: S with type t = string list
  (** [String_list] is an implementation of {{!Tag.S}S} where tags are
      lists of strings.

      The [master] tag is [["master"]] and the human-representation of
      [["x"];["y"]] is ["x/y"]. *)

  (** [STORE] specifies the signature of tag stores.

      A {i tag store} is a key / value store, where keys are names
      created by users (and/or global names created by convention) and
      values are keys from the block store.

      A typical Irmin application should have a very low number of
      keys in the tag store. *)
  module type STORE = sig

    (** {1 Tag Store} *)

    include RW

    module Key: S with type t = key
    (** Base functions over keys. *)

    module Val: Hash.S with type t = value
    (** Base functions over values. *)

  end

end

(** A key in an {{!Irmin.S}stores} is a path of basic elements. We
    call these elements {e steps}, and the following [Path] module
    provides functions to manipulate steps and paths. *)
module Path: sig

  (** {1 Path} *)

  (** Signature for path steps. *)
  module type STEP = Hum.S

  (** Signature for path implementations.*)
  module type S = sig

    (** {1 Path} *)

    type step
    (** Type type for basic steps. *)

    type t = step list
    (** The type for path values. *)

    module Step: STEP with type t = step

    include Hum.S with type t := t

  end

  module Make (S: STEP): S with type step = S.t
  (** A list of steps, representing keys in an Irmin store. *)

  module String: S with type step = string
  (** An implementation of paths using strings as steps. *)

end

(** [Node] provides functions to describe the graph-like structured
    values.

    The node blocks form a labeled directed acyclic graph, labeled
    by {{!Path.S.step}steps}: a list of steps defines a
    unique path from one node to an other.

    Each node can point to user-defined {{!Contents.S}contents}
    values. *)
module Node: sig

  module type S = sig

    (** {1 Node values} *)

    include Tc.S0

    type contents
    (** The type for contents keys. *)

    type node
    (** The type for node keys. *)

    type step
    (** The type for steps between nodes. *)

    val create: contents:(step * contents) list -> succ:(step * node) list -> t
    (** Create a new node. *)

    val empty: t
    (** The empty node. *)

    val is_empty: t -> bool
    (** Is the node empty. *)

    val contents: t -> step -> contents option
    (** Get the node contents.

        A node can point to user-defined
        {{!Node.S.contents}contents}. The edge between the node and
        that contents is labeled by a {{!Node.S.step}step}. *)

    val iter_contents: t -> (step -> contents -> unit) -> unit
    (** Iter over all the contents. Use {{!Node.S.contents}contents} when
        you know the step in advance. *)

    val with_contents: t -> step -> contents option -> t
    (** Replace the contents. *)

    val succ: t -> step -> node option
    (** Extract the successors of a node. *)

    val iter_succ: t -> (step -> node -> unit) -> unit
    (** Iter over all the successors. FIXME *)

    val with_succ: t -> step -> node option -> t
    (** Replace the successors. *)

  end

  (** [Node] provides a simple node implementation, parametrized over
      contents [C], node [N] and paths [P]. *)
  module Make (C: Tc.S0) (N: Tc.S0) (P: Path.S):
    S with type contents = C.t
       and type node = N.t
       and type step = P.step

  (** [STORE] specifies the signature for node stores. *)
  module type STORE = sig

    include AO

    module Path: Path.S
    (** [Step] provides base functions over node steps. *)

    module Key: Hash.S with type t = key
    (** [Key] provides base functions for node keys. *)

    (** [Val] provides base functions for node values. *)
    module Val: S with type t = value
                   and type node = key
                   and type step = Path.step
  end

  (** [Graph] specifies the signature for node graphs. A node graph
      is a DAG labelled by steps. *)
  module type GRAPH = sig

    (** {1 Node Graphs} *)

    type t
    (** The type for store handles. *)

    type contents
    (** The type of user-defined contents. *)

    type node
    (** The type for node values. *)

    type step
    (** The type of steps. A step is used to pass from one node to an
        other. A list of steps forms a path. *)

    val empty: t -> node Lwt.t
    (** The empty node. *)

    val node: t ->
      contents:(step * contents) list -> succ:(step * node) list -> node Lwt.t
    (** [create t contents succ] Create a new node pointing to
        [contents] and [succ], and using the store handle [t]. *)

    val contents: t -> node -> step -> contents option Lwt.t
    (** [contents t n s] is the contents pointed by [s] in the node [n]. *)

    val succ: t -> node -> step -> node option Lwt.t
    (** [succ t n s] is the node pointed by [s] in the node [n]. *)

    val steps: t -> node -> step list Lwt.t
    (** FIXME *)

    val iter_contents: t -> node -> (step -> contents -> unit) -> unit Lwt.t
    (** FIXME *)

    val iter_succ: t -> node -> (step -> node -> unit) -> unit Lwt.t
    (** FIXME *)

    (** {1 Contents} *)

    val mem_contents: t -> node -> step list -> bool Lwt.t
    (** FIXME: Is a path valid. *)

    val read_contents: t -> node -> step list -> contents option Lwt.t
    (** FIXME: Find a value. *)

    val read_contents_exn: t -> node -> step list -> contents Lwt.t
    (** FIXME: Find a value. Raise [Not_found] is [path] is not defined. *)

    val add_contents: t -> node -> step list -> contents -> node Lwt.t
    (** FIXME: Add a value by recusively saving subvalues into the
        corresponding stores. *)

    val remove_contents: t -> node -> step list -> node Lwt.t
    (** FIXME: Remove the contents. *)

    (** {1 Nodes} *)

    val mem_node: t -> node -> step list -> bool Lwt.t
    (** FIXME: Is a path valid. *)

    val read_node: t -> node -> step list -> node option Lwt.t
    (** [read_node t n p] is the node reached following the path [p]
        from the node [n]. If [p] is not a valid path, return
        [None]. *)

    val read_node_exn: t -> node -> step list -> node Lwt.t
    (** Same as {{!Node.GRAPH.read_node}read_node} but raise
        [Not_found] if the path is invalid. *)

    val add_node: t -> node -> step list -> node -> node Lwt.t
    (** FIXME: Add a value by recusively saving subvalues into the
        corresponding stores. *)

    val remove_node: t -> node -> step list -> node Lwt.t
    (** FIXME: Remove the contents. *)

    val merge: t -> node Merge.t
    (** FIXME: Merge two nodes together. *)

    val closure: t -> min:node list -> max:node list -> node list Lwt.t
    (** FIXME: Recursive list. *)

    module Store: Contents.STORE with type t = t and type key = node
    (** FIXME *)

  end

  module Graph (C: Contents.STORE) (S: STORE with type Val.contents = C.key)
    : GRAPH with type t = C.t * S.t
             and type contents = C.key
             and type node = S.key
             and type step = S.Val.step

end

(** Commit values represent the store history.

    Every commit contains a list of predecessor commits, and the
    collection of commits form an acyclic directed graph.

    Every commit also can contain an optional key, pointing to a
    {{!Private.Commit.STORE}node} value. See the
    {{!Private.Node.STORE}Node} signature for more details on node
    values. *)
module Commit: sig

  module type S = sig

    (** {1 Commit values} *)

    include Tc.S0
    (** Base functions over commit values. *)

    type commit
    (** Type for commit keys. *)

    type node
    (** Type for node keys. *)

    val create: task -> ?node:node -> parents:commit list -> t
    (** Create a commit. *)

    val node: t -> node option
    (** The underlying node. *)

    val parents: t -> commit list
    (** The commit parents. *)

    val task: t -> task
    (** The commit provenance. *)

  end

  (** [Make] provides a simple implementation of commit values,
      parametrized over commit [C] and node [N]. *)
  module Make (C: Tc.S0) (N: Tc.S0):
    S with type commit := C.t and type node = N.t

  (** [STORE] specifies the signature for commit stores. *)
  module type STORE = sig

    (** {1 Commit Store} *)

    include AO

    module Key: Hash.S with type t = key
    (** [Key] provides base functions for commit keys. *)

    (** [Val] provides function for commit values. *)
    module Val: S with type t = value and type commit := key

  end

  (** [History] specifies the signature for commit history. The
      history is represented as a partial-order of commits and basic
      functions to search through that history are provided.

      Every commit can point to an entry point in a node graph, where
      user-defined contents are stored. *)
  module type HISTORY = sig

    (** {1 Commit History} *)

    type t
    (** The type for store handles. *)

    type node
    (** The type for node values. *)

    type commit
    (** The type for commit values. *)

    val commit: t -> ?node:node -> parents:commit list -> commit Lwt.t
    (** Create a new commit. *)

    val node: t -> commit -> node option Lwt.t
    (** Get the commit node. FIXME *)

    val parents: t -> commit -> commit list Lwt.t
    (** Get the node parents. FIXME *)

    val merge: t -> commit Merge.t
    (** Lift [S.merge] to the store keys. *)

    val find_common_ancestor: t -> commit -> commit -> commit option Lwt.t
    (** FIXME Find the common ancestor of two commits. *)

    val find_common_ancestor_exn: t -> commit -> commit -> commit Lwt.t
    (** Same as [find_common_ancestor] but raises [Not_found] if the two
        commits share no common ancestor. *)

    val closure: t -> min:commit list -> max:commit list -> commit list Lwt.t
    (** FIXME Recursive list of keys. *)

    module Store: Contents.STORE with type t = t and type key = commit
    (** FIXME *)

  end

  (** [History] builds a commit history. FIXME *)
  module History (N: Contents.STORE) (S: STORE with type Val.node = N.key):
    HISTORY with type t = N.t * S.t
             and type node = N.key
             and type commit = S.key

end

(** [Private] defines functions only useful for creating new
    backends. If you are just using the library (and not developing a
    new backend), you should not use this module. *)
module Private: sig

  (** The signature for slices. *)
  module Slice: sig

    module type S = sig

      (** {1 Slices} *)

      include Tc.S0
      (** Slices are serializable. *)

      type contents
      (** The type for exported contents. *)

      type nodes
      (** The type for exported nodes. *)

      type commits
      (** The type for exported commits. *)

      type tags
      (** The type for exported tags. *)

      val create:
        ?contents:contents -> ?nodes:nodes -> ?commits:commits -> ?tags:tags ->
        unit -> t
      (** Create a new slice. *)

      val contents: t -> contents
      (** The slice contents. *)

      val nodes: t -> nodes
      (** The slice nodes. *)

      val commits: t -> commits
      (** The slice commits. *)

      val tags: t -> tags
      (** The slice tags. *)

    end

    (** Build simple slices. *)
    module Make
        (C: Contents.STORE) (N: Node.STORE) (H: Commit.STORE) (T: Tag.STORE):
      S with type contents = (C.key * C.value) list
         and type nodes = (N.key * N.value) list
         and type commits = (H.key * H.value) list
         and type tags = (T.key * T.value) list

  end

  module Sync: sig

    module type S = sig

      (** {1 Remote synchronization} *)

      type t
      (** The type for store handles. *)

      type head
      (** The type for store heads. *)

      type tag
      (** The type for store tags. *)

      val create: config -> t Lwt.t
      (** Create a remote store handle. *)

      val fetch: t -> ?depth:int -> uri:string -> tag ->
        [`Local of head] option Lwt.t
      (** [fetch t uri] fetches the contents of the remote store
          located at [uri] into the local store [t]. Return the head
          of the remote branch with the same name, which is now in the
          local store. [None] is no such branch exists. *)

      val push: t -> ?depth:int -> uri:string -> tag -> [`Ok | `Error] Lwt.t
      (** [push t uri] pushes the contents of the local store [t] into
          the remote store located at [uri]. *)

    end

    (** [None] is an implementation of {{!Private.Sync.S}S} which does
        nothing. *)
    module None (H: Tc.S0) (T: Tc.S0): S with type head = H.t and type tag = T.t

  end

  (** The complete collection of private implementations. *)
  module type S = sig

    (** {1 Private Implementations} *)

    (** Private contents. *)
    module Contents: Contents.STORE

    (** Private nodes. *)
    module Node: Node.STORE with type Val.contents = Contents.key

    (** Private commits. *)
    module Commit: Commit.STORE with type Val.node = Node.key

    (** Private tags. *)
    module Tag: Tag.STORE with type value = Commit.key

    (** Private slices. *)
    module Slice: Slice.S
      with type contents = (Contents.key * Contents.value) list
       and type nodes = (Node.key * Node.value) list
       and type commits = (Commit.key * Commit.value) list
       and type tags = (Tag.key * Tag.value) list

    module Sync: Sync.S with type head = Commit.key and type tag = Tag.key

  end

end

(** {1 High-level Stores}

    An Irmin store is a branch-consistent store where keys are lists
    of steps.

    An example is a Git repository where keys are filenames, i.e. list
    of ['\']-separated strings. More complex examples are structured
    values, where steps might contains first-class fields accessors
    and array offsets.

    Irmin provides the followgin features:

    {ul
    {- Support for fast {{!BC}clones}, branches and merges, in a
    fashion very similar to Git.}
    {- Efficient {{!View}staging areas} for fast, transient,
    in-memory operations.}
    {- Space efficient {{!Snapshot}snapshots} and fast and consistent
    rollback operations.}
    {- Fast {{!Sync}synchronization} primitives between remote
    stores, using native backend protocols (as the Git protocol) when
    available.}
    }
*)

(** Signature for Irmin stores. *)
module type S = sig

  (** {1 Irmin Store} *)

  type step
  (** The type for step values. *)

  include BC with type key = step list

  module Key: Path.S with type step = step
  (** [Key] provides base functions over step lists. *)

  module Val: Tc.S0 with type t = value
  (** [Val] provides base functions over user-defined, mergeable
      contents. *)

  module Tag: Tag.S with type t = tag
  (** [Tag] provides base functions over user-defined tags. *)

  module Head: Hash.S with type t = head
  (** [Head] prives base functions over head values. *)

  (** Private functions, which might be used by the backends. *)
  module Private: sig
    include Private.S
      with type Node.Path.step = step
       and type Contents.value = value
       and type Commit.key = head
       and type Tag.key = tag
       and type Slice.t = slice
    val contents_t: t -> Contents.t
    val node_t: t -> Node.t
    val commit_t: t -> Commit.t
    val tag_t: t -> Tag.t
    val read_node: t -> key -> Node.key option Lwt.t
    val mem_node: t -> key -> bool Lwt.t
    val update_node: t -> key -> Node.key -> unit Lwt.t
  end

end

(** [View] provides an in-memory partial mirror of the store, with
    lazy reads and delayed write.

    Views are like staging area in Git: they are temporary
    non-persistent areas (they disappear if the host crash), hold in
    memory for efficiency, where reads are done lazily and writes
    are done only when needed on commit: if if you modify a key
    twice, only the last change will be written to the store when
    you commit. Views also hold a list of operations, which are
    checked for conflicts on commits and are used to replay/rebase
    the view if needed. The most important feature of views is that
    they keep track of reads: i.e. you can have a conflict if a view
    reads a key which has been modified concurrently by someone
    else.  *)
module View (S: S): sig

  (** {1 Views} *)

  type db = S.t
  (** The type for store handles. *)

  include RW with type key = S.Key.t and type value = S.Val.t
  (** A view is a read-write temporary store, mirroring the main
      store. *)

  val merge: t -> into:t -> unit Merge.result Lwt.t
  (** Merge the actions done on one view into an other one. If a read
      operation doesn't return the same result, return
      [Conflict]. Only the [into] view is updated. *)

  val merge_exn: t -> into:t -> unit Lwt.t
  (** FIXME *)

  val of_path: db -> key -> t Lwt.t
  (** Read a view from a path in the store. This is a cheap operation,
      all the real reads operation will be done on-demand when the
      view is used. *)

  val update_path: db -> key -> t -> unit Lwt.t
  (** Commit a view to the store. The view *replaces* the current
      subtree, so if you want to do a merge, you have to do it
      manually (by creating a new branch, or rebasing before
      committing). *)

  val rebase_path: db -> key -> t -> unit Merge.result Lwt.t
  (** Rebase the view to the tip of the store. *)

  val rebase_path_exn: db -> key -> t -> unit Lwt.t
  (** FIXME *)

  val merge_path: db -> key -> t -> unit Merge.result Lwt.t
  (** Same as [update_path] but *merges* with the current subtree. *)

  val merge_path_exn: db -> key -> t -> unit Lwt.t
  (** FIXME *)

  (** [Action] provides information about operations performed on a
      view.

      Each view stores the list of {{!View.Action.t}actions} that
      have already been performed on it. These actions are useful
      when the view needs to be rebased: write operations are
      replayed while read results are checked against the original
      run. *)
  module Action: sig

    (** {1 Actions} *)

    type t =
      [ `Read of (key * value option)
      | `Write of (key * value option)
      | `List of (key * key list) ]
    (** Operations on view. The read results are kept to be able
        to replay them on merge and to check for possible conflict:
        this happens if the result read is different from the one
        recorded. *)

    include Tc.S0 with type t := t

    val pretty: t -> string
    (** Pretty-print an action. *)

    val prettys: t list -> string
    (** Pretty-print a sequence of actions. *)

  end
  (** Signature for actions performed on a view. *)

  val actions: t -> Action.t list
  (** Return the list of actions performed on this view since its
      creation. *)

end

(** [Snapshot] provides read-only, space-efficient, checkpoints of a
    store. It also provides functions to rollback to a previous
    state. *)
module Snapshot (S: S): sig

  (** {1 Snapshots} *)

  include RO with type key = S.Key.t and type value = S.Val.t
  (** A snapshot is a read-only store, mirroring the main store. *)

  val create: S.t -> t Lwt.t
  (** Snapshot the current state of the store. *)

  val revert: S.t -> t -> unit Lwt.t
  (** Revert the store to a previous state. *)

  val merge: S.t -> t -> unit Merge.result Lwt.t
  (** Merge the given snapshot into the current branch of the
      store. *)

  val merge_exn: S.t -> t -> unit Lwt.t
  (** FIXME *)

  val watch: S.t -> key -> (key * t) Lwt_stream.t
  (** Subscribe to the stream of modification events attached to a
      given path. Takes and returns a new snapshot every time a
      sub-path is modified. *)

end

(** [Dot] provides functions to export a store to the Graphviz `dot`
    format. *)
module Dot (S: S): sig

  (** {1 Dot Export} *)

  val output_buffer:
    S.t -> ?html:bool -> ?depth:int -> ?full:bool -> date:(int64 -> string) ->
    Buffer.t -> unit Lwt.t
  (** [output_buffer t ?html ?depth ?full buf] outputs the Graphviz
      representation of [t] in the buffer [buf].

      [html] (default is false) enables HTML labels.

      [depth] is used to limit the depth of the commit history. [None]
      here means no limitation.

      If [full] is set (default is not) the full graph, including the
      commits, nodes and contents, is exported, otherwise it is the
      commit history graph only. *)

end

(** [Sync] provides functions to synchronization an Irmin store with
    local and remote Irmin stores. *)
module Sync (S: S): sig

  (** {1 Native Synchronization} *)

  type remote
  (** The type for remote stores. *)

  val uri: string -> remote
  (** [uri s] is the remote store located at [uri]. Use the
      optimized native synchronization protocol when available for the
      given backend. *)

  val store: (module S with type t = 'a) -> 'a -> remote
  (** [store t] is the remote corresponding to the local store
      [t]. Synchronization is done by importing and exporting store
      {{!BC.slice}slices}, so this is usually much slower than native
      synchronization using [uri] remotes. *)

  val fetch: S.t -> ?depth:int -> remote -> S.head option Lwt.t
  (** [create t last] fetch an object in the local store. The local
      store can then be either [merged], or [updated] to the new
      contents. The [depth] parameter limits the history
      depth. Return the new [head] in the local store corresponding
      to the current branch -- [fetch] does not update the local
      branches, use {{!Sync.pull}pull} instead. *)

  val fetch_exn: S.t -> ?depth:int -> remote -> S.head Lwt.t
  (** FIXME *)

  val pull: S.t -> ?depth:int -> remote -> [`Merge | `Update] ->
    unit Merge.result Lwt.t
  (** Same as {{!Sync.fetch}fetch} but also update the current
      branch. Either [merge] or force [update] with the fetched
      head. *)

  val pull_exn: S.t -> ?depth:int -> remote -> [`Merge | `Update] -> unit Lwt.t
  (** FIXME *)

  val push: S.t -> ?depth:int -> remote -> [`Ok | `Error] Lwt.t
  (** [push t f] push the contents of the current branch of the
      store to the remote store -- also update the remote branch
      with the same name as the local one to points to the new
      state. *)

  val push_exn: S.t -> ?depth:int -> remote -> unit Lwt.t
  (** FIXME *)

end

(** {1:backend Backends} *)

(** API to create new Irmin backends. A backend is an implementation
    exposing either a concrete implementation of {!S} or a functor
    providing {!S} once applied.

    There are two ways to create a concrete {!Irmin.S} implementation:

    {ul
    {- {!Make} creates a store where all the objects are stored in the
    same store, using the same internal keys format and a custom binary
    format based on {{:https://github.com/janestreet/bin_prot}bin_prot},
    with no native synchronization primitives: it is usually what is
    needed to quickly create a new backend.}
    {-{!Make_ext} creates a store with a {e deep} embedding of each of
    the internal stores into separate store, with a total control over
    the binary format and using the native synchronization protocols
    when available. This is mainly used by the Git backend, but could
    be used for other similar backends as well in the future.}
    }
*)

(** [AO_MAKER] is the signature exposed by any backend providing
    append-only stores. [K] is the implementation of keys and [V] is
    the implementation of values. *)
module type AO_MAKER =
  functor (K: Hash.S) ->
  functor (V: Tc.S0) ->
    AO with type key = K.t and type value = V.t

(** [RW_MAKER] is the signature exposed by any backend providing
    read-write stores. [K] is the implementation of keys and [V] is
    the implementation of values.*)
module type RW_MAKER =
  functor (K: Hum.S) ->
  functor (V: Hash.S) ->
    RW with type key = K.t and type value = V.t

(** [S_MAKER] is the signature exposed by any backend providing {!S}
    implementations. [S] is the type of steps (a key is list of
    steps), [C] is the implementation of user-defined contents, [T] is
    the implementation of store tags and [H] is the implementation of
    store heads. It does not use any native synchronisation
    primitves. *)
module type S_MAKER =
  functor (P: Path.S) ->
  functor (C: Contents.S) ->
  functor (T: Tag.S) ->
  functor (H: Hash.S) ->
    S with type step = P.step
       and type value = C.t
       and type tag = T.t
       and type head = H.t

(** Simple store creator. Use the same type of all of the internal
    keys and store all the values in the same store. *)
module Make (AO: AO_MAKER) (RW: RW_MAKER): S_MAKER

(** Advanced store creator. *)
module Make_ext (P: Private.S): S
  with type step = P.Node.Path.step
   and type value = P.Contents.value
   and type tag = P.Tag.key
   and type head = P.Tag.value

(** [Watch] provides helpers to register event notifications on
    read-write stores. *)
module Watch: sig

  (** {1 Watch Helpers} *)

  (** The signature for watch helpers. *)
  module type S = sig

    (** {1 Watch Helpers} *)

    type key
    (** The type for store keys. *)

    type value
    (** The type for store values. *)

    type t
    (** The type for watch state. *)

    val notify: t -> key -> value option -> unit
    (** Notify all listeners in the given watch state that a key has
        changed, with the new value associated to this key. If the
        argument is [None], this means the key has been removed. *)

    val create: unit -> t
    (** Create a watch state. *)

    val clear: t -> unit
    (** Clear all register listeners in the given watch state. *)

    val watch: t -> key -> value option -> value option Lwt_stream.t
    (** Create a stream of value notifications. Need to provide the
        initial value, or [None] if the key does not have associated
        contents yet.  *)

    val listen_dir: t -> string
      -> key:(string -> key option)
      -> value:(key -> value option Lwt.t)
      -> unit
      (** Register a fsevents/inotify thread to look for changes in
          the given directory. *)

  end

  val set_listen_dir_hook: (string -> (string -> unit Lwt.t) -> unit) -> unit
  (** Register a function which looks for file changes in a
      directory. Could use [inotify] when available, or use an active
      stats file polling.*)

  val lwt_stream_lift: 'a Lwt_stream.t Lwt.t -> 'a Lwt_stream.t
  (** Lift a stream out of the monad. *)

  (** [Make] builds an implementation of watch helpers. *)
  module Make(K: Tc.S0) (V: Tc.S0): S with type key = K.t and type value = V.t

end

module Env_paths = struct
  type t = {
    data : Eio.Fs.dir_ty Eio.Path.t;
    config : Eio.Fs.dir_ty Eio.Path.t;
    cache : Eio.Fs.dir_ty Eio.Path.t;
    log : Eio.Fs.dir_ty Eio.Path.t;
    temp : Eio.Fs.dir_ty Eio.Path.t;
  }

  module Platform = struct
    type t = MacOS | Windows | Linux

    let current =
      match Sys.os_type with
      | "Unix" -> (
          match Sys.getenv_opt "OSTYPE" with
          | Some ostype when String.starts_with ostype ~prefix:"darwin" -> MacOS
          | _ -> Linux)
      | "Win32" -> Windows
      | _ -> Linux
  end

  let homedir = Sys.getenv "HOME"
  let tmpdir = Filename.get_temp_dir_name ()

  let get_env_or ~default var =
    match Sys.getenv_opt var with Some value -> value | None -> default

  let ( / ) = Eio.Path.( / )

  let macos ~fs name =
    let library = fs / homedir / "Library" in
    {
      data = library / "Application Support" / name;
      config = library / "Preferences" / name;
      cache = library / "Caches" / name;
      log = library / "Logs" / name;
      temp = fs / tmpdir / name;
    }

  let win ~fs name =
    let appdata =
      get_env_or "APPDATA" ~default:(Filename.concat homedir "AppData/Roaming")
    in
    let localappdata =
      get_env_or "LOCALAPPDATA"
        ~default:(Filename.concat homedir "AppData/Local")
    in
    {
      data = fs / localappdata / name / "Data";
      config = fs / appdata / name / "Config";
      cache = fs / localappdata / name / "Cache";
      log = fs / localappdata / name / "Log";
      temp = fs / tmpdir / name;
    }

  let linux ~fs name =
    let username = Filename.basename homedir in
    let xdg_data_home =
      get_env_or "XDG_DATA_HOME"
        ~default:(Filename.concat homedir ".local/share")
    in
    let xdg_config_home =
      get_env_or "XDG_CONFIG_HOME" ~default:(Filename.concat homedir ".config")
    in
    let xdg_cache_home =
      get_env_or "XDG_CACHE_HOME" ~default:(Filename.concat homedir ".cache")
    in
    let xdg_state_home =
      get_env_or "XDG_STATE_HOME"
        ~default:(Filename.concat homedir ".local/state")
    in
    {
      data = fs / xdg_data_home / name;
      config = fs / xdg_config_home / name;
      cache = fs / xdg_cache_home / name;
      log = fs / xdg_state_home / name;
      temp = fs / tmpdir / username / name;
    }

  let create ?suffix ~fs name =
    let name = match suffix with Some s -> name ^ "-" ^ s | None -> name in
    match Platform.current with
    | MacOS -> macos ~fs name
    | Windows -> win ~fs name
    | Linux -> linux ~fs name

  let to_string t =
    String.concat "\n"
      [
        "Data: " ^ Eio.Path.native_exn t.data;
        "Config: " ^ Eio.Path.native_exn t.config;
        "Cache: " ^ Eio.Path.native_exn t.cache;
        "Log: " ^ Eio.Path.native_exn t.log;
        "Temp: " ^ Eio.Path.native_exn t.temp;
      ]
end

module Storage = struct
  open Sqlite3

  type operation = {
    id : int;
    operation_type : string;
    source_path : string;
    destination_path : string;
    timestamp : string;
  }

  let db = ref None

  let init ~db_file =
    db := Some (db_open db_file);
    match !db with
    | Some db -> (
        let sql =
          "CREATE TABLE IF NOT EXISTS operations (\n\
          \                   id INTEGER PRIMARY KEY AUTOINCREMENT,\n\
          \                   operation_type TEXT NOT NULL,\n\
          \                   source_path TEXT NOT NULL,\n\
          \                   destination_path TEXT NOT NULL,\n\
          \                   timestamp DATETIME DEFAULT CURRENT_TIMESTAMP\n\
          \                   );"
        in
        match exec db sql with
        | Rc.OK -> Ok ()
        | err -> Error (Rc.to_string err))
    | None -> Error "Failed to open database"

  let close () =
    match !db with
    | Some db_handle ->
        db_close db_handle |> ignore;
        db := None;
        ()
    | None -> ()

  let insert_operation operation_type source_path destination_path =
    match !db with
    | Some db -> (
        let sql =
          "INSERT INTO operations (operation_type, source_path, \
           destination_path)\n\
          \                   VALUES (?, ?, ?);"
        in
        let stmt = prepare db sql in
        bind stmt 1 (Data.TEXT operation_type) |> ignore;
        bind stmt 2 (Data.TEXT source_path) |> ignore;
        bind stmt 3 (Data.TEXT destination_path) |> ignore;
        match step stmt with
        | Rc.DONE -> Ok ()
        | err -> Error (Rc.to_string err))
    | None -> Error "Database not initialized"

  let get_last_operation () =
    match !db with
    | Some db -> (
        let sql = "SELECT * FROM operations ORDER BY id DESC LIMIT 1;" in
        let stmt = prepare db sql in
        match step stmt with
        | Rc.ROW ->
            Some
              {
                id = column stmt 0 |> Data.to_int_exn;
                operation_type = column stmt 1 |> Data.to_string_exn;
                source_path = column stmt 2 |> Data.to_string_exn;
                destination_path = column stmt 3 |> Data.to_string_exn;
                timestamp = column stmt 4 |> Data.to_string_exn;
              }
        | _ -> None)
    | None -> None

  let get_operations_by_type operation_type =
    match !db with
    | Some db ->
        let sql =
          "SELECT * FROM operations WHERE operation_type = ? ORDER BY id DESC;"
        in
        let stmt = prepare db sql in
        bind stmt 1 (Data.TEXT operation_type) |> ignore;
        let rec loop acc =
          match step stmt with
          | Rc.ROW ->
              let op =
                {
                  id = column stmt 0 |> Data.to_int_exn;
                  operation_type = column stmt 1 |> Data.to_string_exn;
                  source_path = column stmt 2 |> Data.to_string_exn;
                  destination_path = column stmt 3 |> Data.to_string_exn;
                  timestamp = column stmt 4 |> Data.to_string_exn;
                }
              in
              loop (op :: acc)
          | _ -> List.rev acc
        in
        loop []
    | None -> []
end

let path_to_string x = Option.value (Eio.Path.native x) ~default:"Unknown path"

module Rand = struct
  let rand_bits ~secure_random ~length =
    let buf = Cstruct.create length in
    Eio.Flow.read_exact secure_random buf;
    buf

  (* Helper function to generate a random suffix for file paths *)
  let generate_random_suffix ~secure_random ~length =
    let buf = rand_bits ~secure_random ~length in
    Cstruct.to_hex_string buf

  let make_id_generator ~secure_random () =
    generate_random_suffix ~secure_random ~length:16
end

module DdfConfig = struct
  type t = { history_dir : string } [@@deriving serialize, deserialize]

  let make ~history_dir = { history_dir }
  let from_string_storage x = Serde_json.of_string deserialize_t x
  let pp x = Serde_json.to_string serialize_t x
end

module HistoryStack = struct
  type 'a stack = Empty | Item of 'a * 'a stack

  let empty = Empty
  let push x s = Item (x, s)
  let peek = function Empty -> None | Item (v, _) -> Some v
  let pop = function Empty -> None | Item (_, s) -> Some s
end

module Undo = struct
  (* Represents a successfully moved item *)
  type moved_item = { source_path : string; ddf_dest_path : string }
  [@@deriving serialize, deserialize]

  (* Stack of moved items *)
  type t = moved_item HistoryStack.stack

  (* Separate storage state for serialization. Serde either does not handle recursive variants or i cannot set it up properly *)
  type storage = { history : moved_item list }
  [@@deriving serialize, deserialize]

  (* Transform storage into a history stack *)
  let of_storage (s : storage) : t =
    let rec aux acc curr = match curr with [] -> acc | xs -> aux acc xs in
    aux HistoryStack.empty s.history

  let to_storage (x : t) : storage =
    let rec aux acc curr =
      match curr with HistoryStack.Empty -> acc | Item (_, xs) -> aux acc xs
    in
    let history = aux [] x in

    { history }

  let serialize t = Serde_json.to_string serialize_storage t
  let deserialize s = Serde_json.of_string deserialize_storage s
  let make () : t = HistoryStack.empty
  let make_from_storage = deserialize

  (* Save to storage *)
  let save dest (s : storage) =
    let () = Eio.traceln "would be save" in
    serialize s
    |> Result.map (fun state_string ->
           Eio.Path.save ~create:(`Exclusive 0o600) dest state_string)

  let load src =
    let () = Eio.traceln "loading storage" in
    let raw_src = Eio.Path.load src in
    let () = print_endline ("raw source: " ^ raw_src) in
    raw_src |> make_from_storage

  let push = HistoryStack.push
  let pop = HistoryStack.pop
end

let safe_remove ~src ~dest =
  let open Undo in
  match Eio.Path.rename src dest with
  | () ->
      Ok
        {
          source_path = path_to_string src;
          ddf_dest_path = path_to_string dest;
        }
  | exception Sys_error re -> Error re

let is_confirm_line line =
  match line |> String.trim |> String.lowercase_ascii with
  | "y" -> true
  | _ -> false

let prompt_bool ~stdin file =
  let buf = Eio.Buf_read.of_flow stdin ~initial_size:2 ~max_size:10 in
  let () = print_endline file in
  let () = print_endline "Should this be removed? [y/n]" in
  let gather_input () = buf |> Eio.Buf_read.line |> is_confirm_line in
  try gather_input () with Eio.Buf_read.Buffer_limit_exceeded -> false

type ddf_env_deps = {
  ddf_cfg : DdfConfig.t;
  db_path : Eio.Fs.dir_ty Eio.Path.t;
  graveyard_dir : Eio.Fs.dir_ty Eio.Path.t;
}

let init_dirs dirs =
  List.iter (fun x -> Eio.Path.mkdirs ~exists_ok:true ~perm:0o700 x) dirs

let setup_ddf ~fs ~app_name =
  let ( / ) = Eio.Path.( / ) in
  let paths = Env_paths.create ~fs app_name in
  let ddf_config_settings = paths.config / "settings.json" in
  let db_path = paths.data / (app_name ^ ".db") in
  let graveyard_dir = paths.temp / (app_name ^ "-graveyard") in
  let () = init_dirs [ paths.config; graveyard_dir; paths.data ] in
  let () = Storage.init ~db_file:(path_to_string db_path) |> Result.get_ok in
  let ddf_cfg =
    Eio.Path.load ddf_config_settings
    |> DdfConfig.from_string_storage
    |> Result.value ~default:(DdfConfig.make ~history_dir:"FALLBACK")
  in

  { ddf_cfg; db_path; graveyard_dir }

type 'a movable_item = { source_name : string; dest_path : 'a Eio.Path.t }

let make_movable ~tmp_dir ~cwd rand_bits source_name =
  let ( / ) = Eio.Path.( / ) in
  let dest_name = Filename.basename source_name ^ "_" ^ rand_bits () in
  let source_name = path_to_string (cwd / source_name) in
  { dest_path = tmp_dir / dest_name; source_name }

let to_moved_item mi : Undo.moved_item =
  let source_path = mi.source_name in
  let ddf_dest_path = path_to_string mi.dest_path in
  { source_path; ddf_dest_path }

type prompt = Always | Never

let run_ddf ~(fs : Eio.Fs.dir_ty Eio.Path.t) ~secure_random ~cwd ~stdin
    ~app_name prompt items =
  let ( / ) = Eio.Path.( / ) in
  let gen_id_suffix = Rand.make_id_generator ~secure_random in
  let ddf_env = setup_ddf ~fs ~app_name in
  let map_item =
    make_movable ~tmp_dir:ddf_env.graveyard_dir ~cwd gen_id_suffix
  in
  let resources = items |> List.map map_item in
  let run_moves =
    List.map (fun entry ->
        safe_remove ~src:(fs / entry.source_name) ~dest:entry.dest_path)
  in
  match prompt with
  | Never -> run_moves resources |> ignore
  | Always ->
      let _ret =
        resources
        |> List.map (fun res ->
               match prompt_bool ~stdin res.source_name with
               | true ->
                   let _x = 0 in
                   run_moves [ res ] |> ignore
               | false -> print_endline "Skipping...")
      in
      ()

let rand_init = function
  | Some seed -> Random.init seed
  | None -> Random.self_init ()

let rand_bits () = Random.bits () |> Int.to_string

let get_os_tmpdir fs =
  let ( / ) = Eio.Path.( / ) in
  let td = Filename.get_temp_dir_name () in
  fs / td

let safe_remove ~src ~dest =
  match Eio.Path.rename src dest with
  | () -> Ok ()
  | exception Sys_error _ -> Error "unable to move"

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

let setup_ddf ~fs =
  let ( / ) = Eio.Path.( / ) in
  let tmp_dir = get_os_tmpdir fs / "ddf" in
  let () = rand_init None in
  let () = Eio.Path.mkdirs ~exists_ok:true ~perm:0o700 tmp_dir in
  tmp_dir

type 'a movable_item = { source_name : string; dest_path : 'a Eio.Path.t }

let make_movable ~tmp_dir rand_bits source_name =
  let ( / ) = Eio.Path.( / ) in
  let dest_name = source_name ^ "_" ^ rand_bits () in
  {
    dest_path = tmp_dir / dest_name;
    source_name = Filename.basename source_name;
  }

type prompt = Always | Never

let run_ddf env prompt items =
  let ( / ) = Eio.Path.( / ) in
  let cwd = Eio.Stdenv.cwd env in
  let tmp_dir = setup_ddf ~fs:env#fs in
  let map_item = make_movable ~tmp_dir rand_bits in
  let resources = items |> List.map map_item in
  let run_moves =
    List.map (fun entry ->
        safe_remove ~src:(cwd / entry.source_name) ~dest:entry.dest_path)
  in
  match prompt with
  | Never -> run_moves resources |> ignore
  | Always ->
      resources
      |> List.iter (fun res ->
             match prompt_bool ~stdin:env#stdin res.source_name with
             | true -> run_moves [ res ] |> ignore
             | false -> print_endline "Skipping...")
      |> ignore

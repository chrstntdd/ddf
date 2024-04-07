(* Level of care. By default, check if matched files should be deleted. yolo care skips this check and immediately operates on the args *)
type care = Safe | Yolo

let make_care = function true -> Yolo | _ -> Safe

type 'a movable_item = {
  source_name : string;
  dest_name : string;
  dest_path : 'a Eio.Path.t;
}

let ( / ) = Eio.Path.( / )

let run_main env =
  (* Lazily init randomness once we know that the user needs it (after prompting) *)
  let () = Mv_rmrf.Fs.rand_init (Some 1) in
  let tmp_dir = Mv_rmrf.Fs.get_os_tmpdir env#fs / "mvrmrf" in
  let () = Eio.Path.mkdirs ~exists_ok:true ~perm:0o700 tmp_dir in
  let cwd = Eio.Stdenv.cwd env in

  (* TODO: Connect with CLI parser to get list of files/dirs *)
  let items =
    [
      (* "./file.ts"; *)
      (* "./node_modules"; *)
      (* "./dist/server"; *)
      (* "./some/deep/file/name.ml"; *)
      "something.json";
    ]
  in
  let items =
    items
    |> List.map (fun source_name ->
           let dest_name = source_name ^ "_" ^ Mv_rmrf.Fs.rand_bits () in
           {
             dest_name;
             dest_path = tmp_dir / dest_name;
             source_name = Filename.basename source_name;
           })
  in
  let rm =
    List.map (fun entry ->
        Mv_rmrf.Fs.safe_remove ~src:(cwd / entry.source_name)
          ~dest:entry.dest_path
        |> Result.get_ok)
  in
  (* Default behavior, safe, do not modify the file system *)
  let care = make_care false in
  match care with
  | Safe ->
      items
      |> List.iter (fun entry ->
             print_endline (entry.dest_path |> Eio.Path.native_exn))
  | Yolo ->
      rm items |> ignore;
      ()

let () = Eio_main.run @@ run_main

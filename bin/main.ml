type prompt = Always | Never
type 'a movable_item = { source_name : string; dest_path : 'a Eio.Path.t }

let bool_prompt ~stdin file =
  let buf = Eio.Buf_read.of_flow stdin ~initial_size:100 ~max_size:1_000_000 in
  let () = print_endline file in
  let () = print_endline "Should this be removed? [y/n]" in
  let rl () =
    let line = Eio.Buf_read.line buf in
    match line with "y" | "Y" -> true | _ -> false
  in
  rl ()

let run_mv_rmrf env prompt items =
  let ( / ) = Eio.Path.( / ) in
  let cwd = Eio.Stdenv.cwd env in
  let tmp_dir = Mv_rmrf.Fs.get_os_tmpdir env#fs / "mv_rmrf" in
  let () = Mv_rmrf.Fs.rand_init None in
  let () = Eio.Path.mkdirs ~exists_ok:true ~perm:0o700 tmp_dir in
  let resources =
    items
    |> List.map (fun source_name ->
           let dest_name = source_name ^ "_" ^ Mv_rmrf.Fs.rand_bits () in
           {
             dest_path = tmp_dir / dest_name;
             source_name = Filename.basename source_name;
           })
  in
  let run_moves =
    List.map (fun entry ->
        Mv_rmrf.Fs.safe_remove ~src:(cwd / entry.source_name)
          ~dest:entry.dest_path
        |> Result.get_ok)
  in
  match prompt with
  | Never ->
      run_moves resources |> ignore;
      ()
  | Always ->
      resources
      |> List.iter (fun res ->
             match bool_prompt ~stdin:env#stdin res.source_name with
             | true -> run_moves [ res ] |> ignore
             | false -> print_endline "Skipping...")
      |> ignore

let run_cli env =
  let open Cmdliner in
  let runnit = run_mv_rmrf env in
  let files = Arg.(non_empty & pos_all file [] & info [] ~docv:"FILE") in

  let prompt =
    let always =
      let doc = "Prompt before every operation." in
      (Always, Arg.info [ "i" ] ~doc)
    in
    let never =
      let doc = "Ignore nonexistent files and never prompt." in
      (Never, Arg.info [ "y"; "yolo" ] ~doc)
    in
    Arg.(last & vflag_all [ Always ] [ always; never ])
  in

  let cmd =
    let doc = "Remove files or directories" in
    let man =
      [
        `S Manpage.s_description;
        `P
          "$(tname) removes each specified $(i,FILE) by moving it to the \
           os_tmpdir.";
        `P
          "To remove a file whose name starts with a $(b,-), for example\n\
          \        $(b,-foo), use one of these commands:";
        `Pre "$(mname) $(b,-- -foo)";
        `Noblank;
        `Pre "$(mname) $(b,./-foo)";
        `S Manpage.s_bugs;
        `P "Report bugs to mv_rmrf_bugs.nineteen384@passmail.net.";
        `S Manpage.s_see_also;
        `P "$(b,rmdir)(1), $(b,unlink)(2)";
      ]
    in
    let info = Cmd.info "mv_rmrf " ~version:"0.0.0" ~doc ~man in
    Cmd.v info Term.(const runnit $ prompt $ files)
  in

  exit (Cmd.eval cmd)

let () = Eio_main.run @@ run_cli

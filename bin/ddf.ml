module MainCmd = struct
  open Cmdliner

  let contact_email = "ddf.helpful326@passfwd.com"

  let exec_purge_stub all older_than =
    (* Stub implementation *)
    Printf.printf "Purge command invoked with:\n";
    Printf.printf "  All: %b\n" all;
    (match older_than with
    | Some time -> Printf.printf "  Older than: %s\n" time
    | None -> Printf.printf "  Older than: not specified\n");
    () (* Return a success code *)

  (* PURGE Command *)
  let purge_cmd exec_purge =
    let all =
      let doc = "Purge all files in the graveyard." in
      Arg.(value & flag & info [ "all" ] ~doc)
    in
    let older_than =
      let doc =
        "Purge files older than a specific time (e.g., `7d` for 7 days)."
      in
      Arg.(
        value & opt (some string) None & info [ "older-than" ] ~docv:"TIME" ~doc)
    in
    let doc =
      "Permanently deletes files from the graveyard, bypassing the OS cleanup."
    in
    let info = Cmd.info "purge" ~doc in
    Cmd.v info Term.(const exec_purge $ all $ older_than)

  (* DELETE Command *)
  let delete_term run_ddf =
    let files = Arg.(non_empty & pos_all file [] & info [] ~docv:"FILE/DIR") in

    let prompt =
      let always =
        let doc = "Prompt before every operation." in
        (Lib.Always, Arg.info [ "i" ] ~doc)
      in
      let never =
        let doc = "Ignore nonexistent files and never prompt." in
        (Lib.Never, Arg.info [ "y"; "yolo" ] ~doc)
      in
      Arg.(last & vflag_all [ Lib.Always ] [ always; never ])
    in
    Term.(const run_ddf $ prompt $ files)

  let delete_cmd run_ddf ddf_dir =
    let man =
      [
        `S Manpage.s_description;
        `P
          "$(tname) discards each specified $(i,FILE/DIR) by moving it to a \
           directory in `\\$TMPDIR`, listed below.";
        `P ("Discarded $(i,FILE/DIR)s are moved to this directory: " ^ ddf_dir);
        `P
          "To discard a $(i,FILE/DIR) whose name starts with a $(b,-), for \
           example\n\
          \        $(b,-foo), use one of these commands:";
        `Pre "$(mname) $(b,-- -foo)";
        `Noblank;
        `Pre "$(mname) $(b,./-foo)";
      ]
    in
    let info = Cmd.info "delete" ~man in
    Cmd.v info (delete_term run_ddf)

  let run_cli run_ddf ddf_dir =
    let default_term = delete_term run_ddf in
    let cmds = [ delete_cmd run_ddf ddf_dir; purge_cmd exec_purge_stub ] in

    let cmd =
      let doc =
        {|
[d]iscard [d]irectories [f]ast.
Like `rm -rf` using `mv` to `\$TMPDIR` for zippier execution
        |}
      in
      let man =
        [
          `S Manpage.s_bugs;
          `P ("Report bugs to " ^ contact_email);
          `S Manpage.s_see_also;
          `P "$(b,rmdir)(1), $(b,unlink)(2)";
        ]
      in
      let info = Cmd.info "ddf" ~version:"0.0.2-rc0" ~doc ~man in
      Cmd.group ~default:default_term info cmds
    in
    cmd
end

let run_cli env =
  let cmd_name = "ddf" in
  let paths = Lib.Env_paths.create ~fs:env#fs cmd_name in
  let run_ddf =
    Lib.run_ddf ~fs:env#fs ~stdin:env#stdin ~cwd:(Eio.Stdenv.cwd env)
  in
  let ddf_dir = Eio.Path.native_exn paths.temp in
  let main_cmd = MainCmd.run_cli run_ddf ddf_dir in
  let gen_id_suffix =
    Lib.Rand.make_id_generator ~secure_random:env#secure_random
  in

  print_endline ("id: " ^ gen_id_suffix ());

  exit (Cmdliner.Cmd.eval main_cmd)

let () = Eio_main.run @@ run_cli

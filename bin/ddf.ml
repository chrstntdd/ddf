module MainCmd = struct
  let run_cli run_ddf ddf_dir =
    let open Cmdliner in
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

    let cmd =
      let doc =
        "`mv`s directories and files to `\\$TMPDIR` for quick cleanup"
      in
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
          `S Manpage.s_bugs;
          `P "Report bugs to ddf.helpful326@passfwd.com";
          `S Manpage.s_see_also;
          `P "$(b,rmdir)(1), $(b,unlink)(2)";
        ]
      in
      let info = Cmd.info "ddf" ~version:"0.0.1" ~doc ~man in
      Cmd.v info Term.(const run_ddf $ prompt $ files)
    in
    cmd
end

let run_cli env =
  let run_ddf = Lib.run_ddf env in
  let ddf_dir =
    Option.value ~default:"Unknown os_tmpdir"
      (Eio.Path.native (Lib.get_ddf_dir ~fs:env#fs))
  in
  let main_cmd = MainCmd.run_cli run_ddf ddf_dir in
  exit (Cmdliner.Cmd.eval main_cmd)

let () = Eio_main.run @@ run_cli

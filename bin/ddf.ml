let run_cli env =
  let open Cmdliner in
  let run_ddf = Lib.run_ddf env in
  let files = Arg.(non_empty & pos_all file [] & info [] ~docv:"FILE") in

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
        `P "Report bugs to ddf.helpful326@passfwd.com";
        `S Manpage.s_see_also;
        `P "$(b,rmdir)(1), $(b,unlink)(2)";
      ]
    in
    let info = Cmd.info "ddf" ~version:"0.0.1" ~doc ~man in
    Cmd.v info Term.(const run_ddf $ prompt $ files)
  in

  exit (Cmd.eval cmd)

let () = Eio_main.run @@ run_cli

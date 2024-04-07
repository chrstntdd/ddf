let run_main _env =
  let text = Mv_rmrf.Fs.i "Hello, Worldl!" in

  Eio.traceln "oi";
  print_endline text;

  ()

let () = Eio_main.run @@ run_main

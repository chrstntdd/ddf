let rand_init = function
  | Some seed -> Random.init seed
  | None -> Random.self_init ()

let rand_bits () = Random.bits () |> Int.to_string
let ( / ) = Eio.Path.( / )

let get_os_tmpdir fs =
  let td = Filename.get_temp_dir_name () in
  fs / td

let safe_remove ~src ~dest =
  match Eio.Path.rename src dest with
  | () -> Ok ()
  | exception Sys_error _ -> Error "unable to move"

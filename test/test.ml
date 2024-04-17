let ( / ) = Eio.Path.( / )

let test_confirm_input_exact () =
  Alcotest.(check bool) "y is confirmation input" true (Lib.is_confirm_line "y")

let test_confirm_input_case_insensitive () =
  Alcotest.(check bool) "Y is confirmation input" true (Lib.is_confirm_line "Y")

let test_not_confirm_input _cwd () =
  Alcotest.(check bool) "not y/Y considered deny" false (Lib.is_confirm_line "")

let test_overflow_input () =
  Alcotest.(check bool)
    "Large input interpreted as deny" false
    (Lib.is_confirm_line (String.make 100 'x'))

let test_movable_item cwd () =
  let tmp_dir = cwd / "test-tmp" in
  let source_name = "test-item" in
  let mock_bits = "rand-bits-1234" in
  let expected_dest_name = source_name ^ "_" ^ mock_bits in
  let expected_movable_item =
    {
      Lib.dest_path = tmp_dir / expected_dest_name;
      Lib.source_name = Filename.basename source_name;
    }
  in
  let actual_movable_item =
    Lib.make_movable ~tmp_dir (fun _ -> mock_bits) source_name
  in
  let eq a b =
    a.Lib.dest_path |> Eio.Path.native_exn
    = (b.Lib.dest_path |> Eio.Path.native_exn)
    && a.Lib.source_name = b.Lib.source_name
  in
  let pp ppf item =
    Fmt.pf ppf "{ source_name = %s; dest_path = %s }" item.Lib.source_name
      (item.Lib.dest_path |> Eio.Path.native_exn)
  in
  let module MovableItemTestable = struct
    type t = Eio.Fs.dir_ty Lib.movable_item

    let equal = eq
    let pp = pp
  end in
  let testable =
    (module MovableItemTestable : Alcotest.TESTABLE
      with type t = MovableItemTestable.t)
  in

  Alcotest.check testable "movable item record" expected_movable_item
    actual_movable_item

let run_unit_tests env =
  let cwd = Eio.Stdenv.cwd env in
  Alcotest.run "Lib"
    [
      ( "y is confirmation",
        [
          Alcotest.test_case "Input confirmation" `Quick
            test_confirm_input_exact;
        ] );
      ( "Y is also confirmation (case-insensitive)",
        [
          Alcotest.test_case "Input confirmation" `Quick
            test_confirm_input_case_insensitive;
        ] );
      ( "non-y/Y is deny of confirmation prompt",
        [
          Alcotest.test_case "Input confirmation" `Quick
            (test_not_confirm_input cwd);
        ] );
      ( "Large input interpreted as deny",
        [ Alcotest.test_case "Input confirmation" `Quick test_overflow_input ]
      );
      ( "movable_item defines a record of source name and destination path ",
        [
          Alcotest.test_case "movable item creation" `Quick
            (test_movable_item cwd);
        ] );
    ]

let () = Eio_main.run @@ run_unit_tests

let test_confirm_input_exact () =
  Alcotest.(check bool) "y is confirmation input" true (Lib.is_confirm_line "y")

let test_confirm_input_case_insensitive () =
  Alcotest.(check bool) "Y is confirmation input" true (Lib.is_confirm_line "Y")

let test_not_confirm_input () =
  Alcotest.(check bool) "not y/Y considered deny" false (Lib.is_confirm_line "")

let () =
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
          Alcotest.test_case "Input confirmation" `Quick test_not_confirm_input;
        ] );
    ]

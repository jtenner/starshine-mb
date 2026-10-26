// F06 from hunt/daybreak-starshine-r1 at
// 49b757b94b4dfd1a11394aa11081777ddf686b90.
// Split the original loop so both invalid literals run independently.

///|
fn daybreak_expect_i32_literal_rejected(literal : String) -> Unit raise {
  match
    wast_to_binary_module("(module (func (result i32) i32.const \{literal}))") {
    Err(_) => ()
    Ok(lowered) =>
      match lowered.code_sec {
        Some(
          @lib.CodeSec(
            [@lib.Func(_, @lib.Expr([@lib.I32Const(@lib.I32(value))]))]
          )
        ) =>
          fail(
            "expected rejection of \{literal}; lowered to i32.const \{value}",
          )
        _ => fail("expected rejection of \{literal}; lowering succeeded")
      }
  }
}

///|
test "scalar i32 constants reject 4294967296 above the bit-pattern range" {
  daybreak_expect_i32_literal_rejected("4294967296")
}

///|
test "scalar i32 constants reject -2147483649 below the bit-pattern range" {
  daybreak_expect_i32_literal_rejected("-2147483649")
}

///|
test "scalar i32 constants accept the signed and unsigned bit-pattern boundaries" {
  for
    (literal, expected) in [
      ("-2147483648", -2147483648),
      ("2147483647", 2147483647),
      ("4294967295", -1),
    ] {
    let lowered = match
      wast_to_binary_module("(module (func (result i32) i32.const \{literal}))") {
      Ok(module_) => module_
      Err(error) => fail("expected acceptance of \{literal}: \{error}")
    }
    match lowered.code_sec {
      Some(
        @lib.CodeSec(
          [@lib.Func(_, @lib.Expr([@lib.I32Const(@lib.I32(value))]))]
        )
      ) => @debug.assert_eq(value, expected)
      _ => fail("expected one scalar i32 constant for \{literal}")
    }
  }
}

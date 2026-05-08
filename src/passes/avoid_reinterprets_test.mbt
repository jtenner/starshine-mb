///|
fn ar_test_run(text : String) -> @lib.Module {
  match pass_test_run_pipeline(text, ["avoid-reinterprets"]) {
    Ok(mod_) => mod_
    Err(err) =>
      abort("expected avoid-reinterprets pipeline success, got \{err}")
  }
}

///|
fn ar_test_first_body(mod_ : @lib.Module) -> Array[@lib.Instruction] {
  match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body)), ..])) => body
    _ => abort("expected at least one function body")
  }
}

///|
test "avoid-reinterprets rewrites f32 load followed by i32 reinterpret" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (param i32) (result i32)
    #|     local.get 0
    #|     f32.load
    #|     i32.reinterpret_f32))
  let optimized = ar_test_run(input)

  match ar_test_first_body(optimized) {
    [@lib.LocalGet(_), @lib.I32Load(_)] => ()
    other => fail("expected local.get + i32.load, got \{other}")
  }
}

///|
test "avoid-reinterprets rewrites all full-width load reinterpret pairs" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (param i32) (result f32)
    #|     local.get 0
    #|     i32.load
    #|     f32.reinterpret_i32)
    #|   (func (param i32) (result f64)
    #|     local.get 0
    #|     i64.load
    #|     f64.reinterpret_i64)
    #|   (func (param i32) (result i64)
    #|     local.get 0
    #|     f64.load
    #|     i64.reinterpret_f64))
  let optimized = ar_test_run(input)

  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(_, @lib.Expr([@lib.LocalGet(_), @lib.F32Load(_)])),
          @lib.Func(_, @lib.Expr([@lib.LocalGet(_), @lib.F64Load(_)])),
          @lib.Func(_, @lib.Expr([@lib.LocalGet(_), @lib.I64Load(_)])),
        ]
      )
    ) => ()
    other =>
      fail(
        "expected rewritten load-only functions, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "avoid-reinterprets preserves partial-load reinterpret operations" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (param i32) (result f32)
    #|     local.get 0
    #|     i32.load16_u
    #|     f32.reinterpret_i32))
  let optimized = ar_test_run(input)

  match ar_test_first_body(optimized) {
    [@lib.LocalGet(_), @lib.I32Load16U(_), @lib.F32ReinterpretI32] => ()
    other =>
      fail("expected partial-load reinterpret to stay unchanged, got \{other}")
  }
}

///|
test "avoid-reinterprets preserves non-load reinterpret operations" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     f32.const 1
    #|     i32.reinterpret_f32))
  let optimized = ar_test_run(input)

  match ar_test_first_body(optimized) {
    [@lib.F32Const(_), @lib.I32ReinterpretF32] => ()
    other => fail("expected const reinterpret to stay unchanged, got \{other}")
  }
}

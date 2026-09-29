///|
fn sgo_full_pipeline_bench(
  it : @bench.T,
  globals : Int,
  functions : Int,
  candidate : Bool,
) -> Unit {
  let wat : Array[String] = ["(module"]
  for index in 0..<globals {
    wat.push("(global i32 (i32.const \{index + 7}))")
  }
  for _ in 0..<functions {
    wat.push("(func (result i32) ")
    if candidate {
      wat.push(
        "i32.const 1 if (result i32) i32.const 3 else i32.const 4 end drop ",
      )
    }
    wat.push("global.get 0)")
  }
  wat.push(")")
  let input = pass_test_module_from_wat(wat.join(""))
  let options = HotPipelineOptions::new(validate_final_module=false)
  let output = run_hot_pipeline(input, options, ["simplify-globals-optimizing"]).unwrap()
  @validate.validate_module(output).unwrap()
  for func in output.code_sec.unwrap().0 {
    let @lib.Func(_, @lib.Expr(body)) = func
    if body != [@lib.Instruction::i32_const(@lib.I32(7))] {
      abort("SGO full pipeline lost constant-global or dropped-if cleanup")
    }
  }
  it.bench(fn() {
    it.keep(run_hot_pipeline(input, options, ["simplify-globals-optimizing"]))
  })
}

///|
test "bench SGO full pipeline globals=1 functions=1 constant-global" (
  it : @bench.T,
) {
  sgo_full_pipeline_bench(it, 1, 1, false)
}

///|
test "bench SGO full pipeline globals=1 functions=1 dropped-if" (it : @bench.T) {
  sgo_full_pipeline_bench(it, 1, 1, true)
}

///|
test "bench SGO full pipeline globals=128 functions=4 constant-global" (
  it : @bench.T,
) {
  sgo_full_pipeline_bench(it, 128, 4, false)
}

///|
test "bench SGO full pipeline globals=128 functions=4 dropped-if" (
  it : @bench.T,
) {
  sgo_full_pipeline_bench(it, 128, 4, true)
}

///|
test "bench SGO full pipeline globals=16 functions=128 constant-global" (
  it : @bench.T,
) {
  sgo_full_pipeline_bench(it, 16, 128, false)
}

///|
test "bench SGO full pipeline globals=16 functions=128 dropped-if" (
  it : @bench.T,
) {
  sgo_full_pipeline_bench(it, 16, 128, true)
}

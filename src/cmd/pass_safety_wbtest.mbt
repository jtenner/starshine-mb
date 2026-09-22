///|
test "command precompute preserves aliased SIMD select" {
  let output = cmd_deep_audit_run(
    "(module (func (result v128) (local v128 v128) v128.const i32x4 0 0 0 0 local.set 0 v128.const i32x4 1 1 1 1 local.set 0 local.get 0 local.get 0 f32x4.eq local.set 1 local.get 0 local.get 0 local.get 1 v128.bitselect))",
    "precompute",
  )
  assert_true(
    cmd_deep_audit_body(output).contains(@lib.Instruction::v128_bitselect()),
  )
}

///|
test "command local cse retains two shared memory loads" {
  let output = cmd_deep_audit_run(
    "(module (memory 1 1 shared) (func (param i32) (result i32) local.get 0 i32.load local.get 0 i32.load i32.sub))",
    "local-cse",
  )
  @debug.assert_eq(
    cmd_deep_audit_count(cmd_deep_audit_body(output), fn(i) {
      i is @lib.I32Load(_)
    }),
    2,
  )
}

///|
test "command RUME retains wrapping memory64 active data trap" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([
        @lib.MemType::new(@lib.Limits::i64(281474976710655UL, None)),
      ]),
    )
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i64_const(@lib.I64(-65536L))]),
          ),
          Bytes::new(65537),
        ),
      ]),
    )
  let output = cmd_deep_audit_run_module(
    input, "remove-unused-nonfunction-module-elements",
  )
  match output.data_sec {
    Some(@lib.DataSec(datas)) => @debug.assert_eq(datas.length(), 1)
    None => fail("expected active data trap to remain after command dispatch")
  }
}

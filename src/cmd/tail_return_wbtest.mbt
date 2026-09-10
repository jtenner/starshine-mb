///|
test "CLI O4s preserves returns that unwind ambient stack values" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (export \"main\") (param i32 i64) (result i32) local.get 0 local.get 1 i32.const 42 return))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32(42)),
          @lib.Instruction::return_(),
        ]),
      ),
    ]),
  )
  let normalized = cmd_strip_terminal_returns_for_encoding(input)
  @debug.assert_eq(normalized.code_sec, input.code_sec)
  let wasm = encode_module_bytes(input)
  let writes : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "input.wasm" },
    read_file=fn(_) { Ok(wasm) },
    write_file=fn(_, bytes) {
      writes.push(bytes)
      Ok(())
    },
  )
  let _ = run_cmd_with_adapter(
    [
      "--optimize-level", "4", "--shrink-level", "1", "--optimize", "input.wasm",
      "-o", "out.wasm",
    ],
    io,
  ).unwrap()
  @debug.assert_eq(writes.length(), 1)
  @validate.validate_module(decode_module_bytes(writes[0])).unwrap()
}

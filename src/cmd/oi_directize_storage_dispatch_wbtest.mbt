///|
test "OI directization preserves effectful prefixes through active dispatch" {
  let input = @wast.wast_to_binary_module(
    "(module (type $t (func (param i32) (result i32))) (import \"host\" \"f\" (func (type $t))) (global (export \"state\") (mut i32) (i32.const 0)) (func $target (type $t) local.get 0 call 0) (elem declare func $target) (func (export \"run\") (param i32) (result i32) i32.const 17 global.set 0 block (result i32) local.get 0 ref.func $target call_ref $t end))",
  ).unwrap()
  let bytes = @binary.encode_module(input).unwrap()
  for pass in ["optimize-instructions"] {
    let writes : Array[Bytes] = []
    let io = CmdIO::new(
      list_candidates=fn() { ["input.wasm"] },
      file_exists=fn(path) { path == "input.wasm" },
      read_file=fn(path) {
        if path == "input.wasm" {
          Ok(bytes)
        } else {
          Err("missing fixture")
        }
      },
      write_file=fn(_, data) {
        writes.push(data)
        Ok(())
      },
    )
    let summary = run_cmd_with_adapter(
      ["--\{pass}", "--out", "out.wasm", "input.wasm"],
      io,
    ).unwrap()
    assert_eq(summary.output_files, ["out.wasm"])
    assert_eq(writes.length(), 1)
    let output = @binary.decode_module(writes[0]).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) { instr is @lib.CallRef(_) }),
      0,
    )
    assert_true(
      cmd_deep_audit_count(body, fn(instr) { instr is @lib.Call(_) }) > 0,
    )
    assert_eq(@binary.encode_module(input).unwrap(), bytes)
  }
}

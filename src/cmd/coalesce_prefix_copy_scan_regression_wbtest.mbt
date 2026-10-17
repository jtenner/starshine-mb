///|
test "coalesce command keeps loop-prefix source snapshots across later writes" {
  for mutable_source in [false, true] {
    let overwrite = if mutable_source { "i32.const 9 local.set 0" } else { "" }
    let input = @passes.pass_test_module_from_wat(
      "(module (func (export \"run\") (param i32) (result i32) (local i32 i32) " +
      "local.get 0 local.set 1 local.get 0 local.set 2 loop end " +
      overwrite +
      " local.get 1 local.get 2 i32.add))",
    )
    let bytes = encode_module_bytes(input)
    let writes : Array[Bytes] = []
    let io = CmdIO::new(
      list_candidates=fn() { ["prefix.wasm"] },
      file_exists=fn(path) { path == "prefix.wasm" },
      read_file=fn(_) { Ok(bytes) },
      write_file=fn(_, output) {
        writes.push(output)
        Ok(())
      },
    )
    let summary = run_cmd_with_adapter(
      ["--coalesce-locals", "prefix.wasm", "-o", "out.wasm"],
      io,
    ).unwrap()
    assert_eq(summary.resolved_passes, ["coalesce-locals"])
    assert_eq(writes.length(), 1)
    let output = decode_module_bytes(writes[0])
    @validate.validate_module(output).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    let source_write_retained = body.any(fn(instr) {
      instr is @lib.LocalSet(@lib.LocalIdx(0U)) ||
      instr is @lib.LocalTee(@lib.LocalIdx(0U))
    })
    if mutable_source && source_write_retained {
      // The copied old parameter must not become a read of the later 9.
      assert_true(locals.length() > 0)
      assert_true(
        body.any(fn(instr) { instr is @lib.LocalGet(@lib.LocalIdx(1U)) }),
      )
    } else {
      // Cleanup can retire the unread source overwrite. The saved old value
      // can then use the unchanged parameter without a snapshot local.
      assert_eq(locals.length(), 0)
      assert_eq(
        body[body.length() - 3],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
      assert_eq(
        body[body.length() - 2],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
      assert_eq(body[body.length() - 1], @lib.Instruction::i32_add())
    }
    assert_eq(encode_module_bytes(input), bytes)
  }
}

///|
test "DAE command keeps host sink calls and public forwarder arguments" {
  for pass_name in ["dae", "dae-optimizing"] {
    for public_sink in [false, true] {
      let exported = if public_sink { "(export \"forward\")" } else { "" }
      let input = @passes.pass_test_module_from_wat(
        "(module (import \"host\" \"sink\" (func $sink (param i32))) " +
        "(func $forward " +
        exported +
        " (param i32) local.get 0 call $sink) " +
        "(func (export \"run\") i32.const 7 call $forward))",
      )
      let bytes = encode_module_bytes(input)
      let writes : Array[Bytes] = []
      let io = CmdIO::new(
        list_candidates=fn() { ["sink.wasm"] },
        file_exists=fn(path) { path == "sink.wasm" },
        read_file=fn(_) { Ok(bytes) },
        write_file=fn(_, output) {
          writes.push(output)
          Ok(())
        },
      )
      let summary = run_cmd_with_adapter(
        ["--" + pass_name, "sink.wasm", "-o", "out.wasm"],
        io,
      ).unwrap()
      assert_eq(summary.resolved_passes, [pass_name])
      assert_eq(writes.length(), 1)
      let output = decode_module_bytes(writes[0])
      ignore(@validate.validate_module(output).unwrap())
      let funcs = output.code_sec.unwrap().0
      assert_eq(funcs.length(), 2)
      let @lib.Func(_, @lib.Expr(forward)) = funcs[0]
      let @lib.Func(_, @lib.Expr(caller)) = funcs[1]
      assert_eq(forward, [
        if public_sink {
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
        } else {
          @lib.Instruction::i32_const(7)
        },
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      ])
      assert_eq(
        caller,
        if public_sink {
          [
            @lib.Instruction::i32_const(7),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          ]
        } else {
          [@lib.Instruction::call(@lib.FuncIdx::new(1U))]
        },
      )
    }
  }
}

///|
test "optimize-casts invalidates operand refinements when a call result overwrites the local" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x16\x04\x5f\x01\x7f\x00\x60\x01\x64\x00\x01\x64\x00\x60\x01\x6d\x01\x7f\x60\x01\x7f\x01\x7f\x03\x04\x03\x01\x02\x03\x07\x07\x01\x03\x72\x75\x6e\x00\x02\x0a\x35\x03\x0e\x00\x20\x00\xfb\x02\x00\x00\x41\x01\x6a\xfb\x00\x00\x0b\x0b\x00\x20\x00\xfb\x16\x00\xfb\x02\x00\x00\x0b\x18\x01\x01\x6d\x20\x00\xfb\x00\x00\x21\x01\x20\x01\xfb\x16\x00\x10\x00\x21\x01\x20\x01\x10\x01\x0b\x00\x1f\x04\x6e\x61\x6d\x65\x01\x10\x02\x00\x07\x72\x65\x70\x6c\x61\x63\x65\x01\x04\x72\x65\x61\x64\x04\x06\x01\x00\x03\x62\x6f\x78",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-casts",
  ]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
  // The last call must receive the new box, not a cached cast of the old box.
  @debug.assert_eq(
    body[body.length() - 2],
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  )
  ignore(@validate.validate_module(output).unwrap())
}

///|
test "optimize-casts preserves call order when removing a pending cast" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x1b\x05\x5f\x01\x7f\x00\x5f\x02\x64\x00\x00\x64\x00\x00\x60\x00\x01\x64\x00\x60\x00\x01\x64\x00\x60\x00\x01\x7f\x02\x01\x00\x03\x04\x03\x02\x03\x04\x07\x08\x01\x04\x6d\x61\x69\x6e\x00\x02\x0a\x34\x03\x03\x00\x00\x0b\x0a\x00\x41\x01\x41\x00\x6d\xfb\x00\x00\x0b\x23\x01\x01\x6d\x10\x00\x10\x01\x21\x00\xfb\x16\x00\x20\x00\xfb\x16\x00\xfb\x00\x01\xfb\x16\x01\xfb\x02\x01\x01\xfb\x16\x00\xfb\x02\x00\x00\x0b",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-casts",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  // Both callees trap, with distinct traps. Removing the first call's static
  // cast must keep that call before the second call and its local write.
  for module_ in [input, output] {
    let @lib.Func(_, @lib.Expr(body)) = module_.code_sec.unwrap().0[2]
    let calls : Array[UInt] = []
    for instr in body {
      match instr {
        @lib.Call(@lib.FuncIdx(index)) => calls.push(index)
        _ => ()
      }
    }
    @debug.assert_eq(calls, [0U, 1U])
  }
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
  let mut casts = 0
  for instr in body {
    match instr {
      @lib.RefCast(_) => casts += 1
      _ => ()
    }
  }
  @debug.assert_eq(casts, 1)
}

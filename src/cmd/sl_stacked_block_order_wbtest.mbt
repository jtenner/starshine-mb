///|
test "command SL modes preserve an entry read stacked before a nested overwrite" {
  let input = @wast.wast_to_binary_module(
    "(module (func (export \"run\") (param i32) (result i32) local.get 0 block i32.const 11 local.set 0 end local.get 0 i32.add))",
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for
    pass in [
      "simplify-locals", "simplify-locals-nonesting", "simplify-locals-notee", "simplify-locals-nostructure",
      "simplify-locals-notee-nostructure",
    ] {
    let output = cmd_deep_audit_run_module(input, pass)
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output, index=0).filter(fn(instr) {
      !(instr is @lib.Nop)
    })
    assert_eq(body[0], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "command SL and DAE2-O retain branch exits while lifting one-armed results" {
  let input = @wast.wast_to_binary_module(
    "(module (func (export \"run\") (param i32 i32 i32) (result i32) (local i32) i32.const 5 local.set 3 local.get 0 if local.get 0 i32.const 1 i32.and br_if 0 local.get 0 i32.const 1 i32.add local.set 3 end local.get 3 i32.const 2 i32.add))",
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for pass in ["simplify-locals", "simplify-locals-notee", "dae2-optimizing"] {
    let output = cmd_deep_audit_run_module(input, pass)
    @validate.validate_module(output).unwrap()
    let blocks = cmd_deep_audit_body(output, index=0).filter(fn(instr) {
      instr is @lib.Block(@lib.VoidBlockType, _)
    })
    assert_eq(blocks.length(), 1)
    let body = match blocks[0] {
      @lib.Block(_, @lib.Expr(body)) => body
      _ => abort("expected the branch's retained void block")
    }
    let typed_ifs = body.filter(fn(instr) {
      instr is @lib.If(@lib.ValTypeBlockType(_), _, _)
    })
    assert_eq(typed_ifs.length(), 1)
    let then_body = match typed_ifs[0] {
      @lib.If(_, body, _) => body
      _ => abort("expected a typed conditional")
    }
    assert_eq(then_body.filter(fn(instr) { instr is @lib.BrIf(_) }), [
      @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    ])
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "simplify-locals keeps writes before resume-throw handler exits" {
  for throw_ref in [false, true] {
    let form = if throw_ref { "resume_throw_ref" } else { "resume_throw" }
    let input = simplify_locals_resume_throw_handler_module(throw_ref, true)
    assert_true(
      @validate.validate_module(input) is Ok(_),
      msg="invalid input for \{form}",
    )
    let output = audit_run_module(input, "simplify-locals")
    assert_true(
      @validate.validate_module(output) is Ok(_),
      msg="invalid output for \{form}",
    )
    let outer_body = match audit_body(output)[0] {
      @lib.Block(_, @lib.Expr(body)) => body
      other => fail("\{form}: expected outer handler block, got \{other}")
    }
    let body = match outer_body[0] {
      @lib.Block(_, @lib.Expr(body)) => body
      other => fail("\{form}: expected nested void block, got \{other}")
    }
    let target_local = if throw_ref { 2U } else { 1U }
    let mut set_idx = -1
    let mut resume_idx = -1
    for idx = 0; idx < body.length(); idx = idx + 1 {
      match body[idx] {
        @lib.LocalSet(@lib.LocalIdx(local_id)) if local_id == target_local =>
          set_idx = idx
        @lib.ResumeThrow(_, _, _) | @lib.ResumeThrowRef(_, _) =>
          resume_idx = idx
        _ => ()
      }
    }
    assert_true(
      set_idx >= 0 && resume_idx >= 0 && set_idx < resume_idx,
      msg="\{form}: \{body}",
    )
  }
}

///|
test "simplify-locals keeps post-resume-throw writes path-specific" {
  for throw_ref in [false, true] {
    let form = if throw_ref { "resume_throw_ref" } else { "resume_throw" }
    let input = simplify_locals_resume_throw_handler_module(throw_ref, false)
    assert_true(
      @validate.validate_module(input) is Ok(_),
      msg="invalid input for \{form}",
    )
    let output = audit_run_module(input, "simplify-locals")
    assert_true(
      @validate.validate_module(output) is Ok(_),
      msg="invalid output for \{form}",
    )
    let body = audit_body(output)
    let target_local = if throw_ref { 2U } else { 1U }
    assert_true(
      body[body.length() - 1] is @lib.LocalGet(@lib.LocalIdx(local_id)) &&
      local_id == target_local,
      msg="\{form}: \{body}",
    )
  }
}

///|
test "coalesce-locals keeps resume-throw handler successor writes live" {
  for throw_ref in [false, true] {
    let form = if throw_ref { "resume_throw_ref" } else { "resume_throw" }
    let input = simplify_locals_resume_throw_handler_module(throw_ref, false)
    assert_true(
      @validate.validate_module(input) is Ok(_),
      msg="invalid input for \{form}",
    )
    let output = audit_run_module(input, "coalesce-locals")
    assert_true(
      @validate.validate_module(output) is Ok(_),
      msg="invalid output for \{form}",
    )
    @debug.assert_eq(
      audit_count(audit_body(output), fn(instr) { instr is @lib.LocalSet(_) }),
      2,
    )
  }
}

///|
fn simplify_locals_resume_throw_sequence(
  throw_ref : Bool,
  cont : @lib.TypeIdx,
  label : UInt,
) -> Array[@lib.Instruction] {
  let body : Array[@lib.Instruction] = []
  if throw_ref {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  }
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  let handlers = [
    @lib.ResumeHandler::on_label(
      @lib.TagIdx::new(0U),
      @lib.LabelIdx::new(label),
    ),
  ]
  if throw_ref {
    body.push(@lib.Instruction::resume_throw_ref(cont, handlers))
  } else {
    body.push(
      @lib.Instruction::resume_throw(cont, @lib.TagIdx::new(1U), handlers),
    )
  }
  body
}

///|
fn simplify_locals_resume_throw_handler_module(
  throw_ref : Bool,
  write_before : Bool,
) -> @lib.Module {
  let cont_sig = @lib.TypeIdx::new(0U)
  let cont = @lib.TypeIdx::new(1U)
  let handler_tag_sig = @lib.TypeIdx::new(2U)
  let thrown_tag_sig = @lib.TypeIdx::new(3U)
  let func_sig = @lib.TypeIdx::new(4U)
  let cont_ref = @lib.ValType::ref_null(@lib.HeapType::new(cont))
  let params = if throw_ref {
    [cont_ref, @lib.ValType::ref_null_exn()]
  } else {
    [cont_ref]
  }
  let target_local = if throw_ref { 2U } else { 1U }
  let roots : Array[@lib.Instruction] = []
  if write_before {
    let inner : Array[@lib.Instruction] = [
      @lib.Instruction::i32_const(7),
      @lib.Instruction::local_set(@lib.LocalIdx::new(target_local)),
    ]
    for instr in simplify_locals_resume_throw_sequence(throw_ref, cont, 1U) {
      inner.push(instr)
    }
    inner.push(@lib.Instruction::drop())
    roots.push(
      @lib.Instruction::block(
        @lib.BlockType::val_type(cont_ref),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new(inner),
          ),
          @lib.Instruction::local_get(@lib.LocalIdx::new(target_local)),
          @lib.Instruction::drop(),
          @lib.Instruction::ref_null(@lib.HeapType::new(cont)),
        ]),
      ),
    )
  } else {
    roots.push(@lib.Instruction::i32_const(1))
    roots.push(@lib.Instruction::local_set(@lib.LocalIdx::new(target_local)))
    let block_body = simplify_locals_resume_throw_sequence(throw_ref, cont, 0U)
    block_body.push(@lib.Instruction::drop())
    block_body.push(@lib.Instruction::i32_const(9))
    block_body.push(
      @lib.Instruction::local_set(@lib.LocalIdx::new(target_local)),
    )
    block_body.push(@lib.Instruction::ref_null(@lib.HeapType::new(cont)))
    roots.push(
      @lib.Instruction::block(
        @lib.BlockType::val_type(cont_ref),
        @lib.Expr::new(block_body),
      ),
    )
  }
  roots.push(@lib.Instruction::drop())
  roots.push(@lib.Instruction::local_get(@lib.LocalIdx::new(target_local)))
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
        ),
      ),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::cont(cont_sig))),
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(params, [@lib.ValType::i32()]),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([func_sig]))
  .with_tag_sec(
    @lib.TagSec::new([
      @lib.TagType::new(handler_tag_sig),
      @lib.TagType::new(thrown_tag_sig),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new(roots),
      ),
    ]),
  )
}

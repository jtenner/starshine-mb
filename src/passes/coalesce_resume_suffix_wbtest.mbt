///|
fn cl_resume_suffix_module(
  form : Int32,
  nested : Bool,
  terminal : Bool,
) -> @lib.Module {
  let cont = @lib.TypeIdx::new(1U)
  let cont_ref = @lib.ValType::ref_null(@lib.HeapType::new(cont))
  let types = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
    ),
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([cont_ref, @lib.ValType::ref_null_exn()], [cont_ref]),
      ),
    ),
  ])
  let inner : Array[@lib.Instruction] = []
  if nested {
    for _ in 0..<16 {
      inner.push(@lib.Instruction::nop())
    }
  }
  if form == 0 {
    inner.push(@lib.Instruction::i32_const(0))
  }
  if form == 2 {
    inner.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  }
  inner.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  let handlers = [
    @lib.ResumeHandler::on_label(
      @lib.TagIdx::new(0U),
      @lib.LabelIdx::new(if nested { 1U } else { 0U }),
    ),
  ]
  inner.push(
    if form == 0 {
      @lib.Instruction::resume_(cont, handlers)
    } else if form == 1 {
      @lib.Instruction::resume_throw(cont, @lib.TagIdx::new(1U), handlers)
    } else {
      @lib.Instruction::resume_throw_ref(cont, handlers)
    },
  )
  inner.push(@lib.Instruction::drop())
  if terminal {
    inner.push(@lib.Instruction::unreachable_())
  }
  let outer : Array[@lib.Instruction] = if nested {
    [@lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(inner))]
  } else {
    inner
  }
  if terminal {
    outer.push(@lib.Instruction::unreachable_())
  } else {
    outer.push(@lib.Instruction::ref_null(@lib.HeapType::new(cont)))
  }
  @lib.Module::new()
  .with_type_sec(types)
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(4U)]))
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
      ),
    ]),
  )
  .with_tag_sec(
    @lib.TagSec::new([
      @lib.TagType::new(@lib.TypeIdx::new(2U)),
      @lib.TagType::new(@lib.TypeIdx::new(3U)),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(cont_ref),
            @lib.Expr::new(outer),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::ref_null(@lib.HeapType::new(cont)),
        ]),
      ),
    ]),
  )
}

///|
fn cl_check_resume_suffix(
  form : Int32,
  nested : Bool,
  terminal : Bool,
  pass : String,
) -> Unit raise {
  let input = cl_resume_suffix_module(form, nested, terminal)
  let output = cl_resume_suffix_run(input, pass)
  match @validate.validate_module(output) {
    Ok(_) => ()
    Err(err) => fail("invalid continuation output: \{err}")
  }
  match cl_resume_suffix_body(output).last() {
    Some(@lib.RefNull(_)) => ()
    other => fail("required null suffix after on_label was removed: \{other}")
  }
}

///|
test "BURN-006 coalesce-locals resume suffix nested False" {
  cl_check_resume_suffix(0, false, true, "coalesce-locals")
}

///|
test "BURN-006 coalesce-locals resume suffix nested True" {
  cl_check_resume_suffix(0, true, true, "coalesce-locals")
}

///|
test "BURN-006 coalesce-locals resume_throw suffix nested False" {
  cl_check_resume_suffix(1, false, true, "coalesce-locals")
}

///|
test "BURN-006 coalesce-locals resume_throw suffix nested True" {
  cl_check_resume_suffix(1, true, true, "coalesce-locals")
}

///|
test "BURN-006 coalesce-locals resume_throw_ref suffix nested False" {
  cl_check_resume_suffix(2, false, true, "coalesce-locals")
}

///|
test "BURN-006 coalesce-locals resume_throw_ref suffix nested True" {
  cl_check_resume_suffix(2, true, true, "coalesce-locals")
}

///|
test "BURN-006 coalesce-locals resume normal fallthrough control nested False" {
  cl_check_resume_suffix(0, false, false, "coalesce-locals")
}

///|
test "BURN-006 coalesce-locals resume normal fallthrough control nested True" {
  cl_check_resume_suffix(0, true, false, "coalesce-locals")
}

///|
test "BURN-006 coalesce-locals-cfg resume suffix nested False" {
  cl_check_resume_suffix(0, false, true, "coalesce-locals-cfg")
}

///|
test "BURN-006 coalesce-locals-cfg resume suffix nested True" {
  cl_check_resume_suffix(0, true, true, "coalesce-locals-cfg")
}

///|
test "BURN-006 coalesce-locals-cfg resume_throw suffix nested False" {
  cl_check_resume_suffix(1, false, true, "coalesce-locals-cfg")
}

///|
test "BURN-006 coalesce-locals-cfg resume_throw suffix nested True" {
  cl_check_resume_suffix(1, true, true, "coalesce-locals-cfg")
}

///|
test "BURN-006 coalesce-locals-cfg resume_throw_ref suffix nested False" {
  cl_check_resume_suffix(2, false, true, "coalesce-locals-cfg")
}

///|
test "BURN-006 coalesce-locals-cfg resume_throw_ref suffix nested True" {
  cl_check_resume_suffix(2, true, true, "coalesce-locals-cfg")
}

///|
test "BURN-006 coalesce-locals-cfg resume normal fallthrough control nested False" {
  cl_check_resume_suffix(0, false, false, "coalesce-locals-cfg")
}

///|
test "BURN-006 coalesce-locals-cfg resume normal fallthrough control nested True" {
  cl_check_resume_suffix(0, true, false, "coalesce-locals-cfg")
}

///|
test "BURN-006 coalesce indexed control summary preserves resume form 0 exit" {
  let input = cl_resume_suffix_module(0, true, true)
  ignore(@validate.validate_module(input).unwrap())
  let index = cl_control_index_for_body(cl_resume_suffix_body(input), None).unwrap()
  assert_false(
    cl_control_no_fallthrough(index.facts[0]),
    msg="handled resume lets outer block fall through",
  )
}

///|
test "BURN-006 coalesce indexed control summary preserves resume form 1 exit" {
  let input = cl_resume_suffix_module(1, true, true)
  ignore(@validate.validate_module(input).unwrap())
  let index = cl_control_index_for_body(cl_resume_suffix_body(input), None).unwrap()
  assert_false(
    cl_control_no_fallthrough(index.facts[0]),
    msg="handled resume lets outer block fall through",
  )
}

///|
test "BURN-006 coalesce indexed control summary preserves resume form 2 exit" {
  let input = cl_resume_suffix_module(2, true, true)
  ignore(@validate.validate_module(input).unwrap())
  let index = cl_control_index_for_body(cl_resume_suffix_body(input), None).unwrap()
  assert_false(
    cl_control_no_fallthrough(index.facts[0]),
    msg="handled resume lets outer block fall through",
  )
}

///|
fn cl_resume_suffix_body(
  mod_ : @lib.Module,
  index~ : Int32 = 0,
) -> Array[@lib.Instruction] {
  let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[index]
  body
}

///|
fn cl_resume_suffix_run(
  input : @lib.Module,
  pass : String,
) -> @lib.Module raise {
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("invalid audit IR: \{err}")
  }
  match run_hot_pipeline(input, HotPipelineOptions::new(), [pass]) {
    Ok(value) => value
    Err(err) => fail("audit IR pipeline: \{err}")
  }
}

///|
test "BURN-006 coalesce throw forms preserve normal resume fallthrough" {
  for form in [1, 2] {
    for nested in [false, true] {
      for pass in ["coalesce-locals", "coalesce-locals-cfg"] {
        cl_check_resume_suffix(form, nested, false, pass)
      }
    }
  }
}

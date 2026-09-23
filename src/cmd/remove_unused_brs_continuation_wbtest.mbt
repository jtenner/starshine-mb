///|
fn remove_unused_brs_continuation_dispatcher_input() -> @lib.Module {
  let input = @passes.pass_test_module_from_wat(
    "(module (type $s (func)) (type $c (func)) (tag $e) (func (param (ref $c))))",
  )
  let types = input.type_sec.unwrap().0.copy()
  types[1] = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
  )
  let cont = @lib.TypeIdx::new(1U)
  let cont_ref = @lib.ValType::ref_null(@lib.HeapType::new(cont))
  let target = @lib.Instruction::block(
    @lib.BlockType::val_type(cont_ref),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::resume_(cont, [
        @lib.ResumeHandler::on_label(
          @lib.TagIdx::new(0U),
          @lib.LabelIdx::new(0U),
        ),
      ]),
      @lib.Instruction::ref_null(
        @lib.HeapType::abs(@lib.AbsHeapType::no_cont()),
      ),
    ]),
  )
  let removable = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
  )
  let input = input
    .with_type_sec(@lib.TypeSec::new(types))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([target, @lib.Instruction::drop(), removable]),
        ),
      ]),
    )
  match @validate.validate_module(input) {
    Ok(_) => input
    Err(err) => abort("invalid dispatcher RUB continuation fixture: \{err}")
  }
}

///|
test "dispatcher RUB accepts continuation handler target without rollback" {
  let input = remove_unused_brs_continuation_dispatcher_input()
  let trace : Array[String] = []
  let optimized = match
    optimize_module_with_pass_flags_trace(
      input,
      ["remove-unused-brs"],
      OptimizeOptions::new(),
      fn(line) { trace.push(line) },
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dispatcher RUB continuation success, got \{err}")
  }

  assert_true(
    trace.any(fn(line) { line.contains("pass[remove-unused-brs]:done") }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) {
      line.contains("pass[remove-unused-brs]:skip-invalid-lower")
    }),
    msg=trace.to_string(),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid dispatcher RUB output, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => {
      assert_true(
        body.length() >= 2,
        msg="expected continuation block: \{body}",
      )
      match body[0] {
        @lib.Block(@lib.ValTypeBlockType(result), target) => {
          assert_eq(
            result,
            @lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(1U))),
          )
          assert_true(
            target.0.any(fn(instr) { instr is @lib.Resume(_, _) }),
            msg="expected continuation inside target block: \{body}",
          )
        }
        _ => fail("expected preserved continuation target block: \{body}")
      }
    }
    _ => fail("expected one defined continuation function")
  }
}

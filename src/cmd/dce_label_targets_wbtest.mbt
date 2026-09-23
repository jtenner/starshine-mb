///|
test "dispatcher DCE keeps block targeted only by try_table catch" {
  let wat =
    #|(module
    #|  (import "env" "side" (func $side))
    #|  (tag $e)
    #|  (func
    #|    block $handler
    #|      call $side
    #|      try_table (catch_all $handler)
    #|        call $side
    #|      end
    #|      call $side
    #|    end
    #|    block
    #|      i32.const 0
    #|      br_if 0
    #|      i32.const 0
    #|      drop
    #|    end))
  let input = @passes.pass_test_module_from_wat(wat)
  let optimized = match
    optimize_module_with_pass_flags(
      input,
      ["dead-code-elimination"],
      OptimizeOptions::new(),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected dispatcher try_table target preservation, got \{err}")
  }

  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid dispatcher try_table output, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("catch_all"), msg=pretty)
}

///|
fn dce_continuation_target_input() -> @lib.Module {
  let input = @passes.pass_test_module_from_wat(
    "(module (type $s (func)) (type $c (func)) (tag $e) (func (param (ref $c))))",
  )
  let types = input.type_sec.unwrap().0.copy()
  types[1] = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
  )
  let cont = @lib.TypeIdx::new(1U)
  let ref_ = @lib.ValType::ref_null(@lib.HeapType::new(cont))
  let target = @lib.Instruction::block(
    @lib.BlockType::val_type(ref_),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::resume_(cont, [
        @lib.ResumeHandler::on_label(
          @lib.TagIdx::new(0U),
          @lib.LabelIdx::new(0U),
        ),
      ]),
      @lib.Instruction::unreachable_(),
    ]),
  )
  let input = input
    .with_type_sec(@lib.TypeSec::new(types))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([target, @lib.Instruction::drop()]),
        ),
      ]),
    )
  match @validate.validate_module(input) {
    Ok(_) => input
    Err(err) => abort("invalid continuation target fixture: \{err}")
  }
}

///|
test "dispatcher DCE keeps block targeted only by continuation handler" {
  let input = dce_continuation_target_input()
  let trace : Array[String] = []
  let optimized = match
    optimize_module_with_pass_flags_trace(
      input,
      ["dead-code-elimination"],
      OptimizeOptions::new(),
      fn(line) { trace.push(line) },
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected dispatcher continuation target preservation, got \{err}")
  }

  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected valid dispatcher continuation output, got \{err}")
  }
  assert_true(
    trace.any(fn(line) { line.contains("pass[dead-code-elimination]:done") }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) {
      line.contains("pass[dead-code-elimination]:skip-invalid-lower")
    }),
    msg=trace.to_string(),
  )
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => {
      assert_true(body.length() > 0)
      match body[0] {
        @lib.Block(_, @lib.Expr(target_body)) =>
          assert_true(
            target_body.any(fn(instr) { instr is @lib.Resume(_, _) }),
            msg="expected continuation inside preserved target block: \{body}",
          )
        _ => fail("expected preserved continuation target block: \{body}")
      }
    }
    _ => fail("expected one defined continuation function")
  }
}

///|
fn cl_legacy_shared_body_fixture() -> @lib.Module {
  let parsed = pass_test_module_from_wat(
    (
      #|(module
      #| (tag $e)
      #| (func (export "producer") (param i32) (result i32)
      #|   (local i32 i32)
      #|   (try (result i32)
      #|     (do i32.const 7 local.set 2 local.get 2)
      #|     (catch $e i32.const 8 local.set 2 local.get 2)
      #|     (catch_all i32.const 9 local.set 2 local.get 2)))
      #| (func (export "observer") (param i32 i32) (result i32)
      #|   (local i32)
      #|   i32.const 0 drop local.get 1))
    ),
  )
  let funcs = parsed.code_sec.unwrap().0
  let @lib.Func(_, @lib.Expr(producer_body)) = funcs[0]
  let @lib.Func(observer_locals, @lib.Expr(observer_body)) = funcs[1]
  let observer = @lib.Func::new(
    observer_locals,
    @lib.Expr::new([producer_body[0], observer_body[1], observer_body[2]]),
  )
  parsed.with_code_sec(@lib.CodeSec::new([funcs[0], observer]))
}

///|
test "coalesce legacy local remapping preserves shared try and catch bodies" {
  let input = cl_legacy_shared_body_fixture()
  @validate.validate_module(input).unwrap()
  let original_bytes = @binary.encode_module(input).unwrap()
  let funcs = input.code_sec.unwrap().0
  let rewrite = cl_rewrite_func(funcs[0], [@lib.ValType::i32()])
  assert_true(rewrite.changed)
  let candidate = input.with_code_sec(
    @lib.CodeSec::new([rewrite.func, funcs[1]]),
  )
  @validate.validate_module(candidate).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), original_bytes)
  let @lib.Func(_, @lib.Expr(observer_body)) = funcs[1]
  match observer_body[0] {
    @lib.Try(_, @lib.Expr(body), catches, delegate) => {
      assert_eq(delegate, None)
      assert_eq(body[1], @lib.Instruction::local_set(@lib.LocalIdx::new(2U)))
      assert_eq(body[2], @lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
      assert_eq(catches.length(), 2)
      for catch_ in catches {
        let @lib.Expr(body) = match catch_ {
          @lib.LegacyCatch(_, body) | @lib.LegacyCatchAll(body) => body
        }
        assert_eq(body[1], @lib.Instruction::local_set(@lib.LocalIdx::new(2U)))
        assert_eq(body[2], @lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
      }
    }
    _ => fail("expected the retained observer try")
  }
}

///|
test "coalesce unused-local cleanup preserves shared nested dead tails" {
  let parsed = pass_test_module_from_wat(
    (
      #|(module
      #| (func (export "producer") (local i32 i32)
      #|   (block unreachable i32.const 7 drop))
      #| (func (export "observer") nop))
    ),
  )
  let funcs = parsed.code_sec.unwrap().0
  let @lib.Func(_, @lib.Expr(producer_body)) = funcs[0]
  let observer = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([producer_body[0]]),
  )
  let input = parsed.with_code_sec(@lib.CodeSec::new([funcs[0], observer]))
  @validate.validate_module(input).unwrap()
  let original_bytes = @binary.encode_module(input).unwrap()
  let rewrite = cl_rewrite_func(funcs[0], [])
  assert_true(rewrite.changed)
  let candidate = input.with_code_sec(
    @lib.CodeSec::new([rewrite.func, observer]),
  )
  @validate.validate_module(candidate).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), original_bytes)
  let @lib.Func(_, @lib.Expr(observer_body)) = observer
  match observer_body[0] {
    @lib.Block(_, @lib.Expr(body)) =>
      assert_eq(body, [
        @lib.Instruction::unreachable_(),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::drop(),
      ])
    _ => fail("expected the retained observer block")
  }
}

///|
test "coalesce unread tee cleanup preserves an unchanged shared loop input" {
  let parsed = pass_test_module_from_wat(
    (
      #|(module
      #| (func (export "producer") (param i32) (result i32)
      #|   (loop (result i32) i32.const 7 local.tee 0))
      #| (func (export "observer") (param i32) (result i32)
      #|   i32.const 0 drop local.get 0))
    ),
  )
  let funcs = parsed.code_sec.unwrap().0
  let @lib.Func(_, @lib.Expr(producer_body)) = funcs[0]
  let @lib.Func(observer_locals, @lib.Expr(observer_body)) = funcs[1]
  let observer = @lib.Func::new(
    observer_locals,
    @lib.Expr::new([producer_body[0], observer_body[1], observer_body[2]]),
  )
  let input = parsed.with_code_sec(@lib.CodeSec::new([funcs[0], observer]))
  @validate.validate_module(input).unwrap()
  let original_bytes = @binary.encode_module(input).unwrap()
  let unchanged = cl_rewrite_func(funcs[0], [@lib.ValType::i32()])
  assert_false(unchanged.changed)
  let rewrite = cl_cleanup_never_read_tees(unchanged, 1)
  assert_true(rewrite.changed)
  let candidate = input.with_code_sec(
    @lib.CodeSec::new([rewrite.func, observer]),
  )
  @validate.validate_module(candidate).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), original_bytes)
  let @lib.Func(_, @lib.Expr(retained_body)) = observer
  match retained_body[0] {
    @lib.Loop(_, @lib.Expr(body)) =>
      assert_eq(body, [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      ])
    _ => fail("expected the retained observer loop")
  }
}

///|
fn cl_legacy_tee_read_fixture(
  read_from_catch : Bool,
  tagged_catch : Bool,
) -> @lib.Module {
  let base = pass_test_module_from_wat(
    "(module (tag $e) (func (export \"run\") (param i32) (result i32) local.get 0))",
  )
  let read = @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
  let handler = @lib.Expr::new([read])
  let catch_ = if tagged_catch {
    @lib.LegacyCatch::tagged(@lib.TagIdx::new(0U), handler)
  } else {
    @lib.LegacyCatch::all(handler)
  }
  let protected = if read_from_catch {
    [@lib.Instruction::throw_(@lib.TagIdx::new(0U))]
  } else {
    [read]
  }
  base.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
          @lib.Instruction::try_(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            @lib.Expr::new(protected),
            [catch_],
          ),
        ]),
      ),
    ]),
  )
}

///|
fn cl_assert_legacy_tee_read_is_kept(
  input : @lib.Module,
  output : @lib.Module,
) -> Unit raise {
  @validate.validate_module(input).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
  // Both paths read the value 7 written by this tee. If it is deleted, a
  // valid function instead returns its argument (for example 3).
  assert_eq(body[1], @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)))
  match body[3] {
    @lib.Try(_, @lib.Expr(protected), catches, _) => {
      assert_eq(catches.length(), 1)
      let @lib.Expr(handler) = match catches[0] {
        @lib.LegacyCatch(_, body) | @lib.LegacyCatchAll(body) => body
      }
      assert_eq(handler, [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))])
      assert_true(
        protected[0] is @lib.LocalGet(_) || protected[0] is @lib.Throw(_),
      )
    }
    _ => fail("expected the typed legacy try that reads the preceding tee")
  }
}

///|
test "coalesce tee cleanup preserves a write read in a legacy try or catch" {
  for read_from_catch in [false, true] {
    for tagged_catch in [false, true] {
      let input = cl_legacy_tee_read_fixture(read_from_catch, tagged_catch)
      @validate.validate_module(input).unwrap()
      let original_bytes = @binary.encode_module(input).unwrap()
      let original = input.code_sec.unwrap().0[0]
      let rewrite = cl_cleanup_never_read_tees(
        cl_rewrite_func(original, [@lib.ValType::i32()]),
        1,
      )
      let output = input.with_code_sec(@lib.CodeSec::new([rewrite.func]))
      cl_assert_legacy_tee_read_is_kept(input, output)
      assert_eq(@binary.encode_module(input).unwrap(), original_bytes)
    }
  }
}

///|
test "coalesce public pass preserves a write read in a legacy try or catch" {
  for read_from_catch in [false, true] {
    for tagged_catch in [false, true] {
      let input = cl_legacy_tee_read_fixture(read_from_catch, tagged_catch)
      @validate.validate_module(input).unwrap()
      let original_bytes = @binary.encode_module(input).unwrap()
      cl_assert_legacy_tee_read_is_kept(
        input,
        coalesce_locals_run_module_pass(input),
      )
      assert_eq(@binary.encode_module(input).unwrap(), original_bytes)
    }
  }
}

///|
test "coalesce dispatcher preserves a write read in a legacy try or catch" {
  for read_from_catch in [false, true] {
    for tagged_catch in [false, true] {
      let input = cl_legacy_tee_read_fixture(read_from_catch, tagged_catch)
      @validate.validate_module(input).unwrap()
      let original_bytes = @binary.encode_module(input).unwrap()
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
        "coalesce-locals",
      ]).unwrap()
      cl_assert_legacy_tee_read_is_kept(input, output)
      assert_eq(@binary.encode_module(input).unwrap(), original_bytes)
    }
  }
}

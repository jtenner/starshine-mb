///|
test "audit rse retains reset after legacy try writes" {
  let wat =
    #|(module (func (result i32) (local i32)
    #| (try (do i32.const 1 local.set 0) (catch_all))
    #| i32.const 0 local.set 0 local.get 0))
  let output = audit_run(wat, "redundant-set-elimination")
  assert_true(
    audit_body(output).contains(
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    ),
  )
}

///|
test "audit rse tracks multivalue loop stack results" {
  let wat =
    #|(module (func (result i32) (local i32)
    #| i32.const 0
    #| loop (result i32 i32) i32.const 1 i32.const 2 end
    #| drop local.set 0 drop local.get 0))
  let output = audit_run(wat, "redundant-set-elimination")
  assert_true(
    audit_body(output).contains(
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    ),
  )
}

///|
test "audit rse retains reset after exceptional block exit" {
  let wat =
    #|(module (tag $e) (func (param i32) (result i32) (local i32)
    #| block $exit
    #|  try_table (catch_all $exit)
    #|   local.get 0 if throw $e end
    #|  end
    #|  i32.const 1 local.set 1
    #| end
    #| i32.const 1 local.set 1 local.get 1))
  let output = audit_run(wat, "redundant-set-elimination")
  assert_true(
    audit_body(output).contains(
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    ),
  )
}

///|
test "audit hot rse allocates distinct branch value identities" {
  let wat =
    #|(module (func (param i32) (result i32) (local i32)
    #| local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end
    #| i32.const 1 local.set 1 local.get 1))
  let func = rse_test_run_hot(wat)
  let root = @ir.HotRegionRef::root()
  let set = @ir.hot_region_get(func, root, 1)
  assert_true(@ir.hot_node_get(func, set).op is @ir.HotOp::LocalSet)
}

///|
test "audit HOT rse retains outer nondefaultable initialization" {
  let wat =
    #|(module (type $s (struct))
    #| (func (param (ref $s)) (result (ref $s)) (local (ref $s))
    #| block local.get 0 local.set 1 end
    #| local.get 0 local.set 1 local.get 1))
  let func = rse_test_run_hot(wat)
  let root = @ir.HotRegionRef::root()
  assert_true(
    @ir.hot_node_get(func, @ir.hot_region_get(func, root, 1)).op
    is @ir.HotOp::LocalSet,
  )
}

///|
test "audit rse descriptor casts preserve the object identity" {
  let wat =
    #|(module
    #| (rec (type $s (descriptor $d) (struct)) (type $d (describes $s) (struct)))
    #| (func (param (ref null $s)) (param (ref (exact $d))) (result anyref) (local anyref)
    #| local.get 1 local.set 2
    #| local.get 0 local.get 1 ref.cast_desc_eq $s local.set 2
    #| local.get 2))
  let output = audit_run(wat, "redundant-set-elimination")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.LocalSet(_) }),
    2,
  )
}

///|
test "audit rse descriptor branches merge target local facts" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $s (descriptor $d) (struct)) (type $d (describes $s) (struct))) (func (param (ref null $s)) (param (ref (exact $d))) (result i32) (local i32) i32.const 0))",
  )
  let ref_ = @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U)))
  for
    branch in [
      @lib.Instruction::br_on_cast_desc_eq(@lib.LabelIdx::new(0U), ref_, ref_),
      @lib.Instruction::br_on_cast_desc_eq_fail(
        @lib.LabelIdx::new(0U),
        ref_,
        ref_,
      ),
    ] {
    let input = input.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::ref_type(ref_)),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                branch,
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(1),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::ref_null(
                  @lib.HeapType::new(@lib.TypeIdx::new(0U)),
                ),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
    let output = audit_run_module(input, "redundant-set-elimination")
    assert_true(
      audit_body(output).contains(
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      ),
    )
  }
}

///|
test "rse loop legacy EH writes retain post-loop reset" {
  for
    eh in [
      "(try (do i32.const 1 local.set 0) (catch_all))", "(try (do throw $e) (catch $e i32.const 1 local.set 0))",
      "(try (do throw $e) (catch_all i32.const 1 local.set 0))", "(try (do i32.const 1 local.set 0) (catch_all)) local.get 1 i32.const 1 i32.add local.tee 1 i32.const 2 i32.lt_u br_if 0",
      "(block (try (do i32.const 1 local.set 0) (delegate 0)))",
    ] {
    let output = audit_run(
      "(module (tag $e) (func (result i32) (local i32 i32) (loop " +
      eh +
      ") i32.const 0 local.set 0 local.get 0))",
      "redundant-set-elimination",
    )
    assert_true(
      audit_body(output).contains(
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      ),
    )
  }
}

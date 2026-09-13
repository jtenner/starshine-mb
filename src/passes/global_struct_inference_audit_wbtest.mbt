///|
test "audit global struct singleton facts include mutable global allocations" {
  let facts = gsi_test_closed_world_facts(
    "(module (type $s (struct (field i32))) (global (ref $s) (struct.new $s (i32.const 1))) (global (mut (ref $s)) (struct.new $s (i32.const 2))))",
  )
  assert_true(
    gsi_test_closed_world_type_is_poisoned(facts, @lib.TypeIdx::new(0U)),
  )
}

///|
fn gsi_audit_initializer_origin_poisoned(table : Bool) -> Bool raise {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (global (ref $s) (struct.new $s (i32.const 1))))",
  )
  let type_ = @lib.TypeIdx::new(0U)
  let ref_ = @lib.RefType::new(false, @lib.HeapType::new(type_))
  let init = @lib.Expr::new([
    @lib.Instruction::i32_const(2),
    @lib.Instruction::struct_new(type_),
  ])
  let input = if table {
    input.with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(ref_, @lib.Limits::i32(1U, None)),
          Some(init),
        ),
      ]),
    )
  } else {
    input.with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::typed_exprs(ref_, [init]),
        ),
      ]),
    )
  }
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("initializer fixture: \{err}")
  }
  let facts = gsi_build_closed_world_facts(
    @validate.Env::new().with_module(input),
    input,
  )
  gsi_test_closed_world_type_is_poisoned(facts, type_)
}

///|
test "audit global struct singleton facts include table allocations" {
  assert_true(gsi_audit_initializer_origin_poisoned(true))
}

///|
test "audit global struct singleton facts include element allocations" {
  assert_true(gsi_audit_initializer_origin_poisoned(false))
}

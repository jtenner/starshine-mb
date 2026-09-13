///|
test "audit unused table retains trapping descriptor initializer" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $s (descriptor $d) (struct)) (type $d (describes $s) (struct))))",
  ).with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
          @lib.Limits::i32(1U, None),
        ),
        Some(
          @lib.Expr::new([
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::none()),
            ),
            @lib.Instruction::struct_new_desc(@lib.TypeIdx::new(0U)),
          ]),
        ),
      ),
    ]),
  )
  let output = audit_run_module(input, "remove-unused-module-elements")
  assert_true(output.table_sec is Some(@lib.TableSec([_, ..])))
}

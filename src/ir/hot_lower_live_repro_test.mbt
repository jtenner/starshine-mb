///|
test "hot lower keeps unreachable in exact cmd inner carrier shape" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32 i32) (result i32) (local i32 i32 i32 i32 i32) (local.set 3 (block $block2 (result i32) (block $block1 (br $block2 (block (result i32) (block $block (if (i32.eq (local.get 0) (i32.const 1)) (then (local.set 4 (local.tee 5 (local.get 1))) (br $block)) (else (local.set 6 (local.tee 7 (local.get 2))) (br $block1)))) (local.get 4)))))) (local.get 3)))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
              [@lib.ValType::i32()],
            ),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
fn oi_local_group_validation_bench(
  it : @bench.T,
  all_changed : Bool,
  full : Bool,
) -> Unit {
  let seed = pass_test_module_from_wat("(module (func (local i32 f64 i32)))")
  let @lib.Func(locals, _) = seed.code_sec.unwrap().0[0]
  let body = Array::make(128, @lib.Instruction::nop())
  let changed = @lib.Func::new(locals, @lib.Expr::new(body))
  let unchanged = @lib.Func::new(
    @lib.Locals::single(3U, @lib.ValType::i32()),
    @lib.Expr::new(body),
  )
  let input = seed
    .with_func_sec(
      @lib.FuncSec::new(Array::make(128, seed.func_sec.unwrap().0[0])),
    )
    .with_code_sec(
      @lib.CodeSec::new(
        Array::makei(128, fn(index) {
          if all_changed || index % 8 == 0 {
            changed
          } else {
            unchanged
          }
        }),
      ),
    )
  @validate.validate_module(input).unwrap()
  let grouped = run_hot_pipeline_raw_group_body_locals_by_type_module(input)
  @validate.validate_module(grouped).unwrap()
  if !oi_validate_local_group_changed_bodies(input, grouped) ||
    oi_local_group_changed_bodies(input, grouped).length() !=
    (if all_changed { 128 } else { 16 }) {
    abort("OI grouping validation fixture selected incorrect bodies")
  }
  it.bench(fn() {
    it.keep(
      if full {
        @validate.validate_module(grouped).is_ok()
      } else {
        oi_validate_local_group_changed_bodies(input, grouped)
      },
    )
  })
}

///|
test "bench OI grouping validation mixed full" (it : @bench.T) {
  oi_local_group_validation_bench(it, false, true)
}

///|
test "bench OI grouping validation mixed changed bodies" (it : @bench.T) {
  oi_local_group_validation_bench(it, false, false)
}

///|
test "bench OI grouping validation all full" (it : @bench.T) {
  oi_local_group_validation_bench(it, true, true)
}

///|
test "bench OI grouping validation all changed bodies" (it : @bench.T) {
  oi_local_group_validation_bench(it, true, false)
}

///|
fn sgo_wbtest_global_infos(text : String) -> Array[SgoGlobalInfo] {
  let (infos, _) = sgo_collect_global_infos(pass_test_module_from_wat(text))
  infos
}

///|
test "simplify-globals-optimizing fact table records source-specific global traffic" {
  let infos = sgo_wbtest_global_infos(
    (
      #|(module
      #|  (import "env" "imported" (global $imported i32))
      #|  (memory 1)
      #|  (table 2 funcref)
      #|  (func $f)
      #|  (global $reader i32 (global.get $imported))
      #|  (global $mutable (mut i32) (i32.const 0))
      #|  (global $exported (export "exported") (mut i32) (i32.const 1))
      #|  (data (global.get $reader) "x")
      #|  (elem (global.get $reader) $f)
      #|  (func (export "run")
      #|    global.get $mutable
      #|    drop
      #|    i32.const 2
      #|    global.set $mutable))
      #|)
      #|,
    ),
  )

  @debug.assert_eq(infos.length(), 4)
  @debug.assert_eq(infos[0].imported, true)
  @debug.assert_eq(infos[0].global_init_read_count, 1)
  @debug.assert_eq(infos[1].data_offset_read_count, 1)
  @debug.assert_eq(infos[1].elem_offset_read_count, 1)
  @debug.assert_eq(infos[2].function_read_count, 1)
  @debug.assert_eq(infos[2].function_write_count, 1)
  @debug.assert_eq(infos[2].read_count, 1)
  @debug.assert_eq(infos[2].write_count, 1)
  @debug.assert_eq(infos[3].exported, true)
}

///|
test "simplify-globals-optimizing fact table records typed element item global reads" {
  let null_rt = @lib.RefType::abs(@lib.AbsHeapType::none())
  let array_rt = @lib.RefType::abs(@lib.AbsHeapType::array())
  let mod_ = @lib.Module::new()
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::ref_null_type(null_rt), false),
          @lib.Expr::new([@lib.Instruction::ref_null_type(null_rt)]),
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::typed_exprs(array_rt, [
            @lib.Expr::new([
              @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            ]),
          ]),
        ),
      ]),
    )
  let (infos, _) = sgo_collect_global_infos(mod_)

  @debug.assert_eq(infos.length(), 1)
  @debug.assert_eq(infos[0].read_count, 1)
  @debug.assert_eq(infos[0].elem_item_read_count, 1)
}

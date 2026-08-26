///|
pub(all) struct GlobalBuilder {
  globals : Array[@lib.Global]
}

///|
pub fn global_builder_new() -> GlobalBuilder {
  { globals: [] }
}

///|
pub fn GlobalBuilder::push(self : GlobalBuilder, carrier : Int) -> Unit {
  let value_type = match carrier {
    0 => @lib.ValType::i32()
    1 => @lib.ValType::i64()
    2 => @lib.ValType::f32()
    3 => @lib.ValType::f64()
    4 => @lib.ValType::v128()
    _ => @lib.ValType::eqref_null()
  }
  let initial = match carrier {
    0 => [@lib.Instruction::i32_const(@lib.I32::new(0))]
    1 => [@lib.Instruction::i64_const(@lib.I64::new(0L))]
    2 => [@lib.Instruction::f32_const(@lib.F32::new(0.0))]
    3 => [@lib.Instruction::f64_const(@lib.F64::new(0.0))]
    4 => [
      @lib.Instruction::v128_const(
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      ),
    ]
    _ => [
      @lib.Instruction::ref_null(
        @lib.HeapType::abs(@lib.AbsHeapType::none()),
      ),
    ]
  }
  self.globals.push(
    @lib.Global::new(
      @lib.GlobalType::new(value_type, true),
      @lib.Expr::new(initial),
    ),
  )
}

///|
pub fn module_with_globals(
  module_ : @lib.Module,
  builder : GlobalBuilder,
) -> @lib.Module {
  if builder.globals.length() == 0 {
    module_
  } else {
    module_.with_global_sec(@lib.GlobalSec::new(builder.globals))
  }
}

///|
pub fn module_with_start_function(
  module_ : @lib.Module,
  function_index : Int,
) -> @lib.Module {
  module_.with_start_sec(
    @lib.StartSec::new(
      @lib.FuncIdx::new(function_index.reinterpret_as_uint()),
    ),
  )
}

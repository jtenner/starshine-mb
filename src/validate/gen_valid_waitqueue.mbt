///|
fn gen_valid_waitqueue_config() -> GenValidConfig {
  let base = gen_valid_array_memory_config()
  GenValidConfig::{ ..base, max_globals: 1, max_body_statements: 461, }
}

///|
fn gen_valid_waitqueue_module(ctx : GenValidContext) -> Module {
  let seed = if ctx.use_named_streams {
    ctx.root_seed
  } else {
    ctx.rnd.next_uint64()
  }
  let variant = (seed % 6UL).to_int()
  let i32 = ValType::i32()
  let queue_heap = HeapType::shared_abs(AbsHeapType::waitqueue())
  let queue = ValType::ref_null(queue_heap)
  let ti = TypeIdx::new(0U)
  let receiver = ValType::ref_null(HeapType::new(ti))
  let count = Instruction::i32_const(I32((seed >> 8).to_int()))
  let mut params : Array[ValType] = []
  let mut results = [i32]
  let mut module_ = Module::new()
  let body = match variant {
    0 => {
      results = [ValType::ref_type(RefType::new(false, queue_heap))]
      [Instruction::waitqueue_new()]
    }
    1 => [Instruction::waitqueue_new(), count, Instruction::waitqueue_notify()]
    3 =>
      [
        Instruction::ref_null(HeapType::shared_abs(AbsHeapType::no_waitqueue())),
        count,
        Instruction::waitqueue_notify(),
      ]
    4 => {
      module_ = module_.with_global_sec(
        GlobalSec::new([
          Global::new(
            GlobalType::new(queue, false),
            Expr::new([Instruction::waitqueue_new()]),
          ),
        ]),
      )
      [
        Instruction::global_get(GlobalIdx::new(0U)),
        count,
        Instruction::waitqueue_notify(),
      ]
    }
    _ => {
      params = if variant == 5 { [receiver, queue] } else { [receiver] }
      [
        Instruction::local_get(LocalIdx::new(0U)),
        if variant == 5 {
          Instruction::local_get(LocalIdx::new(1U))
        } else {
          Instruction::waitqueue_new()
        },
        count,
        Instruction::i64_const(I64(0L)),
        Instruction::struct_wait(ti, U32((seed & 1UL).to_uint())),
      ]
    }
  }
  module_
  .with_type_sec(
    TypeSec::new([
      RecType::new(
        SubType::comp_type(
          CompType::struct_([
            FieldType::new(StorageType::val_type(i32), Mut::var_()),
            FieldType::new(StorageType::val_type(i32), Mut::var_()),
          ]),
          metadata=TypeMetadata::new(shared=(seed & 8UL) == 0UL),
        ),
      ),
      RecType::new(SubType::comp_type(CompType::func(params, results))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(1U)]))
  .with_code_sec(
    CodeSec::new([Func::new(Locals::from_types([]), Expr::new(body))]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
}

///|
fn gen_valid_atomic_orders_config() -> GenValidConfig {
  let base = gen_valid_array_memory_config()
  GenValidConfig::{
    ..base,
    max_mems: 1,
    max_locals: 1,
    max_body_statements: 463,
  }
}

///|
fn gen_valid_atomic_orders_module(ctx : GenValidContext) -> Module {
  let seed = if ctx.use_named_streams {
    ctx.root_seed
  } else {
    ctx.rnd.next_uint64()
  }
  let kind = (seed % 3UL).to_int()
  let order = match seed / 3UL % 3UL {
    0UL => AtomicOrder::seq_cst()
    1UL => AtomicOrder::acq_rel()
    _ => AtomicOrder::relaxed()
  }
  let shared = ((seed / 9UL) & 1UL) == 0UL
  let memory64 = ((seed / 18UL) & 1UL) != 0UL
  let i32 = ValType::i32()
  let ti = TypeIdx::new(0U)
  let field = U32(((seed >> 6) & 1UL).to_uint())
  let value = Instruction::i32_const(I32((seed >> 8).to_int()))
  let body : Array[Instruction] = []
  let types : Array[RecType] = []
  let locals : Array[ValType] = []
  let mut module_ = Module::new()
  if kind == 0 {
    let address = if memory64 {
      Instruction::i64_const(I64(0L))
    } else {
      Instruction::i32_const(I32(0))
    }
    let ma = MemArg::new(2U, None, seed & 4UL)
    module_ = module_.with_mem_sec(
      MemSec::new([
        MemType::new(
          if memory64 {
            Limits::i64(1UL, Some(1UL))
          } else {
            Limits::i32(1U, Some(1U))
          },
          shared~,
        ),
      ]),
    )
    body.push(address)
    body.push(value)
    body.push(Instruction::i32_atomic_store(ma, order~))
    if (seed & 0x40UL) != 0UL {
      body.push(Instruction::atomic_fence(order~))
    }
    body.push(address)
    body.push(Instruction::i32_const(I32(1)))
    body.push(Instruction::atomic_rmw(AtomicRmwOp::i32_add(), ma, order~))
    body.push(Instruction::drop())
    body.push(address)
    body.push(Instruction::i32_atomic_load(ma, order~))
  } else {
    let field_type = FieldType::new(StorageType::val_type(i32), Mut::var_())
    types.push(
      RecType::new(
        SubType::comp_type(
          if kind == 1 {
            CompType::struct_([field_type, field_type])
          } else {
            CompType::array(field_type)
          },
          metadata=TypeMetadata::new(shared~),
        ),
      ),
    )
    locals.push(ValType::ref_null(HeapType::new(ti)))
    if kind == 1 {
      body.push(Instruction::struct_new_default(ti))
    } else {
      body.push(Instruction::i32_const(I32(2)))
      body.push(Instruction::array_new_default(ti))
    }
    body.push(Instruction::local_set(LocalIdx::new(0U)))
    body.push(Instruction::local_get(LocalIdx::new(0U)))
    if kind == 2 {
      body.push(Instruction::i32_const(I32(field.0.reinterpret_as_int())))
    }
    body.push(value)
    body.push(
      if kind == 1 {
        Instruction::struct_atomic_set(order, ti, field)
      } else {
        Instruction::array_atomic_set(order, ti)
      },
    )
    let rmw_variant = (seed / 36UL % 5UL).to_int()
    if rmw_variant != 0 {
      body.push(Instruction::local_get(LocalIdx::new(0U)))
      if kind == 2 {
        body.push(Instruction::i32_const(I32(field.0.reinterpret_as_int())))
      }
      if rmw_variant <= 2 {
        body.push(
          Instruction::i32_const(I32(if rmw_variant == 1 { 0 } else { 7 })),
        )
        body.push(
          if kind == 1 {
            Instruction::struct_atomic_rmw(
              @lib.AggregateAtomicRmwOp::add(),
              ti,
              field,
              order~,
            )
          } else {
            Instruction::array_atomic_rmw(
              @lib.AggregateAtomicRmwOp::add(),
              ti,
              order~,
            )
          },
        )
      } else {
        body.push(Instruction::i32_const(I32(7)))
        body.push(
          Instruction::i32_const(I32(if rmw_variant == 3 { 7 } else { 8 })),
        )
        body.push(
          if kind == 1 {
            Instruction::struct_atomic_cmpxchg(ti, field, order~)
          } else {
            Instruction::array_atomic_cmpxchg(ti, order~)
          },
        )
      }
      body.push(Instruction::drop())
    }
    body.push(Instruction::local_get(LocalIdx::new(0U)))
    if kind == 2 {
      body.push(Instruction::i32_const(I32(field.0.reinterpret_as_int())))
    }
    body.push(
      if kind == 1 {
        Instruction::struct_atomic_get(order, ti, field)
      } else {
        Instruction::array_atomic_get(order, ti)
      },
    )
  }
  let function_type = TypeIdx::new(types.length().to_uint())
  types.push(RecType::new(SubType::comp_type(CompType::func([], [i32]))))
  module_
  .with_type_sec(TypeSec::new(types))
  .with_func_sec(FuncSec::new([function_type]))
  .with_code_sec(
    CodeSec::new([Func::new(Locals::from_types(locals), Expr::new(body))]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::new("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
}

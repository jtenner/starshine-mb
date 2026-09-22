///|
fn gen_valid_campaign_memory64_config() -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  GenValidConfig::{
    ..base,
    max_type_defs: 1,
    max_imports: 0,
    max_defined_funcs: 1,
    max_tables: 0,
    max_mems: 3,
    max_globals: 0,
    max_tags: 0,
    max_elems: 0,
    max_datas: 0,
    max_params: 0,
    max_results: 0,
    max_locals: 0,
    max_body_statements: 67,
    max_body_depth: 1,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_imports: false,
      allow_tables: false,
      allow_mems: true,
      allow_globals: false,
      allow_tags: false,
      allow_start: false,
      allow_elems: false,
      allow_datas: false,
      allow_ref_types: false,
      allow_v128: false,
      allow_relaxed_simd: false,
      allow_calls: false,
      allow_call_indirect: false,
      allow_tail_calls: false,
      allow_shared_memories: false,
      allow_memory64: true,
      allow_atomics: false,
      allow_typed_body_generator: false,
    },
  }
}

///|
fn gen_valid_campaign_memory64_is_64(seed : UInt64, index : Int) -> Bool {
  let first_is_64 = (seed & 2UL) != 0UL
  match index {
    0 => first_is_64
    1 => !first_is_64
    _ => (seed & 8UL) != 0UL
  }
}

///|
fn gen_valid_campaign_memory64_module(ctx : GenValidContext) -> Module {
  let seed = if ctx.use_named_streams {
    ctx.root_seed
  } else {
    ctx.rnd.next_uint64()
  }
  let count = if (seed & 1UL) == 0UL { 2 } else { 3 }
  let reverse = (seed & 64UL) != 0UL
  let offset = ((seed >> 4) & 3UL) * 4UL
  let mem_names = ["memory0", "memory1", "memory2"]
  let memories : Array[MemType] = []
  let exports : Array[Export] = [
    Export::new(Name::new("run"), ExternIdx::func(FuncIdx::new(0U))),
  ]
  for index = 0; index < count; index = index + 1 {
    let memory64 = gen_valid_campaign_memory64_is_64(seed, index)
    memories.push(
      MemType::new(
        if memory64 {
          Limits::i64(1UL, Some(3UL))
        } else {
          Limits::i32(1U, Some(3U))
        },
      ),
    )
    exports.push(
      Export::new(
        Name::from_string(mem_names[index]),
        ExternIdx::mem(MemIdx::new(index.to_uint())),
      ),
    )
  }
  let body : Array[Instruction] = []
  for slot = 0; slot < count; slot = slot + 1 {
    let index = if reverse { count - 1 - slot } else { slot }
    let memory64 = gen_valid_campaign_memory64_is_64(seed, index)
    let memory = MemIdx::new(index.to_uint())
    let value64 = if index % 2 == 0 {
      ((seed >> 5) & 1UL) != 0UL
    } else {
      ((seed >> 5) & 1UL) == 0UL
    }
    let memarg = MemArg::new(
      if value64 {
        3U
      } else {
        2U
      },
      Some(memory),
      offset,
    )
    let address = if memory64 {
      Instruction::i64_const(I64(32L + ((seed >> 8) & 31UL).to_int64()))
    } else {
      Instruction::i32_const(I32(32 + ((seed >> 8) & 31UL).to_int()))
    }
    body.push(address)
    if value64 {
      body.push(Instruction::i64_const(I64(seed.reinterpret_as_int64())))
      body.push(Instruction::i64_store(memarg))
    } else {
      body.push(Instruction::i32_const(I32(seed.to_int())))
      body.push(Instruction::i32_store(memarg))
    }
    body.push(address)
    body.push(
      if value64 {
        Instruction::i64_load(memarg)
      } else {
        Instruction::i32_load(memarg)
      },
    )
    body.push(Instruction::drop())
    body.push(Instruction::memory_size(memory))
    body.push(Instruction::drop())
    let grow_delta = ((seed >> 2) & 1UL).to_int()
    body.push(
      if memory64 {
        Instruction::i64_const(I64(grow_delta.to_int64()))
      } else {
        Instruction::i32_const(I32(grow_delta))
      },
    )
    body.push(Instruction::memory_grow(memory))
    body.push(Instruction::drop())
  }
  Module::new()
  .with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_mem_sec(MemSec::new(memories))
  .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new(body))]))
  .with_export_sec(ExportSec::new(exports))
}

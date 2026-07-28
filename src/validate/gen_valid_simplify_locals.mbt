///|
fn gen_valid_is_simplify_locals_family_profile_config(
  config : GenValidConfig,
) -> Bool {
  config == GenValidConfig::for_profile(SimplifyLocalsFamilyCoverageProfile)
}

///|
fn gen_valid_simplify_locals_profile_family_ids(
  profile : GenValidProfile,
) -> Array[Int] {
  match profile {
    SimplifyLocalsFamilyCoverageProfile => {
      let ids : Array[Int] = []
      for id = 1; id <= 35; id = id + 1 {
        ids.push(id)
      }
      ids
    }
    _ => []
  }
}

///|
fn gen_valid_simplify_locals_family_profile_config() -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  GenValidConfig::{
    ..base,
    max_type_defs: 8,
    max_imports: 0,
    max_defined_funcs: 16,
    max_tables: 1,
    max_mems: 1,
    max_globals: 1,
    max_tags: 1,
    max_elems: 0,
    max_datas: 0,
    max_params: 2,
    max_results: 1,
    max_locals: 8,
    max_body_statements: 128,
    max_body_depth: 8,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_imports: false,
      allow_tables: true,
      allow_mems: true,
      allow_globals: true,
      allow_tags: true,
      allow_calls: true,
      allow_call_indirect: false,
      allow_tail_calls: false,
      allow_branch_heavy_control: true,
      allow_ref_types: true,
      allow_v128: false,
      allow_relaxed_simd: false,
      allow_atomics: false,
      allow_shared_memories: false,
      allow_memory64: false,
      allow_subtyping_topology: false,
      allow_name_custom_sections: false,
      allow_typed_body_generator: false,
      allow_ssa_nomerge_body_generator: false,
    },
  }
}

///|
fn gen_valid_simplify_locals_family_i32(
  seed : UInt64,
  salt : UInt64,
) -> @lib.I32 {
  I32(((seed ^ (salt * 0x9e3779b97f4a7c15UL)) % 100000UL + 1UL).to_int())
}

///|
fn gen_valid_simplify_locals_func_type(
  params : Array[ValType],
  results : Array[ValType],
) -> RecType {
  RecType::new(SubType::comp_type(CompType::func(params, results)))
}

///|
fn gen_valid_simplify_locals_family_profile_module(seed : UInt64) -> Module {
  let void_type = TypeIdx::new(0U)
  let i32_result_type = TypeIdx::new(1U)
  let i32_param_type = TypeIdx::new(2U)
  let ref_param_type = TypeIdx::new(3U)
  let helper_idx = FuncIdx::new(0U)
  let i32_local = ValType::i32()
  let funcref = ValType::funcref()
  let externref = ValType::externref()
  let memarg = MemArg::new(2U, None, 0UL)
  let c0 = gen_valid_simplify_locals_family_i32(seed, 1UL)
  let c1 = gen_valid_simplify_locals_family_i32(seed, 2UL)
  let c2 = gen_valid_simplify_locals_family_i32(seed, 3UL)
  let c3 = gen_valid_simplify_locals_family_i32(seed, 4UL)
  let c4 = gen_valid_simplify_locals_family_i32(seed, 5UL)
  let c5 = gen_valid_simplify_locals_family_i32(seed, 6UL)

  let helper = Func::new(
    Locals::empty(),
    Expr::new([Instruction::i32_const(c0)]),
  )

  // SL-01..03, SL-07..09, SL-24, and SL-32..33: read counting,
  // first/later-cycle sinking, tee/drop cleanup, overwrite preservation,
  // deferred cycles, and final dead-set cleanup.
  let local_traffic = Func::new(
    Locals::from_types([i32_local, i32_local, i32_local]),
    Expr::new([
      Instruction::i32_const(c1),
      Instruction::local_set(LocalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::drop(),
      Instruction::i32_const(c2),
      Instruction::local_set(LocalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::drop(),
      Instruction::i32_const(c3),
      Instruction::local_tee(LocalIdx::new(1U)),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
      Instruction::call(helper_idx),
      Instruction::local_set(LocalIdx::new(2U)),
      Instruction::call(helper_idx),
      Instruction::local_set(LocalIdx::new(2U)),
      Instruction::local_get(LocalIdx::new(2U)),
      Instruction::drop(),
      Instruction::i32_const(c4),
      Instruction::local_set(LocalIdx::new(1U)),
    ]),
  )

  // SL-04..05: nonesting copy retargeting and parent-position legality.
  let flat_parent = Func::new(
    Locals::from_types([i32_local, i32_local]),
    Expr::new([
      Instruction::i32_const(c1),
      Instruction::i32_const(c2),
      Instruction::i32_add(),
      Instruction::local_set(LocalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::local_set(LocalIdx::new(1U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
      Instruction::i32_const(c3),
      Instruction::i32_const(c4),
      Instruction::i32_add(),
      Instruction::local_set(LocalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::drop(),
    ]),
  )

  // SL-13..17 and SL-23: named-block exit collection, unsupported-target
  // boundary, block-result lifting, br_if ordering, and structure-created tee.
  let block_result = Func::new(
    Locals::from_types([i32_local]),
    Expr::new([
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::i32_const(c1),
          Instruction::local_set(LocalIdx::new(1U)),
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::br_if(LabelIdx::new(0U)),
          Instruction::i32_const(c2),
          Instruction::local_set(LocalIdx::new(1U)),
        ]),
      ),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::ref_null(HeapType::abs(AbsHeapType::extern_())),
          Instruction::br_on_null(LabelIdx::new(0U)),
          Instruction::drop(),
        ]),
      ),
    ]),
  )

  // SL-18..21 and SL-23: two-arm, one-reachable-arm, one-arm speculative,
  // defaultability, and enlargement-equivalent result-slot behavior.
  let if_results = Func::new(
    Locals::from_types([i32_local]),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::if_(
        BlockType::void_(),
        [Instruction::i32_const(c1), Instruction::local_set(LocalIdx::new(1U))],
        Some([
          Instruction::i32_const(c2),
          Instruction::local_set(LocalIdx::new(1U)),
        ]),
      ),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::if_(
        BlockType::void_(),
        [Instruction::return_()],
        Some([
          Instruction::i32_const(c3),
          Instruction::local_set(LocalIdx::new(1U)),
        ]),
      ),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::if_(
        BlockType::void_(),
        [Instruction::i32_const(c4), Instruction::local_set(LocalIdx::new(1U))],
        None,
      ),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
    ]),
  )

  // SL-22..23: narrow loop-result lifting.
  let loop_result = Func::new(
    Locals::from_types([i32_local]),
    Expr::new([
      Instruction::loop_(
        BlockType::void_(),
        Expr::new([
          Instruction::i32_const(c5),
          Instruction::local_set(LocalIdx::new(0U)),
          Instruction::nop(),
        ]),
      ),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::drop(),
    ]),
  )

  // SL-25..31: equivalence classes, transparent block fallthrough,
  // equivalent-set removal policy, representative selection, and adjacent
  // block connectivity.
  let equivalent_sets = Func::new(
    Locals::from_types([i32_local, i32_local, i32_local]),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::local_set(LocalIdx::new(1U)),
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::local_get(LocalIdx::new(1U)),
          Instruction::local_set(LocalIdx::new(2U)),
        ]),
      ),
      Instruction::local_get(LocalIdx::new(2U)),
      Instruction::local_set(LocalIdx::new(1U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::drop(),
    ]),
  )

  // SL-10 and the local/global/memory/table/call legality domains.
  let effect_order = Func::new(
    Locals::from_types([i32_local, funcref]),
    Expr::new([
      Instruction::global_get(GlobalIdx::new(0U)),
      Instruction::local_set(LocalIdx::new(0U)),
      Instruction::i32_const(c1),
      Instruction::global_set(GlobalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::drop(),
      Instruction::i32_const(I32(0)),
      Instruction::i32_load(memarg),
      Instruction::local_set(LocalIdx::new(0U)),
      Instruction::i32_const(I32(4)),
      Instruction::i32_load(memarg),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::drop(),
      Instruction::i32_const(I32(0)),
      Instruction::i32_load(memarg),
      Instruction::local_set(LocalIdx::new(0U)),
      Instruction::i32_const(I32(0)),
      Instruction::i32_const(c2),
      Instruction::i32_store(memarg),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::drop(),
      Instruction::i32_const(I32(0)),
      Instruction::table_get(TableIdx::new(0U)),
      Instruction::local_set(LocalIdx::new(1U)),
      Instruction::nop(),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
      Instruction::i32_const(I32(0)),
      Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
      Instruction::table_set(TableIdx::new(0U)),
      Instruction::call(helper_idx),
      Instruction::drop(),
    ]),
  )

  // SL-09, SL-11..12: may-throw try_table boundary and fresh nonlinear state.
  let eh_boundaries = Func::new(
    Locals::from_types([i32_local, i32_local]),
    Expr::new([
      Instruction::call(helper_idx),
      Instruction::local_set(LocalIdx::new(0U)),
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::try_table(
            BlockType::void_(),
            [Catch::new(TagIdx::new(0U), LabelIdx::new(0U))],
            Expr::new([
              Instruction::local_get(LocalIdx::new(0U)),
              Instruction::drop(),
            ]),
          ),
        ]),
      ),
      Instruction::i32_const(c3),
      Instruction::local_set(LocalIdx::new(1U)),
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::try_table(
            BlockType::void_(),
            [Catch::new(TagIdx::new(0U), LabelIdx::new(0U))],
            Expr::new([
              Instruction::local_get(LocalIdx::new(1U)),
              Instruction::drop(),
            ]),
          ),
        ]),
      ),
    ]),
  )

  // SL-06, SL-21, SL-30, SL-34..35: refined replacement, defaultability,
  // representative type preference, refinalization, and nondefaultable fixups.
  let refined_types = Func::new(
    Locals::from_types([externref]),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::ref_as_non_null(),
      Instruction::local_set(LocalIdx::new(1U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::ref_as_non_null(),
      Instruction::drop(),
    ]),
  )

  let func_types = [
    i32_result_type, void_type, void_type, i32_param_type, i32_param_type, void_type,
    i32_param_type, void_type, void_type, ref_param_type,
  ]
  Module::new()
  .with_type_sec(
    TypeSec::new([
      gen_valid_simplify_locals_func_type([], []),
      gen_valid_simplify_locals_func_type([], [i32_local]),
      gen_valid_simplify_locals_func_type([i32_local], []),
      gen_valid_simplify_locals_func_type([externref], []),
    ]),
  )
  .with_func_sec(FuncSec::new(func_types))
  .with_table_sec(
    TableSec::new([
      Table::new(
        TableType::new(
          RefType::new(true, HeapType::abs(AbsHeapType::func())),
          Limits::i32(1U, Some(1U)),
        ),
        None,
      ),
    ]),
  )
  .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1U, None))]))
  .with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(i32_local, true),
        Expr::new([Instruction::i32_const(I32(0))]),
      ),
    ]),
  )
  .with_tag_sec(TagSec::new([TagType::new(void_type)]))
  .with_code_sec(
    CodeSec::new([
      helper, local_traffic, flat_parent, block_result, if_results, loop_result,
      equivalent_sets, effect_order, eh_boundaries, refined_types,
    ]),
  )
}

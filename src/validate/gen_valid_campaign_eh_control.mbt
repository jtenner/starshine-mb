///|
fn gen_valid_campaign_eh_control_config() -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  GenValidConfig::{
    ..base,
    max_type_defs: 3,
    max_imports: 0,
    max_defined_funcs: 1,
    max_tables: 0,
    max_mems: 0,
    max_globals: 0,
    max_tags: 2,
    max_elems: 0,
    max_datas: 0,
    max_params: 0,
    max_results: 2,
    max_locals: 0,
    max_body_statements: 581,
    max_body_depth: 4,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_imports: false,
      allow_tables: false,
      allow_mems: false,
      allow_globals: false,
      allow_tags: true,
      allow_elems: false,
      allow_datas: false,
      allow_ref_types: true,
      allow_calls: false,
      allow_call_indirect: false,
      allow_tail_calls: false,
      allow_branch_heavy_control: true,
      allow_v128: false,
      allow_relaxed_simd: false,
      allow_atomics: false,
      allow_shared_memories: false,
      allow_memory64: false,
      allow_subtyping_topology: false,
      allow_name_custom_sections: false,
      allow_typed_body_generator: false,
      allow_ssa_nomerge_body_generator: false,
      allow_heap_store_optimization_body_generator: false,
      allow_heap2local_body_generator: false,
    },
  }
}

///|
fn gen_valid_campaign_eh_control_tagged_throw(
  seed : UInt64,
  tag : TagIdx,
) -> Expr {
  if (seed & 8UL) == 0UL {
    Expr::new([Instruction::throw_(tag)])
  } else {
    Expr::new([
      Instruction::block(
        BlockType::void_(),
        Expr::new([Instruction::throw_(tag)]),
      ),
    ])
  }
}

///|
fn gen_valid_campaign_eh_control_ref_throw(seed : UInt64) -> Expr {
  let exn = HeapType::abs(AbsHeapType::exn())
  if (seed & 8UL) == 0UL {
    Expr::new([Instruction::ref_null(exn), Instruction::throw_ref()])
  } else {
    Expr::new([
      Instruction::block(
        BlockType::val_type(ValType::ref_null_exn()),
        Expr::new([Instruction::ref_null(exn)]),
      ),
      Instruction::throw_ref(),
    ])
  }
}

///|
fn gen_valid_campaign_eh_control_module(ctx : GenValidContext) -> Module {
  let seed = ctx.root_seed
  let variant = (seed % 8UL).to_int()
  let tag = TagIdx::new(0U)
  let payload_tag = TagIdx::new(1U)
  let depth0 = LabelIdx::new(0U)
  let exn_result = BlockType::val_type(ValType::ref_null_exn())
  let payload = Instruction::i32_const(I32(((seed >> 3) & 0xffffUL).to_int()))
  let body = match variant {
    0 =>
      [
        Instruction::block(
          BlockType::void_(),
          Expr::new([
            Instruction::try_table(
              BlockType::void_(),
              [Catch::new(tag, depth0)],
              gen_valid_campaign_eh_control_tagged_throw(seed, tag),
            ),
          ]),
        ),
      ]
    1 =>
      [
        Instruction::block(
          exn_result,
          Expr::new([
            Instruction::try_table(
              BlockType::void_(),
              [Catch::ref_(tag, depth0)],
              gen_valid_campaign_eh_control_tagged_throw(seed, tag),
            ),
            Instruction::ref_null(HeapType::abs(AbsHeapType::exn())),
          ]),
        ),
        Instruction::drop(),
      ]
    2 =>
      [
        Instruction::block(
          BlockType::void_(),
          Expr::new([
            Instruction::try_table(
              BlockType::void_(),
              [Catch::all(depth0)],
              gen_valid_campaign_eh_control_ref_throw(seed),
            ),
          ]),
        ),
      ]
    3 =>
      [
        Instruction::block(
          exn_result,
          Expr::new([
            Instruction::try_table(
              exn_result,
              [Catch::all_ref(depth0)],
              gen_valid_campaign_eh_control_ref_throw(seed),
            ),
          ]),
        ),
        Instruction::drop(),
      ]
    4 =>
      [
        Instruction::block(
          BlockType::void_(),
          Expr::new([
            Instruction::block(
              BlockType::void_(),
              Expr::new([
                Instruction::try_table(
                  BlockType::void_(),
                  [Catch::new(tag, LabelIdx::new(1U))],
                  gen_valid_campaign_eh_control_tagged_throw(seed, tag),
                ),
              ]),
            ),
          ]),
        ),
      ]
    5 =>
      [
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::try_table(
              BlockType::void_(),
              [Catch::new(payload_tag, depth0)],
              Expr::new([payload, Instruction::throw_(payload_tag)]),
            ),
            Instruction::i32_const(I32(0)),
          ]),
        ),
        Instruction::drop(),
      ]
    6 =>
      [
        Instruction::try_(
          BlockType::void_(),
          Expr::new([Instruction::throw_(tag)]),
          [
            @lib.LegacyCatch::tagged(
              tag,
              Expr::new([Instruction::rethrow(depth0)]),
            ),
          ],
        ),
      ]
    _ =>
      [
        Instruction::block(
          BlockType::type_idx(TypeIdx::new(2U)),
          Expr::new([
            Instruction::block(
              BlockType::type_idx(TypeIdx::new(2U)),
              Expr::new([
                payload,
                Instruction::i32_const(I32(((seed >> 3) & 0xffUL).to_int())),
                Instruction::i32_const(I32(((seed >> 4) & 1UL).to_int())),
                Instruction::br_table(
                  [LabelIdx::new(0U), LabelIdx::new(1U)],
                  LabelIdx::new(1U),
                ),
              ]),
            ),
          ]),
        ),
        Instruction::drop(),
        Instruction::drop(),
      ]
  }
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([], []))),
      RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
      RecType::new(
        SubType::comp_type(CompType::func([], [ValType::i32(), ValType::i32()])),
      ),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_tag_sec(
    TagSec::new([TagType::new(TypeIdx::new(0U)), TagType::new(TypeIdx::new(1U))]),
  )
  .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new(body))]))
}

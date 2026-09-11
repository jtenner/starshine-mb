///|
fn gen_valid_descriptor_branches_config() -> GenValidConfig {
  let base = gen_valid_array_memory_config()
  GenValidConfig::{
    ..base,
    max_type_defs: 3,
    max_params: 2,
    max_locals: 1,
    max_globals: 1,
    max_body_statements: 464,
  }
}

///|
fn gen_valid_descriptor_branches_module(ctx : GenValidContext) -> Module {
  let seed = if ctx.use_named_streams {
    ctx.root_seed
  } else {
    ctx.rnd.next_uint64()
  }
  let fail_branch = (seed & 1UL) != 0UL
  let exact = (seed & 2UL) != 0UL
  let nullable = (seed & 4UL) != 0UL
  let null_descriptor = (seed & 8UL) != 0UL
  let unreachable_source = (seed & 16UL) != 0UL
  let refine_local = (seed & 32UL) != 0UL
  let nested_target = (seed & 64UL) != 0UL
  let object_index = TypeIdx::new(0U)
  let descriptor_index = TypeIdx::new(1U)
  let source = RefType::new(true, HeapType::new(object_index))
  let target = RefType::new(
    if refine_local {
      !fail_branch
    } else {
      nullable
    },
    HeapType::new(object_index),
    exact~,
  )
  let descriptor = RefType::new(true, HeapType::new(descriptor_index), exact~)
  let label = LabelIdx::new(if nested_target { 1U } else { 0U })
  let branch = if fail_branch {
    Instruction::br_on_cast_desc_eq_fail(label, source, target)
  } else {
    Instruction::br_on_cast_desc_eq(label, source, target)
  }
  let body = [
    if unreachable_source {
      Instruction::unreachable_()
    } else {
      Instruction::local_get(LocalIdx::new(0U))
    },
    if refine_local {
      Instruction::block(
        BlockType::val_type(
          ValType::ref_type(
            RefType::new(false, HeapType::new(descriptor_index), exact~),
          ),
        ),
        Expr::new([
          Instruction::ref_null(HeapType::abs(AbsHeapType::none())),
          Instruction::ref_as_non_null(),
        ]),
      )
    } else if null_descriptor {
      Instruction::ref_null(HeapType::abs(AbsHeapType::none()))
    } else {
      Instruction::local_get(LocalIdx::new(1U))
    },
    branch,
  ]
  if refine_local {
    body.push(Instruction::local_set(LocalIdx::new(2U)))
    body.push(Instruction::unreachable_())
  }
  let block_type = BlockType::val_type(ValType::ref_type(source))
  let increment = fn(amount : Int) {
    [
      Instruction::global_get(GlobalIdx::new(0U)),
      Instruction::i32_const(I32(amount)),
      Instruction::i32_add(),
      Instruction::global_set(GlobalIdx::new(0U)),
    ]
  }
  let outer_body = if nested_target {
    let inner = [Instruction::block(block_type, Expr::new(body))]
    inner.append(increment(1))
    inner
  } else {
    body
  }
  let roots = [Instruction::block(block_type, Expr::new(outer_body))]
  if nested_target {
    // A wrong label can skip either write. Preserve the reference stack value
    // across both updates so label remapping and lifetime capture are exercised.
    roots.append(increment(10))
  }
  let mod_ = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::group([
          SubType::new(
            false,
            [],
            CompType::struct_([]),
            metadata=TypeMetadata::new(descriptor=Some(descriptor_index)),
          ),
          SubType::new(
            false,
            [],
            CompType::struct_([]),
            metadata=TypeMetadata::new(describes=Some(object_index)),
          ),
        ]),
        RecType::new(
          SubType::comp_type(
            CompType::func(
              [ValType::ref_type(source), ValType::ref_type(descriptor)],
              [ValType::ref_type(source)],
            ),
          ),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(2U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          if refine_local {
            Locals::from_types([
              ValType::ref_type(
                RefType::new(false, HeapType::new(object_index)),
              ),
            ])
          } else {
            Locals::empty()
          },
          Expr::new(roots),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
      ]),
    )
  if nested_target {
    mod_
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), true),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
        Export::new(
          Name::from_string("branch-effects"),
          ExternIdx::global(GlobalIdx::new(0U)),
        ),
      ]),
    )
  } else {
    mod_
  }
}

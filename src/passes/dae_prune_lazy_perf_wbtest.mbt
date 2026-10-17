///|
fn dae_prune_lazy_reference_instr(
  instr : @lib.Instruction,
  remap : Array[Int32],
) -> @lib.Instruction {
  let rewrite_block_type = fn(block_type : @lib.BlockType) -> @lib.BlockType {
    match block_type {
      @lib.TypeIdxBlockType(type_idx) =>
        @lib.BlockType::type_idx(dae_rewrite_pruned_type_idx(type_idx, remap))
      @lib.ValTypeBlockType(val_type) =>
        @lib.BlockType::val_type(dae_rewrite_pruned_val_type(val_type, remap))
      _ => block_type
    }
  }
  match instr {
    @lib.Block(block_type, @lib.Expr(body)) =>
      @lib.Instruction::block(
        rewrite_block_type(block_type),
        @lib.Expr::new(dae_prune_lazy_reference_instrs(body, remap)),
      )
    @lib.Loop(block_type, @lib.Expr(body)) =>
      @lib.Instruction::loop_(
        rewrite_block_type(block_type),
        @lib.Expr::new(dae_prune_lazy_reference_instrs(body, remap)),
      )
    @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
      @lib.Instruction::try_table(
        rewrite_block_type(block_type),
        catches,
        @lib.Expr::new(dae_prune_lazy_reference_instrs(body, remap)),
      )
    @lib.Try(block_type, @lib.Expr(body), catches, delegate) => {
      let rewritten_catches : Array[@lib.LegacyCatch] = []
      for catch_ in catches {
        match catch_ {
          @lib.LegacyCatch(tag_idx, @lib.Expr(catch_body)) =>
            rewritten_catches.push(
              @lib.LegacyCatch::tagged(
                tag_idx,
                @lib.Expr::new(
                  dae_prune_lazy_reference_instrs(catch_body, remap),
                ),
              ),
            )
          @lib.LegacyCatchAll(@lib.Expr(catch_body)) =>
            rewritten_catches.push(
              @lib.LegacyCatch::all(
                @lib.Expr::new(
                  dae_prune_lazy_reference_instrs(catch_body, remap),
                ),
              ),
            )
        }
      }
      @lib.Instruction::try_(
        rewrite_block_type(block_type),
        @lib.Expr::new(dae_prune_lazy_reference_instrs(body, remap)),
        rewritten_catches,
        delegate~,
      )
    }
    @lib.If(block_type, then_body, else_body) =>
      @lib.Instruction::if_(
        rewrite_block_type(block_type),
        dae_prune_lazy_reference_instrs(then_body, remap),
        match else_body {
          Some(body) => Some(dae_prune_lazy_reference_instrs(body, remap))
          None => None
        },
      )
    @lib.CallIndirect(type_idx, table_idx) =>
      @lib.Instruction::call_indirect(
        dae_rewrite_pruned_type_idx(type_idx, remap),
        table_idx,
      )
    @lib.ReturnCallIndirect(type_idx, table_idx) =>
      @lib.Instruction::return_call_indirect(
        dae_rewrite_pruned_type_idx(type_idx, remap),
        table_idx,
      )
    @lib.CallRef(type_idx) =>
      @lib.Instruction::call_ref(dae_rewrite_pruned_type_idx(type_idx, remap))
    @lib.ReturnCallRef(type_idx) =>
      @lib.Instruction::return_call_ref(
        dae_rewrite_pruned_type_idx(type_idx, remap),
      )
    @lib.ContNew(type_idx) =>
      @lib.Instruction::cont_new(dae_rewrite_pruned_type_idx(type_idx, remap))
    @lib.ContBind(source_type, target_type) =>
      @lib.Instruction::cont_bind(
        dae_rewrite_pruned_type_idx(source_type, remap),
        dae_rewrite_pruned_type_idx(target_type, remap),
      )
    @lib.Resume(type_idx, handlers) =>
      @lib.Instruction::resume_(
        dae_rewrite_pruned_type_idx(type_idx, remap),
        handlers,
      )
    @lib.ResumeThrow(type_idx, tag, handlers) =>
      @lib.Instruction::resume_throw(
        dae_rewrite_pruned_type_idx(type_idx, remap),
        tag,
        handlers,
      )
    @lib.ResumeThrowRef(type_idx, handlers) =>
      @lib.Instruction::resume_throw_ref(
        dae_rewrite_pruned_type_idx(type_idx, remap),
        handlers,
      )
    @lib.StackSwitch(type_idx, tag) =>
      @lib.Instruction::stack_switch(
        dae_rewrite_pruned_type_idx(type_idx, remap),
        tag,
      )
    @lib.Select(Some(types)) =>
      @lib.Instruction::select(
        types=Some(types.map(fn(vt) { dae_rewrite_pruned_val_type(vt, remap) })),
      )
    @lib.RefNull(rt) =>
      @lib.Instruction::ref_null_type(dae_rewrite_pruned_ref_type(rt, remap))
    @lib.RefGetDesc(type_idx) =>
      @lib.Instruction::ref_get_desc(
        dae_rewrite_pruned_type_idx(type_idx, remap),
      )
    @lib.RefTest(nullable, exact, ht) =>
      @lib.Instruction::ref_test_type(
        @lib.RefType::new(
          nullable,
          dae_rewrite_pruned_heap_type(ht, remap),
          exact~,
        ),
      )
    @lib.RefCast(nullable, exact, ht) =>
      @lib.Instruction::ref_cast_type(
        @lib.RefType::new(
          nullable,
          dae_rewrite_pruned_heap_type(ht, remap),
          exact~,
        ),
      )
    @lib.RefTestDesc(nullable, ht) =>
      @lib.Instruction::ref_test_desc(
        nullable,
        dae_rewrite_pruned_heap_type(ht, remap),
      )
    @lib.RefCastDescEq(nullable, exact, ht) =>
      @lib.Instruction::ref_cast_desc_eq_type(
        @lib.RefType::new(
          nullable,
          dae_rewrite_pruned_heap_type(ht, remap),
          exact~,
        ),
      )
    @lib.BrOnCast(
      label,
      @lib.CastOp(source_nullable, target_nullable, source_exact, target_exact),
      source_type,
      target_type
    ) =>
      @lib.Instruction::br_on_cast(
        label,
        source_nullable,
        dae_rewrite_pruned_heap_type(source_type, remap),
        target_nullable,
        dae_rewrite_pruned_heap_type(target_type, remap),
        source_exact~,
        target_exact~,
      )
    @lib.BrOnCastFail(
      label,
      @lib.CastOp(source_nullable, target_nullable, source_exact, target_exact),
      source_type,
      target_type
    ) =>
      @lib.Instruction::br_on_cast_fail(
        label,
        source_nullable,
        dae_rewrite_pruned_heap_type(source_type, remap),
        target_nullable,
        dae_rewrite_pruned_heap_type(target_type, remap),
        source_exact~,
        target_exact~,
      )
    @lib.BrOnCastDescEq(label, source_type, target_type) =>
      @lib.Instruction::br_on_cast_desc_eq(
        label,
        dae_rewrite_pruned_ref_type(source_type, remap),
        dae_rewrite_pruned_ref_type(target_type, remap),
      )
    @lib.BrOnCastDescEqFail(label, source_type, target_type) =>
      @lib.Instruction::br_on_cast_desc_eq_fail(
        label,
        dae_rewrite_pruned_ref_type(source_type, remap),
        dae_rewrite_pruned_ref_type(target_type, remap),
      )
    _ => instr
  }
}

///|
fn dae_prune_lazy_reference_instrs(
  instrs : Array[@lib.Instruction],
  remap : Array[Int32],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    out.push(dae_prune_lazy_reference_instr(instr, remap))
  }
  out
}

///|
fn dae_prune_lazy_fixture(
  depth : Int32,
  width : Int32,
  mode : Int32,
) -> Array[@lib.Instruction] {
  let leaf = Array::makei(width, fn(index) {
    if mode == 1 || (mode == 2 && index % 16 == 0) {
      @lib.Instruction::call_ref(@lib.TypeIdx::new(2U))
    } else {
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
    }
  })
  let mut body = leaf
  for level in 0..<depth {
    body = [
      @lib.Instruction::block(
        if mode == 1 {
          @lib.BlockType::type_idx(@lib.TypeIdx::new(2U))
        } else {
          @lib.BlockType::void_()
        },
        @lib.Expr::new(body),
      ),
      @lib.Instruction::loop_(
        @lib.BlockType::void_(),
        @lib.Expr::new(if level % 2 == 0 { leaf } else { [] }),
      ),
    ]
  }
  body
}

///|
fn dae_prune_lazy_bench(it : @bench.T, mode : Int32, reference : Bool) -> Unit {
  let input = dae_prune_lazy_fixture(16, 128, mode)
  let remap = [0, 1, 1]
  let expected = dae_prune_lazy_reference_instrs(input, remap)
  if dae_rewrite_pruned_type_idx_instrs(input, remap) != expected {
    abort("DAE lazy type-remap fixture differs from original rewrite")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        dae_prune_lazy_reference_instrs(input, remap)
      } else {
        dae_rewrite_pruned_type_idx_instrs(input, remap)
      },
    )
  })
}

///|
#skip("paired native type-prune cost; dedicated performance lane")
test "bench DAE prune type-free reference" (it : @bench.T) {
  dae_prune_lazy_bench(it, 0, true)
}

///|
#skip("paired native type-prune cost; dedicated performance lane")
test "bench DAE prune type-free candidate" (it : @bench.T) {
  dae_prune_lazy_bench(it, 0, false)
}

///|
#skip("paired native type-prune cost; dedicated performance lane")
test "bench DAE prune dense reference" (it : @bench.T) {
  dae_prune_lazy_bench(it, 1, true)
}

///|
#skip("paired native type-prune cost; dedicated performance lane")
test "bench DAE prune dense candidate" (it : @bench.T) {
  dae_prune_lazy_bench(it, 1, false)
}

///|
#skip("paired native type-prune cost; dedicated performance lane")
test "bench DAE prune sparse reference" (it : @bench.T) {
  dae_prune_lazy_bench(it, 2, true)
}

///|
#skip("paired native type-prune cost; dedicated performance lane")
test "bench DAE prune sparse candidate" (it : @bench.T) {
  dae_prune_lazy_bench(it, 2, false)
}

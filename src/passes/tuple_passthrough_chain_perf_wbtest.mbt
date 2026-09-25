///|
fn tuple_passthrough_chain_fixture(
  depth : Int,
) -> (@ir.HotFunc, @ir.HotUseDef, Int) {
  let instrs : Array[@lib.Instruction] = [
    @lib.Instruction::i32_const(@lib.I32(7)),
  ]
  let locals : Array[@lib.ValType] = []
  for idx in 0..<depth {
    locals.push(@lib.ValType::i32())
    instrs.push(@lib.Instruction::local_tee(@lib.LocalIdx::new(idx.to_uint())))
  }
  locals.push(@lib.ValType::i32())
  instrs.push(@lib.Instruction::local_set(@lib.LocalIdx::new(depth.to_uint())))
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::from_types(locals), @lib.Expr::new(instrs)),
      ]),
    )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let use_def = @ir.use_def_build(func)
  let mut target_id = -1
  for node_id in 0..<@ir.hot_node_count(func) {
    if @ir.hot_node_get(func, node_id).op is @ir.HotOp::Const {
      target_id = node_id
      break
    }
  }
  if target_id < 0 {
    abort("passthrough fixture has no constant target")
  }
  (func, use_def, target_id)
}

///|
fn tuple_passthrough_chain_bench(it : @bench.T, depth : Int) -> Unit {
  let (func, use_def, target_id) = tuple_passthrough_chain_fixture(depth)
  match
    tuple_optimization_find_passthrough_root_chain(func, use_def, target_id) {
    Some(chain) if chain.length() == depth + 1 => ()
    _ => abort("passthrough fixture did not reach root")
  }
  it.bench(fn() {
    it.keep(
      tuple_optimization_find_passthrough_root_chain(func, use_def, target_id),
    )
  })
}

///|
test "TupleOptimization keeps passthrough chain order" {
  let (func, use_def, target_id) = tuple_passthrough_chain_fixture(8)
  match
    tuple_optimization_find_passthrough_root_chain(func, use_def, target_id) {
    Some(chain) => {
      assert_eq(chain.length(), 9)
      for idx in 0..<8 {
        let node = @ir.hot_node_get(func, chain[idx])
        assert_true(node.op is @ir.HotOp::LocalTee)
        assert_eq(node.imm0, idx)
      }
      let last = @ir.hot_node_get(func, chain[8])
      assert_true(last.op is @ir.HotOp::LocalSet)
      assert_eq(last.imm0, 8)
    }
    None => fail("expected passthrough chain")
  }
}

///|
test "bench tuple passthrough chain depth=128" (it : @bench.T) {
  tuple_passthrough_chain_bench(it, 128)
}

///|
test "bench tuple passthrough chain depth=256" (it : @bench.T) {
  tuple_passthrough_chain_bench(it, 256)
}

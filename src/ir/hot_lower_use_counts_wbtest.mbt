///|
fn lower_use_counts_assert_equivalent(func : HotFunc) -> Unit raise {
  let revision = hot_revision_current(func)
  let sites = use_def_build_node_uses(func)
  let counts = hot_node_use_counts_build(func)
  for node in 0..<hot_node_count(func) {
    assert_eq(hot_node_use_count(counts, node), node_use_count(sites, node))
  }
  assert_eq(hot_revision_current(func), revision)
}

///|
test "lower compact counts preserve nested control root and operand multiplicity" {
  for
    wat in [
      "(module (func (param i32) (result i32) block (result i32) local.get 0 i32.const 7 i32.add end))",
      "(module (func (param i32) (result i32) local.get 0 if (result i32) i32.const 7 else i32.const 9 end))",
      "(module (func (param i32) (result i32) block (result i32) loop (result i32) local.get 0 br 1 end end))",
      "(module (type (func (param i32) (result i32))) (func (param i32) (result i32) local.get 0 block (type 0) i32.const 7 i32.add end))",
      "(module (func (result i32) try_table (result i32) i32.const 7 end))", "(module (type (struct (field i32))) (func (param (ref null 0)) (result i32) local.get 0 struct.get 0 0))",
    ] {
    let input = @wast.wast_to_binary_module(wat).unwrap()
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let lifted = hot_lift_func(input, @lib.FuncIdx::new(0U))
    lower_use_counts_assert_equivalent(lifted)
    let output = input.with_code_sec(
      @lib.CodeSec::new([hot_lower_func(lifted)]),
    )
    @validate.validate_module(output).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "lower compact counts preserve shared operands repeated roots and orphan nodes" {
  let func = HotFunc::new()
  let leaf = hot_build_const_i32(func, @lib.I32(7))
  let shared = hot_build_binary(func, @lib.ValType::i32(), leaf, leaf)
  let unused = hot_build_const_i32(func, @lib.I32(9))
  let dead = hot_build_nop(func)
  hot_delete_node(func, dead)
  hot_root_append(func, shared)
  hot_root_append(func, shared)
  lower_use_counts_assert_equivalent(func)
  let counts = hot_node_use_counts_build(func)
  assert_eq(hot_node_use_count(counts, shared), 2)
  assert_eq(hot_node_use_count(counts, leaf), 2)
  assert_eq(hot_node_use_count(counts, unused), 0)
  assert_eq(hot_node_use_count(counts, dead), 0)
}

///|
test "lower compact counts remain independent across changed root snapshots" {
  let func = HotFunc::new()
  let leaf = hot_build_const_i32(func, @lib.I32(7))
  hot_root_append(func, leaf)
  let old = hot_node_use_counts_build(func)
  hot_root_append(func, leaf)
  lower_use_counts_assert_equivalent(func)
  let fresh = hot_node_use_counts_build(func)
  assert_eq(hot_node_use_count(old, leaf), 1)
  assert_eq(hot_node_use_count(fresh, leaf), 2)
}

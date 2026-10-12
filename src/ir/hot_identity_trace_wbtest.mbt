///|
fn hot_identity_test_defined_func(
  mod_ : @lib.Module,
  code_index : Int,
) -> (Int, @lib.Func) {
  let defs = match mod_.code_sec {
    Some(@lib.CodeSec(defs)) => defs
    None => abort("identity fixture requires a code section")
  }
  let context = hot_module_context_from_module(mod_)
  (context.func_types.length() - defs.length() + code_index, defs[code_index])
}

///|
fn hot_identity_test_staged_roundtrip(
  mod_ : @lib.Module,
  code_index : Int,
) -> @lib.Module raise {
  @validate.validate_module(mod_).unwrap()
  let (absolute, _) = hot_identity_test_defined_func(mod_, code_index)
  let hot = hot_lift_func_with_context_result(
    mod_,
    @lib.FuncIdx::new(absolute.reinterpret_as_uint()),
    hot_module_context_from_module(mod_),
    capture_stack_locals=true,
    materialize_multi_values=true,
  ).unwrap()
  hot_verify_all(hot, cache=Some(())).unwrap()
  let cfg = cfg_build(hot, expand_operand_control=true)
  let uses = use_def_build(hot, cfg=Some(cfg))
  assert_true(cfg_block_count(cfg) > 0)
  for id in 0..<hot_node_count(hot) {
    assert_true(node_use_count(uses, id) >= 0)
  }
  // This entry is safe only because the explicit verifier above succeeded.
  let lowered = hot_lower_func_unverified(hot)
  let @lib.CodeSec(defs) = mod_.code_sec.unwrap()
  let next = defs.copy()
  next[code_index] = lowered
  let output = mod_.with_code_sec(@lib.CodeSec::new(next))
  @validate.validate_module(output).unwrap()
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  let fresh = hot_lift_func_with_context_result(
    decoded,
    @lib.FuncIdx::new(absolute.reinterpret_as_uint()),
    hot_module_context_from_module(decoded),
    capture_stack_locals=true,
    materialize_multi_values=true,
  ).unwrap()
  hot_verify_all(fresh, cache=Some(())).unwrap()
  let fresh_cfg = cfg_build(fresh, expand_operand_control=true)
  ignore(use_def_build(fresh, cfg=Some(fresh_cfg)))
  assert_true(cfg_block_count(fresh_cfg) > 0)
  output
}

///|
test "HOT identity trace stages typed entries tuples unreachable and loops" {
  for
    source in [
      "(module (import \"host\" \"pair\" (func (result i32 i64))) (func (result i64) (local i64) call 0 block (param i32 i64) (result i64) local.set 0 drop local.get 0 end))",
      "(module (import \"host\" \"value\" (func (result i32))) (import \"host\" \"condition\" (func (result i32))) (func (result i32) call 0 call 1 if (param i32) (result i32) i32.const 3 i32.add else i32.const 2 i32.add end))",
      "(module (func (result i32) unreachable i32.const 1 i32.const 2 block (param i32 i32) (result i32) i32.div_s end))",
      "(module (func (param i32) (result i32) local.get 0 loop (param i32) (result i32) i32.const 1 i32.sub end))",
    ] {
    let mod_ = @wast.wast_to_binary_module(source).unwrap()
    ignore(hot_identity_test_staged_roundtrip(mod_, 0))
  }
}

///|
test "HOT identity trace relifts supported handler repro from fresh bytes" {
  let bytes = @sfs.read_file_bytes(
    "tests/repros/simplify-locals-eh-catch-observed-write.wasm",
  ).unwrap()
  let mod_ = @binary.decode_module(bytes).unwrap()
  let output = hot_identity_test_staged_roundtrip(mod_, 0)
  @validate.validate_module(output).unwrap()
}

///|
test "HOT identity duplicate producer fault remains valid and observable" {
  let source = @wast.wast_to_binary_module(
    "(module (import \"host\" \"tick\" (func (result i32))) (func (export \"run\") call 0 drop))",
  ).unwrap()
  let (absolute, _) = hot_identity_test_defined_func(source, 0)
  let hot = hot_lift_func_with_context_result(
    source,
    @lib.FuncIdx::new(absolute.reinterpret_as_uint()),
    hot_module_context_from_module(source),
  ).unwrap()
  let duplicate = hot_build_call(hot, 0, [@lib.ValType::i32()], [])
  hot_root_append(hot, hot_build_drop(hot, duplicate))
  hot_verify_all(hot, cache=Some(())).unwrap()
  let lowered = hot_lower_func_unverified(hot)
  let output = source.with_code_sec(@lib.CodeSec::new([lowered]))
  @validate.validate_module(output).unwrap()
  let expected = @wast.wast_to_binary_module(
    "(module (import \"host\" \"tick\" (func (result i32))) (func (export \"run\") call 0 drop call 0 drop))",
  ).unwrap()
  assert_eq(output.code_sec, expected.code_sec)
}

///|
test "HOT identity label retarget fault stays valid but changes the result path" {
  let original = @wast.wast_to_binary_module(
    "(module (func (export \"run\") (result i32) block (result i32) block (result i32) i32.const 7 br 0 end i32.const 1 i32.add end))",
  ).unwrap()
  let (absolute, _) = hot_identity_test_defined_func(original, 0)
  let hot = hot_lift_func_with_context_result(
    original,
    @lib.FuncIdx::new(absolute.reinterpret_as_uint()),
    hot_module_context_from_module(original),
  ).unwrap()
  let labels : Array[LabelId] = []
  let mut branch = HOT_NONE_NODE
  for id in 0..<hot_node_count(hot) {
    let node = hot_node_get(hot, id)
    if node.op is HotOp::Block {
      labels.push(node.imm0)
    } else if node.op is HotOp::Br {
      branch = id
    }
  }
  assert_eq(labels.length(), 2)
  assert_true(branch >= 0)
  let old = hot_node_get(hot, branch)
  let target = if old.imm0 == labels[0] { labels[1] } else { labels[0] }
  hot_node_set(hot, branch, { ..old, imm0: target, })
  hot_verify_all(hot, cache=Some(())).unwrap()
  let output = original.with_code_sec(
    @lib.CodeSec::new([hot_lower_func_unverified(hot)]),
  )
  @validate.validate_module(output).unwrap()
  let changed = @wast.wast_to_binary_module(
    "(module (func (export \"run\") (result i32) block (result i32) block (result i32) i32.const 7 br 1 end i32.const 1 i32.add end))",
  ).unwrap()
  assert_eq(output.code_sec, changed.code_sec)
  assert_true(output.code_sec != original.code_sec)
}

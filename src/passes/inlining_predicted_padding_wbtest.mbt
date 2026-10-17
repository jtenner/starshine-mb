///|
// Frozen allocation baseline from inlining.mbt at a61c3e418f43a469b480febc4ad590310c1451a1.
fn inl_padding_frozen_reference(
  mod_ : @lib.Module,
  predicted : @hashmap.HashMap[String, Int32],
) -> @lib.Module {
  let old_type_idxs = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs
    None => return mod_
  }
  let old_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let type_for_sig = inl_signature_type_idx_map(mod_)
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let imports = inl_imported_func_count(mod_)
  let current : @hashmap.HashMap[String, Int32] = @hashmap.new()
  let mut def_idx = 0
  while def_idx < old_funcs.length() {
    inl_hash_inc_int(
      current,
      inl_func_signature_key(mod_, func_type_indices, imports + def_idx),
    )
    def_idx += 1
  }
  let next_type_idxs : Array[@lib.TypeIdx] = []
  next_type_idxs.append(old_type_idxs)
  let next_funcs : Array[@lib.Func] = []
  next_funcs.append(old_funcs)
  let mut changed = false
  for key in predicted.keys() {
    let want = inl_hash_get_int(predicted, key)
    let mut have = inl_hash_get_int(current, key)
    match type_for_sig.get(key) {
      Some(type_idx) =>
        while have < want {
          next_type_idxs.push(type_idx)
          next_funcs.push(
            @lib.Func::new(
              @lib.Locals::empty(),
              @lib.Expr::new([@lib.Instruction::unreachable_()]),
            ),
          )
          have += 1
          changed = true
        }
      None => ()
    }
  }
  if changed {
    mod_
    .with_func_sec(@lib.FuncSec::new(next_type_idxs))
    .with_code_sec(@lib.CodeSec::new(next_funcs))
  } else {
    mod_
  }
}

///|
fn inl_padding_regression_fixture() -> @lib.Module {
  let source =
    #|(module
    #| (type $void (func))
    #| (type $unary (func (param i32) (result i32)))
    #| (type $wide (func (result i64)))
    #| (import "env" "tap" (func (type $void)))
    #| (func (export "run") (type $void) nop)
    #| (func (type $unary) local.get 0)
    #| (func (type $void) nop))
  pass_test_module_from_wat(source)
  .with_name_sec(
    @lib.NameSec::new(
      module_name=Some(@lib.Name::from_string("padding-source")),
    ),
  )
  .with_func_annotation_sec(
    @lib.FuncAnnotationSec::new([
      @lib.FuncAnnotationAssoc::new(1U, [
        @lib.FuncAnnotation::new("vendor.keep"),
      ]),
    ]),
  )
}

///|
fn inl_padding_compare_reference(
  input : @lib.Module,
  predicted : @hashmap.HashMap[String, Int32],
) -> @lib.Module raise {
  let before = @binary.encode_module(input).unwrap()
  let reference = inl_padding_frozen_reference(input, predicted)
  let actual = inl_pad_unreachable_to_predicted_counts(input, predicted)
  @debug.assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  @debug.assert_eq(@binary.encode_module(input).unwrap(), before)
  @debug.assert_eq(actual.name_sec, input.name_sec)
  @debug.assert_eq(actual.func_annotation_sec, input.func_annotation_sec)
  @debug.assert_eq(actual.import_sec, input.import_sec)
  @debug.assert_eq(actual.export_sec, input.export_sec)
  ignore(@validate.validate_module(actual).unwrap())
  actual
}

///|
test "inlining padding preserves input for empty and zero predictions" {
  let input = inl_padding_regression_fixture()
  let predicted : @hashmap.HashMap[String, Int32] = @hashmap.new()
  let empty = inl_padding_compare_reference(input, predicted)
  assert_true(physical_equal(empty, input))
  predicted.set("p:r:", 0)
  predicted.set("abs-type:999", -1)
  let zero = inl_padding_compare_reference(input, predicted)
  assert_true(physical_equal(zero, input))
}

///|
test "inlining padding keeps satisfied counts and unsupported signatures unchanged" {
  let input = inl_padding_regression_fixture()
  let predicted : @hashmap.HashMap[String, Int32] = @hashmap.new()
  predicted.set("p:r:", 2)
  predicted.set(
    inl_func_type_signature_key([@lib.ValType::i32()], [@lib.ValType::i32()]),
    1,
  )
  let satisfied = inl_padding_compare_reference(input, predicted)
  assert_true(physical_equal(satisfied, input))
  // No f64-result type exists. This signature is intentionally ineligible.
  predicted.set(inl_func_type_signature_key([], [@lib.ValType::f64()]), 4)
  let unsupported = inl_padding_compare_reference(input, predicted)
  assert_true(physical_equal(unsupported, input))
}

///|
test "inlining padding fills multiple signatures without changing existing functions or metadata" {
  let input = inl_padding_regression_fixture()
  let predicted : @hashmap.HashMap[String, Int32] = @hashmap.new()
  let unary = inl_func_type_signature_key([@lib.ValType::i32()], [
    @lib.ValType::i32(),
  ])
  let wide = inl_func_type_signature_key([], [@lib.ValType::i64()])
  predicted.set("p:r:", 4)
  predicted.set(unary, 3)
  predicted.set(wide, 1)
  // A missing ineligible signature must not suppress eligible padding.
  predicted.set(inl_func_type_signature_key([], [@lib.ValType::f64()]), 5)
  let output = inl_padding_compare_reference(input, predicted)
  let funcs = output.code_sec.unwrap().0
  @debug.assert_eq(funcs.length(), 8)
  for index in 0..<3 {
    @debug.assert_eq(funcs[index], input.code_sec.unwrap().0[index])
  }
  for index in 3..<funcs.length() {
    let @lib.Func(locals, _) = funcs[index]
    @debug.assert_eq(locals, @lib.Locals::empty())
    assert_true(inl_func_is_exact_unreachable(funcs[index]))
  }
  let indices = inl_collect_func_type_indices(output)
  let counts : @hashmap.HashMap[String, Int32] = @hashmap.new()
  for index in 0..<funcs.length() {
    inl_hash_inc_int(counts, inl_func_signature_key(output, indices, index + 1))
  }
  @debug.assert_eq(inl_hash_get_int(counts, "p:r:"), 4)
  @debug.assert_eq(inl_hash_get_int(counts, unary), 3)
  @debug.assert_eq(inl_hash_get_int(counts, wide), 1)
}

///|
fn inl_padding_shared_signature_fixture(
  type_count : Int32,
  func_count : Int32,
) -> @lib.Module {
  let (base, indices) = inl_signature_keys_perf_fixture(type_count, func_count)
  base
  .with_func_sec(@lib.FuncSec::new(indices))
  .with_code_sec(
    @lib.CodeSec::new(
      Array::makei(func_count, fn(_) {
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        )
      }),
    ),
  )
}

///|
test "inlining padding matches uncached signatures when functions share a type" {
  let input = inl_padding_shared_signature_fixture(8, 32)
  let indices = inl_collect_func_type_indices(input)
  let formatted = [0]
  let cache = InlSignatureKeyCache::new(
    input,
    indices,
    formatted_signatures=Some(formatted),
  )
  for index in 0..<32 {
    @debug.assert_eq(
      cache.key(index),
      inl_func_signature_key(input, indices, index),
    )
  }
  @debug.assert_eq(formatted[0], 1)
  let predicted : @hashmap.HashMap[String, Int32] = @hashmap.new()
  predicted.set(cache.key(0), 34)
  let output = inl_padding_compare_reference(input, predicted)
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 34)
  @debug.assert_eq(output.func_sec.unwrap().0[32], @lib.TypeIdx::new(0U))
  @debug.assert_eq(output.func_sec.unwrap().0[33], @lib.TypeIdx::new(0U))
}

///|
fn wide_reverse_alias_fixture(
  stable : Int,
  source : Int,
  target : Int,
  ty? : String = "i32",
  tee? : Bool = false,
  type_defs? : String = "",
) -> @lib.Module {
  let locals = Array::make(source + 1, ty).join(" ")
  let prefix = Array::makei(stable, fn(i) {
    "call $produce local.set \{i} local.get \{i} call $consume local.get \{i} call $consume"
  }).join(" ")
  let copy = if tee {
    "local.get \{source} local.tee \{target} call $consume"
  } else {
    "local.get \{source} local.set \{target}"
  }
  pass_test_module_from_wat(
    "(module \{type_defs} (import \"env\" \"produce\" (func $produce (result \{ty}))) (import \"env\" \"consume\" (func $consume (param \{ty}))) (func (export \"run\") (local \{locals}) \{prefix} call $produce local.set \{source} local.get \{source} call $consume \{copy} local.get \{target} call $consume local.get \{target} call $consume))",
  )
}

///|
test "DAE2 removes wide reverse aliases when final local widths cannot grow" {
  for ty in ["i32", "i64", "f64", "externref"] {
    for tee in [false, true] {
      let input = wide_reverse_alias_fixture(128, 129, 128, ty~, tee~)
      let (out, indices) = reverse_alias_compact(input)
      let @lib.Func(locals, @lib.Expr(body)) = out
      assert_eq(locals.length(), 129)
      assert_eq(indices[128], -1)
      assert_eq(indices[129], 128)
      assert_eq(body.filter(fn(i) { i is @lib.LocalTee(_) }).length(), 0)
      assert_eq(body.filter(fn(i) { i is @lib.LocalSet(_) }).length(), 129)
      assert_eq(
        body.filter(fn(i) { i is @lib.LocalGet(@lib.LocalIdx(128U)) }).length(),
        if tee {
          4
        } else {
          3
        },
      )
      let encoded = @binary.encode_module(
        input.with_code_sec(@lib.CodeSec::new([out])),
      ).unwrap()
      assert_true(
        encoded.length() < @binary.encode_module(input).unwrap().length(),
      )
    }
  }
}

///|
test "DAE2 wide reverse alias admission intentionally rejects a compacted width increase" {
  let input = wide_reverse_alias_fixture(127, 200, 128)
  let (out, indices) = reverse_alias_compact(input)
  let @lib.Func(locals, @lib.Expr(body)) = out
  assert_eq(locals.length(), 129)
  assert_eq(indices[128], 127)
  assert_eq(indices[200], 128)
  assert_eq(
    body.filter(fn(i) { i is @lib.LocalGet(@lib.LocalIdx(127U)) }).length(),
    2,
  )
  let seed = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  assert_eq(
    out,
    reverse_alias_reference_compact(
      input.code_sec.unwrap().0[0],
      seed,
      [],
      propagate_parameter_aliases=true,
    ).0,
  )
}

///|
test "DAE2 removes sparse reverse aliases when the source compacts to one byte" {
  let input = wide_reverse_alias_fixture(126, 200, 128)
  let (out, indices) = reverse_alias_compact(input)
  let @lib.Func(locals, @lib.Expr(body)) = out
  assert_eq(locals.length(), 127)
  assert_eq(indices[128], -1)
  assert_eq(indices[200], 126)
  assert_eq(
    body.filter(fn(i) { i is @lib.LocalGet(@lib.LocalIdx(126U)) }).length(),
    3,
  )
}

///|
test "DAE2 wide reverse aliases preserve indexed GC references" {
  let input = wide_reverse_alias_fixture(
    128,
    129,
    128,
    ty="(ref null $s)",
    type_defs="(type $s (struct (field i32)))",
  )
  let (out, indices) = reverse_alias_compact(input)
  let @lib.Func(locals, @lib.Expr(body)) = out
  assert_eq(locals.length(), 129)
  assert_eq(indices[128], -1)
  assert_eq(indices[129], 128)
  assert_eq(
    body.filter(fn(i) { i is @lib.Call(@lib.FuncIdx(0U)) }).length(),
    129,
  )
  assert_eq(
    body.filter(fn(i) { i is @lib.Call(@lib.FuncIdx(1U)) }).length(),
    259,
  )
  assert_true(
    @binary.encode_module(input.with_code_sec(@lib.CodeSec::new([out])))
    .unwrap()
    .length() <
    @binary.encode_module(input).unwrap().length(),
  )
}

///|
test "DAE2 wide reverse aliases obey final width bounds across sparse local layouts" {
  for stable in [0, 1, 126, 127, 128, 129] {
    for target in [128, 150] {
      if target < stable {
        continue
      }
      for source in [151, 200] {
        let input = wide_reverse_alias_fixture(stable, source, target)
        let (out, indices) = reverse_alias_compact(input)
        let @lib.Func(locals, _) = out
        let rejected = stable == 127
        assert_eq(locals.length(), stable + (if rejected { 2 } else { 1 }))
        assert_eq(indices[target], if rejected { stable } else { -1 })
        assert_eq(indices[source], stable + (if rejected { 1 } else { 0 }))
        let seed = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
        let old = fused_alias_reference_compact(
            input.code_sec.unwrap().0[0],
            seed,
            [],
            propagate_parameter_aliases=true,
          ).0
        assert_true(
          @binary.encode_module(input.with_code_sec(@lib.CodeSec::new([out])))
          .unwrap()
          .length() <=
          @binary.encode_module(input.with_code_sec(@lib.CodeSec::new([old])))
          .unwrap()
          .length(),
        )
      }
    }
  }
}

///|
test "DAE2 wide reverse aliases preserve dominance across nested scopes" {
  let prefix = Array::makei(128, fn(i) {
    "call $produce local.set \{i} local.get \{i} call $consume local.get \{i} call $consume"
  }).join(" ")
  let locals = Array::make(130, "i32").join(" ")
  for
    (tail, admitted) in [
      (
        "call $produce local.set 129 local.get 129 call $consume block local.get 129 local.set 128 local.get 128 call $consume local.get 128 call $consume end",
        true,
      ),
      (
        "loop call $produce local.set 129 local.get 129 call $consume local.get 129 local.set 128 local.get 128 call $consume local.get 128 call $consume i32.const 0 br_if 0 end",
        true,
      ),
      (
        "local.get 129 local.set 128 local.get 128 call $consume local.get 128 call $consume call $produce local.set 129 local.get 129 call $consume local.get 129 call $consume",
        false,
      ),
      (
        "i32.const 1 if call $produce local.set 129 local.get 129 call $consume local.get 129 call $consume else local.get 129 local.set 128 local.get 128 call $consume local.get 128 call $consume end",
        false,
      ),
    ] {
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (local \{locals}) \{prefix} \{tail}))",
    )
    let (out, indices) = reverse_alias_compact(input)
    let @lib.Func(locals, _) = out
    assert_eq(locals.length(), if admitted { 129 } else { 130 })
    assert_eq(indices[128], if admitted { -1 } else { 128 })
  }
}

///|
test "DAE2 local index widths cover each unsigned LEB boundary" {
  for
    (index, width) in [
      (0, 1),
      (127, 1),
      (128, 2),
      (16383, 2),
      (16384, 3),
      (2097151, 3),
      (2097152, 4),
      (268435455, 4),
      (268435456, 5),
    ] {
    assert_eq(dae2_local_index_width(index), width)
  }
}

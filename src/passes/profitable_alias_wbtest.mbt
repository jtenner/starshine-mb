///|
fn profitable_alias_test_calls(
  body : Array[@lib.Instruction],
  out : Array[@lib.Instruction],
) -> Unit {
  for instr in body {
    match instr {
      @lib.Call(_) => out.push(instr)
      @lib.Block(_, @lib.Expr(child))
      | @lib.Loop(_, @lib.Expr(child))
      | @lib.TryTable(_, _, @lib.Expr(child)) =>
        profitable_alias_test_calls(child, out)
      @lib.If(_, yes, no) => {
        profitable_alias_test_calls(yes, out)
        match no {
          Some(child) => profitable_alias_test_calls(child, out)
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
fn profitable_alias_fixture(
  tail : String,
  ty? : String = "i32",
  type_defs? : String = "",
) -> @lib.Module {
  let locals = Array::make(201, ty).join(" ")
  // 128 immutable noncopy slots survive; target 127 is deliberately excluded.
  // Removing the target leaves source 200 at index 128, still two-byte LEB.
  let prefix = Array::makei(129, fn(i) {
    if i == 127 {
      ""
    } else {
      "call $produce local.set \{i} local.get \{i} call $consume local.get \{i} call $consume"
    }
  }).join(" ")
  pass_test_module_from_wat(
    "(module \{type_defs} (import \"env\" \"produce\" (func $produce (result \{ty}))) (import \"env\" \"consume\" (func $consume (param \{ty}))) (func (export \"run\") (local \{locals}) \{prefix} \{tail}))",
  )
}

///|
test "DAE2 retires sole-reader reverse copies when removed bytes pay for index growth" {
  for
    (ty, type_defs) in [
      ("i32", ""),
      ("i64", ""),
      ("f64", ""),
      ("externref", ""),
      ("(ref null $s)", "(type $s (struct (field i32)))"),
    ] {
    for tee in [false, true] {
      let writer = if tee { "local.tee" } else { "local.set" }
      let immediate = if tee { "call $consume" } else { "" }
      let input = profitable_alias_fixture(
        "call $produce local.set 200 local.get 200 call $consume local.get 200 \{writer} 127 \{immediate} block local.get 127 call $consume end",
        ty~,
        type_defs~,
      )
      let (out, indices) = reverse_alias_compact(input)
      let @lib.Func(locals, @lib.Expr(body)) = out
      assert_eq(indices[127], -1)
      assert_eq(indices[200], 128)
      assert_eq(locals.length(), 129)
      let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
      let calls : Array[@lib.Instruction] = []
      let original_calls : Array[@lib.Instruction] = []
      profitable_alias_test_calls(body, calls)
      profitable_alias_test_calls(original, original_calls)
      assert_eq(calls, original_calls)
      assert_eq(
        body.last(),
        Some(
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::local_get(@lib.LocalIdx::new(128U)),
              @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            ]),
          ),
        ),
      )
      assert_eq(body.filter(fn(i) { i is @lib.LocalTee(_) }).length(), 0)
      let old = reverse_alias_reference_compact(
          input.code_sec.unwrap().0[0],
          @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
          [],
          propagate_parameter_aliases=true,
        ).0
      assert_true(
        @binary.encode_module(input.with_code_sec(@lib.CodeSec::new([out])))
        .unwrap()
        .length() <
        @binary.encode_module(input.with_code_sec(@lib.CodeSec::new([old])))
        .unwrap()
        .length(),
      )
    }
  }
}

///|
test "DAE2 profitable aliases preserve default reads and intentionally reject unstable roots" {
  for
    (tail, retired) in [
      (
        "call $produce local.set 200 local.get 200 call $consume local.get 200 local.set 127 block local.get 127 call $consume end",
        true,
      ),
      (
        "call $produce local.set 200 local.get 200 call $consume loop local.get 200 local.set 127 local.get 127 call $consume i32.const 0 br_if 0 end",
        true,
      ),
      (
        "local.get 127 call $consume call $produce local.set 200 local.get 200 call $consume local.get 200 local.set 127",
        false,
      ),
      (
        "call $produce local.set 200 local.get 200 call $consume block local.get 200 local.set 127 end local.get 127 call $consume",
        false,
      ),
      (
        "call $produce local.set 200 local.get 200 call $consume i32.const 1 if local.get 200 local.set 127 else local.get 127 call $consume end",
        false,
      ),
      (
        "local.get 200 local.set 127 block local.get 127 call $consume end call $produce local.set 200 local.get 200 call $consume local.get 200 call $consume",
        false,
      ),
      (
        "call $produce local.set 200 local.get 200 call $consume local.get 200 local.set 127 call $produce local.set 200 block local.get 127 call $consume end local.get 200 call $consume",
        false,
      ),
      // Width-changing multi-reader admission is intentionally unsupported.
      (
        "call $produce local.set 200 local.get 200 call $consume local.get 200 local.set 127 block local.get 127 call $consume local.get 127 call $consume end",
        false,
      ),
    ] {
    let input = profitable_alias_fixture(tail)
    let (out, indices) = reverse_alias_compact(input)
    assert_eq(indices[127] < 0, retired)
    if !retired {
      assert_eq(indices[127], 127)
    }
    let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
    let reads = Array::make(201, 0)
    let writes = Array::make(201, 0)
    pass_lower_count_locals(original, reads, writes)
    let legacy = wide_reverse_alias_perf_discover(
      original, reads, writes, false,
    )
    assert_eq(legacy.targets[127], -1L)
    if !retired {
      let expected = reverse_alias_reference_compact(
          input.code_sec.unwrap().0[0],
          @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
          [],
          propagate_parameter_aliases=true,
        ).0
      assert_eq(out, expected)
    }
  }
}

///|
test "DAE2 copy byte budget is strict across all unsigned LEB widths" {
  for
    (source, width) in [
      (127, 1),
      (128, 2),
      (16384, 3),
      (2097152, 4),
      (268435456, 5),
    ] {
    for tee in [false, true] {
      let saved = if tee { 2 } else { 4 }
      assert_eq(
        dae2_alias_copy_pays_for_widening(source, 0, 1, tee),
        width - 1 < saved,
      )
      assert_true(dae2_alias_copy_pays_for_widening(source, 0, 0, tee))
      assert_false(dae2_alias_copy_pays_for_widening(source, 0, 2, tee))
    }
  }
}

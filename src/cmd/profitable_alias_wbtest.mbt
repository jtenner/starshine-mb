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
test "DAE2 optimizing forwards sole-reader wide copies and preserves calls" {
  let locals = Array::make(201, "i32").join(" ")
  let prefix = Array::makei(129, fn(i) {
    if i == 127 {
      ""
    } else {
      "call $produce local.set \{i} local.get \{i} call $consume local.get \{i} call $consume"
    }
  }).join(" ")
  for tee in [false, true] {
    let writer = if tee { "local.tee" } else { "local.set" }
    let immediate = if tee { "call $consume" } else { "" }
    let input = @wast.wast_to_binary_module(
      "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (local \{locals}) \{prefix} call $produce local.set 200 local.get 200 call $consume local.get 200 \{writer} 127 \{immediate} block local.get 127 call $consume end))",
    ).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let output = optimize_module_with_pass_flags(
      input,
      ["dae2-optimizing"],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_eq(locals.length(), 129)
    let calls : Array[@lib.Instruction] = []
    profitable_alias_test_calls(body, calls)
    let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
    let original_calls : Array[@lib.Instruction] = []
    profitable_alias_test_calls(original, original_calls)
    assert_eq(calls, original_calls)
    assert_eq(
      calls.filter(fn(i) { i is @lib.Call(@lib.FuncIdx(0U)) }).length(),
      129,
    )
    assert_eq(
      calls.filter(fn(i) { i is @lib.Call(@lib.FuncIdx(1U)) }).length(),
      if tee {
        259
      } else {
        258
      },
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

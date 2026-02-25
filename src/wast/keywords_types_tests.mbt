///|
test "lookup_keyword classifies module/value/opcode and unknown inputs" {
  match lookup_keyword("module") {
    Some(Module) => ()
    _ => fail("expected module keyword classification")
  }
  match lookup_keyword("extern") {
    Some(ValueType(ExternRef)) => ()
    _ => fail("expected extern alias to classify as externref value type")
  }
  match lookup_keyword("ref.cast_desc_eq") {
    Some(Opcode(RefCastDescEq)) => ()
    _ => fail("expected descriptor cast opcode classification")
  }
  match lookup_keyword("i8x16.relaxed_swizzle") {
    Some(Opcode(I8x16RelaxedSwizzle)) => ()
    _ => fail("expected relaxed SIMD opcode classification")
  }
  match lookup_keyword("totally.unknown.keyword") {
    None => ()
    _ => fail("expected unknown keyword to return None")
  }
}

///|
test "lookup_keyword classifies advanced reference and exception keywords" {
  let keywords = [
    "ref.eq", "ref.as_non_null", "any.convert_extern", "extern.convert_any", "ref.i31",
    "i31.get_s", "i31.get_u", "throw", "throw_ref", "try_table", "catch", "catch_ref",
    "catch_all", "catch_all_ref", "tag",
  ]
  for keyword in keywords {
    match lookup_keyword(keyword) {
      Some(_) => ()
      None => fail("expected keyword to resolve: \{keyword}")
    }
  }
}

///|
test "wast_to_script parser boundaries for empty and unknown commands" {
  let empty_script = match wast_to_script("") {
    Ok(script) => script
    Err(e) => fail("unexpected parse error for empty script: \{e}")
  }
  assert_eq(empty_script.commands.length(), 0)

  match wast_to_script("(unknown)", filename="script-boundary.wast") {
    Ok(_) => fail("expected parse error for unknown command")
    Err(msg) => {
      assert_true(msg.contains("expected WAST command"))
      assert_true(msg.contains("script-boundary.wast:1"))
    }
  }
}

///|
test "wast_to_module parser boundary requires module keyword" {
  match wast_to_module("()", filename="module-boundary.wast") {
    Ok(_) => fail("expected parse error for missing module keyword")
    Err(msg) => {
      assert_true(msg.contains("expected 'module'"))
      assert_true(msg.contains("module-boundary.wast:1"))
    }
  }
}

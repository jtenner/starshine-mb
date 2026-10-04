///|
fn encoded_string_free_module(funcs : Array[Func]) -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
  )
  .with_func_sec(FuncSec::new(Array::make(funcs.length(), TypeIdx::new(0U))))
  .with_code_sec(CodeSec::new(funcs))
}

///|
fn encoded_string_free_check(before : Module, after : Module) -> Unit raise {
  @validate.validate_module(before).unwrap()
  @validate.validate_module(after).unwrap()
  let saved = encode_module(before).unwrap()
  assert_eq(
    encoded_module_sizes(before, after).unwrap(),
    (saved.length(), encode_module(after).unwrap().length()),
  )
  assert_eq(encode_module(before).unwrap(), saved)
}

///|
test "string-free size reuse retains new declarations globals and nested function strings" {
  let shared = Func::new(Locals::empty(), Expr::new([Instruction::nop()]))
  let changed = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::block(
        BlockType::void_(),
        Expr::new([Instruction::string_const(b"nested"), Instruction::drop()]),
      ),
    ]),
  )
  let added = Func::new(
    Locals::empty(),
    Expr::new([Instruction::string_const(b"added"), Instruction::drop()]),
  )
  let before = encoded_string_free_module([shared, shared])
  let after = encoded_string_free_module([shared, changed, added])
    .with_stringrefs_sec(StringRefsSec::new([b"declared"]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::stringref(), false),
          Expr::new([Instruction::string_const(b"global")]),
        ),
      ]),
    )
  assert_eq(encode_module_stringrefs(after), [
    b"declared", b"global", b"nested", b"added",
  ])
  encoded_string_free_check(before, after)
  encoded_string_free_check(before, encoded_string_free_module([added, shared]))
}

///|
test "nonempty prior pools retain shared function strings across declaration index changes" {
  let shared = Func::new(
    Locals::empty(),
    Expr::new([Instruction::string_const(b"shared"), Instruction::drop()]),
  )
  let before = encoded_string_free_module([shared])
  let declarations = Array::makei(128, fn(i) { @utf8.encode("declared-\{i}") })
  let after = encoded_string_free_module([shared]).with_stringrefs_sec(
    StringRefsSec::new(declarations),
  )
  assert_eq(encode_module_stringrefs(after)[128], b"shared")
  encoded_string_free_check(before, after)
}

///|
test "string-free evidence is rebuilt after mutation between independent size comparisons" {
  let body = [Instruction::nop()]
  let shared = Func::new(Locals::empty(), Expr::new(body))
  let module_ = encoded_string_free_module([shared])
  encoded_string_free_check(module_, module_)
  body.push(Instruction::string_const(b"later"))
  body.push(Instruction::drop())
  assert_eq(encode_module_stringrefs(module_), [b"later"])
  encoded_string_free_check(module_, module_)
}

///|
test "string-free reuse intentionally retains invalid replacement encoder errors" {
  let before = encoded_string_free_module([
    Func::new(Locals::empty(), Expr::new([Instruction::nop()])),
  ])
  // Bottom locals are intentionally unencodable; skipping string discovery
  // must never waive the replacement function's declaration/body encoder.
  let after = encoded_string_free_module([
    Func::new(Locals::from_types([ValType::bottom()]), Expr::new([])),
  ])
  let expected = encode_module(after)
  assert_true(expected is Err(_))
  match (encoded_module_sizes(before, after), expected) {
    (Err(actual), Err(reference)) => assert_eq(actual, reference)
    _ => fail("invalid replacement must retain its encoder error")
  }
}

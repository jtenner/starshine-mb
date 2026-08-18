///|
test "ffi bridge constructs and encodes one i32 function module" {
  let parameters = val_types_new()
  let results = val_types_new()
  val_types_push(results, @lib.ValType::i32())
  let rec_types = rec_types_new()
  rec_types_push(
    rec_types,
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func(parameters, results)),
    ),
  )
  let type_indices = type_indices_new()
  type_indices_push(type_indices, @lib.TypeIdx::new(0U))
  let instructions = instructions_new()
  instructions_push(
    instructions,
    @lib.Instruction::i32_const(@lib.I32::new(42)),
  )
  let functions = funcs_new()
  funcs_push(
    functions,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(instructions)),
  )
  let module_ = module_new()
    .with_type_sec(@lib.TypeSec::new(rec_types))
    .with_func_sec(@lib.FuncSec::new(type_indices))
    .with_code_sec(@lib.CodeSec::new(functions))
  assert_true(validate_module(module_))
  let encoded = encode_module(module_)
  assert_true(encoded.is_ok())
  let output = Buffer(size_hint=encoded.byte_length().reinterpret_as_int())
  for index in 0..<encoded.byte_length().reinterpret_as_int() {
    output.write_byte(encoded.byte_at(index.reinterpret_as_uint()))
  }
  match @binary.decode_module(output.to_bytes()) {
    Ok(decoded) => assert_true(@validate.validate_module(decoded) is Ok(_))
    Err(error) => fail("expected encoded bridge module to decode: \{error}")
  }
}

///|
test "core IR resources construct and encode a module from scratch" {
  let i32_type = ValType::i32()
  let function_comp_type = CompType::func_value([], [i32_type])
  let subtype = SubType::comp_type(
    function_comp_type,
    TypeMetadata::create(None, None, false),
  )
  let rec_type = RecType::create(subtype)
  let type_sec = TypeSec::create([rec_type])
  let type_idx = TypeIdx::create(0U)
  let func_sec = FuncSec::create([type_idx])

  let value = I32::create(7)
  let instruction = Instruction::i32_const(value)
  let expression = Expr::create([instruction])
  let function = FuncIr::create(Locals::empty(), expression)
  let code_sec = CodeSec::create([function])

  let module_ = Module::with_code_sec(
    Module::with_func_sec(
      Module::with_type_sec(empty_module(), type_sec),
      func_sec,
    ),
    code_sec,
  )
  match validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail("constructed module did not validate: \{err.message}")
  }
  match encode_module(module_) {
    Ok(wasm) => {
      if wasm.length() <= 8 ||
        wasm[0] != b'\x00' ||
        wasm[1] != b'a' ||
        wasm[2] != b's' ||
        wasm[3] != b'm' {
        fail("constructed module did not encode as wasm")
      }
    }
    Err(err) => fail("constructed module did not encode: \{err.message}")
  }
}

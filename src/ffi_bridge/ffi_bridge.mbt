///|
pub struct EncodedModule {
  bytes : Bytes?
}

///|
pub fn val_types_new() -> Array[@lib.ValType] {
  []
}

///|
pub fn val_types_push(
  values : Array[@lib.ValType],
  value : @lib.ValType,
) -> Unit {
  values.push(value)
}

///|
pub fn rec_types_new() -> Array[@lib.RecType] {
  []
}

///|
pub fn rec_types_push(
  values : Array[@lib.RecType],
  value : @lib.RecType,
) -> Unit {
  values.push(value)
}

///|
pub fn type_indices_new() -> Array[@lib.TypeIdx] {
  []
}

///|
pub fn type_indices_push(
  values : Array[@lib.TypeIdx],
  value : @lib.TypeIdx,
) -> Unit {
  values.push(value)
}

///|
pub fn instructions_new() -> Array[@lib.Instruction] {
  []
}

///|
pub fn instructions_push(
  values : Array[@lib.Instruction],
  value : @lib.Instruction,
) -> Unit {
  values.push(value)
}

///|
pub fn funcs_new() -> Array[@lib.Func] {
  []
}

///|
pub fn funcs_push(values : Array[@lib.Func], value : @lib.Func) -> Unit {
  values.push(value)
}

///|
pub fn module_new() -> @lib.Module {
  @lib.Module::new()
}

///|
pub fn validate_module(module_ : @lib.Module) -> Bool {
  @validate.validate_module(module_) is Ok(_)
}

///|
pub fn encode_module(module_ : @lib.Module) -> EncodedModule {
  match @binary.encode_module(module_) {
    Ok(bytes) => { bytes: Some(bytes) }
    Err(_) => { bytes: None }
  }
}

///|
pub fn EncodedModule::is_ok(self : EncodedModule) -> Bool {
  self.bytes is Some(_)
}

///|
pub fn EncodedModule::byte_length(self : EncodedModule) -> UInt {
  match self.bytes {
    Some(bytes) => bytes.length().reinterpret_as_uint()
    None => 0U
  }
}

///|
pub fn EncodedModule::byte_at(self : EncodedModule, index : UInt) -> Byte {
  match self.bytes {
    Some(bytes) => bytes[index.reinterpret_as_int()]
    None => abort("cannot read failed Starshine module encoding")
  }
}

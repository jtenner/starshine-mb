///|
pub struct EncodedModule {
  bytes : Bytes?
}

///|
let validation_error_bytes : Ref[Bytes] = Ref::new(Bytes::from_array([]))

///|
let validation_error_function_index_cache : Ref[Int] = Ref::new(-1)

///|
fn validation_message_bytes(message : String) -> Bytes {
  let output = @buffer.new(size_hint=message.length())
  for character in message {
    let code = character.to_int()
    if code >= 0 && code <= 255 {
      output.write_byte(code.to_byte())
    } else {
      output.write_byte('?'.to_int().to_byte())
    }
  }
  output.to_bytes()
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
pub fn field_types_new() -> Array[@lib.FieldType] {
  []
}

///|
pub fn field_types_push(
  values : Array[@lib.FieldType],
  value : @lib.FieldType,
) -> Unit {
  values.push(value)
}

///|
pub fn instruction_ref_test_nominal(
  type_index : Int,
) -> @lib.Instruction {
  @lib.Instruction::ref_test(
    false,
    @lib.HeapType::new(
      @lib.TypeIdx::new(type_index.reinterpret_as_uint()),
    ),
  )
}

///|
pub fn instruction_ref_cast_nominal(
  type_index : Int,
) -> @lib.Instruction {
  @lib.Instruction::ref_cast(
    false,
    @lib.HeapType::new(
      @lib.TypeIdx::new(type_index.reinterpret_as_uint()),
    ),
  )
}

///|
pub fn nominal_ref_type(
  type_index : Int,
  nullable : Bool,
) -> @lib.ValType {
  @lib.ValType::ref_type(
    @lib.RefType::new(
      nullable,
      @lib.HeapType::new(
        @lib.TypeIdx::new(type_index.reinterpret_as_uint()),
      ),
    ),
  )
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
pub fn instruction_if(
  type_ : @lib.BlockType,
  consequent : Array[@lib.Instruction],
  alternative : Array[@lib.Instruction],
) -> @lib.Instruction {
  @lib.Instruction::if_(type_, consequent, Some(alternative))
}

///|
pub fn imports_new() -> Array[@lib.Import] {
  []
}

///|
pub struct ImportBuilder {
  module_name : Array[Byte]
  field_name : Array[Byte]
  type_index : Int
}

///|
pub fn import_builder_new(type_index : Int) -> ImportBuilder {
  { module_name: [], field_name: [], type_index }
}

///|
pub fn ImportBuilder::push_module_byte(
  self : ImportBuilder,
  value : Byte,
) -> Unit {
  self.module_name.push(value)
}

///|
pub fn ImportBuilder::push_field_byte(
  self : ImportBuilder,
  value : Byte,
) -> Unit {
  self.field_name.push(value)
}

///|
fn import_name_from_bytes(value : Array[Byte]) -> String {
  let output = StringBuilder::new()
  for byte in value {
    output.write_char(byte.to_int().unsafe_to_char())
  }
  output.to_string()
}

///|
pub fn imports_push_builder(
  values : Array[@lib.Import],
  builder : ImportBuilder,
) -> Unit {
  values.push(
    @lib.Import::new(
      @lib.Name::from_string(import_name_from_bytes(builder.module_name)),
      @lib.Name::from_string(import_name_from_bytes(builder.field_name)),
      @lib.ExternType::func(
        @lib.TypeIdx::new(builder.type_index.reinterpret_as_uint()),
      ),
    ),
  )
}

///|
pub struct RuntimeFunctionBuilder {
  name : Array[Byte]
  base : Int
  utf8_validator_function_index : Int
  wasi_fd_write_function_index : Int
  wasi_fd_read_function_index : Int
  carrier : Int
  second_carrier : Int
  option_none_type : Int
  option_some_type : Int
}

///|
pub fn runtime_function_builder_new(
  base : Int,
  utf8_validator_function_index : Int,
  wasi_fd_write_function_index : Int,
  wasi_fd_read_function_index : Int,
  carrier : Int,
  second_carrier : Int,
  option_none_type : Int,
  option_some_type : Int,
) -> RuntimeFunctionBuilder {
  {
    name: [],
    base,
    utf8_validator_function_index,
    wasi_fd_write_function_index,
    wasi_fd_read_function_index,
    carrier,
    second_carrier,
    option_none_type,
    option_some_type,
  }
}

///|
pub fn RuntimeFunctionBuilder::push_name_byte(
  self : RuntimeFunctionBuilder,
  value : Byte,
) -> Unit {
  self.name.push(value)
}

///|
pub fn funcs_push_runtime(
  values : Array[@lib.Func],
  builder : RuntimeFunctionBuilder,
) -> Bool {
  let name = Bytes::from_array(builder.name)
  let generated = match emit_starshine_text_runtime_function(
    name,
    builder.base,
    builder.utf8_validator_function_index,
    builder.wasi_fd_write_function_index,
    builder.wasi_fd_read_function_index,
  ) {
    Some(value) => Some(value)
    None => match emit_bridge_array_runtime_function(
      name,
      builder.base + 6,
      builder.carrier,
      builder.option_none_type,
      builder.option_some_type,
    ) {
      Some(value) => Some(value)
      None => emit_bridge_map_runtime_function(
        name,
        builder.base + 6,
        builder.carrier,
        builder.second_carrier,
        builder.option_none_type,
        builder.option_some_type,
      )
    }
  }
  match generated {
    Some(value) => {
      values.push(value)
      true
    }
    None => false
  }
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
pub fn module_with_default_memory(module_ : @lib.Module) -> @lib.Module {
  module_.with_mem_sec(
    @lib.MemSec::new([
      @lib.MemType::new(@lib.Limits::i32(1U, None)),
    ]),
  )
}

///|
pub fn validate_module(module_ : @lib.Module) -> Bool {
  match @validate.validate_module(module_) {
    Ok(_) => {
      validation_error_bytes.val = Bytes::from_array([])
      validation_error_function_index_cache.val = -1
      true
    }
    Err(error) => {
      validation_error_bytes.val = validation_message_bytes(
        @validate.validation_error_message(error),
      )
      validation_error_function_index_cache.val = match
        @validate.validation_error_func_idx(error) {
        Some(@lib.FuncIdx(index)) => index.reinterpret_as_int()
        None => -1
      }
      false
    }
  }
}

///|
pub fn validation_error_byte_length() -> UInt {
  validation_error_bytes.val.length().reinterpret_as_uint()
}

///|
pub fn validation_error_byte_at(index : UInt) -> Byte {
  validation_error_bytes.val[index.reinterpret_as_int()]
}

///|
pub fn validation_error_function_index() -> Int {
  validation_error_function_index_cache.val
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

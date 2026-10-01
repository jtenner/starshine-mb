///|
#inline
fn sl_effectful_prefix_can_append_i64_extension(
  prefix : Array[@lib.Instruction],
  instr : @lib.Instruction,
  env : @validate.Env,
) -> Bool {
  match instr {
    @lib.I64ExtendI32S | @lib.I64ExtendI32U => ()
    _ => return false
  }
  if prefix.is_empty() {
    return false
  }
  // The extension consumes a value produced inside the movable prefix and
  // cannot trap. Do not broaden the general leaf classifier: other callers
  // rely on those leaves having no stack inputs.
  match prefix[prefix.length() - 1] {
    @lib.I32Const(_) => true
    @lib.LocalGet(local) =>
      env.get_local_type(local) == Some(@lib.ValType::i32())
    _ => false
  }
}

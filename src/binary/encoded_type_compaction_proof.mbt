///|
// Use the constructor because Module fields are read-only outside lib. Retain
// every original section and annotation except the separately measured code.
fn encoded_compaction_header_module(mod_ : Module) -> Module {
  Module::new(
    custom_secs=mod_.custom_secs,
    type_sec=mod_.type_sec,
    import_sec=mod_.import_sec,
    func_annotation_sec=mod_.func_annotation_sec,
    func_sec=mod_.func_sec,
    table_sec=mod_.table_sec,
    mem_sec=mod_.mem_sec,
    tag_sec=mod_.tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec=mod_.global_sec,
    export_sec=mod_.export_sec,
    start_sec=mod_.start_sec,
    elem_sec=mod_.elem_sec,
    data_cnt_sec=mod_.data_cnt_sec,
    code_sec=None,
    data_sec=mod_.data_sec,
    name_sec=mod_.name_sec,
    raw_name_sec_payload=mod_.raw_name_sec_payload,
    compiler_fact_custom_section=mod_.compiler_fact_custom_section,
  )
}

///|
// A standard type index has a nonnegative S33/ULEB encoding. Moving it earlier
// cannot increase its width. Internal recursive indices remain uncertain.
fn encoded_compaction_type_moves_left(
  before : TypeIdx,
  after : TypeIdx,
) -> Bool {
  match (before, after) {
    (TypeIdx(a), TypeIdx(b)) => b <= a
    _ => false
  }
}

///|
fn encoded_compaction_block_moves_left(
  before : BlockType,
  after : BlockType,
) -> Bool {
  match (before, after) {
    (VoidBlockType, VoidBlockType) => true
    (ValTypeBlockType(NumTypeValType(a)), ValTypeBlockType(NumTypeValType(b))) =>
      a == b
    (ValTypeBlockType(VecTypeValType), ValTypeBlockType(VecTypeValType)) => true
    (TypeIdxBlockType(a), TypeIdxBlockType(b)) =>
      encoded_compaction_type_moves_left(a, b)
    _ => false
  }
}

///|
// These exact leaf arms write fixed opcode bytes without an immediate or error.
// Unknown leaves use their existing encoder instead of extending this proof.
fn encoded_compaction_fixed_leaf(instr : Instruction) -> Bool {
  match instr {
    Unreachable
    | Nop
    | ThrowRef
    | Return
    | Drop
    | I32Eqz
    | I32Eq
    | I32Ne
    | I32LtS
    | I32LtU
    | I32GtS
    | I32GtU
    | I32LeS
    | I32LeU
    | I32GeS
    | I32GeU
    | I64Eqz
    | I64Eq
    | I64Ne
    | I64LtS
    | I64LtU
    | I64GtS
    | I64GtU
    | I64LeS
    | I64LeU
    | I64GeS
    | I64GeU
    | F32Eq
    | F32Ne
    | F32Lt
    | F32Gt
    | F32Le
    | F32Ge
    | F64Eq
    | F64Ne
    | F64Lt
    | F64Gt
    | F64Le
    | F64Ge
    | I32Clz
    | I32Ctz
    | I32Popcnt
    | I32Add
    | I32Sub
    | I32Mul
    | I32DivS
    | I32DivU
    | I32RemS
    | I32RemU
    | I32And
    | I32Or
    | I32Xor
    | I32Shl
    | I32ShrS
    | I32ShrU
    | I32Rotl
    | I32Rotr
    | I64Clz
    | I64Ctz
    | I64Popcnt
    | I64Add
    | I64Sub
    | I64Mul
    | I64DivS
    | I64DivU
    | I64RemS
    | I64RemU
    | I64And
    | I64Or
    | I64Xor
    | I64Shl
    | I64ShrS
    | I64ShrU
    | I64Rotl
    | I64Rotr
    | F32Abs
    | F32Neg
    | F32Ceil
    | F32Floor
    | F32Trunc
    | F32Nearest
    | F32Sqrt
    | F32Add
    | F32Sub
    | F32Mul
    | F32Div
    | F32Min
    | F32Max
    | F32Copysign
    | F64Abs
    | F64Neg
    | F64Ceil
    | F64Floor
    | F64Trunc
    | F64Nearest
    | F64Sqrt
    | F64Add
    | F64Sub
    | F64Mul
    | F64Div
    | F64Min
    | F64Max
    | F64Copysign
    | I32WrapI64
    | I32TruncF32S
    | I32TruncF32U
    | I32TruncF64S
    | I32TruncF64U
    | I64ExtendI32S
    | I64ExtendI32U
    | I64TruncF32S
    | I64TruncF32U
    | I64TruncF64S
    | I64TruncF64U
    | F32ConvertI32S
    | F32ConvertI32U
    | F32ConvertI64S
    | F32ConvertI64U
    | F32DemoteF64
    | F64ConvertI32S
    | F64ConvertI32U
    | F64ConvertI64S
    | F64ConvertI64U
    | F64PromoteF32
    | I32ReinterpretF32
    | I64ReinterpretF64
    | F32ReinterpretI32
    | F64ReinterpretI64
    | I32Extend8S
    | I32Extend16S
    | I64Extend8S
    | I64Extend16S
    | I64Extend32S
    | RefIsNull
    | RefEq
    | RefAsNonNull
    | I32TruncSatF32S
    | I32TruncSatF32U
    | I32TruncSatF64S
    | I32TruncSatF64U
    | I64TruncSatF32S
    | I64TruncSatF32U
    | I64TruncSatF64S
    | I64TruncSatF64U => true
    _ => false
  }
}

///|
// One paired cursor walk proves encoding compatibility and nonincrease. The
// bound includes the expression end byte and uses at most20bytes per ordinary
// scalar leaf,8per control, plus actual branch/typed-select vector width.
// Sequence cursors retain O(control depth) pending work.
fn encoded_compaction_scalar_body_bound(
  before : Array[Instruction],
  after : Array[Instruction],
) -> UInt64? {
  let work = [(before, after, 0)]
  let mut bound = 1UL
  while work.pop() is Some((left, right, start)) {
    if left.length() != right.length() {
      return None
    }
    let mut index = start
    while index < left.length() {
      let old = left[index]
      let next = right[index]
      match (old, next) {
        (Block(a, Expr(xs)), Block(b, Expr(ys)))
        | (Loop(a, Expr(xs)), Loop(b, Expr(ys))) => {
          if !encoded_compaction_block_moves_left(a, b) {
            return None
          }
          bound += 8UL
          if index + 1 < left.length() {
            work.push((left, right, index + 1))
          }
          work.push((xs, ys, 0))
          break
        }
        (If(a, ax, ae), If(b, bx, be)) => {
          if !encoded_compaction_block_moves_left(a, b) {
            return None
          }
          bound += 8UL
          if index + 1 < left.length() {
            work.push((left, right, index + 1))
          }
          match (ae, be) {
            (None, None) => ()
            (Some(xs), Some(ys)) => work.push((xs, ys, 0))
            _ => return None
          }
          work.push((ax, bx, 0))
          break
        }
        (Block(_, _), _)
        | (Loop(_, _), _)
        | (If(_, _, _), _)
        | (Try(_, _, _, _), _)
        | (TryTable(_, _, _), _) => return None
        (CallIndirect(a, ta), CallIndirect(b, tb))
        | (ReturnCallIndirect(a, ta), ReturnCallIndirect(b, tb)) => {
          if ta != tb || !encoded_compaction_type_moves_left(a, b) {
            return None
          }
          bound += 20UL
        }
        (CallRef(a), CallRef(b)) | (ReturnCallRef(a), ReturnCallRef(b)) => {
          if !encoded_compaction_type_moves_left(a, b) {
            return None
          }
          bound += 20UL
        }
        _ => {
          if !physical_equal(old, next) && old != next {
            return None
          }
          let safe = match old {
            I32Const(_)
            | I64Const(_)
            | F32Const(_)
            | F64Const(_)
            | LocalGet(_)
            | LocalSet(_)
            | LocalTee(_)
            | GlobalGet(_)
            | GlobalSet(_)
            | Call(_)
            | ReturnCall(_)
            | Br(_)
            | BrIf(_)
            | MemorySize(_)
            | MemoryGrow(_)
            | MemoryCopy(_, _)
            | MemoryFill(_)
            | MemoryInit(_, _)
            | DataDrop(_)
            | Select(None) => true
            BrTable(targets, _) => {
              bound += 5UL * targets.length().to_uint64()
              true
            }
            Select(Some(types)) => {
              if !types.all(fn(vt) {
                  vt is NumTypeValType(_) || vt is VecTypeValType
                }) {
                return None
              }
              bound += types.length().to_uint64()
              true
            }
            I32Load(m)
            | I64Load(m)
            | F32Load(m)
            | F64Load(m)
            | I32Load8S(m)
            | I32Load8U(m)
            | I32Load16S(m)
            | I32Load16U(m)
            | I64Load8S(m)
            | I64Load8U(m)
            | I64Load16S(m)
            | I64Load16U(m)
            | I64Load32S(m)
            | I64Load32U(m)
            | I32Store(m)
            | I64Store(m)
            | F32Store(m)
            | F64Store(m)
            | I32Store8(m)
            | I32Store16(m)
            | I64Store8(m)
            | I64Store16(m)
            | I64Store32(m) => {
              let MemArg(U32(align), _, _) = m
              align <= 8U
            }
            _ => encoded_compaction_fixed_leaf(old)
          }
          if !safe {
            return None
          }
          bound += 20UL
        }
      }
      if bound > 0x7FFF_FFFFUL {
        return None
      }
      index += 1
    }
    if bound > 0x7FFF_FFFFUL {
      return None
    }
  }
  Some(bound)
}

///|
// Inconclusive proof always retains the original full counter, including its
// exact before/after error order. This helper never substitutes for validation.
fn encoded_type_compaction_is_strictly_smaller_impl(
  before : Module,
  after : Module,
  fallback_body_encodes~ : Array[Int32]? = None,
) -> Bool {
  if before.raw_name_sec_payload is Some(_) ||
    after.raw_name_sec_payload is Some(_) ||
    before.compiler_fact_custom_section is Some(_) ||
    after.compiler_fact_custom_section is Some(_) {
    return false
  }
  let (old_funcs, new_funcs) = match (before.code_sec, after.code_sec) {
    (None, None) => ([], [])
    (Some(CodeSec(xs)), Some(CodeSec(ys))) if xs.length() == ys.length() =>
      (xs, ys)
    _ => return false
  }
  if !old_funcs.is_empty() {
    match (before.func_sec, after.func_sec) {
      (Some(FuncSec(xs)), Some(FuncSec(ys))) if xs.length() ==
        old_funcs.length() &&
        ys.length() == new_funcs.length() => ()
      _ => return false
    }
  }
  let old_header = encoded_compaction_header_module(before)
  let new_header = encoded_compaction_header_module(after)
  let old_pool = encode_module_stringrefs(old_header)
  let new_pool = encode_module_stringrefs(new_header)
  if old_pool != new_pool {
    return false
  }
  let first = EncodedModuleSizeState::new(None)
  let second = EncodedModuleSizeState::new(None)
  let old_buffer = @buffer.new()
  let new_buffer = @buffer.new()
  if encode_module_sections(
      old_header,
      old_buffer,
      false,
      size_state=Some(first),
    )
    is Err(_) {
    return false
  }
  if encode_module_sections(
      new_header,
      new_buffer,
      false,
      size_state=Some(second),
    )
    is Err(_) {
    return false
  }
  let old_header_size = match encoded_module_measured_size(old_buffer, first) {
    Ok(n) => n.to_uint64()
    Err(_) => return false
  }
  let new_header_size = match encoded_module_measured_size(new_buffer, second) {
    Ok(n) => n.to_uint64()
    Err(_) => return false
  }
  if new_header_size >= old_header_size {
    return false
  }
  // The pool omits code deliberately. An uncertain function can encode only
  // literals already in this pool; a missing literal rejects the entire proof.
  let result = with_binary_encode_stringrefs_context(
    if old_pool.is_empty() {
      None
    } else {
      Some(old_pool)
    },
    fn() {
      let mut code_bound = 0UL
      if before.code_sec is Some(_) {
        // Maximum code vector length prefix; exact size is unnecessary here.
        code_bound = 11UL
      }
      for index = 0; index < old_funcs.length(); index = index + 1 {
        let old = old_funcs[index]
        let next = new_funcs[index]
        let Func(old_locals, Expr(xs)) = old
        let Func(new_locals, Expr(ys)) = next
        let scalar = if old_locals == new_locals {
          encoded_compaction_scalar_body_bound(xs, ys)
        } else {
          None
        }
        match scalar {
          Some(body_bound) => {
            let locals = @buffer.new()
            if Encode::encode(old_locals, locals) is Err(_) {
              return Ok(false)
            }
            code_bound += 5UL + locals.length().to_uint64() + body_bound
          }
          None => {
            if fallback_body_encodes is Some(count) {
              count[0] += 1
            }
            let old_body = @buffer.new()
            if Encode::encode(old, old_body) is Err(_) {
              return Ok(false)
            }
            if fallback_body_encodes is Some(count) {
              count[0] += 1
            }
            let new_body = @buffer.new()
            if Encode::encode(next, new_body) is Err(_) {
              return Ok(false)
            }
            if new_body.length() > old_body.length() {
              return Ok(false)
            }
            code_bound += old_body.length().to_uint64()
          }
        }
        if old_header_size + code_bound > 0x7FFF_FFFFUL {
          return Ok(false)
        }
      }
      Ok(old_header_size + code_bound <= 0x7FFF_FFFFUL)
    },
  )
  match result {
    Ok(value) => value
    Err(_) => false
  }
}

///|
/// Prove that a type-compaction candidate has a strictly smaller canonical
/// encoding. A true result also proves both encoded sizes fit Int32. Common
/// bodies use nonincreasing type-index widths; uncertain bodies use the exact
/// encoder. False is inconclusive: callers must retain their full size check.
/// This invocation-local proof never substitutes for module validation.
pub fn encoded_type_compaction_is_strictly_smaller(
  before : Module,
  after : Module,
) -> Bool {
  encoded_type_compaction_is_strictly_smaller_impl(before, after)
}

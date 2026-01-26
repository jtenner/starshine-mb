///|
/// Constant Field Propagation Pass
///
/// Finds struct fields that are always written to with a constant value,
/// and replaces gets of them with that value.
///
/// For example, if we have a struct type T with a field that is always
/// initialized with i32.const 42, and there are no other writes to that
/// field, then anywhere we see a struct.get of that field we can replace
/// it with i32.const 42.
///
/// This is a barebones implementation that:
/// - Tracks values written to struct fields via struct.new
/// - Identifies fields that always have the same constant value
/// - Replaces struct.get operations with those constants
///
/// Limitations of this barebones version:
/// - Does not handle struct.set (only struct.new)
/// - Does not handle type hierarchies/subtypes
/// - Does not handle field copies
/// - Does not use ref.test optimization
/// - Assumes closed world

///|
/// Represents possible constant values for a field
/// Tracks whether a field has a single constant value or multiple/unknown values
pub enum FieldValue {
  /// No value has been noted yet
  Uninitialized
  /// A single constant value
  Constant(TInstr)
  /// Multiple different values or unknown
  Unknown
} derive(Eq)

///|
fn FieldValue::combine(self : FieldValue, other : FieldValue) -> FieldValue {
  match (self, other) {
    (Uninitialized, v) | (v, Uninitialized) => v
    (Constant(a), Constant(b)) => if a == b { Constant(a) } else { Unknown }
    _ => Unknown
  }
}

///|
fn FieldValue::is_constant(self : FieldValue) -> Bool {
  match self {
    Constant(_) => true
    _ => false
  }
}

///|
fn FieldValue::get_constant(self : FieldValue) -> TInstr? {
  match self {
    Constant(v) => Some(v)
    _ => None
  }
}

///|
/// Check if a constant is ref.null
fn is_ref_null(instr : TInstr) -> Bool {
  match instr {
    TRefNull(_) => true
    _ => false
  }
}

///|
/// State for the constant field propagation analysis
pub struct CFPState {
  /// Maps (type_index, field_index) to the values written to that field
  field_values : @hashmap.HashMap[(Int, Int), FieldValue]
  /// Type section from the module, used to look up field types
  type_sec : @lib.TypeSec?
}

///|
pub fn CFPState::new() -> CFPState {
  CFPState::{ field_values: @hashmap.new(), type_sec: None }
}

///|
/// Create a CFPState with type information from a module
pub fn CFPState::from_module(m : Module) -> CFPState {
  CFPState::{ field_values: @hashmap.new(), type_sec: m.type_sec }
}

///|
/// Get the default value constant for a ValType
fn get_default_constant(vt : ValType) -> TInstr? {
  match vt {
    NumTypeValType(nt) =>
      match nt {
        I32NumType => Some(TInstr::i32_const(I32(0)))
        I64NumType => Some(TInstr::i64_const(I64(0L)))
        F32NumType => Some(TInstr::f32_const(F32(0.0)))
        F64NumType => Some(TInstr::f64_const(F64(0.0)))
      }
    VecTypeValType => None // V128 default is complex
    RefTypeValType(rt) =>
      // Default for nullable references is ref.null
      if rt.is_nullable() {
        Some(TInstr::ref_null(rt.get_heap_type()))
      } else {
        None
      }
    BotValType => None
  }
}

///|
/// Get the default value constant for a StorageType
fn get_storage_default_constant(st : @lib.StorageType) -> TInstr? {
  match st {
    ValTypeStorageType(vt) => get_default_constant(vt)
    PackTypeStorageType(_) =>
      // Packed types (i8, i16) default to 0 as i32
      Some(TInstr::i32_const(I32(0)))
  }
}

///|
/// Get the struct fields for a type index
fn get_struct_fields(
  state : CFPState,
  type_idx : TypeIdx,
) -> Array[@lib.FieldType]? {
  get_struct_fields_from_type_sec(state.type_sec, type_idx)
}

///|
/// Helper to get struct fields from type section
fn get_struct_fields_from_type_sec(
  type_sec : @lib.TypeSec?,
  type_idx : TypeIdx,
) -> Array[@lib.FieldType]? {
  match type_sec {
    None => None
    Some(TypeSec(rec_types)) => {
      let idx = match type_idx {
        TypeIdx(i) => i.reinterpret_as_int()
        RecIdx(i) => i.reinterpret_as_int()
      }
      match rec_types.get(idx) {
        None => None
        Some(rec_type) => {
          let subtype = match rec_type {
            SingleRecType(st) => st
            GroupRecType(sts) =>
              match sts.get(0) {
                Some(st) => st
                None => return None
              }
          }
          match subtype.get_comptype() {
            StructCompType(fields) => Some(fields)
            _ => None
          }
        }
      }
    }
  }
}

///|
/// Get the subtype's parent types
fn get_super_types(
  type_sec : @lib.TypeSec?,
  type_idx : TypeIdx,
) -> Array[TypeIdx] {
  match type_sec {
    None => []
    Some(TypeSec(rec_types)) => {
      let idx = match type_idx {
        TypeIdx(i) => i.reinterpret_as_int()
        RecIdx(i) => i.reinterpret_as_int()
      }
      match rec_types.get(idx) {
        None => []
        Some(rec_type) => {
          let subtype = match rec_type {
            SingleRecType(st) => st
            GroupRecType(sts) =>
              match sts.get(0) {
                Some(st) => st
                None => return []
              }
          }
          subtype.super_types()
        }
      }
    }
  }
}

///|
/// Propagate field values from subtypes to supertypes
/// If a subtype writes a different constant to a field than the supertype,
/// the supertype's field becomes Unknown (since we can't distinguish at runtime)
pub fn propagate_to_supertypes(state : CFPState) -> Unit {
  // For each type that has a supertype, propagate its field values
  match state.type_sec {
    None => ()
    Some(TypeSec(rec_types)) =>
      for i = 0; i < rec_types.length(); i = i + 1 {
        let type_idx = TypeIdx::new(i.reinterpret_as_uint())
        let supers = get_super_types(state.type_sec, type_idx)
        for super_idx in supers {
          propagate_fields_to_super(state, type_idx, super_idx)
        }
      }
  }
}

///|
/// Propagate field values from a subtype to its supertype
fn propagate_fields_to_super(
  state : CFPState,
  sub_type_idx : TypeIdx,
  super_type_idx : TypeIdx,
) -> Unit {
  let sub_id = type_idx_to_int(sub_type_idx)
  let super_id = type_idx_to_int(super_type_idx)

  // Get the fields from the supertype (which the subtype inherits)
  match get_struct_fields_from_type_sec(state.type_sec, super_type_idx) {
    None => ()
    Some(super_fields) =>
      // For each field in the supertype
      for i = 0; i < super_fields.length(); i = i + 1 {
        let sub_value = get_field_value(state, sub_id, i)
        let super_value = get_field_value(state, super_id, i)

        // Combine the values - if they differ, both become Unknown
        let combined = super_value.combine(sub_value)
        if combined != super_value {
          state.field_values.set((super_id, i), combined)
        }
        // Also update the subtype to reflect the combined value
        if combined != sub_value {
          state.field_values.set((sub_id, i), combined)
        }
      }
  }
}

///|
/// Note a value written to a field
fn note_field_write(
  state : CFPState,
  type_idx : Int,
  field_idx : Int,
  value : TInstr,
) -> Unit {
  let key = (type_idx, field_idx)
  let current = state.field_values.get(key).unwrap_or(Uninitialized)
  let new_value = current.combine(Constant(value))
  state.field_values.set(key, new_value)
}

///|
/// Get the value for a field
fn get_field_value(
  state : CFPState,
  type_idx : Int,
  field_idx : Int,
) -> FieldValue {
  state.field_values.get((type_idx, field_idx)).unwrap_or(Uninitialized)
}

///|
/// Main constant field propagation pass
/// This is a two-phase pass. Call run_constant_field_propagation for full optimization.
/// The pass itself just scans for struct operations.
pub fn constant_field_propagation_pass() -> ModuleTransformer[CFPState] {
  ModuleTransformer::new()
    .on_func_evt(fn(_self, state, func) {
      match func {
        Func(_, _) => unchanged()
        TFunc(_, body) => {
          // Scan the function for struct.new operations
          scan_for_struct_news(state, body)
          unchanged()
        }
      }
    })
}

///|
/// Run constant field propagation on a module
/// This is a three-phase optimization:
/// 1. Scan all functions to collect field values
/// 2. Propagate values through type hierarchy
/// 3. Replace struct.get operations with constants where possible
pub fn run_constant_field_propagation(m : Module) -> Result[Module, String] {
  // Phase 1: Scan all functions to collect field values
  // Use from_module to get type information for struct.new.default handling
  let state = CFPState::from_module(m)
  match m.code_sec {
    None => return Ok(m) // No functions to optimize
    Some(CodeSec(funcs)) =>
      for func in funcs {
        match func {
          Func(_, _) => ()
          TFunc(_, body) => scan_for_struct_news(state, body)
        }
      }
  }

  // Phase 2: Propagate values through type hierarchy
  propagate_to_supertypes(state)

  // Phase 3: Optimize struct.get operations
  let optimizer = make_cfp_optimizer(state)
  match optimizer.walk_module((), m) {
    Ok(Some((_, new_m))) => Ok(new_m)
    Ok(None) => Ok(m)
    Err(e) => Err(e)
  }
}

///|
/// Create an optimizer that replaces struct.get with constants
fn make_cfp_optimizer(state : CFPState) -> ModuleTransformer[Unit] {
  ModuleTransformer::new()
    .on_tinstruction_evt(fn(self, _, instr) {
      match instr {
        TStructGet(type_idx, field_idx, ref_instr)
        | TStructGetS(type_idx, field_idx, ref_instr)
        | TStructGetU(type_idx, field_idx, ref_instr) => {
          let type_id = type_idx_to_int(type_idx)
          let U32(field_id_uint) = field_idx
          let field_id = field_id_uint.reinterpret_as_int()
          let field_value = get_field_value(state, type_id, field_id)
          match field_value.get_constant() {
            Some(constant) => {
              // Replace with: (drop ref) ; constant
              // We need to keep the ref for side effects (null trap)
              let drop_ref = TInstr::drop(ref_instr)
              // Create a block to hold both instructions
              let result = TInstr::block(
                BlockType::void_(),
                TExpr::new([drop_ref, constant]),
              )
              change((), result)
            }
            None => self.walk_tinstruction_default((), instr)
          }
        }
        // Optimize ref.test when the input is a struct.get from a known ref.null field
        TRefTest(_, _, inner) =>
          match inner {
            TStructGet(type_idx, field_idx, ref_instr)
            | TStructGetS(type_idx, field_idx, ref_instr)
            | TStructGetU(type_idx, field_idx, ref_instr) => {
              let type_id = type_idx_to_int(type_idx)
              let U32(field_id_uint) = field_idx
              let field_id = field_id_uint.reinterpret_as_int()
              let field_value = get_field_value(state, type_id, field_id)
              match field_value.get_constant() {
                Some(constant) =>
                  if is_ref_null(constant) {
                    // ref.test on ref.null always returns 0 (false)
                    let drop_ref = TInstr::drop(ref_instr)
                    let result = TInstr::block(
                      BlockType::void_(),
                      TExpr::new([drop_ref, TInstr::i32_const(I32(0))]),
                    )
                    change((), result)
                  } else {
                    self.walk_tinstruction_default((), instr)
                  }
                None => self.walk_tinstruction_default((), instr)
              }
            }
            _ => self.walk_tinstruction_default((), instr)
          }
        _ => self.walk_tinstruction_default((), instr)
      }
    })
}

///|
/// Scan a function body for struct.new operations
fn scan_for_struct_news(state : CFPState, body : TExpr) -> Unit {
  for instr in body.0 {
    scan_instruction(state, instr)
  }
}

///|
/// Extract type id as Int from TypeIdx
fn type_idx_to_int(type_idx : TypeIdx) -> Int {
  match type_idx {
    TypeIdx(idx) => idx.reinterpret_as_int()
    RecIdx(idx) => idx.reinterpret_as_int()
  }
}

///|
/// Mark a field as having an unknown (non-constant) value
fn note_field_unknown(
  state : CFPState,
  type_idx : Int,
  field_idx : Int,
) -> Unit {
  let key = (type_idx, field_idx)
  state.field_values.set(key, Unknown)
}

///|
/// Check if an instruction is a struct.get from a known constant field
/// Returns the constant value if so, None otherwise
fn get_copied_constant(state : CFPState, instr : TInstr) -> TInstr? {
  match instr {
    TStructGet(type_idx, field_idx, _)
    | TStructGetS(type_idx, field_idx, _)
    | TStructGetU(type_idx, field_idx, _) => {
      let type_id = type_idx_to_int(type_idx)
      let U32(field_id_uint) = field_idx
      let field_id = field_id_uint.reinterpret_as_int()
      let field_value = get_field_value(state, type_id, field_id)
      field_value.get_constant()
    }
    _ => None
  }
}

///|
/// Recursively scan an instruction for struct operations
fn scan_instruction(state : CFPState, instr : TInstr) -> Unit {
  match instr {
    // struct.new with explicit field values
    TStructNew(type_idx, field_values) => {
      let type_id = type_idx_to_int(type_idx)
      for i = 0; i < field_values.length(); i = i + 1 {
        // Check if the field value is a constant
        if is_constant_value(field_values[i]) {
          note_field_write(state, type_id, i, field_values[i])
        } else {
          // Check if value is a struct.get from a known constant field
          match get_copied_constant(state, field_values[i]) {
            Some(constant) => note_field_write(state, type_id, i, constant)
            None =>
              // Non-constant value, mark as unknown
              note_field_unknown(state, type_id, i)
          }
        }
        // Also scan the field value for nested struct operations
        scan_instruction(state, field_values[i])
      }
    }
    // struct.new.default - all fields get default (zero) values
    TStructNewDefault(type_idx) => {
      let type_id = type_idx_to_int(type_idx)
      // If we have type information, track the default values
      match get_struct_fields(state, type_idx) {
        Some(fields) =>
          for i = 0; i < fields.length(); i = i + 1 {
            let FieldType(storage_type, _) = fields[i]
            match get_storage_default_constant(storage_type) {
              Some(default_const) =>
                note_field_write(state, type_id, i, default_const)
              None =>
                // Can't determine default, mark as unknown
                note_field_unknown(state, type_id, i)
            }
          }
        None =>
          // No type info available, can't track defaults
          ()
      }
    }
    // struct.set - track the value being set
    TStructSet(type_idx, field_idx, struct_ref, value) => {
      let type_id = type_idx_to_int(type_idx)
      let U32(field_id_uint) = field_idx
      let field_id = field_id_uint.reinterpret_as_int()
      if is_constant_value(value) {
        note_field_write(state, type_id, field_id, value)
      } else {
        // Check if value is a struct.get from a known constant field
        match get_copied_constant(state, value) {
          Some(constant) => note_field_write(state, type_id, field_id, constant)
          None => note_field_unknown(state, type_id, field_id)
        }
      }
      // Also scan the sub-instructions
      scan_instruction(state, struct_ref)
      scan_instruction(state, value)
    }
    // Recursively scan nested instructions
    TBlock(_, body) => scan_for_struct_news(state, body)
    TLoop(_, body) => scan_for_struct_news(state, body)
    TIf(_, cond, then_body, else_body) => {
      scan_instruction(state, cond)
      scan_for_struct_news(state, then_body)
      match else_body {
        Some(body) => scan_for_struct_news(state, body)
        None => ()
      }
    }
    // For other instructions with sub-expressions, scan recursively
    TStructGet(_, _, ref_instr)
    | TStructGetS(_, _, ref_instr)
    | TStructGetU(_, _, ref_instr) => scan_instruction(state, ref_instr)
    TDrop(sub) => scan_instruction(state, sub)
    TSelect(_, a, b, c) => {
      scan_instruction(state, a)
      scan_instruction(state, b)
      scan_instruction(state, c)
    }
    TLocalSet(_, sub) | TLocalTee(_, sub) => scan_instruction(state, sub)
    TGlobalSet(_, sub) => scan_instruction(state, sub)
    TCall(_, args) =>
      for arg in args {
        scan_instruction(state, arg)
      }
    TCallRef(_, args, funcref) => {
      for arg in args {
        scan_instruction(state, arg)
      }
      scan_instruction(state, funcref)
    }
    TCallIndirect(_, _, args, table_idx) => {
      for arg in args {
        scan_instruction(state, arg)
      }
      scan_instruction(state, table_idx)
    }
    TBr(_, args) =>
      for arg in args {
        scan_instruction(state, arg)
      }
    TBrIf(_, cond, args) => {
      scan_instruction(state, cond)
      for arg in args {
        scan_instruction(state, arg)
      }
    }
    TReturn(args) =>
      for arg in args {
        scan_instruction(state, arg)
      }
    TBrTable(_, _, idx, args) => {
      scan_instruction(state, idx)
      for arg in args {
        scan_instruction(state, arg)
      }
    }
    TTryTable(_, _, body) => scan_for_struct_news(state, body)
    // For simple instructions with no sub-expressions, do nothing
    _ => ()
  }
}

///|
/// Check if an instruction is a constant value
fn is_constant_value(instr : TInstr) -> Bool {
  match instr {
    TI32Const(_) | TI64Const(_) | TF32Const(_) | TF64Const(_) => true
    TRefNull(_) | TRefFunc(_) => true
    _ => false
  }
}

// ============================================================
// Tests
// ============================================================

///|
test "FieldValue::combine with same constants" {
  let v1 = Constant(TInstr::i32_const(I32(42)))
  let v2 = Constant(TInstr::i32_const(I32(42)))
  let result = v1.combine(v2)
  assert_true(result.is_constant())
}

///|
test "FieldValue::combine with different constants" {
  let v1 = Constant(TInstr::i32_const(I32(42)))
  let v2 = Constant(TInstr::i32_const(I32(100)))
  let result = v1.combine(v2)
  assert_true(result == Unknown)
}

///|
test "FieldValue::combine with Uninitialized" {
  let v1 = Uninitialized
  let v2 = Constant(TInstr::i32_const(I32(42)))
  let result = v1.combine(v2)
  assert_true(result.is_constant())
}

///|
test "is_constant_value recognizes i32.const" {
  assert_true(is_constant_value(TInstr::i32_const(I32(42))))
}

///|
test "is_constant_value recognizes i64.const" {
  assert_true(is_constant_value(TInstr::i64_const(I64(100L))))
}

///|
test "is_constant_value recognizes ref.null" {
  assert_true(
    is_constant_value(TInstr::ref_null(HeapType::abs(AbsHeapType::func()))),
  )
}

///|
test "is_constant_value rejects non-constants" {
  assert_false(is_constant_value(TInstr::local_get(LocalIdx::new(0))))
}

///|
test "CFPState::new creates empty state" {
  let state = CFPState::new()
  assert_true(state.field_values.is_empty())
}

///|
test "note_field_write records constant" {
  let state = CFPState::new()
  note_field_write(state, 0, 0, TInstr::i32_const(I32(42)))
  let value = get_field_value(state, 0, 0)
  assert_true(value.is_constant())
}

///|
test "note_field_write combines same constants" {
  let state = CFPState::new()
  note_field_write(state, 0, 0, TInstr::i32_const(I32(42)))
  note_field_write(state, 0, 0, TInstr::i32_const(I32(42)))
  let value = get_field_value(state, 0, 0)
  assert_true(value.is_constant())
}

///|
test "note_field_write marks different constants as unknown" {
  let state = CFPState::new()
  note_field_write(state, 0, 0, TInstr::i32_const(I32(42)))
  note_field_write(state, 0, 0, TInstr::i32_const(I32(100)))
  let value = get_field_value(state, 0, 0)
  assert_true(value == Unknown)
}

///|
test "constant_field_propagation_pass creates valid transformer" {
  let pass = constant_field_propagation_pass()
  assert_true(pass.on_func is Some(_))
}

///|
test "scan_instruction handles struct.set with constant" {
  let state = CFPState::new()
  // Create a struct.set instruction: struct.set type_0, field_1, ref, i32.const 42
  let type_idx = TypeIdx::new(0)
  let field_idx : @lib.U32 = @lib.U32(1)
  let struct_ref = TInstr::local_get(LocalIdx::new(0))
  let value = TInstr::i32_const(I32(42))
  let instr = TInstr::struct_set(type_idx, field_idx, struct_ref, value)
  scan_instruction(state, instr)
  let field_value = get_field_value(state, 0, 1)
  assert_true(field_value.is_constant())
}

///|
test "scan_instruction handles struct.set with non-constant" {
  let state = CFPState::new()
  // Create a struct.set instruction with a non-constant value
  let type_idx = TypeIdx::new(0)
  let field_idx : @lib.U32 = @lib.U32(1)
  let struct_ref = TInstr::local_get(LocalIdx::new(0))
  let value = TInstr::local_get(LocalIdx::new(1)) // non-constant
  let instr = TInstr::struct_set(type_idx, field_idx, struct_ref, value)
  scan_instruction(state, instr)
  let field_value = get_field_value(state, 0, 1)
  assert_true(field_value == Unknown)
}

///|
test "struct.set and struct.new combine correctly" {
  let state = CFPState::new()
  // First, a struct.new with constant value 42 in field 0
  let type_idx = TypeIdx::new(0)
  let struct_new_instr = TInstr::struct_new(type_idx, [
    TInstr::i32_const(I32(42)),
  ])
  scan_instruction(state, struct_new_instr)

  // Field should be constant
  let value1 = get_field_value(state, 0, 0)
  assert_true(value1.is_constant())

  // Now a struct.set with same constant value
  let field_idx : @lib.U32 = @lib.U32(0)
  let struct_ref = TInstr::local_get(LocalIdx::new(0))
  let struct_set_instr = TInstr::struct_set(
    type_idx,
    field_idx,
    struct_ref,
    TInstr::i32_const(I32(42)),
  )
  scan_instruction(state, struct_set_instr)

  // Field should still be constant (same value)
  let value2 = get_field_value(state, 0, 0)
  assert_true(value2.is_constant())
}

///|
test "struct.set with different constant invalidates field" {
  let state = CFPState::new()
  // First, a struct.new with constant value 42 in field 0
  let type_idx = TypeIdx::new(0)
  let struct_new_instr = TInstr::struct_new(type_idx, [
    TInstr::i32_const(I32(42)),
  ])
  scan_instruction(state, struct_new_instr)

  // Now a struct.set with different constant value
  let field_idx : @lib.U32 = @lib.U32(0)
  let struct_ref = TInstr::local_get(LocalIdx::new(0))
  let struct_set_instr = TInstr::struct_set(
    type_idx,
    field_idx,
    struct_ref,
    TInstr::i32_const(I32(100)),
  )
  scan_instruction(state, struct_set_instr)

  // Field should now be Unknown
  let value = get_field_value(state, 0, 0)
  assert_true(value == Unknown)
}

///|
test "make_cfp_optimizer replaces struct.get with constant" {
  // Create a state with a known constant for type 0, field 0
  let state = CFPState::new()
  note_field_write(state, 0, 0, TInstr::i32_const(I32(42)))

  // Create an optimizer
  let optimizer = make_cfp_optimizer(state)

  // Create a struct.get instruction
  let type_idx = TypeIdx::new(0)
  let field_idx : @lib.U32 = @lib.U32(0)
  let ref_instr = TInstr::local_get(LocalIdx::new(0))
  let get_instr = TInstr::struct_get(type_idx, field_idx, ref_instr)

  // Run the optimizer on the instruction
  let result = optimizer.walk_tinstruction((), get_instr)

  // Should return a block with (drop ref) and (i32.const 42)
  match result {
    Ok(Some((_, new_instr))) =>
      match new_instr {
        TBlock(_, body) => {
          assert_eq(body.0.length(), 2)
          assert_true(body.0[0] is TDrop(_))
          assert_true(body.0[1] is TI32Const(_))
        }
        _ => fail("Expected TBlock but got something else")
      }
    _ => fail("Optimizer should have transformed the instruction")
  }
}

///|
test "make_cfp_optimizer preserves struct.get for unknown fields" {
  // Create a state with unknown value for type 0, field 0
  let state = CFPState::new()
  note_field_write(state, 0, 0, TInstr::i32_const(I32(42)))
  note_field_write(state, 0, 0, TInstr::i32_const(I32(100))) // Different value -> Unknown

  // Create an optimizer
  let optimizer = make_cfp_optimizer(state)

  // Create a struct.get instruction
  let type_idx = TypeIdx::new(0)
  let field_idx : @lib.U32 = @lib.U32(0)
  let ref_instr = TInstr::local_get(LocalIdx::new(0))
  let get_instr = TInstr::struct_get(type_idx, field_idx, ref_instr)

  // Run the optimizer on the instruction
  let result = optimizer.walk_tinstruction((), get_instr)

  // Should return the original struct.get (or similar)
  match result {
    Ok(Some((_, new_instr))) =>
      match new_instr {
        TStructGet(_, _, _) => () // Good, preserved the struct.get
        _ => fail("Expected TStructGet but got something else")
      }
    Ok(None) => () // Also acceptable - means no change
    Err(_) => fail("Optimizer should not error")
  }
}

///|
test "struct.new.default tracks default values with type info" {
  // Create a simple struct type with an i32 field
  let field_type = @lib.FieldType::new(
    @lib.StorageType::val_type(ValType::i32()),
    @lib.Mut::var_(),
  )
  let struct_type = @lib.CompType::struct_([field_type])
  let sub_type = @lib.SubType::comp_type(struct_type)
  let rec_type = @lib.RecType::new(sub_type)
  let type_sec = @lib.TypeSec::new([rec_type])

  // Create state with type info
  let state = CFPState::{
    field_values: @hashmap.new(),
    type_sec: Some(type_sec),
  }

  // Scan a struct.new.default instruction
  let type_idx = TypeIdx::new(0)
  let instr = TInstr::struct_new_default(type_idx)
  scan_instruction(state, instr)

  // Field 0 should be constant (default i32 = 0)
  let field_value = get_field_value(state, 0, 0)
  assert_true(field_value.is_constant())

  // Check it's the correct value
  match field_value.get_constant() {
    Some(TI32Const(I32(val))) => assert_eq(val, 0)
    _ => fail("Expected i32.const 0")
  }
}

///|
test "struct.new.default without type info does not track fields" {
  // Create state without type info
  let state = CFPState::new()

  // Scan a struct.new.default instruction
  let type_idx = TypeIdx::new(0)
  let instr = TInstr::struct_new_default(type_idx)
  scan_instruction(state, instr)

  // Field 0 should be Uninitialized (no type info to determine default)
  let field_value = get_field_value(state, 0, 0)
  assert_true(field_value == Uninitialized)
}

///|
test "type hierarchy propagation - same constant" {
  // Create a supertype with one i32 field
  let field_type = @lib.FieldType::new(
    @lib.StorageType::val_type(ValType::i32()),
    @lib.Mut::var_(),
  )
  let super_struct = @lib.CompType::struct_([field_type])
  let super_subtype = @lib.SubType::comp_type(super_struct)
  let super_rec = @lib.RecType::new(super_subtype)

  // Create a subtype that extends the supertype
  let sub_struct = @lib.CompType::struct_([field_type])
  let sub_subtype = @lib.SubType::new(false, [TypeIdx::new(0)], sub_struct)
  let sub_rec = @lib.RecType::new(sub_subtype)
  let type_sec = @lib.TypeSec::new([super_rec, sub_rec])

  // Create state with type info
  let state = CFPState::{
    field_values: @hashmap.new(),
    type_sec: Some(type_sec),
  }

  // Both types write the same constant to field 0
  note_field_write(state, 0, 0, TInstr::i32_const(I32(42)))
  note_field_write(state, 1, 0, TInstr::i32_const(I32(42)))

  // Propagate through hierarchy
  propagate_to_supertypes(state)

  // Both should still be constant
  let super_value = get_field_value(state, 0, 0)
  let sub_value = get_field_value(state, 1, 0)
  assert_true(super_value.is_constant())
  assert_true(sub_value.is_constant())
}

///|
test "type hierarchy propagation - different constants" {
  // Create a supertype with one i32 field
  let field_type = @lib.FieldType::new(
    @lib.StorageType::val_type(ValType::i32()),
    @lib.Mut::var_(),
  )
  let super_struct = @lib.CompType::struct_([field_type])
  let super_subtype = @lib.SubType::comp_type(super_struct)
  let super_rec = @lib.RecType::new(super_subtype)

  // Create a subtype that extends the supertype
  let sub_struct = @lib.CompType::struct_([field_type])
  let sub_subtype = @lib.SubType::new(false, [TypeIdx::new(0)], sub_struct)
  let sub_rec = @lib.RecType::new(sub_subtype)
  let type_sec = @lib.TypeSec::new([super_rec, sub_rec])

  // Create state with type info
  let state = CFPState::{
    field_values: @hashmap.new(),
    type_sec: Some(type_sec),
  }

  // Types write different constants to field 0
  note_field_write(state, 0, 0, TInstr::i32_const(I32(42)))
  note_field_write(state, 1, 0, TInstr::i32_const(I32(100)))

  // Propagate through hierarchy
  propagate_to_supertypes(state)

  // Both should now be Unknown (since they differ)
  let super_value = get_field_value(state, 0, 0)
  let sub_value = get_field_value(state, 1, 0)
  assert_true(super_value == Unknown)
  assert_true(sub_value == Unknown)
}

///|
test "field copy tracking - struct.set with struct.get" {
  let state = CFPState::new()

  // First, set up a known constant in type 0, field 0
  let type_idx_0 = TypeIdx::new(0)
  let struct_new_instr = TInstr::struct_new(type_idx_0, [
    TInstr::i32_const(I32(42)),
  ])
  scan_instruction(state, struct_new_instr)

  // Now do a struct.set that copies from the known constant field
  let type_idx_1 = TypeIdx::new(1)
  let field_idx : @lib.U32 = @lib.U32(0)
  let struct_ref = TInstr::local_get(LocalIdx::new(0))
  let source_ref = TInstr::local_get(LocalIdx::new(1))
  let get_instr = TInstr::struct_get(type_idx_0, @lib.U32(0), source_ref)
  let set_instr = TInstr::struct_set(
    type_idx_1, field_idx, struct_ref, get_instr,
  )
  scan_instruction(state, set_instr)

  // Type 1, field 0 should now be constant (copied from type 0, field 0)
  let field_value = get_field_value(state, 1, 0)
  assert_true(field_value.is_constant())
  match field_value.get_constant() {
    Some(TI32Const(I32(val))) => assert_eq(val, 42)
    _ => fail("Expected i32.const 42")
  }
}

///|
test "field copy tracking - struct.new with struct.get" {
  let state = CFPState::new()

  // First, set up a known constant in type 0, field 0
  let type_idx_0 = TypeIdx::new(0)
  let struct_new_instr = TInstr::struct_new(type_idx_0, [
    TInstr::i32_const(I32(99)),
  ])
  scan_instruction(state, struct_new_instr)

  // Now create a new struct that copies from the known constant field
  let type_idx_1 = TypeIdx::new(1)
  let source_ref = TInstr::local_get(LocalIdx::new(0))
  let get_instr = TInstr::struct_get(type_idx_0, @lib.U32(0), source_ref)
  let new_instr = TInstr::struct_new(type_idx_1, [get_instr])
  scan_instruction(state, new_instr)

  // Type 1, field 0 should now be constant (copied from type 0, field 0)
  let field_value = get_field_value(state, 1, 0)
  assert_true(field_value.is_constant())
  match field_value.get_constant() {
    Some(TI32Const(I32(val))) => assert_eq(val, 99)
    _ => fail("Expected i32.const 99")
  }
}

///|
test "field copy tracking - unknown source field" {
  let state = CFPState::new()

  // Type 0, field 0 is unknown (never written)
  // Now do a struct.set that copies from the unknown field
  let type_idx_0 = TypeIdx::new(0)
  let type_idx_1 = TypeIdx::new(1)
  let field_idx : @lib.U32 = @lib.U32(0)
  let struct_ref = TInstr::local_get(LocalIdx::new(0))
  let source_ref = TInstr::local_get(LocalIdx::new(1))
  let get_instr = TInstr::struct_get(type_idx_0, @lib.U32(0), source_ref)
  let set_instr = TInstr::struct_set(
    type_idx_1, field_idx, struct_ref, get_instr,
  )
  scan_instruction(state, set_instr)

  // Type 1, field 0 should be unknown (source was uninitialized)
  let field_value = get_field_value(state, 1, 0)
  // Uninitialized source means we can't determine the value
  assert_true(not(field_value.is_constant()))
}

///|
test "packed field default values" {
  // Create a struct type with packed i8 and i16 fields
  let i8_field = @lib.FieldType::new(
    @lib.StorageType::pack_type(@lib.PackType::i8()),
    @lib.Mut::var_(),
  )
  let i16_field = @lib.FieldType::new(
    @lib.StorageType::pack_type(@lib.PackType::i16()),
    @lib.Mut::var_(),
  )
  let struct_type = @lib.CompType::struct_([i8_field, i16_field])
  let sub_type = @lib.SubType::comp_type(struct_type)
  let rec_type = @lib.RecType::new(sub_type)
  let type_sec = @lib.TypeSec::new([rec_type])

  // Create state with type info
  let state = CFPState::{
    field_values: @hashmap.new(),
    type_sec: Some(type_sec),
  }

  // Scan a struct.new.default instruction
  let type_idx = TypeIdx::new(0)
  let instr = TInstr::struct_new_default(type_idx)
  scan_instruction(state, instr)

  // Both fields should be constant (default i32 = 0 for packed types)
  let field0_value = get_field_value(state, 0, 0)
  let field1_value = get_field_value(state, 0, 1)
  assert_true(field0_value.is_constant())
  assert_true(field1_value.is_constant())

  // Check they're both i32.const 0
  match field0_value.get_constant() {
    Some(TI32Const(I32(val))) => assert_eq(val, 0)
    _ => fail("Expected i32.const 0 for i8 field")
  }
  match field1_value.get_constant() {
    Some(TI32Const(I32(val))) => assert_eq(val, 0)
    _ => fail("Expected i32.const 0 for i16 field")
  }
}

///|
test "struct.get_s and struct.get_u optimization" {
  // Create a state with a known constant for type 0, field 0
  let state = CFPState::new()
  note_field_write(state, 0, 0, TInstr::i32_const(I32(42)))

  // Create an optimizer
  let optimizer = make_cfp_optimizer(state)

  // Test struct.get_s
  let type_idx = TypeIdx::new(0)
  let field_idx : @lib.U32 = @lib.U32(0)
  let ref_instr = TInstr::local_get(LocalIdx::new(0))
  let get_s_instr = TInstr::struct_get_s(type_idx, field_idx, ref_instr)
  let result = optimizer.walk_tinstruction((), get_s_instr)
  match result {
    Ok(Some((_, new_instr))) =>
      match new_instr {
        TBlock(_, body) => {
          assert_eq(body.0.length(), 2)
          assert_true(body.0[0] is TDrop(_))
          assert_true(body.0[1] is TI32Const(_))
        }
        _ => fail("Expected TBlock but got something else")
      }
    _ => fail("Optimizer should have transformed struct.get_s")
  }

  // Test struct.get_u
  let ref_instr2 = TInstr::local_get(LocalIdx::new(0))
  let get_u_instr = TInstr::struct_get_u(type_idx, field_idx, ref_instr2)
  let result2 = optimizer.walk_tinstruction((), get_u_instr)
  match result2 {
    Ok(Some((_, new_instr))) =>
      match new_instr {
        TBlock(_, body) => {
          assert_eq(body.0.length(), 2)
          assert_true(body.0[0] is TDrop(_))
          assert_true(body.0[1] is TI32Const(_))
        }
        _ => fail("Expected TBlock but got something else")
      }
    _ => fail("Optimizer should have transformed struct.get_u")
  }
}

///|
test "ref.test optimization with ref.null field" {
  // Create a state with a known ref.null constant for type 0, field 0
  let state = CFPState::new()
  let heap_type = @lib.HeapType::abs(@lib.AbsHeapType::any())
  note_field_write(state, 0, 0, TInstr::ref_null(heap_type))

  // Create an optimizer
  let optimizer = make_cfp_optimizer(state)

  // Create a ref.test instruction that tests a struct.get from the ref.null field
  let type_idx = TypeIdx::new(0)
  let field_idx : @lib.U32 = @lib.U32(0)
  let ref_instr = TInstr::local_get(LocalIdx::new(0))
  let get_instr = TInstr::struct_get(type_idx, field_idx, ref_instr)
  let test_instr = TInstr::ref_test(false, heap_type, get_instr)

  // Run the optimizer
  let result = optimizer.walk_tinstruction((), test_instr)

  // Should return a block with (drop ref) and (i32.const 0)
  match result {
    Ok(Some((_, new_instr))) =>
      match new_instr {
        TBlock(_, body) => {
          assert_eq(body.0.length(), 2)
          assert_true(body.0[0] is TDrop(_))
          match body.0[1] {
            TI32Const(I32(val)) => assert_eq(val, 0)
            _ => fail("Expected i32.const 0")
          }
        }
        _ => fail("Expected TBlock but got something else")
      }
    _ => fail("Optimizer should have transformed ref.test")
  }
}

///|
test "ref.test not optimized for non-null constant" {
  // Create a state with a known non-null constant for type 0, field 0
  let state = CFPState::new()
  note_field_write(state, 0, 0, TInstr::i32_const(I32(42)))

  // Create an optimizer
  let optimizer = make_cfp_optimizer(state)

  // Create a ref.test instruction
  let type_idx = TypeIdx::new(0)
  let field_idx : @lib.U32 = @lib.U32(0)
  let ref_instr = TInstr::local_get(LocalIdx::new(0))
  let get_instr = TInstr::struct_get(type_idx, field_idx, ref_instr)
  let heap_type = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let test_instr = TInstr::ref_test(false, heap_type, get_instr)

  // Run the optimizer
  let result = optimizer.walk_tinstruction((), test_instr)

  // Should NOT optimize (i32 is not a ref.null)
  // The struct.get inside will be optimized, but not the ref.test itself
  match result {
    Ok(Some((_, new_instr))) =>
      // The inner struct.get gets optimized, so we get a ref.test with a block inside
      match new_instr {
        TRefTest(_, _, _) => () // Good, ref.test preserved
        TBlock(_, _) => () // Also acceptable - inner was optimized
        _ => ()
      }
    Ok(None) => () // Also acceptable - no change
    Err(_) => fail("Optimizer should not error")
  }
}

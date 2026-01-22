
priv struct Label {
  result : ResultType
  catchable : Bool
}

///|
struct GenValidContext {
  mut func_idx : Int
  funcs : Map[Func, Int]
  sigs : Map[Int, (ResultType, ResultType)]
  func_sigs : Map[Int, Int]
  mut type_idx : Int
  types : Map[RecType, Int]
  mut global_idx : Int
  globals : Array[GlobalType]
  mut locals : Array[ValType]
  mut mem_count : Int
  mut table_count : Int
  // GC types
  struct_types : Array[(Int, Array[FieldType])] // (type_idx, fields)
  array_types : Array[(Int, FieldType)] // (type_idx, element_type)
  // Segments
  mut elem_idx : Int
  elem_modes : Array[ElemMode] // Track elem segment modes for validity
  mut data_idx : Int
  data_modes : Array[DataMode] // Track data segment modes
  // Tags for exception handling
  mut tag_idx : Int
  tag_sigs : Array[(Int, ResultType)] // (tag_idx, param_types)
  rnd : RandomState
  mut label_stack : Array[Label]
}

///|
fn GenValidContext::new(rnd : RandomState) -> GenValidContext {
  {
    func_idx: 0,
    funcs: Map::new(),
    sigs: Map::new(),
    func_sigs: Map::new(),
    type_idx: 0,
    types: Map::new(),
    global_idx: 0,
    globals: [],
    locals: [],
    mem_count: 0,
    table_count: 0,
    struct_types: [],
    array_types: [],
    elem_idx: 0,
    elem_modes: [],
    data_idx: 0,
    data_modes: [],
    tag_idx: 0,
    tag_sigs: [],
    rnd,
    label_stack: []
  }
}

///|
fn GenValidContext::add_tag(
  self : GenValidContext,
  sig_idx : Int,
  params : ResultType,
) -> Int {
  let next = self.tag_idx
  self.tag_idx = next + 1
  self.tag_sigs.push((sig_idx, params))
  next
}

///|
fn GenValidContext::add_signature(
  self : GenValidContext,
  accepts : ResultType,
  returns : ResultType,
) -> Int {
  let next = self.type_idx
  self.type_idx = next + 1
  let rec_type = RecType::new(
    SubType::comp_type(CompType::func(accepts, returns)),
  )
  self.types.set(rec_type, next)
  self.sigs.set(next, (accepts, returns))
  next
}

///|
fn GenValidContext::add_struct_type(
  self : GenValidContext,
  fields : Array[FieldType],
) -> Int {
  let next = self.type_idx
  self.type_idx = next + 1
  let comp_type = CompType::struct_(fields)
  let rec_type = RecType::new(SubType::comp_type(comp_type))
  self.types.set(rec_type, next)
  self.struct_types.push((next, fields))
  next
}

///|
fn GenValidContext::add_array_type(
  self : GenValidContext,
  elem_type : FieldType,
) -> Int {
  let next = self.type_idx
  self.type_idx = next + 1
  let comp_type = CompType::array(elem_type)
  let rec_type = RecType::new(SubType::comp_type(comp_type))
  self.types.set(rec_type, next)
  self.array_types.push((next, elem_type))
  next
}

///|
fn GenValidContext::add_global(
  self : GenValidContext,
  gt : GlobalType,
) -> Int {
  let next = self.global_idx
  self.global_idx = next + 1
  self.globals.push(gt)
  next
}

///|
fn GenValidContext::ensure_memory(self : GenValidContext) -> Unit {
  if self.mem_count == 0 {
    self.mem_count = 1
  }
}

///|
fn GenValidContext::ensure_table(self : GenValidContext) -> Unit {
  if self.table_count == 0 {
    self.table_count = 1
  }
}

fn GenValidContext::empty_labels(self : GenValidContext) -> Array[Int] {
  let result : Array[Int] = []
  for l in 0..<self.label_stack.length() {
    if self.label_stack[l].result == [] {
      result.push(l)
    }
  }
  result
}

///|
fn GenValidContext::add_elem_segment(
  self : GenValidContext,
  mode : ElemMode,
) -> Int {
  let next = self.elem_idx
  self.elem_idx = next + 1
  self.elem_modes.push(mode)
  next
}

///|
fn GenValidContext::add_data_segment(
  self : GenValidContext,
  mode : DataMode,
) -> Int {
  let next = self.data_idx
  self.data_idx = next + 1
  self.data_modes.push(mode)
  next
}

///|
fn GenValidContext::random_int(self : GenValidContext, max : Int) -> Int {
  if max <= 0 {
    return 0
  }
  self.rnd.next_positive_int() % max
}

///|
fn GenValidContext::random_bool(self : GenValidContext) -> Bool {
  self.rnd.next_positive_int() % 2 == 0
}

fn GenValidContext::push_label(
  self : GenValidContext,
  bt : ResultType,
  catchable : Bool
) -> Unit {
  // label 0 = innermost
  self.label_stack.insert(0, Label::{ result: bt, catchable })
}

fn GenValidContext::pop_label(self : GenValidContext) -> Unit {
  // remove innermost label
  ignore(self.label_stack.remove(0))
}

fn GenValidContext::label_count(self : GenValidContext) -> Int {
  self.label_stack.length()
}

///|
fn GenValidContext::get_or_add_signature(
  self : GenValidContext,
  accepts : ResultType,
  returns : ResultType,
) -> Int {
  let rec_type = RecType::new(
    SubType::comp_type(CompType::func(accepts, returns)),
  )
  match self.types.get(rec_type) {
    Some(idx) => idx
    None => self.add_signature(accepts, returns)
  }
}

///|
/// Reserve a function index before the body is generated (for forward references)
fn GenValidContext::reserve_func(
  self : GenValidContext,
  sig_idx : Int,
) -> Int {
  let next = self.func_idx
  self.func_idx = next + 1
  self.func_sigs.set(next, sig_idx)
  next
}

///|
/// Finalize a reserved function by associating it with its body
fn GenValidContext::finalize_func(
  self : GenValidContext,
  func_idx : Int,
  func : Func,
) -> Unit {
  self.funcs.set(func, func_idx)
}

///|
fn GenValidContext::get_callable_funcs(
  self : GenValidContext,
) -> Array[(Int, ResultType, ResultType)] {
  let result : Array[(Int, ResultType, ResultType)] = []
  for t in self.func_sigs.iter() {
    let (func_idx, sig_idx) = t
    match self.sigs.get(sig_idx) {
      Some((accepts, returns)) => result.push((func_idx, accepts, returns))
      None => continue
    }
  }
  result
}

///|
enum TypeGenerationStrategy {
  AtLeast
  AtMost
  Exact
}

///|
pub fn gen_valid_valtype(ctx : GenValidContext) -> ValType {
  match ctx.random_int(4) {
    0 => ValType::i32()
    1 => ValType::i64()
    2 => ValType::f32()
    _ => ValType::f64()
  }
}

///|
pub fn gen_valid_numtype(ctx : GenValidContext) -> NumType {
  match ctx.random_int(4) {
    0 => NumType::i32()
    1 => NumType::i64()
    2 => NumType::f32()
    _ => NumType::f64()
  }
}

///|
/// Generate a storage type for struct/array fields
fn gen_storage_type(ctx : GenValidContext) -> StorageType {
  match ctx.random_int(6) {
    0 => StorageType::val_type(ValType::i32())
    1 => StorageType::val_type(ValType::i64())
    2 => StorageType::val_type(ValType::f32())
    3 => StorageType::val_type(ValType::f64())
    4 => StorageType::pack_type(PackType::i8())
    _ => StorageType::pack_type(PackType::i16())
  }
}

///|
/// Generate table.set instruction (side effect)
fn gen_table_set_tinstr(ctx : GenValidContext) -> TInstr? {
  if ctx.table_count == 0 {
    return None
  }
  let idx = gen_i32_tinstr_simple(ctx)
  let func_ref = if ctx.func_idx > 0 && ctx.random_bool() {
    TInstr::ref_func(
      FuncIdx::new(ctx.random_int(ctx.func_idx).reinterpret_as_uint()),
    )
  } else {
    TRefNull(HeapType::abs(AbsHeapType::func()))
  }
  Some(TTableSet(TableIdx::new(0), idx, func_ref))
}

///|
/// Generate table.size instruction
fn gen_table_size_tinstr(ctx : GenValidContext) -> TInstr? {
  if ctx.table_count == 0 {
    return None
  }
  Some(TTableSize(TableIdx::new(0)))
}

///|
/// Generate table.grow instruction
fn gen_table_grow_tinstr(ctx : GenValidContext) -> TInstr? {
  if ctx.table_count == 0 {
    return None
  }
  let init_val = TInstr::ref_null(HeapType::abs(AbsHeapType::func()))
  let delta = TInstr::i32_const(I32(ctx.random_int(5) + 1))
  Some(TTableGrow(TableIdx::new(0), init_val, delta))
}

///|
/// Generate a field type for structs/arrays
fn gen_field_type(ctx : GenValidContext) -> FieldType {
  let storage = gen_storage_type(ctx)
  let mutable = ctx.random_bool()
  FieldType::new(storage, if mutable { Var } else { Const })
}

///|
/// Generate a constant expression for global initialization
fn gen_const_expr(ctx : GenValidContext, vt : ValType) -> Expr {
  match vt {
    NumTypeValType(I32NumType) =>
      Expr::new([Instruction::i32_const(I32(ctx.random_int(100)))])
    NumTypeValType(I64NumType) =>
      Expr::new([Instruction::i64_const(I64(ctx.random_int(100).to_int64()))])
    NumTypeValType(F32NumType) => Expr::new([Instruction::f32_const(F32(1.0))])
    NumTypeValType(F64NumType) =>
      Expr::new([Instruction::f64_const(F64(ctx.random_int(100).to_double()))])
    VecTypeValType =>
      Expr::new([
        Instruction::v128_const(
          b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
          b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
        ),
      ])
    RefTypeValType(rt) => Expr::new([Instruction::ref_null(rt.get_heap_type())])
    BotValType => Expr::new([Instruction::unreachable_()])
  }
}

///|
pub fn gen_valid_result_type(
  ctx : GenValidContext,
  base : ResultType,
  strategy : TypeGenerationStrategy,
) -> ResultType {
  match strategy {
    Exact => base
    AtLeast => {
      let extra = ctx.random_int(3)
      let result = base.copy()
      for _ in 0..<extra {
        result.push(gen_valid_valtype(ctx))
      }
      result
    }
    AtMost => {
      if base.length() == 0 {
        return []
      }
      let keep = ctx.random_int(base.length() + 1)
      base[0:keep].to_array()
    }
  }
}

///|
/// Generate a call instruction with subtype-aware matching
fn gen_call_tinstr_v2(
  ctx : GenValidContext,
  target_types : ResultType,
  strategy : TypeGenerationStrategy,
) -> TInstr? {
  // Only support Exact strategy to avoid multi-value complexity
  guard strategy is Exact else { return None }
  
  let callables = ctx.find_callable_returning(target_types, Exact)
  if callables.length() == 0 {
    return None
  }
  let (func_idx, accepts, _) = callables[ctx.random_int(callables.length())]
  let args : Array[TInstr] = []
  for param_type in accepts {
    args.push(gen_tinstr_of_type(ctx, param_type))
  }
  Some(TInstr::call(FuncIdx::new(func_idx.reinterpret_as_uint()), args))
}

///|
/// Generate a call_indirect instruction
fn gen_call_indirect_tinstr(
  ctx : GenValidContext,
  target_return : ValType,
) -> TInstr? {
  if ctx.table_count == 0 {
    return None
  }

  // Find a signature that returns exactly the target type (single return only)
  let matching_sigs : Array[(Int, ResultType, ResultType)] = []
  for sig_idx, sig in ctx.sigs {
    let (accepts, returns) = sig
    // Only single-return functions to avoid multi-value issues
    if returns.length() == 1 && returns[0] == target_return {
      matching_sigs.push((sig_idx, accepts, returns))
    }
  }
  if matching_sigs.length() == 0 {
    return None
  }
  let (sig_idx, accepts, _) = matching_sigs[ctx.random_int(
      matching_sigs.length(),
    )]
  let args : Array[TInstr] = []
  for param_type in accepts {
    args.push(gen_tinstr_of_type(ctx, param_type))
  }

  // Table index (i32 on stack)
  let table_idx_val = gen_i32_tinstr_simple(ctx)
  Some(
    TInstr::call_indirect(
      TypeIdx::new(sig_idx.reinterpret_as_uint()),
      TableIdx::new(0),
      args,
      table_idx_val,
    ),
  )
}

///|
/// Generate a struct.new instruction
fn gen_struct_new_tinstr(ctx : GenValidContext) -> TInstr? {
  if ctx.struct_types.length() == 0 {
    return None
  }
  let (type_idx, fields) = ctx.struct_types[ctx.random_int(
      ctx.struct_types.length(),
    )]
  let field_values : Array[TInstr] = []
  for field in fields {
    let vt = storage_type_to_valtype(field.get_storage_type())  // Fixed
    field_values.push(gen_tinstr_of_type(ctx, vt))
  }
  Some(TStructNew(TypeIdx::new(type_idx.reinterpret_as_uint()), field_values))
}

///|
/// Generate a struct.get instruction (requires struct on stack)
fn gen_struct_get_tinstr(
  ctx : GenValidContext,
  target_type : ValType,
) -> TInstr? {
  // Find a struct type with a field matching target_type
  for t in ctx.struct_types {
    let (type_idx, fields) = t
    for field_idx, field in fields {
      let field_vt = storage_type_to_valtype(field.get_storage_type())
      if field_vt == target_type {
        // Generate the struct value first
        let field_values : Array[TInstr] = []
        for f in fields {
          let vt = storage_type_to_valtype(f.get_storage_type())
          field_values.push(gen_tinstr_of_type(ctx, vt))
        }
        let struct_val = TInstr::struct_new(
          TypeIdx::new(type_idx.reinterpret_as_uint()),
          field_values,
        )

        // Use signed get for packed types, regular get otherwise
        match field.get_storage_type() {
          PackTypeStorageType(_) =>
            return Some(
              TInstr::struct_get_s(
                TypeIdx::new(type_idx.reinterpret_as_uint()),
                U32(field_idx.reinterpret_as_uint()),
                struct_val,
              ),
            )
          _ =>
            return Some(
              TInstr::struct_get(
                TypeIdx::new(type_idx.reinterpret_as_uint()),
                U32(field_idx.reinterpret_as_uint()),
                struct_val,
              ),
            )
        }
      }
    }
  }
  None
}

///|
/// Generate an array.new instruction
fn gen_array_new_tinstr(ctx : GenValidContext) -> TInstr? {
  if ctx.array_types.length() == 0 {
    return None
  }
  let (type_idx, elem_type) = ctx.array_types[ctx.random_int(
      ctx.array_types.length(),
    )]
  let elem_vt = storage_type_to_valtype(elem_type.get_storage_type())
  match ctx.random_int(3) {
    0 => {
      // array.new with default value and length
      let init_val = gen_tinstr_of_type(ctx, elem_vt)
      let length = TInstr::i32_const(I32(ctx.random_int(10) + 1))
      Some(
        TArrayNew(
          TypeIdx::new(type_idx.reinterpret_as_uint()),
          init_val,
          length,
        ),
      )
    }
    1 => {
      // array.new_default with just length
      let length = TInstr::i32_const(I32(ctx.random_int(10) + 1))
      Some(
        TArrayNewDefault(TypeIdx::new(type_idx.reinterpret_as_uint()), length),
      )
    }
    _ => {
      // array.new_fixed with explicit elements
      let num_elems = ctx.random_int(5) + 1
      let elems : Array[TInstr] = []
      for _ in 0..<num_elems {
        elems.push(gen_tinstr_of_type(ctx, elem_vt))
      }
      Some(
        TInstr::array_new_fixed(
          TypeIdx::new(type_idx.reinterpret_as_uint()),
          elems,
        ),
      )
    }
  }
}

///|
/// Generate an array.get instruction
fn gen_array_get_tinstr(
  ctx : GenValidContext,
  target_type : ValType,
) -> TInstr? {
  for elem_type in ctx.array_types {
    let (type_idx, elem_type) = elem_type
    let elem_vt = storage_type_to_valtype(elem_type.get_storage_type())
    if elem_vt == target_type {
      // Create an array and get from it
      let init_val = gen_tinstr_of_type(ctx, elem_vt)
      let array = TInstr::array_new(
        TypeIdx::new(type_idx.reinterpret_as_uint()),
        init_val,
        TInstr::i32_const(I32(5)),
      )
      let index = TInstr::i32_const(I32(ctx.random_int(5)))
      match elem_type.get_storage_type() {
        PackTypeStorageType(_) =>
          return Some(
            TArrayGetS(
              TypeIdx::new(type_idx.reinterpret_as_uint()),
              array,
              index,
            ),
          )
        _ =>
          return Some(
            TArrayGet(
              TypeIdx::new(type_idx.reinterpret_as_uint()),
              array,
              index,
            ),
          )
      }
    }
  }
  None
}

///|
/// Convert storage type to the corresponding value type
fn storage_type_to_valtype(st : StorageType) -> ValType {
  match st {
    ValTypeStorageType(vt) => vt
    PackTypeStorageType(_) => ValType::i32() // Packed types are accessed as i32
  }
}

///|
/// Generate a call as a side effect (drop all return values)
fn gen_call_side_effect(ctx : GenValidContext) -> TInstr? {
  let callables = ctx.get_callable_funcs()
  if callables.length() == 0 {
    return None
  }

  // Filter to functions with 0 or 1 return values (avoid multi-value complexity)
  let usable_funcs = callables.filter(fn(c) { c.2.length() <= 1 })

  // Prefer void functions
  let void_funcs = usable_funcs.filter(fn(c) { c.2.length() == 0 })
  if void_funcs.length() > 0 {
    let (func_idx, accepts, _) = void_funcs[ctx.random_int(void_funcs.length())]
    let args : Array[TInstr] = []
    for param_type in accepts {
      args.push(gen_tinstr_of_type(ctx, param_type))
    }
    return Some(TCall(FuncIdx::new(func_idx.reinterpret_as_uint()), args))
  }

  if usable_funcs.length() == 0 {
    return None
  }

  // Call single-return function and drop result
  let (func_idx, accepts, _) = usable_funcs[ctx.random_int(usable_funcs.length())]
  let args : Array[TInstr] = []
  for param_type in accepts {
    args.push(gen_tinstr_of_type(ctx, param_type))
  }
  let call = TInstr::call(FuncIdx::new(func_idx.reinterpret_as_uint()), args)
  Some(TDrop(call))
}

///|
fn gen_i32_tinstr(ctx : GenValidContext) -> TInstr {
  match ctx.random_int(6) {
    0 => TI32Const(I32(ctx.rnd.next_int()))
    1 => {
      let a = gen_i32_tinstr_simple(ctx)
      let b = gen_i32_tinstr_simple(ctx)
      TBinary(I32AddOp, a, b)
    }
    2 => {
      let a = gen_i32_tinstr_simple(ctx)
      let b = gen_i32_tinstr_simple(ctx)
      TBinary(I32MulOp, a, b)
    }
    3 => {
      let a = gen_i32_tinstr_simple(ctx)
      let b = gen_i32_tinstr_simple(ctx)
      TBinary(I32SubOp, a, b)
    }
    4 => {
      let a = gen_i32_tinstr_simple(ctx)
      TUnary(I32ClzOp, a)
    }
    _ => TI32Const(I32(ctx.random_int(1000)))
  }
}

///|
fn gen_i32_tinstr_simple(ctx : GenValidContext) -> TInstr {
  for i, local_type in ctx.locals {
    match local_type {
      NumTypeValType(I32NumType) =>
        if ctx.random_bool() {
          return TLocalGet(LocalIdx::new(i.reinterpret_as_uint()))
        }
      _ => continue
    }
  }
  TI32Const(I32(ctx.random_int(100)))
}

///|
fn gen_i64_tinstr(ctx : GenValidContext) -> TInstr {
  match ctx.random_int(4) {
    0 => TI64Const(I64(ctx.rnd.next_int64()))
    1 => {
      let a = gen_i64_tinstr_simple(ctx)
      let b = gen_i64_tinstr_simple(ctx)
      TBinary(I64AddOp, a, b)
    }
    2 => {
      let a = gen_i32_tinstr_simple(ctx)
      TUnary(I64ExtendI32SOp, a)
    }
    _ => TI64Const(I64(ctx.random_int(1000).to_int64()))
  }
}

///|
fn gen_i64_tinstr_simple(ctx : GenValidContext) -> TInstr {
  for i, local_type in ctx.locals {
    match local_type {
      NumTypeValType(I64NumType) =>
        if ctx.random_bool() {
          return TLocalGet(LocalIdx::new(i.reinterpret_as_uint()))
        }
      _ => continue
    }
  }
  TI64Const(I64(ctx.random_int(100).to_int64()))
}

///|
fn gen_f32_tinstr(ctx : GenValidContext) -> TInstr {
  match ctx.random_int(4) {
    0 => TF32Const(F32(Float::from_double(ctx.rnd.next_double())))
    1 => {
      let a = gen_f32_tinstr_simple(ctx)
      let b = gen_f32_tinstr_simple(ctx)
      TBinary(F32AddOp, a, b)
    }
    2 => {
      let a = gen_i32_tinstr_simple(ctx)
      TUnary(F32ConvertI32SOp, a)
    }
    _ => TF32Const(F32(Float::from_double(ctx.random_int(100).to_double())))
  }
}

///|
fn gen_f32_tinstr_simple(ctx : GenValidContext) -> TInstr {
  for i, local_type in ctx.locals {
    match local_type {
      NumTypeValType(F32NumType) =>
        if ctx.random_bool() {
          return TLocalGet(LocalIdx::new(i.reinterpret_as_uint()))
        }
      _ => continue
    }
  }
  TF32Const(F32(1.0))
}

///|
fn gen_f64_tinstr(ctx : GenValidContext) -> TInstr {
  match ctx.random_int(4) {
    0 => TF64Const(F64(ctx.rnd.next_double()))
    1 => {
      let a = gen_f64_tinstr_simple(ctx)
      let b = gen_f64_tinstr_simple(ctx)
      TBinary(F64AddOp, a, b)
    }
    2 => {
      let a = gen_i64_tinstr_simple(ctx)
      TUnary(F64ConvertI64SOp, a)
    }
    _ => TF64Const(F64(ctx.random_int(100).to_double()))
  }
}

///|
fn gen_f64_tinstr_simple(ctx : GenValidContext) -> TInstr {
  for i, local_type in ctx.locals {
    match local_type {
      NumTypeValType(F64NumType) =>
        if ctx.random_bool() {
          return TLocalGet(LocalIdx::new(i.reinterpret_as_uint()))
        }
      _ => continue
    }
  }
  TF64Const(F64(1.0))
}

///|
/// Generate table.get instruction
fn gen_table_get_tinstr(ctx : GenValidContext) -> TInstr? {
  if ctx.table_count == 0 {
    return None
  }
  let idx = gen_i32_tinstr_simple(ctx)
  Some(TTableGet(TableIdx::new(0), idx))
}

///|
/// Generate memory.init instruction
fn gen_memory_init_tinstr(ctx : GenValidContext) -> TInstr? {
  if ctx.mem_count == 0 || ctx.data_idx == 0 {
    return None
  }

  // Find a passive data segment
  for i, mode in ctx.data_modes {
    match mode {
      Passive => {
        let dest = gen_i32_tinstr_simple(ctx)
        let src_offset = TInstr::i32_const(I32(0))
        let size = TInstr::i32_const(I32(ctx.random_int(16) + 1))
        return Some(
          TInstr::memory_init(
            DataIdx::new(i.reinterpret_as_uint()),
            MemIdx::new(0),
            dest,
            src_offset,
            size,
          ),
        )
      }
      _ => continue
    }
  }
  None
}

///|
/// Generate memory.copy instruction
fn gen_memory_copy_tinstr(ctx : GenValidContext) -> TInstr? {
  if ctx.mem_count == 0 {
    return None
  }
  let dest = gen_i32_tinstr_simple(ctx)
  let src = gen_i32_tinstr_simple(ctx)
  let size = TInstr::i32_const(I32(ctx.random_int(64) + 1))
  Some(TMemoryCopy(MemIdx::new(0), MemIdx::new(0), dest, src, size))
}

///|
/// Generate memory.fill instruction
fn gen_memory_fill_tinstr(ctx : GenValidContext) -> TInstr? {
  if ctx.mem_count == 0 {
    return None
  }
  let dest = gen_i32_tinstr_simple(ctx)
  let value = gen_i32_tinstr_simple(ctx)
  let size = TInstr::i32_const(I32(ctx.random_int(64) + 1))
  Some(TMemoryFill(MemIdx::new(0), dest, value, size))
}

///|
/// Generate array.fill instruction (side effect)
fn gen_array_fill_tinstr(ctx : GenValidContext) -> TInstr? {
  for t in ctx.array_types {
    let (type_idx, elem_type) = t
    if elem_type.is_mutable() {
      let elem_vt = storage_type_to_valtype(elem_type.get_storage_type())
      let init_val = gen_tinstr_of_type(ctx, elem_vt)
      let array = TInstr::array_new(
        TypeIdx::new(type_idx.reinterpret_as_uint()),
        init_val,
        TInstr::i32_const(I32(10)),
      )
      let offset = TInstr::i32_const(I32(ctx.random_int(5)))
      let fill_val = gen_tinstr_of_type(ctx, elem_vt)
      let length = TInstr::i32_const(I32(ctx.random_int(5) + 1))
      return Some(
        TArrayFill(
          TypeIdx::new(type_idx.reinterpret_as_uint()),
          array,
          offset,
          fill_val,
          length,
        ),
      )
    }
  }
  None
}

///|
/// Generate array.copy instruction (side effect)
fn gen_array_copy_tinstr(ctx : GenValidContext) -> TInstr? {
  if ctx.array_types.length() == 0 {
    return None
  }

  // Find two compatible array types (same element type)
  for i in 0..<ctx.array_types.length() {
    let (type_idx_dst, elem_type_dst) = ctx.array_types[i]
    if not(elem_type_dst.is_mutable()) {
      continue
    }
    for j in 0..<ctx.array_types.length() {
      let (type_idx_src, elem_type_src) = ctx.array_types[j]
      if elem_type_dst.get_storage_type() == elem_type_src.get_storage_type() {
        let elem_vt = storage_type_to_valtype(elem_type_dst.get_storage_type())

        // Create destination array
        let dst_init = gen_tinstr_of_type(ctx, elem_vt)
        let dst = TInstr::array_new(
          TypeIdx::new(type_idx_dst.reinterpret_as_uint()),
          dst_init,
          TInstr::i32_const(I32(10)),
        )

        // Create source array
        let src_init = gen_tinstr_of_type(ctx, elem_vt)
        let src = TInstr::array_new(
          TypeIdx::new(type_idx_src.reinterpret_as_uint()),
          src_init,
          TInstr::i32_const(I32(10)),
        )
        let dst_offset = TInstr::i32_const(I32(ctx.random_int(5)))
        let src_offset = TInstr::i32_const(I32(ctx.random_int(5)))
        let length = TInstr::i32_const(I32(ctx.random_int(3) + 1))
        return Some(
          TArrayCopy(
            TypeIdx::new(type_idx_dst.reinterpret_as_uint()),
            TypeIdx::new(type_idx_src.reinterpret_as_uint()),
            dst,
            dst_offset,
            src,
            src_offset,
            length,
          ),
        )
      }
    }
  }
  None
}

///|
/// Generate array.len instruction
fn gen_array_len_tinstr(ctx : GenValidContext) -> TInstr? {
  match gen_array_new_tinstr(ctx) {
    Some(array_instr) => Some(TArrayLen(array_instr))
    None => None
  }
}

fn gen_ref_test_tinstr(ctx : GenValidContext) -> TInstr? {
  let ref_val =
    match gen_known_ref_value(ctx) {
      Some(v) => v
      None => return None
    }

  let test_heap_type =
    if ctx.random_bool() {
      HeapType::abs(AbsHeapType::struct_())
    } else {
      HeapType::abs(AbsHeapType::array())
    }

  Some(TInstr::ref_test(false, test_heap_type, ref_val))
}

///|
fn gen_v128_tinstr(ctx : GenValidContext) -> TInstr {
  if ctx.random_bool() {
    TV128Const(
      b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    )
  } else {
    TI32x4Splat(gen_i32_tinstr_simple(ctx))
  }
}

///|
fn gen_ref_tinstr(ctx : GenValidContext, rt : RefType) -> TInstr {
  match rt.get_heap_type() {
    AbsHeapTypeHeapType(StructAbsHeapType) =>
      match gen_struct_new_tinstr(ctx) {
        Some(instr) => instr
        None => TRefNull(rt.get_heap_type())
      }
    AbsHeapTypeHeapType(ArrayAbsHeapType) =>
      match gen_array_new_tinstr(ctx) {
        Some(instr) => instr
        None => TRefNull(rt.get_heap_type())
      }
    AbsHeapTypeHeapType(FuncAbsHeapType) =>
      if ctx.func_idx > 0 && ctx.random_bool() {
        TRefFunc(
          FuncIdx::new(ctx.random_int(ctx.func_idx).reinterpret_as_uint()),
        )
      } else {
        TRefNull(rt.get_heap_type())
      }
    _ => TRefNull(rt.get_heap_type())
  }
}

///|
/// Check if a result type is a subtype of another (for call compatibility)
/// In WebAssembly, [t1*] <: [t2*] if they have same length and each t1 <: t2
fn is_result_subtype(sub : ResultType, sup : ResultType) -> Bool {
  if sub.length() != sup.length() {
    return false
  }
  for i in 0..<sub.length() {
    if not(is_valtype_subtype(sub[i], sup[i])) {
      return false
    }
  }
  true
}

///|
/// Subtype check for abstract heap types
fn is_abs_heaptype_subtype(sub : AbsHeapType, sup : AbsHeapType) -> Bool {
  if sub == sup {
    return true
  }
  match (sub, sup) {
    // func <: func, nofunc <: func
    (NoFuncAbsHeapType, FuncAbsHeapType) => true
    // extern <: extern, noextern <: extern
    (NoExternAbsHeapType, ExternAbsHeapType) => true
    // i31, struct, array, none <: eq <: any
    (I31AbsHeapType, EqAbsHeapType) => true
    (I31AbsHeapType, AnyAbsHeapType) => true
    (StructAbsHeapType, EqAbsHeapType) => true
    (StructAbsHeapType, AnyAbsHeapType) => true
    (ArrayAbsHeapType, EqAbsHeapType) => true
    (ArrayAbsHeapType, AnyAbsHeapType) => true
    (NoneAbsHeapType, EqAbsHeapType) => true
    (NoneAbsHeapType, AnyAbsHeapType) => true
    (NoneAbsHeapType, I31AbsHeapType) => true
    (NoneAbsHeapType, StructAbsHeapType) => true
    (NoneAbsHeapType, ArrayAbsHeapType) => true
    (EqAbsHeapType, AnyAbsHeapType) => true
    _ => false
  }
}

///|
/// Find functions whose return type is compatible with target using subtyping
fn GenValidContext::find_callable_returning(
  self : GenValidContext,
  target : ResultType,
  strategy : TypeGenerationStrategy,
) -> Array[(Int, ResultType, ResultType)] {
  let result : Array[(Int, ResultType, ResultType)] = []
  for func_idx, sig_idx in self.func_sigs {
    match self.sigs.get(sig_idx) {
      Some((accepts, returns)) => {
        let compatible = match strategy {
          Exact =>
            is_result_subtype(returns, target) &&
            returns.length() == target.length()
          AtLeast =>
            // Returns at least target types (can have more)
            if returns.length() < target.length() {
              false
            } else {
              let mut ok = true
              for i in 0..<target.length() {
                if not(is_valtype_subtype(returns[i], target[i])) {
                  ok = false
                  break
                }
              }
              ok
            }
          AtMost =>
            // Returns at most target types (can have fewer)
            if returns.length() > target.length() {
              false
            } else {
              let mut ok = true
              for i in 0..<returns.length() {
                if not(is_valtype_subtype(returns[i], target[i])) {
                  ok = false
                  break
                }
              }
              ok
            }
        }
        if compatible {
          result.push((func_idx, accepts, returns))
        }
      }
      None => continue
    }
  }
  result
}

///|
/// Subtype check for heap types (simplified)
fn is_heaptype_subtype(sub : HeapType, sup : HeapType) -> Bool {
  match (sub, sup) {
    (AbsHeapTypeHeapType(a), AbsHeapTypeHeapType(b)) =>
      is_abs_heaptype_subtype(a, b)
    (HeapType(a), HeapType(b)) => a == b // Simplified: exact match only
    (HeapType(_), AbsHeapTypeHeapType(AnyAbsHeapType)) => true
    (HeapType(_), AbsHeapTypeHeapType(EqAbsHeapType)) => true
    _ => sub == sup
  }
}

///|
/// Subtype check for reference types
fn is_reftype_subtype(sub : RefType, sup : RefType) -> Bool {
  // If sup is nullable and sub is not, that's fine
  // If sup is not nullable and sub is nullable, that's not fine
  if not(sup.is_nullable()) && sub.is_nullable() {
    return false
  }
  is_heaptype_subtype(sub.get_heap_type(), sup.get_heap_type())
}

///|
/// Simple subtype check for value types
fn is_valtype_subtype(sub : ValType, sup : ValType) -> Bool {
  match (sub, sup) {
    (NumTypeValType(a), NumTypeValType(b)) => a == b
    (VecTypeValType, VecTypeValType) => true
    (RefTypeValType(sub_rt), RefTypeValType(sup_rt)) =>
      is_reftype_subtype(sub_rt, sup_rt)
    (BotValType, _) => true // bot is subtype of everything
    _ => sub == sup
  }
}

///|
/// Generate struct.set side effect
fn gen_struct_set_tinstr(ctx : GenValidContext) -> TInstr? {
  // Find a mutable struct field
  for fields in ctx.struct_types {
    let (type_idx, fields) = fields
    for field_idx, field in fields {
      if field.is_mutable() {
        let field_vt = storage_type_to_valtype(field.get_storage_type())
        // Create struct, then set a field
        let field_values : Array[TInstr] = []
        for f in fields {
          let vt = storage_type_to_valtype(f.get_storage_type())
          field_values.push(gen_tinstr_of_type(ctx, vt))
        }
        let struct_val = TInstr::struct_new(
          TypeIdx::new(type_idx.reinterpret_as_uint()),
          field_values,
        )
        let new_value = gen_tinstr_of_type(ctx, field_vt)
        return Some(
          TStructSet(
            TypeIdx::new(type_idx.reinterpret_as_uint()),
            U32(field_idx.reinterpret_as_uint()),
            struct_val,
            new_value,
          ),
        )
      }
    }
  }
  None
}

///|
/// Generate array.set side effect
fn gen_array_set_tinstr(ctx : GenValidContext) -> TInstr? {
  for t in ctx.array_types {
    let (type_idx, elem_type) = t
    if elem_type.is_mutable() {
      let elem_vt = storage_type_to_valtype(elem_type.get_storage_type())
      let init_val =
        match elem_vt {
          RefTypeValType(rt) => gen_ref_tinstr(ctx, rt)
          _ => gen_tinstr_of_type(ctx, elem_vt)
        }
      let array = TInstr::array_new(
        TypeIdx::new(type_idx.reinterpret_as_uint()),
        init_val,
        TInstr::i32_const(I32(5)),
      )
      let index = TInstr::i32_const(I32(ctx.random_int(5)))
      let new_value = gen_tinstr_of_type(ctx, elem_vt)
      return Some(
        TArraySet(
          TypeIdx::new(type_idx.reinterpret_as_uint()),
          array,
          index,
          new_value,
        ),
      )
    }
  }
  None
}

///|
fn gen_simple_side_effect(ctx : GenValidContext) -> TInstr {
  if ctx.locals.length() > 0 && ctx.random_bool() {
    let idx = ctx.random_int(ctx.locals.length())
    let local_type = ctx.locals[idx]
    let value = gen_tinstr_of_type(ctx, local_type)
    TLocalSet(LocalIdx::new(idx.reinterpret_as_uint()), value)
  } else {
    TDrop(gen_tinstr_of_type(ctx, gen_valid_valtype(ctx)))
  }
}

///|
fn gen_store_tinstr(ctx : GenValidContext) -> TInstr {
  let addr = gen_i32_tinstr_simple(ctx)
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  match ctx.random_int(4) {
    0 => {
      let value = gen_i32_tinstr_simple(ctx)
      TStore(I32StoreOp, mem_arg, addr, value)
    }
    1 => {
      let value = gen_i64_tinstr_simple(ctx)
      TStore(I64StoreOp, mem_arg, addr, value)
    }
    2 => {
      let value = gen_f32_tinstr_simple(ctx)
      TStore(F32StoreOp, mem_arg, addr, value)
    }
    _ => {
      let value = gen_f64_tinstr_simple(ctx)
      TStore(F64StoreOp, mem_arg, addr, value)
    }
  }
}

///|
/// Generate local initialization instructions (now integrated into gen_valid_tfunc)
fn gen_local_inits(ctx : GenValidContext, param_count : Int) -> Array[TInstr] {
  let inits : Array[TInstr] = []
  for i in param_count..<ctx.locals.length() {
    let local_type = ctx.locals[i]
    let init_value = gen_default_value(ctx, local_type)
    inits.push(TLocalSet(LocalIdx::new(i.reinterpret_as_uint()), init_value))
  }
  inits
}

///|
fn gen_default_value(ctx : GenValidContext, vt : ValType) -> TInstr {
  match vt {
    NumTypeValType(I32NumType) => TI32Const(I32(ctx.random_int(100)))
    NumTypeValType(I64NumType) => TI64Const(I64(ctx.random_int(100).to_int64()))
    NumTypeValType(F32NumType) =>
      TF32Const(F32(Float::from_double(ctx.random_int(100).to_double())))
    NumTypeValType(F64NumType) =>
      TF64Const(F64(ctx.random_int(100).to_double()))
    VecTypeValType =>
      TV128Const(
        b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
        b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      )
    RefTypeValType(rt) => TRefNull(rt.get_heap_type())
    BotValType => TUnreachable
  }
}

///|
/// Generate data segments
fn gen_data_segments(ctx : GenValidContext) -> Array[Data] {
  let segments : Array[Data] = []
  let num_segments = ctx.random_int(3) + 1
  for _ in 0..<num_segments {
    // Random bytes for data
    let data_len = ctx.random_int(32) + 8
    let bytes : Array[Byte] = []
    for _ in 0..<data_len {
      bytes.push(ctx.random_int(256).to_byte())
    }
    if ctx.mem_count > 0 && ctx.random_bool() {
      // Active data segment
      let offset = Expr::new([Instruction::i32_const(I32(ctx.random_int(1024)))])
      let mode = DataMode::active(MemIdx::new(0), offset)
      ignore(ctx.add_data_segment(mode))
      segments.push(Data::new(mode, Bytes::from_array(bytes)))
    } else {
      // Passive data segment
      let mode = DataMode::passive()
      ignore(ctx.add_data_segment(mode))
      segments.push(Data::new(mode, Bytes::from_array(bytes)))
    }
  }
  segments
}

///|
/// Generate elem segments
fn gen_elem_segments(ctx : GenValidContext) -> Array[Elem] {
  let segments : Array[Elem] = []
  if ctx.func_idx == 0 {
    return segments
  }
  let num_segments = ctx.random_int(2) + 1
  for _ in 0..<num_segments {
    // Generate funcref expressions
    let num_refs = ctx.random_int(5) + 1
    let init_exprs : Array[Expr] = []
    for _ in 0..<num_refs {
      let func_idx = ctx.random_int(ctx.func_idx)
      init_exprs.push(
        Expr::new([Instruction::ref_func(FuncIdx::new(func_idx.reinterpret_as_uint()))]),
      )
    }
    let ref_type = RefType::new(true, HeapType::abs(AbsHeapType::func()))
    if ctx.table_count > 0 && ctx.random_bool() {
      // Active elem segment
      let offset = Expr::new([Instruction::i32_const(I32(ctx.random_int(10)))])
      let mode = ElemMode::active(TableIdx::new(0), offset)
      let kind = ElemKind::typed_exprs(ref_type, init_exprs)
      ignore(ctx.add_elem_segment(mode))
      // ref_type, init_exprs, mode
      segments.push(Elem::new(mode, kind))
    } else if ctx.random_bool() {
      // Declarative elem segment
      let mode = ElemMode::declarative()
      let kind = ElemKind::typed_exprs(ref_type, init_exprs)
      ignore(ctx.add_elem_segment(mode))
      segments.push(Elem::new(mode, kind))
    } else {
      // Passive elem segment
      let mode = ElemMode::passive()
      let kind = ElemKind::typed_exprs(ref_type, init_exprs)
      ignore(ctx.add_elem_segment(mode))
      segments.push(Elem::new(mode, kind))
    }
  }
  segments
}

///|
/// Generate a br_if instruction (side effect - conditionally branches)
fn gen_br_if_tinstr(ctx : GenValidContext) -> TInstr? {
  let empty_labels = ctx.empty_labels()
  if empty_labels.length() == 0 {
    return None
  }

  let label = empty_labels[ctx.random_int(empty_labels.length())]
  let cond = gen_i32_tinstr_simple(ctx)
  Some(TInstr::br_if(LabelIdx::new(label.reinterpret_as_uint()), cond, []))
}

///|
/// Generate a br_table instruction (side effect)
fn gen_br_table_tinstr(ctx : GenValidContext) -> TInstr? {
  let empty_labels = ctx.empty_labels()
  if empty_labels.length() == 0 {
    return None
  }

  let num_labels = ctx.random_int(3) + 1
  let labels : Array[LabelIdx] = []
  for _ in 0..<num_labels {
    let l = empty_labels[ctx.random_int(empty_labels.length())]
    labels.push(LabelIdx::new(l.reinterpret_as_uint()))
  }

  let default_label =
    LabelIdx::new(
      empty_labels[ctx.random_int(empty_labels.length())]
        .reinterpret_as_uint(),
    )

  let index = gen_i32_tinstr_simple(ctx)
  Some(TInstr::br_table(labels, default_label, index, []))
}

///|
/// Generate a throw instruction
fn gen_throw_tinstr(ctx : GenValidContext) -> TInstr? {
  if ctx.tag_idx == 0 {
    return None
  }
  let tag_idx_val = ctx.random_int(ctx.tag_idx)
  let (_, params) = ctx.tag_sigs[tag_idx_val]
  let args : Array[TInstr] = []
  for param_type in params {
    args.push(gen_tinstr_of_type(ctx, param_type))
  }
  Some(TThrow(TagIdx::new(tag_idx_val.reinterpret_as_uint()), args))
}

fn gen_try_table_tinstr(ctx : GenValidContext) -> TInstr? {
  // Must have tags
  if ctx.tag_idx == 0 {
    return None
  }

  // Must have an enclosing label (label 1)
  if ctx.label_stack.length() <= 1 {
    return None
  }

  let enclosing = ctx.label_stack[1]

  // Enclosing label must be catchable and void
  if !enclosing.catchable || enclosing.result.length() != 0 {
    return None
  }

  // Only allow EMPTY payload tags
  let empty_tags : Array[Int] = []
  for tag_i in 0..<ctx.tag_idx {
    let (_, params) = ctx.tag_sigs[tag_i]
    if params.length() == 0 {
      empty_tags.push(tag_i)
    }
  }

  if empty_tags.length() == 0 {
    return None
  }

  let tag_idx_val =
    empty_tags[ctx.random_int(empty_tags.length())]

  // try body
  ctx.push_label([], false)

  let body_instrs : Array[TInstr] = [
    TThrow(
      TagIdx::new(tag_idx_val.reinterpret_as_uint()),
      [],
    ),
  ]

  if ctx.random_bool() {
    body_instrs.push(gen_simple_side_effect(ctx))
  }

  ctx.pop_label()

  Some(
    TTryTable(
      EmptyBlockType,
      [
        Catch::new(
          TagIdx::new(tag_idx_val.reinterpret_as_uint()),
          LabelIdx::new(1U),
        ),
      ],
      TExpr::new(body_instrs),
    ),
  )
}

///|
/// Generate global.get instruction
fn gen_global_get_tinstr(ctx : GenValidContext, target_type : ValType) -> TInstr? {
  for i, gt in ctx.globals {
    let GlobalType(vt, _) = gt
    if vt == target_type {
      return Some(TGlobalGet(GlobalIdx::new(i.reinterpret_as_uint())))
    }
  }
  None
}

///|
/// Generate a load instruction
fn gen_load_tinstr(ctx : GenValidContext, target_type : ValType) -> TInstr? {
  if ctx.mem_count == 0 {
    return None
  }
  let addr = gen_i32_tinstr_simple(ctx)
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  match target_type {
    NumTypeValType(I32NumType) => Some(TLoad(LoadOp::i32_load(), mem_arg, addr))
    NumTypeValType(I64NumType) => Some(TLoad(LoadOp::i64_load(), mem_arg, addr))
    NumTypeValType(F32NumType) => Some(TLoad(LoadOp::f32_load(), mem_arg, addr))
    NumTypeValType(F64NumType) => Some(TLoad(LoadOp::f64_load(), mem_arg, addr))
    _ => None
  }
}

///|
/// Enhanced gen_tinstr_of_type with more variety including globals and loads
pub fn gen_tinstr_of_type(ctx : GenValidContext, vt : ValType) -> TInstr {
  // Sometimes use a local if available
  if ctx.random_int(6) == 0 {
    for i, local_type in ctx.locals {
      if local_type == vt {
        return TLocalGet(LocalIdx::new(i.reinterpret_as_uint()))
      }
    }
  }

  // Sometimes use a global
  if ctx.random_int(6) == 0 {
    match gen_global_get_tinstr(ctx, vt) {
      Some(instr) => return instr
      None => ()
    }
  }

  // Sometimes use a memory load
  if ctx.random_int(8) == 0 {
    match gen_load_tinstr(ctx, vt) {
      Some(instr) => return instr
      None => ()
    }
  }

  // Sometimes try to generate a call with subtyping
  if ctx.random_int(8) == 0 {
    let strategy = match ctx.random_int(3) {
      0 => Exact
      1 => AtLeast
      _ => AtMost
    }
    match gen_call_tinstr_v2(ctx, [vt], strategy) {
      Some(call) => return call
      None => ()
    }
  }

  // Sometimes try call_indirect
  if ctx.random_int(12) == 0 {
    match gen_call_indirect_tinstr(ctx, vt) {
      Some(call) => return call
      None => ()
    }
  }

  // Sometimes try struct.get
  if ctx.random_int(10) == 0 {
    match gen_struct_get_tinstr(ctx, vt) {
      Some(instr) => return instr
      None => ()
    }
  }

  // Sometimes try array.get
  if ctx.random_int(10) == 0 {
    match gen_array_get_tinstr(ctx, vt) {
      Some(instr) => return instr
      None => ()
    }
  }

  // For i32, try additional sources
  match vt {
    NumTypeValType(I32NumType) => {
      if ctx.random_int(15) == 0 {
        match gen_ref_test_tinstr(ctx) {
          Some(instr) => return instr
          None => ()
        }
      }
      if ctx.random_int(15) == 0 {
        match gen_array_len_tinstr(ctx) {
          Some(instr) => return instr
          None => ()
        }
      }
      if ctx.random_int(15) == 0 {
        match gen_table_size_tinstr(ctx) {
          Some(instr) => return instr
          None => ()
        }
      }
      gen_i32_tinstr(ctx)
    }
    NumTypeValType(I64NumType) => gen_i64_tinstr(ctx)
    NumTypeValType(F32NumType) => gen_f32_tinstr(ctx)
    NumTypeValType(F64NumType) => gen_f64_tinstr(ctx)
    VecTypeValType => gen_v128_tinstr(ctx)
    RefTypeValType(rt) => gen_ref_tinstr(ctx, rt)
    BotValType => TUnreachable
  }
}

fn gen_known_ref_value(ctx : GenValidContext) -> TInstr? {
  // locals
  for i, vt in ctx.locals {
    match vt {
      RefTypeValType(_) =>
        if ctx.random_bool() {
          return Some(TLocalGet(LocalIdx::new(i.reinterpret_as_uint())))
        }
      _ => ()
    }
  }

  // globals
  for i, gt in ctx.globals {
    let GlobalType(vt, _) = gt
    match vt {
      RefTypeValType(_) =>
        if ctx.random_bool() {
          return Some(TGlobalGet(GlobalIdx::new(i.reinterpret_as_uint())))
        }
      _ => ()
    }
  }

  // fallback
  None
}

///|
/// Enhanced gen_side_effect_tinstr with label depth for branches
pub fn gen_side_effect_tinstr(
  ctx : GenValidContext,
  depth : Int,
  label_depth~ : Int = 0,
) -> TInstr {
  if depth > 3 {
    return gen_simple_side_effect(ctx)
  }

  let has_mem = ctx.mem_count > 0
  let has_table = ctx.table_count > 0
  let has_callables = ctx.get_callable_funcs().length() > 0
  let has_structs = ctx.struct_types.length() > 0
  let has_arrays = ctx.array_types.length() > 0
  let has_data = ctx.data_idx > 0
  let has_elem = ctx.elem_idx > 0
  let has_tags = ctx.tag_idx > 0
  let has_globals = ctx.globals.length() > 0
  let has_labels = ctx.label_count() > 0
  let has_passive_data = ctx.data_modes.iter().any(fn(m) {
    match m {
      Passive => true
      _ => false
    }
  })

  let ops : Array[() -> TInstr?] = []

  // ------------------------------------------------------------
  // Basic side effects
  // ------------------------------------------------------------
  ops.push(fn() {
    if ctx.locals.length() > 0 {
      let idx = ctx.random_int(ctx.locals.length())
      let vt = ctx.locals[idx]
      Some(
        TLocalSet(
          LocalIdx::new(idx.reinterpret_as_uint()),
          gen_tinstr_of_type(ctx, vt),
        ),
      )
    } else {
      Some(TDrop(gen_tinstr_of_type(ctx, gen_valid_valtype(ctx))))
    }
  })

  ops.push(fn() {
    Some(TDrop(gen_tinstr_of_type(ctx, gen_valid_valtype(ctx))))
  })

  // ------------------------------------------------------------
  // Block
  // ------------------------------------------------------------
  ops.push(fn() {
    ctx.push_label([], true)
    let n = ctx.random_int(3) + 1
    let instrs : Array[TInstr] = []
    for _ in 0..<n {
      instrs.push(gen_side_effect_tinstr(ctx, depth + 1))
    }
    ctx.pop_label()
    Some(TBlock(EmptyBlockType, TExpr::new(instrs)))
  })

  // ------------------------------------------------------------
  // Loop
  // ------------------------------------------------------------
  ops.push(fn() {
    ctx.push_label([], true)
    let n = ctx.random_int(2) + 1
    let instrs : Array[TInstr] = []
    for _ in 0..<n {
      instrs.push(
        gen_side_effect_tinstr(ctx, depth + 1, label_depth=label_depth + 1),
      )
    }
    ctx.pop_label()
    Some(TLoop(EmptyBlockType, TExpr::new(instrs)))
  })

  // ------------------------------------------------------------
  // If
  // ------------------------------------------------------------
  ops.push(fn() {
    let cond = gen_i32_tinstr_simple(ctx)
    ctx.push_label([], true)

    let then_instrs : Array[TInstr] = []
    for _ in 0..<(ctx.random_int(2) + 1) {
      then_instrs.push(gen_side_effect_tinstr(ctx, depth + 1))
    }

    let else_branch =
      if ctx.random_bool() {
        let else_instrs : Array[TInstr] = []
        for _ in 0..<(ctx.random_int(2) + 1) {
          else_instrs.push(gen_side_effect_tinstr(ctx, depth + 1))
        }
        Some(TExpr::new(else_instrs))
      } else {
        None
      }

    ctx.pop_label()
    Some(TIf(EmptyBlockType, cond, TExpr::new(then_instrs), else_branch))
  })

  // ------------------------------------------------------------
  // Branches
  // ------------------------------------------------------------
  if has_labels {
    ops.push(fn() { gen_br_if_tinstr(ctx) })
    ops.push(fn() { gen_br_table_tinstr(ctx) })
  }

  // ------------------------------------------------------------
  // Globals
  // ------------------------------------------------------------
  if has_globals {
    ops.push(fn() {
      let muts : Array[(Int, ValType)] = []
      for i, gt in ctx.globals {
        let GlobalType(vt, mut_) = gt
        if mut_ {
          muts.push((i, vt))
        }
      }
      if muts.length() == 0 {
        return None
      }
      let (i, vt) = muts[ctx.random_int(muts.length())]
      Some(
        TInstr::global_set(
          GlobalIdx::new(i.reinterpret_as_uint()),
          gen_tinstr_of_type(ctx, vt),
        ),
      )
    })

    ops.push(fn() {
      let i = ctx.random_int(ctx.globals.length())
      Some(TDrop(TGlobalGet(GlobalIdx::new(i.reinterpret_as_uint()))))
    })
  }

  // ------------------------------------------------------------
  // Memory
  // ------------------------------------------------------------
  if has_mem {
    ops.push(fn() { Some(gen_store_tinstr(ctx)) })
    ops.push(fn() { gen_memory_fill_tinstr(ctx) })
    ops.push(fn() { gen_memory_copy_tinstr(ctx) })
    ops.push(fn() { Some(TDrop(TMemorySize(MemIdx::new(0)))) })
    ops.push(fn() {
      Some(
        TDrop(
          TMemoryGrow(
            MemIdx::new(0),
            gen_i32_tinstr_simple(ctx),
          ),
        ),
      )
    })
  }

  if has_mem && has_passive_data {
    ops.push(fn() { gen_memory_init_tinstr(ctx) })
  }

  // ------------------------------------------------------------
  // Table
  // ------------------------------------------------------------
  if has_table {
    ops.push(fn() { gen_table_set_tinstr(ctx) })
    ops.push(fn() {
      Some(
        TDrop(
          gen_table_grow_tinstr(ctx)
            .unwrap_or(TInstr::i32_const(I32(0))),
        ),
      )
    })
    ops.push(fn() {
      match gen_table_get_tinstr(ctx) {
        Some(x) => Some(TDrop(x))
        None => None
      }
    })
    ops.push(fn() {
      match gen_table_size_tinstr(ctx) {
        Some(x) => Some(TDrop(x))
        None => None
      }
    })
  }

  // ------------------------------------------------------------
  // Calls / GC / Segments
  // ------------------------------------------------------------
  if has_callables {
    ops.push(fn() { gen_call_side_effect(ctx) })
  }
  if has_structs {
    ops.push(fn() { gen_struct_set_tinstr(ctx) })
  }
  if has_arrays {
    ops.push(fn() { gen_array_set_tinstr(ctx) })
    ops.push(fn() { gen_array_fill_tinstr(ctx) })
    ops.push(fn() { gen_array_copy_tinstr(ctx) })
  }
  if has_data {
    ops.push(fn() {
      Some(TDataDrop(DataIdx::new(
        ctx.random_int(ctx.data_idx).reinterpret_as_uint(),
      )))
    })
  }
  if has_elem {
    ops.push(fn() {
      Some(TElemDrop(ElemIdx::new(
        ctx.random_int(ctx.elem_idx).reinterpret_as_uint(),
      )))
    })
  }

  // ------------------------------------------------------------
  // Exception handling (FINAL, SAFE)
  // ------------------------------------------------------------
  if has_tags {
    // Wrapper try_table ONLY for empty-payload tags
    ops.push(fn() {
      if ctx.label_stack.length() <= 1 {
        return None
      }

      let enclosing = ctx.label_stack[1]
      if !enclosing.catchable || enclosing.result.length() != 0 {
        return None
      }

      let empty_tags : Array[Int] = []
      for tag_i in 0..<ctx.tag_idx {
        let (_, params) = ctx.tag_sigs[tag_i]
        if params.length() == 0 {
          empty_tags.push(tag_i)
        }
      }

      if empty_tags.length() == 0 {
        return None
      }

      let tag_idx_val =
        empty_tags[ctx.random_int(empty_tags.length())]

      match gen_throw_tinstr(ctx) {
        Some(throw_instr) =>
          Some(
            TTryTable(
              EmptyBlockType,
              [
                Catch::new(
                  TagIdx::new(tag_idx_val.reinterpret_as_uint()),
                  LabelIdx::new(1U),
                ),
              ],
              TExpr::new([throw_instr]),
            ),
          )
        None => None
      }
    })

    // Structured try_table
    ops.push(fn() { gen_try_table_tinstr(ctx) })
  }

  // ------------------------------------------------------------
  // Pick an operation
  // ------------------------------------------------------------
  for _ in 0..<5 {
    let op = ops[ctx.random_int(ops.length())]
    match op() {
      Some(instr) => return instr
      None => ()
    }
  }

  TDrop(gen_tinstr_of_type(ctx, gen_valid_valtype(ctx)))
}

///|
fn gen_return_instrs(
  ctx : GenValidContext,
  returns : ResultType,
) -> Array[TInstr] {
  if returns.length() == 0 {
    return [TReturn([])]
  }
  let return_values : Array[TInstr] = []
  for vt in returns {
    return_values.push(gen_tinstr_of_type(ctx, vt))
  }
  [TReturn(return_values)]
}

///|
pub fn gen_valid_tfunc(
  ctx : GenValidContext,
  accepts : ResultType,
  returns : ResultType,
) -> Func {
    let old_locals = ctx.locals.copy()
    let old_labels = ctx.label_stack.copy()

    // RESET label stack and PUSH FUNCTION LABEL
    ctx.label_stack = []
    ctx.label_stack.push(Label::{ result : returns, catchable : true })

    ctx.locals = []

    // Add parameters as locals
    for vt in accepts {
      ctx.locals.push(vt)
    }

  // Add arbitrary locals
  let num_arbitrary_locals = ctx.random_int(5) + 1
  let all_local_types : Array[ValType] = []

  for _ in 0..<num_arbitrary_locals {
    let local_type = gen_valid_valtype(ctx)
    ctx.locals.push(local_type)
    all_local_types.push(local_type)
  }

  // Generate body
  let body_instrs : Array[TInstr] = []

  // Initialize non-parameter locals using gen_local_inits
  let local_inits = gen_local_inits(ctx, accepts.length())
  for instr in local_inits {
    body_instrs.push(instr)
  }

  // Generate side-effecting body statements with label_depth=0 initially
  let num_statements = ctx.random_int(8) + 2
  for _ in 0..<num_statements {
    body_instrs.push(gen_side_effect_tinstr(ctx, 0, label_depth=0))
  }

  // Generate return
  let return_instrs = gen_return_instrs(ctx, returns)
  for instr in return_instrs {
    body_instrs.push(instr)
  }

  ctx.locals = old_locals
  ctx.label_stack = old_labels

  Func::t_func(all_local_types, TExpr::new(body_instrs))
}

///|
/// Generate tags for exception handling
fn gen_tags(ctx : GenValidContext) -> Array[TagType] {
  let tags : Array[TagType] = []
  let num_tags = ctx.random_int(3) + 1
  for _ in 0..<num_tags {
    // Create a signature for the tag (tags use function types with no returns)
    let num_params = ctx.random_int(3)
    let params : Array[ValType] = []
    for _ in 0..<num_params {
      params.push(gen_valid_valtype(ctx))
    }
    let sig_idx = ctx.get_or_add_signature(params, [])
    ignore(ctx.add_tag(sig_idx, params))
    tags.push(TagType::new(TypeIdx::new(sig_idx.reinterpret_as_uint())))
  }
  tags
}

///|
pub fn gen_valid_module(rnd : RandomState) -> Module {
  let ctx = GenValidContext::new(rnd)

  // Always add memory (to increase MemIdxOOB coverage)
  ctx.ensure_memory()

  // Always add table (to increase TableIdxOOB coverage)
  ctx.ensure_table()

  // Add struct types
  let num_struct_types = ctx.random_int(3)
  for _ in 0..<num_struct_types {
    let num_fields = ctx.random_int(4) + 1
    let fields : Array[FieldType] = []
    for _ in 0..<num_fields {
      fields.push(gen_field_type(ctx))
    }
    ignore(ctx.add_struct_type(fields))
  }

  // Add array types
  let num_array_types = ctx.random_int(3)
  for _ in 0..<num_array_types {
    let elem_type = gen_field_type(ctx)
    ignore(ctx.add_array_type(elem_type))
  }

  // Add more mutable globals (to increase GlobalIdxOOB coverage)
  let num_globals = ctx.random_int(3) + 2 // At least 2 globals
  for _ in 0..<num_globals {
    let gt = GlobalType::new(gen_valid_valtype(ctx), true)
    ignore(ctx.add_global(gt))
  }

  // Generate tags for exception handling (to increase TagIdxOOB coverage)
  let tags = gen_tags(ctx)

  // Pre-declare function signatures and reserve indices
  let func_specs : Array[(Int, Int, ResultType, ResultType)] = [] // (func_idx, sig_idx, accepts, returns)

  // Main function signature (no params, no returns)
  let main_sig_idx = ctx.add_signature([], [])
  let main_func_idx = ctx.reserve_func(main_sig_idx)
  func_specs.push((main_func_idx, main_sig_idx, [], []))

  // Additional function signatures with variety
  let num_extra_funcs = ctx.random_int(4) + 1
  for _ in 0..<num_extra_funcs {
    let num_params = ctx.random_int(4)
    let num_returns = ctx.random_int(3)
    let params : Array[ValType] = []
    for _ in 0..<num_params {
      params.push(gen_valid_valtype(ctx))
    }
    let returns : Array[ValType] = []
    for _ in 0..<num_returns {
      returns.push(gen_valid_valtype(ctx))
    }
    let sig_idx = ctx.get_or_add_signature(params, returns)
    let func_idx = ctx.reserve_func(sig_idx)
    func_specs.push((func_idx, sig_idx, params, returns))
  }

  // Generate elem segments (needs func_idx to be set)
  let elem_segments = gen_elem_segments(ctx)

  // Generate data segments
  let data_segments = gen_data_segments(ctx)

  // Now generate the actual function bodies
  let generated_funcs : Array[(Func, Int)] = []
  for spec in func_specs {
    let (func_idx, _, accepts, returns) = spec
    let func = gen_valid_tfunc(ctx, accepts, returns)
    ctx.finalize_func(func_idx, func)
    generated_funcs.push((func, func_idx))
  }

  // Collect and sort types
  let type_entries : Array[(Int, RecType)] = []

  for t in ctx.struct_types {
    let (idx, fields) = t
    type_entries.push(
      (idx, RecType::new(SubType::comp_type(CompType::struct_(fields)))),
    )
  }

  for t in ctx.array_types {
    let (idx, elem_type) = t
    type_entries.push(
      (idx, RecType::new(SubType::comp_type(CompType::array(elem_type)))),
    )
  }

  for idx, sig in ctx.sigs {
    let (accepts, returns) = sig
    type_entries.push(
      (idx, RecType::new(SubType::comp_type(CompType::func(accepts, returns)))),
    )
  }

  type_entries.sort_by(fn(a, b) { a.0 - b.0 })
  let all_types = type_entries.map(fn(e) { e.1 })

  // Build type indices for func section
  let func_type_indices : Array[TypeIdx] = []
  for spec in func_specs {
    let (_, sig_idx, _, _) = spec
    func_type_indices.push(TypeIdx::new(sig_idx.reinterpret_as_uint()))
  }

  // Build global section
  let globals : Array[Global] = []
  for gt in ctx.globals {
    let GlobalType(vt, _) = gt
    let init_expr = gen_const_expr(ctx, vt)
    globals.push(Global::new(gt, init_expr))
  }

  // Sort functions by index
  generated_funcs.sort_by(fn(a, b) { a.1 - b.1 })

  // Build table with initializer (to increase TableInitMismatch coverage)
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(10, Some(100)),
  )
  // Add an initializer expression for the table
  let table_init = if ctx.func_idx > 0 && ctx.random_bool() {
    Some(
      Expr::new([
        Instruction::ref_func(FuncIdx::new(ctx.random_int(ctx.func_idx).reinterpret_as_uint())),
      ]),
    )
  } else {
    Some(Expr::new([Instruction::ref_null(HeapType::abs(AbsHeapType::func()))]))
  }

  // Build module
  let mut mod = Module::new()
    .with_type_sec(TypeSec::new(all_types))
    .with_func_sec(FuncSec::new(func_type_indices))
    .with_global_sec(GlobalSec::new(globals))
    .with_start_sec(StartSec::new(FuncIdx::new(main_func_idx.reinterpret_as_uint())))
    .with_code_sec(CodeSec::new(generated_funcs.map(fn(f) { f.0 })))
  
  // Always add memory
  mod = mod.with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, Some(10)))]))
  
  // Always add table with initializer
  mod = mod.with_table_sec(TableSec::new([Table::new(table_type, table_init)]))
  
  // Add tag section if we have tags
  if tags.length() > 0 {
    mod = mod.with_tag_sec(TagSec::new(tags))
  }
  
  if elem_segments.length() > 0 {
    mod = mod.with_elem_sec(ElemSec::new(elem_segments))
  }
  if data_segments.length() > 0 {
    mod = mod.with_data_sec(DataSec::new(data_segments))
    mod = mod.with_data_cnt_sec(
      DataCntSec::new(U32(data_segments.length().reinterpret_as_uint())),
    )
  }
  mod
}
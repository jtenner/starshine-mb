///| Compiler facts are advisory metadata. They never change core WebAssembly

///| validation or execution semantics unless an optimizer invocation explicitly

///|
/// chooses to trust semantic assertions after structural validation.
pub struct CompilerFactCustomSection {
  version : UInt
  module_fingerprint : Bytes?
  facts : OptimizationFactsSec
} derive(Eq, Hash, Debug)

///|
pub fn CompilerFactCustomSection::new(
  facts : OptimizationFactsSec,
  version? : UInt = 1U,
  module_fingerprint? : Bytes? = None,
) -> CompilerFactCustomSection {
  { version, module_fingerprint, facts, }
}

///|
pub struct ProducerInfo {
  name : String
  version : String
  build_id : String?
} derive(Eq, Hash, Debug)

///|
pub fn ProducerInfo::new(
  name : String,
  version : String,
  build_id? : String? = None,
) -> ProducerInfo {
  { name, version, build_id, }
}

///|
pub enum WorldMode {
  OpenWorld
  ClosedModule
  ClosedProgram
} derive(Eq, Hash, Debug)

///|
pub fn WorldMode::open_world() -> WorldMode {
  OpenWorld
}

///|
pub fn WorldMode::closed_module() -> WorldMode {
  ClosedModule
}

///|
pub fn WorldMode::closed_program() -> WorldMode {
  ClosedProgram
}

///|
pub struct WorldFacts {
  mode : WorldMode
  host_can_call_exports : Bool
  host_can_mutate_exported_state : Bool
} derive(Eq, Hash, Debug)

///|
pub fn WorldFacts::new(
  mode : WorldMode,
  host_can_call_exports : Bool,
  host_can_mutate_exported_state : Bool,
) -> WorldFacts {
  { mode, host_can_call_exports, host_can_mutate_exported_state, }
}

///|
pub fn WorldFacts::open_world(
  host_can_call_exports? : Bool = true,
  host_can_mutate_exported_state? : Bool = true,
) -> WorldFacts {
  WorldFacts::new(
    WorldMode::open_world(),
    host_can_call_exports,
    host_can_mutate_exported_state,
  )
}

///|
pub fn WorldFacts::closed_module(
  host_can_call_exports? : Bool = true,
  host_can_mutate_exported_state? : Bool = true,
) -> WorldFacts {
  WorldFacts::new(
    WorldMode::closed_module(),
    host_can_call_exports,
    host_can_mutate_exported_state,
  )
}

///|
pub fn WorldFacts::closed_program(
  host_can_call_exports? : Bool = true,
  host_can_mutate_exported_state? : Bool = false,
) -> WorldFacts {
  WorldFacts::new(
    WorldMode::closed_program(),
    host_can_call_exports,
    host_can_mutate_exported_state,
  )
}

///|
pub struct OptimizationFactsSec {
  producer : ProducerInfo?
  world : WorldFacts?
  functions : Array[FunctionFacts]
  signatures : Array[SignatureFacts]
  types : Array[TypeFacts]
  globals : Array[GlobalFacts]
  tables : Array[TableFacts]
  bodies : Array[FunctionBodyFacts]
  hints : Array[OptimizationHint]
} derive(Eq, Hash, Debug)

///|
pub fn OptimizationFactsSec::new(
  producer? : ProducerInfo? = None,
  world? : WorldFacts? = None,
  functions? : Array[FunctionFacts] = [],
  signatures? : Array[SignatureFacts] = [],
  types? : Array[TypeFacts] = [],
  globals? : Array[GlobalFacts] = [],
  tables? : Array[TableFacts] = [],
  bodies? : Array[FunctionBodyFacts] = [],
  hints? : Array[OptimizationHint] = [],
) -> OptimizationFactsSec {
  {
    producer,
    world,
    functions,
    signatures,
    types,
    globals,
    tables,
    bodies,
    hints,
  }
}

///|
pub struct OptimizationFactsBuilder {
  mut producer : ProducerInfo?
  mut world : WorldFacts?
  functions : Array[FunctionFacts]
  signatures : Array[SignatureFacts]
  types : Array[TypeFacts]
  globals : Array[GlobalFacts]
  tables : Array[TableFacts]
  bodies : Array[FunctionBodyFacts]
  hints : Array[OptimizationHint]
} derive(Eq, Hash, Debug)

///|
pub fn OptimizationFactsBuilder::new() -> OptimizationFactsBuilder {
  {
    producer: None,
    world: None,
    functions: [],
    signatures: [],
    types: [],
    globals: [],
    tables: [],
    bodies: [],
    hints: [],
  }
}

///|
pub fn OptimizationFactsBuilder::set_producer(
  self : OptimizationFactsBuilder,
  producer : ProducerInfo,
) -> Unit {
  self.producer = Some(producer)
}

///|
pub fn OptimizationFactsBuilder::set_world(
  self : OptimizationFactsBuilder,
  world : WorldFacts,
) -> Unit {
  self.world = Some(world)
}

///|
pub fn OptimizationFactsBuilder::add_function(
  self : OptimizationFactsBuilder,
  facts : FunctionFacts,
) -> Unit {
  self.functions.push(facts)
}

///|
pub fn OptimizationFactsBuilder::add_signature(
  self : OptimizationFactsBuilder,
  facts : SignatureFacts,
) -> Unit {
  self.signatures.push(facts)
}

///|
pub fn OptimizationFactsBuilder::add_type(
  self : OptimizationFactsBuilder,
  facts : TypeFacts,
) -> Unit {
  self.types.push(facts)
}

///|
pub fn OptimizationFactsBuilder::add_global(
  self : OptimizationFactsBuilder,
  facts : GlobalFacts,
) -> Unit {
  self.globals.push(facts)
}

///|
pub fn OptimizationFactsBuilder::add_table(
  self : OptimizationFactsBuilder,
  facts : TableFacts,
) -> Unit {
  self.tables.push(facts)
}

///|
pub fn OptimizationFactsBuilder::add_body(
  self : OptimizationFactsBuilder,
  facts : FunctionBodyFacts,
) -> Unit {
  self.bodies.push(facts)
}

///|
pub fn OptimizationFactsBuilder::add_hint(
  self : OptimizationFactsBuilder,
  hint : OptimizationHint,
) -> Unit {
  self.hints.push(hint)
}

///|
pub fn OptimizationFactsBuilder::finish(
  self : OptimizationFactsBuilder,
) -> OptimizationFactsSec {
  OptimizationFactsSec::new(
    producer=self.producer,
    world=self.world,
    functions=self.functions.copy(),
    signatures=self.signatures.copy(),
    types=self.types.copy(),
    globals=self.globals.copy(),
    tables=self.tables.copy(),
    bodies=self.bodies.copy(),
    hints=self.hints.copy(),
  )
}

///|
pub struct CodeSite {
  function : UInt
  offset : UInt
} derive(Eq, Hash, Debug)

///|
pub fn CodeSite::new(function : UInt, offset : UInt) -> CodeSite {
  { function, offset, }
}

///|
pub struct ValueSite {
  site : CodeSite
  result : UInt
} derive(Eq, Hash, Debug)

///|
pub fn ValueSite::new(site : CodeSite, result? : UInt = 0U) -> ValueSite {
  { site, result, }
}

///|
pub struct SourceProvenance {
  module_id : UInt64?
  declaration_id : UInt64?
  body_id : UInt64?
  expression_id : UInt64?
  source_offset : UInt64?
  specialization_id : UInt64?
} derive(Eq, Hash, Debug)

///|
pub fn SourceProvenance::new(
  module_id? : UInt64? = None,
  declaration_id? : UInt64? = None,
  body_id? : UInt64? = None,
  expression_id? : UInt64? = None,
  source_offset? : UInt64? = None,
  specialization_id? : UInt64? = None,
) -> SourceProvenance {
  {
    module_id,
    declaration_id,
    body_id,
    expression_id,
    source_offset,
    specialization_id,
  }
}

///|
pub enum IntWidth {
  Int8
  Int16
  Int32
  Int64
} derive(Eq, Hash, Debug)

///|
pub fn IntWidth::i8() -> IntWidth {
  Int8
}

///|
pub fn IntWidth::i16() -> IntWidth {
  Int16
}

///|
pub fn IntWidth::i32() -> IntWidth {
  Int32
}

///|
pub fn IntWidth::i64() -> IntWidth {
  Int64
}

///|
pub fn IntWidth::bit_count(self : IntWidth) -> UInt {
  match self {
    Int8 => 8U
    Int16 => 16U
    Int32 => 32U
    Int64 => 64U
  }
}

///|
pub struct IntConstant {
  width : IntWidth
  bits : UInt64
} derive(Eq, Hash, Debug)

///|
pub fn IntConstant::new(width : IntWidth, bits : UInt64) -> IntConstant {
  { width, bits, }
}

///|
pub struct V128Bits {
  low : UInt64
  high : UInt64
} derive(Eq, Hash, Debug)

///|
pub fn V128Bits::new(low : UInt64, high : UInt64) -> V128Bits {
  { low, high, }
}

///|
pub enum FactHeapType {
  TypeIndex(UInt)
  Any
  Eq
  Struct
  Array
  I31
  Func
  Extern
  Exn
  Cont
  String
  None
  NoFunc
  NoExtern
  NoExn
  NoCont
} derive(Eq, Hash, Debug)

///|
pub fn FactHeapType::type_index(index : UInt) -> FactHeapType {
  TypeIndex(index)
}

///|
pub fn FactHeapType::any() -> FactHeapType {
  Any
}

///|
pub fn FactHeapType::eq() -> FactHeapType {
  Eq
}

///|
pub fn FactHeapType::struct_() -> FactHeapType {
  Struct
}

///|
pub fn FactHeapType::array() -> FactHeapType {
  Array
}

///|
pub fn FactHeapType::i31() -> FactHeapType {
  I31
}

///|
pub fn FactHeapType::func() -> FactHeapType {
  Func
}

///|
pub fn FactHeapType::extern_() -> FactHeapType {
  Extern
}

///|
pub fn FactHeapType::exn() -> FactHeapType {
  Exn
}

///|
pub fn FactHeapType::cont() -> FactHeapType {
  Cont
}

///|
pub fn FactHeapType::string() -> FactHeapType {
  String
}

///|
pub fn FactHeapType::none() -> FactHeapType {
  None
}

///|
pub fn FactHeapType::no_func() -> FactHeapType {
  NoFunc
}

///|
pub fn FactHeapType::no_extern() -> FactHeapType {
  NoExtern
}

///|
pub fn FactHeapType::no_exn() -> FactHeapType {
  NoExn
}

///|
pub fn FactHeapType::no_cont() -> FactHeapType {
  NoCont
}

///|
fn fact_heap_type_rank(value : FactHeapType) -> UInt {
  match value {
    TypeIndex(_) => 0U
    Any => 1U
    Eq => 2U
    Struct => 3U
    Array => 4U
    I31 => 5U
    Func => 6U
    Extern => 7U
    Exn => 8U
    Cont => 9U
    String => 10U
    None => 11U
    NoFunc => 12U
    NoExtern => 13U
    NoExn => 14U
    NoCont => 15U
  }
}

///|
fn fact_heap_type_less(left : FactHeapType, right : FactHeapType) -> Bool {
  let lr = fact_heap_type_rank(left)
  let rr = fact_heap_type_rank(right)
  if lr != rr {
    return lr < rr
  }
  match (left, right) {
    (TypeIndex(a), TypeIndex(b)) => a < b
    _ => false
  }
}

///|
fn normalize_heap_types(values : Array[FactHeapType]) -> Array[FactHeapType] {
  let out : Array[FactHeapType] = []
  for value in values {
    let mut inserted = false
    for i = 0; i < out.length(); i = i + 1 {
      if value == out[i] {
        inserted = true
        break
      }
      if fact_heap_type_less(value, out[i]) {
        out.insert(i, value)
        inserted = true
        break
      }
    }
    if !inserted {
      out.push(value)
    }
  }
  out
}

///|
pub enum FactValue {
  IntegerValue(IntConstant)
  F32Bits(UInt)
  F64Bits(UInt64)
  V128Value(V128Bits)
  RefNullValue(FactHeapType)
  RefFuncValue(UInt)
  ImmutableGlobalValue(UInt)
} derive(Eq, Hash, Debug)

///|
pub fn FactValue::integer(value : IntConstant) -> FactValue {
  IntegerValue(value)
}

///|
pub fn FactValue::f32_bits(bits : UInt) -> FactValue {
  F32Bits(bits)
}

///|
pub fn FactValue::f64_bits(bits : UInt64) -> FactValue {
  F64Bits(bits)
}

///|
pub fn FactValue::v128(value : V128Bits) -> FactValue {
  V128Value(value)
}

///|
pub fn FactValue::ref_null(heap : FactHeapType) -> FactValue {
  RefNullValue(heap)
}

///|
pub fn FactValue::ref_func(function : UInt) -> FactValue {
  RefFuncValue(function)
}

///|
pub fn FactValue::immutable_global(global : UInt) -> FactValue {
  ImmutableGlobalValue(global)
}

///|
fn int_width_rank(width : IntWidth) -> UInt {
  match width {
    Int8 => 0U
    Int16 => 1U
    Int32 => 2U
    Int64 => 3U
  }
}

///|
fn fact_value_rank(value : FactValue) -> UInt {
  match value {
    IntegerValue(_) => 0U
    F32Bits(_) => 1U
    F64Bits(_) => 2U
    V128Value(_) => 3U
    RefNullValue(_) => 4U
    RefFuncValue(_) => 5U
    ImmutableGlobalValue(_) => 6U
  }
}

///|
fn fact_value_less(left : FactValue, right : FactValue) -> Bool {
  let lr = fact_value_rank(left)
  let rr = fact_value_rank(right)
  if lr != rr {
    return lr < rr
  }
  match (left, right) {
    (IntegerValue(a), IntegerValue(b)) => {
      let aw = int_width_rank(a.width)
      let bw = int_width_rank(b.width)
      aw < bw || (aw == bw && a.bits < b.bits)
    }
    (F32Bits(a), F32Bits(b)) => a < b
    (F64Bits(a), F64Bits(b)) => a < b
    (V128Value(a), V128Value(b)) =>
      a.high < b.high || (a.high == b.high && a.low < b.low)
    (RefNullValue(a), RefNullValue(b)) => fact_heap_type_less(a, b)
    (RefFuncValue(a), RefFuncValue(b)) => a < b
    (ImmutableGlobalValue(a), ImmutableGlobalValue(b)) => a < b
    _ => false
  }
}

///|
fn normalize_fact_values(values : Array[FactValue]) -> Array[FactValue] {
  let out : Array[FactValue] = []
  for value in values {
    let mut inserted = false
    for i = 0; i < out.length(); i = i + 1 {
      if value == out[i] {
        inserted = true
        break
      }
      if fact_value_less(value, out[i]) {
        out.insert(i, value)
        inserted = true
        break
      }
    }
    if !inserted {
      out.push(value)
    }
  }
  out
}

///|
/// `Some(empty)` means impossible; `None` means unknown.
pub struct ClosedValueSet(Array[FactValue]) derive(Eq, Hash, Debug)

///|
pub fn ClosedValueSet::new(values : Array[FactValue]) -> ClosedValueSet {
  ClosedValueSet(normalize_fact_values(values))
}

///|
pub struct SignedRange {
  min : Int64
  max : Int64
} derive(Eq, Hash, Debug)

///|
pub fn SignedRange::new(min : Int64, max : Int64) -> SignedRange {
  { min, max, }
}

///|
pub struct UnsignedRange {
  min : UInt64
  max : UInt64
} derive(Eq, Hash, Debug)

///|
pub fn UnsignedRange::new(min : UInt64, max : UInt64) -> UnsignedRange {
  { min, max, }
}

///|
pub struct KnownBits {
  known_zero : UInt64
  known_one : UInt64
} derive(Eq, Hash, Debug)

///|
pub fn KnownBits::new(known_zero : UInt64, known_one : UInt64) -> KnownBits {
  { known_zero, known_one, }
}

///|
pub struct IntegerFacts {
  width : IntWidth
  unsigned_range : UnsignedRange?
  signed_range : SignedRange?
  known_bits : KnownBits?
  nonzero : Bool
} derive(Eq, Hash, Debug)

///|
pub fn IntegerFacts::new(
  width : IntWidth,
  unsigned_range? : UnsignedRange? = None,
  signed_range? : SignedRange? = None,
  known_bits? : KnownBits? = None,
  nonzero? : Bool = false,
) -> IntegerFacts {
  { width, unsigned_range, signed_range, known_bits, nonzero, }
}

///|
pub enum FloatWidth {
  Float32
  Float64
} derive(Eq, Hash, Debug)

///|
pub fn FloatWidth::f32() -> FloatWidth {
  Float32
}

///|
pub fn FloatWidth::f64() -> FloatWidth {
  Float64
}

///|
pub struct FloatClassMask(UInt) derive(Eq, Hash, Debug)

///|
pub fn FloatClassMask::from_bits(bits : UInt) -> FloatClassMask {
  FloatClassMask(bits)
}

///|
pub fn FloatClassMask::bits(self : FloatClassMask) -> UInt {
  self.0
}

///|
pub fn FloatClassMask::empty() -> FloatClassMask {
  FloatClassMask(0U)
}

///|
pub fn FloatClassMask::positive_zero() -> FloatClassMask {
  FloatClassMask(1U << 0)
}

///|
pub fn FloatClassMask::negative_zero() -> FloatClassMask {
  FloatClassMask(1U << 1)
}

///|
pub fn FloatClassMask::positive_normal() -> FloatClassMask {
  FloatClassMask(1U << 2)
}

///|
pub fn FloatClassMask::negative_normal() -> FloatClassMask {
  FloatClassMask(1U << 3)
}

///|
pub fn FloatClassMask::positive_subnormal() -> FloatClassMask {
  FloatClassMask(1U << 4)
}

///|
pub fn FloatClassMask::negative_subnormal() -> FloatClassMask {
  FloatClassMask(1U << 5)
}

///|
pub fn FloatClassMask::positive_infinity() -> FloatClassMask {
  FloatClassMask(1U << 6)
}

///|
pub fn FloatClassMask::negative_infinity() -> FloatClassMask {
  FloatClassMask(1U << 7)
}

///|
pub fn FloatClassMask::nan() -> FloatClassMask {
  FloatClassMask(1U << 8)
}

///|
pub fn FloatClassMask::all() -> FloatClassMask {
  FloatClassMask(0x1FFU)
}

///|
pub fn FloatClassMask::contains(
  self : FloatClassMask,
  other : FloatClassMask,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub fn FloatClassMask::union(
  self : FloatClassMask,
  other : FloatClassMask,
) -> FloatClassMask {
  FloatClassMask(self.0 | other.0)
}

///|
pub struct FloatFacts {
  width : FloatWidth
  possible_classes : FloatClassMask
} derive(Eq, Hash, Debug)

///|
pub fn FloatFacts::new(
  width : FloatWidth,
  possible_classes : FloatClassMask,
) -> FloatFacts {
  { width, possible_classes, }
}

///|
pub enum NullabilityFacts {
  NullOnly
  NonNull
} derive(Eq, Hash, Debug)

///|
pub fn NullabilityFacts::null_only() -> NullabilityFacts {
  NullOnly
}

///|
pub fn NullabilityFacts::non_null() -> NullabilityFacts {
  NonNull
}

///|
pub struct ClosedHeapTypeSet(Array[FactHeapType]) derive(Eq, Hash, Debug)

///|
pub fn ClosedHeapTypeSet::new(
  values : Array[FactHeapType],
) -> ClosedHeapTypeSet {
  ClosedHeapTypeSet(normalize_heap_types(values))
}

///|
pub enum HeapDomain {
  ExactRuntimeType(FactHeapType)
  SubtypesOf(FactHeapType)
  ClosedRuntimeTypes(ClosedHeapTypeSet)
} derive(Eq, Hash, Debug)

///|
pub fn HeapDomain::exact_runtime_type(type_ : FactHeapType) -> HeapDomain {
  ExactRuntimeType(type_)
}

///|
pub fn HeapDomain::subtypes_of(type_ : FactHeapType) -> HeapDomain {
  SubtypesOf(type_)
}

///|
pub fn HeapDomain::closed_runtime_types(
  types : ClosedHeapTypeSet,
) -> HeapDomain {
  ClosedRuntimeTypes(types)
}

///|
pub struct ReferenceFacts {
  nullability : NullabilityFacts?
  heap : HeapDomain?
  function_targets : ClosedFunctionSet?
} derive(Eq, Hash, Debug)

///|
pub fn ReferenceFacts::new(
  nullability? : NullabilityFacts? = None,
  heap? : HeapDomain? = None,
  function_targets? : ClosedFunctionSet? = None,
) -> ReferenceFacts {
  { nullability, heap, function_targets, }
}

///|
pub enum VectorLaneShape {
  I8x16
  I16x8
  I32x4
  I64x2
  F32x4
  F64x2
} derive(Eq, Hash, Debug)

///|
pub fn VectorLaneShape::i8x16() -> VectorLaneShape {
  I8x16
}

///|
pub fn VectorLaneShape::i16x8() -> VectorLaneShape {
  I16x8
}

///|
pub fn VectorLaneShape::i32x4() -> VectorLaneShape {
  I32x4
}

///|
pub fn VectorLaneShape::i64x2() -> VectorLaneShape {
  I64x2
}

///|
pub fn VectorLaneShape::f32x4() -> VectorLaneShape {
  F32x4
}

///|
pub fn VectorLaneShape::f64x2() -> VectorLaneShape {
  F64x2
}

///|
pub struct KnownV128Bits {
  known_zero : V128Bits
  known_one : V128Bits
} derive(Eq, Hash, Debug)

///|
pub fn KnownV128Bits::new(
  known_zero : V128Bits,
  known_one : V128Bits,
) -> KnownV128Bits {
  { known_zero, known_one, }
}

///|
pub struct VectorFacts {
  known_bits : KnownV128Bits?
  splat : FactValue?
  lane_shape : VectorLaneShape?
} derive(Eq, Hash, Debug)

///|
pub fn VectorFacts::new(
  known_bits? : KnownV128Bits? = None,
  splat? : FactValue? = None,
  lane_shape? : VectorLaneShape? = None,
) -> VectorFacts {
  { known_bits, splat, lane_shape, }
}

///|
pub struct ValueFacts {
  possible_values : ClosedValueSet?
  integer : IntegerFacts?
  float_ : FloatFacts?
  vector : VectorFacts?
  reference : ReferenceFacts?
} derive(Eq, Hash, Debug)

///|
pub fn ValueFacts::new(
  possible_values? : ClosedValueSet? = None,
  integer? : IntegerFacts? = None,
  float_? : FloatFacts? = None,
  vector? : VectorFacts? = None,
  reference? : ReferenceFacts? = None,
) -> ValueFacts {
  { possible_values, integer, float_, vector, reference, }
}

///|
pub fn ValueFacts::unknown() -> ValueFacts {
  ValueFacts::new()
}

///|
pub fn ValueFacts::impossible() -> ValueFacts {
  ValueFacts::new(possible_values=Some(ClosedValueSet::new([])))
}

///|
pub fn ValueFacts::exact_value(value : FactValue) -> ValueFacts {
  ValueFacts::new(possible_values=Some(ClosedValueSet::new([value])))
}

///|
pub fn ValueFacts::unsigned_range(
  min : UInt64,
  max : UInt64,
  width? : IntWidth = IntWidth::i64(),
) -> ValueFacts {
  ValueFacts::new(
    integer=Some(
      IntegerFacts::new(
        width,
        unsigned_range=Some(UnsignedRange::new(min, max)),
      ),
    ),
  )
}

///|
pub fn ValueFacts::signed_range(
  min : Int64,
  max : Int64,
  width? : IntWidth = IntWidth::i64(),
) -> ValueFacts {
  ValueFacts::new(
    integer=Some(
      IntegerFacts::new(width, signed_range=Some(SignedRange::new(min, max))),
    ),
  )
}

///|
pub fn ValueFacts::nonnull() -> ValueFacts {
  ValueFacts::new(
    reference=Some(
      ReferenceFacts::new(nullability=Some(NullabilityFacts::non_null())),
    ),
  )
}

///|
pub fn ValueFacts::nonnull_exact_ref(heap : FactHeapType) -> ValueFacts {
  ValueFacts::new(
    reference=Some(
      ReferenceFacts::new(
        nullability=Some(NullabilityFacts::non_null()),
        heap=Some(HeapDomain::exact_runtime_type(heap)),
      ),
    ),
  )
}

///|
pub fn ValueFacts::exact_ref_func(function : UInt) -> ValueFacts {
  ValueFacts::new(
    possible_values=Some(ClosedValueSet::new([FactValue::ref_func(function)])),
    reference=Some(
      ReferenceFacts::new(
        nullability=Some(NullabilityFacts::non_null()),
        heap=Some(HeapDomain::exact_runtime_type(FactHeapType::func())),
        function_targets=Some(ClosedFunctionSet::new([function])),
      ),
    ),
  )
}

///|
pub struct ParameterRef {
  function : UInt
  parameter : UInt
} derive(Eq, Hash, Debug)

///|
pub fn ParameterRef::new(function : UInt, parameter : UInt) -> ParameterRef {
  { function, parameter, }
}

///|
pub struct FunctionResultRef {
  function : UInt
  result : UInt
} derive(Eq, Hash, Debug)

///|
pub fn FunctionResultRef::new(
  function : UInt,
  result : UInt,
) -> FunctionResultRef {
  { function, result, }
}

///|
pub enum ValueRef {
  SiteValue(ValueSite)
  ParameterValue(ParameterRef)
  FunctionResultValue(FunctionResultRef)
  GlobalValue(UInt)
} derive(Eq, Hash, Debug)

///|
pub fn ValueRef::site(site : ValueSite) -> ValueRef {
  SiteValue(site)
}

///|
pub fn ValueRef::parameter(parameter : ParameterRef) -> ValueRef {
  ParameterValue(parameter)
}

///|
pub fn ValueRef::function_result(result : FunctionResultRef) -> ValueRef {
  FunctionResultValue(result)
}

///|
pub fn ValueRef::global(global : UInt) -> ValueRef {
  GlobalValue(global)
}

///|
pub enum AliasSource {
  ParameterAlias(UInt)
  GlobalAlias(UInt)
  SiteAlias(ValueSite)
} derive(Eq, Hash, Debug)

///|
pub fn AliasSource::parameter(parameter : UInt) -> AliasSource {
  ParameterAlias(parameter)
}

///|
pub fn AliasSource::global(global : UInt) -> AliasSource {
  GlobalAlias(global)
}

///|
pub fn AliasSource::site(site : ValueSite) -> AliasSource {
  SiteAlias(site)
}

///|
fn alias_source_rank(value : AliasSource) -> UInt {
  match value {
    ParameterAlias(_) => 0U
    GlobalAlias(_) => 1U
    SiteAlias(_) => 2U
  }
}

///|
fn alias_source_less(left : AliasSource, right : AliasSource) -> Bool {
  let lr = alias_source_rank(left)
  let rr = alias_source_rank(right)
  if lr != rr {
    return lr < rr
  }
  match (left, right) {
    (ParameterAlias(a), ParameterAlias(b)) | (GlobalAlias(a), GlobalAlias(b)) =>
      a < b
    (SiteAlias(a), SiteAlias(b)) =>
      a.site.function < b.site.function ||
      (
        a.site.function == b.site.function &&
        (
          a.site.offset < b.site.offset ||
          (a.site.offset == b.site.offset && a.result < b.result)
        )
      )
    _ => false
  }
}

///|
pub struct ClosedAliasSet(Array[AliasSource]) derive(Eq, Hash, Debug)

///|
pub fn ClosedAliasSet::new(values : Array[AliasSource]) -> ClosedAliasSet {
  let out : Array[AliasSource] = []
  for value in values {
    let mut inserted = false
    for i = 0; i < out.length(); i = i + 1 {
      if value == out[i] {
        inserted = true
        break
      }
      if alias_source_less(value, out[i]) {
        out.insert(i, value)
        inserted = true
        break
      }
    }
    if !inserted {
      out.push(value)
    }
  }
  ClosedAliasSet(out)
}

///|
pub enum ResultIdentityFacts {
  FreshReference
  ClosedAliases(ClosedAliasSet)
} derive(Eq, Hash, Debug)

///|
pub fn ResultIdentityFacts::fresh() -> ResultIdentityFacts {
  FreshReference
}

///|
pub fn ResultIdentityFacts::same_as_parameter(
  parameter : UInt,
) -> ResultIdentityFacts {
  ClosedAliases(ClosedAliasSet::new([AliasSource::parameter(parameter)]))
}

///|
pub fn ResultIdentityFacts::same_as_global(
  global : UInt,
) -> ResultIdentityFacts {
  ClosedAliases(ClosedAliasSet::new([AliasSource::global(global)]))
}

///|
pub fn ResultIdentityFacts::closed_aliases(
  aliases : ClosedAliasSet,
) -> ResultIdentityFacts {
  ClosedAliases(aliases)
}

///|
pub struct ParameterFacts {
  parameter : UInt
  value : ValueFacts?
  uses : ParameterUseMask?
  escape_sinks : EscapeSinkMask?
} derive(Eq, Hash, Debug)

///|
pub fn ParameterFacts::new(
  parameter : UInt,
  value? : ValueFacts? = None,
  uses? : ParameterUseMask? = None,
  escape_sinks? : EscapeSinkMask? = None,
) -> ParameterFacts {
  { parameter, value, uses, escape_sinks, }
}

///|
pub struct ResultFacts {
  result : UInt
  value : ValueFacts?
  identity : ResultIdentityFacts?
} derive(Eq, Hash, Debug)

///|
pub fn ResultFacts::new(
  result : UInt,
  value? : ValueFacts? = None,
  identity? : ResultIdentityFacts? = None,
) -> ResultFacts {
  { result, value, identity, }
}

///|
pub struct ParameterUseMask(UInt64) derive(Eq, Hash, Debug)

///|
pub fn ParameterUseMask::from_bits(bits : UInt64) -> ParameterUseMask {
  ParameterUseMask(bits)
}

///|
pub fn ParameterUseMask::bits(self : ParameterUseMask) -> UInt64 {
  self.0
}

///|
pub fn ParameterUseMask::empty() -> ParameterUseMask {
  ParameterUseMask(0UL)
}

///|
pub fn ParameterUseMask::direct_computation() -> ParameterUseMask {
  ParameterUseMask(1UL << 0)
}

///|
pub fn ParameterUseMask::control() -> ParameterUseMask {
  ParameterUseMask(1UL << 1)
}

///|
pub fn ParameterUseMask::address_index() -> ParameterUseMask {
  ParameterUseMask(1UL << 2)
}

///|
pub fn ParameterUseMask::call_argument() -> ParameterUseMask {
  ParameterUseMask(1UL << 3)
}

///|
pub fn ParameterUseMask::stored_value() -> ParameterUseMask {
  ParameterUseMask(1UL << 4)
}

///|
pub fn ParameterUseMask::return_() -> ParameterUseMask {
  ParameterUseMask(1UL << 5)
}

///|
pub fn ParameterUseMask::identity_observing() -> ParameterUseMask {
  ParameterUseMask(1UL << 6)
}

///|
pub fn ParameterUseMask::all_known() -> ParameterUseMask {
  ParameterUseMask(0x7FUL)
}

///|
pub fn ParameterUseMask::contains(
  self : ParameterUseMask,
  other : ParameterUseMask,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub fn ParameterUseMask::union(
  self : ParameterUseMask,
  other : ParameterUseMask,
) -> ParameterUseMask {
  ParameterUseMask(self.0 | other.0)
}

///|
pub struct EscapeSinkMask(UInt64) derive(Eq, Hash, Debug)

///|
pub fn EscapeSinkMask::from_bits(bits : UInt64) -> EscapeSinkMask {
  EscapeSinkMask(bits)
}

///|
pub fn EscapeSinkMask::bits(self : EscapeSinkMask) -> UInt64 {
  self.0
}

///|
pub fn EscapeSinkMask::empty() -> EscapeSinkMask {
  EscapeSinkMask(0UL)
}

///|
pub fn EscapeSinkMask::return_() -> EscapeSinkMask {
  EscapeSinkMask(1UL << 0)
}

///|
pub fn EscapeSinkMask::call() -> EscapeSinkMask {
  EscapeSinkMask(1UL << 1)
}

///|
pub fn EscapeSinkMask::global() -> EscapeSinkMask {
  EscapeSinkMask(1UL << 2)
}

///|
pub fn EscapeSinkMask::memory() -> EscapeSinkMask {
  EscapeSinkMask(1UL << 3)
}

///|
pub fn EscapeSinkMask::table() -> EscapeSinkMask {
  EscapeSinkMask(1UL << 4)
}

///|
pub fn EscapeSinkMask::heap() -> EscapeSinkMask {
  EscapeSinkMask(1UL << 5)
}

///|
pub fn EscapeSinkMask::throw_() -> EscapeSinkMask {
  EscapeSinkMask(1UL << 6)
}

///|
pub fn EscapeSinkMask::host_unknown() -> EscapeSinkMask {
  EscapeSinkMask(1UL << 7)
}

///|
pub fn EscapeSinkMask::all_known() -> EscapeSinkMask {
  EscapeSinkMask(0xFFUL)
}

///|
pub fn EscapeSinkMask::contains(
  self : EscapeSinkMask,
  other : EscapeSinkMask,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub fn EscapeSinkMask::union(
  self : EscapeSinkMask,
  other : EscapeSinkMask,
) -> EscapeSinkMask {
  EscapeSinkMask(self.0 | other.0)
}

///| Effect bits are broad upper bounds. Optional resource sets are complete only

///|
/// when present; an absent set means unknown, never empty.
pub struct EffectMask(UInt64) derive(Eq, Hash, Debug)

///|
pub fn EffectMask::from_bits(bits : UInt64) -> EffectMask {
  EffectMask(bits)
}

///|
pub fn EffectMask::bits(self : EffectMask) -> UInt64 {
  self.0
}

///|
pub fn EffectMask::empty() -> EffectMask {
  EffectMask(0UL)
}

///|
pub fn EffectMask::may_trap() -> EffectMask {
  EffectMask(1UL << 0)
}

///|
pub fn EffectMask::may_throw() -> EffectMask {
  EffectMask(1UL << 1)
}

///|
pub fn EffectMask::may_diverge() -> EffectMask {
  EffectMask(1UL << 2)
}

///|
pub fn EffectMask::may_call_unknown_code() -> EffectMask {
  EffectMask(1UL << 3)
}

///|
pub fn EffectMask::may_call_host_code() -> EffectMask {
  EffectMask(1UL << 4)
}

///|
pub fn EffectMask::may_reenter() -> EffectMask {
  EffectMask(1UL << 5)
}

///|
pub fn EffectMask::may_suspend() -> EffectMask {
  EffectMask(1UL << 6)
}

///|
pub fn EffectMask::may_allocate_gc() -> EffectMask {
  EffectMask(1UL << 7)
}

///|
pub fn EffectMask::may_observe_reference_identity() -> EffectMask {
  EffectMask(1UL << 8)
}

///|
pub fn EffectMask::may_produce_nondeterministic_results() -> EffectMask {
  EffectMask(1UL << 9)
}

///|
pub fn EffectMask::may_read_global() -> EffectMask {
  EffectMask(1UL << 10)
}

///|
pub fn EffectMask::may_write_global() -> EffectMask {
  EffectMask(1UL << 11)
}

///|
pub fn EffectMask::may_read_memory() -> EffectMask {
  EffectMask(1UL << 12)
}

///|
pub fn EffectMask::may_write_memory() -> EffectMask {
  EffectMask(1UL << 13)
}

///|
pub fn EffectMask::may_grow_memory() -> EffectMask {
  EffectMask(1UL << 14)
}

///|
pub fn EffectMask::may_read_table() -> EffectMask {
  EffectMask(1UL << 15)
}

///|
pub fn EffectMask::may_write_table() -> EffectMask {
  EffectMask(1UL << 16)
}

///|
pub fn EffectMask::may_grow_table() -> EffectMask {
  EffectMask(1UL << 17)
}

///|
pub fn EffectMask::may_read_gc_heap() -> EffectMask {
  EffectMask(1UL << 18)
}

///|
pub fn EffectMask::may_write_gc_heap() -> EffectMask {
  EffectMask(1UL << 19)
}

///|
pub fn EffectMask::may_synchronize() -> EffectMask {
  EffectMask(1UL << 20)
}

///|
pub fn EffectMask::may_wait_or_notify() -> EffectMask {
  EffectMask(1UL << 21)
}

///|
pub fn EffectMask::local_state() -> EffectMask {
  EffectMask(1UL << 22)
}

///|
pub fn EffectMask::contains(self : EffectMask, other : EffectMask) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub fn EffectMask::union(self : EffectMask, other : EffectMask) -> EffectMask {
  EffectMask(self.0 | other.0)
}

///|
/// Compatibility conveniences for the pre-freeze API.
pub fn EffectMask::trap() -> EffectMask {
  EffectMask::may_trap()
}

///|
pub fn EffectMask::throw_() -> EffectMask {
  EffectMask::may_throw()
}

///|
pub fn EffectMask::call() -> EffectMask {
  EffectMask::may_call_unknown_code()
}

///|
pub fn EffectMask::allocation() -> EffectMask {
  EffectMask::may_allocate_gc()
}

///|
pub fn EffectMask::memory_read() -> EffectMask {
  EffectMask::may_read_memory()
}

///|
pub fn EffectMask::memory_write() -> EffectMask {
  EffectMask::may_write_memory()
}

///|
pub fn EffectMask::table_read() -> EffectMask {
  EffectMask::may_read_table()
}

///|
pub fn EffectMask::table_write() -> EffectMask {
  EffectMask::may_write_table()
}

///|
pub fn EffectMask::heap_read() -> EffectMask {
  EffectMask::may_read_gc_heap()
}

///|
pub fn EffectMask::heap_write() -> EffectMask {
  EffectMask::may_write_gc_heap()
}

///|
pub fn EffectMask::global_state() -> EffectMask {
  EffectMask::may_read_global().union(EffectMask::may_write_global())
}

///|
pub fn EffectMask::control() -> EffectMask {
  EffectMask::may_trap()
  .union(EffectMask::may_throw())
  .union(EffectMask::may_diverge())
}

///|
fn normalize_uint_set(values : Array[UInt]) -> Array[UInt] {
  let sorted = values.copy()
  sorted.sort()
  let out : Array[UInt] = []
  for value in sorted {
    if out.is_empty() || out[out.length() - 1] != value {
      out.push(value)
    }
  }
  out
}

///|
pub struct ClosedGlobalSet(Array[UInt]) derive(Eq, Hash, Debug)

///|
pub fn ClosedGlobalSet::new(values : Array[UInt]) -> ClosedGlobalSet {
  ClosedGlobalSet(normalize_uint_set(values))
}

///|
pub struct ClosedMemorySet(Array[UInt]) derive(Eq, Hash, Debug)

///|
pub fn ClosedMemorySet::new(values : Array[UInt]) -> ClosedMemorySet {
  ClosedMemorySet(normalize_uint_set(values))
}

///|
pub struct ClosedTableSet(Array[UInt]) derive(Eq, Hash, Debug)

///|
pub fn ClosedTableSet::new(values : Array[UInt]) -> ClosedTableSet {
  ClosedTableSet(normalize_uint_set(values))
}

///|
pub struct ClosedTypeViewSet(Array[UInt]) derive(Eq, Hash, Debug)

///|
pub fn ClosedTypeViewSet::new(values : Array[UInt]) -> ClosedTypeViewSet {
  ClosedTypeViewSet(normalize_uint_set(values))
}

///|
pub struct ClosedFunctionSet(Array[UInt]) derive(Eq, Hash, Debug)

///|
pub fn ClosedFunctionSet::new(values : Array[UInt]) -> ClosedFunctionSet {
  ClosedFunctionSet(normalize_uint_set(values))
}

///|
pub struct EffectFacts {
  may : EffectMask
  read_globals : ClosedGlobalSet?
  written_globals : ClosedGlobalSet?
  read_memories : ClosedMemorySet?
  written_memories : ClosedMemorySet?
  read_tables : ClosedTableSet?
  written_tables : ClosedTableSet?
  read_heap_types : ClosedTypeViewSet?
  written_heap_types : ClosedTypeViewSet?
  direct_callees : ClosedFunctionSet?
} derive(Eq, Hash, Debug)

///|
pub fn EffectFacts::new(
  may : EffectMask,
  read_globals? : ClosedGlobalSet? = None,
  written_globals? : ClosedGlobalSet? = None,
  read_memories? : ClosedMemorySet? = None,
  written_memories? : ClosedMemorySet? = None,
  read_tables? : ClosedTableSet? = None,
  written_tables? : ClosedTableSet? = None,
  read_heap_types? : ClosedTypeViewSet? = None,
  written_heap_types? : ClosedTypeViewSet? = None,
  direct_callees? : ClosedFunctionSet? = None,
) -> EffectFacts {
  {
    may,
    read_globals,
    written_globals,
    read_memories,
    written_memories,
    read_tables,
    written_tables,
    read_heap_types,
    written_heap_types,
    direct_callees,
  }
}

///|
pub struct FunctionBoundaryFacts {
  all_call_sites_known : Bool
  address_taken : Bool
  host_callable : Bool
} derive(Eq, Hash, Debug)

///|
pub fn FunctionBoundaryFacts::new(
  all_call_sites_known : Bool,
  address_taken : Bool,
  host_callable : Bool,
) -> FunctionBoundaryFacts {
  { all_call_sites_known, address_taken, host_callable, }
}

///|
pub struct FunctionProfile {
  entry_count : UInt64?
  temperature : TemperatureHint?
} derive(Eq, Hash, Debug)

///|
pub fn FunctionProfile::new(
  entry_count? : UInt64? = None,
  temperature? : TemperatureHint? = None,
) -> FunctionProfile {
  { entry_count, temperature, }
}

///|
pub struct CallProfile {
  count : UInt64?
  temperature : TemperatureHint?
} derive(Eq, Hash, Debug)

///|
pub fn CallProfile::new(
  count? : UInt64? = None,
  temperature? : TemperatureHint? = None,
) -> CallProfile {
  { count, temperature, }
}

///|
pub struct BranchProfile {
  taken : UInt64
  not_taken : UInt64
} derive(Eq, Hash, Debug)

///|
pub fn BranchProfile::new(taken : UInt64, not_taken : UInt64) -> BranchProfile {
  { taken, not_taken, }
}

///|
pub struct LoopProfile {
  backedge_count : UInt64?
  estimated_trip_count : UInt64?
} derive(Eq, Hash, Debug)

///|
pub fn LoopProfile::new(
  backedge_count? : UInt64? = None,
  estimated_trip_count? : UInt64? = None,
) -> LoopProfile {
  { backedge_count, estimated_trip_count, }
}

///|
pub enum TemperatureHint {
  Cold
  Normal
  Hot
} derive(Eq, Hash, Debug)

///|
pub fn TemperatureHint::cold() -> TemperatureHint {
  Cold
}

///|
pub fn TemperatureHint::normal() -> TemperatureHint {
  Normal
}

///|
pub fn TemperatureHint::hot() -> TemperatureHint {
  Hot
}

///|
/// Profitability hints are never semantic requirements.
pub enum InlinePolicy {
  DefaultInlinePolicy
  NeverInline
  PreferInline
  AlwaysInline
} derive(Eq, Hash, Debug)

///|
pub fn InlinePolicy::default_() -> InlinePolicy {
  DefaultInlinePolicy
}

///|
pub fn InlinePolicy::never() -> InlinePolicy {
  NeverInline
}

///|
pub fn InlinePolicy::prefer() -> InlinePolicy {
  PreferInline
}

///|
pub fn InlinePolicy::always() -> InlinePolicy {
  AlwaysInline
}

///|
pub struct FunctionFacts {
  function : UInt
  effects : EffectFacts?
  parameters : Array[ParameterFacts]
  results : Array[ResultFacts]
  boundary : FunctionBoundaryFacts?
  profile : FunctionProfile?
  inline_policy : InlinePolicy?
} derive(Eq, Hash, Debug)

///|
pub fn FunctionFacts::new(
  function : UInt,
  effects? : EffectFacts? = None,
  parameters? : Array[ParameterFacts] = [],
  results? : Array[ResultFacts] = [],
  boundary? : FunctionBoundaryFacts? = None,
  profile? : FunctionProfile? = None,
  inline_policy? : InlinePolicy? = None,
) -> FunctionFacts {
  { function, effects, parameters, results, boundary, profile, inline_policy, }
}

///|
pub struct IndexedValueFacts {
  index : UInt
  value : ValueFacts
} derive(Eq, Hash, Debug)

///|
pub fn IndexedValueFacts::new(
  index : UInt,
  value : ValueFacts,
) -> IndexedValueFacts {
  { index, value, }
}

///|
pub struct SignatureFacts {
  signature : UInt
  parameters : Array[IndexedValueFacts]
  results : Array[IndexedValueFacts]
  call_sites_complete : Bool
} derive(Eq, Hash, Debug)

///|
pub fn SignatureFacts::new(
  signature : UInt,
  parameters? : Array[IndexedValueFacts] = [],
  results? : Array[IndexedValueFacts] = [],
  call_sites_complete? : Bool = false,
) -> SignatureFacts {
  { signature, parameters, results, call_sites_complete, }
}

///|
pub enum TypeView {
  ExactTypeView(UInt)
  SubtypeClosureView(UInt)
} derive(Eq, Hash, Debug)

///|
pub fn TypeView::exact(type_ : UInt) -> TypeView {
  ExactTypeView(type_)
}

///|
pub fn TypeView::subtype_closure(type_ : UInt) -> TypeView {
  SubtypeClosureView(type_)
}

///|
pub enum TypePopulation {
  EmptyTypePopulation
  ClosedTypePopulation(ClosedHeapTypeSet)
} derive(Eq, Hash, Debug)

///|
pub fn TypePopulation::empty() -> TypePopulation {
  EmptyTypePopulation
}

///|
pub fn TypePopulation::closed(types : ClosedHeapTypeSet) -> TypePopulation {
  ClosedTypePopulation(types)
}

///|
fn code_site_less(left : CodeSite, right : CodeSite) -> Bool {
  left.function < right.function ||
  (left.function == right.function && left.offset < right.offset)
}

///|
fn normalize_code_sites(values : Array[CodeSite]) -> Array[CodeSite] {
  let out : Array[CodeSite] = []
  for value in values {
    let mut inserted = false
    for i = 0; i < out.length(); i = i + 1 {
      if value == out[i] {
        inserted = true
        break
      }
      if code_site_less(value, out[i]) {
        out.insert(i, value)
        inserted = true
        break
      }
    }
    if !inserted {
      out.push(value)
    }
  }
  out
}

///|
pub enum WriteFacts {
  NoWrites
  InitializationOnly
  ClosedWrites(Array[CodeSite])
} derive(Eq, Hash, Debug)

///|
pub fn WriteFacts::no_writes() -> WriteFacts {
  NoWrites
}

///|
pub fn WriteFacts::initialization_only() -> WriteFacts {
  InitializationOnly
}

///|
pub fn WriteFacts::closed(sites : Array[CodeSite]) -> WriteFacts {
  ClosedWrites(normalize_code_sites(sites))
}

///|
pub struct FieldUsageFacts {
  never_read : Bool
  never_written_after_initialization : Bool
} derive(Eq, Hash, Debug)

///|
pub fn FieldUsageFacts::new(
  never_read? : Bool = false,
  never_written_after_initialization? : Bool = false,
) -> FieldUsageFacts {
  { never_read, never_written_after_initialization, }
}

///|
pub struct FieldFacts {
  view : TypeView
  field : UInt
  stored_contents : ValueFacts?
  writes : WriteFacts?
  usage : FieldUsageFacts?
} derive(Eq, Hash, Debug)

///|
pub fn FieldFacts::new(
  view : TypeView,
  field : UInt,
  stored_contents? : ValueFacts? = None,
  writes? : WriteFacts? = None,
  usage? : FieldUsageFacts? = None,
) -> FieldFacts {
  { view, field, stored_contents, writes, usage, }
}

///|
pub struct ArrayElementFacts {
  view : TypeView
  stored_contents : ValueFacts?
  writes : WriteFacts?
} derive(Eq, Hash, Debug)

///|
pub fn ArrayElementFacts::new(
  view : TypeView,
  stored_contents? : ValueFacts? = None,
  writes? : WriteFacts? = None,
) -> ArrayElementFacts {
  { view, stored_contents, writes, }
}

///|
pub struct TypeFacts {
  type_ : UInt
  population : TypePopulation?
  fields : Array[FieldFacts]
  array_element : ArrayElementFacts?
} derive(Eq, Hash, Debug)

///|
pub fn TypeFacts::new(
  type_ : UInt,
  population? : TypePopulation? = None,
  fields? : Array[FieldFacts] = [],
  array_element? : ArrayElementFacts? = None,
) -> TypeFacts {
  { type_, population, fields, array_element, }
}

///|
pub enum MutationPhase {
  NeverMutated
  InitializationOnlyMutation
  RuntimeMutation
} derive(Eq, Hash, Debug)

///|
pub fn MutationPhase::never() -> MutationPhase {
  NeverMutated
}

///|
pub fn MutationPhase::initialization_only() -> MutationPhase {
  InitializationOnlyMutation
}

///|
pub fn MutationPhase::runtime() -> MutationPhase {
  RuntimeMutation
}

///|
pub struct MutationFacts {
  latest_phase : MutationPhase
  sites : Array[CodeSite]?
} derive(Eq, Hash, Debug)

///|
pub fn MutationFacts::new(
  latest_phase : MutationPhase,
  sites? : Array[CodeSite]? = None,
) -> MutationFacts {
  {
    latest_phase,
    sites: match sites {
      Some(values) => Some(normalize_code_sites(values))
      None => None
    },
  }
}

///|
pub struct GlobalFacts {
  global : UInt
  initial_value : ValueFacts?
  steady_state_value : ValueFacts?
  mutation : MutationFacts?
} derive(Eq, Hash, Debug)

///|
pub fn GlobalFacts::new(
  global : UInt,
  initial_value? : ValueFacts? = None,
  steady_state_value? : ValueFacts? = None,
  mutation? : MutationFacts? = None,
) -> GlobalFacts {
  { global, initial_value, steady_state_value, mutation, }
}

///|
pub struct TableEntryFacts {
  index : UInt64
  value : ReferenceFacts
} derive(Eq, Hash, Debug)

///|
pub fn TableEntryFacts::new(
  index : UInt64,
  value : ReferenceFacts,
) -> TableEntryFacts {
  { index, value, }
}

///|
fn normalize_table_entries(
  values : Array[TableEntryFacts],
) -> Array[TableEntryFacts] {
  let out : Array[TableEntryFacts] = []
  for value in values {
    let mut inserted = false
    for i = 0; i < out.length(); i = i + 1 {
      if value.index <= out[i].index {
        out.insert(i, value)
        inserted = true
        break
      }
    }
    if !inserted {
      out.push(value)
    }
  }
  out
}

///|
pub struct TableFacts {
  table : UInt
  mutation : MutationFacts?
  may_grow : Bool?
  default_value : ReferenceFacts?
  entries : Array[TableEntryFacts]
  contents_complete : Bool
} derive(Eq, Hash, Debug)

///|
pub fn TableFacts::new(
  table : UInt,
  mutation? : MutationFacts? = None,
  may_grow? : Bool? = None,
  default_value? : ReferenceFacts? = None,
  entries? : Array[TableEntryFacts] = [],
  contents_complete? : Bool = false,
) -> TableFacts {
  {
    table,
    mutation,
    may_grow,
    default_value,
    entries: normalize_table_entries(entries),
    contents_complete,
  }
}

///|
pub enum AllocationKind {
  StructAllocation(UInt)
  ArrayAllocation(UInt)
  ClosureAllocation(UInt)
  BoxAllocation(UInt)
  OtherGcAllocation(UInt)
} derive(Eq, Hash, Debug)

///|
pub fn AllocationKind::struct_(type_ : UInt) -> AllocationKind {
  StructAllocation(type_)
}

///|
pub fn AllocationKind::array(type_ : UInt) -> AllocationKind {
  ArrayAllocation(type_)
}

///|
pub fn AllocationKind::closure(type_ : UInt) -> AllocationKind {
  ClosureAllocation(type_)
}

///|
pub fn AllocationKind::box(type_ : UInt) -> AllocationKind {
  BoxAllocation(type_)
}

///|
pub fn AllocationKind::other_gc(type_ : UInt) -> AllocationKind {
  OtherGcAllocation(type_)
}

///|
pub struct AllocationFieldFacts {
  field : UInt
  no_post_init_writes : Bool
  stored_value : ValueFacts?
} derive(Eq, Hash, Debug)

///|
pub fn AllocationFieldFacts::new(
  field : UInt,
  no_post_init_writes? : Bool = false,
  stored_value? : ValueFacts? = None,
) -> AllocationFieldFacts {
  { field, no_post_init_writes, stored_value, }
}

///|
pub struct AllocationFacts {
  kind : AllocationKind
  escape_sinks : EscapeSinkMask?
  identity_unobserved : Bool
  thread_confined : Bool
  length : IntegerFacts?
  fields : Array[AllocationFieldFacts]
} derive(Eq, Hash, Debug)

///|
pub fn AllocationFacts::new(
  kind : AllocationKind,
  escape_sinks? : EscapeSinkMask? = None,
  identity_unobserved? : Bool = false,
  thread_confined? : Bool = false,
  length? : IntegerFacts? = None,
  fields? : Array[AllocationFieldFacts] = [],
) -> AllocationFacts {
  { kind, escape_sinks, identity_unobserved, thread_confined, length, fields, }
}

///|
pub struct AllocationSiteFacts {
  site : ValueSite
  facts : AllocationFacts
  provenance : SourceProvenance?
} derive(Eq, Hash, Debug)

///|
pub fn AllocationSiteFacts::new(
  site : ValueSite,
  facts : AllocationFacts,
  provenance? : SourceProvenance? = None,
) -> AllocationSiteFacts {
  { site, facts, provenance, }
}

///|
pub struct AccessFacts {
  in_bounds : Bool
  alignment_log2 : UInt?
} derive(Eq, Hash, Debug)

///|
pub fn AccessFacts::new(
  in_bounds? : Bool = false,
  alignment_log2? : UInt? = None,
) -> AccessFacts {
  { in_bounds, alignment_log2, }
}

///|
pub struct AccessSiteFacts {
  site : CodeSite
  facts : AccessFacts
  provenance : SourceProvenance?
} derive(Eq, Hash, Debug)

///|
pub fn AccessSiteFacts::new(
  site : CodeSite,
  facts : AccessFacts,
  provenance? : SourceProvenance? = None,
) -> AccessSiteFacts {
  { site, facts, provenance, }
}

///|
pub struct NumericOperationFacts {
  signed_no_wrap : Bool
  unsigned_no_wrap : Bool
  exact_division : Bool
} derive(Eq, Hash, Debug)

///|
pub fn NumericOperationFacts::new(
  signed_no_wrap? : Bool = false,
  unsigned_no_wrap? : Bool = false,
  exact_division? : Bool = false,
) -> NumericOperationFacts {
  { signed_no_wrap, unsigned_no_wrap, exact_division, }
}

///|
pub struct NumericOperationSiteFacts {
  site : ValueSite
  facts : NumericOperationFacts
  provenance : SourceProvenance?
} derive(Eq, Hash, Debug)

///|
pub fn NumericOperationSiteFacts::new(
  site : ValueSite,
  facts : NumericOperationFacts,
  provenance? : SourceProvenance? = None,
) -> NumericOperationSiteFacts {
  { site, facts, provenance, }
}

///|
pub enum FactOperand {
  ValueOperand(ValueRef)
  ConstantOperand(FactValue)
} derive(Eq, Hash, Debug)

///|
pub fn FactOperand::value(value : ValueRef) -> FactOperand {
  ValueOperand(value)
}

///|
pub fn FactOperand::constant(value : FactValue) -> FactOperand {
  ConstantOperand(value)
}

///|
pub enum RelationKind {
  Equal
  NotEqual
  SignedLessThan
  SignedLessOrEqual
  UnsignedLessThan
  UnsignedLessOrEqual
  SameReference
  DistinctReferences
} derive(Eq, Hash, Debug)

///|
pub fn RelationKind::equal() -> RelationKind {
  Equal
}

///|
pub fn RelationKind::not_equal() -> RelationKind {
  NotEqual
}

///|
pub fn RelationKind::signed_less_than() -> RelationKind {
  SignedLessThan
}

///|
pub fn RelationKind::signed_less_or_equal() -> RelationKind {
  SignedLessOrEqual
}

///|
pub fn RelationKind::unsigned_less_than() -> RelationKind {
  UnsignedLessThan
}

///|
pub fn RelationKind::unsigned_less_or_equal() -> RelationKind {
  UnsignedLessOrEqual
}

///|
pub fn RelationKind::same_reference() -> RelationKind {
  SameReference
}

///|
pub fn RelationKind::distinct_references() -> RelationKind {
  DistinctReferences
}

///|
pub struct ScopedRelationFacts {
  at : CodeSite
  left : FactOperand
  kind : RelationKind
  right : FactOperand
} derive(Eq, Hash, Debug)

///|
pub fn ScopedRelationFacts::new(
  at : CodeSite,
  left : FactOperand,
  kind : RelationKind,
  right : FactOperand,
) -> ScopedRelationFacts {
  { at, left, kind, right, }
}

///|
pub struct ExpressionFact {
  value : ValueSite
  facts : ValueFacts
  provenance : SourceProvenance?
} derive(Eq, Hash, Debug)

///|
pub fn ExpressionFact::new(
  value : ValueSite,
  facts : ValueFacts,
  provenance? : SourceProvenance? = None,
) -> ExpressionFact {
  { value, facts, provenance, }
}

///|
pub struct CallSiteFacts {
  site : CodeSite
  direct_target : UInt?
  profile : CallProfile?
  inline_policy : InlinePolicy?
  provenance : SourceProvenance?
} derive(Eq, Hash, Debug)

///|
pub fn CallSiteFacts::new(
  site : CodeSite,
  direct_target? : UInt? = None,
  profile? : CallProfile? = None,
  inline_policy? : InlinePolicy? = None,
  provenance? : SourceProvenance? = None,
) -> CallSiteFacts {
  { site, direct_target, profile, inline_policy, provenance, }
}

///|
pub struct BranchFacts {
  site : CodeSite
  profile : BranchProfile?
  temperature : TemperatureHint?
  provenance : SourceProvenance?
} derive(Eq, Hash, Debug)

///|
pub fn BranchFacts::new(
  site : CodeSite,
  profile? : BranchProfile? = None,
  temperature? : TemperatureHint? = None,
  provenance? : SourceProvenance? = None,
) -> BranchFacts {
  { site, profile, temperature, provenance, }
}

///|
pub struct LoopFacts {
  site : CodeSite
  profile : LoopProfile?
  temperature : TemperatureHint?
  provenance : SourceProvenance?
} derive(Eq, Hash, Debug)

///|
pub fn LoopFacts::new(
  site : CodeSite,
  profile? : LoopProfile? = None,
  temperature? : TemperatureHint? = None,
  provenance? : SourceProvenance? = None,
) -> LoopFacts {
  { site, profile, temperature, provenance, }
}

///|
pub struct FunctionBodyFacts {
  function : UInt
  sites : Array[ExpressionFact]
  relations : Array[ScopedRelationFacts]
  calls : Array[CallSiteFacts]
  branches : Array[BranchFacts]
  loops : Array[LoopFacts]
  allocations : Array[AllocationSiteFacts]
  accesses : Array[AccessSiteFacts]
  numeric_operations : Array[NumericOperationSiteFacts]
} derive(Eq, Hash, Debug)

///|
pub fn FunctionBodyFacts::new(
  function : UInt,
  sites? : Array[ExpressionFact] = [],
  relations? : Array[ScopedRelationFacts] = [],
  calls? : Array[CallSiteFacts] = [],
  branches? : Array[BranchFacts] = [],
  loops? : Array[LoopFacts] = [],
  allocations? : Array[AllocationSiteFacts] = [],
  accesses? : Array[AccessSiteFacts] = [],
  numeric_operations? : Array[NumericOperationSiteFacts] = [],
) -> FunctionBodyFacts {
  {
    function,
    sites,
    relations,
    calls,
    branches,
    loops,
    allocations,
    accesses,
    numeric_operations,
  }
}

///|
pub enum OptimizationGoal {
  PreferSpeed
  Balanced
  PreferSize
} derive(Eq, Hash, Debug)

///|
pub fn OptimizationGoal::prefer_speed() -> OptimizationGoal {
  PreferSpeed
}

///|
pub fn OptimizationGoal::balanced() -> OptimizationGoal {
  Balanced
}

///|
pub fn OptimizationGoal::prefer_size() -> OptimizationGoal {
  PreferSize
}

///|
pub enum HintTarget {
  FunctionHintTarget(UInt)
  SiteHintTarget(CodeSite)
} derive(Eq, Hash, Debug)

///|
pub fn HintTarget::function(function : UInt) -> HintTarget {
  FunctionHintTarget(function)
}

///|
pub fn HintTarget::site(site : CodeSite) -> HintTarget {
  SiteHintTarget(site)
}

///|
/// Probability and confidence values use the inclusive integer domain 0..65535.
pub enum OptimizationHint {
  HotnessHint(HintTarget, TemperatureHint)
  InlineHint(HintTarget, InlinePolicy)
  GoalHint(HintTarget, OptimizationGoal)
  BranchProbabilityHint(CodeSite, UInt)
  EstimatedLoopTripsHint(CodeSite, UInt64)
  LikelyCallTargetHint(CodeSite, UInt, UInt)
  LikelyHeapTypeHint(ValueSite, FactHeapType, UInt)
} derive(Eq, Hash, Debug)

///|
pub fn OptimizationHint::hotness(
  target : HintTarget,
  temperature : TemperatureHint,
) -> OptimizationHint {
  HotnessHint(target, temperature)
}

///|
pub fn OptimizationHint::inline_(
  target : HintTarget,
  policy : InlinePolicy,
) -> OptimizationHint {
  InlineHint(target, policy)
}

///|
pub fn OptimizationHint::goal(
  target : HintTarget,
  goal : OptimizationGoal,
) -> OptimizationHint {
  GoalHint(target, goal)
}

///|
pub fn OptimizationHint::branch_probability(
  site : CodeSite,
  probability : UInt,
) -> OptimizationHint {
  BranchProbabilityHint(site, probability)
}

///|
pub fn OptimizationHint::estimated_loop_trips(
  site : CodeSite,
  trips : UInt64,
) -> OptimizationHint {
  EstimatedLoopTripsHint(site, trips)
}

///|
pub fn OptimizationHint::likely_call_target(
  site : CodeSite,
  function : UInt,
  confidence : UInt,
) -> OptimizationHint {
  LikelyCallTargetHint(site, function, confidence)
}

///|
pub fn OptimizationHint::likely_heap_type(
  site : ValueSite,
  type_ : FactHeapType,
  confidence : UInt,
) -> OptimizationHint {
  LikelyHeapTypeHint(site, type_, confidence)
}

///|
/// Explicit representation of the advisory `compiler.facts` WebAssembly custom
/// section. Facts do not change WebAssembly semantics by themselves. Version 1
/// is the only format currently supported by Starshine.
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
  { version, module_fingerprint, facts }
}

///|
pub struct OptimizationFactsSec {
  functions : Array[FunctionFacts]
  bodies : Array[FunctionBodyFacts]
} derive(Eq, Hash, Debug)

///|
pub fn OptimizationFactsSec::new(
  functions? : Array[FunctionFacts] = [],
  bodies? : Array[FunctionBodyFacts] = [],
) -> OptimizationFactsSec {
  { functions, bodies }
}

///|
pub struct OptimizationFactsBuilder {
  functions : Array[FunctionFacts]
  bodies : Array[FunctionBodyFacts]
} derive(Eq, Hash, Debug)

///|
pub fn OptimizationFactsBuilder::new() -> OptimizationFactsBuilder {
  { functions: [], bodies: [] }
}

///|
pub fn OptimizationFactsBuilder::add_function(
  self : OptimizationFactsBuilder,
  facts : FunctionFacts,
) -> Unit {
  self.functions.push(facts)
}

///|
pub fn OptimizationFactsBuilder::add_body(
  self : OptimizationFactsBuilder,
  facts : FunctionBodyFacts,
) -> Unit {
  self.bodies.push(facts)
}

///|
pub fn OptimizationFactsBuilder::finish(
  self : OptimizationFactsBuilder,
) -> OptimizationFactsSec {
  OptimizationFactsSec::new(
    functions=self.functions.copy(),
    bodies=self.bodies.copy(),
  )
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
  { function, effects, parameters, results, boundary, profile, inline_policy }
}

///|
/// `may` is an upper bound. For each closed set, `Some(set)` claims the set is
/// complete, `None` means the complete set is unknown, and `Some(empty)` means
/// no resource in that category. Consumers must never treat `None` as empty.
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
pub fn EffectMask::control() -> EffectMask {
  EffectMask(1UL << 0)
}

///|
pub fn EffectMask::call() -> EffectMask {
  EffectMask(1UL << 1)
}

///|
pub fn EffectMask::throw_() -> EffectMask {
  EffectMask(1UL << 2)
}

///|
pub fn EffectMask::trap() -> EffectMask {
  EffectMask(1UL << 3)
}

///|
pub fn EffectMask::local_state() -> EffectMask {
  EffectMask(1UL << 4)
}

///|
pub fn EffectMask::global_state() -> EffectMask {
  EffectMask(1UL << 5)
}

///|
pub fn EffectMask::memory_read() -> EffectMask {
  EffectMask(1UL << 6)
}

///|
pub fn EffectMask::memory_write() -> EffectMask {
  EffectMask(1UL << 7)
}

///|
pub fn EffectMask::table_read() -> EffectMask {
  EffectMask(1UL << 8)
}

///|
pub fn EffectMask::table_write() -> EffectMask {
  EffectMask(1UL << 9)
}

///|
pub fn EffectMask::heap_read() -> EffectMask {
  EffectMask(1UL << 10)
}

///|
pub fn EffectMask::heap_write() -> EffectMask {
  EffectMask(1UL << 11)
}

///|
pub fn EffectMask::allocation() -> EffectMask {
  EffectMask(1UL << 12)
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
fn normalize_closed_set(values : Array[UInt]) -> Array[UInt] {
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
  ClosedGlobalSet(normalize_closed_set(values))
}

///|
pub struct ClosedMemorySet(Array[UInt]) derive(Eq, Hash, Debug)

///|
pub fn ClosedMemorySet::new(values : Array[UInt]) -> ClosedMemorySet {
  ClosedMemorySet(normalize_closed_set(values))
}

///|
pub struct ClosedTableSet(Array[UInt]) derive(Eq, Hash, Debug)

///|
pub fn ClosedTableSet::new(values : Array[UInt]) -> ClosedTableSet {
  ClosedTableSet(normalize_closed_set(values))
}

///|
pub struct ClosedTypeViewSet(Array[UInt]) derive(Eq, Hash, Debug)

///|
pub fn ClosedTypeViewSet::new(values : Array[UInt]) -> ClosedTypeViewSet {
  ClosedTypeViewSet(normalize_closed_set(values))
}

///|
pub struct ClosedFunctionSet(Array[UInt]) derive(Eq, Hash, Debug)

///|
pub fn ClosedFunctionSet::new(values : Array[UInt]) -> ClosedFunctionSet {
  ClosedFunctionSet(normalize_closed_set(values))
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
  { parameter, value, uses, escape_sinks }
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
  { result, value, identity }
}

///|
pub enum ResultIdentityFacts {
  FreshIdentity
  SameAsParameter(UInt)
} derive(Eq, Hash, Debug)

///|
pub fn ResultIdentityFacts::fresh() -> ResultIdentityFacts {
  FreshIdentity
}

///|
pub fn ResultIdentityFacts::same_as_parameter(
  parameter : UInt,
) -> ResultIdentityFacts {
  SameAsParameter(parameter)
}

///|
/// Boolean fields are positive assertions only. For example, `non_null=false`
/// means non-nullness is not asserted; it does not mean the value is null.
pub struct ValueFacts {
  non_null : Bool
  exact_heap_type : UInt?
  exact_call_target : UInt?
  signed_range : SignedRange?
  unsigned_range : UnsignedRange?
  does_not_escape : Bool
  identity_not_observed : Bool
} derive(Eq, Hash, Debug)

///|
pub fn ValueFacts::new(
  non_null? : Bool = false,
  exact_heap_type? : UInt? = None,
  exact_call_target? : UInt? = None,
  signed_range? : SignedRange? = None,
  unsigned_range? : UnsignedRange? = None,
  does_not_escape? : Bool = false,
  identity_not_observed? : Bool = false,
) -> ValueFacts {
  {
    non_null,
    exact_heap_type,
    exact_call_target,
    signed_range,
    unsigned_range,
    does_not_escape,
    identity_not_observed,
  }
}

///|
pub struct SignedRange {
  min : Int64
  max : Int64
} derive(Eq, Hash, Debug)

///|
pub fn SignedRange::new(min : Int64, max : Int64) -> SignedRange {
  { min, max }
}

///|
pub struct UnsignedRange {
  min : UInt64
  max : UInt64
} derive(Eq, Hash, Debug)

///|
pub fn UnsignedRange::new(min : UInt64, max : UInt64) -> UnsignedRange {
  { min, max }
}

///|
/// These are independent advisory claims. A false flag does not imply any
/// stronger fact about either of the other flags.
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
  { all_call_sites_known, address_taken, host_callable }
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
  { entry_count, temperature }
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
  { count, temperature }
}

///|
pub struct BranchProfile {
  taken : UInt64
  not_taken : UInt64
} derive(Eq, Hash, Debug)

///|
pub fn BranchProfile::new(taken : UInt64, not_taken : UInt64) -> BranchProfile {
  { taken, not_taken }
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
  { backedge_count, estimated_trip_count }
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
/// Profitability hints only; these variants are not semantic requirements.
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
pub struct FunctionBodyFacts {
  function : UInt
  sites : Array[ExpressionFact]
  relations : Array[FactRelation]
  calls : Array[CallSiteFacts]
  branches : Array[BranchFacts]
  loops : Array[LoopFacts]
  allocations : Array[AllocationSiteFacts]
} derive(Eq, Hash, Debug)

///|
pub fn FunctionBodyFacts::new(
  function : UInt,
  sites? : Array[ExpressionFact] = [],
  relations? : Array[FactRelation] = [],
  calls? : Array[CallSiteFacts] = [],
  branches? : Array[BranchFacts] = [],
  loops? : Array[LoopFacts] = [],
  allocations? : Array[AllocationSiteFacts] = [],
) -> FunctionBodyFacts {
  { function, sites, relations, calls, branches, loops, allocations }
}

///|
/// `offset` is the byte offset from the first instruction opcode in Starshine's
/// canonical encoded function body, after the local-declaration vector. Offset
/// zero names the first opcode. Structural delimiters such as `else`, `catch`,
/// and `end` are not sites. Producers must recompute or drop site facts when
/// body encoding changes make these offsets stale.
pub struct ExpressionFact {
  function : UInt
  offset : UInt
  facts : Array[Fact]
} derive(Eq, Hash, Debug)

///|
pub fn ExpressionFact::new(
  function : UInt,
  offset : UInt,
  facts : Array[Fact],
) -> ExpressionFact {
  { function, offset, facts }
}

///|
pub enum Fact {
  NonNull
  ExactHeapType(UInt)
  ExactCallTarget(UInt)
  SignedRangeFact(Int64, Int64)
  UnsignedRangeFact(UInt64, UInt64)
  DoesNotEscape
  IdentityNotObserved
} derive(Eq, Hash, Debug)

///|
pub fn Fact::non_null() -> Fact {
  NonNull
}

///|
pub fn Fact::exact_heap_type(heap_type : UInt) -> Fact {
  ExactHeapType(heap_type)
}

///|
pub fn Fact::exact_call_target(function : UInt) -> Fact {
  ExactCallTarget(function)
}

///|
pub fn Fact::signed_range(min : Int64, max : Int64) -> Fact {
  SignedRangeFact(min, max)
}

///|
pub fn Fact::unsigned_range(min : UInt64, max : UInt64) -> Fact {
  UnsignedRangeFact(min, max)
}

///|
pub fn Fact::does_not_escape() -> Fact {
  DoesNotEscape
}

///|
pub fn Fact::identity_not_observed() -> Fact {
  IdentityNotObserved
}

///|
pub struct FactSiteRef {
  function : UInt
  offset : UInt
} derive(Eq, Hash, Debug)

///|
pub fn FactSiteRef::new(function : UInt, offset : UInt) -> FactSiteRef {
  { function, offset }
}

///|
/// Advisory cross-site relationships; ordinary Wasm validation never depends
/// on their truth.
pub enum FactRelation {
  SameValue(FactSiteRef, FactSiteRef)
  SameIdentity(FactSiteRef, FactSiteRef)
  DerivedFrom(FactSiteRef, FactSiteRef)
} derive(Eq, Hash, Debug)

///|
pub fn FactRelation::same_value(
  left : FactSiteRef,
  right : FactSiteRef,
) -> FactRelation {
  SameValue(left, right)
}

///|
pub fn FactRelation::same_identity(
  left : FactSiteRef,
  right : FactSiteRef,
) -> FactRelation {
  SameIdentity(left, right)
}

///|
pub fn FactRelation::derived_from(
  value : FactSiteRef,
  source : FactSiteRef,
) -> FactRelation {
  DerivedFrom(value, source)
}

///|
pub struct CallSiteFacts {
  function : UInt
  offset : UInt
  direct_target : UInt?
  profile : CallProfile?
  inline_policy : InlinePolicy?
} derive(Eq, Hash, Debug)

///|
pub fn CallSiteFacts::new(
  function : UInt,
  offset : UInt,
  direct_target? : UInt? = None,
  profile? : CallProfile? = None,
  inline_policy? : InlinePolicy? = None,
) -> CallSiteFacts {
  { function, offset, direct_target, profile, inline_policy }
}

///|
pub struct BranchFacts {
  function : UInt
  offset : UInt
  profile : BranchProfile?
  temperature : TemperatureHint?
} derive(Eq, Hash, Debug)

///|
pub fn BranchFacts::new(
  function : UInt,
  offset : UInt,
  profile? : BranchProfile? = None,
  temperature? : TemperatureHint? = None,
) -> BranchFacts {
  { function, offset, profile, temperature }
}

///|
pub struct LoopFacts {
  function : UInt
  offset : UInt
  profile : LoopProfile?
  temperature : TemperatureHint?
} derive(Eq, Hash, Debug)

///|
pub fn LoopFacts::new(
  function : UInt,
  offset : UInt,
  profile? : LoopProfile? = None,
  temperature? : TemperatureHint? = None,
) -> LoopFacts {
  { function, offset, profile, temperature }
}

///|
pub struct AllocationSiteFacts {
  function : UInt
  offset : UInt
  heap_type : UInt?
  does_not_escape : Bool
  identity_not_observed : Bool
} derive(Eq, Hash, Debug)

///|
pub fn AllocationSiteFacts::new(
  function : UInt,
  offset : UInt,
  heap_type? : UInt? = None,
  does_not_escape? : Bool = false,
  identity_not_observed? : Bool = false,
) -> AllocationSiteFacts {
  { function, offset, heap_type, does_not_escape, identity_not_observed }
}

///|
/// Optimizer-local policy. This is deliberately not serialized in Wasm.
pub enum CompilerFactUsePolicy {
  IgnoreFacts
  HintsOnly
  TrustAssertions
} derive(Eq, Debug)

///|
pub fn CompilerFactUsePolicy::ignore() -> CompilerFactUsePolicy {
  IgnoreFacts
}

///|
pub fn CompilerFactUsePolicy::hints_only() -> CompilerFactUsePolicy {
  HintsOnly
}

///|
pub fn CompilerFactUsePolicy::trust_assertions() -> CompilerFactUsePolicy {
  TrustAssertions
}

///|
pub struct CompilerFactMaterializationStats {
  mut fact_sections_seen : Int
  mut function_bodies_with_facts : Int
  mut function_facts_seen : Int
  mut signature_facts_seen : Int
  mut type_facts_seen : Int
  mut global_facts_seen : Int
  mut table_facts_seen : Int
  mut value_facts_seen : Int
  mut relation_facts_seen : Int
  mut call_facts_seen : Int
  mut branch_facts_seen : Int
  mut loop_facts_seen : Int
  mut allocation_facts_seen : Int
  mut access_facts_seen : Int
  mut numeric_operation_facts_seen : Int
  mut hint_facts_seen : Int
  mut trusted_assertion_facts : Int
  mut hint_only_facts : Int
  mut candidate_rewrites : Int
  mut exact_call_target_facts_seen : Int
  mut exact_call_target_facts_accepted : Int
  mut call_ref_converted : Int
  mut return_call_ref_converted : Int
  mut integer_comparisons_folded : Int
  mut integer_zero_checks_folded : Int
  mut reference_null_checks_folded : Int
  mut structurally_incompatible_rejected : Int
  mut stale_or_unresolved_sites : Int
  mut type_mismatches : Int
  mut invalid_referenced_indices : Int
  mut unsupported_versions : Int
  mut malformed_or_impossible_facts : Int
  mut facts_blocked_by_trust : Int
  mut valid_facts_without_rewrite : Int
  mut ignored_untrusted_assertions : Int
} derive(Eq, Debug)

///|
pub fn CompilerFactMaterializationStats::new() -> CompilerFactMaterializationStats {
  {
    fact_sections_seen: 0,
    function_bodies_with_facts: 0,
    function_facts_seen: 0,
    signature_facts_seen: 0,
    type_facts_seen: 0,
    global_facts_seen: 0,
    table_facts_seen: 0,
    value_facts_seen: 0,
    relation_facts_seen: 0,
    call_facts_seen: 0,
    branch_facts_seen: 0,
    loop_facts_seen: 0,
    allocation_facts_seen: 0,
    access_facts_seen: 0,
    numeric_operation_facts_seen: 0,
    hint_facts_seen: 0,
    trusted_assertion_facts: 0,
    hint_only_facts: 0,
    candidate_rewrites: 0,
    exact_call_target_facts_seen: 0,
    exact_call_target_facts_accepted: 0,
    call_ref_converted: 0,
    return_call_ref_converted: 0,
    integer_comparisons_folded: 0,
    integer_zero_checks_folded: 0,
    reference_null_checks_folded: 0,
    structurally_incompatible_rejected: 0,
    stale_or_unresolved_sites: 0,
    type_mismatches: 0,
    invalid_referenced_indices: 0,
    unsupported_versions: 0,
    malformed_or_impossible_facts: 0,
    facts_blocked_by_trust: 0,
    valid_facts_without_rewrite: 0,
    ignored_untrusted_assertions: 0,
  }
}

///|
pub struct ApplyCompilerFactsResult {
  module_ : @lib.Module
  stats : CompilerFactMaterializationStats
} derive(Debug)

///|
fn compiler_fact_stats_summary(
  stats : CompilerFactMaterializationStats,
) -> String {
  "sections=\{stats.fact_sections_seen} bodies=\{stats.function_bodies_with_facts} categories.function=\{stats.function_facts_seen} categories.signature=\{stats.signature_facts_seen} categories.type=\{stats.type_facts_seen} categories.global=\{stats.global_facts_seen} categories.table=\{stats.table_facts_seen} categories.value=\{stats.value_facts_seen} categories.relation=\{stats.relation_facts_seen} categories.call=\{stats.call_facts_seen} categories.branch=\{stats.branch_facts_seen} categories.loop=\{stats.loop_facts_seen} categories.allocation=\{stats.allocation_facts_seen} categories.access=\{stats.access_facts_seen} categories.numeric=\{stats.numeric_operation_facts_seen} hints=\{stats.hint_facts_seen} trusted=\{stats.trusted_assertion_facts} hint_only=\{stats.hint_only_facts} candidates=\{stats.candidate_rewrites} applied.call_ref=\{stats.call_ref_converted} applied.return_call_ref=\{stats.return_call_ref_converted} applied.integer_compare=\{stats.integer_comparisons_folded} applied.integer_eqz=\{stats.integer_zero_checks_folded} applied.ref_is_null=\{stats.reference_null_checks_folded} rejected.stale=\{stats.stale_or_unresolved_sites} rejected.type=\{stats.type_mismatches} rejected.index=\{stats.invalid_referenced_indices} rejected.version=\{stats.unsupported_versions} rejected.malformed=\{stats.malformed_or_impossible_facts} rejected.structure=\{stats.structurally_incompatible_rejected} blocked.trust=\{stats.facts_blocked_by_trust} no_improvement=\{stats.valid_facts_without_rewrite}"
}

///|
fn compiler_fact_index_size_from_uints(values : Array[UInt]) -> Int {
  let mut size = 0
  for value in values {
    let candidate = value.reinterpret_as_int() + 1
    if candidate > size {
      size = candidate
    }
  }
  size
}

///|
/// Read-only, nonserialized index built once per optimization invocation.
pub struct CompilerFactIndex {
  facts : @representation.OptimizationFactsSec
  functions : Array[@representation.FunctionFacts?]
  bodies : Array[@representation.FunctionBodyFacts?]
  signatures : Array[@representation.SignatureFacts?]
  types : Array[@representation.TypeFacts?]
  globals : Array[@representation.GlobalFacts?]
  tables : Array[@representation.TableFacts?]
} derive(Debug)

///|
pub fn CompilerFactIndex::new(
  facts : @representation.OptimizationFactsSec,
) -> CompilerFactIndex {
  let function_indices : Array[UInt] = []
  for value in facts.functions {
    function_indices.push(value.function)
  }
  for value in facts.bodies {
    function_indices.push(value.function)
  }
  let signature_indices : Array[UInt] = []
  for value in facts.signatures {
    signature_indices.push(value.signature)
  }
  let type_indices : Array[UInt] = []
  for value in facts.types {
    type_indices.push(value.type_)
  }
  let global_indices : Array[UInt] = []
  for value in facts.globals {
    global_indices.push(value.global)
  }
  let table_indices : Array[UInt] = []
  for value in facts.tables {
    table_indices.push(value.table)
  }
  let functions = Array::make(
    compiler_fact_index_size_from_uints(function_indices),
    None,
  )
  let bodies = Array::make(functions.length(), None)
  let signatures = Array::make(
    compiler_fact_index_size_from_uints(signature_indices),
    None,
  )
  let types = Array::make(
    compiler_fact_index_size_from_uints(type_indices),
    None,
  )
  let globals = Array::make(
    compiler_fact_index_size_from_uints(global_indices),
    None,
  )
  let tables = Array::make(
    compiler_fact_index_size_from_uints(table_indices),
    None,
  )
  for value in facts.functions {
    functions[value.function.reinterpret_as_int()] = Some(value)
  }
  for value in facts.bodies {
    bodies[value.function.reinterpret_as_int()] = Some(value)
  }
  for value in facts.signatures {
    signatures[value.signature.reinterpret_as_int()] = Some(value)
  }
  for value in facts.types {
    types[value.type_.reinterpret_as_int()] = Some(value)
  }
  for value in facts.globals {
    globals[value.global.reinterpret_as_int()] = Some(value)
  }
  for value in facts.tables {
    tables[value.table.reinterpret_as_int()] = Some(value)
  }
  { facts, functions, bodies, signatures, types, globals, tables }
}

///|
fn compiler_fact_index_bounded(
  facts : @representation.OptimizationFactsSec,
  env : @validate.Env,
) -> CompilerFactIndex {
  let functions = Array::make(env.funcs.length(), None)
  let bodies = Array::make(env.funcs.length(), None)
  for value in facts.functions {
    let slot = value.function.reinterpret_as_int()
    if slot >= 0 && slot < functions.length() {
      functions[slot] = Some(value)
    }
  }
  for value in facts.bodies {
    let slot = value.function.reinterpret_as_int()
    if slot >= 0 && slot < bodies.length() {
      bodies[slot] = Some(value)
    }
  }

  let signatures = Array::make(env.global_types.length(), None)
  for value in facts.signatures {
    let slot = value.signature.reinterpret_as_int()
    if slot >= 0 && slot < signatures.length() {
      signatures[slot] = Some(value)
    }
  }

  let types = Array::make(env.global_types.length(), None)
  for value in facts.types {
    let slot = value.type_.reinterpret_as_int()
    if slot >= 0 && slot < types.length() {
      types[slot] = Some(value)
    }
  }

  let globals = Array::make(env.globals.length(), None)
  for value in facts.globals {
    let slot = value.global.reinterpret_as_int()
    if slot >= 0 && slot < globals.length() {
      globals[slot] = Some(value)
    }
  }

  let tables = Array::make(env.tables.length(), None)
  for value in facts.tables {
    let slot = value.table.reinterpret_as_int()
    if slot >= 0 && slot < tables.length() {
      tables[slot] = Some(value)
    }
  }

  { facts, functions, bodies, signatures, types, globals, tables, }
}

///|
pub fn CompilerFactIndex::function_facts(
  self : CompilerFactIndex,
  function : @lib.FuncIdx,
) -> @representation.FunctionFacts? {
  let @lib.FuncIdx(raw) = function
  match self.functions.get(raw.reinterpret_as_int()) {
    Some(value) => value
    None => None
  }
}

///|
pub fn CompilerFactIndex::body_facts(
  self : CompilerFactIndex,
  function : @lib.FuncIdx,
) -> @representation.FunctionBodyFacts? {
  let @lib.FuncIdx(raw) = function
  match self.bodies.get(raw.reinterpret_as_int()) {
    Some(value) => value
    None => None
  }
}

///|
pub fn CompilerFactIndex::signature_facts(
  self : CompilerFactIndex,
  signature : @lib.TypeIdx,
) -> @representation.SignatureFacts? {
  match signature {
    @lib.TypeIdx(raw) =>
      match self.signatures.get(raw.reinterpret_as_int()) {
        Some(value) => value
        None => None
      }
    @lib.RecIdx(_) => None
  }
}

///|
pub fn CompilerFactIndex::type_facts(
  self : CompilerFactIndex,
  type_ : @lib.TypeIdx,
) -> @representation.TypeFacts? {
  match type_ {
    @lib.TypeIdx(raw) =>
      match self.types.get(raw.reinterpret_as_int()) {
        Some(value) => value
        None => None
      }
    @lib.RecIdx(_) => None
  }
}

///|
pub fn CompilerFactIndex::global_facts(
  self : CompilerFactIndex,
  global : @lib.GlobalIdx,
) -> @representation.GlobalFacts? {
  let @lib.GlobalIdx(raw) = global
  match self.globals.get(raw.reinterpret_as_int()) {
    Some(value) => value
    None => None
  }
}

///|
pub fn CompilerFactIndex::table_facts(
  self : CompilerFactIndex,
  table : @lib.TableIdx,
) -> @representation.TableFacts? {
  let @lib.TableIdx(raw) = table
  match self.tables.get(raw.reinterpret_as_int()) {
    Some(value) => value
    None => None
  }
}

///|
pub fn CompilerFactIndex::value_facts(
  self : CompilerFactIndex,
  site : @representation.ValueSite,
) -> @representation.ValueFacts? {
  match self.bodies.get(site.site.function.reinterpret_as_int()) {
    Some(Some(body)) =>
      for value in body.sites {
        if value.value == site {
          return Some(value.facts)
        }
      }
    _ => ()
  }
  None
}

///|
pub fn CompilerFactIndex::call_facts(
  self : CompilerFactIndex,
  site : @representation.CodeSite,
) -> @representation.CallSiteFacts? {
  match self.bodies.get(site.function.reinterpret_as_int()) {
    Some(Some(body)) =>
      for value in body.calls {
        if value.site == site {
          return Some(value)
        }
      }
    _ => ()
  }
  None
}

///|
pub fn CompilerFactIndex::allocation_facts(
  self : CompilerFactIndex,
  site : @representation.ValueSite,
) -> @representation.AllocationFacts? {
  match self.bodies.get(site.site.function.reinterpret_as_int()) {
    Some(Some(body)) =>
      for value in body.allocations {
        if value.site == site {
          return Some(value.facts)
        }
      }
    _ => ()
  }
  None
}

///|
pub fn CompilerFactIndex::hints_for_function(
  self : CompilerFactIndex,
  function : @lib.FuncIdx,
) -> Array[@representation.OptimizationHint] {
  let @lib.FuncIdx(raw) = function
  let out : Array[@representation.OptimizationHint] = []
  for hint in self.facts.hints {
    match hint {
      @representation.HotnessHint(@representation.FunctionHintTarget(index), _)
      | @representation.InlineHint(@representation.FunctionHintTarget(index), _)
      | @representation.GoalHint(@representation.FunctionHintTarget(index), _) if index ==
        raw => out.push(hint)
      _ => ()
    }
  }
  out
}

///|
pub fn CompilerFactIndex::hints_for_site(
  self : CompilerFactIndex,
  site : @representation.CodeSite,
) -> Array[@representation.OptimizationHint] {
  let out : Array[@representation.OptimizationHint] = []
  for hint in self.facts.hints {
    let matches = match hint {
      @representation.HotnessHint(@representation.SiteHintTarget(value), _)
      | @representation.InlineHint(@representation.SiteHintTarget(value), _)
      | @representation.GoalHint(@representation.SiteHintTarget(value), _)
      | @representation.BranchProbabilityHint(value, _)
      | @representation.EstimatedLoopTripsHint(value, _)
      | @representation.LikelyCallTargetHint(value, _, _) => value == site
      @representation.LikelyHeapTypeHint(value, _, _) => value.site == site
      _ => false
    }
    if matches {
      out.push(hint)
    }
  }
  out
}

///|
fn compiler_fact_exact_target_from_value_facts(
  facts : @representation.ValueFacts,
) -> UInt? {
  let from_values = match facts.possible_values {
    Some(
      @representation.ClosedValueSet([@representation.RefFuncValue(function)])
    ) => Some(function)
    _ => None
  }
  let from_targets = match facts.reference {
    Some(reference) =>
      match (reference.nullability, reference.function_targets) {
        (
          Some(@representation.NonNull),
          Some(@representation.ClosedFunctionSet([function])),
        ) => Some(function)
        _ => None
      }
    None => None
  }
  match (from_values, from_targets) {
    (Some(left), Some(right)) if left == right => Some(left)
    (Some(_), Some(_)) => None
    (Some(value), None) | (None, Some(value)) => Some(value)
    _ => None
  }
}

///|
pub fn CompilerFactIndex::compiler_fact_exact_call_target(
  self : CompilerFactIndex,
  site : @representation.CodeSite,
  target_value_site? : @representation.ValueSite? = None,
) -> UInt? {
  let call_target = match self.call_facts(site) {
    Some(facts) => facts.direct_target
    None => None
  }
  let value_target = match target_value_site {
    Some(value_site) =>
      match self.value_facts(value_site) {
        Some(facts) => compiler_fact_exact_target_from_value_facts(facts)
        None => None
      }
    None => None
  }
  match (call_target, value_target) {
    (Some(left), Some(right)) if left == right => Some(left)
    (Some(_), Some(_)) => None
    (Some(value), None) | (None, Some(value)) => Some(value)
    _ => None
  }
}

///|
fn compiler_fact_count_exact_targets(index : CompilerFactIndex) -> Int {
  let mut count = 0
  for body in index.facts.bodies {
    for call in body.calls {
      if call.direct_target is Some(_) {
        count += 1
      }
    }
    for site in body.sites {
      if compiler_fact_exact_target_from_value_facts(site.facts) is Some(_) {
        count += 1
      }
    }
  }
  count
}

///|
fn compiler_fact_materializer_result_arity(
  instruction : @lib.Instruction,
  env : @validate.Env,
) -> UInt? {
  match instruction {
    @lib.Call(function) =>
      match env.get_functype_by_funcidx(function) {
        Some(@lib.FuncType(_, results)) =>
          Some(results.length().reinterpret_as_uint())
        None => None
      }
    @lib.CallIndirect(type_, _) | @lib.CallRef(type_) =>
      match env.resolve_functype(type_) {
        Some(@lib.FuncType(_, results)) =>
          Some(results.length().reinterpret_as_uint())
        None => None
      }
    @lib.Block(type_, _)
    | @lib.Loop(type_, _)
    | @lib.If(type_, _, _)
    | @lib.Try(type_, _, _, _)
    | @lib.TryTable(type_, _, _) =>
      match env.expand_blocktype(type_) {
        Ok((_, results)) => Some(results.length().reinterpret_as_uint())
        Err(_) => None
      }
    @lib.Unreachable
    | @lib.Nop
    | @lib.Throw(_)
    | @lib.ThrowRef
    | @lib.Rethrow(_)
    | @lib.Br(_)
    | @lib.BrIf(_)
    | @lib.BrTable(_, _)
    | @lib.Return
    | @lib.ReturnCall(_)
    | @lib.ReturnCallIndirect(_, _)
    | @lib.ReturnCallRef(_)
    | @lib.LocalSet(_)
    | @lib.GlobalSet(_)
    | @lib.TableSet(_)
    | @lib.I32Store(_)
    | @lib.I64Store(_)
    | @lib.F32Store(_)
    | @lib.F64Store(_)
    | @lib.I32Store8(_)
    | @lib.I32Store16(_)
    | @lib.I64Store8(_)
    | @lib.I64Store16(_)
    | @lib.I64Store32(_)
    | @lib.AtomicFence(_)
    | @lib.I32AtomicStore(_, _)
    | @lib.I64AtomicStore(_, _)
    | @lib.I32AtomicStore8(_, _)
    | @lib.I32AtomicStore16(_, _)
    | @lib.I64AtomicStore8(_, _)
    | @lib.I64AtomicStore16(_, _)
    | @lib.I64AtomicStore32(_, _)
    | @lib.StructSet(_, _)
    | @lib.ArraySet(_)
    | @lib.ArrayStore(_, _)
    | @lib.ArrayFill(_)
    | @lib.ArrayCopy(_, _)
    | @lib.ArrayInitData(_, _)
    | @lib.ArrayInitElem(_, _)
    | @lib.MemoryInit(_, _)
    | @lib.DataDrop(_)
    | @lib.MemoryCopy(_, _)
    | @lib.MemoryFill(_)
    | @lib.TableInit(_, _)
    | @lib.ElemDrop(_)
    | @lib.TableCopy(_, _)
    | @lib.TableFill(_)
    | @lib.V128Store(_)
    | @lib.V128Store8Lane(_, _)
    | @lib.V128Store16Lane(_, _)
    | @lib.V128Store32Lane(_, _)
    | @lib.V128Store64Lane(_, _)
    | @lib.Drop => Some(0U)
    _ => Some(1U)
  }
}

///|
priv struct CompilerFactRewriteContext {
  function : UInt
  sites : Array[(UInt, @lib.Instruction)]
  cursor : Ref[Int]
  query : CompilerFactQuery
  stats : CompilerFactMaterializationStats
}

///|
fn compiler_fact_rewrite_nested_instruction(
  instr : @lib.Instruction,
  ctx : CompilerFactRewriteContext,
) -> @lib.Instruction {
  match instr {
    @lib.Block(type_, @lib.Expr(body)) =>
      @lib.Instruction::block(
        type_,
        @lib.Expr::new(compiler_fact_rewrite_region(body, ctx)),
      )
    @lib.Loop(type_, @lib.Expr(body)) =>
      @lib.Instruction::loop_(
        type_,
        @lib.Expr::new(compiler_fact_rewrite_region(body, ctx)),
      )
    @lib.If(type_, then_body, else_body) =>
      @lib.Instruction::if_(
        type_,
        compiler_fact_rewrite_region(then_body, ctx),
        match else_body {
          Some(body) => Some(compiler_fact_rewrite_region(body, ctx))
          None => None
        },
      )
    @lib.Try(type_, @lib.Expr(body), catches, delegate) => {
      let next_catches : Array[@lib.LegacyCatch] = []
      for catch_ in catches {
        match catch_ {
          @lib.LegacyCatch(tag, @lib.Expr(catch_body)) =>
            next_catches.push(
              @lib.LegacyCatch::tagged(
                tag,
                @lib.Expr::new(compiler_fact_rewrite_region(catch_body, ctx)),
              ),
            )
          @lib.LegacyCatchAll(@lib.Expr(catch_body)) =>
            next_catches.push(
              @lib.LegacyCatch::all(
                @lib.Expr::new(compiler_fact_rewrite_region(catch_body, ctx)),
              ),
            )
        }
      }
      @lib.Instruction::try_(
        type_,
        @lib.Expr::new(compiler_fact_rewrite_region(body, ctx)),
        next_catches,
        delegate~,
      )
    }
    @lib.TryTable(type_, catches, @lib.Expr(body)) =>
      @lib.Instruction::try_table(
        type_,
        catches,
        @lib.Expr::new(compiler_fact_rewrite_region(body, ctx)),
      )
    _ => instr
  }
}

///|
fn compiler_fact_compare_expected_type(
  instruction : @lib.Instruction,
) -> @lib.ValType? {
  match instruction {
    @lib.I32Eq
    | @lib.I32Ne
    | @lib.I32LtS
    | @lib.I32LtU
    | @lib.I32GtS
    | @lib.I32GtU
    | @lib.I32LeS
    | @lib.I32LeU
    | @lib.I32GeS
    | @lib.I32GeU => Some(@lib.ValType::i32())
    @lib.I64Eq
    | @lib.I64Ne
    | @lib.I64LtS
    | @lib.I64LtU
    | @lib.I64GtS
    | @lib.I64GtU
    | @lib.I64LeS
    | @lib.I64LeU
    | @lib.I64GeS
    | @lib.I64GeU => Some(@lib.ValType::i64())
    _ => None
  }
}

///|
fn compiler_fact_truth_instruction(
  truth : CompilerFactTruth,
) -> @lib.Instruction? {
  match truth {
    FactProvenTrue => Some(@lib.Instruction::i32_const(@lib.I32(1)))
    FactProvenFalse => Some(@lib.Instruction::i32_const(@lib.I32(0)))
    FactUnknown => None
  }
}

///|
fn compiler_fact_integer_operand_domain(
  ctx : CompilerFactRewriteContext,
  root : (@representation.CodeSite, @lib.Instruction),
  expected : @lib.ValType,
) -> (CompilerFactIntegerDomain?, Bool) {
  match compiler_fact_integer_domain_from_const(root.1) {
    Some(domain) => (Some(domain), false)
    None => {
      let arity = compiler_fact_materializer_result_arity(root.1, ctx.query.env)
      if arity != Some(1U) {
        ctx.stats.type_mismatches += 1
        return (None, false)
      }
      let domain = ctx.query.integer_domain(
        ctx.function,
        @representation.ValueSite::new(root.0),
        root.1,
        expected,
      )
      (domain, domain is Some(_))
    }
  }
}

///|
fn compiler_fact_push_folded_predicate(
  out : Array[@lib.Instruction],
  drops : Int,
  truth : CompilerFactTruth,
) -> Bool {
  let constant = match compiler_fact_truth_instruction(truth) {
    Some(constant) => constant
    None => return false
  }
  for _ in 0..<drops {
    out.push(@lib.Instruction::drop())
  }
  out.push(constant)
  true
}

///|
fn compiler_fact_rewrite_region(
  instrs : Array[@lib.Instruction],
  ctx : CompilerFactRewriteContext,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  let mut previous_root : (@representation.CodeSite, @lib.Instruction)? = None
  let mut before_previous_root : (@representation.CodeSite, @lib.Instruction)? = None
  for original in instrs {
    let ordinal = ctx.cursor.val
    if ordinal < 0 || ordinal >= ctx.sites.length() {
      out.push(original)
      continue
    }
    let offset = ctx.sites[ordinal].0
    ctx.cursor.val += 1
    let site = @representation.CodeSite::new(ctx.function, offset)
    let current = compiler_fact_rewrite_nested_instruction(original, ctx)
    let mut rewritten = false
    match current {
      @lib.CallRef(_) | @lib.ReturnCallRef(_) => {
        let target_value = match previous_root {
          Some((previous_site, previous_instruction)) =>
            match
              compiler_fact_materializer_result_arity(
                previous_instruction,
                ctx.query.env,
              ) {
              Some(arity) if arity > 0U =>
                Some(
                  (
                    @representation.ValueSite::new(
                      previous_site,
                      result=arity - 1U,
                    ),
                    previous_instruction,
                  ),
                )
              _ => None
            }
          None => None
        }
        let target = ctx.query.exact_call_target(
          ctx.function,
          site,
          current,
          target=target_value,
        )
        match target {
          Some(raw_target) => {
            ctx.stats.candidate_rewrites += 1
            let replacement = directize_exact_ref_call_replacement(
              ctx.query.env,
              current,
              @lib.FuncIdx::new(raw_target),
            )
            match replacement {
              Some(replacement) => {
                for instruction in replacement {
                  out.push(instruction)
                }
                ctx.stats.exact_call_target_facts_accepted += 1
                if current is @lib.ReturnCallRef(_) {
                  ctx.stats.return_call_ref_converted += 1
                } else {
                  ctx.stats.call_ref_converted += 1
                }
                rewritten = true
              }
              None => ctx.stats.structurally_incompatible_rejected += 1
            }
          }
          None => ()
        }
      }
      @lib.I32Eqz | @lib.I64Eqz =>
        match previous_root {
          Some(root) => {
            let expected = if current is @lib.I32Eqz {
              @lib.ValType::i32()
            } else {
              @lib.ValType::i64()
            }
            let (domain, used_fact) = compiler_fact_integer_operand_domain(
              ctx, root, expected,
            )
            match domain {
              Some(domain) if used_fact => {
                ctx.stats.candidate_rewrites += 1
                let zero = compiler_fact_integer_domain_exact(domain.width, 0UL)
                let truth = compiler_fact_relation_equal(domain, zero)
                if compiler_fact_push_folded_predicate(out, 1, truth) {
                  ctx.stats.integer_zero_checks_folded += 1
                  rewritten = true
                } else {
                  ctx.stats.valid_facts_without_rewrite += 1
                }
              }
              _ => ()
            }
          }
          None => ()
        }
      @lib.RefIsNull =>
        match previous_root {
          Some(root) =>
            match
              compiler_fact_query_single_result_type(root.1, ctx.query.env) {
              Some(expected) => {
                let truth = ctx.query.null_test(
                  ctx.function,
                  @representation.ValueSite::new(root.0),
                  root.1,
                  expected,
                )
                if truth != FactUnknown {
                  ctx.stats.candidate_rewrites += 1
                  if compiler_fact_push_folded_predicate(out, 1, truth) {
                    ctx.stats.reference_null_checks_folded += 1
                    rewritten = true
                  }
                }
              }
              None => ctx.stats.type_mismatches += 1
            }
          None => ()
        }
      _ =>
        match compiler_fact_compare_expected_type(current) {
          Some(expected) =>
            match (before_previous_root, previous_root) {
              (Some(left_root), Some(right_root)) => {
                let (left, left_fact) = compiler_fact_integer_operand_domain(
                  ctx, left_root, expected,
                )
                let (right, right_fact) = compiler_fact_integer_operand_domain(
                  ctx, right_root, expected,
                )
                match (left, right) {
                  (Some(left), Some(right)) if left_fact || right_fact => {
                    ctx.stats.candidate_rewrites += 1
                    let truth = compiler_fact_relation_for_instruction(
                      current, left, right,
                    )
                    if compiler_fact_push_folded_predicate(out, 2, truth) {
                      ctx.stats.integer_comparisons_folded += 1
                      rewritten = true
                    } else {
                      ctx.stats.valid_facts_without_rewrite += 1
                    }
                  }
                  _ => ()
                }
              }
              _ => ()
            }
          None => ()
        }
    }
    if !rewritten {
      out.push(current)
    }
    before_previous_root = previous_root
    previous_root = Some((site, original))
  }
  out
}

///|
fn apply_compiler_facts_trusted(
  module_ : @lib.Module,
  version : UInt,
  index : CompilerFactIndex,
  stats : CompilerFactMaterializationStats,
) -> Result[@lib.Module, String] {
  let functions = match module_.code_sec {
    Some(@lib.CodeSec(functions)) => functions
    None => return Ok(module_.without_compiler_fact_custom_section())
  }
  let sites = match @binary.compiler_fact_module_opcode_sites(module_) {
    Ok(sites) => sites
    Err(err) => {
      stats.stale_or_unresolved_sites += 1
      return Err("apply-compiler-facts could not index opcode sites: \{err}")
    }
  }
  let imported = directize_imported_func_count(module_)
  let query = CompilerFactQuery::new(
    module_,
    version,
    CompilerFactUsePolicy::trust_assertions(),
    index,
    sites,
    stats,
  )
  let rewritten : Array[@lib.Func] = []
  for defined = 0; defined < functions.length(); defined = defined + 1 {
    let function = functions[defined]
    let @lib.Func(locals, @lib.Expr(body)) = function
    let absolute = (imported + defined).reinterpret_as_uint()
    if index.body_facts(@lib.FuncIdx::new(absolute)) is None {
      rewritten.push(function)
      continue
    }
    let cursor = Ref::new(0)
    let context = {
      function: absolute,
      sites: sites[defined],
      cursor,
      query,
      stats,
    }
    rewritten.push(
      @lib.Func::new(
        locals,
        @lib.Expr::new(compiler_fact_rewrite_region(body, context)),
      ),
    )
  }
  Ok(
    module_
    .with_code_sec(@lib.CodeSec::new(rewritten))
    .without_compiler_fact_custom_section(),
  )
}

///|
fn compiler_fact_record_inventory(
  facts : @representation.OptimizationFactsSec,
  stats : CompilerFactMaterializationStats,
) -> Int {
  stats.function_bodies_with_facts = facts.bodies.length()
  stats.function_facts_seen = facts.functions.length()
  stats.signature_facts_seen = facts.signatures.length()
  stats.type_facts_seen = facts.types.length()
  stats.global_facts_seen = facts.globals.length()
  stats.table_facts_seen = facts.tables.length()
  stats.hint_facts_seen = facts.hints.length()
  let mut assertions = facts.signatures.length() +
    facts.types.length() +
    facts.globals.length() +
    facts.tables.length()
  let mut hints = facts.hints.length()
  for function in facts.functions {
    if function.effects is Some(_) ||
      function.parameters.length() > 0 ||
      function.results.length() > 0 ||
      function.boundary is Some(_) {
      assertions += 1
    }
    if function.profile is Some(_) || function.inline_policy is Some(_) {
      hints += 1
    }
  }
  for body in facts.bodies {
    stats.value_facts_seen += body.sites.length()
    stats.relation_facts_seen += body.relations.length()
    stats.call_facts_seen += body.calls.length()
    stats.branch_facts_seen += body.branches.length()
    stats.loop_facts_seen += body.loops.length()
    stats.allocation_facts_seen += body.allocations.length()
    stats.access_facts_seen += body.accesses.length()
    stats.numeric_operation_facts_seen += body.numeric_operations.length()
    assertions += body.sites.length() +
      body.relations.length() +
      body.allocations.length() +
      body.accesses.length() +
      body.numeric_operations.length()
    for call in body.calls {
      if call.direct_target is Some(_) {
        assertions += 1
      }
      if call.profile is Some(_) || call.inline_policy is Some(_) {
        hints += 1
      }
    }
    hints += body.branches.length() + body.loops.length()
  }
  stats.hint_facts_seen = hints
  assertions
}

///|
fn compiler_fact_count_invalid_top_level_indices(
  facts : @representation.OptimizationFactsSec,
  env : @validate.Env,
) -> Int {
  let mut invalid = 0
  for value in facts.functions {
    if !env.has_func(@lib.FuncIdx::new(value.function)) {
      invalid += 1
    }
  }
  for value in facts.bodies {
    if !env.has_func(@lib.FuncIdx::new(value.function)) {
      invalid += 1
    }
  }
  for value in facts.signatures {
    if value.signature >= env.global_types.length().reinterpret_as_uint() {
      invalid += 1
    }
  }
  for value in facts.types {
    if value.type_ >= env.global_types.length().reinterpret_as_uint() {
      invalid += 1
    }
  }
  for value in facts.globals {
    if env.get_global_type(@lib.GlobalIdx::new(value.global)) is None {
      invalid += 1
    }
  }
  for value in facts.tables {
    if env.get_table_type(@lib.TableIdx::new(value.table)) is None {
      invalid += 1
    }
  }
  invalid + compiler_fact_query_invalid_resource_indices(facts, env)
}

///|
pub fn apply_compiler_facts(
  module_ : @lib.Module,
  policy : CompilerFactUsePolicy,
) -> Result[ApplyCompilerFactsResult, String] {
  let stats = CompilerFactMaterializationStats::new()
  let section = match module_.compiler_fact_custom_section {
    Some(section) => section
    None => return Ok({ module_, stats, })
  }
  stats.fact_sections_seen = 1
  let assertion_count = compiler_fact_record_inventory(section.facts, stats)
  match policy {
    IgnoreFacts | HintsOnly => {
      stats.hint_only_facts = stats.hint_facts_seen
      stats.facts_blocked_by_trust = assertion_count
      let env = @validate.Env::new().with_module(module_)
      let index = compiler_fact_index_bounded(section.facts, env)
      stats.exact_call_target_facts_seen = compiler_fact_count_exact_targets(
        index,
      )
      stats.ignored_untrusted_assertions = stats.exact_call_target_facts_seen
      return Ok({ module_, stats })
    }
    TrustAssertions => stats.trusted_assertion_facts = assertion_count
  }
  if section.version != 1U {
    stats.unsupported_versions = 1
    return Ok({ module_, stats })
  }
  let env = @validate.Env::new().with_module(module_)
  stats.invalid_referenced_indices = compiler_fact_count_invalid_top_level_indices(
    section.facts,
    env,
  )
  if stats.invalid_referenced_indices > 0 {
    return Ok({ module_, stats })
  }
  let imported = directize_imported_func_count(module_)
  let defined = match module_.code_sec {
    Some(@lib.CodeSec(functions)) => functions.length()
    None => 0
  }
  for body in section.facts.bodies {
    let function = body.function.reinterpret_as_int()
    if function < imported || function >= imported + defined {
      stats.stale_or_unresolved_sites += 1
    }
  }
  let index = compiler_fact_index_bounded(section.facts, env)
  stats.exact_call_target_facts_seen = compiler_fact_count_exact_targets(index)
  match apply_compiler_facts_trusted(module_, section.version, index, stats) {
    Ok(module_) => Ok({ module_, stats })
    Err(err) => Err(err)
  }
}

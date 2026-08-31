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
  mut exact_call_target_facts_seen : Int
  mut exact_call_target_facts_accepted : Int
  mut call_ref_converted : Int
  mut return_call_ref_converted : Int
  mut structurally_incompatible_rejected : Int
  mut ignored_untrusted_assertions : Int
} derive(Eq, Debug)

///|
pub fn CompilerFactMaterializationStats::new() -> CompilerFactMaterializationStats {
  {
    fact_sections_seen: 0,
    exact_call_target_facts_seen: 0,
    exact_call_target_facts_accepted: 0,
    call_ref_converted: 0,
    return_call_ref_converted: 0,
    structurally_incompatible_rejected: 0,
    ignored_untrusted_assertions: 0,
  }
}

///|
pub struct ApplyCompilerFactsResult {
  module_ : @lib.Module
  stats : CompilerFactMaterializationStats
} derive(Debug)

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
  let functions = Array::make(
    compiler_fact_index_size_from_uints(function_indices),
    None,
  )
  let bodies = Array::make(functions.length(), None)
  for value in facts.functions {
    functions[value.function.reinterpret_as_int()] = Some(value)
  }
  for value in facts.bodies {
    bodies[value.function.reinterpret_as_int()] = Some(value)
  }

  let signature_indices : Array[UInt] = []
  for value in facts.signatures {
    signature_indices.push(value.signature)
  }
  let signatures = Array::make(
    compiler_fact_index_size_from_uints(signature_indices),
    None,
  )
  for value in facts.signatures {
    signatures[value.signature.reinterpret_as_int()] = Some(value)
  }

  let type_indices : Array[UInt] = []
  for value in facts.types {
    type_indices.push(value.type_)
  }
  let types = Array::make(
    compiler_fact_index_size_from_uints(type_indices),
    None,
  )
  for value in facts.types {
    types[value.type_.reinterpret_as_int()] = Some(value)
  }

  let global_indices : Array[UInt] = []
  for value in facts.globals {
    global_indices.push(value.global)
  }
  let globals = Array::make(
    compiler_fact_index_size_from_uints(global_indices),
    None,
  )
  for value in facts.globals {
    globals[value.global.reinterpret_as_int()] = Some(value)
  }

  let table_indices : Array[UInt] = []
  for value in facts.tables {
    table_indices.push(value.table)
  }
  let tables = Array::make(
    compiler_fact_index_size_from_uints(table_indices),
    None,
  )
  for value in facts.tables {
    tables[value.table.reinterpret_as_int()] = Some(value)
  }

  { facts, functions, bodies, signatures, types, globals, tables }
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
  index : CompilerFactIndex
  env : @validate.Env
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
fn compiler_fact_rewrite_region(
  instrs : Array[@lib.Instruction],
  ctx : CompilerFactRewriteContext,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  let mut previous_root : (@representation.CodeSite, @lib.Instruction)? = None
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
    match current {
      @lib.CallRef(_) | @lib.ReturnCallRef(_) => {
        let target_value_site = match previous_root {
          Some((previous_site, previous_instruction)) =>
            match
              compiler_fact_materializer_result_arity(
                previous_instruction,
                ctx.env,
              ) {
              Some(arity) if arity > 0U =>
                Some(
                  @representation.ValueSite::new(
                    previous_site,
                    result=arity - 1U,
                  ),
                )
              _ => None
            }
          None => None
        }
        let target = ctx.index.compiler_fact_exact_call_target(
          site,
          target_value_site~,
        )
        match target {
          Some(raw_target) => {
            let replacement = directize_exact_ref_call_replacement(
              ctx.env,
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
              }
              None => {
                ctx.stats.structurally_incompatible_rejected += 1
                out.push(current)
              }
            }
          }
          None => out.push(current)
        }
      }
      _ => out.push(current)
    }
    previous_root = Some((site, original))
  }
  out
}

///|
fn apply_compiler_facts_trusted(
  module_ : @lib.Module,
  index : CompilerFactIndex,
  stats : CompilerFactMaterializationStats,
) -> Result[@lib.Module, String] {
  let functions = match module_.code_sec {
    Some(@lib.CodeSec(functions)) => functions
    None => return Ok(module_.without_compiler_fact_custom_section())
  }
  let sites = match @binary.compiler_fact_module_opcode_sites(module_) {
    Ok(sites) => sites
    Err(err) =>
      return Err("apply-compiler-facts could not index opcode sites: \{err}")
  }
  let imported = directize_imported_func_count(module_)
  let env = @validate.Env::new().with_module(module_)
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
      index,
      env,
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
pub fn apply_compiler_facts(
  module_ : @lib.Module,
  policy : CompilerFactUsePolicy,
) -> Result[ApplyCompilerFactsResult, String] {
  let stats = CompilerFactMaterializationStats::new()
  let section = match module_.compiler_fact_custom_section {
    Some(section) => section
    None => return Ok({ module_, stats })
  }
  stats.fact_sections_seen = 1
  let index = CompilerFactIndex::new(section.facts)
  stats.exact_call_target_facts_seen = compiler_fact_count_exact_targets(index)
  match policy {
    IgnoreFacts | HintsOnly => {
      stats.ignored_untrusted_assertions = stats.exact_call_target_facts_seen
      Ok({ module_, stats })
    }
    TrustAssertions =>
      match apply_compiler_facts_trusted(module_, index, stats) {
        Ok(module_) => Ok({ module_, stats })
        Err(err) => Err(err)
      }
  }
}

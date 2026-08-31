///|
fn[T : Validate] validate_compiler_fact_option(
  value : T?,
  env : Env,
) -> Result[Unit, String] {
  match value {
    Some(value) => Validate::validate(value, env)
    None => Ok(())
  }
}

///|
fn validate_compiler_fact_function_index(
  index : UInt,
  env : Env,
) -> Result[Unit, String] {
  if env.has_func(FuncIdx::new(index)) {
    Ok(())
  } else {
    Err(
      "compiler facts function index out of range: function=\{index} total_functions=\{env.funcs.length()}",
    )
  }
}

///|
fn validate_compiler_fact_type_index(
  index : UInt,
  env : Env,
) -> Result[Unit, String] {
  if index < env.global_types.length().reinterpret_as_uint() {
    Ok(())
  } else {
    Err(
      "compiler facts type index out of range: type=\{index} total_types=\{env.global_types.length()}",
    )
  }
}

///|
fn validate_compiler_fact_global_index(
  index : UInt,
  env : Env,
) -> Result[Unit, String] {
  if env.get_global_type(GlobalIdx::new(index)) is Some(_) {
    Ok(())
  } else {
    Err(
      "compiler facts global index out of range: global=\{index} total_globals=\{env.globals.length()}",
    )
  }
}

///|
fn validate_compiler_fact_memory_index(
  index : UInt,
  env : Env,
) -> Result[Unit, String] {
  if env.get_memtype(MemIdx::new(index)) is Some(_) {
    Ok(())
  } else {
    Err(
      "compiler facts memory index out of range: memory=\{index} total_memories=\{env.mems.length()}",
    )
  }
}

///|
fn validate_compiler_fact_table_index(
  index : UInt,
  env : Env,
) -> Result[Unit, String] {
  if env.get_table_type(TableIdx::new(index)) is Some(_) {
    Ok(())
  } else {
    Err(
      "compiler facts table index out of range: table=\{index} total_tables=\{env.tables.length()}",
    )
  }
}

///|
fn validate_compiler_fact_closed_set(
  values : Array[UInt],
  validate_index : (UInt) -> Result[Unit, String],
  label : String,
) -> Result[Unit, String] {
  let mut previous : UInt? = None
  for value in values {
    match previous {
      Some(prev) if value <= prev =>
        return Err("compiler facts \{label} must be sorted and duplicate-free")
      _ => ()
    }
    if validate_index(value) is Err(err) {
      return Err(err)
    }
    previous = Some(value)
  }
  Ok(())
}

///|
pub impl Validate for CompilerFactCustomSection with fn validate(value, env) {
  if value.version != 1U {
    return Err(
      "unsupported compiler facts version: version=\{value.version} supported=1",
    )
  }
  // Fingerprints are intentionally opaque bytes in version 1; no width is fixed.
  Validate::validate(value.facts, env)
}

///|
pub impl Validate for OptimizationFactsSec with fn validate(value, env) {
  let seen_functions = Array::make(env.funcs.length(), false)
  for facts in value.functions {
    let index = facts.function.reinterpret_as_int()
    if index >= 0 && index < seen_functions.length() && seen_functions[index] {
      return Err("duplicate function facts record: function=\{facts.function}")
    }
    if Validate::validate(facts, env) is Err(err) {
      return Err(err)
    }
    if index >= 0 && index < seen_functions.length() {
      seen_functions[index] = true
    }
  }
  let seen_bodies = Array::make(env.funcs.length(), false)
  for body in value.bodies {
    let index = body.function.reinterpret_as_int()
    if index >= 0 && index < seen_bodies.length() && seen_bodies[index] {
      return Err(
        "duplicate function body facts record: function=\{body.function}",
      )
    }
    if Validate::validate(body, env) is Err(err) {
      return Err(err)
    }
    if index >= 0 && index < seen_bodies.length() {
      seen_bodies[index] = true
    }
  }
  Ok(())
}

///|
pub impl Validate for FunctionFacts with fn validate(value, env) {
  if validate_compiler_fact_function_index(value.function, env) is Err(err) {
    return Err(err)
  }
  let FuncType(parameters, results) = match
    env.get_functype_by_funcidx(FuncIdx::new(value.function)) {
    Some(func_type) => func_type
    None => return Err("compiler facts function index has no function type")
  }
  if validate_compiler_fact_option(value.effects, env) is Err(err) {
    return Err(err)
  }
  let seen_parameters = Array::make(parameters.length(), false)
  for parameter in value.parameters {
    if Validate::validate(parameter, env) is Err(err) {
      return Err(err)
    }
    let index = parameter.parameter.reinterpret_as_int()
    if index < 0 || index >= parameters.length() {
      return Err(
        "compiler facts parameter index out of range: function=\{value.function} parameter=\{parameter.parameter} total_parameters=\{parameters.length()}",
      )
    }
    if seen_parameters[index] {
      return Err(
        "duplicate compiler facts parameter record: function=\{value.function} parameter=\{parameter.parameter}",
      )
    }
    seen_parameters[index] = true
  }
  let seen_results = Array::make(results.length(), false)
  for result in value.results {
    if Validate::validate(result, env) is Err(err) {
      return Err(err)
    }
    let index = result.result.reinterpret_as_int()
    if index < 0 || index >= results.length() {
      return Err(
        "compiler facts result index out of range: function=\{value.function} result=\{result.result} total_results=\{results.length()}",
      )
    }
    if seen_results[index] {
      return Err(
        "duplicate compiler facts result record: function=\{value.function} result=\{result.result}",
      )
    }
    seen_results[index] = true
    match result.identity {
      Some(SameAsParameter(parameter)) if parameter >=
        parameters.length().reinterpret_as_uint() =>
        return Err(
          "compiler facts identity parameter index out of range: function=\{value.function} parameter=\{parameter} total_parameters=\{parameters.length()}",
        )
      _ => ()
    }
  }
  if validate_compiler_fact_option(value.boundary, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.profile, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.inline_policy, env)
}

///|
pub impl Validate for EffectFacts with fn validate(value, env) {
  if Validate::validate(value.may, env) is Err(err) {
    return Err(err)
  }
  for set in [value.read_globals, value.written_globals] {
    if validate_compiler_fact_option(set, env) is Err(err) {
      return Err(err)
    }
  }
  for set in [value.read_memories, value.written_memories] {
    if validate_compiler_fact_option(set, env) is Err(err) {
      return Err(err)
    }
  }
  for set in [value.read_tables, value.written_tables] {
    if validate_compiler_fact_option(set, env) is Err(err) {
      return Err(err)
    }
  }
  for set in [value.read_heap_types, value.written_heap_types] {
    if validate_compiler_fact_option(set, env) is Err(err) {
      return Err(err)
    }
  }
  validate_compiler_fact_option(value.direct_callees, env)
}

///|
pub impl Validate for EffectMask with fn validate(value, _) {
  let unknown = value.bits() & UInt64::lnot(0x1FFFUL)
  if unknown == 0UL {
    Ok(())
  } else {
    Err("compiler facts effect mask contains undefined bits: \{unknown}")
  }
}

///|
pub impl Validate for ClosedGlobalSet with fn validate(value, env) {
  let @representation.ClosedGlobalSet(values) = value
  validate_compiler_fact_closed_set(
    values,
    fn(index) { validate_compiler_fact_global_index(index, env) },
    "closed global set",
  )
}

///|
pub impl Validate for ClosedMemorySet with fn validate(value, env) {
  let @representation.ClosedMemorySet(values) = value
  validate_compiler_fact_closed_set(
    values,
    fn(index) { validate_compiler_fact_memory_index(index, env) },
    "closed memory set",
  )
}

///|
pub impl Validate for ClosedTableSet with fn validate(value, env) {
  let @representation.ClosedTableSet(values) = value
  validate_compiler_fact_closed_set(
    values,
    fn(index) { validate_compiler_fact_table_index(index, env) },
    "closed table set",
  )
}

///|
pub impl Validate for ClosedTypeViewSet with fn validate(value, env) {
  let @representation.ClosedTypeViewSet(values) = value
  validate_compiler_fact_closed_set(
    values,
    fn(index) { validate_compiler_fact_type_index(index, env) },
    "closed type view set",
  )
}

///|
pub impl Validate for ClosedFunctionSet with fn validate(value, env) {
  let @representation.ClosedFunctionSet(values) = value
  validate_compiler_fact_closed_set(
    values,
    fn(index) { validate_compiler_fact_function_index(index, env) },
    "closed function set",
  )
}

///|
pub impl Validate for ParameterFacts with fn validate(value, env) {
  if validate_compiler_fact_option(value.value, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.uses, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.escape_sinks, env)
}

///|
pub impl Validate for ParameterUseMask with fn validate(value, _) {
  let unknown = value.bits() & UInt64::lnot(0x7FUL)
  if unknown == 0UL {
    Ok(())
  } else {
    Err("compiler facts parameter use mask contains undefined bits: \{unknown}")
  }
}

///|
pub impl Validate for EscapeSinkMask with fn validate(value, _) {
  let unknown = value.bits() & UInt64::lnot(0xFFUL)
  if unknown == 0UL {
    Ok(())
  } else {
    Err("compiler facts escape sink mask contains undefined bits: \{unknown}")
  }
}

///|
pub impl Validate for ResultFacts with fn validate(value, env) {
  if validate_compiler_fact_option(value.value, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.identity, env)
}

///|
pub impl Validate for ResultIdentityFacts with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for ValueFacts with fn validate(value, env) {
  match value.exact_heap_type {
    Some(index) =>
      if validate_compiler_fact_type_index(index, env) is Err(err) {
        return Err(err)
      }
    None => ()
  }
  match value.exact_call_target {
    Some(index) =>
      if validate_compiler_fact_function_index(index, env) is Err(err) {
        return Err(err)
      }
    None => ()
  }
  if validate_compiler_fact_option(value.signed_range, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.unsigned_range, env)
}

///|
pub impl Validate for SignedRange with fn validate(value, _) {
  if value.min <= value.max {
    Ok(())
  } else {
    Err(
      "compiler facts signed range has min greater than max: min=\{value.min} max=\{value.max}",
    )
  }
}

///|
pub impl Validate for UnsignedRange with fn validate(value, _) {
  if value.min <= value.max {
    Ok(())
  } else {
    Err(
      "compiler facts unsigned range has min greater than max: min=\{value.min} max=\{value.max}",
    )
  }
}

///|
pub impl Validate for FunctionBoundaryFacts with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for FunctionProfile with fn validate(value, env) {
  validate_compiler_fact_option(value.temperature, env)
}

///|
pub impl Validate for CallProfile with fn validate(value, env) {
  validate_compiler_fact_option(value.temperature, env)
}

///|
pub impl Validate for BranchProfile with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for LoopProfile with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for TemperatureHint with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for InlinePolicy with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for FunctionBodyFacts with fn validate(value, env) {
  if validate_compiler_fact_function_index(value.function, env) is Err(err) {
    return Err(err)
  }
  for site in value.sites {
    if site.function != value.function {
      return Err(
        "compiler facts expression site containing function mismatch: body=\{value.function} site=\{site.function}",
      )
    }
    if Validate::validate(site, env) is Err(err) {
      return Err(err)
    }
  }
  if Validate::validate(value.relations, env) is Err(err) {
    return Err(err)
  }
  for call in value.calls {
    if call.function != value.function {
      return Err(
        "compiler facts call site containing function mismatch: body=\{value.function} site=\{call.function}",
      )
    }
    if Validate::validate(call, env) is Err(err) {
      return Err(err)
    }
  }
  for branch in value.branches {
    if branch.function != value.function {
      return Err(
        "compiler facts branch site containing function mismatch: body=\{value.function} site=\{branch.function}",
      )
    }
    if Validate::validate(branch, env) is Err(err) {
      return Err(err)
    }
  }
  for loop_ in value.loops {
    if loop_.function != value.function {
      return Err(
        "compiler facts loop site containing function mismatch: body=\{value.function} site=\{loop_.function}",
      )
    }
    if Validate::validate(loop_, env) is Err(err) {
      return Err(err)
    }
  }
  for allocation in value.allocations {
    if allocation.function != value.function {
      return Err(
        "compiler facts allocation site containing function mismatch: body=\{value.function} site=\{allocation.function}",
      )
    }
    if Validate::validate(allocation, env) is Err(err) {
      return Err(err)
    }
  }
  Ok(())
}

///|
pub impl Validate for ExpressionFact with fn validate(value, env) {
  if validate_compiler_fact_function_index(value.function, env) is Err(err) {
    return Err(err)
  }
  Validate::validate(value.facts, env)
}

///|
pub impl Validate for Fact with fn validate(value, env) {
  match value {
    NonNull | DoesNotEscape | IdentityNotObserved => Ok(())
    ExactHeapType(index) => validate_compiler_fact_type_index(index, env)
    ExactCallTarget(index) => validate_compiler_fact_function_index(index, env)
    SignedRangeFact(min, max) =>
      Validate::validate(SignedRange::new(min, max), env)
    UnsignedRangeFact(min, max) =>
      Validate::validate(UnsignedRange::new(min, max), env)
  }
}

///|
pub impl Validate for FactSiteRef with fn validate(value, env) {
  validate_compiler_fact_function_index(value.function, env)
}

///|
pub impl Validate for FactRelation with fn validate(value, env) {
  let (left, right) = match value {
    SameValue(left, right)
    | SameIdentity(left, right)
    | DerivedFrom(left, right) => (left, right)
  }
  if Validate::validate(left, env) is Err(err) {
    return Err(err)
  }
  Validate::validate(right, env)
}

///|
pub impl Validate for CallSiteFacts with fn validate(value, env) {
  if validate_compiler_fact_function_index(value.function, env) is Err(err) {
    return Err(err)
  }
  match value.direct_target {
    Some(index) =>
      if validate_compiler_fact_function_index(index, env) is Err(err) {
        return Err(err)
      }
    None => ()
  }
  if validate_compiler_fact_option(value.profile, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.inline_policy, env)
}

///|
pub impl Validate for BranchFacts with fn validate(value, env) {
  if validate_compiler_fact_function_index(value.function, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.profile, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.temperature, env)
}

///|
pub impl Validate for LoopFacts with fn validate(value, env) {
  if validate_compiler_fact_function_index(value.function, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.profile, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.temperature, env)
}

///|
pub impl Validate for AllocationSiteFacts with fn validate(value, env) {
  if validate_compiler_fact_function_index(value.function, env) is Err(err) {
    return Err(err)
  }
  match value.heap_type {
    Some(index) => validate_compiler_fact_type_index(index, env)
    None => Ok(())
  }
}

///|
fn module_has_compiler_fact_metadata(module_ : Module) -> Bool {
  if module_.compiler_fact_custom_section is Some(_) {
    return true
  }
  module_.custom_secs.any(fn(custom) {
    let CustomSec(name, _) = custom
    name == Name::new("compiler.facts")
  })
}

///|
priv struct CompilerFactOpcodeIndex {
  imported_functions : Int
  defined_offsets : Array[Array[UInt]]
}

///|
fn compiler_fact_opcode_index(
  module_ : Module,
  imported_functions : Int,
) -> Result[CompilerFactOpcodeIndex, String] {
  match @binary.compiler_fact_module_opcode_offsets(module_) {
    Ok(defined_offsets) => Ok({ imported_functions, defined_offsets })
    Err(err) =>
      Err(
        "compiler facts could not index encoded function instructions: \{err}",
      )
  }
}

///|
fn validate_compiler_fact_instruction_site(
  index : CompilerFactOpcodeIndex,
  function : UInt,
  offset : UInt,
  kind : String,
) -> Result[Unit, String] {
  let absolute = function.reinterpret_as_int()
  let defined = absolute - index.imported_functions
  if defined < 0 || defined >= index.defined_offsets.length() {
    return Err(
      "compiler facts instruction site has no defined function body: kind=\{kind} function=\{function} offset=\{offset}",
    )
  }
  if index.defined_offsets[defined].any(fn(candidate) { candidate == offset }) {
    Ok(())
  } else {
    Err(
      "compiler facts instruction site does not exist: kind=\{kind} function=\{function} offset=\{offset}",
    )
  }
}

///|
fn validate_compiler_fact_body_sites(
  facts : OptimizationFactsSec,
  index : CompilerFactOpcodeIndex,
) -> Result[Unit, String] {
  for body in facts.bodies {
    let body_function = body.function.reinterpret_as_int()
    let defined = body_function - index.imported_functions
    if defined < 0 || defined >= index.defined_offsets.length() {
      return Err(
        "compiler facts function body record has no defined function body: function=\{body.function}",
      )
    }
    for site in body.sites {
      if validate_compiler_fact_instruction_site(
          index,
          site.function,
          site.offset,
          "expression",
        )
        is Err(err) {
        return Err(err)
      }
    }
    for relation in body.relations {
      let (left, right) = match relation {
        SameValue(left, right)
        | SameIdentity(left, right)
        | DerivedFrom(left, right) => (left, right)
      }
      if validate_compiler_fact_instruction_site(
          index,
          left.function,
          left.offset,
          "relation-left",
        )
        is Err(err) {
        return Err(err)
      }
      if validate_compiler_fact_instruction_site(
          index,
          right.function,
          right.offset,
          "relation-right",
        )
        is Err(err) {
        return Err(err)
      }
    }
    for call in body.calls {
      if validate_compiler_fact_instruction_site(
          index,
          call.function,
          call.offset,
          "call",
        )
        is Err(err) {
        return Err(err)
      }
    }
    for branch in body.branches {
      if validate_compiler_fact_instruction_site(
          index,
          branch.function,
          branch.offset,
          "branch",
        )
        is Err(err) {
        return Err(err)
      }
    }
    for loop_ in body.loops {
      if validate_compiler_fact_instruction_site(
          index,
          loop_.function,
          loop_.offset,
          "loop",
        )
        is Err(err) {
        return Err(err)
      }
    }
    for allocation in body.allocations {
      if validate_compiler_fact_instruction_site(
          index,
          allocation.function,
          allocation.offset,
          "allocation",
        )
        is Err(err) {
        return Err(err)
      }
    }
  }
  Ok(())
}

///|
fn validate_compiler_fact_module_section(
  module_ : Module,
  env : Env,
  imported_functions : Int,
) -> Result[Unit, String] {
  for custom in module_.custom_secs {
    let CustomSec(name, _) = custom
    if name == Name::new("compiler.facts") {
      return Err(
        "reserved compiler.facts custom section must use Module.compiler_fact_custom_section",
      )
    }
  }
  match module_.compiler_fact_custom_section {
    Some(section) => {
      if Validate::validate(section, env) is Err(err) {
        return Err(err)
      }
      let index = match
        compiler_fact_opcode_index(module_, imported_functions) {
        Ok(index) => index
        Err(err) => return Err(err)
      }
      validate_compiler_fact_body_sites(section.facts, index)
    }
    None => Ok(())
  }
}

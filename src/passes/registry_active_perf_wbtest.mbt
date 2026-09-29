///|
fn registry_active_fixture(name : String, count : Int) -> @lib.Module {
  let seed = match name {
    "constraint-analysis" =>
      pass_test_module_from_wat(
        "(module (func (param i32) (result i32) local.get 0 i32.const 10 i32.eq if (result i32) local.get 0 i32.const 0 i32.ne else i32.const 7 end))",
      )
    "coalesce-locals-cfg" =>
      pass_test_module_from_wat(
        "(module (func (param i32) (result i32) (local i32 i32) local.get 0 local.set 1 local.get 1 local.set 2 loop local.get 2 local.set 1 end local.get 1))",
      )
    "merge-locals" =>
      pass_test_module_from_wat(
        "(module (func (result i32) (local i32 i32) i32.const 1 local.set 0 local.get 0 local.set 1 local.get 0 local.get 1 i32.add))",
      )
    _ => pass_test_module_from_wat("(module (func (result i32) i32.const 7))")
  }
  seed
  .with_func_sec(
    @lib.FuncSec::new(Array::make(count, seed.func_sec.unwrap().0[0])),
  )
  .with_code_sec(
    @lib.CodeSec::new(Array::make(count, seed.code_sec.unwrap().0[0])),
  )
}

///|
fn registry_active_bench(it : @bench.T, name : String, count : Int) -> Unit {
  let input = registry_active_fixture(name, count)
  @validate.validate_module(input).unwrap()
  let flag = if name == "no-inline" ||
    name == "no-full-inline" ||
    name == "no-partial-inline" {
    name + "=*"
  } else {
    name
  }
  let options = HotPipelineOptions::new(validate_final_module=false)
  let output = run_hot_pipeline(input, options, [flag]).unwrap()
  @validate.validate_module(output).unwrap()
  if name == "no-inline" ||
    name == "no-full-inline" ||
    name == "no-partial-inline" {
    let (full, partial) = no_inline_policy_flags(output)
    if full.length() != count ||
      partial.length() != count ||
      full.any(fn(value) { value != (name != "no-partial-inline") }) ||
      partial.any(fn(value) { value != (name != "no-full-inline") }) ||
      input.func_annotation_sec is Some(_) {
      abort(
        "registry policy benchmark did not annotate every intended function",
      )
    }
  } else if @binary.encode_module(output).unwrap() ==
    @binary.encode_module(input).unwrap() {
    abort("registry benchmark did not trigger its pass")
  }
  if name == "constraint-analysis" &&
    ca_test_opcode_count(output, @lib.Instruction::i32_ne()) != 0 {
    abort("constraint-analysis did not fold the constrained comparison")
  }
  if name == "merge-locals" {
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    if !body.contains(@lib.Instruction::local_get(@lib.LocalIdx::new(1U))) {
      abort("merge-locals lost the destination value")
    }
  }
  it.bench(fn() { it.keep(run_hot_pipeline(input, options, [flag])) })
}

///|
fn registry_active_stable_import_bench(it : @bench.T, count : Int) -> Unit {
  let wat : Array[String] = ["(module (type $sig (func))"]
  for _ in 0..<count {
    wat.push("(import \"env\" \"shared\" (func (type $sig)))")
  }
  wat.push("(func (export \"run\") call 0 call 1))")
  let input = pass_test_module_from_wat(wat.join(""))
  let options = HotPipelineOptions::new(validate_final_module=false)
  let output = run_hot_pipeline(input, options, [
    "duplicate-import-elimination-assume-stable-bindings",
  ]).unwrap()
  @validate.validate_module(output).unwrap()
  if output.import_sec.unwrap().0.length() != 1 {
    abort("stable import benchmark did not merge bindings")
  }
  it.bench(fn() {
    it.keep(
      run_hot_pipeline(input, options, [
        "duplicate-import-elimination-assume-stable-bindings",
      ]),
    )
  })
}

///|
fn registry_active_compiler_facts_bench(it : @bench.T) -> Unit {
  let input = pass_test_module_from_wat(
    "(module (type $sig (func (param i32) (result i32))) (func $helper (type $sig) local.get 0) (elem declare func $helper) (func (export \"run\") (result i32) i32.const 7 ref.func $helper call_ref $sig))",
  )
  let sites = @binary.compiler_fact_module_opcode_sites(input).unwrap()[1]
  let mut site = None
  for (offset, instruction) in sites {
    if instruction is @lib.CallRef(_) {
      site = Some(@representation.CodeSite::new(1U, offset))
    }
  }
  let input = input.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(bodies=[
        @representation.FunctionBodyFacts::new(1U, calls=[
          @representation.CallSiteFacts::new(
            site.unwrap(),
            direct_target=Some(0U),
          ),
        ]),
      ]),
    ),
  )
  let options = HotPipelineOptions::new(
    validate_final_module=false,
    compiler_fact_policy=CompilerFactUsePolicy::trust_assertions(),
  )
  let output = run_hot_pipeline(input, options, ["apply-compiler-facts"]).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  if !body.contains(@lib.Instruction::call(@lib.FuncIdx::new(0U))) ||
    body.contains(@lib.Instruction::call_ref(@lib.TypeIdx::new(0U))) {
    abort("compiler facts benchmark did not directize the exact target")
  }
  it.bench(fn() {
    it.keep(run_hot_pipeline(input, options, ["apply-compiler-facts"]))
  })
}

///|
test "bench active registry constraint-analysis functions=16" (it : @bench.T) {
  registry_active_bench(it, "constraint-analysis", 16)
}

///|
test "bench active registry constraint-analysis functions=128" (it : @bench.T) {
  registry_active_bench(it, "constraint-analysis", 128)
}

///|
test "bench active registry merge-locals functions=16" (it : @bench.T) {
  registry_active_bench(it, "merge-locals", 16)
}

///|
test "bench active registry merge-locals functions=128" (it : @bench.T) {
  registry_active_bench(it, "merge-locals", 128)
}

///|
test "bench active registry no-inline functions=16" (it : @bench.T) {
  registry_active_bench(it, "no-inline", 16)
}

///|
test "bench active registry no-inline functions=128" (it : @bench.T) {
  registry_active_bench(it, "no-inline", 128)
}

///|
test "bench active registry no-full-inline functions=16" (it : @bench.T) {
  registry_active_bench(it, "no-full-inline", 16)
}

///|
test "bench active registry no-full-inline functions=128" (it : @bench.T) {
  registry_active_bench(it, "no-full-inline", 128)
}

///|
test "bench active registry no-partial-inline functions=16" (it : @bench.T) {
  registry_active_bench(it, "no-partial-inline", 16)
}

///|
test "bench active registry no-partial-inline functions=128" (it : @bench.T) {
  registry_active_bench(it, "no-partial-inline", 128)
}

///|
test "bench active registry stable import bindings imports=16" (it : @bench.T) {
  registry_active_stable_import_bench(it, 16)
}

///|
test "bench active registry stable import bindings imports=128" (it : @bench.T) {
  registry_active_stable_import_bench(it, 128)
}

///|
test "bench active registry apply compiler facts" (it : @bench.T) {
  registry_active_compiler_facts_bench(it)
}

///|
fn registry_active_dae_alias_bench(it : @bench.T, count : Int) -> Unit {
  let wat : Array[String] = [
    "(module (func $helper (param i32) (result i32) i32.const 7) (func (export \"run\")",
  ]
  for _ in 0..<count {
    wat.push("i32.const 9 call $helper drop ")
  }
  wat.push("))")
  let input = pass_test_module_from_wat(wat.join(""))
  let options = HotPipelineOptions::new(validate_final_module=false)
  let name = "dead-argument-elimination-optimizing"
  let output = run_hot_pipeline(input, options, [name]).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.FuncType(params, _) = @validate.Env::new()
    .with_module(output)
    .get_functype_by_funcidx(@lib.FuncIdx::new(0U))
    .unwrap()
  if params.length() != 0 {
    abort("DAEO alias benchmark kept the unused parameter")
  }
  it.bench(fn() { it.keep(run_hot_pipeline(input, options, [name])) })
}

///|
test "bench active registry coalesce-locals-cfg functions=16" (it : @bench.T) {
  registry_active_bench(it, "coalesce-locals-cfg", 16)
}

///|
test "bench active registry DAEO alias calls=16" (it : @bench.T) {
  registry_active_dae_alias_bench(it, 16)
}

///|
test "bench active registry coalesce-locals-cfg functions=128" (it : @bench.T) {
  registry_active_bench(it, "coalesce-locals-cfg", 128)
}

///|
test "bench active registry DAEO alias calls=128" (it : @bench.T) {
  registry_active_dae_alias_bench(it, 128)
}

///|
test "bench active registry inline-main named wrapper" (it : @bench.T) {
  let input = pass_test_module_from_wat(
    "(module (func $__original_main (result i32) i32.const 7) (func $main (export \"main\") (result i32) call $__original_main))",
  )
  let options = HotPipelineOptions::new(validate_final_module=false)
  let output = run_hot_pipeline(input, options, ["inline-main"]).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  if body != [@lib.Instruction::i32_const(@lib.I32(7))] ||
    output.code_sec.unwrap().0.length() != 2 {
    abort("named main benchmark changed helper retention or failed to inline")
  }
  it.bench(fn() { it.keep(run_hot_pipeline(input, options, ["inline-main"])) })
}

///|
fn registry_active_handler_bench(it : @bench.T, count : Int) -> Unit {
  let wat : Array[String] = ["(module (tag $e)"]
  for _ in 0..<count {
    wat.push(
      "(func (param i32) (result i32) (local i32 i32 i32) local.get 0 local.set 1 i32.const 5 local.set 3 block $catch try_table (catch $e $catch) local.get 0 if i32.const 10 local.set 2 throw $e end end end local.get 1 local.get 2 i32.add)",
    )
  }
  wat.push(")")
  let input = pass_test_module_from_wat(wat.join(""))
  @validate.validate_module(input).unwrap()
  let original = @binary.encode_module(input).unwrap()
  let options = HotPipelineOptions::new(validate_final_module=false)
  let output = run_hot_pipeline(input, options, ["coalesce-locals"]).unwrap()
  @validate.validate_module(output).unwrap()
  if @binary.encode_module(output).unwrap().length() >= original.length() ||
    @binary.encode_module(input).unwrap() != original {
    abort(
      "handler benchmark did not reduce copy traffic with an immutable input",
    )
  }
  it.bench(fn() {
    it.keep(run_hot_pipeline(input, options, ["coalesce-locals"]))
  })
}

///|
test "bench active nested handlers functions=16" (it : @bench.T) {
  registry_active_handler_bench(it, 16)
}

///|
test "bench active nested handlers functions=128" (it : @bench.T) {
  registry_active_handler_bench(it, 128)
}

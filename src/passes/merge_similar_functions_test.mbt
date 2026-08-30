///|
fn msf_test_run(source : String) -> @lib.Module raise {
  match pass_test_run_pipeline(source, ["merge-similar-functions"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-similar-functions success, got \{err}")
  }
}

///|
test "merge-similar-functions shares large literal-only siblings" {
  let optimized = try! msf_test_run(
    (
      #|(module
      #|  (func (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i32.const 42)
      #|  (func (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i32.const 43))
      #|,
    ),
  )
  match (optimized.func_sec, optimized.code_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) => {
      @debug.assert_eq(type_idxs.length(), 3)
      @debug.assert_eq(funcs.length(), 3)
      let helper_idx = @lib.FuncIdx::new(2U)
      let @lib.Func(first_locals, @lib.Expr(first)) = funcs[0]
      let @lib.Func(second_locals, @lib.Expr(second)) = funcs[1]
      let @lib.Func(helper_locals, @lib.Expr(helper)) = funcs[2]
      @debug.assert_eq(first_locals, @lib.Locals::empty())
      @debug.assert_eq(second_locals, @lib.Locals::empty())
      @debug.assert_eq(first, [
        @lib.Instruction::i32_const(@lib.I32(42)),
        @lib.Instruction::return_call(helper_idx),
      ])
      @debug.assert_eq(second, [
        @lib.Instruction::i32_const(@lib.I32(43)),
        @lib.Instruction::return_call(helper_idx),
      ])
      @debug.assert_eq(helper_locals, @lib.Locals::empty())
      @debug.assert_eq(helper.length(), 15)
      @debug.assert_eq(
        helper[14],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
    }
    _ => fail("expected merged function and code sections")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected valid merged module, got \{@validate.validation_error_message(err)}",
      )
  }
}

///|
test "merge-similar-functions reuses repeated literal difference vectors" {
  let optimized = try! msf_test_run(
    (
      #|(module
      #|  (func (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i32.const 42 i32.const 42 i32.add)
      #|  (func (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i32.const 43 i32.const 43 i32.add))
      #|,
    ),
  )
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 3)
      let @lib.Func(_, @lib.Expr(helper)) = funcs[2]
      @debug.assert_eq(
        helper[12],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
      @debug.assert_eq(
        helper[13],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
      @debug.assert_eq(helper[14], @lib.Instruction::i32_add())
    }
    None => fail("expected code section")
  }
}

///|
test "merge-similar-functions shifts original non-parameter locals" {
  let optimized = try! msf_test_run(
    (
      #|(module
      #|  (func (param i32) (result i32) (local i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i32.const 42 local.get 0 i32.add local.get 1 i32.add)
      #|  (func (param i32) (result i32) (local i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i32.const 43 local.get 0 i32.add local.get 1 i32.add))
      #|,
    ),
  )
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 3)
      let @lib.Func(helper_locals, @lib.Expr(helper)) = funcs[2]
      @debug.assert_eq(
        helper_locals,
        @lib.Locals::single(1U, @lib.ValType::i32()),
      )
      @debug.assert_eq(
        helper[12],
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      )
      @debug.assert_eq(
        helper[13],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
      @debug.assert_eq(helper[14], @lib.Instruction::i32_add())
      @debug.assert_eq(
        helper[15],
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      )
      @debug.assert_eq(helper[16], @lib.Instruction::i32_add())
    }
    None => fail("expected code section")
  }
}

///|
test "merge-similar-functions parameterizes same-type direct callees" {
  let optimized = try! msf_test_run(
    (
      #|(module
      #|  (type $callee (func (result i32)))
      #|  (func $callee0 (type $callee) (result i32) i32.const 0)
      #|  (func $callee1 (type $callee) (result i32) i32.const 1)
      #|  (elem declare func $callee0 $callee1)
      #|  (func (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    call $callee0)
      #|  (func (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    call $callee1))
      #|,
    ),
  )
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 5)
      let helper_idx = @lib.FuncIdx::new(4U)
      let @lib.Func(_, @lib.Expr(first)) = funcs[2]
      let @lib.Func(_, @lib.Expr(second)) = funcs[3]
      let @lib.Func(_, @lib.Expr(helper)) = funcs[4]
      @debug.assert_eq(first, [
        @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
        @lib.Instruction::return_call(helper_idx),
      ])
      @debug.assert_eq(second, [
        @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
        @lib.Instruction::return_call(helper_idx),
      ])
      @debug.assert_eq(
        helper[18],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
      @debug.assert_eq(
        helper[19],
        @lib.Instruction::call_ref(@lib.TypeIdx::new(0U)),
      )
    }
    None => fail("expected code section")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected valid call-target merge, got \{@validate.validation_error_message(err)}",
      )
  }
}

///|
test "merge-similar-functions preserves incompatible callee types" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $a (func))
      #|  (type $b (func (param i32)))
      #|  (func $callee0 (type $a))
      #|  (func $callee1 (type $b) (param i32))
      #|  (func nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop call $callee0)
      #|  (func nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop i32.const 0 call $callee1))
      #|,
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), [
      "merge-similar-functions",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-similar-functions success, got \{err}")
  }
  @debug.assert_eq(optimized, input)
}

///|
test "merge-similar-functions preserves return-call indirection" {
  let optimized = try! msf_test_run(
    (
      #|(module
      #|  (type $callee (func (result i32)))
      #|  (func $callee0 (type $callee) (result i32) i32.const 0)
      #|  (func $callee1 (type $callee) (result i32) i32.const 1)
      #|  (elem declare func $callee0 $callee1)
      #|  (func (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    return_call $callee0)
      #|  (func (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    return_call $callee1))
      #|,
    ),
  )
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 5)
      let @lib.Func(_, @lib.Expr(first)) = funcs[2]
      let @lib.Func(_, @lib.Expr(helper)) = funcs[4]
      @debug.assert_eq(
        first.last(),
        Some(@lib.Instruction::return_call(@lib.FuncIdx::new(4U))),
      )
      @debug.assert_eq(
        helper.last(),
        Some(@lib.Instruction::return_call_ref(@lib.TypeIdx::new(0U))),
      )
    }
    None => fail("expected code section")
  }
}

///|
test "merge-similar-functions rewrites nested literal sites" {
  let optimized = try! msf_test_run(
    (
      #|(module
      #|  (func (param i32) (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    block (result i32) i32.const 42 end)
      #|  (func (param i32) (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    block (result i32) i32.const 43 end))
      #|,
    ),
  )
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 3)
      let @lib.Func(_, @lib.Expr(helper)) = funcs[2]
      match helper.last() {
        Some(@lib.Block(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(idx))]))) =>
          @debug.assert_eq(idx, 1U)
        _ => fail("expected nested synthetic local.get")
      }
    }
    None => fail("expected code section")
  }
}

///|
test "merge-similar-functions orders helpers by primary function index" {
  let optimized = try! msf_test_run(
    (
      #|(module
      #|  (func (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i32.const 10)
      #|  (func (result i64)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i64.const 20)
      #|  (func (result i64)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i64.const 21)
      #|  (func (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i32.const 11))
      #|,
    ),
  )
  match optimized.type_sec {
    Some(@lib.TypeSec(types)) => {
      @debug.assert_eq(types.length(), 4)
      @debug.assert_eq(
        types[2],
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      )
      @debug.assert_eq(
        types[3],
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i64()], [@lib.ValType::i64()]),
          ),
        ),
      )
    }
    None => fail("expected helper types")
  }
}

///|
test "merge-similar-functions shares profitable exact duplicates" {
  let optimized = try! msf_test_run(
    (
      #|(module
      #|  (func (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i32.const 42)
      #|  (func (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i32.const 42))
      #|,
    ),
  )
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 3)
      let @lib.Func(_, @lib.Expr(first)) = funcs[0]
      @debug.assert_eq(first, [
        @lib.Instruction::return_call(@lib.FuncIdx::new(2U)),
      ])
    }
    None => fail("expected merged code section")
  }
}

///|
test "merge-similar-functions merges duplicate simple function type indices" {
  let optimized = try! msf_test_run(
    (
      #|(module
      #|  (type $a (func (result i32)))
      #|  (type $b (func (result i32)))
      #|  (func (type $a) (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i32.const 42)
      #|  (func (type $b) (result i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i32.const 43))
      #|,
    ),
  )
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => @debug.assert_eq(funcs.length(), 3)
    None => fail("expected merged code section")
  }
}

///|
test "merge-similar-functions preserves differing local declaration types" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (func (result i32) (local i32)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i32.const 42)
      #|  (func (result i32) (local i64)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i32.const 43))
      #|,
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), [
      "merge-similar-functions",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-similar-functions success, got \{err}")
  }
  @debug.assert_eq(optimized, input)
}

///|
test "O4z similar-functions portfolio includes generic MSF" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (func (result i64)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i64.const 42)
      #|  (func (result i64)
      #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    i64.const 43))
      #|,
    ),
  )
  let optimized = o4z_outline_similar_size_functions(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => @debug.assert_eq(funcs.length(), 3)
    None => fail("expected generic O4z MSF output")
  }
}

///|
test "merge-similar-functions GenValid leaves trigger valid encoded rewrites" {
  let profile_names = [
    "merge-similar-functions-literals", "merge-similar-functions-repeated-diff",
    "merge-similar-functions-exact-duplicates", "merge-similar-functions-duplicate-types",
    "merge-similar-functions-locals", "merge-similar-functions-nested", "merge-similar-functions-call-targets",
    "merge-similar-functions-tail-calls",
  ]
  for index = 0; index < profile_names.length(); index = index + 1 {
    let profile_name = profile_names[index]
    let profile = match @validate.gen_valid_profile_by_name(profile_name) {
      Ok(value) => value
      Err(err) => fail(err)
    }
    let generated = match
      @validate.gen_valid_module_result_from_seed(
        0x4d534600UL + index.to_uint64(),
        @validate.GenValidConfig::for_profile(profile),
      ) {
      Ok(value) => value
      Err(failure) => fail(failure.validation_error_message)
    }
    let encoded = match @binary.encode_module(generated.wasm_module) {
      Ok(bytes) => bytes
      Err(err) => fail("profile \{profile_name} failed to encode: \{err}")
    }
    let decoded = match @binary.decode_module(encoded) {
      Ok(mod_) => mod_
      Err(err) => fail("profile \{profile_name} failed to decode: \{err}")
    }
    let optimized = match
      run_hot_pipeline(decoded, HotPipelineOptions::new(), [
        "merge-similar-functions",
      ]) {
      Ok(mod_) => mod_
      Err(err) => fail("profile \{profile_name} failed to optimize: \{err}")
    }
    assert_true(
      optimized != decoded,
      msg="profile \{profile_name} did not trigger merge-similar-functions",
    )
    match @validate.validate_module(optimized) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "profile \{profile_name} produced invalid output: \{@validate.validation_error_message(err)}",
        )
    }
    let rewritten = match @binary.encode_module(optimized) {
      Ok(bytes) => bytes
      Err(err) =>
        fail("profile \{profile_name} output failed to encode: \{err}")
    }
    match @binary.decode_module(rewritten) {
      Ok(_) => ()
      Err(err) =>
        fail("profile \{profile_name} output failed to roundtrip: \{err}")
    }
  }
}

///|
test "merge-similar-functions leaves tiny literal wrappers separate" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 44) (func (result i32) i32.const 45))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), [
      "merge-similar-functions",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-similar-functions success, got \{err}")
  }
  @debug.assert_eq(optimized, input)
}

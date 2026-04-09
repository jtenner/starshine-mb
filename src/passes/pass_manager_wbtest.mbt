///|
test "hot pipeline debug dump targets stay disabled without trace" {
  let options = HotPipelineOptions::new()

  assert_false(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(2941U),
      "dead-code-elimination",
    ),
  )
  assert_false(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(2944U),
      "vacuum",
    ),
  )
}

///|
test "hot pipeline debug dump targets require traced dce or vacuum on target funcs" {
  let options = HotPipelineOptions::new(trace=Some(fn(_) { () }))

  assert_true(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(2941U),
      "dead-code-elimination",
    ),
  )
  assert_true(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(2944U),
      "vacuum",
    ),
  )
  assert_false(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(2941U),
      "remove-unused-names",
    ),
  )
  assert_false(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(12U),
      "dead-code-elimination",
    ),
  )
}

///|
test "raw simplify-locals branchy structured gate accepts target-like stats" {
  let accepted = {
    locals_count: 184,
    instr_count: 1072,
    has_structured_control: true,
    if_count: 53,
    block_count: 24,
    loop_count: 0,
    local_set_count: 69,
    local_get_count: 315,
    call_count: 107,
    return_count: 7,
    exact_tail_count: 0,
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_branchy_structured_call_heavy_stats(
      accepted,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_branchy_structured_call_heavy_stats({
      ..accepted,
      local_set_count: 63,
    }),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_branchy_structured_call_heavy_stats({
      ..accepted,
      call_count: 95,
    }),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_branchy_structured_call_heavy_stats({
      ..accepted,
      loop_count: 1,
    }),
  )
}

///|
#cfg(target="native")
fn pass_manager_test_native_c_string(text : String) -> Bytes {
  let out = @buffer.new(size_hint=text.length() + 1)
  for c in text {
    let code = c.to_int()
    if code >= 0 && code <= 255 {
      out.write_byte(code.to_byte())
    } else {
      out.write_byte('?'.to_int().to_byte())
    }
  }
  out.write_byte(0)
  out.to_bytes()
}

///|
#cfg(target="native")
#borrow(path, mode)
extern "c" fn pass_manager_test_native_fopen(
  path : Bytes,
  mode : Bytes,
) -> UInt64 = "fopen"

///|
#cfg(target="native")
extern "c" fn pass_manager_test_native_fclose(stream : UInt64) -> Int = "fclose"

///|
#cfg(target="native")
extern "c" fn pass_manager_test_native_fseek(
  stream : UInt64,
  offset : Int,
  whence : Int,
) -> Int = "fseek"

///|
#cfg(target="native")
extern "c" fn pass_manager_test_native_ftell(stream : UInt64) -> Int64 = "ftell"

///|
#cfg(target="native")
#borrow(ptr)
extern "c" fn pass_manager_test_native_fread(
  ptr : Bytes,
  size : UInt64,
  count : UInt64,
  stream : UInt64,
) -> UInt64 = "fread"

///|
#cfg(target="native")
fn pass_manager_test_native_read_bytes(path : String) -> Bytes? {
  let c_path = pass_manager_test_native_c_string(path)
  let c_mode = pass_manager_test_native_c_string("rb")
  let file = pass_manager_test_native_fopen(c_path, c_mode)
  if file == 0UL {
    return None
  }
  if pass_manager_test_native_fseek(file, 0, 2) != 0 {
    ignore(pass_manager_test_native_fclose(file))
    return None
  }
  let size_i64 = pass_manager_test_native_ftell(file)
  if size_i64 < 0L {
    ignore(pass_manager_test_native_fclose(file))
    return None
  }
  let size_u = size_i64.reinterpret_as_uint64()
  if pass_manager_test_native_fseek(file, 0, 0) != 0 {
    ignore(pass_manager_test_native_fclose(file))
    return None
  }
  let bytes = Bytes::new(size_u.to_int())
  let read = if size_u == 0UL {
    0UL
  } else {
    pass_manager_test_native_fread(bytes, 1UL, size_u, file)
  }
  let close_code = pass_manager_test_native_fclose(file)
  if close_code != 0 {
    return None
  }
  if size_u == 0UL || read == size_u {
    Some(bytes)
  } else {
    None
  }
}

///|
#cfg(target="native")
fn pass_manager_test_native_read_repo_fixture(path : String) -> Bytes? {
  for base in [path, "../starshine-mb/\{path}"] {
    for
      prefix in [
        "", "../", "../../", "../../../", "../../../../", "../../../../../", "../../../../../../",
      ] {
      match pass_manager_test_native_read_bytes("\{prefix}\{base}") {
        Some(bytes) => return Some(bytes)
        None => ()
      }
    }
  }
  None
}

///|
#cfg(target="native")
test "raw simplify-locals gate accepts debug artifact Func 409" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(409U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let module_state = { module_ctx: None }
  ignore(
    run_hot_pipeline_require_module_ctx(
      mod_,
      module_state,
      HotPipelineOptions::new(),
    ),
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_i32_pair_result(
      mod_,
      func_idx,
      module_state,
      HotPipelineOptions::new(),
    ),
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_multivalue_call_ladder(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "multivalue-call-heavy-ladder")
}

///|
#cfg(target="native")
test "raw simplify-locals gate still accepts debug artifact Func 409 with cached module ctx" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(409U)
  let module_state = { module_ctx: None }
  ignore(
    run_hot_pipeline_require_module_ctx(
      mod_,
      module_state,
      HotPipelineOptions::new(),
    ),
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      module_state,
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "multivalue-call-heavy-ladder")
}

///|
#cfg(target="native")
test "raw simplify-locals skips decode-shaped debug artifact Func 1950" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(1950U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_decode_structured_call_heavy(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "decode-structured-call-heavy")
}

///|
#cfg(target="native")
test "raw simplify-locals skips straight-line builder debug artifact Func 262" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(262U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_straight_line_builder_churn(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_true(pipeline_result.unchanged_original)
  assert_eq(pipeline_result.reason, "straight-line-builder-churn")
}

///|
#cfg(target="native")
test "raw simplify-locals skips huge straight-line call builder debug artifact Func 1800" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(1800U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_huge_straight_line_call_builder(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_true(pipeline_result.unchanged_original)
  assert_eq(pipeline_result.reason, "huge-straight-line-call-builder")
}

///|
#cfg(target="native")
test "raw simplify-locals skips encode-shaped debug artifact Func 2053" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(2053U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_encode_structured_call_heavy(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "encode-structured-call-heavy")
}

///|
#cfg(target="native")
test "raw simplify-locals skips branchy decode debug artifact Func 1949" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(1949U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_branchy_decode_structured_call_heavy(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "branchy-decode-structured-call-heavy")
}

///|
#cfg(target="native")
test "raw simplify-locals skips stringview trim-end debug artifact Func 4238" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(4238U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_stringview_trim_loop_churn(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "stringview-trim-loop-churn")
}

///|
#cfg(target="native")
test "raw simplify-locals skips stringview trim-start debug artifact Func 4239" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(4239U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_stringview_trim_loop_churn(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "stringview-trim-loop-churn")
}

///|
#cfg(target="native")
test "raw simplify-locals skips transformer catch debug artifact Func 1409" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(1409U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_transformer_catch_structured_call_heavy(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "transformer-catch-structured-call-heavy")
}

///|
#cfg(target="native")
test "raw simplify-locals skips transformer catch debug artifact Func 1410" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(1410U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_transformer_catch_structured_call_heavy(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "transformer-catch-structured-call-heavy")
}

///|
#cfg(target="native")
test "raw simplify-locals skips transformer catch debug artifact Func 1411" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(1411U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_transformer_catch_structured_call_heavy(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "transformer-catch-structured-call-heavy")
}

///|
#cfg(target="native")
test "raw simplify-locals gate accepts debug artifact Func 414" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(414U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_i32_pair_result(
      mod_,
      func_idx,
      { module_ctx: None },
      HotPipelineOptions::new(),
    ),
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_multivalue_call_ladder(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "multivalue-call-heavy-ladder")
}

///|
#cfg(target="native")
test "raw simplify-locals gate accepts debug artifact Func 370" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(370U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_i32_pair_result(
      mod_,
      func_idx,
      { module_ctx: None },
      HotPipelineOptions::new(),
    ),
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_multivalue_call_ladder(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "multivalue-call-heavy-ladder")
}

///|
#cfg(target="native")
test "raw simplify-locals gate accepts debug artifact Func 473" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(473U)
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_false(pipeline_result.unchanged_original)
  assert_eq(pipeline_result.reason, "straight-line-adjacent-local-tee")
}

///|
#cfg(target="native")
test "raw simplify-locals rewrites lane-builder debug artifact Func 1884" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(1884U)
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_false(pipeline_result.unchanged_original)
  assert_eq(pipeline_result.reason, "straight-line-lane-builder")
}

///|
#cfg(target="native")
test "raw simplify-locals skips branchy structured debug artifact funcs" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for raw_idx in [1058, 1274] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
    let pipeline_result = match
      run_hot_pipeline_func(
        mod_,
        func_idx,
        @ir.HotPassDescriptor::new("simplify-locals"),
        { module_ctx: None },
        HotPipelineOptions::new(),
      ) {
      Ok(result) => result
      Err(err) =>
        fail("expected simplify-locals hot pipeline success, got \{err}")
    }
    assert_true(
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(
      pipeline_result.unchanged_original,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_eq(
      pipeline_result.reason,
      "branchy-structured-call-heavy",
      msg="func=\{raw_idx}",
    )
  }
}

///|
#cfg(target="native")
test "raw simplify-locals rewrites structured debug artifact Func 225" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(225U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let module_state = { module_ctx: None }
  let module_ctx = run_hot_pipeline_require_module_ctx(
    mod_,
    module_state,
    HotPipelineOptions::new(),
  )
  let env = run_hot_pipeline_raw_simplify_locals_func_env(
    mod_, func_idx, module_ctx, locals,
  )
  let (_, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_instrs(
    instrs, env,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(rewrite_count >= 16)
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_false(pipeline_result.unchanged_original)
  assert_eq(pipeline_result.reason, "structured-pure-copy-call-tail")
}

///|
#cfg(target="native")
test "raw simplify-locals skips giant debug artifact Func 501" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      @lib.FuncIdx::new(501U),
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "giant-local-func-noop")
}

///|
#cfg(target="native")
test "raw simplify-locals skips large structured call-heavy debug artifact funcs" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for raw_idx in [298, 871, 901, 951] {
    let func_idx = @lib.FuncIdx::new(raw_idx.to_uint())
    let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
      mod_, func_idx,
    )
    let pipeline_result = match
      run_hot_pipeline_func(
        mod_,
        func_idx,
        @ir.HotPassDescriptor::new("simplify-locals"),
        { module_ctx: None },
        HotPipelineOptions::new(),
      ) {
      Ok(result) => result
      Err(err) =>
        fail("expected simplify-locals hot pipeline success, got \{err}")
    }
    assert_true(
      run_hot_pipeline_raw_simplify_locals_should_skip_giant_structured_call_heavy(
        locals, instrs,
      ),
      msg="func=\{raw_idx}",
    )
    assert_true(
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(pipeline_result.unchanged_original, msg="func=\{raw_idx}")
    assert_eq(pipeline_result.reason, "giant-structured-call-heavy")
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips read-only local debug artifact funcs" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for raw_idx in [570, 571] {
    let func_idx = @lib.FuncIdx::new(raw_idx.to_uint())
    let pipeline_result = match
      run_hot_pipeline_func(
        mod_,
        func_idx,
        @ir.HotPassDescriptor::new("simplify-locals"),
        { module_ctx: None },
        HotPipelineOptions::new(),
      ) {
      Ok(result) => result
      Err(err) =>
        fail("expected simplify-locals hot pipeline success, got \{err}")
    }
    assert_true(
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(pipeline_result.unchanged_original, msg="func=\{raw_idx}")
    assert_eq(pipeline_result.reason, "no-local-writes")
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips medium structured call-heavy debug artifact funcs" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for raw_idx in [235, 297, 713, 2177] {
    let func_idx = @lib.FuncIdx::new(raw_idx.to_uint())
    let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
      mod_, func_idx,
    )
    let pipeline_result = match
      run_hot_pipeline_func(
        mod_,
        func_idx,
        @ir.HotPassDescriptor::new("simplify-locals"),
        { module_ctx: None },
        HotPipelineOptions::new(),
      ) {
      Ok(result) => result
      Err(err) =>
        fail("expected simplify-locals hot pipeline success, got \{err}")
    }
    assert_true(
      run_hot_pipeline_raw_simplify_locals_should_skip_medium_structured_call_heavy(
        locals, instrs,
      ),
      msg="func=\{raw_idx}",
    )
    assert_true(
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(pipeline_result.unchanged_original, msg="func=\{raw_idx}")
    assert_eq(pipeline_result.reason, "medium-structured-call-heavy")
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips transformer structured call-heavy debug artifact funcs" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for
    raw_idx in [
      1582, 1647, 1648, 1652, 1661, 1662, 1664, 1669, 1673, 1674, 1675, 1676, 1677,
      1678, 1685,
    ] {
    let func_idx = @lib.FuncIdx::new(raw_idx.to_uint())
    let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
      mod_, func_idx,
    )
    let pipeline_result = match
      run_hot_pipeline_func(
        mod_,
        func_idx,
        @ir.HotPassDescriptor::new("simplify-locals"),
        { module_ctx: None },
        HotPipelineOptions::new(),
      ) {
      Ok(result) => result
      Err(err) =>
        fail("expected simplify-locals hot pipeline success, got \{err}")
    }
    assert_true(
      run_hot_pipeline_raw_simplify_locals_should_skip_transformer_structured_call_heavy(
        locals, instrs,
      ),
      msg="func=\{raw_idx}",
    )
    assert_true(
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(pipeline_result.unchanged_original, msg="func=\{raw_idx}")
    assert_eq(pipeline_result.reason, "transformer-structured-call-heavy")
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips small-loop call-heavy debug artifact funcs" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for raw_idx in [3794, 3885] {
    let func_idx = @lib.FuncIdx::new(raw_idx.to_uint())
    let pipeline_result = match
      run_hot_pipeline_func(
        mod_,
        func_idx,
        @ir.HotPassDescriptor::new("simplify-locals"),
        { module_ctx: None },
        HotPipelineOptions::new(),
      ) {
      Ok(result) => result
      Err(err) =>
        fail("expected simplify-locals hot pipeline success, got \{err}")
    }
    assert_true(
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(pipeline_result.unchanged_original, msg="func=\{raw_idx}")
    assert_eq(pipeline_result.reason, "small-loop-call-heavy")
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips loop-heavy structured call-heavy debug artifact funcs" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for raw_idx in [519, 585] {
    let func_idx = @lib.FuncIdx::new(raw_idx.to_uint())
    let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
      mod_, func_idx,
    )
    let pipeline_result = match
      run_hot_pipeline_func(
        mod_,
        func_idx,
        @ir.HotPassDescriptor::new("simplify-locals"),
        { module_ctx: None },
        HotPipelineOptions::new(),
      ) {
      Ok(result) => result
      Err(err) =>
        fail("expected simplify-locals hot pipeline success, got \{err}")
    }
    assert_true(
      run_hot_pipeline_raw_simplify_locals_should_skip_loop_heavy_structured_call_heavy(
        locals, instrs,
      ),
      msg="func=\{raw_idx}",
    )
    assert_true(
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(pipeline_result.unchanged_original, msg="func=\{raw_idx}")
    assert_eq(pipeline_result.reason, "loop-heavy-structured-call-heavy")
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips giant structured local churn debug artifact Func 3722" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(3722U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_giant_structured_local_churn(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_true(pipeline_result.unchanged_original)
  assert_eq(pipeline_result.reason, "giant-structured-local-churn")
}

///|
#cfg(target="native")
test "raw simplify-locals gate accepts multivalue status debug artifact Func 3764" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(3764U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_i32_pair_result(
      mod_,
      func_idx,
      { module_ctx: None },
      HotPipelineOptions::new(),
    ),
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_multivalue_call_ladder(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "multivalue-call-heavy-ladder")
}

///|
#cfg(target="native")
test "raw simplify-locals rewrites small multivalue debug artifact Func 353" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(353U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      { module_ctx: None },
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_i32_pair_result(
      mod_,
      func_idx,
      { module_ctx: None },
      HotPipelineOptions::new(),
    ),
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_multivalue_call_ladder(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_eq(pipeline_result.reason, "multivalue-call-heavy-ladder")
}

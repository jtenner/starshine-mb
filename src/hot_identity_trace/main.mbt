///|
priv struct HotIdentityMetrics {
  mut source_validate_us : UInt64
  mut lift_us : UInt64
  mut verify_us : UInt64
  mut fresh_analysis_us : UInt64
  mut lower_us : UInt64
  mut output_validate_us : UInt64
  mut encode_us : UInt64
  mut relift_us : UInt64
  mut function_count : Int
  mut input_nodes : Int
  mut input_roots : Int
  mut input_locals : Int
  mut input_cfg_blocks : Int
  mut input_use_sites : Int
  mut output_nodes : Int
  mut output_roots : Int
  mut output_locals : Int
  mut output_cfg_blocks : Int
  mut output_use_sites : Int
}

///|
fn HotIdentityMetrics::new() -> HotIdentityMetrics {
  {
    source_validate_us: 0UL,
    lift_us: 0UL,
    verify_us: 0UL,
    fresh_analysis_us: 0UL,
    lower_us: 0UL,
    output_validate_us: 0UL,
    encode_us: 0UL,
    relift_us: 0UL,
    function_count: 0,
    input_nodes: 0,
    input_roots: 0,
    input_locals: 0,
    input_cfg_blocks: 0,
    input_use_sites: 0,
    output_nodes: 0,
    output_roots: 0,
    output_locals: 0,
    output_cfg_blocks: 0,
    output_use_sites: 0,
  }
}

///|
fn hot_identity_use_sites(hot : @ir.HotFunc, uses : @ir.HotUseDef) -> Int {
  let mut count = 0
  for id in 0..<@ir.hot_node_count(hot) {
    count += @ir.node_use_count(uses, id)
  }
  count
}

///|
fn hot_identity_observe(
  hot : @ir.HotFunc,
  output : Bool,
  metrics : HotIdentityMetrics,
) -> Unit {
  let cfg = @ir.cfg_build(hot, expand_operand_control=true)
  let uses = @ir.use_def_build(hot, cfg=Some(cfg))
  let nodes = @ir.hot_node_count(hot)
  let roots = @ir.hot_root_count(hot)
  let locals = @ir.hot_local_count(hot)
  let blocks = @ir.cfg_block_count(cfg)
  let use_sites = hot_identity_use_sites(hot, uses)
  if output {
    metrics.output_nodes += nodes
    metrics.output_roots += roots
    metrics.output_locals += locals
    metrics.output_cfg_blocks += blocks
    metrics.output_use_sites += use_sites
  } else {
    metrics.input_nodes += nodes
    metrics.input_roots += roots
    metrics.input_locals += locals
    metrics.input_cfg_blocks += blocks
    metrics.input_use_sites += use_sites
  }
}

///|
fn hot_identity_lift(
  mod_ : @lib.Module,
  absolute_func_index : Int,
  capture_stack_locals : Bool,
  materialize_multi_values : Bool,
) -> Result[@ir.HotFunc, String] {
  match
    @ir.hot_lift_func_with_context_result(
      mod_,
      @lib.FuncIdx::new(absolute_func_index.reinterpret_as_uint()),
      @ir.hot_module_context_from_module(mod_),
      capture_stack_locals~,
      materialize_multi_values~,
    ) {
    Ok(hot) => Ok(hot)
    Err(error) =>
      Err("lift failed for function \{absolute_func_index}: \{error}")
  }
}

///|
fn hot_identity_verify(
  hot : @ir.HotFunc,
  absolute_func_index : Int,
) -> Result[Unit, String] {
  match @ir.hot_verify_all(hot, cache=Some(())) {
    Ok(_) => Ok(())
    Err(error) =>
      Err("verify failed for function \{absolute_func_index}: \{error}")
  }
}

///|
fn run_hot_identity_once(
  input : @lib.Module,
  capture_stack_locals : Bool,
  materialize_multi_values : Bool,
  metrics : HotIdentityMetrics,
) -> Result[(@lib.Module, Bytes), String] {
  let started = @lib.trace_now_us()
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(error) => return Err("source validation failed: \{error}")
  }
  metrics.source_validate_us += @lib.trace_elapsed_us_since(started)
  let defs = match input.code_sec {
    Some(@lib.CodeSec(defs)) => defs
    None => return Err("HOT identity trace requires a code section")
  }
  let context = @ir.hot_module_context_from_module(input)
  let imported = context.func_types.length() - defs.length()
  let lowered = defs.copy()
  metrics.function_count += defs.length()
  for code_index in 0..<defs.length() {
    let absolute = imported + code_index
    let started = @lib.trace_now_us()
    let hot = match
      hot_identity_lift(
        input, absolute, capture_stack_locals, materialize_multi_values,
      ) {
      Ok(hot) => hot
      Err(error) => return Err(error)
    }
    metrics.lift_us += @lib.trace_elapsed_us_since(started)
    let started = @lib.trace_now_us()
    match hot_identity_verify(hot, absolute) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    metrics.verify_us += @lib.trace_elapsed_us_since(started)
    let started = @lib.trace_now_us()
    hot_identity_observe(hot, false, metrics)
    metrics.fresh_analysis_us += @lib.trace_elapsed_us_since(started)
    let started = @lib.trace_now_us()
    // Verification succeeded immediately above. This entry avoids timing a
    // second implicit verifier as part of lowering.
    lowered[code_index] = @ir.hot_lower_func_unverified(hot)
    metrics.lower_us += @lib.trace_elapsed_us_since(started)
  }
  let output = input.with_code_sec(@lib.CodeSec::new(lowered))
  let started = @lib.trace_now_us()
  match @validate.validate_module(output) {
    Ok(_) => ()
    Err(error) => return Err("lowered output validation failed: \{error}")
  }
  metrics.output_validate_us += @lib.trace_elapsed_us_since(started)
  let started = @lib.trace_now_us()
  let bytes = match @binary.encode_module(output) {
    Ok(bytes) => bytes
    Err(error) => return Err("lowered output encode failed: \{error}")
  }
  metrics.encode_us += @lib.trace_elapsed_us_since(started)
  let started = @lib.trace_now_us()
  let decoded = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(error) => return Err("lowered output decode failed: \{error}")
  }
  let output_defs = match decoded.code_sec {
    Some(@lib.CodeSec(items)) => items
    None => return Err("redecoded HOT identity output lost its code section")
  }
  let output_context = @ir.hot_module_context_from_module(decoded)
  let output_imported = output_context.func_types.length() -
    output_defs.length()
  for code_index in 0..<output_defs.length() {
    let absolute = output_imported + code_index
    let hot = match
      hot_identity_lift(
        decoded, absolute, capture_stack_locals, materialize_multi_values,
      ) {
      Ok(hot) => hot
      Err(error) => return Err("fresh output \{error}")
    }
    match hot_identity_verify(hot, absolute) {
      Ok(_) => ()
      Err(error) => return Err("fresh output \{error}")
    }
    hot_identity_observe(hot, true, metrics)
  }
  metrics.relift_us += @lib.trace_elapsed_us_since(started)
  Ok((output, bytes))
}

///|
fn hot_identity_json(
  input_path : String,
  output_path : String,
  repeats : Int,
  capture_stack_locals : Bool,
  materialize_multi_values : Bool,
  input_bytes : Int,
  output_bytes : Int,
  metrics : HotIdentityMetrics,
) -> String {
  "{\"schema\":\"starshine.hot-identity-trace.v1\",\"input\":\"\{input_path}\",\"output\":\"\{output_path}\",\"repeats\":\{repeats},\"captureStackLocals\":\{capture_stack_locals},\"materializeMultiValues\":\{materialize_multi_values},\"lowering\":\"unverified entry after explicit successful hot_verify_all; default canonicalization options\",\"inputBytes\":\{input_bytes},\"outputBytes\":\{output_bytes},\"sourceValidateUs\":\{metrics.source_validate_us},\"liftUs\":\{metrics.lift_us},\"verifyUs\":\{metrics.verify_us},\"freshAnalysisUs\":\{metrics.fresh_analysis_us},\"lowerUs\":\{metrics.lower_us},\"outputValidateUs\":\{metrics.output_validate_us},\"encodeUs\":\{metrics.encode_us},\"reliftFreshAnalysisUs\":\{metrics.relift_us},\"functionCount\":\{metrics.function_count},\"inputNodes\":\{metrics.input_nodes},\"inputRoots\":\{metrics.input_roots},\"inputLocals\":\{metrics.input_locals},\"inputCfgBlocks\":\{metrics.input_cfg_blocks},\"inputUseSites\":\{metrics.input_use_sites},\"outputNodes\":\{metrics.output_nodes},\"outputRoots\":\{metrics.output_roots},\"outputLocals\":\{metrics.output_locals},\"outputCfgBlocks\":\{metrics.output_cfg_blocks},\"outputUseSites\":\{metrics.output_use_sites},\"guestExecution\":\"not performed by trace executable\"}"
}

///|
fn hot_identity_usage() -> String {
  "usage: hot_identity_trace <input.wasm> <output.wasm> [repeat] [default|capture|materialize|both]"
}

///|
fn hot_identity_parse_repeat(raw : String) -> Int {
  if raw.length() == 0 {
    abort("repeat must not be empty")
  }
  let mut value = 0
  for c in raw {
    if c < '0' || c > '9' {
      abort("repeat must be an integer")
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
  }
  if value <= 0 || value > 1000 {
    abort("repeat must be in 1..1000")
  }
  value
}

///|
fn main {
  let args = @env.args()
  let offset = if args.length() > 0 && args[0].contains("hot_identity_trace") {
    1
  } else {
    0
  }
  if args.length() - offset < 2 || args.length() - offset > 4 {
    abort(hot_identity_usage())
  }
  let input_path = args[offset]
  let output_path = args[offset + 1]
  let repeats = if args.length() - offset >= 3 {
    hot_identity_parse_repeat(args[offset + 2])
  } else {
    1
  }
  let mode = if args.length() - offset >= 4 {
    args[offset + 3]
  } else {
    "default"
  }
  let (capture_stack_locals, materialize_multi_values) = match mode {
    "default" => (false, false)
    "capture" => (true, false)
    "materialize" => (false, true)
    "both" => (true, true)
    _ => abort("mode must be 'default', 'capture', 'materialize', or 'both'")
  }
  let input_bytes = match @sfs.read_file_bytes(input_path) {
    Ok(bytes) => bytes
    Err(error) => abort(error)
  }
  let input = match @binary.decode_module(input_bytes) {
    Ok(mod_) => mod_
    Err(error) => abort("input decode failed: \{error}")
  }
  let metrics = HotIdentityMetrics::new()
  let mut output_bytes : Bytes? = None
  for _ in 0..<repeats {
    match
      run_hot_identity_once(
        input, capture_stack_locals, materialize_multi_values, metrics,
      ) {
      Ok((_, bytes)) => output_bytes = Some(bytes)
      Err(error) => abort(error)
    }
  }
  let output_bytes = output_bytes.unwrap()
  match @sfs.write_file_bytes(output_path, output_bytes) {
    Ok(_) => ()
    Err(error) => abort(error)
  }
  println(
    hot_identity_json(
      input_path,
      output_path,
      repeats,
      capture_stack_locals,
      materialize_multi_values,
      input_bytes.length(),
      output_bytes.length(),
      metrics,
    ),
  )
}

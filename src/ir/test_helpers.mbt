///|
pub struct IrTestHotFixture {
  mod_ : @lib.Module
  code_idx : Int
  hot_func : HotFunc
}

///|
fn ir_test_module_from_wat(text : String) -> @lib.Module {
  let mod_ = match @wast.wast_to_binary_module(text, filename="ir-test.wat") {
    Ok(mod_) => mod_
    Err(err) => abort("unexpected IR test fixture parse failure: \{err}")
  }
  match @validate.validate_module(mod_) {
    Ok(_) => mod_
    Err(err) => abort("unexpected invalid IR test fixture: \{err}")
  }
}

///|
fn ir_test_imported_func_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
pub fn ir_test_build_hot_from_wat(
  text : String,
  code_idx? : Int = 0,
) -> IrTestHotFixture {
  let mod_ = ir_test_module_from_wat(text)
  match mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      if code_idx < 0 || code_idx >= defs.length() {
        abort("IR test hot fixture requires a valid defined-function index")
      }
      let hot_func = hot_lift_func(
        mod_,
        @lib.FuncIdx::new(
          (ir_test_imported_func_count(mod_) + code_idx).reinterpret_as_uint(),
        ),
      )
      match hot_verify_core(hot_func) {
        Ok(_) => ()
        Err(err) =>
          abort("unexpected lifted IR test fixture core failure: \{err}")
      }
      match hot_verify_control(hot_func) {
        Ok(_) => ()
        Err(err) =>
          abort("unexpected lifted IR test fixture control failure: \{err}")
      }
      { mod_, code_idx, hot_func }
    }
    None => abort("IR test hot fixture requires a module with a code section")
  }
}

///|
pub fn ir_test_assert_verify_and_lower(
  fixture : IrTestHotFixture,
) -> @lib.Module {
  match hot_verify_core(fixture.hot_func) {
    Ok(_) => ()
    Err(err) => abort("expected hot fixture to pass core verification: \{err}")
  }
  match hot_verify_control(fixture.hot_func) {
    Ok(_) => ()
    Err(err) =>
      abort("expected hot fixture to pass control verification: \{err}")
  }
  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      if fixture.code_idx < 0 || fixture.code_idx >= defs.length() {
        abort("IR test lower helper requires a valid defined-function index")
      }
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => abort("IR test lower helper requires a code section")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => out
    Err(err) => abort("expected lowered IR test fixture to validate: \{err}")
  }
}

///|
fn ir_test_join_lines(lines : Array[String]) -> String {
  let out = StringBuilder::new()
  for i = 0; i < lines.length(); i = i + 1 {
    if i > 0 {
      out.write_string("\n")
    }
    out.write_string(lines[i])
  }
  out.to_string()
}

///|
fn ir_test_join_csv(parts : Array[String]) -> String {
  let out = StringBuilder::new()
  for i = 0; i < parts.length(); i = i + 1 {
    if i > 0 {
      out.write_string(", ")
    }
    out.write_string(parts[i])
  }
  out.to_string()
}

///|
fn ir_test_edge_kind_name(kind : CfgEdgeKind) -> String {
  match kind {
    CfgEdgeKind::FallthroughEdge => "fallthrough"
    CfgEdgeKind::BranchEdge => "branch"
    CfgEdgeKind::ReturnEdge => "return"
    CfgEdgeKind::ExceptionalEdge => "exceptional"
    CfgEdgeKind::UnreachableExitEdge => "unreachable"
  }
}

///|
fn ir_test_dump_edges(edges : Array[CfgEdge]) -> String {
  let parts : Array[String] = []
  for edge in edges {
    parts.push("\{ir_test_edge_kind_name(edge.kind)}:\{edge.block}")
  }
  let body = ir_test_join_csv(parts)
  "[\{body}]"
}

///|
fn ir_test_dump_bitset(bitset : Bitset) -> String {
  let parts : Array[String] = []
  bitset_for_each_set_bit(bitset, fn(bit) { parts.push(bit.to_string()) })
  let body = ir_test_join_csv(parts)
  "[\{body}]"
}

///|
fn ir_test_dump_value_origin(origin : HotSsaValueOrigin) -> String {
  match origin {
    HotSsaValueOrigin::EntryParamDef(local_id) => "param(\{local_id})"
    HotSsaValueOrigin::EntryDefaultInitDef(local_id) => "init(\{local_id})"
    HotSsaValueOrigin::LocalSetDef(node_id) => "set(\{node_id})"
    HotSsaValueOrigin::LocalTeeDef(node_id) => "tee(\{node_id})"
    HotSsaValueOrigin::PhiDef(phi_id) => "phi(\{phi_id})"
  }
}

///|
fn ir_test_dump_use_origin(origin : HotSsaUseOrigin) -> String {
  match origin {
    HotSsaUseOrigin::LocalGetUse(node_id) => "get(\{node_id})"
    HotSsaUseOrigin::PhiInputUse(phi_id, predecessor) =>
      "phi(\{phi_id}<-\{predecessor})"
  }
}

///|
pub fn ir_test_dump_cfg(func : HotFunc) -> String {
  let cfg = cfg_build(func)
  let exceptional = match cfg_exceptional_exit_block(cfg) {
    Some(block_id) => block_id.to_string()
    None => "-"
  }
  let lines = [
    "entry=\{cfg_entry_block(cfg)} exit=\{cfg_exit_block(cfg)} exceptional=\{exceptional}",
  ]
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    let block = cfg_block_get(cfg, block_id)
    lines.push(
      "block=\{block_id} synthetic=\{block.is_synthetic} holder=\{block.region_holder} span=\{block.start_slot}..\{block.end_slot} nodes=\{block.nodes} preds=\{ir_test_dump_edges(block.preds)} succs=\{ir_test_dump_edges(block.succs)}",
    )
  }
  ir_test_join_lines(lines)
}

///|
pub fn ir_test_dump_dom(func : HotFunc) -> String {
  dom_debug_dump(dom_build(cfg_build(func)))
}

///|
pub fn ir_test_dump_liveness(func : HotFunc) -> String {
  let cfg = cfg_build(func)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let lines = [
    "include_exceptional_edges=\{liveness.include_exceptional_edges}",
  ]
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    lines.push(
      "block=\{block_id} in=\{ir_test_dump_bitset(live_in(liveness, block_id))} out=\{ir_test_dump_bitset(live_out(liveness, block_id))}",
    )
  }
  ir_test_join_lines(lines)
}

///|
pub fn ir_test_dump_ssa(func : HotFunc) -> String {
  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let lines = ["entry_defs=\{ssa.entry_defs}"]
  for value_id = 0; value_id < ssa.value_types.length(); value_id = value_id + 1 {
    let uses = ssa_uses_of_value(ssa, value_id)
    let use_parts : Array[String] = []
    for use_origin in uses {
      use_parts.push(ir_test_dump_use_origin(use_origin))
    }
    let use_body = ir_test_join_csv(use_parts)
    lines.push(
      "value=\{value_id} origin=\{ir_test_dump_value_origin(ssa_value_origin(ssa, value_id))} uses=[\{use_body}]",
    )
  }
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    let phis = ssa_phis_for_block(ssa, block_id)
    lines.push("block=\{block_id} phis=\{phis}")
    for phi_id in phis {
      let inputs = ssa_phi_inputs(ssa, phi_id)
      let input_parts : Array[String] = []
      for input in inputs {
        input_parts.push("\{input.predecessor}->\{input.value_id}")
      }
      let input_body = ir_test_join_csv(input_parts)
      lines.push(
        "phi=\{phi_id} block=\{ssa_phi_block(ssa, phi_id)} local=\{ssa_phi_local(ssa, phi_id)} inputs=[\{input_body}]",
      )
    }
  }
  for node_id = 0; node_id < hot_node_count(func); node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    match hot_node_get(func, node_id).op {
      HotOp::LocalGet =>
        lines.push(
          "node=\{node_id} get=\{ssa_value_for_local_get(ssa, node_id)}",
        )
      HotOp::LocalSet | HotOp::LocalTee =>
        lines.push("node=\{node_id} def=\{ssa_def_for_local_set(ssa, node_id)}")
      _ => ()
    }
  }
  ir_test_join_lines(lines)
}

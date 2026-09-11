///|
// Type locations use the same graph as function parameters/results. All
// members of a declared subtype family share liveness, while private direct
// functions keep independent locations and receive replacement signatures.
fn dae2_exposure_module(mod_ : @lib.Module) -> @lib.Module {
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let retained = elems.filter(fn(elem) {
        let @lib.Elem(mode, kind) = elem
        if !(mode is @lib.Declarative) {
          return true
        }
        // An untyped declaration authorizes ref.func validation but does not
        // create a runtime reference. Real body/global/table references remain
        // visible to the ordinary exposure collector. Concrete typed element
        // declarations retain their signature until their type is remapped too.
        match kind {
          @lib.FuncsElemKind(_) | @lib.FuncExprsElemKind(_) => false
          @lib.TypedExprsElemKind(ref_type, _) =>
            ref_type.get_heap_type() !=
            @lib.HeapType::abs(@lib.AbsHeapType::func())
        }
      })
      mod_.with_elem_sec(@lib.ElemSec::new(retained))
    }
    None => mod_
  }
}

///|
fn dae2_call_info(
  infos : Array[Dae2Function],
  type_infos : Array[Int],
  func : @ir.HotFunc,
  node : Int,
) -> Dae2Function {
  infos[dae2_call_info_index(type_infos, func, node)]
}

///|
fn dae2_call_info_index(
  type_infos : Array[Int],
  func : @ir.HotFunc,
  node : Int,
) -> Int {
  let data = @ir.hot_node_get(func, node)
  match data.op {
    @ir.Call | @ir.ReturnCall => data.imm0
    _ => {
      let sig = @ir.hot_call_sig_get(func, data.imm0)
      type_infos[dae2_type_slot(sig.type_idx, 0)]
    }
  }
}

///|
fn dae2_type_slot(index : @lib.TypeIdx, base : Int) -> Int {
  match index {
    @lib.TypeIdx(raw) => raw.reinterpret_as_int()
    @lib.RecIdx(raw) => base + raw.reinterpret_as_int()
  }
}

///|
fn dae2_type_ref_edges(
  graph : Dae2Graph,
  owner : Int,
  value : @lib.ValType,
  base : Int,
) -> Unit {
  match value {
    @lib.RefTypeValType(ref_type) =>
      match ref_type.get_heap_type() {
        @lib.HeapType(index) => graph.edge(owner, dae2_type_slot(index, base))
        @lib.DefTypeHeapType(_) =>
          // Embedded definitions have no stable module index. Keep the visible
          // closure conservative instead of treating a missing identity as empty.
          for index = 0; index < graph.used.length(); index = index + 1 {
            graph.edge(owner, index)
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn dae2_type_field_edges(
  graph : Dae2Graph,
  owner : Int,
  field : @lib.FieldType,
  base : Int,
) -> Unit {
  let @lib.FieldType(storage, _) = field
  match storage {
    @lib.ValTypeStorageType(value) =>
      dae2_type_ref_edges(graph, owner, value, base)
    _ => ()
  }
}

///|
fn dae2_prepare_type_locations(
  mod_ : @lib.Module,
  context : @ir.HotModuleContext,
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  exposure : Array[DaeFunctionExposure],
  closed_world : Bool,
) -> Array[Int] {
  let total = context.subtypes.length()
  let bases = Array::make(total, 0)
  match mod_.type_sec {
    Some(@lib.TypeSec(groups)) => {
      let mut offset = 0
      for group in groups {
        let size = match group {
          @lib.SingleRecType(_) => 1
          @lib.GroupRecType(items) => items.length()
        }
        for member_idx = 0; member_idx < size; member_idx = member_idx + 1 {
          bases[offset + member_idx] = offset
        }
        offset += size
      }
    }
    None => ()
  }
  let roots = Array::makei(total, fn(index) { index })
  // Validated Wasm supertypes precede their subtypes. Resolve each family root
  // without depending on hash-map insertion order or destination mutations.
  for index = 0; index < total; index = index + 1 {
    for super_type in context.subtypes[index].super_types() {
      let parent = dae2_type_slot(super_type, bases[index])
      roots[index] = roots[parent]
    }
  }
  let type_infos = Array::make(total, -1)
  for index = 0; index < total; index = index + 1 {
    match context.subtypes[index].get_comptype() {
      @lib.FuncCompType(params, results) => {
        let root = roots[index]
        if type_infos[root] < 0 {
          let param_locations = params.map(fn(_) { graph.location() })
          let result_location = graph.location()
          type_infos[root] = infos.length()
          infos.push({
            params,
            results,
            param_locations,
            result_location,
            node_locations: [],
            call_infos: [],
          })
        }
        type_infos[index] = type_infos[root]
      }
      _ => ()
    }
  }
  let public_types = Dae2Graph::new()
  for index = 0; index < total; index = index + 1 {
    ignore(public_types.location())
  }
  for index = 0; index < total; index = index + 1 {
    let subtype = context.subtypes[index]
    let base = bases[index]
    for parent in subtype.super_types() {
      public_types.edge(index, dae2_type_slot(parent, base))
    }
    for metadata_type in [subtype.describes_type(), subtype.descriptor_type()] {
      match metadata_type {
        Some(target) => public_types.edge(index, dae2_type_slot(target, base))
        None => ()
      }
    }
    match subtype.get_comptype() {
      @lib.FuncCompType(params, results) =>
        for value in params + results {
          dae2_type_ref_edges(public_types, index, value, base)
        }
      @lib.StructCompType(fields) =>
        for field in fields {
          dae2_type_field_edges(public_types, index, field, base)
        }
      @lib.ArrayCompType(field) =>
        dae2_type_field_edges(public_types, index, field, base)
      @lib.ContCompType(target) => {
        let target = dae2_type_slot(target, base)
        public_types.edge(index, target)
        // Stack switching signatures require separate operand/handler rewrites.
        public_types.observe(target)
      }
    }
  }
  for index = 0; index < exposure.length(); index = index + 1 {
    let e = exposure[index]
    let type_index = dae2_type_slot(context.func_type_idxs[index], 0)
    let type_info = infos[type_infos[type_index]]
    if dae_function_exposure_blocks_boundary(e) {
      let info = infos[index]
      for param = 0; param < info.param_locations.length(); param = param + 1 {
        graph.edge(
          info.param_locations[param],
          type_info.param_locations[param],
        )
        graph.edge(
          type_info.param_locations[param],
          info.param_locations[param],
        )
      }
      graph.edge(info.result_location, type_info.result_location)
      graph.edge(type_info.result_location, info.result_location)
      if !closed_world || e.imported || e.exported {
        public_types.observe(type_index)
      }
    }
  }
  // Imported/exported tables and globals expose their concrete reference types.
  let exposed = Array::make(total, false)
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        let @lib.Import(_, _, kind) = import_
        match kind {
          @lib.TableExternType(tt) => dae_mark_used_table_type(tt, exposed)
          @lib.GlobalExternType(gt) => dae_mark_used_global_type(gt, exposed)
          @lib.TagExternType(@lib.TagType(tt)) =>
            dae_mark_used_type_idx(tt, exposed)
          _ => ()
        }
      }
    None => ()
  }
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        let @lib.Export(_, kind) = export_
        match kind {
          @lib.TableExternIdx(@lib.TableIdx(raw)) =>
            dae_mark_used_table_type(
              context.tables[raw.reinterpret_as_int()],
              exposed,
            )
          @lib.GlobalExternIdx(@lib.GlobalIdx(raw)) =>
            dae_mark_used_global_type(
              context.globals[raw.reinterpret_as_int()],
              exposed,
            )
          _ => ()
        }
      }
    None => ()
  }
  for tag in context.tags {
    let @lib.TagType(index) = tag
    dae_mark_used_type_idx(index, exposed)
  }
  for index = 0; index < total; index = index + 1 {
    if exposed[index] || !closed_world {
      public_types.observe(index)
    }
  }
  public_types.solve()
  for index = 0; index < total; index = index + 1 {
    if public_types.used[index] && type_infos[index] >= 0 {
      let info = infos[type_infos[index]]
      for location in info.param_locations {
        graph.observe(location)
      }
      graph.observe(info.result_location)
    }
  }
  type_infos
}

///|
fn dae2_rewrite_signature_type(
  subtype : @lib.SubType,
  params : Array[@lib.ValType],
  results : Array[@lib.ValType],
) -> @lib.SubType {
  let comp = @lib.CompType::func(params, results)
  match subtype {
    @lib.SubType(final_, supers, metadata, _) =>
      @lib.SubType::new(final_, supers, comp, metadata~)
    @lib.CompTypeSubType(metadata, _) =>
      @lib.SubType::comp_type(comp, metadata~)
  }
}

///|
fn dae2_rewrite_type_section(
  types : @lib.TypeSec,
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  type_infos : Array[Int],
) -> @lib.TypeSec {
  let @lib.TypeSec(groups) = types
  let mut index = 0
  let rewritten = groups.map(fn(group) {
    let members = match group {
      @lib.SingleRecType(sub) => [sub]
      @lib.GroupRecType(members) => members
    }
    let members = members.map(fn(subtype) {
      let current = index
      index += 1
      if current >= type_infos.length() || type_infos[current] < 0 {
        return subtype
      }
      let info = infos[type_infos[current]]
      match subtype.get_comptype() {
        @lib.FuncCompType(params, results) => {
          let kept : Array[@lib.ValType] = []
          for param = 0; param < params.length(); param = param + 1 {
            if graph.used[info.param_locations[param]] {
              kept.push(params[param])
            }
          }
          dae2_rewrite_signature_type(
            subtype,
            kept,
            if graph.used[info.result_location] {
              results
            } else {
              []
            },
          )
        }
        _ => subtype
      }
    })
    match group {
      @lib.SingleRecType(_) => @lib.RecType::new(members[0])
      _ => @lib.RecType::group(members)
    }
  })
  @lib.TypeSec::new(rewritten)
}

///|
fn dae2_preserve_control_types(
  func : @ir.HotFunc,
  context : @ir.HotModuleContext,
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  type_infos : Array[Int],
  lower_state : HotPipelineLowerState,
  replacements : @hashmap.HashMap[Int, @lib.TypeIdx],
) -> Unit {
  for node = 0; node < @ir.hot_node_count(func); node = node + 1 {
    if !@ir.hot_node_is_live(func, node) || !@ir.hot_is_control_node(func, node) {
      continue
    }
    let block_type = match
      @ir.hot_type_get(func, @ir.hot_node_type(func, node)) {
      @ir.BlockResult(bt) | @ir.BlockResultResolved(bt, _, _) => bt
      _ => continue
    }
    let old_index = match block_type {
      @lib.TypeIdxBlockType(index) => dae2_type_slot(index, 0)
      _ => continue
    }
    if old_index >= type_infos.length() || type_infos[old_index] < 0 {
      continue
    }
    let info = infos[type_infos[old_index]]
    if info.param_locations.all(fn(location) { graph.used[location] }) &&
      (info.results.is_empty() || graph.used[info.result_location]) {
      continue
    }
    let @lib.FuncType(params, results) = match
      @ir.hot_module_resolve_type_func_type(
        context,
        @lib.TypeIdx::new(old_index.reinterpret_as_uint()),
      ) {
      Some(sig) => sig
      None => continue
    }
    let replacement = match replacements.get(old_index) {
      Some(index) => index
      None => {
        let types = match lower_state.next_type_sec {
          Some(types) => types
          None => continue
        }
        let (types, index) = dae_append_new_func_type(types, params, results)
        lower_state.next_type_sec = Some(types)
        lower_state.type_sec_changed = true
        replacements.set(old_index, index)
        index
      }
    }
    @ir.hot_control_result_type_set(
      func,
      node,
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(replacement),
        params,
        results,
      ),
    )
  }
}

///|
fn dae2_original_block_type(
  block : @lib.BlockType,
  replacements : @hashmap.HashMap[Int, @lib.TypeIdx],
) -> @lib.BlockType {
  if block is @lib.TypeIdxBlockType(index) {
    if replacements.get(dae2_type_slot(index, 0)) is Some(replacement) {
      return @lib.BlockType::type_idx(replacement)
    }
  }
  block
}

///|
fn dae2_original_control_types(
  body : Array[@lib.Instruction],
  replacements : @hashmap.HashMap[Int, @lib.TypeIdx],
) -> Array[@lib.Instruction] {
  body.map(fn(instruction) {
    match instruction {
      @lib.Block(block, @lib.Expr(body)) =>
        @lib.Instruction::block(
          dae2_original_block_type(block, replacements),
          @lib.Expr::new(dae2_original_control_types(body, replacements)),
        )
      @lib.Loop(block, @lib.Expr(body)) =>
        @lib.Instruction::loop_(
          dae2_original_block_type(block, replacements),
          @lib.Expr::new(dae2_original_control_types(body, replacements)),
        )
      @lib.If(block, yes, no) =>
        @lib.Instruction::if_(
          dae2_original_block_type(block, replacements),
          dae2_original_control_types(yes, replacements),
          no.map(fn(body) { dae2_original_control_types(body, replacements) }),
        )
      @lib.Try(block, @lib.Expr(body), catches, delegate) =>
        @lib.Instruction::try_(
          dae2_original_block_type(block, replacements),
          @lib.Expr::new(dae2_original_control_types(body, replacements)),
          catches.map(fn(catch_) {
            match catch_ {
              @lib.LegacyCatch(tag, @lib.Expr(body)) =>
                @lib.LegacyCatch::tagged(
                  tag,
                  @lib.Expr::new(
                    dae2_original_control_types(body, replacements),
                  ),
                )
              @lib.LegacyCatchAll(@lib.Expr(body)) =>
                @lib.LegacyCatch::all(
                  @lib.Expr::new(
                    dae2_original_control_types(body, replacements),
                  ),
                )
            }
          }),
          delegate~,
        )
      @lib.TryTable(block, catches, @lib.Expr(body)) =>
        @lib.Instruction::try_table(
          dae2_original_block_type(block, replacements),
          catches,
          @lib.Expr::new(dae2_original_control_types(body, replacements)),
        )
      _ => instruction
    }
  })
}

///|
fn dae2_function_needs_rewrite(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  type_infos : Array[Int],
  info : Dae2Function,
  func : @ir.HotFunc,
) -> Bool {
  if dae2_signature_changes(graph, info) {
    return true
  }
  for node = 0; node < @ir.hot_node_count(func); node = node + 1 {
    match @ir.hot_node_get(func, node).op {
      @ir.Call
      | @ir.ReturnCall
      | @ir.CallIndirect
      | @ir.ReturnCallIndirect
      | @ir.CallRef
      | @ir.ReturnCallRef =>
        if dae2_signature_changes(
            graph,
            dae2_call_info(infos, type_infos, func, node),
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn dae2_pin_intrinsic_targets(
  context : @ir.HotModuleContext,
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  func : @ir.HotFunc,
) -> Unit {
  // These imports bind a referenced target signature. Keep the signature
  // even when the caller and its result are otherwise unused.
  for node = 0; node < @ir.hot_node_count(func); node = node + 1 {
    let data = @ir.hot_node_get(func, node)
    if data.op is @ir.Call {
      match context.func_imports[data.imm0] {
        Some((module_name, field_name)) if module_name ==
          @lib.Name::from_string("binaryen-intrinsics") &&
          field_name == @lib.Name::from_string("call.without.effects") => {
          let children = @ir.hot_child_span(func, node)
          if !children.is_empty() {
            let target = @ir.hot_node_get(func, children[children.length() - 1])
            if target.op is @ir.RefFunc {
              let target_info = infos[target.imm0]
              for location in target_info.param_locations {
                graph.observe(location)
              }
              graph.observe(target_info.result_location)
            }
          }
        }
        _ => ()
      }
    }
  }
}

///|
// Lowering can retain a tuple forwarding wrapper after SimplifyLocals. A
// zero-parameter block containing only local reads cannot branch, trap or
// consume the enclosing stack. Removing that wrapper exposes capture pairs.
fn dae2_cleanup_tuple_forwarding(
  instrs : Array[@lib.Instruction],
  module_ctx : @ir.HotModuleContext,
) -> (Array[@lib.Instruction], Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  for instr in instrs {
    match instr {
      @lib.Block(@lib.TypeIdxBlockType(index), @lib.Expr(body)) if body.all(fn(
          instr,
        ) {
          instr is @lib.LocalGet(_)
        }) =>
        match @ir.hot_module_resolve_type_func_type(module_ctx, index) {
          Some(@lib.FuncType([], results)) if results.length() > 1 &&
            results.length() == body.length() => {
            out.append(body)
            changed = true
            continue
          }
          _ => ()
        }
      _ => ()
    }
    out.push(
      pass_lower_map_children(instr, fn(body) {
        let (body, nested_changed) = dae2_cleanup_tuple_forwarding(
          body, module_ctx,
        )
        changed = changed || nested_changed
        body
      }),
    )
  }
  (out, changed)
}

///|
// The optimizing variant removes redundant capture pairs after its cleanup
// pipeline as well: SimplifyLocals may itself lift and materialize a stack
// value. Compact source and generated locals together to make reruns bounded.
fn dae2_cleanup_captures(mod_ : @lib.Module) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  if funcs.is_empty() {
    return mod_
  }
  let params = rl_defined_func_param_cache(mod_)
  let module_ctx = @ir.hot_module_context_from_module(mod_)
  let remaps : Array[Array[Int]?] = []
  let changed_labels : Array[Bool] = []
  let bodies : Array[@lib.Func] = []
  for index = 0; index < funcs.length(); index = index + 1 {
    let @lib.Func(locals, @lib.Expr(instrs)) = funcs[index]
    let (instrs, labels_changed) = dae2_cleanup_tuple_forwarding(
      instrs, module_ctx,
    )
    changed_labels.push(labels_changed)
    let input = @lib.Func::new(locals, @lib.Expr::new(instrs))
    let (body, mapping) = pass_lower_compact_captures_with_map(
      input,
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      params[index],
    )
    bodies.push(body)
    remaps.push(Some(mapping))
  }
  let next = mod_.with_code_sec(@lib.CodeSec::new(bodies))
  let imported = rl_imported_func_count(mod_)
  match rl_rewrite_name_sec(mod_.name_sec, imported, remaps) {
    Some(names) => {
      // Removing a control label changes the ordinal of later labels. Keep
      // metadata for unchanged functions; changed functions have no label map.
      let label_names = match names.label_names {
        Some(@lib.IndirectNameMap(entries)) => {
          let retained = entries.filter(fn(entry) {
            let @lib.IndirectNameAssoc(index, _) = entry
            let defined = index.to_int() - imported
            defined < 0 ||
            defined >= changed_labels.length() ||
            !changed_labels[defined]
          })
          if retained.is_empty() {
            None
          } else {
            Some(@lib.IndirectNameMap::new(retained))
          }
        }
        None => None
      }
      next.with_name_sec(
        @lib.NameSec::new(
          module_name=names.module_name,
          func_names=names.func_names,
          local_names=names.local_names,
          label_names~,
          type_names=names.type_names,
          table_names=names.table_names,
          memory_names=names.memory_names,
          global_names=names.global_names,
          elem_names=names.elem_names,
          data_names=names.data_names,
          field_names=names.field_names,
          tag_names=names.tag_names,
        ),
      )
    }
    None => next.without_name_sec()
  }
}

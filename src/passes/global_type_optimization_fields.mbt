///|
// Field liveness is shared across a nominal hierarchy. Constructor writes do
// not prevent immutability; explicit accesses constrain the layouts instead.
fn gto_map_children(
  instr : @lib.Instruction,
  rewrite : (@lib.Expr) -> @lib.Expr,
) -> @lib.Instruction {
  match instr {
    @lib.Block(bt, body) => @lib.Instruction::block(bt, rewrite(body))
    @lib.Loop(bt, body) => @lib.Instruction::loop_(bt, rewrite(body))
    @lib.If(bt, yes, no) => {
      let @lib.Expr(yes) = rewrite(@lib.Expr::new(yes))
      let no = no.map(fn(body) { rewrite(@lib.Expr::new(body)).0 })
      @lib.Instruction::if_(bt, yes, no)
    }
    @lib.TryTable(bt, catches, body) =>
      @lib.Instruction::try_table(bt, catches, rewrite(body))
    @lib.Try(bt, body, catches, delegate) =>
      @lib.Instruction::try_(
        bt,
        rewrite(body),
        catches.map(fn(c) {
          match c {
            @lib.LegacyCatch(tag, expr) =>
              @lib.LegacyCatch::tagged(tag, rewrite(expr))
            @lib.LegacyCatchAll(expr) => @lib.LegacyCatch::all(rewrite(expr))
          }
        }),
        delegate~,
      )
    _ => instr
  }
}

///|
fn gto_field_access(
  instr : @lib.Instruction,
) -> (@lib.TypeIdx, @lib.U32, Bool, Bool)? {
  match instr {
    @lib.StructGet(t, f)
    | @lib.StructGetS(t, f)
    | @lib.StructGetU(t, f)
    | @lib.StructAtomicGet(_, t, f)
    | @lib.StructAtomicGetS(_, t, f)
    | @lib.StructAtomicGetU(_, t, f)
    | @lib.StructWait(t, f) => Some((t, f, true, false))
    @lib.StructSet(t, f) | @lib.StructAtomicSet(_, t, f) =>
      Some((t, f, false, true))
    @lib.StructAtomicRmw(_, _, t, f) | @lib.StructAtomicCmpxchg(_, t, f) =>
      Some((t, f, true, true))
    _ => None
  }
}

///|
fn gto_scan_fields(
  expr : @lib.Expr,
  reads : Array[Array[Bool]],
  writes : Array[Array[Bool]],
) -> Unit {
  for instr in expr.0 {
    match gto_field_access(instr) {
      Some((@lib.TypeIdx(t), @lib.U32(f), read, write)) => {
        let t = t.to_int()
        let f = f.to_int()
        if t < reads.length() && f < reads[t].length() {
          reads[t][f] = reads[t][f] || read
          writes[t][f] = writes[t][f] || write
        }
      }
      _ => ()
    }
    ignore(
      gto_map_children(instr, fn(body) {
        gto_scan_fields(body, reads, writes)
        body
      }),
    )
  }
}

///|
fn gto_map_initializers(
  mod_ : @lib.Module,
  rewrite : (@lib.Expr) -> @lib.Expr,
) -> @lib.Module {
  let mut next = mod_
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      next = next.with_global_sec(
        @lib.GlobalSec::new(
          globals.map(fn(g) {
            let @lib.Global(ty, init) = g
            @lib.Global::new(ty, rewrite(init))
          }),
        ),
      )
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) =>
      next = next.with_table_sec(
        @lib.TableSec::new(
          tables.map(fn(t) {
            let @lib.Table(ty, init) = t
            @lib.Table::new(ty, init.map(rewrite))
          }),
        ),
      )
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      next = next.with_elem_sec(
        @lib.ElemSec::new(
          elems.map(fn(e) {
            let @lib.Elem(mode, kind) = e
            let kind = match kind {
              @lib.FuncExprsElemKind(exprs) =>
                @lib.ElemKind::func_exprs(exprs.map(rewrite))
              @lib.TypedExprsElemKind(ty, exprs) =>
                @lib.ElemKind::typed_exprs(ty, exprs.map(rewrite))
              _ => kind
            }
            @lib.Elem::new(mode, kind)
          }),
        ),
      )
    None => ()
  }
  next
}

///|
fn gto_public_types(
  mod_ : @lib.Module,
  context : @ir.HotModuleContext,
  bases : Array[Int],
) -> Array[Bool] {
  let graph = Dae2Graph::new()
  for _ in context.subtypes {
    ignore(graph.location())
  }
  for i, subtype in context.subtypes {
    let base = bases[i]
    graph.edge(i, base)
    graph.edge(base, i)
    for parent in subtype.super_types() {
      graph.edge(i, dae2_type_slot(parent, base))
    }
    for target in [subtype.describes_type(), subtype.descriptor_type()] {
      if target is Some(t) {
        graph.edge(i, dae2_type_slot(t, base))
      }
    }
    match subtype.get_comptype() {
      @lib.StructCompType(fields) =>
        for f in fields {
          dae2_type_field_edges(graph, i, f, base)
        }
      @lib.ArrayCompType(f) => dae2_type_field_edges(graph, i, f, base)
      @lib.FuncCompType(params, results) =>
        for vt in params + results {
          dae2_type_ref_edges(graph, i, vt, base)
        }
      @lib.ContCompType(t) => graph.edge(i, dae2_type_slot(t, base))
    }
  }
  let exposed = Array::make(context.subtypes.length(), false)
  // Binaryen's getIgnorablePublicTypes preserves the canonical mutable
  // byte/UTF-16 arrays used for strings across Web host boundaries.
  for i, subtype in context.subtypes {
    let singleton = bases[i] == i &&
      (i + 1 == bases.length() || bases[i + 1] != i)
    if singleton &&
      !subtype.metadata().is_shared() &&
      subtype.super_types().is_empty() &&
      subtype.descriptor_type() is None &&
      subtype.describes_type() is None &&
      (
        subtype is @lib.SubType(true, _, _, _) ||
        subtype is @lib.CompTypeSubType(_, _)
      ) {
      match subtype.get_comptype() {
        @lib.ArrayCompType(
          @lib.FieldType(@lib.PackTypeStorageType(_), @lib.Var)
        ) => exposed[i] = true
        _ => ()
      }
    }
  }
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for @lib.Import(_, _, kind) in imports {
        match kind {
          @lib.FuncExternType(t) => dae_mark_used_type_idx(t, exposed)
          @lib.TableExternType(t) => dae_mark_used_table_type(t, exposed)
          @lib.GlobalExternType(t) => dae_mark_used_global_type(t, exposed)
          @lib.TagExternType(@lib.TagType(t)) =>
            dae_mark_used_type_idx(t, exposed)
          _ => ()
        }
      }
    None => ()
  }
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for @lib.Export(_, kind) in exports {
        match kind {
          @lib.FuncExternIdx(@lib.FuncIdx(i)) =>
            dae_mark_used_type_idx(context.func_type_idxs[i.to_int()], exposed)
          @lib.TableExternIdx(@lib.TableIdx(i)) =>
            dae_mark_used_table_type(context.tables[i.to_int()], exposed)
          @lib.GlobalExternIdx(@lib.GlobalIdx(i)) =>
            dae_mark_used_global_type(context.globals[i.to_int()], exposed)
          @lib.TagExternIdx(@lib.TagIdx(i)) => {
            let @lib.TagType(t) = context.tags[i.to_int()]
            dae_mark_used_type_idx(t, exposed)
          }
          _ => ()
        }
      }
    None => ()
  }
  for i, visible in exposed {
    if visible {
      graph.observe(i)
    }
  }
  graph.solve()
  graph.used
}

///|
fn gto_remap_field(instr : @lib.Instruction, f : @lib.U32) -> @lib.Instruction {
  match instr {
    @lib.StructGet(t, _) => @lib.Instruction::struct_get(t, f)
    @lib.StructGetS(t, _) => @lib.Instruction::struct_get_s(t, f)
    @lib.StructGetU(t, _) => @lib.Instruction::struct_get_u(t, f)
    @lib.StructSet(t, _) => @lib.Instruction::struct_set(t, f)
    @lib.StructAtomicGet(o, t, _) =>
      @lib.Instruction::struct_atomic_get(o, t, f)
    @lib.StructAtomicGetS(o, t, _) =>
      @lib.Instruction::struct_atomic_get_s(o, t, f)
    @lib.StructAtomicGetU(o, t, _) =>
      @lib.Instruction::struct_atomic_get_u(o, t, f)
    @lib.StructAtomicSet(o, t, _) =>
      @lib.Instruction::struct_atomic_set(o, t, f)
    @lib.StructAtomicRmw(o, op, t, _) =>
      @lib.Instruction::struct_atomic_rmw(op, t, f, order=o)
    @lib.StructAtomicCmpxchg(o, t, _) =>
      @lib.Instruction::struct_atomic_cmpxchg(t, f, order=o)
    @lib.StructWait(t, _) => @lib.Instruction::struct_wait(t, f)
    _ => instr
  }
}

///|
fn gto_operand_start(
  mod_ : @lib.Module,
  funcs : Array[@lib.TypeIdx],
  instrs : Array[@lib.Instruction],
  end : Int,
) -> Int {
  let mut needed = 1
  for i = end; i >= 0; i = i - 1 {
    match dae_stack_effect_evidence(instrs[i], mod_, funcs) {
      Some(e) => {
        if e.outputs > needed {
          return -1
        }
        needed = needed - e.outputs + e.inputs
        if needed == 0 {
          return i
        }
      }
      None => return -1
    }
  }
  -1
}

///|
fn gto_droppable(instrs : Array[@lib.Instruction]) -> Bool {
  instrs.all(fn(i) {
    dae_instr_is_droppable_pure_leaf(i) ||
    dae_instr_is_nontrapping_pure_unary(i) ||
    dae_instr_is_nontrapping_pure_binary(i) ||
    i is @lib.RefFunc(_) ||
    i is @lib.StructNew(_) ||
    i is @lib.StructNewDefault(_)
  })
}

///|
fn gto_layout_expr(
  expr : @lib.Expr,
  maps : Array[Array[Int]],
  mod_ : @lib.Module,
  context : @ir.HotModuleContext,
  locals : @lib.Locals?,
  param_count : Int,
  removed_inits : Array[@lib.Global],
  failed : Array[Bool],
) -> @lib.Expr {
  let out : Array[@lib.Instruction] = []
  let starts : Array[Int] = []
  let instrs = expr.0
  for pos, original in instrs {
    starts.push(out.length())
    let instr = gto_map_children(original, fn(body) {
      gto_layout_expr(
        body, maps, mod_, context, locals, param_count, removed_inits, failed,
      )
    })
    match gto_field_access(instr) {
      Some((@lib.TypeIdx(t), @lib.U32(f), read, _)) => {
        let next = maps[t.to_int()][f.to_int()]
        if next < 0 && !read {
          out.push(@lib.Instruction::drop())
          out.push(@lib.Instruction::ref_as_non_null())
          out.push(@lib.Instruction::drop())
        } else if next >= 0 {
          out.push(gto_remap_field(instr, @lib.U32::new(next.to_uint())))
        } else {
          failed[0] = true
          out.push(instr)
        }
        continue
      }
      _ => ()
    }
    match instr {
      @lib.StructNew(@lib.TypeIdx(t)) => {
        let map = maps[t.to_int()]
        let mut changed = false
        let mut reordered = false
        let mut prev = -1
        for i, n in map {
          if i != n {
            changed = true
          }
          if n >= 0 {
            if n < prev {
              reordered = true
            }
            prev = n
          }
        }
        if !changed {
          out.push(instr)
          continue
        }
        let ranges : Array[(Int, Int)] = []
        let mut end = pos
        for _ in map {
          let start = gto_operand_start(
            mod_,
            context.func_type_idxs,
            instrs,
            end - 1,
          )
          if start < 0 {
            failed[0] = true
            return expr
          }
          ranges.push((start, end))
          end = start
        }
        let ranges = ranges.rev()
        while out.length() > starts[end] {
          ignore(out.pop())
        }
        let kept : Array[Array[@lib.Instruction]] = Array::make(
          map.filter(fn(n) { n >= 0 }).length(),
          [],
        )
        for i, range in ranges {
          let (start, end) = range
          let old = gsi_instr_slice(instrs, start, end)
          let body = gto_layout_expr(
              @lib.Expr::new(old),
              maps,
              mod_,
              context,
              locals,
              param_count,
              removed_inits,
              failed,
            ).0
          if map[i] < 0 {
            if !gto_droppable(body) {
              if locals is None {
                let fields = match context.subtypes[t.to_int()].get_comptype() {
                  @lib.StructCompType(f) => f
                  _ => {
                    failed[0] = true
                    return expr
                  }
                }
                removed_inits.push(
                  @lib.Global::new(
                    @lib.GlobalType::new(fields[i].unpack(), false),
                    @lib.Expr::new(body),
                  ),
                )
              } else {
                out.append(body)
                out.push(@lib.Instruction::drop())
              }
            }
          } else if reordered {
            if gto_droppable(body) &&
              body.all(fn(i) {
                !(i is @lib.LocalGet(_) ||
                i is @lib.GlobalGet(_) ||
                i is @lib.MemorySize(_) ||
                i is @lib.TableSize(_))
              }) {
              kept[map[i]] = body
            } else {
              let local_types = match locals {
                Some(l) => l
                None => {
                  failed[0] = true
                  return expr
                }
              }
              let fields = match context.subtypes[t.to_int()].get_comptype() {
                @lib.StructCompType(f) => f
                _ => {
                  failed[0] = true
                  return expr
                }
              }
              let vt = fields[i].unpack()
              let local_type = match vt {
                @lib.RefTypeValType(r) =>
                  @lib.ValType::ref_type(r.make_nullable())
                _ => vt
              }
              let slot = @lib.LocalIdx::new(
                (param_count + local_types.length()).to_uint(),
              )
              local_types.push(local_type)
              out.append(body)
              out.push(@lib.Instruction::local_set(slot))
              let reload = [@lib.Instruction::local_get(slot)]
              if local_type != vt {
                reload.push(@lib.Instruction::ref_as_non_null())
              }
              kept[map[i]] = reload
            }
          } else {
            out.append(body)
          }
        }
        if reordered {
          for body in kept {
            out.append(body)
          }
        }
        if kept.is_empty() {
          out.push(@lib.Instruction::struct_new_default(@lib.TypeIdx::new(t)))
        } else {
          out.push(instr)
        }
      }
      _ => out.push(instr)
    }
  }
  @lib.Expr::new(out)
}

///|
fn gto_optimize_fields(mod_ : @lib.Module) -> @lib.Module {
  let mod_ = pass_cleanup_unused_type_groups(gto_canonicalize_types(mod_))
  let recs = match mod_.type_sec {
    Some(@lib.TypeSec(t)) => t
    None => return mod_
  }
  let context = @ir.hot_module_context_from_module(mod_)
  let types = context.subtypes
  let bases : Array[Int] = []
  for rec in recs {
    let base = bases.length()
    match rec {
      @lib.SingleRecType(_) => bases.push(base)
      @lib.GroupRecType(g) =>
        for _ in g {
          bases.push(base)
        }
    }
  }
  let public_ = gto_public_types(mod_, context, bases)
  let fields = types.map(fn(t) {
    match t.get_comptype() {
      @lib.StructCompType(f) => f
      _ => []
    }
  })
  let reads = fields.map(fn(f) { Array::make(f.length(), false) })
  let writes = fields.map(fn(f) { Array::make(f.length(), false) })
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for @lib.Func(_, body) in funcs {
        gto_scan_fields(body, reads, writes)
      }
    None => ()
  }
  ignore(
    gto_map_initializers(mod_, fn(body) {
      gto_scan_fields(body, reads, writes)
      body
    }),
  )
  // Descriptor prototype handling has additional host constraints. The
  // descriptor-specific stage handles those groups after ordinary structs.
  for i, t in types {
    if t.describes_type() is Some(_) || t.descriptor_type() is Some(_) {
      public_[i] = true
    }
  }
  let parents = types.map(fn(t) {
    match t.super_types() {
      [@lib.TypeIdx(i), ..] => i.to_int()
      _ => -1
    }
  })
  let all_reads = reads.map(fn(r) { r.copy() })
  let all_writes = writes.map(fn(r) { r.copy() })
  let mut changed = true
  while changed {
    changed = false
    for i, p in parents {
      if p < 0 {
        continue
      }
      for f = 0; f < fields[p].length(); f = f + 1 {
        let r = all_reads[p][f] || all_reads[i][f] || public_[p] || public_[i]
        let w = all_writes[p][f] || all_writes[i][f] || public_[p] || public_[i]
        if r != all_reads[p][f] ||
          r != all_reads[i][f] ||
          w != all_writes[p][f] ||
          w != all_writes[i][f] {
          changed = true
        }
        all_reads[p][f] = r
        all_reads[i][f] = r
        all_writes[p][f] = w
        all_writes[i][f] = w
      }
    }
  }
  let maps = fields.map(fn(f) { Array::make(f.length(), -1) })
  let immutable = fields.map(fn(f) { Array::make(f.length(), false) })
  let next_types : Array[@lib.SubType] = []
  let mut any_change = false
  for i, subtype in types {
    let p = parents[i]
    if p >= 0 {
      for f = 0; f < fields[p].length(); f = f + 1 {
        reads[i][f] = reads[i][f] || reads[p][f]
        writes[i][f] = writes[i][f] || writes[p][f]
      }
    }
    let mut next = 0
    let mut inherited = 0
    if p >= 0 {
      inherited = fields[p].length()
      for f = 0; f < inherited; f = f + 1 {
        if maps[p][f] >= 0 {
          maps[i][f] = maps[p][f]
          next = Int::max(next, maps[p][f] + 1)
        }
      }
    }
    for f = 0; f < fields[i].length(); f = f + 1 {
      let removable = !public_[i] &&
        (!all_reads[i][f] || (!reads[i][f] && !writes[i][f]))
      if maps[i][f] < 0 && !removable {
        maps[i][f] = next
        next += 1
      }
      immutable[i][f] = !public_[i] &&
        !all_writes[i][f] &&
        (f >= inherited || immutable[p][f])
      if maps[i][f] != f ||
        (immutable[i][f] && fields[i][f] is @lib.FieldType(_, @lib.Var)) {
        any_change = true
      }
    }
    let comp = match subtype.get_comptype() {
      @lib.StructCompType(_) => {
        let out = Array::make(next, gto_placeholder_field())
        for f, field in fields[i] {
          if maps[i][f] >= 0 {
            let @lib.FieldType(storage, mutability) = field
            out[maps[i][f]] = @lib.FieldType::new(
              storage,
              if immutable[i][f] {
                @lib.Mut::const_()
              } else {
                mutability
              },
            )
          }
        }
        @lib.CompType::struct_(out)
      }
      comp => comp
    }
    next_types.push(
      match subtype {
        @lib.SubType(final_, supers, metadata, _) =>
          @lib.SubType::new(final_, supers, comp, metadata~)
        @lib.CompTypeSubType(metadata, _) =>
          @lib.SubType::comp_type(comp, metadata~)
      },
    )
  }
  if !any_change {
    return mod_
  }
  let failed = [false]
  let removed_inits : Array[@lib.Global] = []
  let mut candidate = gto_map_initializers(mod_, fn(body) {
    gto_layout_expr(body, maps, mod_, context, None, 0, removed_inits, failed)
  })
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let imported = context.func_type_idxs.length() - funcs.length()
      let next_funcs : Array[@lib.Func] = []
      for i, @lib.Func(locals, body) in funcs {
        let locals = locals.copy()
        let @lib.FuncType(params, _) = context.func_types[imported + i]
        let body = gto_layout_expr(
          body,
          maps,
          mod_,
          context,
          Some(locals),
          params.length(),
          removed_inits,
          failed,
        )
        next_funcs.push(@lib.Func::new(locals, body))
      }
      candidate = candidate.with_code_sec(@lib.CodeSec::new(next_funcs))
    }
    None => ()
  }
  if failed[0] {
    return mod_
  }
  if !removed_inits.is_empty() {
    let globals = match candidate.global_sec {
      Some(@lib.GlobalSec(gs)) => gs.copy()
      None => []
    }
    globals.append(removed_inits)
    candidate = candidate.with_global_sec(@lib.GlobalSec::new(globals))
  }
  let next_recs : Array[@lib.RecType] = []
  let mut index = 0
  for rec in recs {
    match rec {
      @lib.SingleRecType(_) => {
        next_recs.push(@lib.RecType::new(next_types[index]))
        index += 1
      }
      @lib.GroupRecType(group) => {
        let next : Array[@lib.SubType] = []
        for _ in group {
          next.push(next_types[index])
          index += 1
        }
        next_recs.push(@lib.RecType::group(next))
      }
    }
  }
  candidate = candidate.with_type_sec(@lib.TypeSec::new(next_recs))
  match mod_.name_sec {
    Some(names) => {
      let field_names = names.field_names.map(fn(name_map) {
        let @lib.IndirectNameMap(entries) = name_map
        @lib.IndirectNameMap::new(
          entries.map(fn(entry) {
            let @lib.IndirectNameAssoc(t, @lib.NameMap(names)) = entry
            let retained : Array[@lib.NameAssoc] = []
            for @lib.NameAssoc(f, name) in names {
              let n = maps[t.to_int()][f.to_int()]
              if n >= 0 {
                retained.push(@lib.NameAssoc::new(n.to_uint(), name))
              }
            }
            retained.sort_by(fn(a, b) {
              let @lib.NameAssoc(a, _) = a
              let @lib.NameAssoc(b, _) = b
              a.compare(b)
            })
            @lib.IndirectNameAssoc::new(t, @lib.NameMap::new(retained))
          }),
        )
      })
      candidate = candidate.with_name_sec(
        @lib.NameSec::new(
          module_name=names.module_name,
          func_names=names.func_names,
          local_names=names.local_names,
          label_names=names.label_names,
          type_names=names.type_names,
          field_names~,
          table_names=names.table_names,
          memory_names=names.memory_names,
          global_names=names.global_names,
          elem_names=names.elem_names,
          data_names=names.data_names,
          tag_names=names.tag_names,
        ),
      )
    }
    None => ()
  }
  let type_order = gto_collect_type_order(
    candidate.with_type_sec(mod_.type_sec.unwrap()),
  )
  let candidate = gto_regroup_private_types(candidate, public_, type_order)
  if @validate.validate_module(candidate).is_ok() {
    candidate
  } else {
    mod_
  }
}

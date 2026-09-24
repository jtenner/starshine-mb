///|
fn mso_shared_i31(nullable : Bool) -> @lib.ValType {
  @lib.ValType::ref_type(
    @lib.RefType::new(
      nullable,
      @lib.HeapType::shared_abs(@lib.AbsHeapType::i31()),
    ),
  )
}

///|
fn mso_shared_any(nullable : Bool) -> @lib.ValType {
  @lib.ValType::ref_type(
    @lib.RefType::new(
      nullable,
      @lib.HeapType::shared_abs(@lib.AbsHeapType::any()),
    ),
  )
}

///|
fn mso_function_type(types : Array[@lib.SubType], idx : @lib.TypeIdx) -> Bool {
  match idx {
    @lib.TypeIdx(raw) if raw.to_int() < types.length() =>
      types[raw.to_int()].get_comptype() is @lib.FuncCompType(_, _)
    _ => false
  }
}

///|
fn mso_rewrite_heap_type(
  heap : @lib.HeapType,
  types : Array[@lib.SubType],
) -> @lib.HeapType {
  match heap {
    @lib.AbsHeapTypeHeapType(@lib.FuncAbsHeapType)
    | @lib.SharedAbsHeapTypeHeapType(@lib.FuncAbsHeapType)
    | @lib.AbsHeapTypeHeapType(@lib.ExternAbsHeapType) =>
      @lib.HeapType::shared_abs(@lib.AbsHeapType::i31())
    @lib.HeapType(idx) if mso_function_type(types, idx) =>
      @lib.HeapType::shared_abs(@lib.AbsHeapType::i31())
    @lib.AbsHeapTypeHeapType(@lib.NoFuncAbsHeapType)
    | @lib.SharedAbsHeapTypeHeapType(@lib.NoFuncAbsHeapType)
    | @lib.AbsHeapTypeHeapType(@lib.NoExternAbsHeapType) =>
      @lib.HeapType::shared_abs(@lib.AbsHeapType::none())
    @lib.AbsHeapTypeHeapType(abs) => @lib.HeapType::shared_abs(abs)
    _ => heap
  }
}

///|
fn mso_rewrite_val_type(
  vt : @lib.ValType,
  types : Array[@lib.SubType],
) -> @lib.ValType {
  match vt {
    @lib.RefTypeValType(ref_type) =>
      @lib.ValType::ref_type(
        @lib.RefType::new(
          ref_type.is_nullable(),
          mso_rewrite_heap_type(ref_type.get_heap_type(), types),
          exact=ref_type.is_exact(),
        ),
      )
    _ => vt
  }
}

///|
fn mso_rewrite_field(
  field : @lib.FieldType,
  types : Array[@lib.SubType],
) -> @lib.FieldType {
  let @lib.FieldType(storage, mutability) = field
  match storage {
    @lib.ValTypeStorageType(vt) =>
      @lib.FieldType::new(
        @lib.StorageType::val_type(mso_rewrite_val_type(vt, types)),
        mutability,
      )
    _ => field
  }
}

///|
fn mso_rewrite_subtype(
  subtype : @lib.SubType,
  types : Array[@lib.SubType],
) -> @lib.SubType {
  let comp_type = subtype.get_comptype()
  let next_comp = match comp_type {
    @lib.FuncCompType(params, results) => {
      let next_params = params.map(fn(vt) { mso_rewrite_val_type(vt, types) })
      let next_results = results.map(fn(vt) { mso_rewrite_val_type(vt, types) })
      @lib.CompType::func(next_params, next_results)
    }
    @lib.StructCompType(fields) =>
      @lib.CompType::struct_(
        fields.map(fn(field) { mso_rewrite_field(field, types) }),
      )
    @lib.ArrayCompType(field) =>
      @lib.CompType::array(mso_rewrite_field(field, types))
    _ => comp_type
  }
  let shared = comp_type is @lib.StructCompType(_) ||
    comp_type is @lib.ArrayCompType(_)
  match subtype {
    @lib.SubType(final_, supers, metadata, _) =>
      @lib.SubType::new(
        final_,
        supers,
        next_comp,
        metadata=metadata.with_shared(shared),
      )
    @lib.CompTypeSubType(metadata, _) =>
      @lib.SubType::comp_type(next_comp, metadata=metadata.with_shared(shared))
  }
}

///|
fn mso_rewrite_expr(
  expr : @lib.Expr,
  types : Array[@lib.SubType],
  refs : MsoReferences,
  function_table : @lib.TableIdx,
  scratch? : (@lib.Locals, Int)? = None,
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.RefFunc(@lib.FuncIdx(raw)) => {
        out.push(
          @lib.Instruction::i32_const(@lib.I32(refs.index(raw).to_int())),
        )
        out.push(@lib.Instruction::ref_i31_shared())
      }
      @lib.RefNull(ref_type) =>
        out.push(
          @lib.Instruction::ref_null_type(
            @lib.RefType::new(
              ref_type.is_nullable(),
              mso_rewrite_heap_type(ref_type.get_heap_type(), types),
              exact=ref_type.is_exact(),
            ),
          ),
        )
      @lib.Block(block_type, body) =>
        out.push(
          @lib.Instruction::block(
            mso_refinalized_block_type(block_type, body, types),
            mso_rewrite_expr(body, types, refs, function_table, scratch~),
          ),
        )
      @lib.Loop(block_type, body) =>
        out.push(
          @lib.Instruction::loop_(
            mso_rewrite_block_type(block_type, types),
            mso_rewrite_expr(body, types, refs, function_table, scratch~),
          ),
        )
      @lib.If(block_type, then_body, else_body) => {
        let @lib.Expr(next_then) = mso_rewrite_expr(
          @lib.Expr::new(then_body),
          types,
          refs,
          function_table,
          scratch~,
        )
        let next_else = match else_body {
          Some(body) => {
            let @lib.Expr(next_body) = mso_rewrite_expr(
              @lib.Expr::new(body),
              types,
              refs,
              function_table,
              scratch~,
            )
            Some(next_body)
          }
          None => None
        }
        out.push(
          @lib.Instruction::if_(
            mso_rewrite_block_type(block_type, types),
            next_then,
            next_else,
          ),
        )
      }
      @lib.RefI31 => out.push(@lib.Instruction::ref_i31_shared())
      @lib.CallRef(t) => {
        if mso_emit_null_call(out, types, t) {
          continue
        }
        out.push(@lib.Instruction::i31_get_u())
        out.push(@lib.Instruction::call_indirect(t, function_table))
      }
      @lib.ReturnCallRef(t) => {
        if mso_emit_null_call(out, types, t) {
          continue
        }
        out.push(@lib.Instruction::i31_get_u())
        out.push(@lib.Instruction::return_call_indirect(t, function_table))
      }
      @lib.CallIndirect(t, table) => {
        out.push(@lib.Instruction::table_get(table))
        out.push(@lib.Instruction::i31_get_u())
        out.push(@lib.Instruction::call_indirect(t, function_table))
      }
      @lib.ReturnCallIndirect(t, table) => {
        out.push(@lib.Instruction::table_get(table))
        out.push(@lib.Instruction::i31_get_u())
        out.push(@lib.Instruction::return_call_indirect(t, function_table))
      }
      @lib.TryTable(bt, catches, body) =>
        out.push(
          @lib.Instruction::try_table(
            mso_rewrite_block_type(bt, types),
            catches,
            mso_rewrite_expr(body, types, refs, function_table, scratch~),
          ),
        )
      @lib.RefTest(nullable, exact, heap) =>
        if heap is @lib.HeapType(t) && mso_function_type(types, t) {
          mso_signature_cast(
            out, instr, nullable, exact, heap, function_table, scratch, true,
          )
        } else {
          out.push(
            @lib.Instruction::ref_test_type(
              @lib.RefType::new(
                nullable,
                mso_rewrite_heap_type(heap, types),
                exact~,
              ),
            ),
          )
        }
      @lib.RefCast(nullable, exact, heap) =>
        if heap is @lib.HeapType(t) && mso_function_type(types, t) {
          mso_signature_cast(
            out, instr, nullable, exact, heap, function_table, scratch, false,
          )
        } else {
          out.push(
            @lib.Instruction::ref_cast_type(
              @lib.RefType::new(
                nullable,
                mso_rewrite_heap_type(heap, types),
                exact~,
              ),
            ),
          )
        }
      @lib.Select(Some(values)) =>
        out.push(
          @lib.Instruction::select(
            types=Some(values.map(fn(v) { mso_rewrite_val_type(v, types) })),
          ),
        )
      @lib.BrOnCast(label, op, source, target) =>
        out.push(
          @lib.Instruction::br_on_cast(
            label,
            op.source_nullable(),
            mso_rewrite_heap_type(source, types),
            op.target_nullable(),
            mso_rewrite_heap_type(target, types),
            source_exact=op.source_exact(),
            target_exact=op.target_exact(),
          ),
        )
      @lib.BrOnCastFail(label, op, source, target) =>
        out.push(
          @lib.Instruction::br_on_cast_fail(
            label,
            op.source_nullable(),
            mso_rewrite_heap_type(source, types),
            op.target_nullable(),
            mso_rewrite_heap_type(target, types),
            source_exact=op.source_exact(),
            target_exact=op.target_exact(),
          ),
        )
      @lib.Try(bt, body, catches, delegate) => {
        let body = mso_rewrite_expr(body, types, refs, function_table, scratch~)
        let catches = catches.map(fn(c) {
          match c {
            @lib.LegacyCatch(tag, expr) =>
              @lib.LegacyCatch::tagged(
                tag,
                mso_rewrite_expr(expr, types, refs, function_table, scratch~),
              )
            @lib.LegacyCatchAll(expr) =>
              @lib.LegacyCatch::all(
                mso_rewrite_expr(expr, types, refs, function_table, scratch~),
              )
          }
        })
        out.push(
          @lib.Instruction::try_(
            mso_rewrite_block_type(bt, types),
            body,
            catches,
            delegate~,
          ),
        )
      }
      _ => out.push(instr)
    }
  }
  @lib.Expr::new(out)
}

///|
fn mso_rewrite_block_type(
  block_type : @lib.BlockType,
  types : Array[@lib.SubType],
) -> @lib.BlockType {
  match block_type {
    @lib.ValTypeBlockType(vt) =>
      @lib.BlockType::val_type(mso_rewrite_val_type(vt, types))
    _ => block_type
  }
}

///|
fn mso_rewrite_locals(
  locals : @lib.Locals,
  types : Array[@lib.SubType],
) -> @lib.Locals {
  let runs : Array[@lib.LocalRun] = []
  for run in locals.runs {
    runs.push(
      @lib.LocalRun::new(
        run.count(),
        mso_rewrite_val_type(run.val_type(), types),
      ),
    )
  }
  @lib.Locals::new(runs)
}

///|
fn mso_rewrite_ref_type(
  ref_type : @lib.RefType,
  types : Array[@lib.SubType],
) -> @lib.RefType {
  @lib.RefType::new(
    ref_type.is_nullable(),
    mso_rewrite_heap_type(ref_type.get_heap_type(), types),
    exact=ref_type.is_exact(),
  )
}

///|
fn mso_rewrite_elem(
  elem : @lib.Elem,
  types : Array[@lib.SubType],
  refs : MsoReferences,
  function_table : @lib.TableIdx,
) -> @lib.Elem {
  let @lib.Elem(mode, kind) = elem
  let next_mode = match mode {
    @lib.Active(table_idx, offset) =>
      @lib.ElemMode::active(
        table_idx,
        mso_rewrite_expr(offset, types, refs, function_table),
      )
    _ => mode
  }
  let next_kind = match kind {
    @lib.FuncsElemKind(indices) => {
      let values : Array[@lib.Expr] = []
      for @lib.FuncIdx(raw) in indices {
        values.push(
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(refs.index(raw).to_int())),
            @lib.Instruction::ref_i31_shared(),
          ]),
        )
      }
      @lib.ElemKind::typed_exprs(
        @lib.RefType::new(
          true,
          @lib.HeapType::shared_abs(@lib.AbsHeapType::i31()),
        ),
        values,
      )
    }
    @lib.FuncExprsElemKind(values) =>
      @lib.ElemKind::typed_exprs(
        @lib.RefType::new(
          true,
          @lib.HeapType::shared_abs(@lib.AbsHeapType::i31()),
        ),
        values.map(fn(value) {
          mso_rewrite_expr(value, types, refs, function_table)
        }),
      )
    @lib.TypedExprsElemKind(ref_type, values) =>
      @lib.ElemKind::typed_exprs(
        mso_rewrite_ref_type(ref_type, types),
        values.map(fn(value) {
          mso_rewrite_expr(value, types, refs, function_table)
        }),
      )
  }
  @lib.Elem::new(next_mode, next_kind)
}

///|
fn mso_is_extern(vt : @lib.ValType) -> Bool {
  match vt {
    @lib.RefTypeValType(ref_type) =>
      ref_type.get_heap_type()
      is @lib.AbsHeapTypeHeapType(@lib.ExternAbsHeapType)
    _ => false
  }
}

///|
fn mso_signature(
  types : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> (Array[@lib.ValType], Array[@lib.ValType])? {
  match type_idx {
    @lib.TypeIdx(raw) if raw.to_int() < types.length() =>
      match types[raw.to_int()].get_comptype() {
        @lib.FuncCompType(params, results) => Some((params, results))
        _ => None
      }
    _ => None
  }
}

///|
fn mso_signature_has_extern(
  types : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> Bool {
  match mso_signature(types, type_idx) {
    Some((params, results)) =>
      params.any(mso_is_extern) || results.any(mso_is_extern)
    None => false
  }
}

///|
fn mso_boundary_type(
  vt : @lib.ValType,
  types : Array[@lib.SubType],
) -> @lib.ValType {
  if mso_is_extern(vt) {
    vt
  } else {
    mso_rewrite_val_type(vt, types)
  }
}

///|
fn mso_append_signature(
  rec_types : Array[@lib.RecType],
  params : Array[@lib.ValType],
  results : Array[@lib.ValType],
  flat_count : Array[Int],
) -> @lib.TypeIdx {
  let idx = @lib.TypeIdx::new(flat_count[0].to_uint())
  flat_count[0] += 1
  rec_types.push(
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func(params, results)),
    ),
  )
  idx
}

///|
fn mso_convert_to_index(
  out : Array[@lib.Instruction],
  source : @lib.ValType,
  helper : @lib.FuncIdx,
) -> Unit {
  if mso_is_extern(source) {
    out.push(@lib.Instruction::call(helper))
    match source {
      @lib.RefTypeValType(ref_type) if !ref_type.is_nullable() =>
        out.push(@lib.Instruction::ref_as_non_null())
      _ => ()
    }
  }
}

///|
fn mso_convert_to_ref(
  out : Array[@lib.Instruction],
  target : @lib.ValType,
  helper : @lib.FuncIdx,
) -> Unit {
  if mso_is_extern(target) {
    out.push(@lib.Instruction::call(helper))
    match target {
      @lib.RefTypeValType(ref_type) if !ref_type.is_nullable() =>
        out.push(@lib.Instruction::ref_as_non_null())
      _ => ()
    }
  }
}

///|
fn mso_to_index_func(table_idx : @lib.TableIdx) -> @lib.Func {
  let shared_i31 = mso_shared_i31(true)
  let shared_i31_nonnull = mso_shared_i31(false)
  let nullable_result = @lib.BlockType::val_type(shared_i31)
  let nonnull_result = @lib.BlockType::val_type(shared_i31_nonnull)
  @lib.Func::new(
    @lib.Locals::single(1U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_is_null(),
      @lib.Instruction::if_(
        nullable_result,
        [
          @lib.Instruction::ref_null(
            @lib.HeapType::shared_abs(@lib.AbsHeapType::none()),
          ),
        ],
        Some([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::table_grow(table_idx),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::i32_ge_s(),
          @lib.Instruction::if_(
            nonnull_result,
            [
              @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
              @lib.Instruction::ref_i31_shared(),
            ],
            Some([@lib.Instruction::unreachable_()]),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn mso_to_ref_func(table_idx : @lib.TableIdx) -> @lib.Func {
  @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_is_null(),
      @lib.Instruction::if_(
        @lib.BlockType::val_type(@lib.ValType::externref()),
        [
          @lib.Instruction::ref_null(
            @lib.HeapType::abs(@lib.AbsHeapType::no_extern()),
          ),
        ],
        Some([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i31_get_u(),
          @lib.Instruction::table_get(table_idx),
        ]),
      ),
    ]),
  )
}

///|
fn mso_retarget_import_calls(
  expr : @lib.Expr,
  redirects : Map[UInt, UInt],
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.Call(@lib.FuncIdx(raw)) =>
        out.push(
          @lib.Instruction::call(
            @lib.FuncIdx::new(redirects.get(raw).unwrap_or(raw)),
          ),
        )
      @lib.ReturnCall(@lib.FuncIdx(raw)) =>
        out.push(
          @lib.Instruction::return_call(
            @lib.FuncIdx::new(redirects.get(raw).unwrap_or(raw)),
          ),
        )
      @lib.Block(bt, body) =>
        out.push(
          @lib.Instruction::block(
            bt,
            mso_retarget_import_calls(body, redirects),
          ),
        )
      @lib.Loop(bt, body) =>
        out.push(
          @lib.Instruction::loop_(
            bt,
            mso_retarget_import_calls(body, redirects),
          ),
        )
      @lib.If(bt, yes, no) => {
        let @lib.Expr(next_yes) = mso_retarget_import_calls(
          @lib.Expr::new(yes),
          redirects,
        )
        let next_no = match no {
          Some(body) => {
            let @lib.Expr(next_body) = mso_retarget_import_calls(
              @lib.Expr::new(body),
              redirects,
            )
            Some(next_body)
          }
          None => None
        }
        out.push(@lib.Instruction::if_(bt, next_yes, next_no))
      }
      _ => out.push(instr)
    }
  }
  @lib.Expr::new(out)
}

///|
fn mso_scan_conversions(
  expr : @lib.Expr,
  needs_any_to_extern : Array[Bool],
  needs_extern_to_any : Array[Bool],
) -> Unit {
  let @lib.Expr(instrs) = expr
  for instr in instrs {
    match instr {
      @lib.ExternConvertAny => needs_any_to_extern[0] = true
      @lib.AnyConvertExtern => needs_extern_to_any[0] = true
      @lib.Block(_, body) | @lib.Loop(_, body) =>
        mso_scan_conversions(body, needs_any_to_extern, needs_extern_to_any)
      @lib.If(_, yes, no) => {
        mso_scan_conversions(
          @lib.Expr::new(yes),
          needs_any_to_extern,
          needs_extern_to_any,
        )
        match no {
          Some(body) =>
            mso_scan_conversions(
              @lib.Expr::new(body),
              needs_any_to_extern,
              needs_extern_to_any,
            )
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
fn mso_rewrite_conversions(
  expr : @lib.Expr,
  any_to_extern : @lib.FuncIdx?,
  extern_to_any : @lib.FuncIdx?,
  to_index : @lib.FuncIdx,
  to_ref : @lib.FuncIdx,
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.ExternConvertAny => {
        out.push(@lib.Instruction::call(any_to_extern.unwrap()))
        out.push(@lib.Instruction::call(to_index))
      }
      @lib.AnyConvertExtern => {
        out.push(@lib.Instruction::call(to_ref))
        out.push(@lib.Instruction::call(extern_to_any.unwrap()))
      }
      @lib.Block(bt, body) =>
        out.push(
          @lib.Instruction::block(
            bt,
            mso_rewrite_conversions(
              body, any_to_extern, extern_to_any, to_index, to_ref,
            ),
          ),
        )
      @lib.Loop(bt, body) =>
        out.push(
          @lib.Instruction::loop_(
            bt,
            mso_rewrite_conversions(
              body, any_to_extern, extern_to_any, to_index, to_ref,
            ),
          ),
        )
      @lib.If(bt, yes, no) => {
        let @lib.Expr(next_yes) = mso_rewrite_conversions(
          @lib.Expr::new(yes),
          any_to_extern,
          extern_to_any,
          to_index,
          to_ref,
        )
        let next_no = match no {
          Some(body) => {
            let @lib.Expr(next_body) = mso_rewrite_conversions(
              @lib.Expr::new(body),
              any_to_extern,
              extern_to_any,
              to_index,
              to_ref,
            )
            Some(next_body)
          }
          None => None
        }
        out.push(@lib.Instruction::if_(bt, next_yes, next_no))
      }
      _ => out.push(instr)
    }
  }
  @lib.Expr::new(out)
}

///|
fn make_shared_objects_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  // This intrinsic requires its last argument to remain a function reference.
  // Replacing it with a shared i31 makes the module invalid under Binaryen 133.
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(module_name, field_name, @lib.FuncExternType(_)) if module_name ==
            @lib.Name::from_string("binaryen-intrinsics") &&
            field_name == @lib.Name::from_string("call.without.effects") =>
            return mod_
          _ => ()
        }
      }
    None => ()
  }
  let rec_types = match mod_.type_sec {
    Some(@lib.TypeSec(types)) => types
    None => return mod_
  }
  let types = cl_module_subtypes(mod_)
  let refs = mso_collect_references(mod_, types)
  let original_table_count = @ir.hot_module_context_from_module(mod_).tables.length()
  let function_table = @lib.TableIdx::new(original_table_count.to_uint())
  let rewritten_types : Array[@lib.RecType] = []
  for rec_type in rec_types {
    match rec_type {
      @lib.SingleRecType(subtype) =>
        rewritten_types.push(
          @lib.RecType::new(mso_rewrite_subtype(subtype, types)),
        )
      @lib.GroupRecType(group) =>
        rewritten_types.push(
          @lib.RecType::group(
            group.map(fn(subtype) { mso_rewrite_subtype(subtype, types) }),
          ),
        )
    }
  }
  let orig_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => []
  }
  let needs_any_to_extern = [false]
  let needs_extern_to_any = [false]
  for func in orig_funcs {
    let @lib.Func(_, body) = func
    mso_scan_conversions(body, needs_any_to_extern, needs_extern_to_any)
  }
  let orig_func_types = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs
    None => []
  }
  let orig_imports = match mod_.import_sec {
    Some(@lib.ImportSec(imports)) => imports
    None => []
  }
  let orig_exports = match mod_.export_sec {
    Some(@lib.ExportSec(exports)) => exports
    None => []
  }
  let all_func_types : Array[@lib.TypeIdx] = []
  let import_specs : Array[(UInt, @lib.TypeIdx)] = []
  let mut import_count = 0
  for import_ in orig_imports {
    match import_ {
      @lib.Import(_, _, @lib.FuncExternType(type_idx)) => {
        all_func_types.push(type_idx)
        if mso_signature_has_extern(types, type_idx) {
          import_specs.push((import_count.to_uint(), type_idx))
        }
        import_count += 1
      }
      _ => ()
    }
  }
  for type_idx in orig_func_types {
    all_func_types.push(type_idx)
  }
  let export_specs : Array[(UInt, @lib.TypeIdx)] = []
  let export_redirects : Map[UInt, UInt] = Map([])
  for export_ in orig_exports {
    match export_ {
      @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(raw))) if raw.to_int() <
        all_func_types.length() => {
        let type_idx = all_func_types[raw.to_int()]
        if mso_signature_has_extern(types, type_idx) &&
          !export_redirects.contains(raw) {
          export_specs.push((raw, type_idx))
          export_redirects[raw] = raw
        }
      }
      _ => ()
    }
  }
  let base = import_count + orig_funcs.length()
  let to_index_idx = @lib.FuncIdx::new(
    (base + import_specs.length() + export_specs.length()).to_uint(),
  )
  let to_ref_idx = @lib.FuncIdx::new(
    (base + import_specs.length() + export_specs.length() + 1).to_uint(),
  )
  let flat_count = [types.length()]
  let next_imports : Array[@lib.Import] = []
  let redirects : Map[UInt, UInt] = Map([])
  for import_ in orig_imports {
    match import_ {
      @lib.Import(module_name, field_name, @lib.FuncExternType(type_idx)) => {
        let boundary_idx = if mso_signature_has_extern(types, type_idx) {
          let (params, results) = mso_signature(types, type_idx).unwrap()
          let boundary_params = params.map(fn(vt) {
            mso_boundary_type(vt, types)
          })
          let boundary_results = results.map(fn(vt) {
            mso_boundary_type(vt, types)
          })
          mso_append_signature(
            rewritten_types, boundary_params, boundary_results, flat_count,
          )
        } else {
          type_idx
        }
        next_imports.push(
          @lib.Import::new(
            module_name,
            field_name,
            @lib.ExternType::func(boundary_idx),
          ),
        )
      }
      @lib.Import(
        module_name,
        field_name,
        @lib.GlobalExternType(@lib.GlobalType(vt, mutable_))
      ) =>
        next_imports.push(
          @lib.Import::new(
            module_name,
            field_name,
            @lib.ExternType::global(
              @lib.GlobalType::new(mso_rewrite_val_type(vt, types), mutable_),
            ),
          ),
        )
      @lib.Import(
        module_name,
        field_name,
        @lib.TableExternType(@lib.TableType(rt, limits))
      ) =>
        next_imports.push(
          @lib.Import::new(
            module_name,
            field_name,
            @lib.ExternType::table(
              @lib.TableType::new(mso_rewrite_ref_type(rt, types), limits),
            ),
          ),
        )
      _ => next_imports.push(import_)
    }
  }
  let next_exports = orig_exports.copy()
  let next_func_types = orig_func_types.copy()
  let next_funcs : Array[@lib.Func] = []
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for ordinal, @lib.Func(locals, body) in funcs {
        let locals = mso_rewrite_locals(locals, types)
        let (params, _) = mso_signature(
          types,
          all_func_types[import_count + ordinal],
        ).unwrap()
        let body = mso_rewrite_expr(
          body,
          types,
          refs,
          function_table,
          scratch=Some((locals, params.length())),
        )
        next_funcs.push(@lib.Func::new(locals, body))
      }
    None => ()
  }
  for ordinal, spec in import_specs {
    let (import_idx, type_idx) = spec
    redirects[import_idx] = (base + ordinal).to_uint()
    let (params, results) = mso_signature(types, type_idx).unwrap()
    if results.length() > 1 {
      return mod_
    }
    let body : Array[@lib.Instruction] = []
    for i, param in params {
      body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(i.to_uint())))
      mso_convert_to_ref(body, param, to_ref_idx)
    }
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(import_idx)))
    if results.length() == 1 {
      mso_convert_to_index(body, results[0], to_index_idx)
    }
    next_func_types.push(type_idx)
    next_funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)))
  }
  for i = 0; i < orig_funcs.length(); i = i + 1 {
    let @lib.Func(locals, body) = next_funcs[i]
    next_funcs[i] = @lib.Func::new(
      locals,
      mso_retarget_import_calls(body, redirects),
    )
  }
  for ordinal, spec in export_specs {
    let (raw, type_idx) = spec
    let (params, results) = mso_signature(types, type_idx).unwrap()
    if results.length() > 1 {
      return mod_
    }
    let boundary_idx = mso_append_signature(
      rewritten_types,
      params.map(fn(vt) { mso_boundary_type(vt, types) }),
      results.map(fn(vt) { mso_boundary_type(vt, types) }),
      flat_count,
    )
    let body : Array[@lib.Instruction] = []
    for i, param in params {
      body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(i.to_uint())))
      mso_convert_to_index(body, param, to_index_idx)
    }
    let target = redirects.get(raw).unwrap_or(raw)
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(target)))
    if results.length() == 1 {
      mso_convert_to_ref(body, results[0], to_ref_idx)
    }
    next_func_types.push(boundary_idx)
    next_funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)))
    export_redirects[raw] = (base + import_specs.length() + ordinal).to_uint()
  }
  for i, export_ in orig_exports {
    match export_ {
      @lib.Export(name, @lib.FuncExternIdx(@lib.FuncIdx(raw))) =>
        match export_redirects.get(raw) {
          Some(wrapper) =>
            next_exports[i] = @lib.Export::new(
              name,
              @lib.ExternIdx::func(@lib.FuncIdx::new(wrapper)),
            )
          None => ()
        }
      _ => ()
    }
  }
  let mut candidate = mod_.with_type_sec(@lib.TypeSec::new(rewritten_types))
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      candidate = candidate.with_global_sec(
        @lib.GlobalSec::new(
          globals.map(fn(g) {
            let @lib.Global(@lib.GlobalType(vt, mutable_), init) = g
            @lib.Global::new(
              @lib.GlobalType::new(mso_rewrite_val_type(vt, types), mutable_),
              mso_rewrite_expr(init, types, refs, function_table),
            )
          }),
        ),
      )
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) => {
      let next_tables : Array[@lib.Table] = []
      for @lib.Table(@lib.TableType(ref_type, limits), init) in tables {
        next_tables.push(
          @lib.Table::new(
            @lib.TableType::new(mso_rewrite_ref_type(ref_type, types), limits),
            init.map(fn(expr) {
              mso_rewrite_expr(expr, types, refs, function_table)
            }),
          ),
        )
      }
      candidate = candidate.with_table_sec(@lib.TableSec::new(next_tables))
    }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      candidate = candidate.with_elem_sec(
        @lib.ElemSec::new(
          elems.map(fn(elem) {
            mso_rewrite_elem(elem, types, refs, function_table)
          }),
        ),
      )
    None => ()
  }
  if refs.needs_table[0] {
    let tables = match candidate.table_sec {
      Some(@lib.TableSec(ts)) => ts.copy()
      None => []
    }
    tables.push(
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::abs(@lib.AbsHeapType::func()),
          @lib.Limits::i32(
            refs.functions.length().to_uint(),
            Some(refs.functions.length().to_uint()),
          ),
        ),
        None,
      ),
    )
    candidate = candidate.with_table_sec(@lib.TableSec::new(tables))
    if !refs.functions.is_empty() {
      let elems = match candidate.elem_sec {
        Some(@lib.ElemSec(es)) => es.copy()
        None => []
      }
      elems.push(
        @lib.Elem::new(
          @lib.ElemMode::active(
            function_table,
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
          ),
          @lib.ElemKind::funcs(
            refs.functions.map(fn(f) {
              let @lib.FuncIdx(raw) = f
              @lib.FuncIdx::new(redirects.get(raw).unwrap_or(raw))
            }),
          ),
        ),
      )
      candidate = candidate.with_elem_sec(@lib.ElemSec::new(elems))
    }
  }
  if !import_specs.is_empty() ||
    !export_specs.is_empty() ||
    needs_any_to_extern[0] ||
    needs_extern_to_any[0] {
    let table_idx = @lib.TableIdx::new(
      (original_table_count + (if refs.needs_table[0] { 1 } else { 0 })).to_uint(),
    )
    let tables = match candidate.table_sec {
      Some(@lib.TableSec(tables)) => tables.copy()
      None => []
    }
    tables.push(
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::abs(@lib.AbsHeapType::extern_()),
          @lib.Limits::i32(0U, None),
        ),
        None,
      ),
    )
    candidate = candidate.with_table_sec(@lib.TableSec::new(tables))
    next_func_types.push(
      mso_append_signature(
        rewritten_types,
        [@lib.ValType::externref()],
        [mso_shared_i31(true)],
        flat_count,
      ),
    )
    next_funcs.push(mso_to_index_func(table_idx))
    next_func_types.push(
      mso_append_signature(
        rewritten_types,
        [mso_shared_i31(true)],
        [@lib.ValType::externref()],
        flat_count,
      ),
    )
    next_funcs.push(mso_to_ref_func(table_idx))
    candidate = candidate.with_type_sec(@lib.TypeSec::new(rewritten_types))
  }
  if !orig_imports.is_empty() {
    candidate = candidate.with_import_sec(@lib.ImportSec::new(next_imports))
  }
  if !next_exports.is_empty() {
    candidate = candidate.with_export_sec(@lib.ExportSec::new(next_exports))
  }
  if !next_func_types.is_empty() {
    candidate = candidate.with_func_sec(@lib.FuncSec::new(next_func_types))
  }
  if !next_funcs.is_empty() {
    candidate = candidate.with_code_sec(@lib.CodeSec::new(next_funcs))
  }
  let extra_import_count = (if needs_any_to_extern[0] { 1 } else { 0 }) +
    (if needs_extern_to_any[0] { 1 } else { 0 })
  if extra_import_count > 0 {
    let remap : Array[UInt] = []
    for idx = 0; idx < import_count + next_funcs.length(); idx = idx + 1 {
      remap.push(
        (if idx < import_count { idx } else { idx + extra_import_count }).to_uint(),
      )
    }
    candidate = dfe_rewrite_module_func_idxs(candidate, remap)
    let mut host_any_to_extern : @lib.FuncIdx? = None
    let mut host_extern_to_any : @lib.FuncIdx? = None
    if needs_any_to_extern[0] {
      let idx = mso_append_signature(
        rewritten_types,
        [mso_shared_any(true)],
        [@lib.ValType::externref()],
        flat_count,
      )
      host_any_to_extern = Some(@lib.FuncIdx::new(import_count.to_uint()))
      next_imports.push(
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("any_to_extern"),
          @lib.ExternType::func(idx),
        ),
      )
    }
    if needs_extern_to_any[0] {
      let idx = mso_append_signature(
        rewritten_types,
        [@lib.ValType::externref()],
        [mso_shared_any(true)],
        flat_count,
      )
      host_extern_to_any = Some(
        @lib.FuncIdx::new(
          (import_count + (if needs_any_to_extern[0] { 1 } else { 0 })).to_uint(),
        ),
      )
      next_imports.push(
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("extern_to_any"),
          @lib.ExternType::func(idx),
        ),
      )
    }
    let shifted_to_index = @lib.FuncIdx::new(
      (base + import_specs.length() + export_specs.length() + extra_import_count).to_uint(),
    )
    let shifted_to_ref = @lib.FuncIdx::new(
      (base +
      import_specs.length() +
      export_specs.length() +
      1 +
      extra_import_count).to_uint(),
    )
    let @lib.CodeSec(shifted_funcs) = candidate.code_sec.unwrap()
    let final_funcs = shifted_funcs.copy()
    for i = 0; i < orig_funcs.length(); i = i + 1 {
      let @lib.Func(locals, body) = final_funcs[i]
      final_funcs[i] = @lib.Func::new(
        locals,
        mso_rewrite_conversions(
          body, host_any_to_extern, host_extern_to_any, shifted_to_index, shifted_to_ref,
        ),
      )
    }
    candidate = candidate.with_code_sec(@lib.CodeSec::new(final_funcs))
    candidate = candidate.with_import_sec(@lib.ImportSec::new(next_imports))
    candidate = candidate.with_type_sec(@lib.TypeSec::new(rewritten_types))
  }
  match candidate.type_sec {
    Some(@lib.TypeSec(candidate_types)) if candidate_types.length() >= 2 =>
      match (candidate_types[0], candidate_types[1]) {
        (@lib.SingleRecType(first), @lib.SingleRecType(second)) if first.get_comptype()
          is @lib.FuncCompType(_, _) &&
          second.get_comptype() is @lib.StructCompType(_) => {
          let remap : Map[UInt, UInt] = Map([])
          remap[0U] = 1U
          remap[1U] = 0U
          let rewritten = dfe_rewrite_module_type_idxs(candidate, remap)
          let @lib.TypeSec(rewritten_types) = rewritten.type_sec.unwrap()
          let reordered = rewritten_types.copy()
          reordered[0] = rewritten_types[1]
          reordered[1] = rewritten_types[0]
          candidate = rewritten.with_type_sec(@lib.TypeSec::new(reordered))
        }
        _ => ()
      }
    _ => ()
  }
  if @validate.validate_module(candidate).is_ok() {
    candidate
  } else {
    mod_
  }
}

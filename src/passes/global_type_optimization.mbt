///|
fn gto_scan_exposure(
  instrs : Array[@lib.Instruction],
  exposure : Array[Bool],
  first_field_read : Array[Bool],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.ExternConvertAny => exposure[0] = true
      @lib.StructGet(_, @lib.U32(0U))
      | @lib.StructGetS(_, @lib.U32(0U))
      | @lib.StructGetU(_, @lib.U32(0U)) => first_field_read[0] = true
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        gto_scan_exposure(body, exposure, first_field_read)
      @lib.If(_, then_body, else_body) => {
        gto_scan_exposure(then_body, exposure, first_field_read)
        match else_body {
          Some(body) => gto_scan_exposure(body, exposure, first_field_read)
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
fn gto_field_can_configure_prototype(field : @lib.FieldType) -> Bool {
  match field.unpack() {
    @lib.RefTypeValType(ref_type) =>
      ref_type.get_heap_type()
      is @lib.AbsHeapTypeHeapType(@lib.ExternAbsHeapType)
    _ => false
  }
}

///|
fn gto_placeholder_field() -> @lib.FieldType {
  @lib.FieldType::new(
    @lib.StorageType::pack_type(@lib.PackType::i8()),
    @lib.Mut::const_(),
  )
}

///|
fn gto_type_plan(plans : Array[Int], type_idx : @lib.TypeIdx) -> Int {
  match type_idx {
    @lib.TypeIdx(raw) => {
      let index = raw.to_int()
      if index >= 0 && index < plans.length() {
        plans[index]
      } else {
        0
      }
    }
    _ => 0
  }
}

///|
fn gto_rewrite_subtype(subtype : @lib.SubType, plan : Int) -> @lib.SubType {
  if plan == 0 {
    return subtype
  }
  let fields = match subtype.get_comptype() {
    @lib.StructCompType(fields) => fields
    _ => return subtype
  }
  let next_fields = fields.copy()
  if plan == 1 {
    next_fields[0] = gto_placeholder_field()
  } else {
    next_fields.insert(0, gto_placeholder_field())
  }
  let comp_type = @lib.CompType::struct_(next_fields)
  match subtype {
    @lib.SubType(final_, supers, metadata, _) =>
      @lib.SubType::new(final_, supers, comp_type, metadata~)
    @lib.CompTypeSubType(metadata, _) =>
      @lib.SubType::comp_type(comp_type, metadata~)
  }
}

///|
fn gto_rewrite_expr(
  expr : @lib.Expr,
  plans : Array[Int],
  old_subtypes : Array[@lib.SubType],
  env : @validate.Env,
  failed : Array[Bool],
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.Block(block_type, body) =>
        out.push(
          @lib.Instruction::block(
            block_type,
            gto_rewrite_expr(body, plans, old_subtypes, env, failed),
          ),
        )
      @lib.Loop(block_type, body) =>
        out.push(
          @lib.Instruction::loop_(
            block_type,
            gto_rewrite_expr(body, plans, old_subtypes, env, failed),
          ),
        )
      @lib.If(block_type, then_body, else_body) => {
        let @lib.Expr(next_then) = gto_rewrite_expr(
          @lib.Expr::new(then_body),
          plans,
          old_subtypes,
          env,
          failed,
        )
        let next_else = match else_body {
          Some(body) => {
            let @lib.Expr(next_body) = gto_rewrite_expr(
              @lib.Expr::new(body),
              plans,
              old_subtypes,
              env,
              failed,
            )
            Some(next_body)
          }
          None => None
        }
        out.push(@lib.Instruction::if_(block_type, next_then, next_else))
      }
      @lib.StructGet(type_idx, @lib.U32(field)) => {
        let increment = if gto_type_plan(plans, type_idx) == 2 {
          1U
        } else {
          0U
        }
        out.push(
          @lib.Instruction::struct_get(type_idx, @lib.U32(field + increment)),
        )
      }
      @lib.StructNew(type_idx) => {
        let plan = gto_type_plan(plans, type_idx)
        if plan != 0 {
          let field_count = match type_idx {
            @lib.TypeIdx(raw) =>
              match old_subtypes[raw.to_int()].get_comptype() {
                @lib.StructCompType(fields) => fields.length()
                _ => 0
              }
            _ => 0
          }
          let mut operand_end = out.length() - 1
          let mut first_start = -1
          for operand = 0; operand < field_count; operand = operand + 1 {
            first_start = gsi_find_operand_start(env, out, operand_end)
            if first_start < 0 {
              failed[0] = true
              break
            }
            operand_end = first_start - 1
          }
          if first_start >= 0 && !failed[0] {
            if plan == 2 {
              out.insert(first_start, @lib.Instruction::i32_const(@lib.I32(0)))
            } else if out[first_start] is @lib.RefNull(_) {
              out[first_start] = @lib.Instruction::i32_const(@lib.I32(0))
            } else {
              failed[0] = true
            }
          }
        }
        out.push(instr)
      }
      _ => out.push(instr)
    }
  }
  @lib.Expr::new(out)
}

///|
fn global_type_optimization_run_module_pass(
  mod_ : @lib.Module,
  closed_world : Bool,
) -> @lib.Module {
  if !closed_world {
    return mod_
  }
  let mod_ = gto_optimize_fields(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let old_subtypes = cl_module_subtypes(mod_)
  let exposure = [false]
  let first_field_read = [false]
  for func in funcs {
    let @lib.Func(_, @lib.Expr(body)) = func
    gto_scan_exposure(body, exposure, first_field_read)
  }
  if !exposure[0] {
    return mod_
  }
  let plans = Array::make(old_subtypes.length(), 0)
  for index, subtype in old_subtypes {
    if subtype.describes_type() is None {
      continue
    }
    match subtype.get_comptype() {
      @lib.StructCompType(fields) if fields.length() >= 2 &&
        !gto_field_can_configure_prototype(fields[0]) =>
        plans[index] = if first_field_read[0] { 2 } else { 1 }
      _ => ()
    }
  }
  if plans.all(fn(plan) { plan == 0 }) {
    return mod_
  }
  let rec_types = match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => rec_types
    None => return mod_
  }
  let rewritten_types : Array[@lib.RecType] = []
  let mut flat_index = 0
  for rec_type in rec_types {
    match rec_type {
      @lib.SingleRecType(subtype) => {
        rewritten_types.push(
          @lib.RecType::new(gto_rewrite_subtype(subtype, plans[flat_index])),
        )
        flat_index += 1
      }
      @lib.GroupRecType(group) => {
        let next_group : Array[@lib.SubType] = []
        for subtype in group {
          next_group.push(gto_rewrite_subtype(subtype, plans[flat_index]))
          flat_index += 1
        }
        rewritten_types.push(@lib.RecType::group(next_group))
      }
    }
  }
  let env = @validate.Env::new().with_module(mod_)
  let failed = [false]
  let rewritten_funcs : Array[@lib.Func] = []
  for func in funcs {
    let @lib.Func(locals, body) = func
    rewritten_funcs.push(
      @lib.Func::new(
        locals,
        gto_rewrite_expr(body, plans, old_subtypes, env, failed),
      ),
    )
  }
  if failed[0] {
    return mod_
  }
  let candidate = mod_
    .with_type_sec(@lib.TypeSec::new(rewritten_types))
    .with_code_sec(@lib.CodeSec::new(rewritten_funcs))
  if @validate.validate_module(candidate).is_ok() {
    candidate
  } else {
    mod_
  }
}

///|
fn feature_value_uses_exact(value : ValType) -> Bool {
  match value {
    RefTypeValType(ref_type) => ref_type.is_exact()
    _ => false
  }
}

///|
fn feature_block_uses_exact(block_type : BlockType) -> Bool {
  match block_type {
    ValTypeBlockType(value) => feature_value_uses_exact(value)
    _ => false
  }
}

///|
fn feature_subtype_uses_descriptors(subtype : SubType) -> Bool {
  if subtype.describes_type() != None || subtype.descriptor_type() != None {
    return true
  }
  match subtype.get_comptype() {
    FuncCompType(params, results) =>
      params.any(feature_value_uses_exact) ||
      results.any(feature_value_uses_exact)
    StructCompType(fields) =>
      fields.any(fn(field) { feature_value_uses_exact(field.0.unpack()) })
    ArrayCompType(field) => feature_value_uses_exact(field.0.unpack())
    ContCompType(_) => false
  }
}

///|
fn feature_body_uses_descriptors(body : Array[Instruction]) -> Bool {
  for instr in body {
    let uses = match instr {
      StructNewDesc(_)
      | StructNewDefaultDesc(_)
      | RefGetDesc(_)
      | RefTestDesc(_, _)
      | RefCastDescEq(_, _, _)
      | BrOnCastDescEq(_, _, _)
      | BrOnCastDescEqFail(_, _, _) => true
      RefNull(ref_type) => ref_type.is_exact()
      RefTest(_, exact, _) | RefCast(_, exact, _) => exact
      BrOnCast(_, cast, _, _) | BrOnCastFail(_, cast, _, _) =>
        cast.source_exact() || cast.target_exact()
      Select(Some(types)) => types.any(feature_value_uses_exact)
      Block(block_type, Expr(body))
      | Loop(block_type, Expr(body))
      | TryTable(block_type, _, Expr(body)) =>
        feature_block_uses_exact(block_type) ||
        feature_body_uses_descriptors(body)
      If(block_type, then_body, else_body) =>
        feature_block_uses_exact(block_type) ||
        feature_body_uses_descriptors(then_body) ||
        (match else_body {
          Some(body) => feature_body_uses_descriptors(body)
          None => false
        })
      Try(block_type, Expr(body), catches, _) =>
        feature_block_uses_exact(block_type) ||
        feature_body_uses_descriptors(body) ||
        catches.any(fn(catch_) {
          match catch_ {
            LegacyCatch(_, Expr(body)) | LegacyCatchAll(Expr(body)) =>
              feature_body_uses_descriptors(body)
          }
        })
      _ => false
    }
    if uses {
      return true
    }
  }
  false
}

///|
/// Detect the custom-descriptors proposal in encoded module constructs. This
/// includes exact references even when no descriptor-bearing type is declared.
/// Ordinary GC allocation instructions alone do not opt into the proposal.
pub fn module_uses_custom_descriptors(mod_ : Module) -> Bool {
  match mod_.type_sec {
    Some(TypeSec(groups)) =>
      for group in groups {
        match group {
          SingleRecType(subtype) =>
            if feature_subtype_uses_descriptors(subtype) {
              return true
            }
          GroupRecType(subtypes) =>
            if subtypes.any(feature_subtype_uses_descriptors) {
              return true
            }
        }
      }
    None => ()
  }
  match mod_.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, type_) = import_
        match type_ {
          TableExternType(TableType(ref_type, _)) =>
            if ref_type.is_exact() {
              return true
            }
          GlobalExternType(GlobalType(value, _)) =>
            if feature_value_uses_exact(value) {
              return true
            }
          _ => ()
        }
      }
    None => ()
  }
  match mod_.table_sec {
    Some(TableSec(tables)) =>
      for table in tables {
        let Table(TableType(ref_type, _), init) = table
        if ref_type.is_exact() {
          return true
        }
        match init {
          Some(Expr(body)) =>
            if feature_body_uses_descriptors(body) {
              return true
            }
          None => ()
        }
      }
    None => ()
  }
  match mod_.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(GlobalType(value, _), Expr(body)) = global
        if feature_value_uses_exact(value) ||
          feature_body_uses_descriptors(body) {
          return true
        }
      }
    None => ()
  }
  match mod_.elem_sec {
    Some(ElemSec(elems)) =>
      for elem in elems {
        let Elem(mode, kind) = elem
        match mode {
          Active(_, Expr(body)) =>
            if feature_body_uses_descriptors(body) {
              return true
            }
          _ => ()
        }
        match kind {
          TypedExprsElemKind(ref_type, exprs) => {
            if ref_type.is_exact() {
              return true
            }
            for expr in exprs {
              if feature_body_uses_descriptors(expr.0) {
                return true
              }
            }
          }
          FuncExprsElemKind(exprs) =>
            for expr in exprs {
              if feature_body_uses_descriptors(expr.0) {
                return true
              }
            }
          FuncsElemKind(_) => ()
        }
      }
    None => ()
  }
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(locals, Expr(body)) = func
        for run in locals.runs() {
          if feature_value_uses_exact(run.vt) {
            return true
          }
        }
        if feature_body_uses_descriptors(body) {
          return true
        }
      }
    None => ()
  }
  match mod_.data_sec {
    Some(DataSec(segments)) =>
      for segment in segments {
        let Data(mode, _) = segment
        match mode {
          Active(_, Expr(body)) =>
            if feature_body_uses_descriptors(body) {
              return true
            }
          Passive => ()
        }
      }
    None => ()
  }
  false
}

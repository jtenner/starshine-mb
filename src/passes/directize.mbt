///|
priv struct TableInfo {
  flat_names : Array[FuncIdx?]

  // true if any instruction may overwrite or invalidate
  // existing entries
  may_overwrite_entries : Bool

  // true if table.grow may add new entries
  may_grow : Bool
  initial_contents_immutable : Bool
}

///|
fn TableInfo::can_optimize_by_entry(self : TableInfo) -> Bool {
  self.initial_contents_immutable && !self.may_overwrite_entries
}

///|
type TableInfoMap = Map[TableIdx, TableInfo]

///|
priv enum IndirectTargetInfo {
  Known(FuncIdx)
  Trap
  Unknown
}

///|
fn make_table_write_analyzer(infos : TableInfoMap) -> ModuleTransformer[Unit] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_tinstruction: Some(fn(_, _, instr) {
      match instr {
        TTableSet(table_idx, _, _)
        | TTableFill(table_idx, _, _, _)
        | TTableInit(_, table_idx, _, _, _)
        | TTableCopy(table_idx, _, _, _, _) =>
          match infos.get(table_idx) {
            Some(info) =>
              infos.set(table_idx, TableInfo::{
                flat_names: info.flat_names,
                may_overwrite_entries: true,
                may_grow: info.may_grow,
                initial_contents_immutable: info.initial_contents_immutable,
              })
            None => ()
          }
        TTableGrow(table_idx, _, _) =>
          match infos.get(table_idx) {
            Some(info) =>
              infos.set(table_idx, TableInfo::{
                flat_names: info.flat_names,
                may_overwrite_entries: info.may_overwrite_entries,
                may_grow: true,
                initial_contents_immutable: info.initial_contents_immutable,
              })
            None => ()
          }
        _ => ()
      }
      Ok(None)
    }),
  }
}

///|
fn compute_table_info(
  m : Module,
  initial_immutable : Bool,
) -> Result[TableInfoMap, String] {
  let infos = Map::new()

  // --- Initialize tables ---
  match m.table_sec {
    Some(TableSec(tables)) =>
      for i in 0..<tables.length() {
        let min_size = match tables[i].0.1 {
          I32Limits(min, _) => min
          I64Limits(min, _) => min.to_uint()
        }
        infos.set(@lib.TableIdx(i.reinterpret_as_uint()), TableInfo::{
          flat_names: Array::make(min_size.reinterpret_as_int(), None),
          may_overwrite_entries: false,
          may_grow: false,
          initial_contents_immutable: initial_immutable,
        })
      }
    None => ()
  }

  // --- Apply element segments ---
  match m.elem_sec {
    Some(ElemSec(elems)) =>
      for elem in elems {
        match elem {
          Elem(Active(table_idx, offset_expr), kind) =>
            match infos.get(table_idx) {
              Some(info) => {
                // Non-constant offsets invalidate optimization
                if offset_expr.0.length() != 1 {
                  infos.set(table_idx, TableInfo::{
                    flat_names: info.flat_names,
                    may_overwrite_entries: true,
                    may_grow: info.may_grow,
                    initial_contents_immutable: info.initial_contents_immutable,
                  })
                  continue
                }
                match offset_expr.0[0] {
                  I32Const(I32(off)) =>
                    match kind {
                      FuncsElemKind(funcs) => {
                        let names = info.flat_names
                        for j in 0..<funcs.length() {
                          let idx = off + j
                          if idx >= 0 && idx < names.length() {
                            names[idx] = Some(funcs[j])
                          }
                        }
                        infos.set(table_idx, TableInfo::{
                          flat_names: names,
                          may_overwrite_entries: info.may_overwrite_entries,
                          may_grow: info.may_grow,
                          initial_contents_immutable: info.initial_contents_immutable,
                        })
                      }
                      _ =>
                        infos.set(table_idx, TableInfo::{
                          flat_names: info.flat_names,
                          may_overwrite_entries: true,
                          may_grow: info.may_grow,
                          initial_contents_immutable: info.initial_contents_immutable,
                        })
                    }
                  _ =>
                    infos.set(table_idx, TableInfo::{
                      flat_names: info.flat_names,
                      may_overwrite_entries: true,
                      may_grow: info.may_grow,
                      initial_contents_immutable: info.initial_contents_immutable,
                    })
                }
              }
              None => ()
            }
          _ => ()
        }
      }
    None => ()
  }

  // --- Analyze code ---
  let analyzer = make_table_write_analyzer(infos)
  match analyzer.walk_module((), m) {
    Ok(_) => Ok(infos)
    Err(e) => Err(e)
  }
}

///|
fn get_target_info(
  index : TInstr,
  table : TableInfo,
  call_type : TypeIdx,
  func_types : Map[FuncIdx, TypeIdx],
  env : Env,
) -> IndirectTargetInfo {
  match index {
    TI32Const(I32(i)) => {
      let idx = i.reinterpret_as_uint()
      let size = table.flat_names.length().reinterpret_as_uint()
      if idx >= size {
        if table.may_grow {
          Unknown
        } else {
          Trap
        }
      } else {
        match table.flat_names[idx.reinterpret_as_int()] {
          None => Trap
          Some(func_idx) =>
            match func_types.get(func_idx) {
              None => Trap
              Some(func_ty_idx) =>
                match env.resolve_functype(func_ty_idx) {
                  None => Trap
                  Some(func_ty) =>
                    match env.resolve_functype(call_type) {
                      None => Trap
                      Some(call_ty) =>
                        if func_ty == call_ty {
                          Known(func_idx)
                        } else {
                          Trap
                        }
                    }
                }
            }
        }
      }
    }
    _ => Unknown
  }
}

///|
fn get_select_targets(
  then_idx : TInstr,
  else_idx : TInstr,
  table : TableInfo,
  call_type : TypeIdx,
  func_types : Map[FuncIdx, TypeIdx],
  env : Env,
) -> (IndirectTargetInfo, IndirectTargetInfo) {
  let then_info = get_target_info(then_idx, table, call_type, func_types, env)
  let else_info = get_target_info(else_idx, table, call_type, func_types, env)
  (then_info, else_info)
}

///|
fn make_call_branch(info : IndirectTargetInfo, args : Array[TInstr]) -> TExpr {
  match info {
    Known(func_idx) => TExpr([TCall(func_idx, args)])
    Trap => TExpr([TUnreachable])
    Unknown =>
      // Should never be used if we check properly
      TExpr([TUnreachable])
  }
}

///|
fn rewrite_select_call_indirect(
  type_idx : TypeIdx,
  table : TableInfo,
  args : Array[TInstr],
  then_idx : TInstr,
  else_idx : TInstr,
  cond : TInstr,
  func_types : Map[FuncIdx, TypeIdx],
  env : Env,
) -> TInstr? {
  let (then_info, else_info) = get_select_targets(
    then_idx, else_idx, table, type_idx, func_types, env,
  )
  match then_info {
    Unknown => None
    _ =>
      match else_info {
        Unknown => None
        _ => {
          let then_expr = make_call_branch(then_info, args)
          let else_expr = make_call_branch(else_info, args)
          Some(
            TIf(TypeIdxBlockType(type_idx), cond, then_expr, Some(else_expr)),
          )
        }
      }
  }
}

///|
fn rewrite_br_table_call_indirect(
  type_idx : TypeIdx,
  table : TableInfo,
  args : Array[TInstr],
  labels : Array[LabelIdx],
  default_label : LabelIdx,
  index : TInstr,
  carried : Array[TInstr],
  func_types : Map[FuncIdx, TypeIdx],
  env : Env,
) -> TInstr? {
  let target_count = labels.length() + 1
  let targets = Array::new()

  // Resolve each possible numeric index
  for i in 0..<target_count {
    let idx_instr = @lib.TI32Const(I32(i))
    let info = get_target_info(idx_instr, table, type_idx, func_types, env)
    match info {
      Unknown => return None
      _ => targets.push(info)
    }
  }

  // Build nested blocks from bottom up
  let mut body = @lib.TExpr([TBrTable(labels, default_label, index, carried)])
  for info in targets.rev_iter() {
    let branch = match info {
      Known(func_idx) => @lib.TExpr([TCall(func_idx, args), TReturn([])])
      Trap => TExpr([TUnreachable])
      Unknown => TExpr([TUnreachable])
    }
    body = TExpr([TBlock(TypeIdxBlockType(type_idx), branch), ..body.0])
  }
  Some(TBlock(TypeIdxBlockType(type_idx), body))
}

///|
fn make_directize_transformer(
  tables : TableInfoMap,
  func_types : Map[FuncIdx, TypeIdx],
  env : Env,
) -> ModuleTransformer[Unit] {
  return ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_tinstruction: Some(fn(_, _, instr) {
      match instr {
        TCallIndirect(type_idx, table_idx, args, index) =>
          match tables.get(table_idx) {
            Some(table) if table.can_optimize_by_entry() =>
              match index {
                TSelect(_, then_idx, else_idx, cond) =>
                  match
                    rewrite_select_call_indirect(
                      type_idx, table, args, then_idx, else_idx, cond, func_types,
                      env,
                    ) {
                    Some(i) => Ok(Some(((), i)))
                    None => Ok(None)
                  }
                TBrTable(labels, default_label, idx, carried) =>
                  match
                    rewrite_br_table_call_indirect(
                      type_idx, table, args, labels, default_label, idx, carried,
                      func_types, env,
                    ) {
                    Some(i) => Ok(Some(((), i)))
                    None => Ok(None)
                  }
                _ =>
                  match
                    get_target_info(index, table, type_idx, func_types, env) {
                    Known(f) => Ok(Some(((), TCall(f, args))))
                    Trap => Ok(Some(((), TUnreachable)))
                    Unknown => Ok(None)
                  }
              }
            _ => Ok(None)
          }
        TReturnCallIndirect(type_idx, table_idx, args, index) =>
          match tables.get(table_idx) {
            Some(table) if table.can_optimize_by_entry() =>
              match get_target_info(index, table, type_idx, func_types, env) {
                Known(f) => Ok(Some(((), TReturnCall(f, args))))
                Trap => Ok(Some(((), TUnreachable)))
                Unknown => Ok(None)
              }
            _ => Ok(None)
          }
        _ => Ok(None)
      }
    }),
  }
}

///|
pub fn directize_module(
  m : Module,
  initial_immutable : Bool,
) -> Result[Module, String] {
  let env = Env::new().with_module(m)
  let tables = match compute_table_info(m, initial_immutable) {
    Err(t) => return Err(t)
    Ok(tables) => tables
  }

  // Build func_types map manually from the function section
  let func_types = Map::new()
  match m.func_sec {
    None => ()
    Some(FuncSec(types)) =>
      for i in 0..<types.length() {
        func_types.set(@lib.FuncIdx(i.reinterpret_as_uint()), types[i])
      }
  }
  let transformer = make_directize_transformer(tables, func_types, env)
  match transformer.walk_module((), m) {
    Ok(Some((_, new_m))) => Ok(new_m)
    Ok(None) => Ok(m)
    Err(e) => Err(e)
  }
}

///|
fn make_simple_functype() -> RecType {
  SingleRecType(CompTypeSubType(FuncCompType([], [])))
}

///|
fn make_functype_i32_to_i32() -> RecType {
  SingleRecType(
    CompTypeSubType(
      FuncCompType([NumTypeValType(I32NumType)], [NumTypeValType(I32NumType)]),
    ),
  )
}

// =============================================================================
// BASIC DIRECTIZATION TESTS
// =============================================================================

///|
test "directize: constant index resolves to known function" {
  // Setup: table with func 0 at index 0
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0)))]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([instr]))])) =>
      match instr {
        TCall(FuncIdx(0), []) => () // Expected: transformed to direct call
        other => fail("Expected TCall(FuncIdx(0)), got \{other}")
      }
    _ => fail("Unexpected code section structure")
  }
}

///|
test "directize: out-of-bounds constant index becomes unreachable" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(10)))], // Out of bounds
          ),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TUnreachable]))])) => () // Expected
    Some(CodeSec([TFunc(_, TExpr([instr]))])) =>
      fail("Expected TUnreachable, got \{instr}")
    _ => fail("Unexpected code section structure")
  }
}

///|
test "directize: null entry in table becomes unreachable" {
  // Table with size 2, but only index 0 is filled
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(2, Some(2)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(1)))], // Index 1 is null
          ),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TUnreachable]))])) => ()
    _ => fail("Expected unreachable for null table entry")
  }
}

///|
test "directize: non-constant index is not transformed" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [NumTypeValType(I32NumType)],
          TExpr([
            TCallIndirect(TypeIdx(0), TableIdx(0), [], TLocalGet(LocalIdx(0))), // Dynamic index
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCallIndirect(_, _, _, TLocalGet(_))]))])) =>
      ()
    _ => fail("Expected call_indirect to remain unchanged with dynamic index")
  }
}

// =============================================================================
// TYPE MISMATCH TESTS
// =============================================================================

///|
test "directize: type mismatch becomes unreachable" {
  // Function has type 0 (void -> void), but call uses type 1 (i32 -> i32)
  let m = Module::new()
    .with_type_sec(
      TypeSec([make_simple_functype(), make_functype_i32_to_i32()]),
    )
    .with_func_sec(FuncSec([TypeIdx(0)])) // Function uses type 0
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([
            TCallIndirect(
              TypeIdx(1),
              TableIdx(0),
              [TI32Const(I32(42))],
              TI32Const(I32(0)),
            ), // Wrong type
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TUnreachable]))])) => ()
    _ => fail("Expected unreachable for type mismatch")
  }
}

// =============================================================================
// TABLE MUTABILITY TESTS
// =============================================================================

///|
test "directize: table.set prevents optimization" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0), TypeIdx(0)])) // Two functions
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([
            TTableSet(TableIdx(0), TI32Const(I32(0)), TRefFunc(FuncIdx(1))), // Modifies table
            TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0))),
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([_, TCallIndirect(_, _, _, _)]))])) => ()
    _ => fail("Expected call_indirect to remain when table.set is present")
  }
}

///|
test "directize: table.fill prevents optimization" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(2, Some(2)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([
            TTableFill(
              TableIdx(0),
              TI32Const(I32(0)),
              TRefFunc(FuncIdx(0)),
              TI32Const(I32(2)),
            ),
            TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0))),
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([_, TCallIndirect(_, _, _, _)]))])) => ()
    _ => fail("Expected call_indirect to remain when table.fill is present")
  }
}

///|
test "directize: table.copy prevents optimization on dest table" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
        Elem(
          Active(TableIdx(1), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([
            TTableCopy(
              TableIdx(0),
              TableIdx(1),
              TI32Const(I32(0)),
              TI32Const(I32(0)),
              TI32Const(I32(1)),
            ),
            TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0))),
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([_, TCallIndirect(_, _, _, _)]))])) => ()
    _ =>
      fail(
        "Expected call_indirect to remain when table.copy modifies dest table",
      )
  }
}

///|
test "directize: table.init prevents optimization" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(ElemSec([Elem(Passive, FuncsElemKind([FuncIdx(0)]))]))
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([
            TTableInit(
              ElemIdx(0),
              TableIdx(0),
              TI32Const(I32(0)),
              TI32Const(I32(0)),
              TI32Const(I32(1)),
            ),
            TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0))),
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([_, TCallIndirect(_, _, _, _)]))])) => ()
    _ => fail("Expected call_indirect to remain when table.init is present")
  }
}

///|
test "directize: table.grow marks table as growable" {
  // Out of bounds access on growable table should be Unknown, not Trap
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, None),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([
            TDrop(
              TTableGrow(TableIdx(0), TRefFunc(FuncIdx(0)), TI32Const(I32(1))),
            ),
            TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(5))), // Potentially valid after grow
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([_, TCallIndirect(_, _, _, _)]))])) => ()
    _ => fail("Expected call_indirect to remain when table may grow")
  }
}

///|
test "directize: initial_immutable=false prevents optimization" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0)))]),
        ),
      ]),
    )
  let result = directize_module(m, false) // initial_immutable = false
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCallIndirect(_, _, _, _)]))])) => ()
    _ =>
      fail("Expected call_indirect to remain when initial_immutable is false")
  }
}

// =============================================================================
// RETURN_CALL_INDIRECT TESTS
// =============================================================================

///|
test "directize: return_call_indirect with constant index" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([
            TReturnCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0))),
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TReturnCall(FuncIdx(0), [])]))])) => ()
    _ => fail("Expected return_call_indirect to become return_call")
  }
}

///|
test "directize: return_call_indirect out of bounds becomes unreachable" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([
            TReturnCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(99))),
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TUnreachable]))])) => ()
    _ => fail("Expected unreachable for out of bounds return_call_indirect")
  }
}

// =============================================================================
// SELECT-BASED INDIRECT CALL TESTS
// =============================================================================

///|
test "directize: select-based call_indirect with both branches known" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0), TypeIdx(0)])) // Two functions
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(2, Some(2)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0), FuncIdx(1)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [NumTypeValType(I32NumType)],
          TExpr([
            TCallIndirect(
              TypeIdx(0),
              TableIdx(0),
              [],
              TSelect(
                None,
                TI32Const(I32(0)),
                TI32Const(I32(1)),
                TLocalGet(LocalIdx(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TIf(_, _, _, Some(_))]))])) => ()
    _ => fail("Expected select-based call_indirect to become if-then-else")
  }
}

///|
test "directize: select-based call_indirect with one branch trapping" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(2, Some(2)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [NumTypeValType(I32NumType)],
          TExpr([
            TCallIndirect(
              TypeIdx(0),
              TableIdx(0),
              [],
              TSelect(
                None,
                TI32Const(I32(0)),
                TI32Const(I32(1)),
                TLocalGet(LocalIdx(0)),
              ),
            ), // Index 1 is null
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TIf(_, _, then_expr, Some(else_expr))]))])) => {
      // One branch should have TCall, other should have TUnreachable
      let has_call = match then_expr.0 {
        [TCall(_, _)] => true
        _ => false
      }
      let has_unreachable = match else_expr.0 {
        [TUnreachable] => true
        _ => false
      }
      assert_true(has_call && has_unreachable)
    }
    _ => fail("Expected select-based call to become if with trap branch")
  }
}

///|
test "directize: select-based call_indirect with unknown branch not transformed" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, None),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [NumTypeValType(I32NumType)],
          TExpr([
            TDrop(
              TTableGrow(TableIdx(0), TRefFunc(FuncIdx(0)), TI32Const(I32(10))),
            ),
            TCallIndirect(
              TypeIdx(0),
              TableIdx(0),
              [],
              TSelect(
                None,
                TI32Const(I32(0)),
                TI32Const(I32(5)),
                TLocalGet(LocalIdx(0)),
              ),
            ), // Index 5 is unknown after grow
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(
      CodeSec(
        [TFunc(_, TExpr([_, TCallIndirect(_, _, _, TSelect(_, _, _, _))]))]
      )
    ) => ()
    _ => fail("Expected select-based call to remain when one branch is unknown")
  }
}

// =============================================================================
// BR_TABLE-BASED INDIRECT CALL TESTS
// =============================================================================

///|
test "directize: br_table-based call_indirect with all branches known" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0), TypeIdx(0), TypeIdx(0)])) // Three functions
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(3, Some(3)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0), FuncIdx(1), FuncIdx(2)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [NumTypeValType(I32NumType)],
          TExpr([
            TCallIndirect(
              TypeIdx(0),
              TableIdx(0),
              [],
              TBrTable(
                [LabelIdx(0), LabelIdx(1)],
                LabelIdx(2),
                TLocalGet(LocalIdx(0)),
                [],
              ),
            ),
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TBlock(_, _)]))])) => ()
    _ => fail("Expected br_table-based call to become nested blocks")
  }
}

// =============================================================================
// ELEMENT SEGMENT TESTS
// =============================================================================

///|
test "directize: passive element segment doesn't initialize table" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(ElemSec([Elem(Passive, FuncsElemKind([FuncIdx(0)]))])) // Passive, not active
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0)))]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TUnreachable]))])) => () // Entry is null
    _ => fail("Expected unreachable when element segment is passive")
  }
}

///|
test "directize: declarative element segment doesn't initialize table" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(ElemSec([Elem(Declarative, FuncsElemKind([FuncIdx(0)]))])) // Declarative
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0)))]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TUnreachable]))])) => ()
    _ => fail("Expected unreachable when element segment is declarative")
  }
}

///|
test "directize: element segment with non-constant offset marks table mutable" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_global_sec(
      GlobalSec([
        Global(
          GlobalType(NumTypeValType(I32NumType), false),
          Expr([I32Const(I32(0))]),
        ),
      ]),
    )
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([GlobalGet(GlobalIdx(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    ) // Non-constant offset
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0)))]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCallIndirect(_, _, _, _)]))])) => ()
    _ =>
      fail("Expected call_indirect to remain with non-constant element offset")
  }
}

///|
test "directize: element segment with expression kind marks table mutable" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncExprsElemKind([Expr([RefFunc(FuncIdx(0))])]),
        ),
      ]),
    ) // Expression kind
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0)))]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCallIndirect(_, _, _, _)]))])) => ()
    _ => fail("Expected call_indirect to remain with expression element kind")
  }
}

// =============================================================================
// MULTIPLE TABLES TESTS
// =============================================================================

///|
test "directize: multiple tables, only one modified" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0), TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
        Elem(
          Active(TableIdx(1), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(1)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([
            TTableSet(TableIdx(0), TI32Const(I32(0)), TRefFunc(FuncIdx(1))), // Modify table 0
            TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0))), // Should NOT be optimized
            TCallIndirect(TypeIdx(0), TableIdx(1), [], TI32Const(I32(0))), // Should be optimized
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [_, TCallIndirect(_, TableIdx(0), _, _), TCall(FuncIdx(1), [])]
            )
          ),
        ]
      )
    ) => ()
    _ =>
      fail(
        "Expected table 0 call to remain indirect, table 1 call to become direct",
      )
  }
}

// =============================================================================
// ARGUMENTS PROPAGATION TESTS
// =============================================================================

///|
test "directize: arguments are propagated to direct call" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_functype_i32_to_i32()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([
            TCallIndirect(
              TypeIdx(0),
              TableIdx(0),
              [TI32Const(I32(42))],
              TI32Const(I32(0)),
            ),
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCall(FuncIdx(0), [TI32Const(I32(42))])]))])) =>
      ()
    _ => fail("Expected arguments to be propagated to direct call")
  }
}

// =============================================================================
// NEGATIVE INDEX TEST
// =============================================================================

///|
test "directize: negative index (interpreted as large unsigned) becomes unreachable" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(-1)))], // -1 = 0xFFFFFFFF
          ),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TUnreachable]))])) => ()
    _ => fail("Expected unreachable for negative index")
  }
}

// =============================================================================
// EMPTY TABLE TEST
// =============================================================================

///|
test "directize: empty table always traps" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(0, Some(0)),
          ),
          None,
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0)))]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TUnreachable]))])) => ()
    _ => fail("Expected unreachable for empty table access")
  }
}

// =============================================================================
// NO TRANSFORMATION WHEN NO TABLES
// =============================================================================

///|
test "directize: module without tables" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_code_sec(CodeSec([TFunc([], TExpr([TNop]))]))
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TNop]))])) => ()
    _ => fail("Expected no changes for module without tables")
  }
}

// =============================================================================
// ELEMENT SEGMENT OFFSET BEYOND TABLE SIZE
// =============================================================================

///|
test "directize: element segment at offset beyond initial table entries" {
  // Table size is 4, element at offset 2 writes indices 2 and 3
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0), TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I32Limits(4, Some(4)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(2))])),
          FuncsElemKind([FuncIdx(0), FuncIdx(1)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([
            TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0))), // null - trap
            TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(2))), // func 0
            TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(3))), // func 1
          ]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr([TUnreachable, TCall(FuncIdx(0), []), TCall(FuncIdx(1), [])])
          ),
        ]
      )
    ) => ()
    _ => fail("Expected correct handling of element segment at non-zero offset")
  }
}

// =============================================================================
// 64-BIT TABLE LIMITS TEST
// =============================================================================

///|
test "directize: table with i64 limits" {
  let m = Module::new()
    .with_type_sec(TypeSec([make_simple_functype()]))
    .with_func_sec(FuncSec([TypeIdx(0)]))
    .with_table_sec(
      TableSec([
        Table(
          TableType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
            I64Limits(1UL, Some(1UL)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec([
        Elem(
          Active(TableIdx(0), Expr([I32Const(I32(0))])),
          FuncsElemKind([FuncIdx(0)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec([
        TFunc(
          [],
          TExpr([TCallIndirect(TypeIdx(0), TableIdx(0), [], TI32Const(I32(0)))]),
        ),
      ]),
    )
  let result = directize_module(m, true)
  assert_true(result is Ok(_))
  let new_m = result.unwrap()
  match new_m.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCall(FuncIdx(0), [])]))])) => ()
    _ => fail("Expected directization to work with i64 table limits")
  }
}

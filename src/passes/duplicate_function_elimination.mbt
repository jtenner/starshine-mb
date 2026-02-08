///|
struct DFEKey {
  func_type : FuncType
  func : Func
} derive(Eq, Hash)

///|
fn dfe_key(func_type : FuncType, func : Func) -> DFEKey {
  { func_type, func }
}

///|
fn dfe_imported_func_count(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, ex) = import_
        match ex {
          FuncExternType(_) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn dfe_extract_comp_type(sub_type : SubType) -> CompType {
  match sub_type {
    SubType(_, _, comp) => comp
    CompTypeSubType(comp) => comp
  }
}

///|
fn dfe_resolve_func_type(
  comp_types : Array[CompType],
  idx : TypeIdx,
) -> FuncType? {
  let i = match idx {
    TypeIdx(n) => n
    RecIdx(n) => n
  }
  let j = i.reinterpret_as_int()
  if j < 0 || j >= comp_types.length() {
    return None
  }
  match comp_types[j] {
    FuncCompType(params, results) => Some(FuncType::new(params, results))
    _ => None
  }
}

///|
fn dfe_collect_func_types(mod : Module) -> Array[FuncType] {
  let comp_types : Array[CompType] = []
  match mod.type_sec {
    Some(TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          SingleRecType(sub_type) =>
            comp_types.push(dfe_extract_comp_type(sub_type))
          GroupRecType(sub_types) =>
            for sub_type in sub_types {
              comp_types.push(dfe_extract_comp_type(sub_type))
            }
        }
      }
    None => ()
  }
  let func_types : Array[FuncType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, ex) = import_
        match ex {
          FuncExternType(type_idx) =>
            match dfe_resolve_func_type(comp_types, type_idx) {
              Some(ft) => func_types.push(ft)
              None => func_types.push(FuncType::new([], []))
            }
          _ => ()
        }
      }
    None => ()
  }
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        match dfe_resolve_func_type(comp_types, type_idx) {
          Some(ft) => func_types.push(ft)
          None => func_types.push(FuncType::new([], []))
        }
      }
    None => ()
  }
  func_types
}

///|
fn dfe_limit_for_options(
  defined_func_count : Int,
  options : OptimizeOptions,
) -> Int {
  if options.optimize_level >= 3 || options.shrink_level >= 1 {
    defined_func_count
  } else if options.optimize_level >= 2 {
    10
  } else {
    1
  }
}

///|
fn dfe_func_idx_from_abs(abs_idx : Int) -> FuncIdx {
  func_idx(abs_idx.reinterpret_as_uint())
}

///|
fn dfe_remap_func_indices(
  mod : Module,
  remap : Map[FuncIdx, FuncIdx],
) -> Result[Module, String] {
  if remap.is_empty() {
    return Ok(mod)
  }
  let transformer = ModuleTransformer::new().on_funcidx_evt(fn(_, _, idx) {
    match remap.get(idx) {
      Some(new_idx) =>
        if new_idx != idx {
          change((), new_idx)
        } else {
          unchanged()
        }
      None => unchanged()
    }
  })
  match transformer.walk_module((), mod) {
    Ok(Some((_, new_mod))) => Ok(new_mod)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
  }
}

///|
fn dfe_run_iteration(mod : Module) -> Result[(Module, Bool), String] {
  let imported_func_count = dfe_imported_func_count(mod)
  let type_idxs = match mod.func_sec {
    Some(FuncSec(items)) => items
    None => return Ok((mod, false))
  }
  let funcs = match mod.code_sec {
    Some(CodeSec(items)) => items
    None => return Ok((mod, false))
  }
  if type_idxs.length() != funcs.length() {
    return Err(
      "duplicate_function_elimination: func_sec/code_sec length mismatch",
    )
  }
  if funcs.is_empty() {
    return Ok((mod, false))
  }
  let func_types = dfe_collect_func_types(mod)
  let total_funcs = imported_func_count + funcs.length()
  if func_types.length() < total_funcs {
    return Ok((mod, false))
  }
  let canonical_by_key : Map[DFEKey, Int] = Map::new()
  let replacements_abs : Map[Int, Int] = Map::new()
  let remove_def : Array[Bool] = []
  for _ in funcs {
    remove_def.push(false)
  }
  for def_idx = 0; def_idx < funcs.length(); def_idx = def_idx + 1 {
    let abs_idx = imported_func_count + def_idx
    let key = dfe_key(func_types[abs_idx], funcs[def_idx])
    match canonical_by_key.get(key) {
      Some(canonical_abs_idx) => {
        replacements_abs[abs_idx] = canonical_abs_idx
        remove_def[def_idx] = true
      }
      None => canonical_by_key[key] = abs_idx
    }
  }
  if replacements_abs.is_empty() {
    return Ok((mod, false))
  }
  let new_type_idxs : Array[TypeIdx] = []
  let new_funcs : Array[Func] = []
  for def_idx = 0; def_idx < funcs.length(); def_idx = def_idx + 1 {
    if !remove_def[def_idx] {
      new_type_idxs.push(type_idxs[def_idx])
      new_funcs.push(funcs[def_idx])
    }
  }
  let old_abs_to_new_abs : Array[Int] = []
  for i = 0; i < imported_func_count; i = i + 1 {
    old_abs_to_new_abs.push(i)
  }
  let mut next_def_abs = imported_func_count
  for def_idx = 0; def_idx < funcs.length(); def_idx = def_idx + 1 {
    if remove_def[def_idx] {
      old_abs_to_new_abs.push(-1)
    } else {
      old_abs_to_new_abs.push(next_def_abs)
      next_def_abs += 1
    }
  }
  let remap : Map[FuncIdx, FuncIdx] = Map::new()
  for old_abs = 0; old_abs < old_abs_to_new_abs.length(); old_abs = old_abs + 1 {
    let new_abs = old_abs_to_new_abs[old_abs]
    if new_abs >= 0 {
      remap[dfe_func_idx_from_abs(old_abs)] = dfe_func_idx_from_abs(new_abs)
    }
  }
  for entry in replacements_abs {
    let (old_abs, canonical_abs) = entry
    if canonical_abs < 0 || canonical_abs >= old_abs_to_new_abs.length() {
      return Err(
        "duplicate_function_elimination: invalid canonical function index",
      )
    }
    let canonical_new_abs = old_abs_to_new_abs[canonical_abs]
    if canonical_new_abs < 0 {
      return Err("duplicate_function_elimination: canonical function removed")
    }
    remap[dfe_func_idx_from_abs(old_abs)] = dfe_func_idx_from_abs(
      canonical_new_abs,
    )
  }
  let new_mod = mod
    .with_func_sec(FuncSec::new(new_type_idxs))
    .with_code_sec(CodeSec::new(new_funcs))
  match dfe_remap_func_indices(new_mod, remap) {
    Ok(out) => Ok((out, true))
    Err(e) => Err(e)
  }
}

///|
fn duplicate_function_elimination(
  mod : Module,
  options : OptimizeOptions,
) -> Result[Module, String] {
  let defined_func_count = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
  let mut limit = dfe_limit_for_options(defined_func_count, options)
  let mut mod = mod
  while limit > 0 {
    limit -= 1
    match dfe_run_iteration(mod) {
      Err(e) => return Err(e)
      Ok((new_mod, changed)) => {
        mod = new_mod
        if !changed {
          break
        }
      }
    }
  }
  Ok(mod)
}

///|
test "duplicate function elimination removes duplicate function bodies" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let root = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), []),
      TInstr::call(FuncIdx::new(2), []),
    ]),
  )
  let dup_a = Func::t_func([], TExpr::new([TInstr::nop()]))
  let dup_b = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(CodeSec::new([root, dup_a, dup_b]))
  let optimized = match
    duplicate_function_elimination(mod, OptimizeOptions::new()) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_function_elimination error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
  match optimized.func_sec {
    Some(FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr(instrs)), _])) => {
      let mut seen = 0
      for instr in instrs {
        match instr {
          TCall(FuncIdx(raw), []) => {
            assert_eq(raw.reinterpret_as_int(), 1)
            seen += 1
          }
          _ => ()
        }
      }
      assert_eq(seen, 2)
    }
    _ => fail("expected remapped root function calls")
  }
}

///|
test "duplicate function elimination limit respects optimize level" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let a1 = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(2), [])]))
  let a2 = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(3), [])]))
  let b1 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let b2 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(0),
      ]),
    )
    .with_code_sec(CodeSec::new([a1, a2, b1, b2]))
  let low = OptimizeOptions::new(optimize_level=0, shrink_level=0)
  let low_optimized = match duplicate_function_elimination(mod, low) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_function_elimination error: \{e}")
  }
  match low_optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 3)
    None => fail("expected code section")
  }
  let high = OptimizeOptions::new(optimize_level=2, shrink_level=0)
  let high_optimized = match duplicate_function_elimination(mod, high) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_function_elimination error: \{e}")
  }
  match high_optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
}

///|
test "duplicate function elimination uses shrink level for multi-iteration" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let a1 = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(2), [])]))
  let a2 = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(3), [])]))
  let b1 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let b2 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(0),
      ]),
    )
    .with_code_sec(CodeSec::new([a1, a2, b1, b2]))
  let options = OptimizeOptions::new(optimize_level=0, shrink_level=1)
  let optimized = match duplicate_function_elimination(mod, options) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_function_elimination error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
}

///|
test "duplicate function elimination does not merge equal bodies with different types" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let t_i32_void = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32()], [])),
  )
  let root = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), []),
      TInstr::call(FuncIdx::new(2), [TInstr::i32_const(I32(7))]),
    ]),
  )
  let f_void = Func::t_func([], TExpr::new([TInstr::nop()]))
  let f_i32_void = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void, t_i32_void]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(1)]),
    )
    .with_code_sec(CodeSec::new([root, f_void, f_i32_void]))
  let optimized = match
    duplicate_function_elimination(mod, OptimizeOptions::new()) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_function_elimination error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 3)
    None => fail("expected code section")
  }
}

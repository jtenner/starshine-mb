///| 
/// Copyright 2023 WebAssembly Community Group participants
/// 
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
/// 
///     http://www.apache.org/licenses/LICENSE-2.0
/// 
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an "AS IS" BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.
///

///|
fn rf_count_imported_funcs(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn rf_funcidx_to_abs(idx : FuncIdx) -> Int {
  let FuncIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn rf_funcidx_from_abs(abs : Int) -> FuncIdx {
  FuncIdx::new(abs.reinterpret_as_uint())
}

///|
fn rf_defined_index(imported : Int, defined_count : Int, idx : FuncIdx) -> Int? {
  let abs = rf_funcidx_to_abs(idx)
  let def = abs - imported
  if def >= 0 && def < defined_count {
    Some(def)
  } else {
    None
  }
}

///|
fn rf_bump_defined_count(
  counts : Array[Int],
  imported : Int,
  idx : FuncIdx,
) -> Unit {
  match rf_defined_index(imported, counts.length(), idx) {
    Some(def_idx) => counts[def_idx] = counts[def_idx] + 1
    None => ()
  }
}

///|
fn rf_scan_call_counts(
  funcs : Array[Func],
  imported : Int,
  counts : Array[Int],
) -> Result[Unit, String] {
  let tscanner = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    instr,
  ) {
    match instr {
      TCall(target, _) => rf_bump_defined_count(counts, imported, target)
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  let scanner = ModuleTransformer::new().on_instruction_evt(fn(self, _, instr) {
    match instr {
      Call(target) => rf_bump_defined_count(counts, imported, target)
      _ => ()
    }
    self.walk_instruction_default((), instr)
  })
  for func in funcs {
    match func {
      TFunc(_, body) =>
        match tscanner.walk_texpr((), body) {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
      Func(_, body) =>
        match scanner.walk_expr((), body) {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
    }
  }
  Ok(())
}

///|
fn rf_remap_func_indices(
  mod : Module,
  remap : Map[FuncIdx, FuncIdx],
) -> Result[Module, String] {
  let transformer = ModuleTransformer::new().on_funcidx_evt(fn(_, _, idx) {
    match remap.get(idx) {
      Some(new_idx) =>
        if new_idx == idx {
          unchanged()
        } else {
          change((), new_idx)
        }
      None => unchanged()
    }
  })
  match transformer.walk_module((), mod) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
  }
}

///|
fn reorder_functions(mod : Module) -> Result[Module, String] {
  let imported = rf_count_imported_funcs(mod)
  let type_idxs = match mod.func_sec {
    Some(FuncSec(items)) => items
    None => return Ok(mod)
  }
  let funcs = match mod.code_sec {
    Some(CodeSec(items)) => items
    None => return Ok(mod)
  }
  if type_idxs.length() != funcs.length() {
    return Err("reorder_functions: func_sec/code_sec length mismatch")
  }
  if funcs.length() <= 1 {
    return Ok(mod)
  }
  let counts = Array::make(funcs.length(), 0)
  match rf_scan_call_counts(funcs, imported, counts) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match mod.start_sec {
    Some(StartSec(idx)) => rf_bump_defined_count(counts, imported, idx)
    None => ()
  }
  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          Export(_, FuncExternIdx(idx)) =>
            rf_bump_defined_count(counts, imported, idx)
          _ => ()
        }
      }
    None => ()
  }
  match mod.elem_sec {
    Some(ElemSec(elems)) =>
      for elem in elems {
        match elem {
          Elem(_, FuncsElemKind(funcs)) =>
            for idx in funcs {
              rf_bump_defined_count(counts, imported, idx)
            }
          _ => ()
        }
      }
    None => ()
  }
  let order : Array[Int] = []
  for i = 0; i < funcs.length(); i = i + 1 {
    order.push(i)
  }
  order.sort_by(fn(a, b) {
    let ca = counts[a]
    let cb = counts[b]
    if ca == cb {
      b - a
    } else {
      cb - ca
    }
  })
  let mut changed = false
  for i = 0; i < order.length(); i = i + 1 {
    if order[i] != i {
      changed = true
      break
    }
  }
  if !changed {
    return Ok(mod)
  }
  let old_def_to_new_def = Array::make(funcs.length(), 0)
  let reordered_types : Array[TypeIdx] = []
  let reordered_funcs : Array[Func] = []
  for new_def = 0; new_def < order.length(); new_def = new_def + 1 {
    let old_def = order[new_def]
    old_def_to_new_def[old_def] = new_def
    reordered_types.push(type_idxs[old_def])
    reordered_funcs.push(funcs[old_def])
  }
  let remap : Map[FuncIdx, FuncIdx] = Map::new()
  for abs = 0; abs < imported; abs = abs + 1 {
    let idx = rf_funcidx_from_abs(abs)
    remap[idx] = idx
  }
  for old_def = 0; old_def < funcs.length(); old_def = old_def + 1 {
    let old_abs = imported + old_def
    let new_abs = imported + old_def_to_new_def[old_def]
    remap[rf_funcidx_from_abs(old_abs)] = rf_funcidx_from_abs(new_abs)
  }
  let reordered_mod = mod
    .with_func_sec(FuncSec::new(reordered_types))
    .with_code_sec(CodeSec::new(reordered_funcs))
  rf_remap_func_indices(reordered_mod, remap)
}

///|
fn reorder_functions_by_name(mod : Module) -> Result[Module, String] {
  // The current IR does not preserve per-function symbolic names.
  // Keep source order to preserve determinism.
  Ok(mod)
}

///|
fn rf_run_reorder_functions(mod : Module) -> Module {
  match reorder_functions(mod) {
    Ok(out) => out
    Err(e) => abort("reorder_functions failed: \{e}")
  }
}

///|
fn rf_run_reorder_functions_by_name(mod : Module) -> Module {
  match reorder_functions_by_name(mod) {
    Ok(out) => out
    Err(e) => abort("reorder_functions_by_name failed: \{e}")
  }
}

///|
test "reorder_functions reorders defined functions by static use counts and rewrites indices" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let import_sec = ImportSec::new([
    Import::new(
      Name::new("env"),
      Name::new("imp"),
      ExternType::func(TypeIdx::new(0)),
    ),
  ])
  let f0 = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(2), []),
      TInstr::call(FuncIdx::new(2), []),
    ]),
  )
  let f1 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let f2 = Func::t_func(
    [],
    TExpr::new([TInstr::drop(TInstr::i32_const(I32(7)))]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_import_sec(import_sec)
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(CodeSec::new([f0, f1, f2]))
    .with_start_sec(StartSec::new(FuncIdx::new(3)))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("root"), ExternIdx::func(FuncIdx::new(1))),
      ]),
    )
    .with_elem_sec(
      ElemSec::new([
        Elem::new(ElemMode::passive(), ElemKind::funcs([FuncIdx::new(3)])),
      ]),
    )
  let out = rf_run_reorder_functions(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TI32Const(I32(7)))])), _, _])) => ()
    _ => fail("expected highest-used function to be moved first")
  }
  match out.start_sec {
    Some(StartSec(FuncIdx(i))) => assert_eq(i, 1U)
    _ => fail("expected remapped start function index")
  }
  match out.export_sec {
    Some(ExportSec([Export(_, FuncExternIdx(FuncIdx(i)))])) => assert_eq(i, 3U)
    _ => fail("expected remapped function export index")
  }
  match out.elem_sec {
    Some(ElemSec([Elem(_, FuncsElemKind([FuncIdx(i)]))])) => assert_eq(i, 1U)
    _ => fail("expected remapped element function index")
  }
}

///|
test "reorder_functions_by_name currently preserves order when symbolic names are absent" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let f0 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let f1 = Func::t_func(
    [],
    TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([f0, f1]))
  let out = rf_run_reorder_functions_by_name(mod)
  match out.code_sec {
    Some(
      CodeSec(
        [TFunc(_, TExpr([TNop])), TFunc(_, TExpr([TDrop(TI32Const(I32(1)))]))]
      )
    ) => ()
    _ => fail("expected function order to be preserved")
  }
}

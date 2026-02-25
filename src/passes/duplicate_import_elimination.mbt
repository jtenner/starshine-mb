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
priv struct DIEImportKey {
  module_name : Name
  base_name : Name
} derive(Eq, Hash)

///|
fn die_key(module_name : Name, base_name : Name) -> DIEImportKey {
  { module_name, base_name }
}

///|
fn die_defined_func_count(mod : Module) -> Result[Int, String] {
  let func_count = match mod.func_sec {
    Some(FuncSec(funcs)) => funcs.length()
    None => 0
  }
  let code_count = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
  if func_count != code_count {
    Err("duplicate_import_elimination: func_sec/code_sec length mismatch")
  } else {
    Ok(func_count)
  }
}

///|
fn die_remap_func_indices(
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
fn duplicate_import_elimination(mod : Module) -> Result[Module, String] {
  let imports = match mod.import_sec {
    Some(ImportSec(imports)) => imports
    None => return Ok(mod)
  }
  let defined_func_count = match die_defined_func_count(mod) {
    Ok(n) => n
    Err(e) => return Err(e)
  }
  if imports.is_empty() {
    return Ok(mod)
  }
  let env = Env::new().with_module(mod)
  let seen : Map[DIEImportKey, Int] = Map::new()
  let duplicate_import_entry = Array::make(imports.length(), false)
  let duplicate_func_to_canonical : Map[Int, Int] = Map::new()
  let mut imported_func_count = 0
  for i = 0; i < imports.length(); i = i + 1 {
    match imports[i] {
      Import(module_name, base_name, FuncExternType(_)) => {
        let current_idx = imported_func_count
        let key = die_key(module_name, base_name)
        match seen.get(key) {
          Some(previous_idx) => {
            let previous_type = env.get_functype_by_funcidx(
              FuncIdx::new(previous_idx.reinterpret_as_uint()),
            )
            let current_type = env.get_functype_by_funcidx(
              FuncIdx::new(current_idx.reinterpret_as_uint()),
            )
            if previous_type is Some(_) && previous_type == current_type {
              duplicate_import_entry[i] = true
              duplicate_func_to_canonical[current_idx] = previous_idx
            }
          }
          None => ()
        }
        seen[key] = current_idx
        imported_func_count += 1
      }
      _ => ()
    }
  }
  if duplicate_func_to_canonical.is_empty() {
    return Ok(mod)
  }
  let old_import_to_new = Array::make(imported_func_count, -1)
  let mut new_imported_func_count = 0
  for old_idx = 0; old_idx < imported_func_count; old_idx = old_idx + 1 {
    match duplicate_func_to_canonical.get(old_idx) {
      Some(canonical_old_idx) => {
        if canonical_old_idx < 0 ||
          canonical_old_idx >= old_import_to_new.length() {
          return Err(
            "duplicate_import_elimination: invalid canonical import index",
          )
        }
        let mapped = old_import_to_new[canonical_old_idx]
        if mapped < 0 {
          return Err(
            "duplicate_import_elimination: canonical import mapping unresolved",
          )
        }
        old_import_to_new[old_idx] = mapped
      }
      None => {
        old_import_to_new[old_idx] = new_imported_func_count
        new_imported_func_count += 1
      }
    }
  }
  let total_old_funcs = imported_func_count + defined_func_count
  let remap : Map[FuncIdx, FuncIdx] = Map::new()
  for old_idx = 0; old_idx < imported_func_count; old_idx = old_idx + 1 {
    let new_idx = old_import_to_new[old_idx]
    if new_idx < 0 {
      return Err("duplicate_import_elimination: unresolved import remap")
    }
    remap[FuncIdx::new(old_idx.reinterpret_as_uint())] = FuncIdx::new(
      new_idx.reinterpret_as_uint(),
    )
  }
  for old_idx = imported_func_count
      old_idx < total_old_funcs
      old_idx = old_idx + 1 {
    let def_idx = old_idx - imported_func_count
    let new_idx = new_imported_func_count + def_idx
    remap[FuncIdx::new(old_idx.reinterpret_as_uint())] = FuncIdx::new(
      new_idx.reinterpret_as_uint(),
    )
  }
  let new_imports : Array[Import] = []
  for i = 0; i < imports.length(); i = i + 1 {
    if !duplicate_import_entry[i] {
      new_imports.push(imports[i])
    }
  }
  let new_mod = mod.with_import_sec(ImportSec::new(new_imports))
  die_remap_func_indices(new_mod, remap)
}

///|
test "duplicate import elimination merges duplicate function imports" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let imports = ImportSec::new([
    Import::new(
      Name::new("env"),
      Name::new("foo"),
      ExternType::func(TypeIdx::new(0)),
    ),
    Import::new(
      Name::new("env"),
      Name::new("foo"),
      ExternType::func(TypeIdx::new(0)),
    ),
    Import::new(
      Name::new("env"),
      Name::new("bar"),
      ExternType::func(TypeIdx::new(0)),
    ),
  ])
  let root = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), []),
      TInstr::call(FuncIdx::new(2), []),
      TInstr::call(FuncIdx::new(4), []),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_import_sec(imports)
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([root, callee]))
  let optimized = match duplicate_import_elimination(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_import_elimination error: \{e}")
  }
  match optimized.import_sec {
    Some(ImportSec(imps)) => assert_eq(imps.length(), 2)
    None => fail("expected import section")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr(instrs)), _])) => {
      assert_eq(instrs.length(), 3)
      match instrs[0] {
        TCall(FuncIdx(i), []) => assert_eq(i, 0U)
        _ => fail("expected first call to remap duplicate import to canonical")
      }
      match instrs[1] {
        TCall(FuncIdx(i), []) => assert_eq(i, 1U)
        _ => fail("expected second call to remap surviving import index")
      }
      match instrs[2] {
        TCall(FuncIdx(i), []) => assert_eq(i, 3U)
        _ =>
          fail(
            "expected defined function call index to shift by removed import",
          )
      }
    }
    _ => fail("expected code section")
  }
}

///|
test "duplicate import elimination keeps imports when function types differ" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let t1 = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0, t1]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("foo"),
          ExternType::func(TypeIdx::new(0)),
        ),
        Import::new(
          Name::new("env"),
          Name::new("foo"),
          ExternType::func(TypeIdx::new(1)),
        ),
      ]),
    )
  let optimized = match duplicate_import_elimination(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_import_elimination error: \{e}")
  }
  match optimized.import_sec {
    Some(ImportSec(imps)) => assert_eq(imps.length(), 2)
    None => fail("expected import section")
  }
}

///|
test "duplicate import elimination ignores non-function imports" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("g"),
          ExternType::global(GlobalType::new(ValType::i32(), false)),
        ),
        Import::new(
          Name::new("env"),
          Name::new("g"),
          ExternType::global(GlobalType::new(ValType::i32(), false)),
        ),
      ]),
    )
  let optimized = match duplicate_import_elimination(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_import_elimination error: \{e}")
  }
  match optimized.import_sec {
    Some(ImportSec(imps)) => assert_eq(imps.length(), 2)
    None => fail("expected import section")
  }
}

///|
test "duplicate import elimination handles mixed extern kinds and remaps exports" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let imports = ImportSec::new([
    Import::new(
      Name::new("env"),
      Name::new("foo"),
      ExternType::func(TypeIdx::new(0)),
    ),
    Import::new(
      Name::new("env"),
      Name::new("foo"),
      ExternType::global(GlobalType::new(ValType::i32(), false)),
    ),
    Import::new(
      Name::new("env"),
      Name::new("foo"),
      ExternType::func(TypeIdx::new(0)),
    ),
    Import::new(
      Name::new("env"),
      Name::new("mem"),
      ExternType::mem(MemType::new(Limits::i32(1, None))),
    ),
    Import::new(
      Name::new("env"),
      Name::new("bar"),
      ExternType::func(TypeIdx::new(0)),
    ),
  ])
  let root = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), []),
      TInstr::call(FuncIdx::new(2), []),
      TInstr::call(FuncIdx::new(4), []),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_import_sec(imports)
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([root, callee]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("callee"), ExternIdx::func(FuncIdx::new(4))),
      ]),
    )
  let optimized = match duplicate_import_elimination(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_import_elimination error: \{e}")
  }
  match optimized.import_sec {
    Some(ImportSec(imps)) => {
      assert_eq(imps.length(), 4)
      let mut func_count = 0
      let mut global_count = 0
      let mut mem_count = 0
      for imp in imps {
        let Import(_, _, ex) = imp
        match ex {
          FuncExternType(_) => func_count += 1
          GlobalExternType(_) => global_count += 1
          MemExternType(_) => mem_count += 1
          _ => ()
        }
      }
      assert_eq(func_count, 2)
      assert_eq(global_count, 1)
      assert_eq(mem_count, 1)
    }
    None => fail("expected import section")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr(instrs)), _])) => {
      assert_eq(instrs.length(), 3)
      match instrs[0] {
        TCall(FuncIdx(i), []) => assert_eq(i, 0U)
        _ => fail("expected duplicate foo import call to remap to canonical")
      }
      match instrs[1] {
        TCall(FuncIdx(i), []) => assert_eq(i, 1U)
        _ => fail("expected bar import call to keep compacted index")
      }
      match instrs[2] {
        TCall(FuncIdx(i), []) => assert_eq(i, 3U)
        _ =>
          fail(
            "expected defined function call index to shift by removed function import",
          )
      }
    }
    _ => fail("expected code section")
  }
  match optimized.export_sec {
    Some(ExportSec([Export(_, FuncExternIdx(FuncIdx(i)))])) => assert_eq(i, 3U)
    _ => fail("expected exported defined function index to be remapped")
  }
}

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
fn rg_count_imported_globals(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn rg_globalidx_to_int(idx : GlobalIdx) -> Int {
  let GlobalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn rg_globalidx_from_int(idx : Int) -> GlobalIdx {
  GlobalIdx::new(idx.reinterpret_as_uint())
}

///|
fn rg_defined_index(
  imported_globals : Int,
  defined_count : Int,
  idx : GlobalIdx,
) -> Int? {
  let abs = rg_globalidx_to_int(idx)
  let def = abs - imported_globals
  if def >= 0 && def < defined_count {
    Some(def)
  } else {
    None
  }
}

///|
fn rg_bump_count(
  counts : Array[Double],
  imported_globals : Int,
  idx : GlobalIdx,
) -> Unit {
  match rg_defined_index(imported_globals, counts.length(), idx) {
    Some(def_idx) => counts[def_idx] = counts[def_idx] + 1.0
    None => ()
  }
}

///|
fn rg_collect_use_counts(
  mod : Module,
  imported_globals : Int,
  defined_count : Int,
) -> Result[Array[Double], String] {
  let counts = Array::make(defined_count, 0.0)
  let walker = ModuleTransformer::new()
    .on_tinstruction_evt(fn(self, _, instr) {
      match instr {
        TGlobalGet(idx) => rg_bump_count(counts, imported_globals, idx)
        TGlobalSet(idx, _) => rg_bump_count(counts, imported_globals, idx)
        _ => ()
      }
      self.walk_tinstruction_default((), instr)
    })
    .on_instruction_evt(fn(self, _, instr) {
      match instr {
        GlobalGet(idx) => rg_bump_count(counts, imported_globals, idx)
        GlobalSet(idx) => rg_bump_count(counts, imported_globals, idx)
        _ => ()
      }
      self.walk_instruction_default((), instr)
    })
  match walker.walk_module((), mod) {
    Ok(_) => Ok(counts)
    Err(e) => Err(e)
  }
}

///|
fn rg_collect_dependencies(
  globals : Array[Global],
  imported_globals : Int,
) -> Result[Array[Array[Int]], String] {
  let dep_sets : Array[Set[Int]] = []
  for _ in globals {
    dep_sets.push(Set::new())
  }
  for i = 0; i < globals.length(); i = i + 1 {
    let Global(_, init) = globals[i]
    let walker = ModuleTransformer::new().on_instruction_evt(fn(
      self,
      _,
      instr,
    ) {
      match instr {
        GlobalGet(idx) =>
          match rg_defined_index(imported_globals, globals.length(), idx) {
            Some(dep_idx) => dep_sets[dep_idx].add(i)
            None => ()
          }
        _ => ()
      }
      self.walk_instruction_default((), instr)
    })
    match walker.walk_expr((), init) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }
  let deps : Array[Array[Int]] = []
  for dep_set in dep_sets {
    let items : Array[Int] = []
    for item in dep_set {
      items.push(item)
    }
    items.sort()
    deps.push(items)
  }
  Ok(deps)
}

///|
fn rg_topological_sort(deps : Array[Array[Int]]) -> Array[Int] {
  let n = deps.length()
  let indegree = Array::make(n, 0)
  for src = 0; src < n; src = src + 1 {
    for dst in deps[src] {
      indegree[dst] = indegree[dst] + 1
    }
  }
  let queue : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    if indegree[i] == 0 {
      queue.push(i)
    }
  }
  let out : Array[Int] = []
  let mut qi = 0
  while qi < queue.length() {
    let curr = queue[qi]
    qi = qi + 1
    out.push(curr)
    for dep in deps[curr] {
      indegree[dep] = indegree[dep] - 1
      if indegree[dep] == 0 {
        queue.push(dep)
      }
    }
  }
  if out.length() == n {
    return out
  }
  let seen = Array::make(n, false)
  for idx in out {
    seen[idx] = true
  }
  for i = 0; i < n; i = i + 1 {
    if !seen[i] {
      out.push(i)
    }
  }
  out
}

///|
fn rg_min_topological_sort(
  deps : Array[Array[Int]],
  prefer_before : (Int, Int) -> Bool,
) -> Array[Int] {
  let n = deps.length()
  let indegree = Array::make(n, 0)
  for src = 0; src < n; src = src + 1 {
    for dst in deps[src] {
      indegree[dst] = indegree[dst] + 1
    }
  }
  let emitted = Array::make(n, false)
  let available : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    if indegree[i] == 0 {
      available.push(i)
    }
  }
  let out : Array[Int] = []
  while out.length() < n {
    if available.is_empty() {
      for i = 0; i < n; i = i + 1 {
        if !emitted[i] {
          available.push(i)
          break
        }
      }
    }
    let mut best_pos = 0
    let mut best = available[0]
    for pos = 1; pos < available.length(); pos = pos + 1 {
      let candidate = available[pos]
      if prefer_before(candidate, best) {
        best = candidate
        best_pos = pos
      }
    }
    let last = available.pop().unwrap()
    if best_pos < available.length() {
      available[best_pos] = last
    }
    if emitted[best] {
      continue
    }
    emitted[best] = true
    out.push(best)
    for dep in deps[best] {
      indegree[dep] = indegree[dep] - 1
      if indegree[dep] == 0 && !emitted[dep] {
        available.push(dep)
      }
    }
  }
  out
}

///|
fn rg_do_sort(counts : Array[Double], deps : Array[Array[Int]]) -> Array[Int] {
  rg_min_topological_sort(deps, fn(a, b) {
    let ca = counts[a]
    let cb = counts[b]
    if ca != cb {
      ca > cb
    } else {
      a < b
    }
  })
}

///|
fn rg_uleb_bytes(v : Int) -> Int {
  let mut bytes = 1
  let mut x = v.to_uint64()
  while x >= 128UL {
    bytes += 1
    x = x >> 7
  }
  bytes
}

///|
fn rg_compute_size(
  indices : Array[Int],
  counts : Array[Double],
  always : Bool,
) -> Double {
  if always {
    let mut total = 0.0
    for i = 0; i < indices.length(); i = i + 1 {
      total = total + counts[indices[i]] * (1.0 + i.to_double() / 128.0)
    }
    return total
  }
  let mut total = 0.0
  for i = 0; i < indices.length(); i = i + 1 {
    total = total + counts[indices[i]] * rg_uleb_bytes(i).to_double()
  }
  total
}

///|
fn rg_remap_global_indices(
  mod : Module,
  remap : Map[GlobalIdx, GlobalIdx],
) -> Result[Module, String] {
  if remap.is_empty() {
    return Ok(mod)
  }
  let pass = ModuleTransformer::new().on_globalidx_evt(fn(_, _, idx) {
    match remap.get(idx) {
      Some(next) => if next == idx { unchanged() } else { change((), next) }
      None => unchanged()
    }
  })
  match pass.walk_module((), mod) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
  }
}

///|
fn reorder_globals_impl(mod : Module, always : Bool) -> Result[Module, String] {
  let globals = match mod.global_sec {
    Some(GlobalSec(items)) => items
    None => return Ok(mod)
  }
  if globals.length() <= 1 {
    return Ok(mod)
  }
  if globals.length() < 128 && !always {
    return Ok(mod)
  }
  let imported_globals = rg_count_imported_globals(mod)
  let counts = match
    rg_collect_use_counts(mod, imported_globals, globals.length()) {
    Ok(out) => out
    Err(e) => return Err(e)
  }
  let deps = match rg_collect_dependencies(globals, imported_globals) {
    Ok(out) => out
    Err(e) => return Err(e)
  }
  let options : Array[(Array[Int], Double)] = []
  let add_option = fn(custom_counts : Array[Double]) {
    let order = rg_do_sort(custom_counts, deps)
    let size = rg_compute_size(order, counts, always)
    options.push((order, size))
  }
  add_option(Array::make(globals.length(), 0.0))
  add_option(counts)
  let topo = rg_topological_sort(deps)
  let sum_counts = Array::make(globals.length(), 0.0)
  let exp_counts = Array::make(globals.length(), 0.0)
  let exp_factor = 0.095
  for rev = topo.length() - 1; rev >= 0; rev = rev - 1 {
    let g = topo[rev]
    sum_counts[g] = counts[g]
    exp_counts[g] = counts[g]
    for dep in deps[g] {
      sum_counts[g] = sum_counts[g] + sum_counts[dep]
      exp_counts[g] = exp_counts[g] + exp_factor * exp_counts[dep]
    }
    if rev == 0 {
      break
    }
  }
  add_option(sum_counts)
  add_option(exp_counts)
  if options.is_empty() {
    return Ok(mod)
  }
  let mut best_order = options[0].0
  let mut best_size = options[0].1
  for i = 1; i < options.length(); i = i + 1 {
    let candidate = options[i]
    if candidate.1 < best_size {
      best_order = candidate.0
      best_size = candidate.1
    }
  }
  let mut changed = false
  for i = 0; i < best_order.length(); i = i + 1 {
    if best_order[i] != i {
      changed = true
      break
    }
  }
  if !changed {
    return Ok(mod)
  }
  let reordered_globals : Array[Global] = []
  let old_to_new = Array::make(globals.length(), 0)
  for new_idx = 0; new_idx < best_order.length(); new_idx = new_idx + 1 {
    let old_idx = best_order[new_idx]
    reordered_globals.push(globals[old_idx])
    old_to_new[old_idx] = new_idx
  }
  let remap : Map[GlobalIdx, GlobalIdx] = Map::new()
  for i = 0; i < imported_globals; i = i + 1 {
    let idx = rg_globalidx_from_int(i)
    remap[idx] = idx
  }
  for old_idx = 0; old_idx < globals.length(); old_idx = old_idx + 1 {
    let old_abs = imported_globals + old_idx
    let new_abs = imported_globals + old_to_new[old_idx]
    remap[rg_globalidx_from_int(old_abs)] = rg_globalidx_from_int(new_abs)
  }
  let reordered_mod = mod.with_global_sec(GlobalSec::new(reordered_globals))
  rg_remap_global_indices(reordered_mod, remap)
}

///|
fn reorder_globals_ir_pass(
  _mod : Module,
  always : Bool,
) -> ModuleTransformer[IRContext] {
  ModuleTransformer::new().on_module_evt(fn(_, ctx, mod) {
    match reorder_globals_impl(mod, always) {
      Ok(next) => if next == mod { unchanged() } else { change(ctx, next) }
      Err(e) => Err(e)
    }
  })
}

///|
fn rg_run_reorder_globals(mod : Module, always : Bool) -> Module {
  let pass = reorder_globals_ir_pass(mod, always)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    Ok(None) => mod
    Err(e) => abort("reorder_globals pass failed: \{e}")
  }
}

///|
test "reorder_globals_always reorders globals by use count while preserving dependencies" {
  let imported = Import::new(
    Name::new("env"),
    Name::new("gimp"),
    ExternType::global(GlobalType::new(ValType::i32(), true)),
  )
  let g0 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::i32_const(I32(1))]),
  )
  let g1 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::global_get(GlobalIdx::new(1))]),
  )
  let g2 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::i32_const(I32(2))]),
  )
  let body = TExpr::new([
    TInstr::drop(TInstr::global_get(GlobalIdx::new(3))),
    TInstr::drop(TInstr::global_get(GlobalIdx::new(3))),
    TInstr::global_set(GlobalIdx::new(2), TInstr::i32_const(I32(9))),
  ])
  let mod = Module::new()
    .with_import_sec(ImportSec::new([imported]))
    .with_global_sec(GlobalSec::new([g0, g1, g2]))
    .with_code_sec(CodeSec::new([Func::t_func([], body)]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("g1"), ExternIdx::global(GlobalIdx::new(2))),
      ]),
    )
  let out = rg_run_reorder_globals(mod, true)
  match out.global_sec {
    Some(GlobalSec(globals)) => {
      assert_eq(globals.length(), 3)
      match globals[0] {
        Global(_, Expr([I32Const(I32(v))])) => assert_eq(v, 2)
        _ => fail("expected first reordered global init to be i32.const 2")
      }
      match globals[1] {
        Global(_, Expr([I32Const(I32(v))])) => assert_eq(v, 1)
        _ => fail("expected second reordered global init to be i32.const 1")
      }
      match globals[2] {
        Global(_, Expr([GlobalGet(GlobalIdx(i))])) => assert_eq(i, 2U)
        _ =>
          fail("expected third reordered global init to depend on remapped g0")
      }
    }
    _ =>
      fail("expected globals reordered to [g2, g0, g1] with remapped init dep")
  }
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                TDrop(TGlobalGet(GlobalIdx(g0))),
                TDrop(TGlobalGet(GlobalIdx(g1))),
                TGlobalSet(GlobalIdx(g2), _),
              ],
              ..,
            }
          ),
        ]
      )
    ) => {
      assert_eq(g0, 1U)
      assert_eq(g1, 1U)
      assert_eq(g2, 3U)
    }
    _ => fail("expected global indices remapped in code")
  }
  match out.export_sec {
    Some(ExportSec([Export(_, GlobalExternIdx(GlobalIdx(i)))])) =>
      assert_eq(i, 3U)
    _ => fail("expected remapped exported global index")
  }
}

///|
test "reorder_globals non-always keeps modules with fewer than 128 globals unchanged" {
  let g0 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::i32_const(I32(1))]),
  )
  let g1 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::i32_const(I32(2))]),
  )
  let body = TExpr::new([
    TInstr::drop(TInstr::global_get(GlobalIdx::new(1))),
    TInstr::drop(TInstr::global_get(GlobalIdx::new(1))),
  ])
  let mod = Module::new()
    .with_global_sec(GlobalSec::new([g0, g1]))
    .with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let out = rg_run_reorder_globals(mod, false)
  assert_eq(out, mod)
}

///|
test "rg_do_sort prefers higher-count available globals while honoring deps" {
  let deps = [[1], [], []]
  let counts = [1.0, 1.0, 2.0]
  let order = rg_do_sort(counts, deps)
  assert_eq(order, [2, 0, 1])
}

///|
test "rg_collect_use_counts counts global.get and global.set over module and code" {
  let imported = Import::new(
    Name::new("env"),
    Name::new("gimp"),
    ExternType::global(GlobalType::new(ValType::i32(), true)),
  )
  let g0 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::i32_const(I32(1))]),
  )
  let g1 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::global_get(GlobalIdx::new(1))]),
  )
  let g2 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::i32_const(I32(2))]),
  )
  let body = TExpr::new([
    TInstr::drop(TInstr::global_get(GlobalIdx::new(3))),
    TInstr::drop(TInstr::global_get(GlobalIdx::new(3))),
    TInstr::global_set(GlobalIdx::new(2), TInstr::i32_const(I32(9))),
  ])
  let mod = Module::new()
    .with_import_sec(ImportSec::new([imported]))
    .with_global_sec(GlobalSec::new([g0, g1, g2]))
    .with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let counts = match rg_collect_use_counts(mod, 1, 3) {
    Ok(out) => out
    Err(e) => fail("unexpected count collection failure: \{e}")
  }
  assert_eq(counts, [1.0, 1.0, 2.0])
}

///|
test "rg_compute_size in always mode prefers front-loading high-count globals" {
  let counts = [1.0, 1.0, 2.0]
  let id_size = rg_compute_size([0, 1, 2], counts, true)
  let reordered_size = rg_compute_size([2, 0, 1], counts, true)
  assert_true(reordered_size < id_size)
}

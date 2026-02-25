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
priv struct GEEffects {
  mut reads_memory : Bool
  mut writes_memory : Bool
  mut reads_globals : Bool
  mut writes_globals : Bool
  mut calls : Bool
  mut branches : Bool
  mut throws : Bool
  mut traps : Bool
}

///|
fn GEEffects::new() -> GEEffects {
  {
    reads_memory: false,
    writes_memory: false,
    reads_globals: false,
    writes_globals: false,
    calls: false,
    branches: false,
    throws: false,
    traps: false,
  }
}

///|
fn GEEffects::merge_in(self : GEEffects, other : GEEffects) -> Unit {
  self.reads_memory = self.reads_memory || other.reads_memory
  self.writes_memory = self.writes_memory || other.writes_memory
  self.reads_globals = self.reads_globals || other.reads_globals
  self.writes_globals = self.writes_globals || other.writes_globals
  self.calls = self.calls || other.calls
  self.branches = self.branches || other.branches
  self.throws = self.throws || other.throws
  self.traps = self.traps || other.traps
}

///|
priv struct GEFuncInfo {
  mut effects : GEEffects?
  called_functions : Set[Int]
}

///|
fn GEFuncInfo::new() -> GEFuncInfo {
  { effects: None, called_functions: Set::new() }
}

///|
fn ge_count_imported_funcs(mod : Module) -> Int {
  let mut total = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => total += 1
          _ => ()
        }
      }
    None => ()
  }
  total
}

///|
fn ge_count_defined_funcs(mod : Module) -> Int {
  match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
}

///|
fn ge_funcidx_to_int(idx : FuncIdx) -> Int {
  let FuncIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn ge_in_func_range(idx : Int, total_funcs : Int) -> Bool {
  idx >= 0 && idx < total_funcs
}

///|
fn ge_collect_shallow_effects_into(instr : TInstr, effects : GEEffects) -> Unit {
  match instr {
    TGlobalGet(_) => effects.reads_globals = true
    TGlobalSet(_, _) => effects.writes_globals = true
    TLoad(_, _, _) => {
      effects.reads_memory = true
      effects.traps = true
    }
    TStore(_, _, _, _) => {
      effects.writes_memory = true
      effects.traps = true
    }
    TMemoryGrow(_, _) => effects.writes_memory = true
    TMemorySize(_) => effects.reads_memory = true
    TMemoryCopy(_, _, _, _, _) => {
      effects.reads_memory = true
      effects.writes_memory = true
    }
    TMemoryFill(_, _, _, _) => effects.writes_memory = true
    TMemoryInit(_, _, _, _, _) => {
      effects.reads_memory = true
      effects.writes_memory = true
    }
    TDataDrop(_) => effects.writes_memory = true
    TTableSet(_, _, _) | TTableGrow(_, _, _) | TTableFill(_, _, _, _) =>
      effects.writes_memory = true
    TTableGet(_, _) | TTableSize(_) => effects.reads_memory = true
    TTableCopy(_, _, _, _, _) | TTableInit(_, _, _, _, _) | TElemDrop(_) => {
      effects.reads_memory = true
      effects.writes_memory = true
    }
    TCall(_, _) | TCallIndirect(_, _, _, _) | TCallRef(_, _, _) =>
      effects.calls = true
    TReturnCall(_, _)
    | TReturnCallIndirect(_, _, _, _)
    | TReturnCallRef(_, _, _) => {
      effects.calls = true
      effects.branches = true
    }
    TBr(_, _)
    | TBrIf(_, _, _)
    | TBrTable(_, _, _, _)
    | TBrOnNull(_, _, _)
    | TBrOnNonNull(_, _, _)
    | TBrOnCast(_, _, _, _, _, _)
    | TBrOnCastFail(_, _, _, _, _, _)
    | TReturn(_) => effects.branches = true
    TThrow(_, _) => {
      effects.throws = true
      effects.branches = true
    }
    TThrowRef(_) => {
      effects.throws = true
      effects.branches = true
    }
    TUnreachable => effects.traps = true
    TRefAsNonNull(_) | TRefCast(_, _, _) | TRefCastDescEq(_, _, _) =>
      effects.traps = true
    TStructGet(_, _, _) | TStructGetS(_, _, _) | TStructGetU(_, _, _) => {
      effects.reads_memory = true
      effects.traps = true
    }
    TStructSet(_, _, _, _) => {
      effects.writes_memory = true
      effects.traps = true
    }
    TArrayNew(_, _, _)
    | TArrayNewDefault(_, _)
    | TArrayNewFixed(_, _)
    | TArrayNewData(_, _, _, _)
    | TArrayNewElem(_, _, _, _) => {
      effects.writes_memory = true
      effects.traps = true
    }
    TArrayGet(_, _, _)
    | TArrayGetS(_, _, _)
    | TArrayGetU(_, _, _)
    | TArrayLen(_) => {
      effects.reads_memory = true
      effects.traps = true
    }
    TArraySet(_, _, _, _)
    | TArrayFill(_, _, _, _, _)
    | TArrayCopy(_, _, _, _, _, _, _)
    | TArrayInitData(_, _, _, _, _, _)
    | TArrayInitElem(_, _, _, _, _, _) => {
      effects.reads_memory = true
      effects.writes_memory = true
      effects.traps = true
    }
    TAtomicFence
    | TMemoryAtomicNotify(_, _, _)
    | TMemoryAtomicWait32(_, _, _, _)
    | TMemoryAtomicWait64(_, _, _, _)
    | TAtomicRmw(_, _, _, _)
    | TAtomicCmpxchg(_, _, _, _, _) => {
      effects.reads_memory = true
      effects.writes_memory = true
    }
    TBinary(op, _, _) =>
      match op {
        I32DivSOp
        | I32DivUOp
        | I32RemSOp
        | I32RemUOp
        | I64DivSOp
        | I64DivUOp
        | I64RemSOp
        | I64RemUOp => effects.traps = true
        _ => ()
      }
    TUnary(op, _) =>
      match op {
        I32TruncF32SOp
        | I32TruncF32UOp
        | I32TruncF64SOp
        | I32TruncF64UOp
        | I64TruncF32SOp
        | I64TruncF32UOp
        | I64TruncF64SOp
        | I64TruncF64UOp => effects.traps = true
        _ => ()
      }
    _ => ()
  }
}

///|
fn ge_collect_shallow_effects(instr : TInstr) -> GEEffects {
  let effects = GEEffects::new()
  ge_collect_shallow_effects_into(instr, effects)
  effects
}

///|
fn ge_collect_effects_texpr(body : TExpr) -> GEEffects {
  let effects = GEEffects::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    ge_collect_shallow_effects_into(curr, effects)
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), body))
  effects
}

///|
fn ge_scan_defined_func(func : Func, total_funcs : Int) -> GEFuncInfo {
  let info = GEFuncInfo::new()
  match func {
    TFunc(_, body) => {
      let full_effects = ge_collect_effects_texpr(body)
      let mut effects_opt : GEEffects? = Some(full_effects)
      if full_effects.calls {
        match effects_opt {
          Some(effects) => {
            effects.calls = false
            effects.throws = false
          }
          None => ()
        }
        let scanner = ModuleTransformer::new().on_tinstruction_evt(fn(
          self,
          _,
          curr,
        ) {
          match curr {
            TCall(target, _) | TReturnCall(target, _) => {
              let called = ge_funcidx_to_int(target)
              if ge_in_func_range(called, total_funcs) {
                info.called_functions.add(called)
              }
            }
            _ => {
              let shallow = ge_collect_shallow_effects(curr)
              if shallow.calls {
                effects_opt = None
              } else if shallow.throws {
                match effects_opt {
                  Some(effects) => effects.throws = true
                  None => ()
                }
              }
            }
          }
          self.walk_tinstruction_default((), curr)
        })
        ignore(scanner.walk_texpr((), body))
      }
      info.effects = effects_opt
    }
    _ => info.effects = None
  }
  info
}

///|
fn global_effects_compute(mod : Module) -> Array[GEEffects?] {
  let imported_funcs = ge_count_imported_funcs(mod)
  let defined_funcs = ge_count_defined_funcs(mod)
  let total_funcs = imported_funcs + defined_funcs
  let infos : Array[GEFuncInfo] = Array::make(total_funcs, GEFuncInfo::new())

  for i = 0; i < imported_funcs; i = i + 1 {
    infos[i].effects = None
  }

  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for def_idx = 0; def_idx < funcs.length(); def_idx = def_idx + 1 {
        let abs_idx = imported_funcs + def_idx
        infos[abs_idx] = ge_scan_defined_func(funcs[def_idx], total_funcs)
      }
    None => ()
  }

  let callers : Array[Set[Int]] = Array::make(total_funcs, Set::new())
  let work : Array[(Int, Int)] = []
  for caller = 0; caller < total_funcs; caller = caller + 1 {
    for called in infos[caller].called_functions {
      work.push((caller, called))
    }
  }

  while !work.is_empty() {
    let (caller, called) = work.pop().unwrap()
    if !ge_in_func_range(caller, total_funcs) ||
      !ge_in_func_range(called, total_funcs) {
      continue
    }
    if callers[called].contains(caller) {
      continue
    }
    callers[called].add(caller)
    for called_by_called in infos[called].called_functions {
      if ge_in_func_range(called_by_called, total_funcs) &&
        !callers[called_by_called].contains(caller) {
        work.push((caller, called_by_called))
      }
    }
  }

  for i = 0; i < total_funcs; i = i + 1 {
    if callers[i].contains(i) {
      match infos[i].effects {
        Some(effects) => effects.traps = true
        None => ()
      }
    }
  }

  for callee = 0; callee < total_funcs; callee = callee + 1 {
    for caller in callers[callee] {
      match infos[caller].effects {
        None => ()
        Some(caller_effects) =>
          match infos[callee].effects {
            None => infos[caller].effects = None
            Some(callee_effects) => caller_effects.merge_in(callee_effects)
          }
      }
    }
  }

  let out : Array[GEEffects?] = Array::make(total_funcs, None)
  for i = 0; i < total_funcs; i = i + 1 {
    out[i] = infos[i].effects
  }
  out
}

///|
fn global_effects_ir_pass(mod : Module) -> ModuleTransformer[IRContext] {
  ignore(mod)
  ModuleTransformer::new().on_module_evt(fn(
    _,
    _ctx : IRContext,
    _mod : Module,
  ) {
    ignore(global_effects_compute(_mod))
    unchanged()
  })
}

///|
fn ge_expect_known(effects : Array[GEEffects?], idx : Int) -> GEEffects raise {
  match effects[idx] {
    Some(effect) => effect
    None => fail("expected known effects for function \{idx}")
  }
}

///|
test "global effects computes transitive direct-call effects and recursion traps" {
  let mod = Module::new()
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), false),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(1), [])])),
        Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(2), [])])),
        Func::t_func(
          [],
          TExpr::new([TInstr::drop(TInstr::global_get(GlobalIdx::new(0)))]),
        ),
        Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(3), [])])),
      ]),
    )
  let effects = global_effects_compute(mod)
  let fx0 = ge_expect_known(effects, 0)
  let fx1 = ge_expect_known(effects, 1)
  let fx2 = ge_expect_known(effects, 2)
  let fx3 = ge_expect_known(effects, 3)
  assert_true(fx0.reads_globals)
  assert_true(fx1.reads_globals)
  assert_true(fx2.reads_globals)
  assert_true(!fx0.calls)
  assert_true(!fx1.calls)
  assert_true(!fx2.calls)
  assert_true(fx3.traps)
}

///|
test "global effects marks indirect-call functions as unknown" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::funcref()],
        TExpr::new([
          TInstr::call_ref(
            TypeIdx::new(0),
            [],
            TInstr::local_get(LocalIdx::new(0)),
          ),
        ]),
      ),
    ]),
  )
  let effects = global_effects_compute(mod)
  match effects[0] {
    None => ()
    Some(_) => fail("expected unknown effects for call_ref")
  }
}

///|
test "global effects treats imported calls as unknown and propagates to callers" {
  let void_ty = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([void_ty]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("imp"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(0), [])])),
      ]),
    )
  let effects = global_effects_compute(mod)
  assert_eq(effects.length(), 2)
  match effects[0] {
    None => ()
    Some(_) => fail("expected imported function effects to remain unknown")
  }
  match effects[1] {
    None => ()
    Some(_) => fail("expected caller of imported function to be unknown")
  }
}

///|
test "global effects preserves non-call throw effects when direct calls exist" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::call(FuncIdx::new(1), []),
          TInstr::throw_(TagIdx::new(0), []),
        ]),
      ),
      Func::t_func([], TExpr::new([TInstr::nop()])),
    ]),
  )
  let effects = global_effects_compute(mod)
  let fx0 = ge_expect_known(effects, 0)
  assert_true(fx0.throws)
}

///|
test "global effects propagates throws from direct callees" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(1), [])])),
      Func::t_func([], TExpr::new([TInstr::throw_(TagIdx::new(0), [])])),
    ]),
  )
  let effects = global_effects_compute(mod)
  let fx0 = ge_expect_known(effects, 0)
  assert_true(fx0.throws)
}

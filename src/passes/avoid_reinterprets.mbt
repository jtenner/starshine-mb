///|
fn is_reinterpret(op : UnaryOp) -> Bool {
  match op {
    I32ReinterpretF32Op => true
    I64ReinterpretF64Op => true
    F32ReinterpretI32Op => true
    F64ReinterpretI64Op => true
    _ => false
  }
}

///|
fn reinterpret_load_op(op : LoadOp) -> LoadOp? {
  match op {
    F32LoadOp => Some(LoadOp::i32_load())
    I32LoadOp => Some(LoadOp::f32_load())
    F64LoadOp => Some(LoadOp::i64_load())
    I64LoadOp => Some(LoadOp::f64_load())
    _ => None
  }
}

///|
fn reinterpret_compatible(op : UnaryOp, load_op : LoadOp) -> Bool {
  match (op, load_op) {
    (I32ReinterpretF32Op, F32LoadOp) => true
    (F32ReinterpretI32Op, I32LoadOp) => true
    (I64ReinterpretF64Op, F64LoadOp) => true
    (F64ReinterpretI64Op, I64LoadOp) => true
    _ => false
  }
}

///|
fn rewrite_reinterpret_of_load(instr : TInstr) -> TInstr? {
  match instr {
    TUnary(op, TLoad(load_op, memarg, ptr)) => {
      if !reinterpret_compatible(op, load_op) {
        return None
      }
      match reinterpret_load_op(load_op) {
        Some(new_op) => Some(TInstr::load(new_op, memarg, ptr))
        None => None
      }
    }
    _ => None
  }
}

///|
fn get_single_load_from_local(
  graph : LocalGraph,
  get_idx : Int,
) -> (LoadOp, MemArg, TInstr)? {
  let sets = graph.get_sets(get_idx)
  if sets.length() != 1 {
    return None
  }
  match sets.to_array()[0] {
    LocalSet::Set(_, TLocalSet(_, TLoad(op, memarg, ptr))) =>
      Some((op, memarg, ptr))
    _ => None
  }
}

///|
fn avoid_reinterprets() -> ModuleTransformer[IRContext] {
  let mut idx = 0
  ModuleTransformer::new()
  .on_func_evt(fn(self, state : IRContext, func) {
    match func {
      Func(_) => Err("Expected TFunc")
      TFunc(_, body) => {
        state.set_body(body)
        self.walk_func_default(state, func)
      }
    }
  })
  .on_tinstruction_evt(fn(_self, state, instr) {
    let cur_idx = idx
    match instr {
      TInstr::TUnary(_, TInstr::TLocalGet(_)) => idx += 1
      _ => ()
    }

    // Case A: reinterpret(load)
    if rewrite_reinterpret_of_load(instr) is Some(new_instr) {
      return change(state, new_instr)
    }
    let graph = state.get_local_graph()

    // Case B: reinterpret(local.get)
    match instr {
      TInstr::TUnary(op, TInstr::TLocalGet(_)) if is_reinterpret(op) =>
        match get_single_load_from_local(graph, cur_idx) {
          Some((load_op, memarg, ptr)) =>
            match reinterpret_load_op(load_op) {
              Some(new_op) => change(state, TInstr::load(new_op, memarg, ptr))
              None => change(state, instr)
            }
          None => change(state, instr)
        }
      _ => unchanged()
    }
  })
}

///|
test "AvoidReinterprets: rewrite reinterpret(load)" {
  let instr = TInstr::unary(
    UnaryOp::i32_reinterpret_f32(),
    TInstr::load(
      LoadOp::f32_load(),
      MemArg::new(0, None, 0),
      TInstr::i32_const(I32(0)),
    ),
  )
  let expr = TExpr::new([instr])
  let func = Func::t_func([], expr)
  let pass = avoid_reinterprets()
  let state = IRContext::new()
  let (_, new_func) = pass.walk_func(state, func).unwrap().unwrap()
  match new_func {
    TFunc(_, TExpr(instrs)) =>
      match instrs[0] {
        TInstr::TLoad(LoadOp::I32LoadOp, _, _) => ()
        _ => fail("expected i32.load")
      }
    _ => fail("expected TFunc")
  }
}

///|
test "AvoidReinterprets: rewrite reinterpret(local.get) with single load" {
  let x = LocalIdx::new(0)
  let instrs = [
    TInstr::local_set(
      x,
      TInstr::load(
        LoadOp::f32_load(),
        MemArg::new(0, None, 0),
        TInstr::i32_const(I32(0)),
      ),
    ),
    TInstr::unary(UnaryOp::i32_reinterpret_f32(), TInstr::local_get(x)),
  ]
  let expr = TExpr::new(instrs)
  let func = Func::t_func([], expr)
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = avoid_reinterprets()
  let initial_state = IRContext::new()
  let (_, new_module) = pass.walk_module(initial_state, mod).unwrap().unwrap()
  let CodeSec(funcs) = new_module.code_sec.unwrap()
  let new_func = funcs[0]
  match new_func {
    TFunc(_, TExpr(new_instrs)) =>
      match new_instrs[1] {
        TInstr::TLoad(LoadOp::I32LoadOp, _, _) => ()
        _ => fail("expected i32.load")
      }
    _ => fail("expected TFunc")
  }
}

///|
test "AvoidReinterprets: do not rewrite when multiple defining loads exist" {
  let x = LocalIdx::new(0)
  let instrs = [
    TInstr::local_set(
      x,
      TInstr::load(
        LoadOp::f32_load(),
        MemArg::new(0, None, 0),
        TInstr::i32_const(I32(0)),
      ),
    ),
    TInstr::local_set(
      x,
      TInstr::load(
        LoadOp::f32_load(),
        MemArg::new(4, None, 0),
        TInstr::i32_const(I32(0)),
      ),
    ),
    TInstr::unary(UnaryOp::i32_reinterpret_f32(), TInstr::local_get(x)),
  ]
  let expr = TExpr::new(instrs)
  let func = Func::t_func([], expr)
  let pass = avoid_reinterprets()
  let state = IRContext::new()
  let (_, new_func) = pass.walk_func(state, func).unwrap().unwrap()
  match new_func {
    TFunc(_, TExpr(new_instrs)) =>
      match new_instrs[2] {
        TInstr::TLoad(LoadOp::I32LoadOp, _, _) => ()
        _ => fail("expected i32.load")
      }
    _ => fail("expected TFunc")
  }
}

///|
test "AvoidReinterprets: unrelated instructions are unchanged" {
  let instr = TInstr::unary(UnaryOp::i32_eqz(), TInstr::i32_const(I32(0)))
  let expr = TExpr::new([instr])
  let func = Func::t_func([], expr)
  let pass = avoid_reinterprets()
  let state = IRContext::new()
  let (_, new_func) = pass.walk_func(state, func).unwrap().unwrap()
  assert_eq(new_func, func)
}

///|
test "AvoidReinterprets: reinterpret of non-load is unchanged" {
  let instr = TInstr::unary(
    UnaryOp::i32_reinterpret_f32(),
    TInstr::i32_const(I32(42)),
  )
  let expr = TExpr::new([instr])
  let func = Func::t_func([], expr)
  let pass = avoid_reinterprets()
  let state = IRContext::new()
  let (_, new_func) = pass.walk_func(state, func).unwrap().unwrap()
  assert_eq(new_func, func)
}

///|
test "AvoidReinterprets: reinterpret with mismatched load type is unchanged" {
  let instr = TInstr::unary(
    UnaryOp::i64_reinterpret_f64(),
    TInstr::load(
      LoadOp::f32_load(), // mismatch
      MemArg::new(0, None, 0),
      TInstr::i32_const(I32(0)),
    ),
  )
  let expr = TExpr::new([instr])
  let func = Func::t_func([], expr)
  let pass = avoid_reinterprets()
  let state = IRContext::new()
  let (_, new_func) = pass.walk_func(state, func).unwrap().unwrap()
  assert_eq(new_func, func)
}

///|
test "AvoidReinterprets: reinterpret(local.get) inside expression" {
  let x = LocalIdx::new(0)
  let instrs = [
    TInstr::local_set(
      x,
      TInstr::load(
        LoadOp::f32_load(),
        MemArg::new(0, None, 0),
        TInstr::i32_const(I32(0)),
      ),
    ),
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::unary(UnaryOp::i32_reinterpret_f32(), TInstr::local_get(x)),
      TInstr::i32_const(I32(1)),
    ),
  ]
  let expr = TExpr::new(instrs)
  let func = Func::t_func([], expr)
  let pass = avoid_reinterprets()
  let state = IRContext::new()
  let (_, new_func) = pass.walk_func(state, func).unwrap().unwrap()
  match new_func {
    TFunc(_, TExpr(new_instrs)) =>
      match new_instrs[1] {
        TInstr::TBinary(_, TInstr::TLoad(LoadOp::I32LoadOp, _, _), _) => ()
        _ => fail("expected i32.load inside binary expression")
      }
    _ => fail("expected TFunc")
  }
}

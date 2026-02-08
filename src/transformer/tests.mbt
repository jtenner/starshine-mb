///|
test "change and unchanged helpers return expected transformer results" {
  match (change(7, 9) : TransformerResult[Int, Int]) {
    Ok(Some((state, value))) => {
      assert_eq(state, 7)
      assert_eq(value, 9)
    }
    _ => fail("expected change to return Some result")
  }
  match (unchanged() : TransformerResult[Int, Int]) {
    Ok(None) => ()
    _ => fail("expected unchanged to return None")
  }
}

///|
test "walk_module applies on_tinstruction rewrite" {
  let transformer = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    instr,
  ) {
    match instr {
      TLocalGet(LocalIdx(i)) if i == 0U =>
        change((), TInstr::local_get(LocalIdx::new(1)))
      _ => self.walk_tinstruction_default((), instr)
    }
  })
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func([], TExpr::new([TInstr::local_get(LocalIdx::new(0))])),
    ]),
  )
  let rewritten = match transformer.walk_module((), mod) {
    Ok(Some((_, m))) => m
    Ok(None) => fail("expected transformed module")
    Err(e) => fail("unexpected walk_module error: \{e}")
  }
  match rewritten.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TLocalGet(LocalIdx(i))]))])) =>
      assert_eq(i, 1U)
    _ => fail("expected local.get index rewrite")
  }
}

///|
test "walk_module forwards event errors" {
  let transformer = ModuleTransformer::new().on_tinstruction_evt(fn(
    _,
    _,
    instr,
  ) {
    match instr {
      TNop => error("boom")
      _ => unchanged()
    }
  })
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
  )
  match transformer.walk_module((), mod) {
    Ok(_) => fail("expected walk_module to return Err")
    Err(msg) => assert_eq(msg, "boom")
  }
}

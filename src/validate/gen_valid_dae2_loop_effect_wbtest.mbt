///|
fn dae2_gen_loop_effect_shape(input : Module) -> Bool? {
  let bodies = match input.code_sec {
    Some(CodeSec(bodies)) => bodies
    None => return None
  }
  let Func(_, Expr(body)) = bodies[bodies.length() - 1]
  for index = 0; index + 1 < body.length(); index = index + 1 {
    match (body[index], body[index + 1]) {
      (
        Instruction::Loop(VoidBlockType, Expr(loop_body)),
        Instruction::LocalGet(local),
      ) => {
        if loop_body.length() < 2 ||
          loop_body[loop_body.length() - 1] != Instruction::local_set(local) ||
          loop_body[loop_body.length() - 2] !=
          Instruction::call(FuncIdx::new(0U)) ||
          !loop_body.any(fn(op) { op is Instruction::I32Load(_) }) {
          continue
        }
        let Func(_, Expr(producer)) = bodies[0]
        let exports = input.export_sec.unwrap().0
        if !producer.any(fn(op) { op is Instruction::GlobalSet(_) }) ||
          !exports.any(fn(item) {
            let Export(_, kind) = item
            kind == ExternIdx::global(GlobalIdx::new(0U))
          }) ||
          !exports.any(fn(item) {
            let Export(_, kind) = item
            kind ==
            ExternIdx::func(FuncIdx::new((bodies.length() - 1).to_uint()))
          }) {
          return None
        }
        let mut held = false
        for prefix in 0..<index {
          held = held || body[prefix] is Instruction::I32Load(_)
        }
        return Some(held)
      }
      _ => ()
    }
  }
  None
}

///|
fn dae2_gen_loop_prefix_traps(input : Module) -> Bool {
  let CodeSec(bodies) = input.code_sec.unwrap()
  let Func(_, Expr(body)) = bodies[bodies.length() - 1]
  body[0] is Instruction::I32Const(I32(65536))
}

///|
test "dae2 control generator emits effectful void loop stores and held trapping prefixes" {
  let mut plain = false
  let mut held = false
  let mut held_trap = false
  for seed in [0UL, 8UL, 16UL, 24UL] {
    let input = gen_valid_module_from_seed(
        seed,
        GenValidConfig::for_profile(Dae2ControlFlowProfile),
      ).unwrap().wasm_module
    validate_module(input).unwrap()
    match dae2_gen_loop_effect_shape(input) {
      Some(false) => plain = true
      Some(true) => {
        held_trap = held_trap || dae2_gen_loop_prefix_traps(input)
        held = held || !dae2_gen_loop_prefix_traps(input)
      }
      None => ()
    }
  }
  assert_true(
    plain,
    msg="control profile missed effectful void loop result capture",
  )
  assert_true(
    held,
    msg="control profile missed a trapping load held across the loop",
  )
  assert_true(
    held_trap,
    msg="control profile missed a held out-of-bounds load before the effect",
  )
}

///|
#skip("dedicated DAE2 aggregate shape coverage; no default seed sweep")
test "dae2 aggregate selects observable void loop captures and held load variants" {
  let mut plain = false
  let mut held = false
  let mut held_trap = false
  for index in 1..<257 {
    if gen_valid_profile_leaf_for_case(Dae2AllProfile, 0x5eedUL, index) !=
      Dae2ControlFlowProfile {
      continue
    }
    let input = gen_valid_module_from_seed(
        gen_valid_case_seed(0x5eedUL, index),
        GenValidConfig::for_profile(Dae2ControlFlowProfile),
      ).unwrap().wasm_module
    match dae2_gen_loop_effect_shape(input) {
      Some(false) => plain = true
      Some(true) => {
        held_trap = held_trap || dae2_gen_loop_prefix_traps(input)
        held = held || !dae2_gen_loop_prefix_traps(input)
      }
      None => ()
    }
  }
  assert_true(
    plain && held && held_trap,
    msg="aggregate missed one loop-effect observation family",
  )
}

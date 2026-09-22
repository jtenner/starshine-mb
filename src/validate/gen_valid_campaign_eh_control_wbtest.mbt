///|
fn gen_valid_campaign_eh_control_test_body(
  mod_ : Module,
) -> Array[Instruction]? {
  match mod_.code_sec {
    Some(CodeSec([Func(_, Expr(body))])) => Some(body)
    _ => None
  }
}

///|
fn gen_valid_campaign_eh_control_test_shape(mod_ : Module) -> Int? {
  let body = match gen_valid_campaign_eh_control_test_body(mod_) {
    Some(body) => body
    None => return None
  }
  match body {
    [
      Block(
        _,
        Expr([TryTable(_, [Catch(TagIdx(1U), LabelIdx(0U))], _), I32Const(_)])
      ),
      Drop,
      ..,
    ] => Some(5)
    [
      Block(
        ValTypeBlockType(_),
        Expr(
          [
            TryTable(VoidBlockType, [CatchRef(TagIdx(0U), LabelIdx(0U))], _),
            RefNull(_),
          ]
        )
      ),
      Drop,
      ..,
    ] => Some(1)
    [Block(_, Expr([TryTable(_, catches, _)])), ..] =>
      match catches {
        [Catch(TagIdx(0U), LabelIdx(0U))] => Some(0)
        [CatchAll(LabelIdx(0U))] => Some(2)
        [CatchAllRef(LabelIdx(0U))] => Some(3)
        _ => None
      }
    [Block(_, Expr([Block(_, Expr([TryTable(_, catches, _)]))])), ..] =>
      match catches {
        [Catch(TagIdx(0U), LabelIdx(1U))] => Some(4)
        _ => None
      }
    [Try(_, _, [LegacyCatch(TagIdx(0U), Expr([Rethrow(LabelIdx(0U))]))], _), ..] =>
      Some(6)
    [
      Block(
        TypeIdxBlockType(TypeIdx(2U)),
        Expr(
          [
            Block(
              TypeIdxBlockType(TypeIdx(2U)),
              Expr(
                [_, _, _, BrTable([LabelIdx(0U), LabelIdx(1U)], LabelIdx(1U))]
              )
            ),
          ]
        )
      ),
      ..,
    ] => Some(7)
    _ => None
  }
}

///|
test "campaign EH control GenValid covers eight exact layouts and validates" {
  let profile = match gen_valid_profile_by_name("campaign-eh-control") {
    Ok(profile) => profile
    Err(message) => fail(message)
  }
  let seen : Array[Bool] = [
    false, false, false, false, false, false, false, false,
  ]
  for seed = 0; seed < 128; seed = seed + 1 {
    let generated = match
      gen_valid_module_result_from_seed(
        seed.to_uint64(),
        GenValidConfig::for_profile(profile),
      ) {
      Ok(value) => value
      Err(failure) => fail(failure.validation_error_message)
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    let shape = match
      gen_valid_campaign_eh_control_test_shape(generated.wasm_module) {
      Some(shape) => shape
      None => fail("unexpected EH/control campaign body for seed \{seed}")
    }
    @debug.assert_eq(shape, seed % 8)
    seen[shape] = true
  }
  for found in seen {
    assert_true(found)
  }
}

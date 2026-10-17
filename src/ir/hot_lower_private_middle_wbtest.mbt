///|
fn lower_middle_apply(
  kind : String,
  func : HotFunc,
  body : Array[Instruction],
  extras : Array[ValType],
  options : HotLowerOptions,
  reference~ : Bool = false,
) -> Array[Instruction] {
  match kind {
    "nested" =>
      if reference {
        lower_middle_reference_stackify_nested_body(func, body, extras, options)
      } else {
        hot_lower_impl_stackify_nested_body(func, body, extras, options)
      }
    "prefix" =>
      if reference {
        lower_middle_reference_stackify_wrapped_struct_set_prefixes(
          func, body, extras, options,
        )
      } else {
        hot_lower_impl_stackify_wrapped_struct_set_prefixes(
          func, body, extras, options,
        )
      }
    "split" =>
      if reference {
        lower_middle_reference_fix_split_payload_wrappers_in_body(body)
      } else {
        hot_lower_impl_fix_split_payload_wrappers_in_body(body)
      }
    "tee" =>
      if reference {
        lower_middle_reference_prune_dead_local_tees_in_body(
          body,
          [8, 8],
          options,
        )
      } else {
        hot_lower_impl_prune_dead_local_tees_in_body(body, [8, 8], options)
      }
    _ => abort("unknown private lower stage")
  }
}

///|
test "private lower middle stages keep unchanged nested instructions and bytes" {
  let input = @wast.wast_to_binary_module(
    "(module (func (param i32) block loop local.get 0 drop end end local.get 0 if local.get 0 drop else local.get 0 drop end block try_table (catch_all 0) block i32.const 0 br_table 0 1 end end end local.get 0 local.get 0 local.get 0 select (result i32) drop))",
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, Expr(body)) = input.code_sec.unwrap().0[0]
  let hot = hot_lift_func(input, FuncIdx::new(0U))
  for
    options in [
      HotLowerOptions::new(),
      HotLowerOptions::new(
        preserve_if_arm_single_nops=true,
        preserve_dead_local_tee_drops=true,
        preserve_nontrailing_nops=true,
        preserve_trailing_nops=true,
        preserve_typed_loop_const_prefix_spills=true,
        preserve_flat_ir_spills=true,
        flatten_unused_result_blocks=true,
        preserve_struct_set_value_blocks=true,
      ),
    ] {
    for kind in ["nested", "prefix", "split", "tee"] {
      let expected = lower_middle_apply(
        kind,
        hot,
        body,
        [],
        options,
        reference=true,
      )
      let output = lower_middle_apply(kind, hot, body, [], options)
      assert_eq(output, expected)
      assert_eq(output, body)
      assert_eq(
        @binary.encode_module(
          input.with_code_sec(
            @lib.CodeSec::new([@lib.Func::new(locals, Expr::new(output))]),
          ),
        ).unwrap(),
        saved,
      )
      assert_eq(@binary.encode_module(input).unwrap(), saved)
      assert_true(physical_equal(output, body), msg=kind)
    }
  }
}

///|
test "private lower middle stages retain active prefix scratch and nested rewrites" {
  let ref_type = ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(0U)))
  let hot = HotFunc::new(locals=HotLocals::new(locals=[ref_type]))
  let active = [
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([
        Instruction::i32_const(I32(0)),
        Instruction::drop(),
        Instruction::i32_const(I32(7)),
      ]),
    ),
    Instruction::struct_set(@lib.TypeIdx::new(0U), @lib.U32(0U)),
  ]
  for nested in [false, true] {
    let body = if nested {
      [Instruction::loop_(BlockType::void_(), Expr::new(active))]
    } else {
      active
    }
    let extras : Array[ValType] = []
    let expected_extras : Array[ValType] = []
    let kind = if nested { "nested" } else { "prefix" }
    let output = lower_middle_apply(
      kind,
      hot,
      body,
      extras,
      HotLowerOptions::new(),
    )
    let expected = lower_middle_apply(
      kind,
      hot,
      body,
      expected_extras,
      HotLowerOptions::new(),
      reference=true,
    )
    assert_eq(output, expected)
    assert_eq(extras, expected_extras)
    assert_eq(extras, [ref_type])
    assert_true(output != body)
    let preserved = lower_middle_apply(
      kind,
      hot,
      body,
      [],
      HotLowerOptions::new(preserve_struct_set_value_blocks=true),
    )
    assert_eq(preserved, body)
    assert_true(physical_equal(preserved, body))
  }
}

///|
test "private lower split fix keeps its exact active branch depth rewrite" {
  let bt = BlockType::val_type(ValType::i32())
  let child = [
    Instruction::i32_const(I32(1)),
    Instruction::if_(
      BlockType::void_(),
      [Instruction::br(LabelIdx::new(1U))],
      Some([Instruction::br(LabelIdx::new(2U))]),
    ),
  ]
  let body = [
    Instruction::block(
      bt,
      Expr::new([
        Instruction::block(
          BlockType::void_(),
          Expr::new([
            Instruction::block(
              bt,
              Expr::new([
                Instruction::block(BlockType::void_(), Expr::new(child)),
                Instruction::i32_const(I32(7)),
              ]),
            ),
            Instruction::br(LabelIdx::new(1U)),
          ]),
        ),
        Instruction::i32_const(I32(9)),
      ]),
    ),
  ]
  let expected = lower_middle_reference_fix_split_payload_wrappers_in_body(body)
  let output = hot_lower_impl_fix_split_payload_wrappers_in_body(body)
  assert_eq(output, expected)
  assert_true(output != body)
  guard output[0] is Block(_, Expr(outer)) else { fail("missing outer block") }
  guard outer[0] is Block(_, Expr(wrapper)) else { fail("missing wrapper") }
  guard wrapper[0] is Block(_, Expr(inner)) else {
    fail("missing payload block")
  }
  guard inner[0] is Block(_, Expr(fixed)) else { fail("missing fixed child") }
  guard fixed[1] is If(_, yes, Some(no)) else {
    fail("missing fixed conditional")
  }
  assert_eq(yes, [Instruction::br(LabelIdx::new(0U))])
  assert_eq(no, [Instruction::br(LabelIdx::new(1U))])
}

///|
test "private lower tee pruning removes dead tees and preserves requested tee drop shape" {
  let local = LocalIdx::new(0U)
  let child = [
    Instruction::i32_const(I32(7)),
    Instruction::local_tee(local),
    Instruction::drop(),
  ]
  let body = [Instruction::block(BlockType::void_(), Expr::new(child))]
  let options = HotLowerOptions::new()
  let expected = lower_middle_reference_prune_dead_local_tees_in_body(
    body,
    [0],
    options,
  )
  let output = hot_lower_impl_prune_dead_local_tees_in_body(body, [0], options)
  assert_eq(output, expected)
  assert_eq(output, [
    Instruction::block(
      BlockType::void_(),
      Expr::new([Instruction::i32_const(I32(7)), Instruction::drop()]),
    ),
  ])
  let preserved = hot_lower_impl_prune_dead_local_tees_in_body(
    body,
    [0],
    HotLowerOptions::new(preserve_dead_local_tee_drops=true),
  )
  assert_eq(preserved, body)
  assert_true(physical_equal(preserved, body))
}

///|
fn lower_middle_mutate_public_payload(
  body : Array[Instruction],
  kind : String,
) -> Bool {
  for instr in body {
    match (kind, instr) {
      ("select", Select(Some(types))) => {
        types[0] = ValType::i64()
        return true
      }
      ("table", BrTable(targets, _)) if !targets.is_empty() => {
        targets[0] = LabelIdx::new(1U)
        return true
      }
      ("catch", TryTable(_, catches, _)) if !catches.is_empty() => {
        catches[0] = @lib.Catch::all(LabelIdx::new(1U))
        return true
      }
      ("body", If(_, yes, _)) => {
        yes.push(Instruction::nop())
        return true
      }
      _ => ()
    }
    match instr {
      Block(_, Expr(child))
      | Loop(_, Expr(child))
      | TryTable(_, _, Expr(child)) =>
        if lower_middle_mutate_public_payload(child, kind) {
          return true
        }
      If(_, yes, no) => {
        if lower_middle_mutate_public_payload(yes, kind) {
          return true
        }
        if no is Some(child) && lower_middle_mutate_public_payload(child, kind) {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
test "private middle retention keeps public lowering payload and body ownership" {
  for
    (kind, control) in [
      ("select", "local.get 0 local.get 0 local.get 0 select (result i32) drop"),
      ("table", "block block local.get 0 br_table 0 1 end end"),
      ("catch", "block try_table (catch_all 0) local.get 0 drop end end"),
      ("body", "local.get 0 if local.get 0 drop else local.get 0 drop end"),
    ] {
    let input = @wast.wast_to_binary_module(
      "(module (func (param i32) \{control}))",
    ).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let hot = hot_lift_func(input, FuncIdx::new(0U))
    let first = hot_lower_func(hot)
    let expected_module = input.with_code_sec(@lib.CodeSec::new([first]))
    @validate.validate_module(expected_module).unwrap()
    let expected_bytes = @binary.encode_module(expected_module).unwrap()
    let @lib.Func(_, Expr(body)) = first
    assert_true(lower_middle_mutate_public_payload(body, kind), msg=kind)
    let second = input.with_code_sec(@lib.CodeSec::new([hot_lower_func(hot)]))
    @validate.validate_module(second).unwrap()
    assert_eq(@binary.encode_module(second).unwrap(), expected_bytes)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

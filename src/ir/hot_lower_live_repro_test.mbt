///|
test "hot lower keeps unreachable in exact cmd inner carrier shape" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32 i32) (result i32) (local i32 i32 i32 i32 i32) (local.set 3 (block $block2 (result i32) (block $block1 (br $block2 (block (result i32) (block $block (if (i32.eq (local.get 0) (i32.const 1)) (then (local.set 4 (local.tee 5 (local.get 1))) (br $block)) (else (local.set 6 (local.tee 7 (local.get 2))) (br $block1)))) (local.get 4)))))) (local.get 3)))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
              [@lib.ValType::i32()],
            ),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "hot lower live repro validates parent-exit payload carry shape" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (block $outer (result i32) (block $exit (block $work (if (i32.eq (local.get 0) (i32.const 1)) (then (local.set 2 (local.get 1)) (br $work)) (else (local.set 2 (i32.const 9)) (br $exit))) unreachable) (br $outer (local.get 2))) (i32.const 0))))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates compare-shape split local.set carry" {
  let source =
    #|(module
    #|  (func (param i64) (result i32) (local i32 i32 i64 i32)
    #|    (local.set 1
    #|      (block $block24 (result i32)
    #|        (block $block23
    #|          (if
    #|            (i64.eq
    #|              (local.tee 3
    #|                (local.get 0))
    #|              (i64.const 4294967296))
    #|            (then
    #|              (drop
    #|                (i32.const 5))
    #|              (br $block23))
    #|            (else
    #|              (local.set 2
    #|                (local.tee 4
    #|                  (i32.wrap_i64
    #|                    (local.tee 3
    #|                      (local.get 3)))))
    #|              (br $block23)))
    #|          unreachable)
    #|        (local.get 2)))
    #|    (local.get 1)))
  let fixture = ir_test_build_hot_from_wat(source)
  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates typed loop carrier reloads backedge value" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $loop (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $loop
    #|      end
    #|      local.get 1
    #|      drop
    #|    end
    #|    i32.const 1)
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates repeated shared operand emission" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (i32.add (local.get 0) (local.get 1))))",
  )
  let add_id = hot_root_get(fixture.hot_func, 0)
  let lhs = hot_child_get(fixture.hot_func, add_id, 0)
  hot_child_set(fixture.hot_func, add_id, 1, lhs)
  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates value-if condition consumed before later drop" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32)
    #|    i32.const 0
    #|    loop $loop (type $loop_t)
    #|      local.tee 0
    #|      i32.const 0
    #|      i32.lt_s
    #|      if (result i32)
    #|        i32.const 1
    #|      else
    #|        local.get 0
    #|        i32.const 5
    #|        i32.ge_s
    #|      end
    #|      if
    #|        nop
    #|      end
    #|      local.get 0
    #|      drop
    #|      local.get 0
    #|      i32.const 1
    #|      i32.add
    #|      br $loop
    #|    end
    #|    i32.const 1)
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  let mut loop_id = -1
  for idx = 0; idx < hot_root_count(fixture.hot_func); idx = idx + 1 {
    let root_id = hot_root_get(fixture.hot_func, idx)
    match hot_node_get(fixture.hot_func, root_id).op {
      Loop => {
        loop_id = root_id
        break
      }
      _ => ()
    }
  }
  if loop_id < 0 {
    fail("expected fixture loop root")
  }
  let loop_body = hot_region_body_ref(fixture.hot_func, loop_id)
  let value_if = hot_region_get(fixture.hot_func, loop_body, 0)
  let inner_value_if = hot_child_get(fixture.hot_func, value_if, 0)
  let value_if_else = match
    hot_region_else_ref(fixture.hot_func, inner_value_if) {
    Some(region) => region
    None => fail("expected nested if with else")
  }
  let compare = hot_region_get(fixture.hot_func, value_if_else, 0)
  let shared_local_get = hot_child_get(fixture.hot_func, compare, 0)
  let drop_root = hot_region_get(fixture.hot_func, loop_body, 2)
  hot_child_set(fixture.hot_func, drop_root, 0, shared_local_get)
  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates moving a set past an earlier zero-result branch root" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) block $done local.get 0 br_if $done end i32.const 7 local.set 2 local.get 0 if local.get 1 drop end local.get 2))",
  )
  let block_id = hot_root_get(fixture.hot_func, 0)
  let local_set = hot_root_get(fixture.hot_func, 1)
  let if_id = hot_root_get(fixture.hot_func, 2)
  let local_get = hot_root_get(fixture.hot_func, 3)

  hot_region_replace_body(fixture.hot_func, HotRegionRef::root(), [
    block_id, if_id, local_set, local_get,
  ])

  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates moving a set past an earlier branch root when the crossed gap is branch-free" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32 i32) block $done local.get 0 br_if $done end local.get 1 local.set 2 i32.const 7 local.set 3 local.get 2 if local.get 2 drop end local.get 3))",
  )
  let block_id = hot_root_get(fixture.hot_func, 0)
  let used_set = hot_root_get(fixture.hot_func, 1)
  let moved_set = hot_root_get(fixture.hot_func, 2)
  let if_id = hot_root_get(fixture.hot_func, 3)
  let local_get = hot_root_get(fixture.hot_func, 4)

  hot_region_replace_body(fixture.hot_func, HotRegionRef::root(), [
    block_id, used_set, if_id, moved_set, local_get,
  ])

  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates earlier zero-result branch root inside an outer result carrier" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (block $outer (result i32) (block $done (br_if $done (local.get 0))) (local.set 2 (i32.const 7)) (if (local.get 0) (then (drop (local.get 1)))) (br $outer (local.get 2)))))",
  )
  let outer = hot_root_get(fixture.hot_func, 0)
  let outer_body = hot_region_body_ref(fixture.hot_func, outer)
  let block_id = hot_region_get(fixture.hot_func, outer_body, 0)
  let local_set = hot_region_get(fixture.hot_func, outer_body, 1)
  let if_id = hot_region_get(fixture.hot_func, outer_body, 2)
  let br_id = hot_region_get(fixture.hot_func, outer_body, 3)

  hot_region_replace_body(fixture.hot_func, outer_body, [
    block_id, if_id, local_set, br_id,
  ])

  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates dropped result-carrying block root before later if sink" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32)
    #|    (block $outer (result i32)
    #|      (block $prefix (result i32)
    #|        (block $work
    #|          (if (local.get 0)
    #|            (then
    #|              (br $work))
    #|            (else
    #|              (br $prefix (i32.const 0))))
    #|          unreachable)
    #|        (i32.const 1))
    #|      drop
    #|      (local.get 1)
    #|      (local.set 2)
    #|      (local.get 1)
    #|      (local.set 3)
    #|      (local.get 3)
    #|      (if
    #|        (then
    #|          (drop (local.get 3))))
    #|      (local.get 2)))
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  let mut outer_body : HotRegionRef? = None
  let candidate_tags : Array[String] = []
  for node_id = 0
      node_id < hot_node_count(fixture.hot_func)
      node_id = node_id + 1 {
    if !hot_node_is_live(fixture.hot_func, node_id) {
      continue
    }
    match hot_node_get(fixture.hot_func, node_id).op {
      Block =>
        if hot_node_result_arity(fixture.hot_func, node_id) == 1 {
          let region = hot_region_body_ref(fixture.hot_func, node_id)
          let tags : Array[String] = []
          for idx = 0
              idx < hot_region_root_count(fixture.hot_func, region)
              idx = idx + 1 {
            let root = hot_region_get(fixture.hot_func, region, idx)
            let op = hot_node_get(fixture.hot_func, root).op
            match op {
              LocalGet | LocalSet | LocalTee =>
                tags.push("\{op}(\{hot_node_get(fixture.hot_func, root).imm0})")
              _ => tags.push(op.to_string())
            }
          }
          candidate_tags.push(tags.to_string())
          if tags == ["Drop", "LocalSet(2)", "LocalSet(3)", "If", "LocalGet(2)"] {
            outer_body = Some(region)
            break
          }
        }
      _ => ()
    }
  }
  let outer_body = match outer_body {
    Some(region) => region
    None => fail("expected result-carrying prefix body: \{candidate_tags}")
  }
  let drop_root = hot_region_get(fixture.hot_func, outer_body, 0)
  let moved_set = hot_region_get(fixture.hot_func, outer_body, 1)
  let used_set = hot_region_get(fixture.hot_func, outer_body, 2)
  let if_id = hot_region_get(fixture.hot_func, outer_body, 3)
  let next_get = hot_region_get(fixture.hot_func, outer_body, 4)

  hot_region_replace_body(fixture.hot_func, outer_body, [
    drop_root, used_set, if_id, moved_set, next_get,
  ])

  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates live-like dropped-owner predecessor chain" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32)
    #|    (block $holder (result i32)
    #|      (drop
    #|        (block $outer (result i32)
    #|          (block $prefix
    #|            (if (local.get 0)
    #|              (then
    #|                (call $touch (local.get 1))
    #|                (br $prefix))
    #|              (else
    #|                (if (local.get 0)
    #|                  (then
    #|                    (call $touch (local.get 1))
    #|                    (br $prefix))
    #|                  (else
    #|                    (drop (i32.const 0)))))))
    #|          (br $outer (i32.const 0))
    #|          (call $touch (local.get 1))
    #|          (local.get 1)
    #|          (local.set 2)
    #|          (local.get 1)
    #|          (local.set 3)
    #|          (local.get 3)
    #|          (if
    #|            (then
    #|              (call $touch (local.get 3))))
    #|          (local.get 2)))
    #|      (i32.const 9)))
    #|  (func $touch (param i32)))
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  let mut outer_body : HotRegionRef? = None
  let candidate_tags : Array[String] = []
  for node_id = 0
      node_id < hot_node_count(fixture.hot_func)
      node_id = node_id + 1 {
    if !hot_node_is_live(fixture.hot_func, node_id) {
      continue
    }
    match hot_node_get(fixture.hot_func, node_id).op {
      Block =>
        if hot_node_result_arity(fixture.hot_func, node_id) == 1 {
          let region = hot_region_body_ref(fixture.hot_func, node_id)
          let tags : Array[String] = []
          for idx = 0
              idx < hot_region_root_count(fixture.hot_func, region)
              idx = idx + 1 {
            let root = hot_region_get(fixture.hot_func, region, idx)
            let op = hot_node_get(fixture.hot_func, root).op
            match op {
              LocalGet | LocalSet | LocalTee =>
                tags.push("\{op}(\{hot_node_get(fixture.hot_func, root).imm0})")
              _ => tags.push(op.to_string())
            }
          }
          candidate_tags.push(tags.to_string())
          if tags ==
            [
              "Block", "Br", "Call", "LocalSet(2)", "LocalSet(3)", "If", "LocalGet(2)",
            ] {
            outer_body = Some(region)
            break
          }
        }
      _ => ()
    }
  }
  let outer_body = match outer_body {
    Some(region) => region
    None => fail("expected live-like dropped-owner body: \{candidate_tags}")
  }
  let prefix_block = hot_region_get(fixture.hot_func, outer_body, 0)
  let br_id = hot_region_get(fixture.hot_func, outer_body, 1)
  let call_id = hot_region_get(fixture.hot_func, outer_body, 2)
  let moved_set = hot_region_get(fixture.hot_func, outer_body, 3)
  let used_set = hot_region_get(fixture.hot_func, outer_body, 4)
  let if_id = hot_region_get(fixture.hot_func, outer_body, 5)
  let next_get = hot_region_get(fixture.hot_func, outer_body, 6)

  hot_region_replace_body(fixture.hot_func, outer_body, [
    prefix_block, br_id, call_id, used_set, if_id, moved_set, next_get,
  ])

  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates self-and-dropped-owner block root before later if sink" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32)
    #|    (block $holder (result i32)
    #|      (drop
    #|        (block $outer (result i32)
    #|          (block $prefix
    #|            (if (local.get 0)
    #|              (then
    #|                (call $touch (local.get 1))
    #|                (br $prefix))
    #|              (else
    #|                (if (local.get 0)
    #|                  (then
    #|                    (call $touch (local.get 1))
    #|                    (br $prefix))
    #|                  (else
    #|                    (drop (i32.const 0))))))
    #|            (br $outer (i32.const 0)))
    #|          (call $touch (local.get 1))
    #|          (local.get 1)
    #|          (local.set 2)
    #|          (local.get 1)
    #|          (local.set 3)
    #|          (local.get 3)
    #|          (if
    #|            (then
    #|              (call $touch (local.get 3))))
    #|          (local.get 2)))
    #|      (i32.const 9)))
    #|  (func $touch (param i32)))
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  let mut outer_body : HotRegionRef? = None
  let candidate_tags : Array[String] = []
  for node_id = 0
      node_id < hot_node_count(fixture.hot_func)
      node_id = node_id + 1 {
    if !hot_node_is_live(fixture.hot_func, node_id) {
      continue
    }
    match hot_node_get(fixture.hot_func, node_id).op {
      Block =>
        if hot_node_result_arity(fixture.hot_func, node_id) == 1 {
          let region = hot_region_body_ref(fixture.hot_func, node_id)
          let tags : Array[String] = []
          for idx = 0
              idx < hot_region_root_count(fixture.hot_func, region)
              idx = idx + 1 {
            let root = hot_region_get(fixture.hot_func, region, idx)
            let op = hot_node_get(fixture.hot_func, root).op
            match op {
              LocalGet | LocalSet | LocalTee =>
                tags.push("\{op}(\{hot_node_get(fixture.hot_func, root).imm0})")
              _ => tags.push(op.to_string())
            }
          }
          candidate_tags.push(tags.to_string())
          if tags ==
            ["Block", "Call", "LocalSet(2)", "LocalSet(3)", "If", "LocalGet(2)"] {
            outer_body = Some(region)
            break
          }
        }
      _ => ()
    }
  }
  let outer_body = match outer_body {
    Some(region) => region
    None => fail("expected self-and-dropped-owner body: \{candidate_tags}")
  }
  let prefix_block = hot_region_get(fixture.hot_func, outer_body, 0)
  let call_id = hot_region_get(fixture.hot_func, outer_body, 1)
  let moved_set = hot_region_get(fixture.hot_func, outer_body, 2)
  let used_set = hot_region_get(fixture.hot_func, outer_body, 3)
  let if_id = hot_region_get(fixture.hot_func, outer_body, 4)
  let next_get = hot_region_get(fixture.hot_func, outer_body, 5)

  hot_region_replace_body(fixture.hot_func, outer_body, [
    prefix_block, call_id, used_set, if_id, moved_set, next_get,
  ])

  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates self-contained block root before later if sink" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32)
    #|    (block $prefix
    #|      (block $carry (result i32)
    #|        (block $work
    #|          (if (local.get 0)
    #|            (then
    #|              (br $work))
    #|            (else
    #|              (br $carry (i32.const 0))))
    #|          unreachable)
    #|        (i32.const 1))
    #|      drop)
    #|    (local.get 1)
    #|    (local.set 2)
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 3)
    #|    (if
    #|      (then
    #|        (drop (local.get 3))))
    #|    (local.get 2))
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  assert_eq(hot_root_count(fixture.hot_func), 5)
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 0)).op.to_string(),
    "Block",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 1)).op.to_string(),
    "LocalSet",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 2)).op.to_string(),
    "LocalSet",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 3)).op.to_string(),
    "If",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 4)).op.to_string(),
    "LocalGet",
  )
  let prefix_block = hot_root_get(fixture.hot_func, 0)
  let moved_set = hot_root_get(fixture.hot_func, 1)
  let used_set = hot_root_get(fixture.hot_func, 2)
  let if_id = hot_root_get(fixture.hot_func, 3)
  let next_get = hot_root_get(fixture.hot_func, 4)

  hot_region_replace_body(fixture.hot_func, HotRegionRef::root(), [
    prefix_block, used_set, if_id, moved_set, next_get,
  ])

  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates earlier explicit-exit local.set if carrier before later if sink" {
  let source =
    #|(module
    #|  (func $side (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    (local.set 2
    #|      (if (result i32)
    #|        (local.get 0)
    #|        (then
    #|          (local.set 5 (local.get 1))
    #|          (i32.const 7))
    #|        (else
    #|          (local.set 5 (local.get 1))
    #|          (call $side (local.get 1))
    #|          (return (i32.const 9)))))
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 1)
    #|    (local.set 4)
    #|    (local.get 4)
    #|    (if
    #|      (then
    #|        (call $side (local.get 4))))
    #|    (local.get 3))
    #|)
  let fixture = ir_test_build_hot_from_wat(source, code_idx=1)
  assert_eq(hot_root_count(fixture.hot_func), 5)
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 0)).op.to_string(),
    "LocalSet",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 1)).op.to_string(),
    "LocalSet",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 2)).op.to_string(),
    "LocalSet",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 3)).op.to_string(),
    "If",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 4)).op.to_string(),
    "LocalGet",
  )
  let carrier_set = hot_root_get(fixture.hot_func, 0)
  let moved_set = hot_root_get(fixture.hot_func, 1)
  let used_set = hot_root_get(fixture.hot_func, 2)
  let if_id = hot_root_get(fixture.hot_func, 3)
  let next_get = hot_root_get(fixture.hot_func, 4)

  hot_region_replace_body(fixture.hot_func, HotRegionRef::root(), [
    carrier_set, used_set, if_id, moved_set, next_get,
  ])

  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates earlier explicit-exit local.set carrying a nested self-owner if block before later if sink" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    (local.set 2
    #|      (block $carry (result i32)
    #|        (block $mid
    #|          (br $carry
    #|            (if (result i32)
    #|              (local.get 0)
    #|              (then
    #|                (block $inner (result i32)
    #|                  (local.set 4 (local.get 1))
    #|                  (br $inner (local.get 4))))
    #|              (else
    #|                (local.set 4 (i32.const 5))
    #|                (local.get 4)))))
    #|        (local.get 1)))
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 1)
    #|    (local.set 5)
    #|    (local.get 5)
    #|    (if
    #|      (then
    #|        (drop (local.get 5))))
    #|    (local.get 3))
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  assert_eq(hot_root_count(fixture.hot_func), 5)
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 0)).op.to_string(),
    "LocalSet",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 1)).op.to_string(),
    "LocalSet",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 2)).op.to_string(),
    "LocalSet",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 3)).op.to_string(),
    "If",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 4)).op.to_string(),
    "LocalGet",
  )
  let carrier_set = hot_root_get(fixture.hot_func, 0)
  let moved_set = hot_root_get(fixture.hot_func, 1)
  let used_set = hot_root_get(fixture.hot_func, 2)
  let if_id = hot_root_get(fixture.hot_func, 3)
  let next_get = hot_root_get(fixture.hot_func, 4)

  hot_region_replace_body(fixture.hot_func, HotRegionRef::root(), [
    carrier_set, used_set, if_id, moved_set, next_get,
  ])

  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates direct payload branch back to inner block before later if sink" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    (local.set 2
    #|      (block $outer (result i32)
    #|        (block $mid
    #|          (br $outer
    #|            (if (result i32) (local.get 0)
    #|              (then
    #|                (local.set 3 (local.get 1))
    #|                (local.get 3))
    #|              (else
    #|                (local.set 4 (local.get 1))
    #|                (br $mid)))))
    #|        (local.get 4)))
    #|    (local.get 1)
    #|    (local.set 5)
    #|    (local.get 1)
    #|    (if
    #|      (then
    #|        (drop (local.get 1))))
    #|    (local.get 5))
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  assert_eq(hot_root_count(fixture.hot_func), 4)
  let carrier_set = hot_root_get(fixture.hot_func, 0)
  let moved_set = hot_root_get(fixture.hot_func, 1)
  let if_id = hot_root_get(fixture.hot_func, 2)
  let next_get = hot_root_get(fixture.hot_func, 3)
  hot_region_replace_body(fixture.hot_func, HotRegionRef::root(), [
    carrier_set, if_id, moved_set, next_get,
  ])
  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates direct payload branch back to inner block with unrelated trailing local.get before later if sink" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32)
    #|    (local.set 2
    #|      (block $outer (result i32)
    #|        (block $mid
    #|          (br $outer
    #|            (if (result i32) (local.get 0)
    #|              (then
    #|                (local.set 3 (local.get 1))
    #|                (i32.const 7))
    #|              (else
    #|                (local.set 3 (i32.const 5))
    #|                (br $mid)))))
    #|        (local.get 1)))
    #|    (local.get 1)
    #|    (local.set 4)
    #|    (local.get 1)
    #|    (if
    #|      (then
    #|        (drop (local.get 1))))
    #|    (local.get 4))
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  assert_eq(hot_root_count(fixture.hot_func), 4)
  let carrier_set = hot_root_get(fixture.hot_func, 0)
  let moved_set = hot_root_get(fixture.hot_func, 1)
  let if_id = hot_root_get(fixture.hot_func, 2)
  let next_get = hot_root_get(fixture.hot_func, 3)
  hot_region_replace_body(fixture.hot_func, HotRegionRef::root(), [
    carrier_set, if_id, moved_set, next_get,
  ])
  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates direct payload inner-block exit plus terminal exit before later if sink" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32)
    #|    (local.set 2
    #|      (block $outer (result i32)
    #|        (block $mid
    #|          (br $outer
    #|            (if (result i32) (local.get 0)
    #|              (then
    #|                (return (i32.const 7)))
    #|              (else
    #|                (local.set 3 (i32.const 5))
    #|                (br $mid)))))
    #|        (local.get 1)))
    #|    (local.get 1)
    #|    (local.set 4)
    #|    (local.get 1)
    #|    (if
    #|      (then
    #|        (drop (local.get 1))))
    #|    (local.get 4))
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  assert_eq(hot_root_count(fixture.hot_func), 4)
  let carrier_set = hot_root_get(fixture.hot_func, 0)
  let moved_set = hot_root_get(fixture.hot_func, 1)
  let if_id = hot_root_get(fixture.hot_func, 2)
  let next_get = hot_root_get(fixture.hot_func, 3)
  hot_region_replace_body(fixture.hot_func, HotRegionRef::root(), [
    carrier_set, if_id, moved_set, next_get,
  ])
  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates earlier explicit-exit if root before later if sink" {
  let source =
    #|(module
    #|  (func $side (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32)
    #|    (if
    #|      (local.get 0)
    #|      (then
    #|        (local.set 4 (local.get 1))
    #|        (return (i32.const 9))))
    #|    (local.get 1)
    #|    (local.set 2)
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 3)
    #|    (if
    #|      (then
    #|        (call $side (local.get 3))))
    #|    (local.get 2))
    #|)
  let fixture = ir_test_build_hot_from_wat(source, code_idx=1)
  assert_eq(hot_root_count(fixture.hot_func), 5)
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 0)).op.to_string(),
    "If",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 1)).op.to_string(),
    "LocalSet",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 2)).op.to_string(),
    "LocalSet",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 3)).op.to_string(),
    "If",
  )
  assert_eq(
    hot_node_get(fixture.hot_func, hot_root_get(fixture.hot_func, 4)).op.to_string(),
    "LocalGet",
  )
  let earlier_if = hot_root_get(fixture.hot_func, 0)
  let moved_set = hot_root_get(fixture.hot_func, 1)
  let used_set = hot_root_get(fixture.hot_func, 2)
  let if_id = hot_root_get(fixture.hot_func, 3)
  let next_get = hot_root_get(fixture.hot_func, 4)

  hot_region_replace_body(fixture.hot_func, HotRegionRef::root(), [
    earlier_if, used_set, if_id, moved_set, next_get,
  ])

  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates earlier zero-result branch root inside a parent-escape carrier" {
  let source =
    #|(module
    #|  (func $side (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    (block $outer (result i32)
    #|      (block $err
    #|        (block $carrier (result i32)
    #|          (block $work
    #|            (local.get 0)
    #|            (if (result i32)
    #|              (then
    #|                (local.set 2 (local.get 1))
    #|                (local.set 3 (local.get 1))
    #|                (br $work))
    #|              (else
    #|                (local.set 5 (i32.const 9))
    #|                (br $err)))
    #|            unreachable)
    #|          (block $skip
    #|            (br_if $skip (local.get 0)))
    #|          (local.set 4 (local.get 2))
    #|          (if
    #|            (local.get 2)
    #|            (then
    #|              (call $side (local.get 2))))
    #|          (drop (i32.const 0))
    #|          (local.get 3))
    #|        br $outer)
    #|      (local.get 5))))
    #|)
  let fixture = ir_test_build_hot_from_wat(source, code_idx=1)
  let mut carrier_body : HotRegionRef? = None
  for node_id = 0
      node_id < hot_node_count(fixture.hot_func)
      node_id = node_id + 1 {
    if !hot_node_is_live(fixture.hot_func, node_id) {
      continue
    }
    match hot_node_get(fixture.hot_func, node_id).op {
      Block => {
        let region = hot_region_body_ref(fixture.hot_func, node_id)
        let tags : Array[String] = []
        for idx = 0
            idx < hot_region_root_count(fixture.hot_func, region)
            idx = idx + 1 {
          let root = hot_region_get(fixture.hot_func, region, idx)
          let op = hot_node_get(fixture.hot_func, root).op
          match op {
            LocalGet | LocalSet | LocalTee =>
              tags.push("\{op}(\{hot_node_get(fixture.hot_func, root).imm0})")
            _ => tags.push(op.to_string())
          }
        }
        if tags ==
          ["Block", "Block", "LocalSet(4)", "If", "Drop", "LocalGet(3)"] {
          carrier_body = Some(region)
          break
        }
      }
      _ => ()
    }
  }
  let carrier_body = match carrier_body {
    Some(region) => region
    None => fail("expected parent-escape carrier body")
  }
  let work = hot_region_get(fixture.hot_func, carrier_body, 0)
  let skip = hot_region_get(fixture.hot_func, carrier_body, 1)
  let moved_set = hot_region_get(fixture.hot_func, carrier_body, 2)
  let decref_if = hot_region_get(fixture.hot_func, carrier_body, 3)
  let drop_root = hot_region_get(fixture.hot_func, carrier_body, 4)
  let next_get = hot_region_get(fixture.hot_func, carrier_body, 5)

  hot_region_replace_body(fixture.hot_func, carrier_body, [
    work, skip, decref_if, moved_set, drop_root, next_get,
  ])

  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
priv struct HotLowerParentEscapeCrossedGapFixture {
  fixture : IrTestHotFixture
  carrier_body : HotRegionRef
  err_block : Int
}

///|
fn hot_lower_live_parent_escape_crossed_gap_fixture() -> HotLowerParentEscapeCrossedGapFixture {
  let source =
    #|(module
    #|  (func $side (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32)
    #|    (block $outer (result i32)
    #|      (block $err
    #|        (block $carrier (result i32)
    #|          (block $work
    #|            (local.get 0)
    #|            (if (result i32)
    #|              (then
    #|                (local.set 2 (local.get 1))
    #|                (local.set 3 (local.get 1))
    #|                (br $work))
    #|              (else
    #|                (local.set 6 (i32.const 9))
    #|                (br $err)))
    #|            unreachable)
    #|          (block $skip
    #|            (br_if $skip (local.get 0)))
    #|          (local.set 4 (local.get 2))
    #|          (local.set 5 (local.get 3))
    #|          (if
    #|            (local.get 4)
    #|            (then
    #|              (call $side (local.get 4))))
    #|          (drop (i32.const 0))
    #|          (local.get 5))
    #|        br $outer)
    #|      (local.get 6))))
    #|)
  let fixture = ir_test_build_hot_from_wat(source, code_idx=1)
  let mut carrier_body : HotRegionRef? = None
  let mut err_block = -1
  for node_id = 0
      node_id < hot_node_count(fixture.hot_func)
      node_id = node_id + 1 {
    if !hot_node_is_live(fixture.hot_func, node_id) {
      continue
    }
    match hot_node_get(fixture.hot_func, node_id).op {
      Block => {
        let region = hot_region_body_ref(fixture.hot_func, node_id)
        if hot_region_root_count(fixture.hot_func, region) == 1 {
          let root0 = hot_region_get(fixture.hot_func, region, 0)
          match hot_node_get(fixture.hot_func, root0).op {
            Br =>
              if hot_child_count(fixture.hot_func, root0) >= 1 {
                let payload = hot_child_get(fixture.hot_func, root0, 0)
                match hot_node_get(fixture.hot_func, payload).op {
                  Block => err_block = node_id
                  _ => ()
                }
              }
            _ => ()
          }
          continue
        }
        let tags : Array[String] = []
        for idx = 0
            idx < hot_region_root_count(fixture.hot_func, region)
            idx = idx + 1 {
          let root = hot_region_get(fixture.hot_func, region, idx)
          let op = hot_node_get(fixture.hot_func, root).op
          match op {
            LocalGet | LocalSet | LocalTee =>
              tags.push("\{op}(\{hot_node_get(fixture.hot_func, root).imm0})")
            _ => tags.push(op.to_string())
          }
        }
        if tags ==
          [
            "Block", "Block", "LocalSet(4)", "LocalSet(5)", "If", "Drop", "LocalGet(5)",
          ] {
          carrier_body = Some(region)
        }
      }
      _ => ()
    }
  }
  {
    fixture,
    carrier_body: match carrier_body {
      Some(region) => region
      None => abort("expected parent-escape crossed-gap carrier body")
    },
    err_block,
  }
}

///|
fn hot_lower_live_apply_parent_escape_crossed_gap_reorder(
  real : HotLowerParentEscapeCrossedGapFixture,
) -> Unit {
  let work = hot_region_get(real.fixture.hot_func, real.carrier_body, 0)
  let skip = hot_region_get(real.fixture.hot_func, real.carrier_body, 1)
  let used_set = hot_region_get(real.fixture.hot_func, real.carrier_body, 2)
  let moved_set = hot_region_get(real.fixture.hot_func, real.carrier_body, 3)
  let if_id = hot_region_get(real.fixture.hot_func, real.carrier_body, 4)
  let drop_root = hot_region_get(real.fixture.hot_func, real.carrier_body, 5)
  let next_get = hot_region_get(real.fixture.hot_func, real.carrier_body, 6)

  hot_region_replace_body(real.fixture.hot_func, real.carrier_body, [
    work, skip, used_set, if_id, moved_set, drop_root, next_get,
  ])
}

///|
test "hot lower live repro validates a parent-escape carrier with a branch-free crossed gap" {
  let real = hot_lower_live_parent_escape_crossed_gap_fixture()
  hot_lower_live_apply_parent_escape_crossed_gap_reorder(real)

  let lowered = hot_lower_func(real.fixture.hot_func)
  let next_code_sec = match real.fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[real.fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = real.fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot verify rejects a parent-escape carrier with a branch-free crossed gap when parent err block becomes result-producing" {
  let real = hot_lower_live_parent_escape_crossed_gap_fixture()
  hot_lower_live_apply_parent_escape_crossed_gap_reorder(real)
  hot_control_result_type_set(
    real.fixture.hot_func,
    real.err_block,
    hot_type_intern_value(real.fixture.hot_func, @lib.ValType::i32()),
  )

  match hot_verify_all(real.fixture.hot_func, cache=Some(())) {
    Err(InvalidBranchArity(_, _, 0, 1)) => ()
    Err(err) => fail(err.to_string())
    Ok(_) =>
      fail(
        "expected parent err block result rewrite to invalidate parent-escape crossed-gap carrier too",
      )
  }
}

///|
test "hot lower live repro validates extracted parent-escape carrier with earlier zero-result branch root" {
  let source =
    #|(module
    #|  (func $side (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    (block $outer (result i32)
    #|      (block $err
    #|        (block $carrier (result i32)
    #|          (block $work
    #|            (local.get 0)
    #|            (if (result i32)
    #|              (then
    #|                (local.set 2 (local.get 1))
    #|                (local.set 3 (local.get 1))
    #|                (br $work))
    #|              (else
    #|                (local.set 5 (i32.const 9))
    #|                (br $err)))
    #|            unreachable)
    #|          (block $skip
    #|            (br_if $skip (local.get 0)))
    #|          (local.set 4 (local.get 2))
    #|          (if
    #|            (local.get 2)
    #|            (then
    #|              (call $side (local.get 2))))
    #|          (drop (i32.const 0))
    #|          (local.get 3))
    #|        br $outer)
    #|      (local.get 5))))
    #|)
  let fixture = ir_test_build_hot_from_wat(source, code_idx=1)
  let mut carrier_body : HotRegionRef? = None
  let mut err_body : HotRegionRef? = None
  let mut err_branch = -1
  let mut err_carrier_block = -1
  for node_id = 0
      node_id < hot_node_count(fixture.hot_func)
      node_id = node_id + 1 {
    if !hot_node_is_live(fixture.hot_func, node_id) {
      continue
    }
    match hot_node_get(fixture.hot_func, node_id).op {
      Block => {
        let region = hot_region_body_ref(fixture.hot_func, node_id)
        let tags : Array[String] = []
        for idx = 0
            idx < hot_region_root_count(fixture.hot_func, region)
            idx = idx + 1 {
          let root = hot_region_get(fixture.hot_func, region, idx)
          let op = hot_node_get(fixture.hot_func, root).op
          match op {
            LocalGet | LocalSet | LocalTee =>
              tags.push("\{op}(\{hot_node_get(fixture.hot_func, root).imm0})")
            _ => tags.push(op.to_string())
          }
        }
        if tags ==
          ["Block", "Block", "LocalSet(4)", "If", "Drop", "LocalGet(3)"] {
          carrier_body = Some(region)
        }
        if tags == ["Br"] {
          let branch = hot_region_get(fixture.hot_func, region, 0)
          if hot_child_count(fixture.hot_func, branch) >= 1 {
            let payload = hot_child_get(fixture.hot_func, branch, 0)
            match hot_node_get(fixture.hot_func, payload).op {
              Block => {
                err_body = Some(region)
                err_branch = branch
                err_carrier_block = payload
              }
              _ => ()
            }
          }
        }
      }
      _ => ()
    }
  }
  let carrier_body = match carrier_body {
    Some(region) => region
    None => fail("expected parent-escape carrier body")
  }
  let err_body = match err_body {
    Some(region) => region
    None => fail("expected parent err body")
  }
  if err_branch < 0 || err_carrier_block < 0 {
    fail("expected parent err branch carrying block payload")
  }

  let work = hot_region_get(fixture.hot_func, carrier_body, 0)
  let skip = hot_region_get(fixture.hot_func, carrier_body, 1)
  let moved_set = hot_region_get(fixture.hot_func, carrier_body, 2)
  let decref_if = hot_region_get(fixture.hot_func, carrier_body, 3)
  let drop_root = hot_region_get(fixture.hot_func, carrier_body, 4)
  let next_get = hot_region_get(fixture.hot_func, carrier_body, 5)
  let carrier_payload = hot_child_get(fixture.hot_func, moved_set, 0)

  hot_region_replace_body(fixture.hot_func, carrier_body, [
    work, skip, carrier_payload,
  ])
  hot_region_insert(fixture.hot_func, err_body, 0, [
    err_carrier_block, moved_set, decref_if, drop_root,
  ])
  hot_child_set(fixture.hot_func, err_branch, 0, next_get)

  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates extracted parent-escape carrier with a branch-free crossed gap" {
  let source =
    #|(module
    #|  (func $side (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32)
    #|    (block $outer (result i32)
    #|      (block $err
    #|        (block $carrier (result i32)
    #|          (block $work
    #|            (local.get 0)
    #|            (if (result i32)
    #|              (then
    #|                (local.set 2 (local.get 1))
    #|                (local.set 3 (local.get 1))
    #|                (br $work))
    #|              (else
    #|                (local.set 6 (i32.const 9))
    #|                (br $err)))
    #|            unreachable)
    #|          (block $skip
    #|            (br_if $skip (local.get 0)))
    #|          (local.set 4 (local.get 2))
    #|          (local.set 5 (local.get 3))
    #|          (if
    #|            (local.get 4)
    #|            (then
    #|              (call $side (local.get 4))))
    #|          (drop (i32.const 0))
    #|          (local.get 5))
    #|        br $outer)
    #|      (local.get 6))))
    #|)
  let fixture = ir_test_build_hot_from_wat(source, code_idx=1)
  let mut carrier_body : HotRegionRef? = None
  let mut err_body : HotRegionRef? = None
  let mut err_branch = -1
  let mut err_carrier_block = -1
  for node_id = 0
      node_id < hot_node_count(fixture.hot_func)
      node_id = node_id + 1 {
    if !hot_node_is_live(fixture.hot_func, node_id) {
      continue
    }
    match hot_node_get(fixture.hot_func, node_id).op {
      Block => {
        let region = hot_region_body_ref(fixture.hot_func, node_id)
        let tags : Array[String] = []
        for idx = 0
            idx < hot_region_root_count(fixture.hot_func, region)
            idx = idx + 1 {
          let root = hot_region_get(fixture.hot_func, region, idx)
          let op = hot_node_get(fixture.hot_func, root).op
          match op {
            LocalGet | LocalSet | LocalTee =>
              tags.push("\{op}(\{hot_node_get(fixture.hot_func, root).imm0})")
            _ => tags.push(op.to_string())
          }
        }
        if tags ==
          [
            "Block", "Block", "LocalSet(4)", "LocalSet(5)", "If", "Drop", "LocalGet(5)",
          ] {
          carrier_body = Some(region)
        }
        if tags == ["Br"] {
          let branch = hot_region_get(fixture.hot_func, region, 0)
          if hot_child_count(fixture.hot_func, branch) >= 1 {
            let payload = hot_child_get(fixture.hot_func, branch, 0)
            match hot_node_get(fixture.hot_func, payload).op {
              Block => {
                err_body = Some(region)
                err_branch = branch
                err_carrier_block = payload
              }
              _ => ()
            }
          }
        }
      }
      _ => ()
    }
  }
  let carrier_body = match carrier_body {
    Some(region) => region
    None => fail("expected extracted parent-escape crossed-gap carrier body")
  }
  let err_body = match err_body {
    Some(region) => region
    None => fail("expected extracted parent-escape crossed-gap err body")
  }
  let work = hot_region_get(fixture.hot_func, carrier_body, 0)
  let skip = hot_region_get(fixture.hot_func, carrier_body, 1)
  let used_set = hot_region_get(fixture.hot_func, carrier_body, 2)
  let moved_set = hot_region_get(fixture.hot_func, carrier_body, 3)
  let if_id = hot_region_get(fixture.hot_func, carrier_body, 4)
  let drop_root = hot_region_get(fixture.hot_func, carrier_body, 5)
  let next_get = hot_region_get(fixture.hot_func, carrier_body, 6)
  let carrier_payload = hot_child_get(fixture.hot_func, moved_set, 0)

  hot_region_replace_body(fixture.hot_func, carrier_body, [
    work, skip, used_set, carrier_payload,
  ])
  hot_region_insert(fixture.hot_func, err_body, 0, [
    err_carrier_block, moved_set, if_id, drop_root,
  ])
  hot_child_set(fixture.hot_func, err_branch, 0, next_get)

  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates reordered real carrier with earlier zero-result branch root" {
  let real = hot_lower_live_real_carrier_with_skip_fixture()
  let work = hot_region_get(real.fixture.hot_func, real.carrier_body, 0)
  let skip = hot_region_get(real.fixture.hot_func, real.carrier_body, 1)
  let moved_set = hot_region_get(real.fixture.hot_func, real.carrier_body, 2)
  let decref_if = hot_region_get(real.fixture.hot_func, real.carrier_body, 3)
  let store = hot_region_get(real.fixture.hot_func, real.carrier_body, 4)
  let drop_root = hot_region_get(real.fixture.hot_func, real.carrier_body, 5)
  let next_get = hot_region_get(real.fixture.hot_func, real.carrier_body, 6)

  hot_region_replace_body(real.fixture.hot_func, real.carrier_body, [
    work, skip, decref_if, moved_set, store, drop_root, next_get,
  ])

  let lowered = hot_lower_func(real.fixture.hot_func)
  let next_code_sec = match real.fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[real.fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = real.fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
priv struct HotLowerRealCrossedGapFixture {
  fixture : IrTestHotFixture
  carrier_body : HotRegionRef
  err_block : Int
  err_body : HotRegionRef
  err_branch : Int
  err_carrier_block : Int
}

///|
fn hot_lower_live_real_crossed_gap_fixture() -> HotLowerRealCrossedGapFixture {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $incref (param i32))
    #|  (func $decref (param i32))
    #|  (func $decode (param i32 i32) (result i32)
    #|    local.get 0)
    #|  (func $get_tag (param i32) (result i32)
    #|    i32.const 1)
    #|  (func (param i32 i32 i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    (block $outer (result i32)
    #|      (block $err
    #|        (block $carrier (result i32)
    #|          (block $work
    #|            (local.get 1)
    #|            (i32.load offset=8 align=1)
    #|            (local.tee 4)
    #|            (i32.const 1)
    #|            i32.add
    #|            (local.set 5)
    #|            (local.get 0)
    #|            (call $incref)
    #|            (local.get 0)
    #|            (local.get 5)
    #|            (call $decode)
    #|            (local.tee 6)
    #|            (call $get_tag)
    #|            (i32.const 1)
    #|            i32.eq
    #|            (if (result i32)
    #|              (then
    #|                (local.get 6)
    #|                (i32.load offset=12 align=1)
    #|                (local.set 7)
    #|                (local.get 6)
    #|                (i32.load offset=8 align=1)
    #|                (local.set 8)
    #|                (local.get 7)
    #|                (local.get 8)
    #|                (local.set 3)
    #|                (local.set 2)
    #|                (br $work))
    #|              (else
    #|                (local.get 0)
    #|                (call $decref)
    #|                (local.get 2)
    #|                (call $decref)
    #|                (local.get 3)
    #|                (call $decref)
    #|                (local.get 1)
    #|                (call $decref)
    #|                (local.get 6)
    #|                (i32.load offset=8 align=1)
    #|                (local.set 9)
    #|                (br $err)))
    #|            unreachable)
    #|          (block $skip
    #|            (br_if $skip (local.get 0)))
    #|          (local.get 2)
    #|          (local.set 10)
    #|          (local.get 2)
    #|          (local.set 5)
    #|          (local.get 10)
    #|          (if
    #|            (then
    #|              (local.get 10)
    #|              (call $decref)))
    #|          (local.get 1)
    #|          (local.get 5)
    #|          (i32.store offset=8 align=1)
    #|          (i32.const 0)
    #|          drop
    #|          (local.get 3))
    #|        br $outer)
    #|      (local.get 9))))
    #|)
  let fixture = ir_test_build_hot_from_wat(source, code_idx=4)
  let mut carrier_body : HotRegionRef? = None
  let mut err_block = -1
  let mut err_body : HotRegionRef? = None
  let mut err_branch = -1
  let mut err_carrier_block = -1
  for node_id = 0
      node_id < hot_node_count(fixture.hot_func)
      node_id = node_id + 1 {
    if !hot_node_is_live(fixture.hot_func, node_id) {
      continue
    }
    match hot_node_get(fixture.hot_func, node_id).op {
      Block => {
        let region = hot_region_body_ref(fixture.hot_func, node_id)
        if hot_region_root_count(fixture.hot_func, region) == 1 {
          let root0 = hot_region_get(fixture.hot_func, region, 0)
          match hot_node_get(fixture.hot_func, root0).op {
            Br =>
              if hot_child_count(fixture.hot_func, root0) >= 1 {
                let payload = hot_child_get(fixture.hot_func, root0, 0)
                match hot_node_get(fixture.hot_func, payload).op {
                  Block => {
                    err_block = node_id
                    err_body = Some(region)
                    err_branch = root0
                    err_carrier_block = payload
                  }
                  _ => ()
                }
              }
            _ => ()
          }
          continue
        }
        let tags : Array[String] = []
        for idx = 0
            idx < hot_region_root_count(fixture.hot_func, region)
            idx = idx + 1 {
          let root = hot_region_get(fixture.hot_func, region, idx)
          let op = hot_node_get(fixture.hot_func, root).op
          match op {
            LocalGet | LocalSet | LocalTee =>
              tags.push("\{op}(\{hot_node_get(fixture.hot_func, root).imm0})")
            _ => tags.push(op.to_string())
          }
        }
        if tags ==
          [
            "Block", "Block", "LocalSet(10)", "LocalSet(5)", "If", "Store", "Drop",
            "LocalGet(3)",
          ] {
          carrier_body = Some(region)
        }
      }
      _ => ()
    }
  }
  {
    fixture,
    carrier_body: match carrier_body {
      Some(region) => region
      None => abort("expected real crossed-gap carrier body")
    },
    err_block,
    err_body: match err_body {
      Some(region) => region
      None => abort("expected real crossed-gap err body")
    },
    err_branch,
    err_carrier_block,
  }
}

///|
fn hot_lower_live_apply_reordered_real_crossed_gap(
  real : HotLowerRealCrossedGapFixture,
) -> Unit {
  let work = hot_region_get(real.fixture.hot_func, real.carrier_body, 0)
  let skip = hot_region_get(real.fixture.hot_func, real.carrier_body, 1)
  let used_set = hot_region_get(real.fixture.hot_func, real.carrier_body, 2)
  let moved_set = hot_region_get(real.fixture.hot_func, real.carrier_body, 3)
  let decref_if = hot_region_get(real.fixture.hot_func, real.carrier_body, 4)
  let store = hot_region_get(real.fixture.hot_func, real.carrier_body, 5)
  let drop_root = hot_region_get(real.fixture.hot_func, real.carrier_body, 6)
  let next_get = hot_region_get(real.fixture.hot_func, real.carrier_body, 7)

  hot_region_replace_body(real.fixture.hot_func, real.carrier_body, [
    work, skip, used_set, decref_if, moved_set, store, drop_root, next_get,
  ])
}

///|
fn hot_lower_live_apply_parent_err_extraction_for_crossed_gap(
  real : HotLowerRealCrossedGapFixture,
) -> Unit {
  if real.err_branch < 0 || real.err_carrier_block < 0 {
    abort("expected parent err branch carrying block payload")
  }
  let work = hot_region_get(real.fixture.hot_func, real.carrier_body, 0)
  let skip = hot_region_get(real.fixture.hot_func, real.carrier_body, 1)
  let used_set = hot_region_get(real.fixture.hot_func, real.carrier_body, 2)
  let moved_set = hot_region_get(real.fixture.hot_func, real.carrier_body, 3)
  let decref_if = hot_region_get(real.fixture.hot_func, real.carrier_body, 4)
  let store = hot_region_get(real.fixture.hot_func, real.carrier_body, 5)
  let drop_root = hot_region_get(real.fixture.hot_func, real.carrier_body, 6)
  let next_get = hot_region_get(real.fixture.hot_func, real.carrier_body, 7)
  let carrier_payload = hot_child_get(real.fixture.hot_func, moved_set, 0)

  hot_region_replace_body(real.fixture.hot_func, real.carrier_body, [
    work, skip, used_set, carrier_payload,
  ])
  hot_region_insert(real.fixture.hot_func, real.err_body, 0, [
    real.err_carrier_block,
    moved_set,
    decref_if,
    store,
    drop_root,
  ])
  hot_child_set(real.fixture.hot_func, real.err_branch, 0, next_get)
}

///|
test "hot lower live repro validates reordered real carrier with a branch-free crossed gap" {
  let real = hot_lower_live_real_crossed_gap_fixture()
  hot_lower_live_apply_reordered_real_crossed_gap(real)

  let lowered = hot_lower_func(real.fixture.hot_func)
  let next_code_sec = match real.fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[real.fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = real.fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot verify rejects reordered real carrier with a branch-free crossed gap when parent err block becomes result-producing" {
  let real = hot_lower_live_real_crossed_gap_fixture()
  hot_lower_live_apply_reordered_real_crossed_gap(real)
  hot_control_result_type_set(
    real.fixture.hot_func,
    real.err_block,
    hot_type_intern_value(real.fixture.hot_func, @lib.ValType::i32()),
  )

  match hot_verify_all(real.fixture.hot_func, cache=Some(())) {
    Err(InvalidBranchArity(_, _, 0, 1)) => ()
    Err(err) => fail(err.to_string())
    Ok(_) =>
      fail(
        "expected parent err block result rewrite to invalidate reordered real crossed-gap carrier too",
      )
  }
}

///|
test "hot verify rejects retargeting a carrier arm branch past its result payload" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32) (local i32)
    #|    (block $outer
    #|      (block $carry (result i32)
    #|        (block $work
    #|          (if (local.get 0)
    #|            (then
    #|              (local.set 2 (i32.const 7))
    #|              (br $work))
    #|            (else
    #|              (local.set 2 (i32.const 9))
    #|              (br $work)))
    #|          unreachable)
    #|        (local.get 1))
    #|      drop)
    #|    i32.const 0))
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  let mut carry = -1
  let mut work = -1
  for node_id = 0
      node_id < hot_node_count(fixture.hot_func)
      node_id = node_id + 1 {
    if !hot_node_is_live(fixture.hot_func, node_id) {
      continue
    }
    match hot_node_get(fixture.hot_func, node_id).op {
      Block => {
        let body = hot_region_body_ref(fixture.hot_func, node_id)
        if hot_node_result_arity(fixture.hot_func, node_id) == 1 &&
          hot_region_root_count(fixture.hot_func, body) == 2 {
          let root0 = hot_region_get(fixture.hot_func, body, 0)
          let root1 = hot_region_get(fixture.hot_func, body, 1)
          match hot_node_get(fixture.hot_func, root0).op {
            Block =>
              match hot_node_get(fixture.hot_func, root1).op {
                LocalGet if hot_node_get(fixture.hot_func, root1).imm0 == 1 =>
                  carry = node_id
                _ => ()
              }
            _ => ()
          }
        }
        if hot_region_root_count(fixture.hot_func, body) == 2 {
          let root0 = hot_region_get(fixture.hot_func, body, 0)
          let root1 = hot_region_get(fixture.hot_func, body, 1)
          match hot_node_get(fixture.hot_func, root0).op {
            If =>
              match hot_node_get(fixture.hot_func, root1).op {
                Unreachable => work = node_id
                _ => ()
              }
            _ => ()
          }
        }
      }
      _ => ()
    }
  }
  if carry < 0 || work < 0 {
    fail("expected carrier and work blocks")
  }
  let carry_label = hot_control_node_label(fixture.hot_func, carry)
  let work_body = hot_region_body_ref(fixture.hot_func, work)
  let if_id = hot_region_get(fixture.hot_func, work_body, 0)
  let else_ref = match hot_region_else_ref(fixture.hot_func, if_id) {
    Some(region) => region
    None => fail("expected carrier if else region")
  }
  let else_set = hot_region_get(fixture.hot_func, else_ref, 0)
  let retargeted = hot_build_br(fixture.hot_func, carry_label)

  hot_region_replace_body(fixture.hot_func, else_ref, [else_set, retargeted])

  match hot_verify_all(fixture.hot_func, cache=Some(())) {
    Err(InvalidBranchArity(_, _, 0, 1)) => ()
    Err(err) => fail(err.to_string())
    Ok(_) =>
      fail(
        "expected retargeted carrier branch to invalidate outer result payload arity",
      )
  }
}

///|
test "hot verify rejects making a parent exit carrier block result-producing" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (block $outer (result i32) (block $exit (block $work (if (i32.eq (local.get 0) (i32.const 1)) (then (local.set 2 (local.get 1)) (br $work)) (else (local.set 2 (i32.const 9)) (br $exit))) unreachable) (br $outer (local.get 2))) (i32.const 0))))",
  )
  let outer = hot_root_get(fixture.hot_func, 0)
  let outer_body = hot_region_body_ref(fixture.hot_func, outer)
  let exit_block = hot_region_get(fixture.hot_func, outer_body, 0)

  hot_control_result_type_set(
    fixture.hot_func,
    exit_block,
    hot_type_intern_value(fixture.hot_func, @lib.ValType::i32()),
  )

  match hot_verify_all(fixture.hot_func, cache=Some(())) {
    Err(InvalidBranchArity(_, _, 0, 1)) => ()
    Err(err) => fail(err.to_string())
    Ok(_) =>
      fail(
        "expected parent exit result rewrite to invalidate branch payload arity",
      )
  }
}

///|
priv struct HotLowerRealCarrierFixture {
  fixture : IrTestHotFixture
  carrier_body : HotRegionRef
  err_block : Int
  err_body : HotRegionRef
  err_branch : Int
  err_carrier_block : Int
  carried_if : Int
}

///|
fn hot_lower_live_real_carrier_with_skip_fixture() -> HotLowerRealCarrierFixture {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $incref (param i32))
    #|  (func $decref (param i32))
    #|  (func $decode (param i32 i32) (result i32)
    #|    local.get 0)
    #|  (func $get_tag (param i32) (result i32)
    #|    i32.const 1)
    #|  (func (param i32 i32 i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    (block $outer (result i32)
    #|      (block $err
    #|        (block $carrier (result i32)
    #|          (block $work
    #|            (local.get 1)
    #|            (i32.load offset=8 align=1)
    #|            (local.tee 4)
    #|            (i32.const 1)
    #|            i32.add
    #|            (local.set 5)
    #|            (local.get 0)
    #|            (call $incref)
    #|            (local.get 0)
    #|            (local.get 5)
    #|            (call $decode)
    #|            (local.tee 6)
    #|            (call $get_tag)
    #|            (i32.const 1)
    #|            i32.eq
    #|            (if (result i32)
    #|              (then
    #|                (local.get 6)
    #|                (i32.load offset=12 align=1)
    #|                (local.set 7)
    #|                (local.get 6)
    #|                (i32.load offset=8 align=1)
    #|                (local.set 8)
    #|                (local.get 7)
    #|                (local.get 8)
    #|                (local.set 3)
    #|                (local.set 2)
    #|                (br $work))
    #|              (else
    #|                (local.get 0)
    #|                (call $decref)
    #|                (local.get 2)
    #|                (call $decref)
    #|                (local.get 3)
    #|                (call $decref)
    #|                (local.get 1)
    #|                (call $decref)
    #|                (local.get 6)
    #|                (i32.load offset=8 align=1)
    #|                (local.set 9)
    #|                (br $err)))
    #|            unreachable)
    #|          (block $skip
    #|            (br_if $skip (local.get 0)))
    #|          (local.get 2)
    #|          (local.set 5)
    #|          (local.get 2)
    #|          (if
    #|            (then
    #|              (local.get 2)
    #|              (call $decref)))
    #|          (local.get 1)
    #|          (local.get 5)
    #|          (i32.store offset=8 align=1)
    #|          (i32.const 0)
    #|          drop
    #|          (local.get 3))
    #|        br $outer)
    #|      (local.get 9))))
    #|)
  let fixture = ir_test_build_hot_from_wat(source, code_idx=4)
  let mut carrier_body : HotRegionRef? = None
  let mut err_block = -1
  let mut err_body : HotRegionRef? = None
  let mut err_branch = -1
  let mut err_carrier_block = -1
  let mut carried_if = -1
  for node_id = 0
      node_id < hot_node_count(fixture.hot_func)
      node_id = node_id + 1 {
    if !hot_node_is_live(fixture.hot_func, node_id) {
      continue
    }
    match hot_node_get(fixture.hot_func, node_id).op {
      If =>
        if hot_node_result_arity(fixture.hot_func, node_id) == 1 {
          let then_ref = hot_region_then_ref(fixture.hot_func, node_id)
          if hot_region_root_count(fixture.hot_func, then_ref) >= 2 {
            let then0 = hot_region_get(fixture.hot_func, then_ref, 0)
            let then1 = hot_region_get(fixture.hot_func, then_ref, 1)
            match hot_node_get(fixture.hot_func, then0).op {
              LocalSet =>
                match hot_node_get(fixture.hot_func, then1).op {
                  LocalSet => carried_if = node_id
                  _ => ()
                }
              _ => ()
            }
          }
        }
      _ => ()
    }
    match hot_node_get(fixture.hot_func, node_id).op {
      Block => {
        let region = hot_region_body_ref(fixture.hot_func, node_id)
        if hot_region_root_count(fixture.hot_func, region) == 1 {
          let root0 = hot_region_get(fixture.hot_func, region, 0)
          match hot_node_get(fixture.hot_func, root0).op {
            Br =>
              if hot_child_count(fixture.hot_func, root0) >= 1 {
                let payload = hot_child_get(fixture.hot_func, root0, 0)
                match hot_node_get(fixture.hot_func, payload).op {
                  Block => {
                    err_block = node_id
                    err_body = Some(region)
                    err_branch = root0
                    err_carrier_block = payload
                  }
                  _ => ()
                }
              }
            _ => ()
          }
          continue
        }
        let tags : Array[String] = []
        for idx = 0
            idx < hot_region_root_count(fixture.hot_func, region)
            idx = idx + 1 {
          let root = hot_region_get(fixture.hot_func, region, idx)
          let op = hot_node_get(fixture.hot_func, root).op
          match op {
            LocalGet | LocalSet | LocalTee =>
              tags.push("\{op}(\{hot_node_get(fixture.hot_func, root).imm0})")
            _ => tags.push(op.to_string())
          }
        }
        if tags ==
          [
            "Block", "Block", "LocalSet(5)", "If", "Store", "Drop", "LocalGet(3)",
          ] {
          carrier_body = Some(region)
        }
      }
      _ => ()
    }
  }
  {
    fixture,
    carrier_body: match carrier_body {
      Some(region) => region
      None => abort("expected real carrier body with zero-result prefix root")
    },
    err_block,
    err_body: match err_body {
      Some(region) => region
      None => abort("expected parent err region")
    },
    err_branch,
    err_carrier_block,
    carried_if,
  }
}

///|
fn hot_lower_live_real_carrier_fixture() -> HotLowerRealCarrierFixture {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $incref (param i32))
    #|  (func $decref (param i32))
    #|  (func $decode (param i32 i32) (result i32)
    #|    local.get 0)
    #|  (func $get_tag (param i32) (result i32)
    #|    i32.const 1)
    #|  (func (param i32 i32 i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    (block $outer (result i32)
    #|      (block $err
    #|        (block $carrier (result i32)
    #|          (block $work
    #|            (local.get 1)
    #|            (i32.load offset=8 align=1)
    #|            (local.tee 4)
    #|            (i32.const 1)
    #|            i32.add
    #|            (local.set 5)
    #|            (local.get 0)
    #|            (call $incref)
    #|            (local.get 0)
    #|            (local.get 5)
    #|            (call $decode)
    #|            (local.tee 6)
    #|            (call $get_tag)
    #|            (i32.const 1)
    #|            i32.eq
    #|            (if (result i32)
    #|              (then
    #|                (local.get 6)
    #|                (i32.load offset=12 align=1)
    #|                (local.set 7)
    #|                (local.get 6)
    #|                (i32.load offset=8 align=1)
    #|                (local.set 8)
    #|                (local.get 7)
    #|                (local.get 8)
    #|                (local.set 3)
    #|                (local.set 2)
    #|                (br $work))
    #|              (else
    #|                (local.get 0)
    #|                (call $decref)
    #|                (local.get 2)
    #|                (call $decref)
    #|                (local.get 3)
    #|                (call $decref)
    #|                (local.get 1)
    #|                (call $decref)
    #|                (local.get 6)
    #|                (i32.load offset=8 align=1)
    #|                (local.set 9)
    #|                (br $err)))
    #|            unreachable)
    #|          (local.get 2)
    #|          (local.set 5)
    #|          (local.get 2)
    #|          (if
    #|            (then
    #|              (local.get 2)
    #|              (call $decref)))
    #|          (local.get 1)
    #|          (local.get 5)
    #|          (i32.store offset=8 align=1)
    #|          (i32.const 0)
    #|          drop
    #|          (local.get 3))
    #|        br $outer)
    #|      (local.get 9))))
    #|)
  let fixture = ir_test_build_hot_from_wat(source, code_idx=4)
  let mut carrier_body : HotRegionRef? = None
  let mut err_block = -1
  let mut err_body : HotRegionRef? = None
  let mut err_branch = -1
  let mut err_carrier_block = -1
  let mut carried_if = -1
  for node_id = 0
      node_id < hot_node_count(fixture.hot_func)
      node_id = node_id + 1 {
    if !hot_node_is_live(fixture.hot_func, node_id) {
      continue
    }
    match hot_node_get(fixture.hot_func, node_id).op {
      If =>
        if hot_node_result_arity(fixture.hot_func, node_id) == 1 {
          let then_ref = hot_region_then_ref(fixture.hot_func, node_id)
          if hot_region_root_count(fixture.hot_func, then_ref) >= 2 {
            let then0 = hot_region_get(fixture.hot_func, then_ref, 0)
            let then1 = hot_region_get(fixture.hot_func, then_ref, 1)
            match hot_node_get(fixture.hot_func, then0).op {
              LocalSet =>
                match hot_node_get(fixture.hot_func, then1).op {
                  LocalSet => carried_if = node_id
                  _ => ()
                }
              _ => ()
            }
          }
        }
      _ => ()
    }
    match hot_node_get(fixture.hot_func, node_id).op {
      Block => {
        let region = hot_region_body_ref(fixture.hot_func, node_id)
        if hot_region_root_count(fixture.hot_func, region) == 1 {
          let root0 = hot_region_get(fixture.hot_func, region, 0)
          match hot_node_get(fixture.hot_func, root0).op {
            Br =>
              if hot_child_count(fixture.hot_func, root0) >= 1 {
                let payload = hot_child_get(fixture.hot_func, root0, 0)
                match hot_node_get(fixture.hot_func, payload).op {
                  Block => {
                    err_block = node_id
                    err_body = Some(region)
                    err_branch = root0
                    err_carrier_block = payload
                  }
                  _ => ()
                }
              }
            _ => ()
          }
          continue
        }
        if hot_region_root_count(fixture.hot_func, region) < 3 {
          continue
        }
        let root0 = hot_region_get(fixture.hot_func, region, 0)
        let root1 = hot_region_get(fixture.hot_func, region, 1)
        let root2 = hot_region_get(fixture.hot_func, region, 2)
        match hot_node_get(fixture.hot_func, root0).op {
          Block =>
            match hot_node_get(fixture.hot_func, root1).op {
              LocalSet =>
                match hot_node_get(fixture.hot_func, root2).op {
                  If => carrier_body = Some(region)
                  _ => ()
                }
              _ => ()
            }
          _ => ()
        }
      }
      _ => ()
    }
  }
  {
    fixture,
    carrier_body: match carrier_body {
      Some(region) => region
      None => abort("expected real-carrier body region")
    },
    err_block,
    err_body: match err_body {
      Some(region) => region
      None => abort("expected parent err region")
    },
    err_branch,
    err_carrier_block,
    carried_if,
  }
}

///|
fn hot_lower_live_apply_parent_err_extraction(
  real : HotLowerRealCarrierFixture,
) -> Unit {
  if real.err_branch < 0 || real.err_carrier_block < 0 {
    abort("expected parent err branch carrying block payload")
  }
  if real.carried_if < 0 {
    abort("expected carried result if")
  }
  let work = hot_region_get(real.fixture.hot_func, real.carrier_body, 0)
  let moved_set = hot_region_get(real.fixture.hot_func, real.carrier_body, 1)
  let decref_if = hot_region_get(real.fixture.hot_func, real.carrier_body, 2)
  let store = hot_region_get(real.fixture.hot_func, real.carrier_body, 3)
  let drop_root = hot_region_get(real.fixture.hot_func, real.carrier_body, 4)
  let next_get = hot_region_get(real.fixture.hot_func, real.carrier_body, 5)
  let carrier_payload = hot_child_get(real.fixture.hot_func, moved_set, 0)

  hot_region_replace_body(real.fixture.hot_func, real.carrier_body, [
    work, carrier_payload,
  ])
  hot_region_insert(real.fixture.hot_func, real.err_body, 0, [
    real.err_carrier_block,
    moved_set,
    decref_if,
    store,
    drop_root,
  ])
  hot_child_set(real.fixture.hot_func, real.err_branch, 0, next_get)
}

///|
fn hot_lower_live_apply_parent_err_extraction_with_skip(
  real : HotLowerRealCarrierFixture,
) -> Unit {
  if real.err_branch < 0 || real.err_carrier_block < 0 {
    abort("expected parent err branch carrying block payload")
  }
  if real.carried_if < 0 {
    abort("expected carried result if")
  }
  let work = hot_region_get(real.fixture.hot_func, real.carrier_body, 0)
  let skip = hot_region_get(real.fixture.hot_func, real.carrier_body, 1)
  let moved_set = hot_region_get(real.fixture.hot_func, real.carrier_body, 2)
  let decref_if = hot_region_get(real.fixture.hot_func, real.carrier_body, 3)
  let store = hot_region_get(real.fixture.hot_func, real.carrier_body, 4)
  let drop_root = hot_region_get(real.fixture.hot_func, real.carrier_body, 5)
  let next_get = hot_region_get(real.fixture.hot_func, real.carrier_body, 6)
  let carrier_payload = hot_child_get(real.fixture.hot_func, moved_set, 0)

  hot_region_replace_body(real.fixture.hot_func, real.carrier_body, [
    work, skip, carrier_payload,
  ])
  hot_region_insert(real.fixture.hot_func, real.err_body, 0, [
    real.err_carrier_block,
    moved_set,
    decref_if,
    store,
    drop_root,
  ])
  hot_child_set(real.fixture.hot_func, real.err_branch, 0, next_get)
}

///|
test "hot lower live repro validates extracted real carrier with a branch-free crossed gap" {
  let real = hot_lower_live_real_crossed_gap_fixture()
  hot_lower_live_apply_parent_err_extraction_for_crossed_gap(real)

  let lowered = hot_lower_func(real.fixture.hot_func)
  let next_code_sec = match real.fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[real.fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = real.fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot verify rejects extracted real carrier with a branch-free crossed gap when parent err block becomes result-producing" {
  let real = hot_lower_live_real_crossed_gap_fixture()
  hot_lower_live_apply_parent_err_extraction_for_crossed_gap(real)
  hot_control_result_type_set(
    real.fixture.hot_func,
    real.err_block,
    hot_type_intern_value(real.fixture.hot_func, @lib.ValType::i32()),
  )

  match hot_verify_all(real.fixture.hot_func, cache=Some(())) {
    Err(InvalidBranchArity(_, _, 0, 1)) => ()
    Err(err) => fail(err.to_string())
    Ok(_) =>
      fail(
        "expected parent err block result rewrite to invalidate crossed-gap branch payload arity",
      )
  }
}

///|
test "hot lower live repro validates extracted real carrier with earlier zero-result branch root through parent err block" {
  let real = hot_lower_live_real_carrier_with_skip_fixture()
  hot_lower_live_apply_parent_err_extraction_with_skip(real)
  hot_control_result_type_set(
    real.fixture.hot_func,
    real.carried_if,
    hot_type_void(real.fixture.hot_func),
  )

  let lowered = hot_lower_func(real.fixture.hot_func)
  let next_code_sec = match real.fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[real.fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = real.fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot verify rejects extracted real carrier with earlier zero-result branch root when parent err block becomes result-producing" {
  let real = hot_lower_live_real_carrier_with_skip_fixture()
  hot_lower_live_apply_parent_err_extraction_with_skip(real)
  hot_control_result_type_set(
    real.fixture.hot_func,
    real.err_block,
    hot_type_intern_value(real.fixture.hot_func, @lib.ValType::i32()),
  )
  hot_control_result_type_set(
    real.fixture.hot_func,
    real.carried_if,
    hot_type_void(real.fixture.hot_func),
  )

  match hot_verify_all(real.fixture.hot_func, cache=Some(())) {
    Err(InvalidBranchArity(_, _, 0, 1)) => ()
    Err(err) => fail(err.to_string())
    Ok(_) =>
      fail(
        "expected parent err block result rewrite to invalidate closer zero-result-prefix carrier too",
      )
  }
}

///|
test "hot lower live repro validates extracted carrier payload and void carried if through parent err block" {
  let real = hot_lower_live_real_carrier_fixture()
  hot_lower_live_apply_parent_err_extraction(real)
  hot_control_result_type_set(
    real.fixture.hot_func,
    real.carried_if,
    hot_type_void(real.fixture.hot_func),
  )

  let lowered = hot_lower_func(real.fixture.hot_func)
  let next_code_sec = match real.fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[real.fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = real.fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot verify rejects extracted carrier payload when parent err block becomes result-producing" {
  let real = hot_lower_live_real_carrier_fixture()
  hot_lower_live_apply_parent_err_extraction(real)
  hot_control_result_type_set(
    real.fixture.hot_func,
    real.err_block,
    hot_type_intern_value(real.fixture.hot_func, @lib.ValType::i32()),
  )
  hot_control_result_type_set(
    real.fixture.hot_func,
    real.carried_if,
    hot_type_void(real.fixture.hot_func),
  )

  match hot_verify_all(real.fixture.hot_func, cache=Some(())) {
    Err(InvalidBranchArity(_, _, 0, 1)) => ()
    Err(err) => fail(err.to_string())
    Ok(_) =>
      fail(
        "expected parent err block result rewrite to invalidate branch payload arity",
      )
  }
}

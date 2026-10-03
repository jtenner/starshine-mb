///|
// Frozen eager output-storage boundary; recursive child rewriting is identical.
fn type_remap_eager_reference(
  instrs : Array[@lib.Instruction],
  remap : Map[UInt, UInt],
) -> Array[@lib.Instruction]? {
  let rewritten : Array[@lib.Instruction] = Array::new(capacity=instrs.length())
  let mut changed = false
  let mut idx = 0
  while idx < instrs.length() {
    let instr = instrs[idx]
    match dfe_try_rewrite_instruction_type_idxs(instr, remap) {
      Some(next) => {
        if !changed {
          let mut prefix = 0
          while prefix < idx {
            rewritten.push(instrs[prefix])
            prefix += 1
          }
          changed = true
        }
        rewritten.push(next)
      }
      None => if changed { rewritten.push(instr) }
    }
    idx += 1
  }
  if changed {
    Some(rewritten)
  } else {
    None
  }
}

///|
test "type remap storage preserves unchanged input and ordered sparse edits" {
  let remap : Map[UInt, UInt] = Map([])
  remap[1U] = 0U
  for width in [0, 1, 8] {
    for changed in [false, true] {
      let body = Array::make(width, @lib.Instruction::nop())
      if changed {
        body.push(@lib.Instruction::call_ref(@lib.TypeIdx::new(1U)))
      }
      body.push(@lib.Instruction::call(@lib.FuncIdx::new(3U)))
      let snapshot = body.copy()
      let expected = type_remap_eager_reference(body, remap)
      let actual = dfe_try_rewrite_instruction_array_type_idxs(body, remap)
      assert_eq(actual, expected)
      assert_eq(body, snapshot)
      if changed {
        let next = actual.unwrap()
        assert_eq(
          next[width],
          @lib.Instruction::call_ref(@lib.TypeIdx::new(0U)),
        )
        assert_eq(next[width + 1], body[width + 1])
        assert_false(physical_equal(next, body))
        for index in 0..<width {
          assert_true(physical_equal(next[index], body[index]))
        }
        next.push(@lib.Instruction::unreachable_())
        assert_eq(body, snapshot)
      } else {
        assert_true(actual is None)
      }
    }
  }
}

///|
test "type remap storage preserves nested control GC references and dense changes" {
  let remap : Map[UInt, UInt] = Map([])
  remap[1U] = 0U
  let inner = [
    @lib.Instruction::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(1U))),
  ]
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      @lib.Expr::new(inner),
    ),
    @lib.Instruction::call_ref(@lib.TypeIdx::new(1U)),
    @lib.Instruction::return_call_ref(@lib.TypeIdx::new(1U)),
  ]
  let snapshot = body.copy()
  let expected = type_remap_eager_reference(body, remap).unwrap()
  let actual = dfe_try_rewrite_instruction_array_type_idxs(body, remap).unwrap()
  assert_eq(actual, expected)
  assert_eq(body, snapshot)
  assert_eq(inner, [
    @lib.Instruction::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(1U))),
  ])
  assert_eq(actual[1], @lib.Instruction::call_ref(@lib.TypeIdx::new(0U)))
  assert_eq(actual[2], @lib.Instruction::return_call_ref(@lib.TypeIdx::new(0U)))
  let identity : Map[UInt, UInt] = Map([])
  identity[1U] = 1U
  // Existing remapping treats an explicitly present identity mapping as a
  // rewrite. Preserve that contract rather than folding another transform in.
  assert_eq(
    dfe_try_rewrite_instruction_array_type_idxs(body, identity),
    type_remap_eager_reference(body, identity),
  )
  assert_eq(
    dfe_try_rewrite_instruction_array_type_idxs(body, identity).unwrap(),
    body,
  )
  let absent : Map[UInt, UInt] = Map([])
  assert_true(dfe_try_rewrite_instruction_array_type_idxs(body, absent) is None)
  // A later remap must observe current input, not reuse an unchanged proof.
  assert_eq(
    dfe_try_rewrite_instruction_array_type_idxs(body, remap).unwrap(),
    actual,
  )
}

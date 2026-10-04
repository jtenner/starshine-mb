///|
fn cl_live_words_from_bools(values : Array[Bool]) -> @bitset.BitSet {
  let out = @bitset.BitSet::new(values.length())
  for i = 0; i < values.length(); i = i + 1 {
    if values[i] {
      out[i] = true
    }
  }
  out
}

///|
fn cl_mark_structured_liveness_backward(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  effective : Array[Bool],
  write_live_hazards : CLBitMatrix,
  visited_actions : Array[Int],
  live_after : Array[Bool],
  label_lives : Array[Array[Bool]],
  action_cursor : Array[Int],
  exception_live? : Array[Bool] = [],
  control_visits? : Array[Int]? = None,
  control_index? : CLControlIndex? = None,
  control_start? : Int = 0,
) -> Array[Bool] {
  cl_live_words_to_bools(
    cl_mark_structured_live_words_backward(
      instrs,
      actions,
      effective,
      write_live_hazards,
      visited_actions,
      cl_live_words_from_bools(live_after),
      label_lives.map(cl_live_words_from_bools),
      action_cursor,
      exception_live=cl_live_words_from_bools(exception_live),
      control_visits~,
      control_index~,
      control_start~,
    ),
  )
}

///|
test "coalesce structured live words preserve all Boolean-reference fields across word boundaries" {
  for count in [2, 8, 63, 64, 65, 129] {
    let last = count - 1
    let middle = count / 2
    for
      source in [
        "local.get 0 if local.get \{last} local.set \{middle} else local.get \{middle} local.set \{last} end local.get \{middle} drop local.get \{last} drop",
        "local.get 0 if i32.const 7 local.set \{last} end local.get \{last} drop",
        "block local.get 0 if i32.const 7 local.set \{last} local.get \{middle} drop br 1 else local.get \{last} drop end end local.get \{last} drop",
        "block loop local.get 0 br_if 1 local.get \{last} drop i32.const 7 local.set \{middle} end end local.get \{middle} drop",
        "block i32.const 7 local.set \{last} local.get 0 br_table 0 0 0 i32.const 9 local.set \{last} end local.get \{last} drop",
        "block try_table (catch $e 0) local.get 0 if i32.const 7 local.set \{last} throw $e else local.get \{middle} drop end end end local.get \{last} drop",
        "local.get \{last} drop return_call $tick i32.const 9 local.set \{middle}",
      ] {
      let input = pass_test_module_from_wat(
        "(module (import \"host\" \"tick\" (func $tick)) (tag $e) (func (param i32) (local \{Array::make(count - 1, "i32").join(" ")}) \{source}))",
      )
      @validate.validate_module(input).unwrap()
      let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
      let live_after = Array::makei(count, fn(i) { i % 3 == 0 })
      let labels = [Array::makei(count, fn(i) { i % 5 == 0 })]
      let exception_live = Array::makei(count, fn(i) { i % 7 == 0 })
      let saved = (
        live_after.copy(),
        labels.map(fn(row) { row.copy() }),
        exception_live.copy(),
      )
      let actual = cl_branch_live_storage_result(
        body, live_after, labels, exception_live, false,
      )
      assert_eq(
        actual,
        cl_branch_live_storage_result(
          body, live_after, labels, exception_live, true,
        ),
      )
      actual.0[0] = !actual.0[0]
      assert_eq((live_after, labels, exception_live), saved)
    }
  }
}

///|
test "coalesce packed liveness joins preserve row widths and independent snapshots" {
  for width in [0, 1, 63, 64, 65, 129] {
    let live = @bitset.BitSet::new(width)
    let larger = @bitset.BitSet::make(width + 65, true)
    cl_replace_live_words(live, larger)
    assert_eq(cl_live_words_to_bools(live), Array::make(width, true))
    let saved = live.copy()
    cl_replace_live_words(live, @bitset.BitSet::new(0))
    assert_eq(cl_live_words_to_bools(live), Array::make(width, false))
    cl_union_live_words(live, larger)
    assert_eq(cl_live_words_to_bools(live), Array::make(width, true))
    assert_eq(live.words.length(), (width + 63) / 64)
    if width % 64 != 0 {
      assert_eq(
        live.words[live.words.length() - 1],
        (1UL << (width % 64)) - 1UL,
      )
    }
    live.fill(false)
    assert_eq(cl_live_words_to_bools(saved), Array::make(width, true))
    assert_eq(larger.length(), width + 65)
    assert_true(larger[width + 64])
  }
}

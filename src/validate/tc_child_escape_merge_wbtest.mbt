///|
test "child escape merge preserves ordered duplicates with one owned output" {
  for left in [[], [-1, 0], [0x7fffffff], [0, 1, 4, 1], [5, 2]] {
    for right in [left, [], [0], [0, 3, 3], [2, 6]] {
      let held_left = left.copy()
      let held_right = right.copy()
      let expected = tc_escape_depths_merge(
        tc_escape_depths_shift_to_parent(left),
        tc_escape_depths_shift_to_parent(right),
      )
      let output_arrays = [0]
      let actual = tc_escape_depths_merge_children(
        left,
        right,
        output_arrays=Some(output_arrays),
      )
      assert_eq(actual, expected)
      assert_eq(left, held_left)
      assert_eq(right, held_right)
      actual.push(17)
      assert_eq(left, held_left)
      assert_eq(right, held_right)
      assert_eq(output_arrays, [1])
    }
  }
}

///|
test "finish if escape merge retains parent sharing and child ownership" {
  for parent_depths in [[], [7, 7]] {
    for left_depths in [[], [0], [0, 2, 2]] {
      for right_depths in [[], [0], [3, 1]] {
        let parent = TcState::{
          ..make_state(empty_env(), []),
          reachable_escape_depths: parent_depths.copy(),
        }
        let left = TcState::{
          ..make_state(parent.env, []),
          reachable_escape_depths: left_depths.copy(),
        }
        let right = TcState::{
          ..make_state(parent.env, []),
          reachable_escape_depths: right_depths.copy(),
        }
        let expected_children = tc_escape_depths_merge(
          tc_escape_depths_shift_to_parent(left_depths),
          tc_escape_depths_shift_to_parent(right_depths),
        )
        let expected = tc_escape_depths_merge(parent_depths, expected_children)
        let actual = tc_state_finish_if(parent, parent, left, right, []).unwrap()
        assert_eq(actual.reachable_escape_depths, expected)
        assert_true(actual.reachable)
        assert_eq(actual.escape, NoTcEscape)
        assert_eq(actual.stack, [])
        assert_eq(
          physical_equal(
            actual.reachable_escape_depths,
            parent.reachable_escape_depths,
          ),
          !parent_depths.is_empty() && expected_children.is_empty(),
        )
        actual.reachable_escape_depths.push(11)
        assert_eq(left.reachable_escape_depths, left_depths)
        assert_eq(right.reachable_escape_depths, right_depths)
        if parent_depths.is_empty() || !expected_children.is_empty() {
          assert_eq(parent.reachable_escape_depths, parent_depths)
        }
      }
    }
  }
}

///|
test "finish if escape merge retains first invalid branch error and inputs" {
  let parent = TcState::{
    ..make_state(empty_env(), []),
    reachable_escape_depths: [7],
  }
  let left = TcState::{
    ..make_state(parent.env, []),
    reachable_escape_depths: [0, 3],
  }
  let right = TcState::{
    ..make_state(parent.env, [ValType::i64()]),
    reachable_escape_depths: [2, 2],
  }
  assert_eq(
    tc_state_finish_if(parent, parent, left, right, [ValType::i32()]).unwrap_err(),
    "stack underflow",
  )
  let valid_left = TcState::{ ..left, stack: [ValType::i32()], }
  assert_eq(
    tc_state_finish_if(parent, parent, valid_left, right, [ValType::i32()]).unwrap_err(),
    "type mismatch",
  )
  assert_eq(parent.reachable_escape_depths, [7])
  assert_eq(left.reachable_escape_depths, [0, 3])
  assert_eq(right.reachable_escape_depths, [2, 2])
  assert_eq(left.stack, [])
  assert_eq(valid_left.stack, [ValType::i32()])
  assert_eq(right.stack, [ValType::i64()])
}

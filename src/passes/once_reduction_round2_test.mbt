///|
test "round2 once independent guard init 1 block False tail False" {
  let output = audit_run(
    (
      #|(module (global $a (mut i32) (i32.const 1))
      #|(global $b (mut i32) (i32.const 0))
      #|(global $side (export "side") (mut i32) (i32.const 0))
      #|(func $B global.get $b if return end i32.const 1 global.set $b i32.const 7 global.set $side)
      #|(func (export "run") global.get $a if return end i32.const 1 global.set $a call $B))
    ),
    "once-reduction",
  )
  assert_true(
    audit_count(audit_body(output, index=1), fn(i) {
      i is @lib.GlobalGet(@lib.GlobalIdx(0U))
    }) >
    0,
  )
}

///|
test "round2 once independent guard init 1 block False tail True" {
  let output = audit_run(
    (
      #|(module (global $a (mut i32) (i32.const 1))
      #|(global $b (mut i32) (i32.const 0))
      #|(global $side (export "side") (mut i32) (i32.const 0))
      #|(func $B global.get $b if return end i32.const 1 global.set $b i32.const 7 global.set $side)
      #|(func (export "run") global.get $a if return end i32.const 1 global.set $a return_call $B))
    ),
    "once-reduction",
  )
  assert_true(
    audit_count(audit_body(output, index=1), fn(i) {
      i is @lib.GlobalGet(@lib.GlobalIdx(0U))
    }) >
    0,
  )
}

///|
test "round2 once independent guard init 1 block True tail False" {
  let output = audit_run(
    (
      #|(module (global $a (mut i32) (i32.const 1))
      #|(global $b (mut i32) (i32.const 0))
      #|(global $side (export "side") (mut i32) (i32.const 0))
      #|(func $B global.get $b if return end i32.const 1 global.set $b i32.const 7 global.set $side)
      #|(func (export "run") block global.get $a if return end i32.const 1 global.set $a call $B end))
    ),
    "once-reduction",
  )
  assert_true(
    audit_count(audit_body(output, index=1), fn(i) {
      i is @lib.GlobalGet(@lib.GlobalIdx(0U))
    }) >
    0,
  )
}

///|
test "round2 once independent guard init 1 block True tail True" {
  let output = audit_run(
    (
      #|(module (global $a (mut i32) (i32.const 1))
      #|(global $b (mut i32) (i32.const 0))
      #|(global $side (export "side") (mut i32) (i32.const 0))
      #|(func $B global.get $b if return end i32.const 1 global.set $b i32.const 7 global.set $side)
      #|(func (export "run") block global.get $a if return end i32.const 1 global.set $a return_call $B end))
    ),
    "once-reduction",
  )
  assert_true(
    audit_count(audit_body(output, index=1), fn(i) {
      i is @lib.GlobalGet(@lib.GlobalIdx(0U))
    }) >
    0,
  )
}

///|
test "round2 once independent guard init -1 block False tail False" {
  let output = audit_run(
    (
      #|(module (global $a (mut i32) (i32.const -1))
      #|(global $b (mut i32) (i32.const 0))
      #|(global $side (export "side") (mut i32) (i32.const 0))
      #|(func $B global.get $b if return end i32.const 1 global.set $b i32.const 7 global.set $side)
      #|(func (export "run") global.get $a if return end i32.const 1 global.set $a call $B))
    ),
    "once-reduction",
  )
  assert_true(
    audit_count(audit_body(output, index=1), fn(i) {
      i is @lib.GlobalGet(@lib.GlobalIdx(0U))
    }) >
    0,
  )
}

///|
test "round2 once independent guard init -1 block False tail True" {
  let output = audit_run(
    (
      #|(module (global $a (mut i32) (i32.const -1))
      #|(global $b (mut i32) (i32.const 0))
      #|(global $side (export "side") (mut i32) (i32.const 0))
      #|(func $B global.get $b if return end i32.const 1 global.set $b i32.const 7 global.set $side)
      #|(func (export "run") global.get $a if return end i32.const 1 global.set $a return_call $B))
    ),
    "once-reduction",
  )
  assert_true(
    audit_count(audit_body(output, index=1), fn(i) {
      i is @lib.GlobalGet(@lib.GlobalIdx(0U))
    }) >
    0,
  )
}

///|
test "round2 once independent guard init -1 block True tail False" {
  let output = audit_run(
    (
      #|(module (global $a (mut i32) (i32.const -1))
      #|(global $b (mut i32) (i32.const 0))
      #|(global $side (export "side") (mut i32) (i32.const 0))
      #|(func $B global.get $b if return end i32.const 1 global.set $b i32.const 7 global.set $side)
      #|(func (export "run") block global.get $a if return end i32.const 1 global.set $a call $B end))
    ),
    "once-reduction",
  )
  assert_true(
    audit_count(audit_body(output, index=1), fn(i) {
      i is @lib.GlobalGet(@lib.GlobalIdx(0U))
    }) >
    0,
  )
}

///|
test "round2 once independent guard init -1 block True tail True" {
  let output = audit_run(
    (
      #|(module (global $a (mut i32) (i32.const -1))
      #|(global $b (mut i32) (i32.const 0))
      #|(global $side (export "side") (mut i32) (i32.const 0))
      #|(func $B global.get $b if return end i32.const 1 global.set $b i32.const 7 global.set $side)
      #|(func (export "run") block global.get $a if return end i32.const 1 global.set $a return_call $B end))
    ),
    "once-reduction",
  )
  assert_true(
    audit_count(audit_body(output, index=1), fn(i) {
      i is @lib.GlobalGet(@lib.GlobalIdx(0U))
    }) >
    0,
  )
}

///|
test "fourth audit local cse preserves interleaved global write" {
  let output = audit_run(
    "(module (global (export \"g\") (mut i32) (i32.const 0)) (func (param i32) (result i32) local.get 0 i32.const 1 i32.add drop local.get 0 i32.const 99 global.set 0 i32.const 1 i32.add))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalSet(_) }),
    1,
  )
}

///|
test "fourth audit local cse preserves interleaved store" {
  let output = audit_run(
    "(module (memory 1) (func (param i32) (result i32) local.get 0 i32.const 1 i32.add drop local.get 0 i32.const 0 i32.const 99 i32.store i32.const 1 i32.add))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Store(_) }),
    1,
  )
}

///|
test "fourth audit local cse preserves interleaved call" {
  let output = audit_run(
    "(module (import \"env\" \"effect\" (func)) (func (param i32) (result i32) local.get 0 i32.const 1 i32.add drop local.get 0 call 0 i32.const 1 i32.add))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.Call(_) }),
    1,
  )
}

///|
test "fourth audit local cse i32.add keeps i32.const 99 local.set 1" {
  let output = audit_run(
    "(module  (func (param i32) (result i32) (local i32) local.get 0 i32.const 1 i32.add drop local.get 0 i32.const 99 local.set 1 i32.const 1 i32.add))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) {
      i is @lib.LocalSet(@lib.LocalIdx(1U))
    }),
    1,
  )
}

///|
test "fourth audit local cse i32.add keeps i32.const 0 i32.load drop" {
  let output = audit_run(
    "(module (memory 1) (func (param i32) (result i32)  local.get 0 i32.const 1 i32.add drop local.get 0 i32.const 0 i32.load drop i32.const 1 i32.add))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Load(_) }),
    1,
  )
}

///|
test "fourth audit local cse i32.add keeps i32.const 1 i32.const 0 i32.div_s drop" {
  let output = audit_run(
    "(module  (func (param i32) (result i32)  local.get 0 i32.const 1 i32.add drop local.get 0 i32.const 1 i32.const 0 i32.div_s drop i32.const 1 i32.add))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32DivS }),
    1,
  )
}

///|
test "fourth audit local cse i32.mul keeps i32.const 99 local.set 1" {
  let output = audit_run(
    "(module  (func (param i32) (result i32) (local i32) local.get 0 i32.const 1 i32.mul drop local.get 0 i32.const 99 local.set 1 i32.const 1 i32.mul))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) {
      i is @lib.LocalSet(@lib.LocalIdx(1U))
    }),
    1,
  )
}

///|
test "fourth audit local cse i32.mul keeps i32.const 0 i32.load drop" {
  let output = audit_run(
    "(module (memory 1) (func (param i32) (result i32)  local.get 0 i32.const 1 i32.mul drop local.get 0 i32.const 0 i32.load drop i32.const 1 i32.mul))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Load(_) }),
    1,
  )
}

///|
test "fourth audit local cse i32.mul keeps i32.const 1 i32.const 0 i32.div_s drop" {
  let output = audit_run(
    "(module  (func (param i32) (result i32)  local.get 0 i32.const 1 i32.mul drop local.get 0 i32.const 1 i32.const 0 i32.div_s drop i32.const 1 i32.mul))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32DivS }),
    1,
  )
}

///|
test "fourth audit local cse i32.xor keeps i32.const 99 local.set 1" {
  let output = audit_run(
    "(module  (func (param i32) (result i32) (local i32) local.get 0 i32.const 1 i32.xor drop local.get 0 i32.const 99 local.set 1 i32.const 1 i32.xor))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) {
      i is @lib.LocalSet(@lib.LocalIdx(1U))
    }),
    1,
  )
}

///|
test "fourth audit local cse i32.xor keeps i32.const 0 i32.load drop" {
  let output = audit_run(
    "(module (memory 1) (func (param i32) (result i32)  local.get 0 i32.const 1 i32.xor drop local.get 0 i32.const 0 i32.load drop i32.const 1 i32.xor))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Load(_) }),
    1,
  )
}

///|
test "fourth audit local cse i32.xor keeps i32.const 1 i32.const 0 i32.div_s drop" {
  let output = audit_run(
    "(module  (func (param i32) (result i32)  local.get 0 i32.const 1 i32.xor drop local.get 0 i32.const 1 i32.const 0 i32.div_s drop i32.const 1 i32.xor))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32DivS }),
    1,
  )
}

///|
test "fourth audit local cse i32.eq keeps i32.const 99 local.set 1" {
  let output = audit_run(
    "(module  (func (param i32) (result i32) (local i32) local.get 0 i32.const 1 i32.eq drop local.get 0 i32.const 99 local.set 1 i32.const 1 i32.eq))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) {
      i is @lib.LocalSet(@lib.LocalIdx(1U))
    }),
    1,
  )
}

///|
test "fourth audit local cse i32.eq keeps i32.const 0 i32.load drop" {
  let output = audit_run(
    "(module (memory 1) (func (param i32) (result i32)  local.get 0 i32.const 1 i32.eq drop local.get 0 i32.const 0 i32.load drop i32.const 1 i32.eq))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Load(_) }),
    1,
  )
}

///|
test "fourth audit local cse i32.eq keeps i32.const 1 i32.const 0 i32.div_s drop" {
  let output = audit_run(
    "(module  (func (param i32) (result i32)  local.get 0 i32.const 1 i32.eq drop local.get 0 i32.const 1 i32.const 0 i32.div_s drop i32.const 1 i32.eq))",
    "local-cse",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32DivS }),
    1,
  )
}

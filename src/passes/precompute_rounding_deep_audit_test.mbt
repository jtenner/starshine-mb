///|
test "deep audit precompute rounds i64 s exp 54 neighbor -1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 18014399583223807 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1518338048L,
  ])
}

///|
test "deep audit precompute rounds i64 s exp 54 neighbor -1 negative True" {
  let output = audit_run(
    "(module (func (result i32) i64.const -18014399583223807 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    -629145600L,
  ])
}

///|
test "deep audit precompute rounds i64 s exp 54 neighbor 0 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 18014399583223808 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1518338048L,
  ])
}

///|
test "deep audit precompute rounds i64 s exp 54 neighbor 0 negative True" {
  let output = audit_run(
    "(module (func (result i32) i64.const -18014399583223808 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    -629145600L,
  ])
}

///|
test "deep audit precompute rounds i64 s exp 54 neighbor 1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 18014399583223809 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1518338049L,
  ])
}

///|
test "deep audit precompute rounds i64 s exp 54 neighbor 1 negative True" {
  let output = audit_run(
    "(module (func (result i32) i64.const -18014399583223809 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    -629145599L,
  ])
}

///|
test "deep audit precompute rounds i64 s exp 62 neighbor -1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 4611686293305294847 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1585446912L,
  ])
}

///|
test "deep audit precompute rounds i64 s exp 62 neighbor -1 negative True" {
  let output = audit_run(
    "(module (func (result i32) i64.const -4611686293305294847 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    -562036736L,
  ])
}

///|
test "deep audit precompute rounds i64 s exp 62 neighbor 0 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 4611686293305294848 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1585446912L,
  ])
}

///|
test "deep audit precompute rounds i64 s exp 62 neighbor 0 negative True" {
  let output = audit_run(
    "(module (func (result i32) i64.const -4611686293305294848 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    -562036736L,
  ])
}

///|
test "deep audit precompute rounds i64 s exp 62 neighbor 1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 4611686293305294849 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1585446913L,
  ])
}

///|
test "deep audit precompute rounds i64 s exp 62 neighbor 1 negative True" {
  let output = audit_run(
    "(module (func (result i32) i64.const -4611686293305294849 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    -562036735L,
  ])
}

///|
test "deep audit precompute rounds i64 u exp 54 neighbor -1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 18014399583223807 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1518338048L,
  ])
}

///|
test "deep audit precompute rounds i64 u exp 54 neighbor 0 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 18014399583223808 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1518338048L,
  ])
}

///|
test "deep audit precompute rounds i64 u exp 54 neighbor 1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 18014399583223809 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1518338049L,
  ])
}

///|
test "deep audit precompute rounds i64 u exp 62 neighbor -1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 4611686293305294847 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1585446912L,
  ])
}

///|
test "deep audit precompute rounds i64 u exp 62 neighbor 0 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 4611686293305294848 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1585446912L,
  ])
}

///|
test "deep audit precompute rounds i64 u exp 62 neighbor 1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 4611686293305294849 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1585446913L,
  ])
}

///|
test "deep audit precompute rounds i64 u exp 63 neighbor -1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const -9223371487098961921 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1593835520L,
  ])
}

///|
test "deep audit precompute rounds i64 u exp 63 neighbor 0 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const -9223371487098961920 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1593835520L,
  ])
}

///|
test "deep audit precompute rounds i64 u exp 63 neighbor 1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const -9223371487098961919 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1593835521L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 s exp 54 neighbor -1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 18014399583223807 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1518338048L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 s exp 54 neighbor -1 negative True" {
  let output = audit_run(
    "(module (func (result i32) i64.const -18014399583223807 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    -629145600L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 s exp 54 neighbor 0 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 18014399583223808 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1518338048L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 s exp 54 neighbor 0 negative True" {
  let output = audit_run(
    "(module (func (result i32) i64.const -18014399583223808 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    -629145600L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 s exp 54 neighbor 1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 18014399583223809 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1518338049L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 s exp 54 neighbor 1 negative True" {
  let output = audit_run(
    "(module (func (result i32) i64.const -18014399583223809 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    -629145599L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 s exp 62 neighbor -1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 4611686293305294847 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1585446912L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 s exp 62 neighbor -1 negative True" {
  let output = audit_run(
    "(module (func (result i32) i64.const -4611686293305294847 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    -562036736L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 s exp 62 neighbor 0 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 4611686293305294848 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1585446912L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 s exp 62 neighbor 0 negative True" {
  let output = audit_run(
    "(module (func (result i32) i64.const -4611686293305294848 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    -562036736L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 s exp 62 neighbor 1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 4611686293305294849 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1585446913L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 s exp 62 neighbor 1 negative True" {
  let output = audit_run(
    "(module (func (result i32) i64.const -4611686293305294849 f32.convert_i64_s i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    -562036735L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 u exp 54 neighbor -1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 18014399583223807 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1518338048L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 u exp 54 neighbor 0 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 18014399583223808 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1518338048L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 u exp 54 neighbor 1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 18014399583223809 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1518338049L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 u exp 62 neighbor -1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 4611686293305294847 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1585446912L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 u exp 62 neighbor 0 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 4611686293305294848 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1585446912L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 u exp 62 neighbor 1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const 4611686293305294849 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1585446913L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 u exp 63 neighbor -1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const -9223371487098961921 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1593835520L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 u exp 63 neighbor 0 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const -9223371487098961920 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1593835520L,
  ])
}

///|
test "deep audit precompute-propagate rounds i64 u exp 63 neighbor 1 negative False" {
  let output = audit_run(
    "(module (func (result i32) i64.const -9223371487098961919 f32.convert_i64_u i32.reinterpret_f32))",
    "precompute-propagate",
  )
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1593835521L,
  ])
}

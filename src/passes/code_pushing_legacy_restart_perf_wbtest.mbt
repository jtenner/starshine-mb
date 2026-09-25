///|
fn code_pushing_legacy_restart_perf_body(
  moves : Int,
) -> Array[@lib.Instruction] {
  let source = StringBuilder::new()
  source.write_string("(module (func")
  for _ in 0..<(moves + 1) {
    source.write_string(" (local i32)")
  }
  source.write_string(" (block $out")
  for local_id in 0..<(moves + 1) {
    source.write_string(" (local.set ")
    source.write_string(local_id.to_string())
    source.write_string(" (i32.const 1))")
    source.write_string(" (try (do nop) (catch_all))")
    source.write_string(" (drop (i32.const 0))")
    source.write_string(" (br_if $out (i32.const 0))")
    source.write_string(" (drop (local.get ")
    source.write_string(local_id.to_string())
    source.write_string("))")
    if local_id == 0 {
      source.write_string(" (local.set 0 (i32.const 2))")
    }
  }
  source.write_string(")))")
  let fixture = pass_test_module_from_wat(source.to_string())
  match fixture.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => body
    _ => abort("CodePushing legacy restart fixture lacks one function")
  }
}

///|
fn code_pushing_legacy_restart_perf_bench(it : @bench.T, moves : Int) -> Unit {
  let body = code_pushing_legacy_restart_perf_body(moves)
  let (_, changed) = code_pushing_raw_rewrite_legacy_instrs(body, body)
  if !changed {
    abort("CodePushing legacy restart fixture moved no constants")
  }
  it.bench(fn() {
    let (rewritten, changed) = code_pushing_raw_rewrite_legacy_instrs(
      body, body,
    )
    it.keep(rewritten)
    it.keep(changed)
  })
}

///|
test "CodePushing legacy restart keeps rejected set and moves eligible sets" {
  let body = code_pushing_legacy_restart_perf_body(2)
  let (rewritten, changed) = code_pushing_raw_rewrite_legacy_instrs(body, body)
  assert_true(changed)
  let roots = match rewritten {
    [@lib.Block(_, @lib.Expr(roots))] => roots
    _ => abort("CodePushing legacy restart fixture lost its block")
  }
  let mut moved = 0
  for idx = 0; idx + 2 < roots.length(); idx = idx + 1 {
    if roots[idx] is @lib.BrIf(_) && roots[idx + 2] is @lib.LocalSet(_) {
      moved += 1
    }
  }
  assert_eq(moved, 2)
}

///|
test "bench CodePushing legacy restart moves=1" (it : @bench.T) {
  code_pushing_legacy_restart_perf_bench(it, 1)
}

///|
test "bench CodePushing legacy restart moves=16" (it : @bench.T) {
  code_pushing_legacy_restart_perf_bench(it, 16)
}

///|
test "bench CodePushing legacy restart moves=32" (it : @bench.T) {
  code_pushing_legacy_restart_perf_bench(it, 32)
}

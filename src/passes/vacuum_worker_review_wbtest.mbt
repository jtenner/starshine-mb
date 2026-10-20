///|
fn vacuum_worker_review_fixture(kind : Int32) -> Array[@lib.Instruction] {
  match kind {
    0 => vacuum_worker_review_f2850()
    1 | 4 => {
      let body = [
        pass_manager_test_vacuum_plain_block(
          pass_manager_test_vacuum_f4702_loop_call_result_child_body(),
        ),
      ]
      body.append(pass_manager_test_vacuum_f4702_store_continuation())
      let padded = if kind == 4 {
        let padded = []
        for instr in body {
          padded.push(@lib.Instruction::nop())
          padded.push(instr)
        }
        padded
      } else {
        body
      }
      [pass_manager_test_vacuum_plain_block(padded)]
    }
    2 => vacuum_worker_review_f1963()
    _ =>
      [
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          ]),
          @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        ]),
      ]
  }
}

///|
/// Raw artifact fragments retain their external local, call and label indices.
/// Snapshot bytes to check ownership without treating the fragment as a module.
fn vacuum_worker_review_bytes(body : Array[@lib.Instruction]) -> Bytes {
  @binary.encode_module(
    @lib.Module::new().with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
      ]),
    ),
  ).unwrap()
}

///|
test "Vacuum worker retains shape precedence effects and input ownership" {
  for kind in 0..<5 {
    let input = vacuum_worker_review_fixture(kind)
    let saved = vacuum_worker_review_bytes(input)
    let expected = vacuum_worker_review_reference(input, None)
    let actual = run_hot_pipeline_raw_vacuum_preclean_instrs_owned(input, None)
    assert_eq(actual, expected)
    assert_eq(vacuum_worker_review_bytes(input), saved)
    if kind != 3 {
      assert_true(actual.1)
    }
  }
}

///|
fn vacuum_worker_review_bench(
  it : @bench.T,
  kind : Int32,
  reference : Bool,
) -> Unit raise {
  let input = vacuum_worker_review_fixture(kind)
  let expected = vacuum_worker_review_reference(input, None)
  assert_eq(
    run_hot_pipeline_raw_vacuum_preclean_instrs_owned(input, None),
    expected,
  )
  if kind != 3 {
    assert_true(expected.1)
  }
  let work = fn() {
    it.keep(
      if reference {
        vacuum_worker_review_reference(input, None)
      } else {
        run_hot_pipeline_raw_vacuum_preclean_instrs_owned(input, None)
      },
    )
  }
  // Equal work counts let the external allocator probe compare both paths.
  if @env.get_env_var("STARSHINE_PASS_REVIEW_FIXED") == Some("1") {
    for _ in 0..<64 {
      work()
    }
  } else if @env.get_env_var("STARSHINE_PASS_REVIEW_FIXED") != Some("0") {
    it.bench(work)
  }
}

///|
test "bench Vacuum worker f2850 reference" (it : @bench.T) {
  vacuum_worker_review_bench(it, 0, true)
}

///|
test "bench Vacuum worker f2850 single probe" (it : @bench.T) {
  vacuum_worker_review_bench(it, 0, false)
}

///|
test "bench Vacuum worker f4702 reference" (it : @bench.T) {
  vacuum_worker_review_bench(it, 1, true)
}

///|
test "bench Vacuum worker f4702 single probe" (it : @bench.T) {
  vacuum_worker_review_bench(it, 1, false)
}

///|
test "bench Vacuum worker f1963 reference" (it : @bench.T) {
  vacuum_worker_review_bench(it, 2, true)
}

///|
test "bench Vacuum worker f1963 single probe" (it : @bench.T) {
  vacuum_worker_review_bench(it, 2, false)
}

///|
test "bench Vacuum worker clean miss reference" (it : @bench.T) {
  vacuum_worker_review_bench(it, 3, true)
}

///|
test "bench Vacuum worker clean miss single probe" (it : @bench.T) {
  vacuum_worker_review_bench(it, 3, false)
}

///|
test "bench Vacuum worker Nop padded f4702 reference" (it : @bench.T) {
  vacuum_worker_review_bench(it, 4, true)
}

///|
test "bench Vacuum worker Nop padded f4702 single probe" (it : @bench.T) {
  vacuum_worker_review_bench(it, 4, false)
}

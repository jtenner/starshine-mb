///|
priv struct MBParityFixture {
  name : String
  mod : Module
}

///|
fn MBParityFixture::new(name : String, mod : Module) -> MBParityFixture {
  { name, mod }
}

///|
priv struct MBParityBaselineMetrics {
  total_fixtures : Int
  changed_count : Int
  valid_after_count : Int
  idempotent_count : Int
  value_branch_count_after : Int
}

///|
fn MBParityBaselineMetrics::new(
  total_fixtures : Int,
  changed_count : Int,
  valid_after_count : Int,
  idempotent_count : Int,
  value_branch_count_after : Int,
) -> MBParityBaselineMetrics {
  {
    total_fixtures,
    changed_count,
    valid_after_count,
    idempotent_count,
    value_branch_count_after,
  }
}

///|
fn mbp_fixture_corpus() -> Array[MBParityFixture] {
  let fixtures : Array[MBParityFixture] = []

  let nested_unnamed = mb_make_test_module_with_body(
    [],
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(1))),
          TInstr::drop(TInstr::i32_const(I32(2))),
        ]),
      ),
    ]),
  )
  fixtures.push(MBParityFixture::new("nested_unnamed_merge", nested_unnamed))

  let two_level = mb_make_test_module_with_body(
    [],
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([TInstr::drop(TInstr::i32_const(I32(3)))]),
          ),
        ]),
      ),
    ]),
  )
  fixtures.push(MBParityFixture::new("two_level_convergence", two_level))

  let dropped_br = mb_make_test_module_with_body(
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(5))]),
            TInstr::i32_const(I32(7)),
          ]),
        ),
      ),
    ]),
  )
  fixtures.push(MBParityFixture::new("dropped_break_value_strip", dropped_br))

  let already_flat = mb_make_test_module_with_body(
    [],
    TExpr::new([TInstr::drop(TInstr::i32_const(I32(9)))]),
  )
  fixtures.push(MBParityFixture::new("already_flat_noop", already_flat))

  let loop_tail_extract = mb_make_test_module_with_body(
    [],
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::loop_(
            BlockType::void_(),
            TExpr::new([
              TInstr::block(
                BlockType::void_(),
                TExpr::new([
                  TInstr::br_if(LabelIdx::new(1), TInstr::i32_const(I32(0)), []),
                  TInstr::call(FuncIdx::new(0), []),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
  fixtures.push(MBParityFixture::new("loop_tail_extract", loop_tail_extract))

  let try_table_all_ref = uf_test_try_table_catch_all_ref_module()
  fixtures.push(
    MBParityFixture::new("try_table_catch_all_ref", try_table_all_ref),
  )

  let restructure_operand = mb_make_test_module_with_body(
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::block(
            BlockType::val_type(ValType::i32()),
            TExpr::new([
              TInstr::drop(TInstr::i32_const(I32(1))),
              TInstr::i32_const(I32(2)),
            ]),
          ),
          TInstr::i32_const(I32(3)),
        ),
      ),
    ]),
  )
  fixtures.push(
    MBParityFixture::new("restructure_operand_prefix_pull", restructure_operand),
  )

  let idempotence_seed = mb_make_test_module_with_body(
    [],
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::drop(
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(1))),
                TInstr::i32_const(I32(2)),
              ]),
            ),
          ),
        ]),
      ),
    ]),
  )
  fixtures.push(MBParityFixture::new("idempotence_seed", idempotence_seed))

  fixtures
}

///|
fn mbp_value_branch_count_expr(expr : TExpr) -> Int {
  let mut count = 0
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TBr(_, values) | TInstrKind::TBrIf(_, _, values) =>
          if !values.is_empty() {
            count += 1
          }
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), expr))
  count
}

///|
fn mbp_value_branch_count_module(mod : Module) -> Int {
  let mut count = 0
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        match func {
          TFunc(_, _, body) => count += mbp_value_branch_count_expr(body)
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn mbp_collect_baseline_metrics(iterations : Int) -> MBParityBaselineMetrics {
  let fixture_list = mbp_fixture_corpus()
  let mut changed_count = 0
  let mut valid_after_count = 0
  let mut idempotent_count = 0
  let mut value_branch_count_after = 0
  for _ in 0..<iterations {
    for fixture in fixture_list {
      ignore(fixture.name)
      let out = run_merge_blocks(fixture.mod)
      if out != fixture.mod {
        changed_count += 1
      }
      match validate_module(out) {
        Ok(_) => valid_after_count += 1
        Err(_) => ()
      }
      if run_merge_blocks(out) == out {
        idempotent_count += 1
      }
      value_branch_count_after += mbp_value_branch_count_module(out)
    }
  }
  MBParityBaselineMetrics::new(
    fixture_list.length() * iterations,
    changed_count,
    valid_after_count,
    idempotent_count,
    value_branch_count_after,
  )
}

///|
fn mbp_time_fixed_corpus_us(iterations : Int) -> UInt64 {
  let fixture_list = mbp_fixture_corpus()
  let start_us = trace_now_us()
  for _ in 0..<iterations {
    for fixture in fixture_list {
      ignore(run_merge_blocks(fixture.mod))
    }
  }
  trace_elapsed_us_since(start_us)
}

///|
test "merge blocks parity corpus contains fixed fixtures" {
  let fixtures = mbp_fixture_corpus()
  assert_eq(fixtures.length(), 8)
}

///|
test "merge blocks parity fixtures validate before and after pass" {
  for fixture in mbp_fixture_corpus() {
    match validate_module(fixture.mod) {
      Ok(_) => ()
      Err(e) =>
        fail("expected fixture to validate before pass: \{fixture.name}: \{e}")
    }
    let out = run_merge_blocks(fixture.mod)
    match validate_module(out) {
      Ok(_) => ()
      Err(e) =>
        fail("expected fixture to validate after pass: \{fixture.name}: \{e}")
    }
  }
}

///|
test "merge blocks parity baseline correctness metrics are stable" {
  let metrics = mbp_collect_baseline_metrics(1)
  assert_eq(metrics.total_fixtures, 8)
  assert_eq(metrics.changed_count, 5)
  assert_eq(metrics.valid_after_count, 8)
  assert_eq(metrics.idempotent_count, 8)
  assert_eq(metrics.value_branch_count_after, 0)
}

///|
test "merge blocks parity timing harness runs fixed corpus" {
  let elapsed_us = mbp_time_fixed_corpus_us(128)
  assert_true(elapsed_us > 0UL)
}

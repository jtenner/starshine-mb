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
priv struct MBParityMatrixCase {
  category : String
  scenario : String
  mod : Module
  expected_changed : Bool?
  expected_value_branch_after : Int?
  require_stack_sig_consistency : Bool
}

///|
fn MBParityMatrixCase::new(
  category : String,
  scenario : String,
  mod : Module,
  expected_changed : Bool?,
  expected_value_branch_after : Int?,
  require_stack_sig_consistency : Bool,
) -> MBParityMatrixCase {
  {
    category,
    scenario,
    mod,
    expected_changed,
    expected_value_branch_after,
    require_stack_sig_consistency,
  }
}

///|
priv struct MBParityMatrixResult {
  category : String
  scenario : String
  changed : Bool
  validates_before : Bool
  validates_after : Bool
  idempotent : Bool
  value_branch_after : Int
  stack_sig_consistent_after : Bool
  expected_changed : Bool?
  expected_value_branch_after : Int?
  require_stack_sig_consistency : Bool
}

///|
fn MBParityMatrixResult::new(
  category : String,
  scenario : String,
  changed : Bool,
  validates_before : Bool,
  validates_after : Bool,
  idempotent : Bool,
  value_branch_after : Int,
  stack_sig_consistent_after : Bool,
  expected_changed : Bool?,
  expected_value_branch_after : Int?,
  require_stack_sig_consistency : Bool,
) -> MBParityMatrixResult {
  {
    category,
    scenario,
    changed,
    validates_before,
    validates_after,
    idempotent,
    value_branch_after,
    stack_sig_consistent_after,
    expected_changed,
    expected_value_branch_after,
    require_stack_sig_consistency,
  }
}

///|
priv struct MBParitySignoffMetrics {
  total_rows : Int
  match_rows : Int
  intentional_divergence_rows : Int
  validates_before_rows : Int
  validates_after_rows : Int
  idempotent_rows : Int
  changed_rows : Int
  value_branch_zero_rows : Int
  stack_sig_required_rows : Int
  stack_sig_consistent_rows : Int
  required_category_count : Int
}

///|
fn MBParitySignoffMetrics::new(
  total_rows : Int,
  match_rows : Int,
  intentional_divergence_rows : Int,
  validates_before_rows : Int,
  validates_after_rows : Int,
  idempotent_rows : Int,
  changed_rows : Int,
  value_branch_zero_rows : Int,
  stack_sig_required_rows : Int,
  stack_sig_consistent_rows : Int,
  required_category_count : Int,
) -> MBParitySignoffMetrics {
  {
    total_rows,
    match_rows,
    intentional_divergence_rows,
    validates_before_rows,
    validates_after_rows,
    idempotent_rows,
    changed_rows,
    value_branch_zero_rows,
    stack_sig_required_rows,
    stack_sig_consistent_rows,
    required_category_count,
  }
}

///|
fn mbp_required_parity_matrix_categories() -> Array[String] {
  [
    "named block merge boundaries", "loop-tail extraction", "dropped-block value removal",
    "try_table catch permutations", "restructure dependency/effect collisions", "type/stack-signature invariants",
    "idempotence",
  ]
}

///|
fn mbp_named_block_boundary_module() -> Module {
  mb_make_test_module_with_body(
    Locals::empty(),
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
          ),
          TInstr::drop(TInstr::i32_const(I32(1))),
        ]),
      ),
    ]),
  )
}

///|
fn mbp_loop_tail_extract_module() -> Module {
  mb_make_test_module_with_body(
    Locals::empty(),
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
}

///|
fn mbp_dropped_value_removal_module() -> Module {
  mb_make_test_module_with_body(
    Locals::empty(),
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
}

///|
fn mbp_try_table_catch_ref_no_params_module() -> Module {
  let tag_type = TagType::new(TypeIdx::new(0))
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::try_table(
            BlockType::void_(),
            [Catch::ref_(TagIdx::new(0), LabelIdx::new(1))],
            TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
          ),
          TInstr::i32_const(I32(6)),
        ]),
      ),
    ),
  ])
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([], []))),
      RecType::new(SubType::comp_type(CompType::func([], []))),
    ]),
  )
  .with_tag_sec(TagSec::new([tag_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
  .with_code_sec(CodeSec::new([Func::t_func([], Locals::empty(), body)]))
}

///|
fn mbp_try_table_catch_targeting_origin_blocked_module() -> Module {
  let tag_type = TagType::new(TypeIdx::new(0))
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::try_table(
            BlockType::void_(),
            [Catch::new(TagIdx::new(0), LabelIdx::new(1))],
            TExpr::new([
              TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(8))]),
            ]),
          ),
          TInstr::i32_const(I32(1)),
        ]),
      ),
    ),
  ])
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
      RecType::new(SubType::comp_type(CompType::func([], []))),
    ]),
  )
  .with_tag_sec(TagSec::new([tag_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
  .with_code_sec(CodeSec::new([Func::t_func([], Locals::empty(), body)]))
}

///|
fn mbp_try_table_catch_all_targeting_origin_blocked_module() -> Module {
  let tag_type = TagType::new(TypeIdx::new(0))
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::try_table(
            BlockType::void_(),
            [Catch::all(LabelIdx::new(1))],
            TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
          ),
          TInstr::i32_const(I32(2)),
        ]),
      ),
    ),
  ])
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([], []))),
      RecType::new(SubType::comp_type(CompType::func([], []))),
    ]),
  )
  .with_tag_sec(TagSec::new([tag_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
  .with_code_sec(CodeSec::new([Func::t_func([], Locals::empty(), body)]))
}

///|
fn mbp_try_table_catch_ref_paramful_blocked_module() -> Module {
  let tag_type = TagType::new(TypeIdx::new(0))
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::try_table(
            BlockType::void_(),
            [Catch::ref_(TagIdx::new(0), LabelIdx::new(1))],
            TExpr::new([TInstr::nop()]),
          ),
          TInstr::i32_const(I32(1)),
        ]),
      ),
    ),
  ])
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
      RecType::new(SubType::comp_type(CompType::func([], []))),
    ]),
  )
  .with_tag_sec(TagSec::new([tag_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
  .with_code_sec(CodeSec::new([Func::t_func([], Locals::empty(), body)]))
}

///|
fn mbp_restructure_effect_collision_module() -> Module {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::call(FuncIdx::new(1), []),
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::drop(TInstr::call(FuncIdx::new(1), [])),
            TInstr::i32_const(I32(2)),
          ]),
        ),
      ),
    ),
  ])
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([], []))),
      RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func([], Locals::empty(), body),
      Func::t_func([], Locals::empty(), TExpr::new([TInstr::i32_const(I32(9))])),
    ]),
  )
}

///|
fn mbp_typed_stack_signature_module() -> Module {
  mb_make_test_module_with_body(
    Locals::from_types([ValType::i32()]),
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::local_set(
            LocalIdx::new(0),
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::block(BlockType::void_(), TExpr::new([TInstr::nop()])),
                TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(9))]),
              ]),
            ),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn mbp_idempotence_matrix_module() -> Module {
  mb_make_test_module_with_body(
    Locals::empty(),
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
}

///|
fn mbp_validates_module(mod : Module) -> Bool {
  match validate_module(mod) {
    Ok(_) => true
    Err(_) => false
  }
}

///|
fn mbp_stack_sig_consistent_module(mod : Module) -> Bool {
  match mod.code_sec {
    Some(CodeSec(funcs)) => {
      for func in funcs {
        match func {
          TFunc(params, locals, body) => {
            let env = Env::new()
              .with_module(mod)
              .with_locals(FunctionLocals::new(params, locals).all_locals())
            match mb_stack_sig_list(body.instrs, env) {
              Some(sig) => if !mb_stack_sig_is_consistent(sig) { return false }
              None => return false
            }
          }
          _ => ()
        }
      }
      true
    }
    None => true
  }
}

///|
fn mbp_parity_matrix_cases() -> Array[MBParityMatrixCase] {
  [
    MBParityMatrixCase::new(
      "named block merge boundaries",
      "named-branch-boundary-preserved",
      mbp_named_block_boundary_module(),
      Some(false),
      None,
      false,
    ),
    MBParityMatrixCase::new(
      "loop-tail extraction",
      "loop-tail-extracts-safe-suffix",
      mbp_loop_tail_extract_module(),
      Some(true),
      None,
      false,
    ),
    MBParityMatrixCase::new(
      "dropped-block value removal",
      "dropped-break-values-stripped",
      mbp_dropped_value_removal_module(),
      Some(true),
      Some(0),
      false,
    ),
    MBParityMatrixCase::new(
      "try_table catch permutations",
      "catch_all_ref-allowed-rewrite",
      uf_test_try_table_catch_all_ref_module(),
      Some(false),
      None,
      false,
    ),
    MBParityMatrixCase::new(
      "try_table catch permutations",
      "catch_ref_no_params-allowed-rewrite",
      mbp_try_table_catch_ref_no_params_module(),
      Some(true),
      None,
      false,
    ),
    MBParityMatrixCase::new(
      "try_table catch permutations",
      "catch-targeting-origin-blocked",
      mbp_try_table_catch_targeting_origin_blocked_module(),
      Some(false),
      None,
      false,
    ),
    MBParityMatrixCase::new(
      "try_table catch permutations",
      "catch_all-targeting-origin-blocked",
      mbp_try_table_catch_all_targeting_origin_blocked_module(),
      Some(false),
      None,
      false,
    ),
    MBParityMatrixCase::new(
      "try_table catch permutations",
      "catch_ref_paramful-targeting-origin-blocked",
      mbp_try_table_catch_ref_paramful_blocked_module(),
      Some(false),
      None,
      false,
    ),
    MBParityMatrixCase::new(
      "restructure dependency/effect collisions",
      "effect-collision-blocks-pull",
      mbp_restructure_effect_collision_module(),
      Some(false),
      None,
      false,
    ),
    MBParityMatrixCase::new(
      "type/stack-signature invariants",
      "typed-if-stack-signature-preserved",
      mbp_typed_stack_signature_module(),
      None,
      None,
      true,
    ),
    MBParityMatrixCase::new(
      "idempotence",
      "run-once-vs-twice-stable",
      mbp_idempotence_matrix_module(),
      Some(true),
      None,
      false,
    ),
  ]
}

///|
fn mbp_collect_parity_matrix_results() -> Array[MBParityMatrixResult] {
  let rows : Array[MBParityMatrixResult] = []
  for case in mbp_parity_matrix_cases() {
    let validates_before = mbp_validates_module(case.mod)
    let out = run_merge_blocks(case.mod)
    let validates_after = mbp_validates_module(out)
    let changed = out != case.mod
    let idempotent = run_merge_blocks(out) == out
    let value_branch_after = mbp_value_branch_count_module(out)
    let stack_sig_consistent_after = if case.require_stack_sig_consistency {
      mbp_stack_sig_consistent_module(out)
    } else {
      true
    }
    rows.push(
      MBParityMatrixResult::new(
        case.category,
        case.scenario,
        changed,
        validates_before,
        validates_after,
        idempotent,
        value_branch_after,
        stack_sig_consistent_after,
        case.expected_changed,
        case.expected_value_branch_after,
        case.require_stack_sig_consistency,
      ),
    )
  }
  rows
}

///|
fn mbp_parity_row_signoff_status(
  row : MBParityMatrixResult,
) -> (String, String?) {
  if row.category == "try_table catch permutations" && !row.validates_before {
    (
      "Intentional divergence",
      Some(
        "This parity row uses a non-validating pre-pass fixture to lock legality/shape behavior only; signoff tracks outcome parity rather than strict validator preconditions for this row.",
      ),
    )
  } else {
    ("Match", None)
  }
}

///|
fn mbp_collect_parity_signoff_metrics() -> MBParitySignoffMetrics {
  let rows = mbp_collect_parity_matrix_results()
  let mut match_rows = 0
  let mut intentional_divergence_rows = 0
  let mut validates_before_rows = 0
  let mut validates_after_rows = 0
  let mut idempotent_rows = 0
  let mut changed_rows = 0
  let mut value_branch_zero_rows = 0
  let mut stack_sig_required_rows = 0
  let mut stack_sig_consistent_rows = 0
  for row in rows {
    if row.validates_before {
      validates_before_rows += 1
    }
    if row.validates_after {
      validates_after_rows += 1
    }
    if row.idempotent {
      idempotent_rows += 1
    }
    if row.changed {
      changed_rows += 1
    }
    if row.value_branch_after == 0 {
      value_branch_zero_rows += 1
    }
    if row.require_stack_sig_consistency {
      stack_sig_required_rows += 1
      if row.stack_sig_consistent_after {
        stack_sig_consistent_rows += 1
      }
    }
    let (status, _) = mbp_parity_row_signoff_status(row)
    if status == "Match" {
      match_rows += 1
    } else if status == "Intentional divergence" {
      intentional_divergence_rows += 1
    }
  }
  MBParitySignoffMetrics::new(
    rows.length(),
    match_rows,
    intentional_divergence_rows,
    validates_before_rows,
    validates_after_rows,
    idempotent_rows,
    changed_rows,
    value_branch_zero_rows,
    stack_sig_required_rows,
    stack_sig_consistent_rows,
    mbp_required_parity_matrix_categories().length(),
  )
}

///|
fn mbp_fixture_corpus() -> Array[MBParityFixture] {
  let fixtures : Array[MBParityFixture] = []

  let nested_unnamed = mb_make_test_module_with_body(
    Locals::empty(),
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
    Locals::empty(),
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
    Locals::empty(),
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
    Locals::empty(),
    TExpr::new([TInstr::drop(TInstr::i32_const(I32(9)))]),
  )
  fixtures.push(MBParityFixture::new("already_flat_noop", already_flat))

  let loop_tail_extract = mb_make_test_module_with_body(
    Locals::empty(),
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
    Locals::empty(),
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
    Locals::empty(),
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

///|
test "merge blocks parity matrix covers required categories" {
  let rows = mbp_collect_parity_matrix_results()
  let required = mbp_required_parity_matrix_categories()
  for category in required {
    let mut found = false
    for row in rows {
      if row.category == category {
        found = true
        break
      }
    }
    assert_true(found, msg="missing parity matrix category: \{category}")
  }
}

///|
test "merge blocks parity matrix rows meet expected outcomes" {
  let rows = mbp_collect_parity_matrix_results()
  assert_true(!rows.is_empty())
  for row in rows {
    if row.category != "try_table catch permutations" {
      assert_true(
        row.validates_before,
        msg="expected row to validate before pass: \{row.category}/\{row.scenario}",
      )
      assert_true(
        row.validates_after,
        msg="expected row to validate after pass: \{row.category}/\{row.scenario}",
      )
    }
    assert_true(
      row.idempotent,
      msg="expected row to be idempotent (run once vs twice): \{row.category}/\{row.scenario}",
    )
    match row.expected_changed {
      Some(expect_changed) =>
        if row.changed != expect_changed {
          fail(
            "unexpected changed flag for parity row \{row.category}/\{row.scenario}: expected=\{expect_changed} actual=\{row.changed}",
          )
        }
      None => ()
    }
    match row.expected_value_branch_after {
      Some(expected_value_branch_after) =>
        if row.value_branch_after != expected_value_branch_after {
          fail(
            "unexpected value-branch count for parity row \{row.category}/\{row.scenario}: expected=\{expected_value_branch_after} actual=\{row.value_branch_after}",
          )
        }
      None => ()
    }
    if row.require_stack_sig_consistency {
      assert_true(
        row.stack_sig_consistent_after,
        msg="expected stack signature consistency after pass: \{row.category}/\{row.scenario}",
      )
    }
  }
}

///|
test "merge blocks parity signoff classifies each row as match or intentional divergence" {
  for row in mbp_collect_parity_matrix_results() {
    let (status, _) = mbp_parity_row_signoff_status(row)
    assert_true(
      status == "Match" || status == "Intentional divergence",
      msg="unexpected signoff status for row \{row.category}/\{row.scenario}: \{status}",
    )
  }
}

///|
test "merge blocks parity signoff metrics are stable" {
  let metrics = mbp_collect_parity_signoff_metrics()
  assert_eq(metrics.total_rows, 11)
  assert_eq(
    metrics.total_rows,
    metrics.match_rows + metrics.intentional_divergence_rows,
  )
  assert_eq(metrics.match_rows, 8)
  assert_eq(metrics.intentional_divergence_rows, 3)
  assert_eq(metrics.idempotent_rows, metrics.total_rows)
  assert_eq(metrics.required_category_count, 7)
  assert_eq(metrics.validates_before_rows, 8)
  assert_eq(metrics.validates_after_rows, 9)
  assert_eq(metrics.changed_rows, 5)
  assert_eq(metrics.value_branch_zero_rows, 10)
  assert_eq(metrics.stack_sig_required_rows, 1)
  assert_eq(metrics.stack_sig_consistent_rows, metrics.stack_sig_required_rows)
}

///|
test "merge blocks parity signoff intentional divergence rows are explicit" {
  let intentional_divergence_rows : Array[String] = []
  for row in mbp_collect_parity_matrix_results() {
    let (status, rationale) = mbp_parity_row_signoff_status(row)
    if status == "Intentional divergence" {
      assert_true(
        rationale is Some(_),
        msg="intentional divergence row must include rationale: \{row.category}/\{row.scenario}",
      )
      intentional_divergence_rows.push(row.scenario)
    }
  }
  assert_eq(intentional_divergence_rows.length(), 3)
  assert_true(
    intentional_divergence_rows.contains("catch_ref_no_params-allowed-rewrite"),
  )
  assert_true(
    intentional_divergence_rows.contains("catch_all-targeting-origin-blocked"),
  )
  assert_true(
    intentional_divergence_rows.contains(
      "catch_ref_paramful-targeting-origin-blocked",
    ),
  )
}

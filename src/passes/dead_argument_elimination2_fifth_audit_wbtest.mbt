///|
test "fifth audit dae2 public rec sibling i32 (import" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $f (func (param i32))) (type $s (struct))) (import \"m\" \"g\" (global (ref null $s))) (func $helper (type $f) (param i32)) (table 1 funcref) (elem (i32.const 0) $helper) (func (export \"run\") i32.const 7 i32.const 0 call_indirect (type $f)))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2"],
  ).unwrap()
  let before = @validate.Env::new().with_module(input)
  let after = @validate.Env::new().with_module(output)
  @debug.assert_eq(
    after.resolve_functype(@lib.TypeIdx::new(0U)),
    before.resolve_functype(@lib.TypeIdx::new(0U)),
  )
}

///|
test "fifth audit dae2 public rec sibling i32 (global" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $f (func (param i32))) (type $s (struct))) (global (export \"g\") (ref null $s) ref.null $s) (func $helper (type $f) (param i32)) (table 1 funcref) (elem (i32.const 0) $helper) (func (export \"run\") i32.const 7 i32.const 0 call_indirect (type $f)))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2"],
  ).unwrap()
  let before = @validate.Env::new().with_module(input)
  let after = @validate.Env::new().with_module(output)
  @debug.assert_eq(
    after.resolve_functype(@lib.TypeIdx::new(0U)),
    before.resolve_functype(@lib.TypeIdx::new(0U)),
  )
}

///|
test "fifth audit dae2 public rec sibling i32 (table" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $f (func (param i32))) (type $s (struct))) (func $helper (type $f) (param i32)) (table 1 funcref) (table (export \"t\") 1 (ref null $s)) (elem (i32.const 0) func $helper) (func (export \"run\") i32.const 7 i32.const 0 call_indirect (type $f)))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2"],
  ).unwrap()
  let before = @validate.Env::new().with_module(input)
  let after = @validate.Env::new().with_module(output)
  @debug.assert_eq(
    after.resolve_functype(@lib.TypeIdx::new(0U)),
    before.resolve_functype(@lib.TypeIdx::new(0U)),
  )
}

///|
test "fifth audit dae2 public rec sibling i64 (import" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $f (func (param i64))) (type $s (struct))) (import \"m\" \"g\" (global (ref null $s))) (func $helper (type $f) (param i64)) (table 1 funcref) (elem (i32.const 0) $helper) (func (export \"run\") i64.const 7 i32.const 0 call_indirect (type $f)))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2"],
  ).unwrap()
  let before = @validate.Env::new().with_module(input)
  let after = @validate.Env::new().with_module(output)
  @debug.assert_eq(
    after.resolve_functype(@lib.TypeIdx::new(0U)),
    before.resolve_functype(@lib.TypeIdx::new(0U)),
  )
}

///|
test "fifth audit dae2 public rec sibling i64 (global" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $f (func (param i64))) (type $s (struct))) (global (export \"g\") (ref null $s) ref.null $s) (func $helper (type $f) (param i64)) (table 1 funcref) (elem (i32.const 0) $helper) (func (export \"run\") i64.const 7 i32.const 0 call_indirect (type $f)))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2"],
  ).unwrap()
  let before = @validate.Env::new().with_module(input)
  let after = @validate.Env::new().with_module(output)
  @debug.assert_eq(
    after.resolve_functype(@lib.TypeIdx::new(0U)),
    before.resolve_functype(@lib.TypeIdx::new(0U)),
  )
}

///|
test "fifth audit dae2 public rec sibling i64 (table" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $f (func (param i64))) (type $s (struct))) (func $helper (type $f) (param i64)) (table 1 funcref) (table (export \"t\") 1 (ref null $s)) (elem (i32.const 0) func $helper) (func (export \"run\") i64.const 7 i32.const 0 call_indirect (type $f)))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2"],
  ).unwrap()
  let before = @validate.Env::new().with_module(input)
  let after = @validate.Env::new().with_module(output)
  @debug.assert_eq(
    after.resolve_functype(@lib.TypeIdx::new(0U)),
    before.resolve_functype(@lib.TypeIdx::new(0U)),
  )
}

///|
test "fifth audit dae2-optimizing public rec sibling i32 (import" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $f (func (param i32))) (type $s (struct))) (import \"m\" \"g\" (global (ref null $s))) (func $helper (type $f) (param i32)) (table 1 funcref) (elem (i32.const 0) $helper) (func (export \"run\") i32.const 7 i32.const 0 call_indirect (type $f)))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2-optimizing"],
  ).unwrap()
  let before = @validate.Env::new().with_module(input)
  let after = @validate.Env::new().with_module(output)
  @debug.assert_eq(
    after.resolve_functype(@lib.TypeIdx::new(0U)),
    before.resolve_functype(@lib.TypeIdx::new(0U)),
  )
}

///|
test "fifth audit dae2-optimizing public rec sibling i32 (global" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $f (func (param i32))) (type $s (struct))) (global (export \"g\") (ref null $s) ref.null $s) (func $helper (type $f) (param i32)) (table 1 funcref) (elem (i32.const 0) $helper) (func (export \"run\") i32.const 7 i32.const 0 call_indirect (type $f)))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2-optimizing"],
  ).unwrap()
  let before = @validate.Env::new().with_module(input)
  let after = @validate.Env::new().with_module(output)
  @debug.assert_eq(
    after.resolve_functype(@lib.TypeIdx::new(0U)),
    before.resolve_functype(@lib.TypeIdx::new(0U)),
  )
}

///|
test "fifth audit dae2-optimizing public rec sibling i32 (table" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $f (func (param i32))) (type $s (struct))) (func $helper (type $f) (param i32)) (table 1 funcref) (table (export \"t\") 1 (ref null $s)) (elem (i32.const 0) func $helper) (func (export \"run\") i32.const 7 i32.const 0 call_indirect (type $f)))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2-optimizing"],
  ).unwrap()
  let before = @validate.Env::new().with_module(input)
  let after = @validate.Env::new().with_module(output)
  @debug.assert_eq(
    after.resolve_functype(@lib.TypeIdx::new(0U)),
    before.resolve_functype(@lib.TypeIdx::new(0U)),
  )
}

///|
test "fifth audit dae2-optimizing public rec sibling i64 (import" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $f (func (param i64))) (type $s (struct))) (import \"m\" \"g\" (global (ref null $s))) (func $helper (type $f) (param i64)) (table 1 funcref) (elem (i32.const 0) $helper) (func (export \"run\") i64.const 7 i32.const 0 call_indirect (type $f)))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2-optimizing"],
  ).unwrap()
  let before = @validate.Env::new().with_module(input)
  let after = @validate.Env::new().with_module(output)
  @debug.assert_eq(
    after.resolve_functype(@lib.TypeIdx::new(0U)),
    before.resolve_functype(@lib.TypeIdx::new(0U)),
  )
}

///|
test "fifth audit dae2-optimizing public rec sibling i64 (global" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $f (func (param i64))) (type $s (struct))) (global (export \"g\") (ref null $s) ref.null $s) (func $helper (type $f) (param i64)) (table 1 funcref) (elem (i32.const 0) $helper) (func (export \"run\") i64.const 7 i32.const 0 call_indirect (type $f)))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2-optimizing"],
  ).unwrap()
  let before = @validate.Env::new().with_module(input)
  let after = @validate.Env::new().with_module(output)
  @debug.assert_eq(
    after.resolve_functype(@lib.TypeIdx::new(0U)),
    before.resolve_functype(@lib.TypeIdx::new(0U)),
  )
}

///|
test "fifth audit dae2-optimizing public rec sibling i64 (table" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $f (func (param i64))) (type $s (struct))) (func $helper (type $f) (param i64)) (table 1 funcref) (table (export \"t\") 1 (ref null $s)) (elem (i32.const 0) func $helper) (func (export \"run\") i64.const 7 i32.const 0 call_indirect (type $f)))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2-optimizing"],
  ).unwrap()
  let before = @validate.Env::new().with_module(input)
  let after = @validate.Env::new().with_module(output)
  @debug.assert_eq(
    after.resolve_functype(@lib.TypeIdx::new(0U)),
    before.resolve_functype(@lib.TypeIdx::new(0U)),
  )
}

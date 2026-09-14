///|
fn deep_audit_rume_input(kind : String) -> @lib.Module {
  if kind == "table" {
    let base = pass_test_module_from_wat(
      "(module (type $f (func (result i32))) (import \"env\" \"target\" (global funcref)) (table 1 funcref) (func (export \"run\") (result i32) i32.const 0 call_indirect (type $f)))",
    )
    return base.with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::abs(@lib.AbsHeapType::func()),
            @lib.Limits::i32(1U, None),
          ),
          Some(
            @lib.Expr::new([
              @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            ]),
          ),
        ),
      ]),
    )
  }
  let base = pass_test_module_from_wat(
    "(module (type $f (func (result i32))) (type $a (array (mut funcref))) (table 1 funcref) (func $target (type $f) i32.const 42) (func (export \"run\") (result i32) i32.const 0 call_indirect (type $f)))",
  )
  let get = @lib.Expr::new([
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  ])
  let func_ref = @lib.Expr::new([
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
  ])
  let base = base.with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::funcref(), false),
        func_ref,
      ),
    ]),
  )
  let declarations = @lib.Elem::new(
    @lib.ElemMode::declarative(),
    @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
  )
  let mode = if kind == "active" {
    @lib.ElemMode::active(
      @lib.TableIdx::new(0U),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    )
  } else {
    @lib.ElemMode::passive()
  }
  let base = base.with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        mode,
        @lib.ElemKind::typed_exprs(
          @lib.RefType::abs(@lib.AbsHeapType::func()),
          [get],
        ),
      ),
      declarations,
    ]),
  )
  if kind == "passive" {
    let funcs = base.code_sec.unwrap().0.copy()
    funcs[1] = @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::array_new_elem(
          @lib.TypeIdx::new(1U),
          @lib.ElemIdx::new(0U),
        ),
        @lib.Instruction::array_len(),
      ]),
    )
    base.with_code_sec(@lib.CodeSec::new(funcs))
  } else {
    base
  }
}

///|
test "deep audit remove-unused-module-elements retains active global reference closed false" {
  let input = deep_audit_rume_input("active")
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=false), [
      "remove-unused-module-elements",
    ]) {
    Ok(output) => output
    Err(err) => fail("expected valid RUME output: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_true(output.global_sec is Some(@lib.GlobalSec([_, ..])))
  assert_true(output.code_sec is Some(@lib.CodeSec([_, _, ..])))
}

///|
test "deep audit remove-unused-module-elements retains active global reference closed true" {
  let input = deep_audit_rume_input("active")
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=true), [
      "remove-unused-module-elements",
    ]) {
    Ok(output) => output
    Err(err) => fail("expected valid RUME output: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_true(output.global_sec is Some(@lib.GlobalSec([_, ..])))
  assert_true(output.code_sec is Some(@lib.CodeSec([_, _, ..])))
}

///|
test "deep audit remove-unused-nonfunction-module-elements retains active global reference closed false" {
  let input = deep_audit_rume_input("active")
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=false), [
      "remove-unused-nonfunction-module-elements",
    ]) {
    Ok(output) => output
    Err(err) => fail("expected valid RUME output: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_true(output.global_sec is Some(@lib.GlobalSec([_, ..])))
  assert_true(output.code_sec is Some(@lib.CodeSec([_, _, ..])))
}

///|
test "deep audit remove-unused-nonfunction-module-elements retains active global reference closed true" {
  let input = deep_audit_rume_input("active")
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=true), [
      "remove-unused-nonfunction-module-elements",
    ]) {
    Ok(output) => output
    Err(err) => fail("expected valid RUME output: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_true(output.global_sec is Some(@lib.GlobalSec([_, ..])))
  assert_true(output.code_sec is Some(@lib.CodeSec([_, _, ..])))
}

///|
test "deep audit remove-unused-module-elements retains passive global reference closed false" {
  let input = deep_audit_rume_input("passive")
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=false), [
      "remove-unused-module-elements",
    ]) {
    Ok(output) => output
    Err(err) => fail("expected valid RUME output: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_true(output.global_sec is Some(@lib.GlobalSec([_, ..])))
  assert_true(output.code_sec is Some(@lib.CodeSec([_, _, ..])))
}

///|
test "deep audit remove-unused-module-elements retains passive global reference closed true" {
  let input = deep_audit_rume_input("passive")
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=true), [
      "remove-unused-module-elements",
    ]) {
    Ok(output) => output
    Err(err) => fail("expected valid RUME output: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_true(output.global_sec is Some(@lib.GlobalSec([_, ..])))
  assert_true(output.code_sec is Some(@lib.CodeSec([_, _, ..])))
}

///|
test "deep audit remove-unused-nonfunction-module-elements retains passive global reference closed false" {
  let input = deep_audit_rume_input("passive")
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=false), [
      "remove-unused-nonfunction-module-elements",
    ]) {
    Ok(output) => output
    Err(err) => fail("expected valid RUME output: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_true(output.global_sec is Some(@lib.GlobalSec([_, ..])))
  assert_true(output.code_sec is Some(@lib.CodeSec([_, _, ..])))
}

///|
test "deep audit remove-unused-nonfunction-module-elements retains passive global reference closed true" {
  let input = deep_audit_rume_input("passive")
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=true), [
      "remove-unused-nonfunction-module-elements",
    ]) {
    Ok(output) => output
    Err(err) => fail("expected valid RUME output: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_true(output.global_sec is Some(@lib.GlobalSec([_, ..])))
  assert_true(output.code_sec is Some(@lib.CodeSec([_, _, ..])))
}

///|
test "deep audit remove-unused-module-elements retains table global reference closed false" {
  let input = deep_audit_rume_input("table")
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=false), [
      "remove-unused-module-elements",
    ]) {
    Ok(output) => output
    Err(err) => fail("expected valid RUME output: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_true(output.import_sec is Some(@lib.ImportSec([_, ..])))
  assert_true(output.code_sec is Some(@lib.CodeSec([_, ..])))
}

///|
test "deep audit remove-unused-module-elements retains table global reference closed true" {
  let input = deep_audit_rume_input("table")
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=true), [
      "remove-unused-module-elements",
    ]) {
    Ok(output) => output
    Err(err) => fail("expected valid RUME output: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_true(output.import_sec is Some(@lib.ImportSec([_, ..])))
  assert_true(output.code_sec is Some(@lib.CodeSec([_, ..])))
}

///|
test "deep audit remove-unused-nonfunction-module-elements retains table global reference closed false" {
  let input = deep_audit_rume_input("table")
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=false), [
      "remove-unused-nonfunction-module-elements",
    ]) {
    Ok(output) => output
    Err(err) => fail("expected valid RUME output: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_true(output.import_sec is Some(@lib.ImportSec([_, ..])))
  assert_true(output.code_sec is Some(@lib.CodeSec([_, ..])))
}

///|
test "deep audit remove-unused-nonfunction-module-elements retains table global reference closed true" {
  let input = deep_audit_rume_input("table")
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=true), [
      "remove-unused-nonfunction-module-elements",
    ]) {
    Ok(output) => output
    Err(err) => fail("expected valid RUME output: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_true(output.import_sec is Some(@lib.ImportSec([_, ..])))
  assert_true(output.code_sec is Some(@lib.CodeSec([_, ..])))
}

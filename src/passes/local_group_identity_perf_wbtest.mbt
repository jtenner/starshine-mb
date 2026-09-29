///|
fn oi_group_numeric_locals_if_smaller_reference(
  mod_ : @lib.Module,
  touched? : Array[Bool]? = None,
) -> @lib.Module {
  if pass_module_has_legacy_try(mod_) ||
    oi_local_group_has_offset_metadata(mod_) {
    return mod_
  }
  let grouped = run_hot_pipeline_raw_group_body_locals_by_type_module(
    mod_,
    touched~,
  )
  if grouped.code_sec == mod_.code_sec {
    return mod_
  }
  let size_baseline = if mod_.compiler_fact_custom_section is Some(_) {
    mod_.without_compiler_fact_custom_section()
  } else {
    mod_
  }
  match @binary.encoded_module_sizes(size_baseline, grouped) {
    Ok((old_size, new_size)) if new_size < old_size =>
      if @validate.validate_module(grouped) is Ok(_) {
        return grouped
      }
    _ => ()
  }
  mod_
}

///|
fn dfe_group_numeric_locals_if_smaller_reference(
  mod_ : @lib.Module,
) -> @lib.Module {
  let before = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let grouped = run_hot_pipeline_raw_group_body_locals_by_type_module(mod_)
  let after = grouped.code_sec.unwrap().0
  let mut changed = false
  for idx = 0; idx < before.length(); idx = idx + 1 {
    let @lib.Func(old_locals, _) = before[idx]
    let @lib.Func(new_locals, _) = after[idx]
    if old_locals != new_locals {
      changed = true
      break
    }
  }
  if !changed {
    return mod_
  }
  match @binary.encoded_module_sizes(mod_, grouped) {
    Ok((old_size, new_size)) if new_size < old_size =>
      if @validate.validate_module(grouped) is Ok(_) {
        return grouped
      }
    _ => ()
  }
  mod_
}

///|
fn local_group_identity_bench(
  it : @bench.T,
  count : Int,
  width : Int,
  changed : Bool,
  oi : Bool,
  reference : Bool,
) -> Unit {
  let seed = pass_test_module_from_wat("(module (func (local i32)))")
  let locals = if changed {
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i64(),
    ])
  } else {
    @lib.Locals::single(16U, @lib.ValType::i32())
  }
  let body = Array::make(width, @lib.Instruction::nop())
  let func = @lib.Func::new(locals, @lib.Expr::new(body))
  let mod_ = seed
    .with_func_sec(
      @lib.FuncSec::new(Array::make(count, seed.func_sec.unwrap().0[0])),
    )
    .with_code_sec(@lib.CodeSec::new(Array::make(count, func)))
  @validate.validate_module(mod_).unwrap()
  let run = fn(old) {
    if oi {
      if old {
        oi_group_numeric_locals_if_smaller_reference(mod_)
      } else {
        oi_group_numeric_locals_if_smaller(mod_)
      }
    } else if old {
      dfe_group_numeric_locals_if_smaller_reference(mod_)
    } else {
      dfe_group_numeric_locals_if_smaller(mod_)
    }
  }
  if @binary.encode_module(run(true)).unwrap() !=
    @binary.encode_module(run(false)).unwrap() {
    abort("local grouping identity changed output bytes")
  }
  it.bench(fn() { it.keep(run(reference)) })
}

///|
test "bench DFE grouping functions=16 width=4 unchanged reference" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 16, 4, false, false, true)
}

///|
test "bench DFE grouping functions=16 width=4 unchanged identity" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 16, 4, false, false, false)
}

///|
test "bench OI grouping functions=16 width=4 unchanged reference" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 16, 4, false, true, true)
}

///|
test "bench OI grouping functions=16 width=4 unchanged identity" (it : @bench.T) {
  local_group_identity_bench(it, 16, 4, false, true, false)
}

///|
test "bench DFE grouping functions=16 width=4 changed reference" (it : @bench.T) {
  local_group_identity_bench(it, 16, 4, true, false, true)
}

///|
test "bench DFE grouping functions=16 width=4 changed identity" (it : @bench.T) {
  local_group_identity_bench(it, 16, 4, true, false, false)
}

///|
test "bench OI grouping functions=16 width=4 changed reference" (it : @bench.T) {
  local_group_identity_bench(it, 16, 4, true, true, true)
}

///|
test "bench OI grouping functions=16 width=4 changed identity" (it : @bench.T) {
  local_group_identity_bench(it, 16, 4, true, true, false)
}

///|
test "bench DFE grouping functions=128 width=128 unchanged reference" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 128, 128, false, false, true)
}

///|
test "bench DFE grouping functions=128 width=128 unchanged identity" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 128, 128, false, false, false)
}

///|
test "bench OI grouping functions=128 width=128 unchanged reference" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 128, 128, false, true, true)
}

///|
test "bench OI grouping functions=128 width=128 unchanged identity" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 128, 128, false, true, false)
}

///|
test "bench DFE grouping functions=128 width=128 changed reference" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 128, 128, true, false, true)
}

///|
test "bench DFE grouping functions=128 width=128 changed identity" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 128, 128, true, false, false)
}

///|
test "bench OI grouping functions=128 width=128 changed reference" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 128, 128, true, true, true)
}

///|
test "bench OI grouping functions=128 width=128 changed identity" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 128, 128, true, true, false)
}

///|
test "bench DFE grouping functions=4 width=4096 unchanged reference" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 4, 4096, false, false, true)
}

///|
test "bench DFE grouping functions=4 width=4096 unchanged identity" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 4, 4096, false, false, false)
}

///|
test "bench OI grouping functions=4 width=4096 unchanged reference" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 4, 4096, false, true, true)
}

///|
test "bench OI grouping functions=4 width=4096 unchanged identity" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 4, 4096, false, true, false)
}

///|
test "bench DFE grouping functions=4 width=4096 changed reference" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 4, 4096, true, false, true)
}

///|
test "bench DFE grouping functions=4 width=4096 changed identity" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 4, 4096, true, false, false)
}

///|
test "bench OI grouping functions=4 width=4096 changed reference" (
  it : @bench.T,
) {
  local_group_identity_bench(it, 4, 4096, true, true, true)
}

///|
test "bench OI grouping functions=4 width=4096 changed identity" (it : @bench.T) {
  local_group_identity_bench(it, 4, 4096, true, true, false)
}

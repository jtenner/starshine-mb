///|
fn table_image_experiment_source(extra~ : String = "") -> @lib.Module {
  pass_test_module_from_wat(
    "(module (type (func (result i32))) (table 2 funcref) (func (type 0) i32.const 11) (func (type 0) i32.const 22) (func (type 0) i32.const 33) (func (export \"sum\") (result i32) i32.const 0 call_indirect (type 0) i32.const 1 call_indirect (type 0) i32.add) \{extra} (elem (i32.const 0) func 0 1) (elem (i32.const 1) func 2))",
  )
}

///|
fn table_image_experiment_overwrite_candidate(
  input : @lib.Module,
) -> @lib.Module {
  // A manually constructed candidate for this fixture, not a production pass.
  input.with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(2U)]),
      ),
    ]),
  )
}

///|
fn table_image_experiment_image(
  input : @lib.Module,
) -> Result[Array[UInt32?], String] {
  // This small model covers only the fixed, internal-table fixtures below.
  if input.import_sec is Some(_) {
    return Err("imported state is outside the fixture domain")
  }
  let capacity = match input.table_sec {
    Some(
      @lib.TableSec(
        [@lib.Table(@lib.TableType(_, @lib.I32Limits(capacity, _)), None)]
      )
    ) if capacity <= 16U => capacity.to_int()
    _ => return Err("unsupported table fixture")
  }
  let image : Array[UInt32?] = Array::make(capacity, None)
  for elem in input.elem_sec.unwrap().0 {
    match elem {
      @lib.Elem(@lib.Declarative, _) => ()
      @lib.Elem(
        @lib.Active(
          @lib.TableIdx(0U),
          @lib.Expr([@lib.I32Const(@lib.I32(offset))])
        ),
        @lib.FuncsElemKind(funcs)
      ) => {
        if offset < 0 || offset > capacity || funcs.length() > capacity - offset {
          return Err("active element out of bounds")
        }
        for position, func in funcs {
          image[offset + position] = Some(func.0)
        }
      }
      _ => return Err("unsupported element fixture")
    }
  }
  Ok(image)
}

///|
fn table_image_experiment_check(
  input : @lib.Module,
  candidate : @lib.Module,
  before_size : Int32,
  after_size : Int32,
) -> Unit raise {
  ignore(@validate.validate_module(input).unwrap())
  ignore(@validate.validate_module(candidate).unwrap())
  let before = @binary.encode_module(input).unwrap()
  let after = @binary.encode_module(candidate).unwrap()
  @debug.assert_eq(before.length(), before_size)
  @debug.assert_eq(after.length(), after_size)
  @debug.assert_eq(
    table_image_experiment_image(input),
    Ok([Some(0U), Some(2U)]),
  )
  @debug.assert_eq(
    table_image_experiment_image(candidate),
    table_image_experiment_image(input),
  )
  @debug.assert_eq(candidate.code_sec, input.code_sec)
  @debug.assert_eq(candidate.export_sec, input.export_sec)
  let decoded = @binary.decode_module(after).unwrap()
  ignore(@validate.validate_module(decoded).unwrap())
  @debug.assert_eq(
    table_image_experiment_image(decoded),
    table_image_experiment_image(input),
  )
  @debug.assert_eq(@binary.encode_module(input).unwrap(), before)
}

///|
test "final table-image experiment merges a proved in-bounds overwrite" {
  let input = table_image_experiment_source()
  let candidate = table_image_experiment_overwrite_candidate(input)
  table_image_experiment_check(input, candidate, 85, 79)
}

///|
test "final table-image experiment merges adjacent constant segments" {
  let input = table_image_experiment_source()
  let elems = input.elem_sec.unwrap().0.copy()
  elems[0] = @lib.Elem::new(
    elems[0].0,
    @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
  )
  let input = input.with_elem_sec(@lib.ElemSec::new(elems))
  table_image_experiment_check(
    input,
    table_image_experiment_overwrite_candidate(input),
    84,
    79,
  )
}

///|
test "final table-image experiment rejects declaration loss and costs its repair" {
  let input = table_image_experiment_source(
    extra="(func (export \"reference\") (result funcref) ref.func 1)",
  )
  let naive = table_image_experiment_overwrite_candidate(input)
  ignore(@validate.validate_module(input).unwrap())
  assert_true(@validate.validate_module(naive) is Err(_))
  let elems = naive.elem_sec.unwrap().0.copy()
  elems.push(
    @lib.Elem::new(
      @lib.ElemMode::declarative(),
      @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
    ),
  )
  let repaired = naive.with_elem_sec(@lib.ElemSec::new(elems))
  table_image_experiment_check(input, repaired, 107, 105)
  let @lib.Func(_, @lib.Expr(body)) = repaired.code_sec.unwrap().0[4]
  @debug.assert_eq(body, [@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))])
}

///|
test "final table-image experiment intentionally rejects unremapped runtime segment indices" {
  // Segment deletion is unsupported when these retained operands need a remap.
  for
    extra in [
      "(func (export \"touch\") elem.drop 1)", "(func (export \"touch\") i32.const 0 i32.const 0 i32.const 0 table.init 1)",
    ] {
    let input = table_image_experiment_source(extra~)
    ignore(@validate.validate_module(input).unwrap())
    let naive = table_image_experiment_overwrite_candidate(input)
    @debug.assert_eq(
      table_image_experiment_image(naive),
      table_image_experiment_image(input),
    )
    assert_true(@validate.validate_module(naive) is Err(_))
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[4]
    assert_true(o4z_canonicalize_final_size_instrs_use_elem_indices(body))
  }
}

///|
test "final table-image experiment rejects removing a constant initialization trap" {
  let base = table_image_experiment_source()
  let merged = table_image_experiment_overwrite_candidate(base)
  let input = base.with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(2))]),
        ),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
      ),
      merged.elem_sec.unwrap().0[0],
    ]),
  )
  ignore(@validate.validate_module(input).unwrap())
  ignore(@validate.validate_module(merged).unwrap())
  @debug.assert_eq(
    table_image_experiment_image(input),
    Err("active element out of bounds"),
  )
  @debug.assert_eq(
    table_image_experiment_image(merged),
    Ok([Some(0U), Some(2U)]),
  )
  @debug.assert_eq(@binary.encode_module(input).unwrap().length(), 85)
  @debug.assert_eq(@binary.encode_module(merged).unwrap().length(), 79)
}

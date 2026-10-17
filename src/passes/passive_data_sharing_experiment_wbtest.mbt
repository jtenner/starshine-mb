///|
// Report task 39: a fixture-scoped candidate, never a production pass.
fn mp_passive_sharing_experiment(input : @lib.Module) -> @lib.Module? {
  // This experiment excludes metadata and non-code expression users. A
  // production pass needs their complete data-index inventory and remapping.
  if !input.custom_secs.is_empty() ||
    input.name_sec is Some(_) ||
    input.raw_name_sec_payload is Some(_) ||
    input.compiler_fact_custom_section is Some(_) ||
    input.func_annotation_sec is Some(_) ||
    input.import_sec is Some(_) ||
    input.global_sec is Some(_) ||
    input.table_sec is Some(_) ||
    input.elem_sec is Some(_) ||
    input.start_sec is Some(_) {
    return None
  }
  let data = match input.data_sec {
    Some(
      @lib.DataSec(
        [@lib.Data(@lib.Passive, left), @lib.Data(@lib.Passive, right)]
      )
    ) if left == right => left
    _ => return None
  }
  let funcs = match input.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return None
  }
  let rewritten : Array[@lib.Func] = []
  for func in funcs {
    let @lib.Func(locals, @lib.Expr(body)) = func
    let next : Array[@lib.Instruction] = []
    for instr in body {
      match instr {
        @lib.MemoryInit(@lib.DataIdx(raw), mem) if raw <= 1U =>
          next.push(@lib.Instruction::memory_init(@lib.DataIdx::new(0U), mem))
        @lib.LocalGet(_) | @lib.I32Const(_) | @lib.Drop | @lib.Nop =>
          next.push(instr)
        // Drop states stay independent. GC users and all structured/unknown
        // instructions are intentionally outside this fixture-scoped proof.
        _ => return None
      }
    }
    rewritten.push(@lib.Func::new(locals, @lib.Expr::new(next)))
  }
  Some(
    input
    .with_data_sec(
      @lib.DataSec::new([@lib.Data::new(@lib.DataMode::passive(), data)]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
    .with_code_sec(@lib.CodeSec::new(rewritten)),
  )
}

///|
fn mp_passive_sharing_fixture(length : Int32, with_drop : Bool) -> @lib.Module {
  let payload = "A".repeat(length)
  let dropper = if with_drop {
    "(func (export \"drop0\") data.drop 0) (func (export \"drop1\") data.drop 1)"
  } else {
    ""
  }
  pass_test_module_from_wat(
    "(module (memory (export \"memory\") 1) " +
    "(data \"\{payload}\") (data \"\{payload}\") " +
    "(func (export \"copy0\") (param i32 i32 i32) local.get 0 local.get 1 local.get 2 memory.init 0) " +
    "(func (export \"copy1\") (param i32 i32 i32) local.get 0 local.get 1 local.get 2 memory.init 1) " +
    dropper +
    ")",
  )
}

///|
// Deliberately invalid optimization: it couples two independent drop states.
// The resulting module remains well typed, so runtime evidence is required.
fn mp_passive_sharing_blind_candidate(input : @lib.Module) -> @lib.Module {
  let funcs = input.code_sec.unwrap().0.map(fn(func) {
    let @lib.Func(locals, @lib.Expr(body)) = func
    @lib.Func::new(
      locals,
      @lib.Expr::new(
        body.map(fn(instr) {
          match instr {
            @lib.MemoryInit(_, mem) =>
              @lib.Instruction::memory_init(@lib.DataIdx::new(0U), mem)
            @lib.DataDrop(_) =>
              @lib.Instruction::data_drop(@lib.DataIdx::new(0U))
            _ => instr
          }
        }),
      ),
    )
  })
  input
  .with_data_sec(@lib.DataSec::new([input.data_sec.unwrap().0[0]]))
  .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
test "passive sharing experiment admits equal read-only payloads without new runtime state" {
  for
    (length, expected_before, expected_after) in [
      (0, 94, 92),
      (1, 96, 93),
      (64, 223, 156),
      (128, 353, 222),
    ] {
    let input = mp_passive_sharing_fixture(length, false)
    @validate.validate_module(input).unwrap()
    let before = @binary.encode_module(input).unwrap()
    let output = mp_passive_sharing_experiment(input).unwrap()
    @validate.validate_module(output).unwrap()
    let after = @binary.encode_module(output).unwrap()
    assert_eq(before.length(), expected_before)
    assert_eq(after.length(), expected_after)
    assert_true(after.length() < before.length())
    assert_eq(output.data_sec.unwrap().0.length(), 1)
    assert_eq(output.data_cnt_sec, Some(@lib.DataCntSec::new(@lib.U32(1U))))
    assert_eq(output.global_sec, input.global_sec)
    let old_funcs = input.code_sec.unwrap().0
    let new_funcs = output.code_sec.unwrap().0
    for index in 0..<old_funcs.length() {
      let @lib.Func(old_locals, @lib.Expr(old_body)) = old_funcs[index]
      let @lib.Func(new_locals, @lib.Expr(new_body)) = new_funcs[index]
      assert_eq(new_locals, old_locals)
      assert_eq(new_body.length(), old_body.length())
      assert_eq(new_body[0:3].to_array(), old_body[0:3].to_array())
      assert_eq(
        new_body[3],
        @lib.Instruction::memory_init(
          @lib.DataIdx::new(0U),
          @lib.MemIdx::new(0U),
        ),
      )
    }
    assert_eq(@binary.encode_module(input).unwrap(), before)
    println(
      "passive-sharing payload=\{length} before=\{before.length()} after=\{after.length()} added_globals=0 added_locals=0 added_instructions=0",
    )
  }
}

///|
test "passive sharing experiment intentionally rejects independent data drop lifetimes" {
  let input = mp_passive_sharing_fixture(64, true)
  @validate.validate_module(input).unwrap()
  let before = @binary.encode_module(input).unwrap()
  assert_true(mp_passive_sharing_experiment(input) is None)
  let blind = mp_passive_sharing_blind_candidate(input)
  @validate.validate_module(blind).unwrap()
  // Even the invalid optimization can save bytes. Typing and size cannot
  // justify merging independently observable dropped-segment states.
  assert_true(@binary.encode_module(blind).unwrap().length() < before.length())
  assert_eq(@binary.encode_module(input).unwrap(), before)
}

///|
test "passive sharing experiment intentionally excludes GC data users from its proof" {
  let base = mp_passive_sharing_fixture(4, false)
  let @lib.TypeSec(original_types) = base.type_sec.unwrap()
  let types = original_types.copy()
  let array_type = @lib.TypeIdx::new(
    dae_type_sec_flattened_length(base.type_sec.unwrap()).to_uint(),
  )
  types.push(
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(
          @lib.FieldType::new(
            @lib.StorageType::pack_type(@lib.PackType::i8()),
            @lib.Mut::var_(),
          ),
        ),
      ),
    ),
  )
  let funcs = base.code_sec.unwrap().0.copy()
  funcs[0] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(4)),
      @lib.Instruction::array_new_data(array_type, @lib.DataIdx::new(1U)),
      @lib.Instruction::drop(),
    ]),
  )
  let input = base
    .with_type_sec(@lib.TypeSec::new(types))
    .with_code_sec(@lib.CodeSec::new(funcs))
  @validate.validate_module(input).unwrap()
  let before = @binary.encode_module(input).unwrap()
  assert_true(mp_passive_sharing_experiment(input) is None)
  assert_eq(@binary.encode_module(input).unwrap(), before)
}

///|
#skip("manual task-39 runtime artifact export; no filesystem writes in the default lane")
test "passive sharing experiment exports exact bounded runtime candidates" {
  let dir = ".tmp/report-optimization-20261016/passive-data-sharing/"
  for length in [0, 1, 64, 128] {
    let input = mp_passive_sharing_fixture(length, false)
    let candidate = mp_passive_sharing_experiment(input).unwrap()
    @validate.validate_module(input).unwrap()
    @validate.validate_module(candidate).unwrap()
    @sfs.write_file_bytes(
      dir + "read-only-\{length}.before.wasm",
      @binary.encode_module(input).unwrap(),
    ).unwrap()
    @sfs.write_file_bytes(
      dir + "read-only-\{length}.candidate.wasm",
      @binary.encode_module(candidate).unwrap(),
    ).unwrap()
  }
  let input = mp_passive_sharing_fixture(64, true)
  let blind = mp_passive_sharing_blind_candidate(input)
  @validate.validate_module(input).unwrap()
  @validate.validate_module(blind).unwrap()
  @sfs.write_file_bytes(
    dir + "drop.before.wasm",
    @binary.encode_module(input).unwrap(),
  ).unwrap()
  @sfs.write_file_bytes(
    dir + "drop.blind.wasm",
    @binary.encode_module(blind).unwrap(),
  ).unwrap()
}

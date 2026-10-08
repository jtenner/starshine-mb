///|
test "mass repair command precompute preserves a scratch value needed at exit" {
  let output = cmd_deep_audit_run(
    "(module (func (param i32) (result i32) (local i32) i32.const 7 local.set 1 local.get 0 local.get 1 i32.add local.set 0 local.get 1))",
    "precompute",
  )
  @validate.validate_module(decode_module_bytes(encode_module_bytes(output))).unwrap()
  let body = cmd_deep_audit_body(output)
  match body.last() {
    Some(@lib.I32Const(@lib.I32(value))) => assert_eq(value, 7)
    Some(@lib.LocalGet(target)) =>
      assert_true(
        cmd_deep_audit_count(body, fn(instr) {
          match instr {
            @lib.LocalSet(local) | @lib.LocalTee(local) => local == target
            _ => false
          }
        }) >
        0,
      )
    _ => abort("expected retained scratch read or its constant value")
  }
}

///|
test "mass repair command precompute folds valid fractional truncations" {
  for pass in ["precompute", "precompute-propagate"] {
    let output = cmd_deep_audit_run(
      "(module (func (result i32) f64.const -0.5 i32.trunc_f64_u))", pass,
    )
    assert_eq(cmd_deep_audit_body(output), [
      @lib.Instruction::i32_const(@lib.I32(0)),
    ])
    @validate.validate_module(output).unwrap()
  }
}

///|
test "mass repair command optimizing DAE retains a legacy parameter write" {
  let seed = @wast.wast_to_binary_module(
    "(module (tag) (func $f (param i32) (result i32) (local i32) i32.const 0) (func (export \"run\") (result i32) i32.const 5 call $f))",
  ).unwrap()
  let get = @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
  let funcs = seed.code_sec.unwrap().0.copy()
  funcs[0] = @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::i32()]),
    @lib.Expr::new([
      @lib.Instruction::try_(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          get,
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        ]),
        [@lib.LegacyCatch::all(@lib.Expr::new([@lib.Instruction::nop()]))],
      ),
      get,
    ]),
  )
  let input = seed.with_code_sec(@lib.CodeSec::new(funcs))
  @validate.validate_module(input).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["dae-optimizing"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(6)),
  ])
  @validate.validate_module(decode_module_bytes(encode_module_bytes(output))).unwrap()
}

///|
test "mass repair command SGO folds an ordinary sibling of legacy control" {
  let output = cmd_deep_audit_run(
    "(module (global $g i32 (i32.const 7)) (func (try (do nop) (catch_all nop))) (func (result i32) global.get $g))",
    "simplify-globals-optimizing",
  )
  assert_eq(cmd_deep_audit_body(output, index=1), [
    @lib.Instruction::i32_const(@lib.I32(7)),
  ])
  @validate.validate_module(output).unwrap()
}

///|
test "mass repair command LocalCSE covers a seventeen instruction region" {
  let output = cmd_deep_audit_run(
    "(module (func (param i32) (result i32) nop nop local.get 0 i32.const 3 i32.add local.get 0 i32.const 2 i32.sub i32.mul local.get 0 i32.const 3 i32.add local.get 0 i32.const 2 i32.sub i32.mul i32.mul))",
    "local-cse",
  )
  let body = cmd_deep_audit_body(output)
  assert_eq(cmd_deep_audit_count(body, fn(instr) { instr is @lib.I32Add }), 1)
  assert_eq(cmd_deep_audit_count(body, fn(instr) { instr is @lib.I32Sub }), 1)
  @validate.validate_module(decode_module_bytes(encode_module_bytes(output))).unwrap()
}

///|
test "mass repair command LocalCSE leaf roots retain profitable availability" {
  let words : Array[String] = []
  for value in 0..<65 {
    words.push("i32.const \{value} drop")
  }
  for write_local in [false, true] {
    let write = if write_local { "i32.const 1 local.set 0" } else { "" }
    let output = cmd_deep_audit_run(
      "(module (func (param i32) (result i32) local.get 0 i32.const 7 i32.add local.get 0 i32.const 3 i32.sub i32.mul drop \{words.join(" " )} \{write} local.get 0 i32.const 7 i32.add local.get 0 i32.const 3 i32.sub i32.mul))",
      "local-cse",
    )
    assert_eq(
      cmd_deep_audit_count(cmd_deep_audit_body(output), fn(instr) {
        instr is @lib.I32Mul
      }),
      if write_local {
        2
      } else {
        1
      },
    )
    @validate.validate_module(decode_module_bytes(encode_module_bytes(output))).unwrap()
  }
}

///|
test "mass repair command DAE2 singleton pruning reduces encoded bytes" {
  let input = @wast.wast_to_binary_module(
    "(module (type $A (func (param i32))) (table 1 funcref) (func $a (type $A)) (elem (i32.const 0) func $a) (func (export \"run\") i32.const 9 call $a))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let saved = encode_module_bytes(input.without_name_sec())
  for pass_name in ["dae2", "dae2-optimizing"] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass_name],
      OptimizeOptions::new(closed_world=true),
    ).unwrap()
    let encoded = encode_module_bytes(output.without_name_sec())
    assert_true(
      if pass_name == "dae2" {
        encoded.length() < saved.length()
      } else {
        encoded.length() <= saved.length()
      },
    )
    @validate.validate_module(decode_module_bytes(encoded)).unwrap()
  }
  assert_eq(encode_module_bytes(input.without_name_sec()), saved)
}

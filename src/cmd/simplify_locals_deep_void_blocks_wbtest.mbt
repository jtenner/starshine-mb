///|
fn simplify_locals_deep_void_blocks_module(depth : Int32) -> @lib.Module {
  let mut body = @lib.Expr::new([
    @lib.Instruction::i32_const(7),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(42),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ])
  for _ in 0..<depth {
    body = @lib.Expr::new([
      @lib.Instruction::block(@lib.BlockType::void_(), body),
    ])
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(0)]),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::from_types([@lib.ValType::i32()]), body),
    ]),
  )
}

///|
fn simplify_locals_deep_void_blocks_with_root_terminator_module(
  depth : Int32,
) -> @lib.Module {
  let module_ = simplify_locals_deep_void_blocks_module(depth)
  let (locals, body) = match module_.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, @lib.Expr(body))])) => (locals, body)
    _ => abort("expected one defined function")
  }
  let next_body = body.copy()
  next_body.push(@lib.Instruction::unreachable_())
  module_.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(next_body))]),
  )
}

///|
fn simplify_locals_deep_void_blocks_count_global_sets(
  module_ : @lib.Module,
) -> Int32 {
  let pending : Array[Array[@lib.Instruction]] = []
  let root = match module_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(root))])) => root
    _ => abort("expected one defined function")
  }
  pending.push(root)
  let mut count = 0
  while !pending.is_empty() {
    let body = pending.pop().unwrap()
    for index = 0; index < body.length(); index = index + 1 {
      match body[index] {
        @lib.GlobalSet(@lib.GlobalIdx(0U)) => {
          if index == 0 ||
            body[index - 1] != @lib.Instruction::i32_const(@lib.I32(42)) {
            return -1
          }
          count += 1
        }
        @lib.Block(_, @lib.Expr(nested)) => pending.push(nested)
        _ => ()
      }
    }
  }
  count
}

///|
fn simplify_locals_deep_void_blocks_count_local_traffic(
  module_ : @lib.Module,
) -> Int32 {
  let pending : Array[Array[@lib.Instruction]] = []
  let root = match module_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(root))])) => root
    _ => abort("expected one defined function")
  }
  pending.push(root)
  let mut count = 0
  while !pending.is_empty() {
    let body = pending.pop().unwrap()
    for instr in body {
      match instr {
        @lib.LocalGet(@lib.LocalIdx(0U))
        | @lib.LocalSet(@lib.LocalIdx(0U))
        | @lib.LocalTee(@lib.LocalIdx(0U)) => count += 1
        @lib.Block(_, @lib.Expr(nested)) => pending.push(nested)
        _ => ()
      }
    }
  }
  count
}

///|
test "command simplify-locals handles 128 nested observable void blocks" {
  let input = simplify_locals_deep_void_blocks_module(128)
  assert_true(@validate.validate_module(input) is Ok(_))
  for pass in ["simplify-locals", "simplify-locals-nostructure"] {
    let output = cmd_deep_audit_run_module(input, pass)
    assert_true(@validate.validate_module(output) is Ok(_), msg=pass)
    assert_eq(simplify_locals_deep_void_blocks_count_global_sets(output), 1)
    assert_eq(simplify_locals_deep_void_blocks_count_local_traffic(output), 0)
    let roundtrip = decode_module_bytes(encode_module_bytes(output))
    assert_true(@validate.validate_module(roundtrip) is Ok(_), msg=pass)
    assert_eq(simplify_locals_deep_void_blocks_count_global_sets(roundtrip), 1)
    assert_eq(
      simplify_locals_deep_void_blocks_count_local_traffic(roundtrip),
      0,
    )
  }
}

///|
test "CLI simplify-locals encodes 128 nested observable void blocks" {
  let input = simplify_locals_deep_void_blocks_module(128)
  let input_bytes = @binary.encode_module(input).unwrap()
  for pass in ["simplify-locals", "simplify-locals-nostructure"] {
    let writes : Array[Bytes] = []
    let io = CmdIO::new(
      list_candidates=fn() { ["input.wasm"] },
      file_exists=fn(path) { path == "input.wasm" },
      read_file=fn(_) { Ok(input_bytes) },
      write_file=fn(_, bytes) {
        writes.push(bytes)
        Ok(())
      },
    )
    ignore(
      run_cmd_with_adapter(["--\{pass}", "--out", "out.wasm", "input.wasm"], io).unwrap(),
    )
    assert_eq(writes.length(), 1)
    let output = @binary.decode_module(writes[0]).unwrap()
    assert_true(@validate.validate_module(output) is Ok(_), msg=pass)
    assert_eq(simplify_locals_deep_void_blocks_count_global_sets(output), 1)
    assert_eq(simplify_locals_deep_void_blocks_count_local_traffic(output), 0)
  }
}

///|
test "command simplify-locals handles a deep rewrite before a root terminator" {
  let input = simplify_locals_deep_void_blocks_with_root_terminator_module(128)
  assert_true(@validate.validate_module(input) is Ok(_))
  for pass in ["simplify-locals", "simplify-locals-nostructure"] {
    let output = cmd_deep_audit_run_module(input, pass)
    assert_true(@validate.validate_module(output) is Ok(_), msg=pass)
    assert_eq(simplify_locals_deep_void_blocks_count_global_sets(output), 1)
    assert_eq(simplify_locals_deep_void_blocks_count_local_traffic(output), 0)
  }
}

///|
fn ocr_run(
  source : String,
  pass : String,
  options~ : HotPipelineOptions = HotPipelineOptions::new(),
) -> @lib.Module raise {
  match pass_test_run_pipeline(source, [pass], options~) {
    Ok(mod_) => mod_
    Err(err) => fail("expected \{pass} pipeline success, got \{err}")
  }
}

///|
fn ocr_func(mod_ : @lib.Module, idx : Int32) -> @lib.Func raise {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) if idx >= 0 && idx < funcs.length() => funcs[idx]
    _ => fail("expected defined function \{idx}")
  }
}

///|
fn ocr_instr_contains_loop(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Loop(_, _) => true
    @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
      ocr_instrs_contain_loop(body)
    @lib.If(_, then_body, else_body) =>
      ocr_instrs_contain_loop(then_body) ||
      (match else_body {
        Some(body) => ocr_instrs_contain_loop(body)
        None => false
      })
    _ => false
  }
}

///|
fn ocr_instrs_contain_loop(instrs : Array[@lib.Instruction]) -> Bool {
  instrs.any(ocr_instr_contains_loop)
}

///|
fn ocr_count_blocks(instrs : Array[@lib.Instruction]) -> Int32 {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body)) => {
        count += 1
        count += ocr_count_blocks(body)
      }
      @lib.Loop(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        count += ocr_count_blocks(body)
      @lib.If(_, then_body, else_body) => {
        count += ocr_count_blocks(then_body)
        match else_body {
          Some(body) => count += ocr_count_blocks(body)
          None => ()
        }
      }
      _ => ()
    }
  }
  count
}

///|
fn ocr_instrs_contain_local_tee(
  instrs : Array[@lib.Instruction],
  expected : UInt32,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.LocalTee(@lib.LocalIdx(raw)) if raw == expected => return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ocr_instrs_contain_local_tee(body, expected) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ocr_instrs_contain_local_tee(then_body, expected) {
          return true
        }
        match else_body {
          Some(body) =>
            if ocr_instrs_contain_local_tee(body, expected) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ocr_instrs_have_set_before_br_if(
  instrs : Array[@lib.Instruction],
  expected : UInt32,
) -> Bool {
  let mut saw_set = false
  for instr in instrs {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) if raw ==
        expected => saw_set = true
      @lib.BrIf(_) if saw_set => return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ocr_instrs_have_set_before_br_if(body, expected) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ocr_instrs_have_set_before_br_if(then_body, expected) {
          return true
        }
        match else_body {
          Some(body) =>
            if ocr_instrs_have_set_before_br_if(body, expected) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ocr_call_has_prior_br_if(instrs : Array[@lib.Instruction]) -> Bool {
  let mut saw_br_if = false
  for instr in instrs {
    match instr {
      @lib.BrIf(_) => saw_br_if = true
      @lib.Call(_) if saw_br_if => return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ocr_call_has_prior_br_if(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ocr_call_has_prior_br_if(then_body) {
          return true
        }
        match else_body {
          Some(body) => if ocr_call_has_prior_br_if(body) { return true }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ocr_instrs_contain_global_get(
  instrs : Array[@lib.Instruction],
  expected : UInt32,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.GlobalGet(@lib.GlobalIdx(raw)) if raw == expected => return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ocr_instrs_contain_global_get(body, expected) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ocr_instrs_contain_global_get(then_body, expected) {
          return true
        }
        match else_body {
          Some(body) =>
            if ocr_instrs_contain_global_get(body, expected) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ocr_instrs_contain_i32_const(
  instrs : Array[@lib.Instruction],
  expected : Int32,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.I32Const(@lib.I32(value)) if value == expected => return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ocr_instrs_contain_i32_const(body, expected) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ocr_instrs_contain_i32_const(then_body, expected) {
          return true
        }
        match else_body {
          Some(body) =>
            if ocr_instrs_contain_i32_const(body, expected) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
test "DAE preserves a nonterminating loop before unreachable" {
  let optimized = ocr_run(
    (
      #|(module
      #|  (func $f (result i32) (loop $again br $again) unreachable)
      #|  (func (export "run") call $f drop))
    ),
    "dae",
  )
  let @lib.Func(_, @lib.Expr(body)) = ocr_func(optimized, 0)
  assert_true(
    ocr_instrs_contain_loop(body),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
  )
}

///|
test "code-pushing does not move an unreachable suffix call into execution" {
  let optimized = ocr_run(
    (
      #|(module
      #|  (import "env" "effect" (func $effect))
      #|  (func (export "f") (block unreachable call $effect) unreachable))
    ),
    "code-pushing",
  )
  let @lib.Func(_, @lib.Expr(body)) = ocr_func(optimized, 0)
  assert_false(
    body is [@lib.Call(_), ..],
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "remove-unused-brs does not speculate a ref.is_null call condition" {
  let optimized = ocr_run(
    (
      #|(module
      #|  (import "env" "effect" (func $effect (result funcref)))
      #|  (func (export "f") (param i32)
      #|    block
      #|      local.get 0 br_if 0
      #|      call $effect ref.is_null br_if 0
      #|      nop
      #|    end))
    ),
    "remove-unused-brs",
    options=HotPipelineOptions::new(optimize_level=4, shrink_level=1),
  )
  let @lib.Func(_, @lib.Expr(body)) = ocr_func(optimized, 0)
  assert_true(
    ocr_call_has_prior_br_if(body),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "vacuum keeps a block that can branch around a terminal return" {
  let optimized = ocr_run(
    (
      #|(module (func (export "run") (param i32)
      #|  nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|  block local.get 0 br_if 0 return end
      #|  unreachable))
    ),
    "vacuum",
    options=HotPipelineOptions::new(optimize_level=4, shrink_level=1),
  )
  let @lib.Func(_, @lib.Expr(body)) = ocr_func(optimized, 0)
  assert_true(
    ocr_count_blocks(body) >= 1,
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
  )
}

///|
test "vacuum keeps a child block with an earlier self branch" {
  let optimized = ocr_run(
    (
      #|(module (func (export "run") (param i32) (result i32)
      #|  nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|  block $parent
      #|    block $child
      #|      local.get 0 br_if $child
      #|      i32.const 0 br_table $parent
      #|    end
      #|    unreachable
      #|  end
      #|  i32.const 7))
    ),
    "vacuum",
  )
  let @lib.Func(_, @lib.Expr(body)) = ocr_func(optimized, 0)
  assert_true(
    ocr_count_blocks(body) >= 2,
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
  )
}

///|
test "coalesce-locals accounts for try_table catch exits" {
  let optimized = ocr_run(
    (
      #|(module
      #|  (tag $e)
      #|  (func (export "run") (result i32) (local i32 i32)
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 1 local.tee 0 drop
      #|    i32.const 2 local.set 1
      #|    block $exit
      #|      try_table (catch_all $exit) throw $e end
      #|    end
      #|    local.get 0))
    ),
    "coalesce-locals",
  )
  let @lib.Func(locals, _) = ocr_func(optimized, 0)
  @debug.assert_eq(locals.length(), 2)
}

///|
test "dead-code-elimination treats br 0 in try_table as fallthrough" {
  let optimized = ocr_run(
    (
      #|(module (func (export "f") (result i32)
      #|  try_table i32.const 0 drop br 0 end
      #|  i32.const 7))
    ),
    "dead-code-elimination",
  )
  let @lib.Func(_, @lib.Expr(body)) = ocr_func(optimized, 0)
  assert_true(
    body is [_, @lib.I32Const(@lib.I32(7))],
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
  )
}

///|
test "heap-store-optimization preserves a nonterminating constructor operand" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::ref_null(@lib.HeapType::new(struct_idx)),
          ]),
          @lib.Expr::new([
            @lib.Instruction::loop_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
            ),
            @lib.Instruction::struct_new(struct_idx),
            @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_as_non_null(),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::struct_set(struct_idx, @lib.U32(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_as_non_null(),
            @lib.Instruction::struct_get(struct_idx, @lib.U32(0U)),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("expected valid HSO loop fixture, got \{err}")
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), [
      "heap-store-optimization",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected HSO pipeline success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(body)) = ocr_func(optimized, 0)
  assert_true(
    ocr_instrs_contain_loop(body),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
  )
}

///|
test "simplify-locals keeps a write read by a br_if condition" {
  let optimized = ocr_run(
    (
      #|(module (func (export "run") (result i32) (local i32)
      #|  block
      #|    i32.const 7 local.set 0
      #|    local.get 0 br_if 0
      #|    i32.const 9 local.set 0
      #|  end
      #|  local.get 0))
    ),
    "simplify-locals",
  )
  let @lib.Func(_, @lib.Expr(body)) = ocr_func(optimized, 0)
  assert_true(
    ocr_instrs_have_set_before_br_if(body, 0U),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
  )
}

///|
test "ssa-nomerge keeps loop-carried local reads" {
  let optimized = ocr_run(
    (
      #|(module (func (export "f") (param $trap i32) (param $n i32) (result i32)
      #|  (local $a i32)
      #|  local.get $trap
      #|  if
      #|    try_table (catch_all 0) ref.null noexn throw_ref end
      #|  end
      #|  loop
      #|    local.get $a i32.const 1 i32.add local.set $a
      #|    local.get $n i32.const 1 i32.sub local.tee $n br_if 0
      #|  end
      #|  local.get $a))
    ),
    "ssa-nomerge",
  )
  let @lib.Func(_, @lib.Expr(body)) = ocr_func(optimized, 0)
  let mut preserved = false
  for instr in body {
    match instr {
      @lib.Loop(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(2U)), ..])) =>
        preserved = true
      _ => ()
    }
  }
  assert_true(preserved, msg=optimized.pretty_print_func(@lib.FuncIdx::new(0U)))
}

///|
test "tuple-optimization preserves payload local.tee writes" {
  let optimized = ocr_run(
    (
      #|(module
      #|  (type $pair (func (result i32 i64)))
      #|  (func (export "run") (result i32) (local i32 i64 i32 i64 i32)
      #|    block (type $pair) i32.const 7 i64.const 9 end
      #|    local.set 1 local.set 0
      #|    block (type $pair) local.get 0 local.tee 4 local.get 1 end
      #|    local.set 3 local.set 2
      #|    local.get 2 drop local.get 3 drop local.get 4))
    ),
    "tuple-optimization",
  )
  let @lib.Func(_, @lib.Expr(body)) = ocr_func(optimized, 0)
  assert_true(
    ocr_instrs_contain_local_tee(body, 4U),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
  )
}

///|
test "inlining does not create an uninitialized nondefaultable tail-call local" {
  let source =
    #|(module
    #|  (type $s (struct))
    #|  (type $leaf_t (func (param (ref $s)) (result i32)))
    #|  (import "env" "leaf" (func $leaf (type $leaf_t)))
    #|  (func $tail (type $leaf_t) (param (ref $s)) (result i32)
    #|    try_table (result i32) local.get 0 return_call $leaf end)
    #|  (func (export "run") (type $leaf_t) (param (ref $s)) (result i32)
    #|    local.get 0 call $tail i32.const 1 i32.add))
  match pass_test_run_pipeline(source, ["inlining"]) {
    Ok(mod_) =>
      match @validate.validate_module(mod_) {
        Ok(_) => ()
        Err(err) => fail("expected valid inlining output, got \{err}")
      }
    Err(err) => fail("expected inlining to avoid invalid hoisting, got \{err}")
  }
}

///|
test "remove-unused-module-elements preserves active element table slots" {
  let optimized = ocr_run(
    (
      #|(module
      #|  (type $ti64 (func (result i64)))
      #|  (type $ti32 (func (result i32)))
      #|  (table 3 funcref)
      #|  (elem (i32.const 0) func $a $unused $b)
      #|  (func $a (type $ti64) (result i64) i64.const 11)
      #|  (func $unused (type $ti64) (result i64) i64.const 22)
      #|  (func $b (type $ti32) (result i32) i32.const 42)
      #|  (func (export "run") (type $ti32) (result i32)
      #|    ref.func $a drop i32.const 2 call_indirect (type $ti32)))
    ),
    "remove-unused-module-elements",
    options=HotPipelineOptions::new(closed_world=true),
  )
  assert_true(
    optimized.elem_sec
    is Some(@lib.ElemSec([@lib.Elem(_, @lib.FuncsElemKind([_, _, _]))])),
    msg="active element segment lost a table slot",
  )
}

///|
test "remove-unused-module-elements promotes late element ref.func call targets" {
  let input = match
    @binary.decode_module(
      Bytes::from_array([
        0, 97, 115, 109, 1, 0, 0, 0, 1, 12, 3, 96, 0, 1, 127, 94, 100, 0, 1, 96,
        0, 0, 3, 4, 3, 0, 2, 0, 6, 7, 1, 99, 1, 1, 208, 1, 11, 7, 18, 2, 6, 114,
        101, 97, 100, 101, 114, 0, 0, 5, 109, 97, 107, 101, 114, 0, 1, 9, 8, 1, 5,
        100, 0, 1, 210, 2, 11, 10, 32, 3, 12, 0, 35, 0, 212, 65, 0, 251, 11, 1, 20,
        0, 11, 12, 0, 65, 0, 65, 1, 251, 10, 1, 0, 36, 0, 11, 4, 0, 65, 42, 11, 0,
        32, 4, 110, 97, 109, 101, 1, 4, 1, 2, 1, 102, 4, 7, 2, 0, 1, 70, 1, 1, 65,
        7, 4, 1, 0, 1, 103, 8, 4, 1, 0, 1, 101,
      ]),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected late elem fixture decode, got \{err}")
  }
  assert_true(@validate.validate_module(input) is Ok(_))
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=true), [
      "remove-unused-module-elements",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected RUME pipeline success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(body)) = ocr_func(optimized, 2)
  assert_false(
    body is [@lib.Unreachable],
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
}

///|
test "dae2 keeps a signature exposed through an exported funcref global" {
  let optimized = ocr_run(
    (
      #|(module
      #|  (type $sig (func (param i32) (result i32)))
      #|  (global (export "callback") funcref ref.func $f)
      #|  (func $f (type $sig) (param i32) (result i32) local.get 0))
    ),
    "dae2",
    options=HotPipelineOptions::new(closed_world=true),
  )
  let env = @validate.Env::new().with_module(optimized)
  @debug.assert_eq(
    env.get_functype_by_funcidx(@lib.FuncIdx::new(0U)),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
}

///|
test "global-struct-inference does not merge equivalent nominal type slots" {
  let optimized = ocr_run(
    (
      #|(module
      #|  (type $a (struct (field i32)))
      #|  (type $b (struct (field i32)))
      #|  (global $ga (ref $a) i32.const 7 struct.new $a)
      #|  (global $gb (ref $b) i32.const 9 struct.new $b)
      #|  (func $read (param (ref $a)) (result i32)
      #|    local.get 0 struct.get $a 0)
      #|  (func (export "run") (result i32) global.get $gb call $read))
    ),
    "global-struct-inference",
    options=HotPipelineOptions::new(closed_world=true),
  )
  let @lib.Func(_, @lib.Expr(body)) = ocr_func(optimized, 0)
  assert_true(
    body is [@lib.LocalGet(@lib.LocalIdx(0U)), @lib.StructGet(_, _)] ||
    ocr_instrs_contain_global_get(body, 1U) ||
    ocr_instrs_contain_i32_const(body, 9),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
  )
}

///|
test "simplify-globals-optimizing rejects a nonlocal br_if guard" {
  let optimized = ocr_run(
    (
      #|(module
      #|  (global $g (mut i32) i32.const 0)
      #|  (func (export "run") (param i32) (result i32)
      #|    block
      #|      block (result i32)
      #|        global.get $g local.get 0 br_if 1 drop i32.const 1
      #|      end
      #|      if i32.const 9 global.set $g end
      #|    end
      #|    i32.const 7))
    ),
    "simplify-globals-optimizing",
  )
  assert_true(
    optimized.global_sec
    is Some(@lib.GlobalSec([@lib.Global(@lib.GlobalType(_, true), _)])),
    msg="nonlocal branch caused a mutable global to be frozen",
  )
}

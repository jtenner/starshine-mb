///|
test "code-folding shares calls while preserving scoped reference initialization" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #| (type $S (struct (field i32)))
      #| (func $read (param (ref $S)) (result i32)
      #|   local.get 0 struct.get $S 0)
      #| (func (export "run") (param i32) (result i32) (local (ref $S) i32)
      #|   local.get 0
      #|   if
      #|     i32.const 7 struct.new $S local.set 1
      #|     local.get 1 call $read local.set 2
      #|   else
      #|     i32.const 9 struct.new $S local.set 1
      #|     local.get 1 call $read local.set 2
      #|   end
      #|   local.get 2)
      #| (func (export "main")
      #|   i32.const 0 call 1 i32.const 9 i32.ne if unreachable end
      #|   i32.const 1 call 1 i32.const 7 i32.ne if unreachable end))
    ),
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "code-folding",
  ]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  @debug.assert_eq(
    locals[0],
    @lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let mut calls = 0
  let mut checked_reads = 0
  for index, instr in body {
    match instr {
      @lib.Call(_) => calls += 1
      @lib.RefAsNonNull => {
        assert_true(index > 0 && body[index - 1] is @lib.LocalGet(_))
        checked_reads += 1
      }
      _ => ()
    }
  }
  @debug.assert_eq(calls, 1)
  @debug.assert_eq(checked_reads, 1)
  ignore(@validate.validate_module(output).unwrap())
}

///|
test "code-folding keeps enclosing reference initialization without null checks" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #| (type $S (struct (field i32)))
      #| (func $read (param (ref $S)) (result i32)
      #|   local.get 0 struct.get $S 0)
      #| (func (param i32) (result i32) (local (ref $S) i32)
      #|   i32.const 11 struct.new $S local.set 1
      #|   local.get 0
      #|   if
      #|     i32.const 7 drop
      #|     local.get 1 call $read local.set 2
      #|   else
      #|     i32.const 9 drop
      #|     local.get 1 call $read local.set 2
      #|   end
      #|   local.get 2))
    ),
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "code-folding",
  ]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  let @lib.Func(original_locals, _) = input.code_sec.unwrap().0[1]
  @debug.assert_eq(locals[0], original_locals[0])
  let mut calls = 0
  for instr in body {
    match instr {
      @lib.Call(_) => calls += 1
      @lib.RefAsNonNull =>
        fail("enclosing initialization must not add a null check")
      _ => ()
    }
  }
  @debug.assert_eq(calls, 1)
}

///|
test "code-folding restores the result type of tees to weakened reference locals" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #| (type $S (struct (field i32)))
      #| (func $read (param (ref $S)) (result i32)
      #|   local.get 0 struct.get $S 0)
      #| (func (export "run") (param i32) (result i32) (local (ref $S) i32)
      #|   local.get 0
      #|   if
      #|     i32.const 7 struct.new $S local.set 1
      #|     local.get 1 call $read local.set 2
      #|   else
      #|     i32.const 9 struct.new $S local.set 1
      #|     local.get 1 call $read local.set 2
      #|   end
      #|   i32.const 23 struct.new $S local.tee 1 call $read drop
      #|   local.get 2)
      #| (func (export "main")
      #|   i32.const 0 call 1 i32.const 9 i32.ne if unreachable end
      #|   i32.const 1 call 1 i32.const 7 i32.ne if unreachable end))
    ),
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "code-folding",
  ]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  let mut checked_tees = 0
  let mut calls = 0
  for index, instr in body {
    match instr {
      @lib.Call(_) => calls += 1
      @lib.RefAsNonNull if index > 0 && body[index - 1] is @lib.LocalTee(_) =>
        checked_tees += 1
      _ => ()
    }
  }
  @debug.assert_eq(calls, 2)
  @debug.assert_eq(checked_tees, 1)
  ignore(@validate.validate_module(output).unwrap())
}

///|
fn or_test_defined_func_instrs(
  mod_ : @lib.Module,
  defined_idx : Int,
) -> Array[@lib.Instruction] raise {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(defined_idx) {
        Some(@lib.Func(_, @lib.Expr(instrs))) => instrs
        None => fail("expected defined function \{defined_idx}")
      }
    None => fail("expected code section")
  }
}

///|
test "run_hot_pipeline applies once-reduction to repeated once calls" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func $once
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g)
    #|   (func (export "run")
    #|     call $once
    #|     call $once))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected once-reduction pipeline success, got \{err}")
  }

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::nop(),
  ])
}

///|
test "once-reduction keeps globals that are externally visible" {
  let wat =
    #| (module
    #|   (global $g (export "g") (mut i32) (i32.const 0))
    #|   (func $once
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g)
    #|   (func (export "run")
    #|     call $once
    #|     call $once))
    #|
  let input = pass_test_module_from_wat(wat)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected exported-global once-reduction success, got \{err}")
  }

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
}

///|
test "once-reduction collapses trivial once bodies after call optimization" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func (export "run")
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected once body reduction success, got \{err}")
  }

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 0), [
    @lib.Instruction::nop(),
  ])
}

///|
test "once-reduction tracks multiple independent once globals" {
  let input =
    #| (module
    #|   (global $g0 (mut i32) (i32.const 0))
    #|   (global $g1 (mut i32) (i32.const 0))
    #|   (func $once0
    #|     global.get $g0
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g0)
    #|   (func $once1
    #|     global.get $g1
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g1)
    #|   (func (export "run")
    #|     call $once0
    #|     call $once1
    #|     call $once0
    #|     call $once1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected multi-once reduction success, got \{err}")
  }

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 2), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::nop(),
    @lib.Instruction::nop(),
  ])
}

///|
test "once-reduction recognizes once prologue inside a top-level block" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func $once
    #|     block
    #|       global.get $g
    #|       if
    #|         return
    #|       end
    #|       i32.const 1
    #|       global.set $g
    #|     end)
    #|   (func (export "run")
    #|     call $once
    #|     call $once))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected block once-reduction success, got \{err}")
  }

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::nop(),
  ])
}

///|
test "once-reduction removes repeated no-arg binaryen idempotent calls" {
  let input =
    #| (module
    #|   (@binaryen.idempotent)
    #|   (func $idempotent)
    #|   (func (export "run")
    #|     call $idempotent
    #|     call $idempotent))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected idempotent once-reduction success, got \{err}")
  }

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::nop(),
  ])
}

///|
test "once-reduction collapses empty block-root once bodies" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func (export "run")
    #|     block
    #|       global.get $g
    #|       if
    #|         return
    #|       end
    #|       i32.const 1
    #|       global.set $g
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected block body once-reduction success, got \{err}")
  }

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 0), [
    @lib.Instruction::nop(),
  ])
}

///|
test "once-reduction treats binaryen idempotent annotations as fake once roots" {
  let input =
    #| (module
    #|   (@binaryen.idempotent)
    #|   (func $idempotent)
    #|   (func $caller
    #|     call $idempotent)
    #|   (func (export "run")
    #|     call $caller
    #|     call $idempotent))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected idempotent once-reduction success, got \{err}")
  }

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 2), [
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::nop(),
  ])
}

///|
test "once-reduction ignores idempotent annotations on typed functions" {
  let input =
    #| (module
    #|   (@binaryen.idempotent)
    #|   (func $idempotent (param i32) (result i32)
    #|     local.get 0)
    #|   (func (export "run") (result i32)
    #|     i32.const 10
    #|     call $idempotent
    #|     i32.const 20
    #|     call $idempotent
    #|     i32.add))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected typed-idempotent once-reduction success, got \{err}")
  }

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::i32_const(@lib.I32::new(10)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(20)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_add(),
  ])
}

///|
test "once-reduction keeps unannotated imported calls" {
  let input =
    #| (module
    #|   (import "env" "imp" (func $imp))
    #|   (func (export "run")
    #|     call $imp
    #|     call $imp))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected imported-call once-reduction success, got \{err}")
  }

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 0), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
}

///|
test "once-reduction treats idempotent imported calls as fake roots" {
  let input =
    #| (module
    #|   (@binaryen.idempotent)
    #|   (import "env" "imp" (func $imp))
    #|   (func (export "run")
    #|     call $imp
    #|     call $imp))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected idempotent-import once-reduction success, got \{err}")
  }

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 0), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::nop(),
  ])
}

///|
test "once-reduction keeps imported once globals as boundary roots" {
  let input =
    #| (module
    #|   (import "env" "g" (global $g (mut i32)))
    #|   (func $once
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g)
    #|   (func (export "run")
    #|     call $once
    #|     call $once))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected imported-global once-reduction success, got \{err}")
  }

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
}

///|
test "once-reduction rejects extra once-global reads" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func $once
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g)
    #|   (func $read (result i32)
    #|     global.get $g)
    #|   (func (export "run")
    #|     call $once
    #|     call $once
    #|     call $read
    #|     drop))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected extra-read once-reduction success, got \{err}")
  }

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 2), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
}

///|
test "once-reduction keeps direct repeats when the once target also escapes" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (table 1 funcref)
    #|   (elem (i32.const 0) $once)
    #|   (func $once
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g)
    #|   (func (export "run")
    #|     ref.func $once
    #|     drop
    #|     call $once
    #|     call $once))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected escaped-target once-reduction success, got \{err}")
  }

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::nop(),
  ])
}

///|
fn or_test_run_once_reduction(text : String) -> @lib.Module raise {
  match pass_test_run_pipeline(text, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected once-reduction pipeline success, got \{err}")
  }
}

///|
test "once-reduction treats imported idempotent no-arg calls as fake once roots" {
  let input =
    #| (module
    #|   (@binaryen.idempotent)
    #|   (import "env" "imp" (func $imp))
    #|   (func (export "run")
    #|     call $imp
    #|     call $imp))
    #|
  let optimized = try! or_test_run_once_reduction(input)

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 0), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::nop(),
  ])
}

///|
test "once-reduction strips explicit wrapper guard before idempotent payload" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (@binaryen.idempotent)
    #|   (func $idempotent)
    #|   (func $once
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g
    #|     call $idempotent)
    #|   (func (export "run")
    #|     call $once
    #|     call $once))
    #|
  let optimized = try! or_test_run_once_reduction(input)

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::nop(),
    @lib.Instruction::nop(),
    @lib.Instruction::nop(),
    @lib.Instruction::nop(),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
}

///|
test "once-reduction rejects negative i32 once writes like Binaryen" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func $once
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const -1
    #|     global.set $g)
    #|   (func (export "run")
    #|     call $once
    #|     call $once))
    #|
  let optimized = try! or_test_run_once_reduction(input)

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
}

///|
test "once-reduction keeps first post-if call after two-arm merge" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func $once
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g)
    #|   (func (export "run")
    #|     i32.const 1
    #|     if
    #|       call $once
    #|     else
    #|       call $once
    #|     end
    #|     call $once
    #|     call $once))
    #|
  let optimized = try! or_test_run_once_reduction(input)

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::call(@lib.FuncIdx::new(0U))],
      Some([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
    ),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::nop(),
  ])
}

///|
test "once-reduction honors unreachable branch exits before learning once facts" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func $once
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g)
    #|   (func (export "run")
    #|     block $exit
    #|       br $exit
    #|       call $once
    #|     end
    #|     call $once
    #|     call $once))
    #|
  let optimized = try! or_test_run_once_reduction(input)

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::nop(),
  ])
}

///|
test "once-reduction applies Binaryen loop-local dominance without leaking loop facts" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func $once
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g)
    #|   (func (export "run")
    #|     loop $loop
    #|       i32.const 1
    #|       if
    #|         call $once
    #|       end
    #|       call $once
    #|       i32.const 1
    #|       br_if $loop
    #|     end
    #|     call $once
    #|     call $once))
    #|
  let optimized = try! or_test_run_once_reduction(input)

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32::new(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::call(@lib.FuncIdx::new(0U))],
          None,
        ),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32::new(1)),
        @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::nop(),
    @lib.Instruction::nop(),
  ])
}

///|
test "once-reduction optimizes repeated once calls inside try_table and after nonthrowing try" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func $once
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g)
    #|   (func (export "run")
    #|     block $exit
    #|       try_table (catch_all $exit)
    #|         call $once
    #|         call $once
    #|       end
    #|     end
    #|     call $once
    #|     call $once))
    #|
  let optimized = try! or_test_run_once_reduction(input)

  match (try! or_test_defined_func_instrs(optimized, 1)) {
    [
      @lib.Block(
        _,
        @lib.Expr(
          [
            @lib.TryTable(
              _,
              _,
              @lib.Expr([@lib.Call(@lib.FuncIdx(0U)), @lib.Nop])
            ),
          ]
        )
      ),
      @lib.Nop,
      @lib.Nop,
    ] => ()
    other =>
      fail(
        "expected Binaryen try_table once-reduction shape, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "once-reduction does not treat return_call as a Binaryen once call" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func $once
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g)
    #|   (func (export "run")
    #|     return_call $once
    #|     call $once))
    #|
  let optimized = try! or_test_run_once_reduction(input)

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
}

///|
test "once-reduction removes dropped unreachable debris before hard unreachable" {
  let input =
    #| (module
    #|   (func (export "run")
    #|     unreachable
    #|     drop
    #|     drop
    #|     unreachable))
    #|
  let optimized = try! or_test_run_once_reduction(input)

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 0), [
    @lib.Instruction::unreachable_(),
  ])
}

///|
test "once-reduction removes adjacent unreachable debris before hard unreachable" {
  let input =
    #| (module
    #|   (func (export "run")
    #|     unreachable
    #|     unreachable))
    #|
  let optimized = try! or_test_run_once_reduction(input)

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 0), [
    @lib.Instruction::unreachable_(),
  ])
}

///|
test "once-reduction preserves dangerous triple-cycle call order" {
  let input =
    #| (module
    #|   (import "env" "mark" (func $mark (param i32)))
    #|   (global $g0 (mut i32) (i32.const 0))
    #|   (global $g1 (mut i32) (i32.const 0))
    #|   (global $g2 (mut i32) (i32.const 0))
    #|   (func $once0
    #|     global.get $g0
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g0
    #|     call $once1
    #|     call $once2
    #|     i32.const 0
    #|     call $mark)
    #|   (func $once1
    #|     global.get $g1
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g1
    #|     call $once0
    #|     call $once2
    #|     i32.const 1
    #|     call $mark)
    #|   (func $once2
    #|     global.get $g2
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g2
    #|     call $once0
    #|     call $once1
    #|     i32.const 2
    #|     call $mark)
    #|   (func (export "run")
    #|     call $once0))
    #|
  let optimized = try! or_test_run_once_reduction(input)

  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 0), [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::return_()],
      None,
    ),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::i32_const(@lib.I32::new(0)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::return_()],
      None,
    ),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  @debug.assert_eq(try! or_test_defined_func_instrs(optimized, 2), [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(2U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::return_()],
      None,
    ),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(2U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32::new(2)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
}

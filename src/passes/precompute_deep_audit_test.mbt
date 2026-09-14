///|
test "deep audit precompute retains struct receiver global.set" {
  let output = audit_run(
    "(module (type $s (struct (field i32))) (type $a (array i32)) (import \"env\" \"effect\" (func $effect)) (global (export \"g\") (mut i32) (i32.const 0)) (func (result i32) (struct.get $s 0 (block (result (ref $s)) (global.set 0 (i32.const 1)) (struct.new $s (i32.const 7))))))",
    "precompute",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalSet(_) }),
    1,
  )
}

///|
test "deep audit precompute retains struct receiver call" {
  let output = audit_run(
    "(module (type $s (struct (field i32))) (type $a (array i32)) (import \"env\" \"effect\" (func $effect)) (global (export \"g\") (mut i32) (i32.const 0)) (func (result i32) (struct.get $s 0 (block (result (ref $s)) (call $effect) (struct.new $s (i32.const 7))))))",
    "precompute",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.Call(_) }),
    1,
  )
}

///|
test "deep audit precompute-propagate retains struct receiver global.set" {
  let output = audit_run(
    "(module (type $s (struct (field i32))) (type $a (array i32)) (import \"env\" \"effect\" (func $effect)) (global (export \"g\") (mut i32) (i32.const 0)) (func (result i32) (struct.get $s 0 (block (result (ref $s)) (global.set 0 (i32.const 1)) (struct.new $s (i32.const 7))))))",
    "precompute-propagate",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalSet(_) }),
    1,
  )
}

///|
test "deep audit precompute-propagate retains struct receiver call" {
  let output = audit_run(
    "(module (type $s (struct (field i32))) (type $a (array i32)) (import \"env\" \"effect\" (func $effect)) (global (export \"g\") (mut i32) (i32.const 0)) (func (result i32) (struct.get $s 0 (block (result (ref $s)) (call $effect) (struct.new $s (i32.const 7))))))",
    "precompute-propagate",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.Call(_) }),
    1,
  )
}

///|
test "deep audit precompute retains length receiver global" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array i32)) (import \"env\" \"effect\" (func)) (global (export \"g\") (mut i32) (i32.const 0)) (func (result i32) i32.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(
              @lib.ValType::ref_type(
                @lib.RefType::new(
                  false,
                  @lib.HeapType::new(@lib.TypeIdx::new(0U)),
                ),
              ),
            ),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(7)),
              @lib.Instruction::array_new_fixed(
                @lib.TypeIdx::new(0U),
                @lib.U32(1U),
              ),
            ]),
          ),
          @lib.Instruction::array_len(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalSet(_) }),
    1,
  )
}

///|
test "deep audit precompute retains length receiver call" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array i32)) (import \"env\" \"effect\" (func)) (global (export \"g\") (mut i32) (i32.const 0)) (func (result i32) i32.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(
              @lib.ValType::ref_type(
                @lib.RefType::new(
                  false,
                  @lib.HeapType::new(@lib.TypeIdx::new(0U)),
                ),
              ),
            ),
            @lib.Expr::new([
              @lib.Instruction::call(@lib.FuncIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(7)),
              @lib.Instruction::array_new_fixed(
                @lib.TypeIdx::new(0U),
                @lib.U32(1U),
              ),
            ]),
          ),
          @lib.Instruction::array_len(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.Call(_) }),
    1,
  )
}

///|
test "deep audit precompute-propagate retains length receiver global" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array i32)) (import \"env\" \"effect\" (func)) (global (export \"g\") (mut i32) (i32.const 0)) (func (result i32) i32.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(
              @lib.ValType::ref_type(
                @lib.RefType::new(
                  false,
                  @lib.HeapType::new(@lib.TypeIdx::new(0U)),
                ),
              ),
            ),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(7)),
              @lib.Instruction::array_new_fixed(
                @lib.TypeIdx::new(0U),
                @lib.U32(1U),
              ),
            ]),
          ),
          @lib.Instruction::array_len(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute-propagate")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalSet(_) }),
    1,
  )
}

///|
test "deep audit precompute-propagate retains length receiver call" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array i32)) (import \"env\" \"effect\" (func)) (global (export \"g\") (mut i32) (i32.const 0)) (func (result i32) i32.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(
              @lib.ValType::ref_type(
                @lib.RefType::new(
                  false,
                  @lib.HeapType::new(@lib.TypeIdx::new(0U)),
                ),
              ),
            ),
            @lib.Expr::new([
              @lib.Instruction::call(@lib.FuncIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(7)),
              @lib.Instruction::array_new_fixed(
                @lib.TypeIdx::new(0U),
                @lib.U32(1U),
              ),
            ]),
          ),
          @lib.Instruction::array_len(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute-propagate")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.Call(_) }),
    1,
  )
}

///|
test "deep audit precompute retains element receiver global" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array i32)) (import \"env\" \"effect\" (func)) (global (export \"g\") (mut i32) (i32.const 0)) (func (result i32) i32.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(
              @lib.ValType::ref_type(
                @lib.RefType::new(
                  false,
                  @lib.HeapType::new(@lib.TypeIdx::new(0U)),
                ),
              ),
            ),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(7)),
              @lib.Instruction::array_new_fixed(
                @lib.TypeIdx::new(0U),
                @lib.U32(1U),
              ),
            ]),
          ),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::array_get(@lib.TypeIdx::new(0U)),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalSet(_) }),
    1,
  )
}

///|
test "deep audit precompute retains element receiver call" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array i32)) (import \"env\" \"effect\" (func)) (global (export \"g\") (mut i32) (i32.const 0)) (func (result i32) i32.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(
              @lib.ValType::ref_type(
                @lib.RefType::new(
                  false,
                  @lib.HeapType::new(@lib.TypeIdx::new(0U)),
                ),
              ),
            ),
            @lib.Expr::new([
              @lib.Instruction::call(@lib.FuncIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(7)),
              @lib.Instruction::array_new_fixed(
                @lib.TypeIdx::new(0U),
                @lib.U32(1U),
              ),
            ]),
          ),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::array_get(@lib.TypeIdx::new(0U)),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.Call(_) }),
    1,
  )
}

///|
test "deep audit precompute-propagate retains element receiver global" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array i32)) (import \"env\" \"effect\" (func)) (global (export \"g\") (mut i32) (i32.const 0)) (func (result i32) i32.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(
              @lib.ValType::ref_type(
                @lib.RefType::new(
                  false,
                  @lib.HeapType::new(@lib.TypeIdx::new(0U)),
                ),
              ),
            ),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(7)),
              @lib.Instruction::array_new_fixed(
                @lib.TypeIdx::new(0U),
                @lib.U32(1U),
              ),
            ]),
          ),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::array_get(@lib.TypeIdx::new(0U)),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute-propagate")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalSet(_) }),
    1,
  )
}

///|
test "deep audit precompute-propagate retains element receiver call" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array i32)) (import \"env\" \"effect\" (func)) (global (export \"g\") (mut i32) (i32.const 0)) (func (result i32) i32.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(
              @lib.ValType::ref_type(
                @lib.RefType::new(
                  false,
                  @lib.HeapType::new(@lib.TypeIdx::new(0U)),
                ),
              ),
            ),
            @lib.Expr::new([
              @lib.Instruction::call(@lib.FuncIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(7)),
              @lib.Instruction::array_new_fixed(
                @lib.TypeIdx::new(0U),
                @lib.U32(1U),
              ),
            ]),
          ),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::array_get(@lib.TypeIdx::new(0U)),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute-propagate")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.Call(_) }),
    1,
  )
}

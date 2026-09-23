///|
test "dispatcher removes case 144 same-target br_table shells through seven passes" {
  let wat =
    #|(module
    #|  (type $pair (func (result i32 i64)))
    #|  (type $void (func))
    #|  (func (type $void)
    #|    (drop (block $i32 (result i32)
    #|      (br_if $i32 (i32.const 306) (i32.const 1))))
    #|    (drop (block $i64 (result i64)
    #|      (br_if $i64 (i64.const 37) (i32.const 0))))
    #|    (drop (block $f32 (result f32)
    #|      (br_if $f32 (f32.const 82) (i32.const 0))))
    #|    (drop (block $f64 (result f64)
    #|      (br_if $f64 (f64.const 34) (i32.const 1))))
    #|    (drop (block $v128 (result v128)
    #|      (br_if $v128
    #|        (v128.const i32x4 0 0 0 0)
    #|        (i32.const 1))))
    #|    (drop (block $ref (result funcref)
    #|      (br_if $ref (ref.null nofunc) (i32.const 1)))))
    #|  (func (type $pair) (result i32 i64) (local i64)
    #|    (local.set 0 (i64.const 43))
    #|    (drop (block $i32 (result i32)
    #|      (br_table $i32 $i32 (i32.const 291) (i32.const 3))
    #|      unreachable))
    #|    (drop (block $i64 (result i64)
    #|      (br_table $i64 $i64 (i64.const 804) (i32.const 3))
    #|      unreachable))
    #|    (drop (block $f32 (result f32)
    #|      (br_table $f32 $f32 (f32.const 30) (i32.const 1))
    #|      unreachable))
    #|    (drop (block $f64 (result f64)
    #|      (br_table $f64 $f64 (f64.const 86) (i32.const 2))
    #|      unreachable))
    #|    (drop (block $v128 (result v128)
    #|      (br_table $v128 $v128
    #|        (v128.const i32x4 0 0 0 0)
    #|        (i32.const 1))
    #|      unreachable))
    #|    (drop (block $ref (result funcref)
    #|      (br_table $ref $ref (ref.null nofunc) (i32.const 0))
    #|      unreachable))
    #|    i32.const 47
    #|    i64.const 53))
    #|)
  let input = @passes.pass_test_module_from_wat(wat)
  let optimized = optimize_module_with_pass_flags(
    input,
    [
      "optimize-instructions", "precompute", "vacuum", "local-cse", "simplify-locals",
      "remove-unused-brs", "dead-code-elimination",
    ],
    OptimizeOptions::new(),
  ).unwrap()

  match optimized.code_sec {
    Some(@lib.CodeSec([_, @lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(body, [
        @lib.Instruction::nop(),
        @lib.Instruction::i32_const(@lib.I32(47)),
        @lib.Instruction::i64_const(@lib.I64(53L)),
      ])
    _ => fail("expected two optimized function bodies")
  }
}

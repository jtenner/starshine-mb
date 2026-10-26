///|
fn db19_f05_fixture(count : Int32, mode : Int32) -> @lib.Module {
  let catches : Array[@lib.LegacyCatch] = []
  if mode == 3 || mode == 4 {
    catches.push(
      @lib.LegacyCatch::all(@lib.Expr::new([@lib.Instruction::nop()])),
    )
  }
  for _ in 0..<count {
    catches.push(
      @lib.LegacyCatch::tagged(
        @lib.TagIdx::new(0U),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
    )
  }
  if mode == 2 || mode == 4 {
    catches.push(
      @lib.LegacyCatch::all(@lib.Expr::new([@lib.Instruction::nop()])),
    )
  }
  let body = if mode == 0 {
    @lib.Expr::new([@lib.Instruction::nop()])
  } else {
    @lib.Expr::new([
      @lib.Instruction::try_(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::nop()]),
        catches,
      ),
    ])
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
  .with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(@lib.Locals::empty(), body)]),
  )
}

///|
fn db19_f05_bench(it : @bench.T, count : Int32, mode : Int32) -> Unit {
  let input = db19_f05_fixture(count, mode)
  let mut callbacks = 0
  it.bench(count=5, fn() {
    callbacks = callbacks + 1
    it.keep(@validate.validate_module(input))
  })
  println("DB19_CALLBACKS=\{callbacks}")
  let checked = @validate.validate_module(input)
  println("DB19_VALIDATION_ACCEPTED=\{checked is Ok(_)}")
  if checked is Err(err) {
    println("DB19_VALIDATION_ERROR=\{@validate.validation_error_message(err)}")
  }
}

///|
test "bench db19 F05 no legacy try" (it : @bench.T) {
  db19_f05_bench(it, 0, 0)
}

///|
test "bench db19 F05 typed catches=1 final_all=false" (it : @bench.T) {
  db19_f05_bench(it, 1, 1)
}

///|
test "bench db19 F05 typed catches=1 final_all=true" (it : @bench.T) {
  db19_f05_bench(it, 1, 2)
}

///|
test "bench db19 F05 typed catches=16 final_all=false" (it : @bench.T) {
  db19_f05_bench(it, 16, 1)
}

///|
test "bench db19 F05 typed catches=16 final_all=true" (it : @bench.T) {
  db19_f05_bench(it, 16, 2)
}

///|
test "bench db19 F05 typed catches=256 final_all=false" (it : @bench.T) {
  db19_f05_bench(it, 256, 1)
}

///|
test "bench db19 F05 typed catches=256 final_all=true" (it : @bench.T) {
  db19_f05_bench(it, 256, 2)
}

///|
test "bench db19 F05 invalid early catch_all before 16 typed catches" (
  it : @bench.T,
) {
  db19_f05_bench(it, 16, 3)
}

///|
test "bench db19 F05 invalid duplicate catch_all" (it : @bench.T) {
  db19_f05_bench(it, 0, 4)
}

///|
fn dealign_memarg(ma : @lib.MemArg, changed : Array[Bool]) -> @lib.MemArg {
  let @lib.MemArg(align, mem, offset) = ma
  if align == @lib.U32(0U) {
    ma
  } else {
    changed[0] = true
    @lib.MemArg::new(@lib.U32(0U), mem, offset)
  }
}

///|
fn dealign_rewrite_expr(expr : @lib.Expr, changed : Array[Bool]) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let rewritten : Array[@lib.Instruction] = []
  for instr in instrs {
    rewritten.push(dealign_rewrite_instruction(instr, changed))
  }
  @lib.Expr::new(rewritten)
}

///|
fn dealign_rewrite_instruction(
  instr : @lib.Instruction,
  changed : Array[Bool],
) -> @lib.Instruction {
  match instr {
    @lib.Block(block_type, body) =>
      @lib.Instruction::block(block_type, dealign_rewrite_expr(body, changed))
    @lib.Loop(block_type, body) =>
      @lib.Instruction::loop_(block_type, dealign_rewrite_expr(body, changed))
    @lib.If(block_type, then_body, else_body) => {
      let next_then : Array[@lib.Instruction] = []
      for nested in then_body {
        next_then.push(dealign_rewrite_instruction(nested, changed))
      }
      let next_else = match else_body {
        Some(body) => {
          let rewritten : Array[@lib.Instruction] = []
          for nested in body {
            rewritten.push(dealign_rewrite_instruction(nested, changed))
          }
          Some(rewritten)
        }
        None => None
      }
      @lib.Instruction::if_(block_type, next_then, next_else)
    }
    @lib.Try(block_type, body, catches, delegate) => {
      let next_catches : Array[@lib.LegacyCatch] = []
      for catch_ in catches {
        match catch_ {
          @lib.LegacyCatch(tag_idx, catch_body) =>
            next_catches.push(
              @lib.LegacyCatch::tagged(
                tag_idx,
                dealign_rewrite_expr(catch_body, changed),
              ),
            )
          @lib.LegacyCatchAll(catch_body) =>
            next_catches.push(
              @lib.LegacyCatch::all(dealign_rewrite_expr(catch_body, changed)),
            )
        }
      }
      @lib.Instruction::try_(
        block_type,
        dealign_rewrite_expr(body, changed),
        next_catches,
        delegate~,
      )
    }
    @lib.TryTable(block_type, catches, body) =>
      @lib.Instruction::try_table(
        block_type,
        catches,
        dealign_rewrite_expr(body, changed),
      )
    @lib.I32Load(ma) => @lib.Instruction::i32_load(dealign_memarg(ma, changed))
    @lib.I64Load(ma) => @lib.Instruction::i64_load(dealign_memarg(ma, changed))
    @lib.F32Load(ma) => @lib.Instruction::f32_load(dealign_memarg(ma, changed))
    @lib.F64Load(ma) => @lib.Instruction::f64_load(dealign_memarg(ma, changed))
    @lib.I32Load8S(ma) =>
      @lib.Instruction::i32_load8s(dealign_memarg(ma, changed))
    @lib.I32Load8U(ma) =>
      @lib.Instruction::i32_load8u(dealign_memarg(ma, changed))
    @lib.I32Load16S(ma) =>
      @lib.Instruction::i32_load16s(dealign_memarg(ma, changed))
    @lib.I32Load16U(ma) =>
      @lib.Instruction::i32_load16u(dealign_memarg(ma, changed))
    @lib.I64Load8S(ma) =>
      @lib.Instruction::i64_load8s(dealign_memarg(ma, changed))
    @lib.I64Load8U(ma) =>
      @lib.Instruction::i64_load8u(dealign_memarg(ma, changed))
    @lib.I64Load16S(ma) =>
      @lib.Instruction::i64_load16s(dealign_memarg(ma, changed))
    @lib.I64Load16U(ma) =>
      @lib.Instruction::i64_load16u(dealign_memarg(ma, changed))
    @lib.I64Load32S(ma) =>
      @lib.Instruction::i64_load32s(dealign_memarg(ma, changed))
    @lib.I64Load32U(ma) =>
      @lib.Instruction::i64_load32u(dealign_memarg(ma, changed))
    @lib.I32Store(ma) =>
      @lib.Instruction::i32_store(dealign_memarg(ma, changed))
    @lib.I64Store(ma) =>
      @lib.Instruction::i64_store(dealign_memarg(ma, changed))
    @lib.F32Store(ma) =>
      @lib.Instruction::f32_store(dealign_memarg(ma, changed))
    @lib.F64Store(ma) =>
      @lib.Instruction::f64_store(dealign_memarg(ma, changed))
    @lib.I32Store8(ma) =>
      @lib.Instruction::i32_store8(dealign_memarg(ma, changed))
    @lib.I32Store16(ma) =>
      @lib.Instruction::i32_store16(dealign_memarg(ma, changed))
    @lib.I64Store8(ma) =>
      @lib.Instruction::i64_store8(dealign_memarg(ma, changed))
    @lib.I64Store16(ma) =>
      @lib.Instruction::i64_store16(dealign_memarg(ma, changed))
    @lib.I64Store32(ma) =>
      @lib.Instruction::i64_store32(dealign_memarg(ma, changed))
    @lib.V128Load(ma) =>
      @lib.Instruction::v128_load(dealign_memarg(ma, changed))
    @lib.V128Load8x8S(ma) =>
      @lib.Instruction::v128_load8x8s(dealign_memarg(ma, changed))
    @lib.V128Load8x8U(ma) =>
      @lib.Instruction::v128_load8x8u(dealign_memarg(ma, changed))
    @lib.V128Load16x4S(ma) =>
      @lib.Instruction::v128_load16x4s(dealign_memarg(ma, changed))
    @lib.V128Load16x4U(ma) =>
      @lib.Instruction::v128_load16x4u(dealign_memarg(ma, changed))
    @lib.V128Load32x2S(ma) =>
      @lib.Instruction::v128_load32x2s(dealign_memarg(ma, changed))
    @lib.V128Load32x2U(ma) =>
      @lib.Instruction::v128_load32x2u(dealign_memarg(ma, changed))
    @lib.V128Load8Splat(ma) =>
      @lib.Instruction::v128_load8_splat(dealign_memarg(ma, changed))
    @lib.V128Load16Splat(ma) =>
      @lib.Instruction::v128_load16_splat(dealign_memarg(ma, changed))
    @lib.V128Load32Splat(ma) =>
      @lib.Instruction::v128_load32_splat(dealign_memarg(ma, changed))
    @lib.V128Load64Splat(ma) =>
      @lib.Instruction::v128_load64_splat(dealign_memarg(ma, changed))
    @lib.V128Store(ma) =>
      @lib.Instruction::v128_store(dealign_memarg(ma, changed))
    @lib.V128Load32Zero(ma) =>
      @lib.Instruction::v128_load32_zero(dealign_memarg(ma, changed))
    @lib.V128Load64Zero(ma) =>
      @lib.Instruction::v128_load64_zero(dealign_memarg(ma, changed))
    @lib.V128Load8Lane(ma, lane) =>
      @lib.Instruction::v128_load8_lane(dealign_memarg(ma, changed), lane)
    @lib.V128Load16Lane(ma, lane) =>
      @lib.Instruction::v128_load16_lane(dealign_memarg(ma, changed), lane)
    @lib.V128Load32Lane(ma, lane) =>
      @lib.Instruction::v128_load32_lane(dealign_memarg(ma, changed), lane)
    @lib.V128Load64Lane(ma, lane) =>
      @lib.Instruction::v128_load64_lane(dealign_memarg(ma, changed), lane)
    @lib.V128Store8Lane(ma, lane) =>
      @lib.Instruction::v128_store8_lane(dealign_memarg(ma, changed), lane)
    @lib.V128Store16Lane(ma, lane) =>
      @lib.Instruction::v128_store16_lane(dealign_memarg(ma, changed), lane)
    @lib.V128Store32Lane(ma, lane) =>
      @lib.Instruction::v128_store32_lane(dealign_memarg(ma, changed), lane)
    @lib.V128Store64Lane(ma, lane) =>
      @lib.Instruction::v128_store64_lane(dealign_memarg(ma, changed), lane)
    @lib.ArrayLoad(op, type_idx, ma) =>
      @lib.Instruction::array_load(
        op,
        type_idx,
        memarg=dealign_memarg(ma, changed),
      )
    @lib.ArrayStore(op, type_idx, ma) =>
      @lib.Instruction::array_store(
        op,
        type_idx,
        memarg=dealign_memarg(ma, changed),
      )
    _ => instr
  }
}

///|
fn dealign_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let @lib.CodeSec(funcs) = match mod_.code_sec {
    Some(section) => section
    None => return mod_
  }
  let changed = [false]
  let rewritten : Array[@lib.Func] = []
  for func in funcs {
    let @lib.Func(locals, body) = func
    rewritten.push(@lib.Func::new(locals, dealign_rewrite_expr(body, changed)))
  }
  if changed[0] {
    mod_.with_code_sec(@lib.CodeSec::new(rewritten))
  } else {
    mod_
  }
}

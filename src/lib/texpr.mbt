///|
/// Convert flat Expr to tree-based TExpr
pub fn expr_to_texpr(expr : Expr, env : Env) -> Result[TExpr, String] {
  let stack : Array[TInstr] = []
  for instr in expr.0 {
    match instr_to_tinstr(instr, stack, env) {
      Ok(_) => ()
      Err(t) => return Err(t)
    }
  }
  Ok(TExpr(stack))
}

///|
/// Convert tree-based TExpr back to flat Expr
pub fn texpr_to_expr(texpr : TExpr) -> Expr {
  let instrs : Array[Instruction] = []
  for value in texpr.0 {
    tinstr_to_instr(value, instrs)
  }
  Expr(instrs)
}

// ============================================================================
// Expr -> TExpr helpers
// ============================================================================

///|
fn pop(stack : Array[TInstr]) -> Result[TInstr, String] {
  match stack.pop() {
    Some(v) => Ok(v)
    None => Err("Stack underflow during tree conversion")
  }
}

///|
fn pop_n(stack : Array[TInstr], n : Int) -> Result[Array[TInstr], String] {
  if stack.length() < n {
    return Err(
      "Stack underflow: need \{n} values but only \{stack.length()} available",
    )
  }
  let result : Array[TInstr] = Array::make(n, TInstr::TNop)
  // Pop in reverse order, then we have them in correct order
  for i = n - 1; i >= 0; i = i - 1 {
    result[i] = stack.pop().unwrap()
  }
  Ok(result)
}

///|
fn block_type_inputs(bt : BlockType, env : Env) -> Int {
  match bt {
    EmptyBlockType => 0
    ValTypeBlockType(_) => 0
    TypeIdxBlockType(idx) =>
      match env.resolve_functype(idx) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
  }
}

///|
fn instr_to_tinstr(
  instr : Instruction,
  stack : Array[TInstr],
  env : Env,
) -> Result[Unit, String] {
  match instr {
    // === Constants ===
    I32Const(v) => stack.push(TI32Const(v))
    I64Const(v) => stack.push(TI64Const(v))
    F32Const(v) => stack.push(TF32Const(v))
    F64Const(v) => stack.push(TF64Const(v))
    RefNull(ht) => stack.push(TRefNull(ht))
    RefFunc(idx) => stack.push(TRefFunc(idx))
    V128Const(
      b0,
      b1,
      b2,
      b3,
      b4,
      b5,
      b6,
      b7,
      b8,
      b9,
      b10,
      b11,
      b12,
      b13,
      b14,
      b15
    ) =>
      stack.push(
        TV128Const(
          b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15,
        ),
      )

    // === Nullary ===
    Unreachable => stack.push(TUnreachable)
    Nop => stack.push(TNop)
    LocalGet(idx) => stack.push(TLocalGet(idx))
    GlobalGet(idx) => stack.push(TGlobalGet(idx))
    MemorySize(idx) => stack.push(TMemorySize(idx))
    TableSize(idx) => stack.push(TTableSize(idx))

    // === Unary numeric ===
    I32Eqz => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32EqzOp, op))
    }
    I64Eqz => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64EqzOp, op))
    }
    I32Clz => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32ClzOp, op))
    }
    I32Ctz => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32CtzOp, op))
    }
    I32Popcnt => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32PopcntOp, op))
    }
    I64Clz => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64ClzOp, op))
    }
    I64Ctz => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64CtzOp, op))
    }
    I64Popcnt => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64PopcntOp, op))
    }
    F32Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32AbsOp, op))
    }
    F32Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32NegOp, op))
    }
    F32Ceil => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32CeilOp, op))
    }
    F32Floor => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32FloorOp, op))
    }
    F32Trunc => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32TruncOp, op))
    }
    F32Nearest => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32NearestOp, op))
    }
    F32Sqrt => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32SqrtOp, op))
    }
    F64Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64AbsOp, op))
    }
    F64Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64NegOp, op))
    }
    F64Ceil => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64CeilOp, op))
    }
    F64Floor => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64FloorOp, op))
    }
    F64Trunc => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64TruncOp, op))
    }
    F64Nearest => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64NearestOp, op))
    }
    F64Sqrt => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64SqrtOp, op))
    }

    // === Conversions ===
    I32WrapI64 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32WrapI64Op, op))
    }
    I32TruncF32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32TruncF32SOp, op))
    }
    I32TruncF32U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32TruncF32UOp, op))
    }
    I32TruncF64S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32TruncF64SOp, op))
    }
    I32TruncF64U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32TruncF64UOp, op))
    }
    I64ExtendI32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64ExtendI32SOp, op))
    }
    I64ExtendI32U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64ExtendI32UOp, op))
    }
    I64TruncF32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64TruncF32SOp, op))
    }
    I64TruncF32U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64TruncF32UOp, op))
    }
    I64TruncF64S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64TruncF64SOp, op))
    }
    I64TruncF64U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64TruncF64UOp, op))
    }
    F32ConvertI32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32ConvertI32SOp, op))
    }
    F32ConvertI32U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32ConvertI32UOp, op))
    }
    F32ConvertI64S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32ConvertI64SOp, op))
    }
    F32ConvertI64U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32ConvertI64UOp, op))
    }
    F32DemoteF64 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32DemoteF64Op, op))
    }
    F64ConvertI32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64ConvertI32SOp, op))
    }
    F64ConvertI32U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64ConvertI32UOp, op))
    }
    F64ConvertI64S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64ConvertI64SOp, op))
    }
    F64ConvertI64U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64ConvertI64UOp, op))
    }
    F64PromoteF32 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64PromoteF32Op, op))
    }
    I32ReinterpretF32 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32ReinterpretF32Op, op))
    }
    I64ReinterpretF64 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64ReinterpretF64Op, op))
    }
    F32ReinterpretI32 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32ReinterpretI32Op, op))
    }
    F64ReinterpretI64 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64ReinterpretI64Op, op))
    }
    I32Extend8S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32Extend8SOp, op))
    }
    I32Extend16S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32Extend16SOp, op))
    }
    I64Extend8S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64Extend8SOp, op))
    }
    I64Extend16S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64Extend16SOp, op))
    }
    I64Extend32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64Extend32SOp, op))
    }
    I32TruncSatF32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32TruncSatF32SOp, op))
    }
    I32TruncSatF32U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32TruncSatF32UOp, op))
    }
    I32TruncSatF64S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32TruncSatF64SOp, op))
    }
    I32TruncSatF64U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32TruncSatF64UOp, op))
    }
    I64TruncSatF32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64TruncSatF32SOp, op))
    }
    I64TruncSatF32U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64TruncSatF32UOp, op))
    }
    I64TruncSatF64S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64TruncSatF64SOp, op))
    }
    I64TruncSatF64U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64TruncSatF64UOp, op))
    }

    // === Binary numeric ===
    I32Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32EqOp, lhs, rhs))
    }
    I32Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32NeOp, lhs, rhs))
    }
    I32LtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32LtSOp, lhs, rhs))
    }
    I32LtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32LtUOp, lhs, rhs))
    }
    I32GtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32GtSOp, lhs, rhs))
    }
    I32GtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32GtUOp, lhs, rhs))
    }
    I32LeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32LeSOp, lhs, rhs))
    }
    I32LeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32LeUOp, lhs, rhs))
    }
    I32GeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32GeSOp, lhs, rhs))
    }
    I32GeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32GeUOp, lhs, rhs))
    }
    I64Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64EqOp, lhs, rhs))
    }
    I64Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64NeOp, lhs, rhs))
    }
    I64LtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64LtSOp, lhs, rhs))
    }
    I64LtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64LtUOp, lhs, rhs))
    }
    I64GtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64GtSOp, lhs, rhs))
    }
    I64GtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64GtUOp, lhs, rhs))
    }
    I64LeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64LeSOp, lhs, rhs))
    }
    I64LeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64LeUOp, lhs, rhs))
    }
    I64GeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64GeSOp, lhs, rhs))
    }
    I64GeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64GeUOp, lhs, rhs))
    }
    F32Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32EqOp, lhs, rhs))
    }
    F32Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32NeOp, lhs, rhs))
    }
    F32Lt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32LtOp, lhs, rhs))
    }
    F32Gt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32GtOp, lhs, rhs))
    }
    F32Le => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32LeOp, lhs, rhs))
    }
    F32Ge => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32GeOp, lhs, rhs))
    }
    F64Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64EqOp, lhs, rhs))
    }
    F64Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64NeOp, lhs, rhs))
    }
    F64Lt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64LtOp, lhs, rhs))
    }
    F64Gt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64GtOp, lhs, rhs))
    }
    F64Le => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64LeOp, lhs, rhs))
    }
    F64Ge => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64GeOp, lhs, rhs))
    }
    I32Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32AddOp, lhs, rhs))
    }
    I32Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32SubOp, lhs, rhs))
    }
    I32Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32MulOp, lhs, rhs))
    }
    I32DivS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32DivSOp, lhs, rhs))
    }
    I32DivU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32DivUOp, lhs, rhs))
    }
    I32RemS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32RemSOp, lhs, rhs))
    }
    I32RemU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32RemUOp, lhs, rhs))
    }
    I32And => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32AndOp, lhs, rhs))
    }
    I32Or => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32OrOp, lhs, rhs))
    }
    I32Xor => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32XorOp, lhs, rhs))
    }
    I32Shl => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32ShlOp, lhs, rhs))
    }
    I32ShrS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32ShrSOp, lhs, rhs))
    }
    I32ShrU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32ShrUOp, lhs, rhs))
    }
    I32Rotl => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32RotlOp, lhs, rhs))
    }
    I32Rotr => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32RotrOp, lhs, rhs))
    }
    I64Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64AddOp, lhs, rhs))
    }
    I64Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64SubOp, lhs, rhs))
    }
    I64Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64MulOp, lhs, rhs))
    }
    I64DivS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64DivSOp, lhs, rhs))
    }
    I64DivU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64DivUOp, lhs, rhs))
    }
    I64RemS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64RemSOp, lhs, rhs))
    }
    I64RemU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64RemUOp, lhs, rhs))
    }
    I64And => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64AndOp, lhs, rhs))
    }
    I64Or => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64OrOp, lhs, rhs))
    }
    I64Xor => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64XorOp, lhs, rhs))
    }
    I64Shl => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64ShlOp, lhs, rhs))
    }
    I64ShrS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64ShrSOp, lhs, rhs))
    }
    I64ShrU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64ShrUOp, lhs, rhs))
    }
    I64Rotl => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64RotlOp, lhs, rhs))
    }
    I64Rotr => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64RotrOp, lhs, rhs))
    }
    F32Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32AddOp, lhs, rhs))
    }
    F32Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32SubOp, lhs, rhs))
    }
    F32Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32MulOp, lhs, rhs))
    }
    F32Div => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32DivOp, lhs, rhs))
    }
    F32Min => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32MinOp, lhs, rhs))
    }
    F32Max => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32MaxOp, lhs, rhs))
    }
    F32Copysign => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32CopysignOp, lhs, rhs))
    }
    F64Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64AddOp, lhs, rhs))
    }
    F64Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64SubOp, lhs, rhs))
    }
    F64Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64MulOp, lhs, rhs))
    }
    F64Div => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64DivOp, lhs, rhs))
    }
    F64Min => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64MinOp, lhs, rhs))
    }
    F64Max => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64MaxOp, lhs, rhs))
    }
    F64Copysign => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64CopysignOp, lhs, rhs))
    }

    // === Other unary ===
    Drop => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TDrop(op))
    }
    LocalSet(idx) => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLocalSet(idx, op))
    }
    LocalTee(idx) => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLocalTee(idx, op))
    }
    GlobalSet(idx) => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TGlobalSet(idx, op))
    }
    RefIsNull => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TRefIsNull(op))
    }
    RefAsNonNull => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TRefAsNonNull(op))
    }
    RefEq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TRefEq(lhs, rhs))
    }
    RefI31 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TRefI31(op))
    }
    I31GetS => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TI31GetS(op))
    }
    I31GetU => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TI31GetU(op))
    }
    ArrayLen => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TArrayLen(op))
    }
    AnyConvertExtern => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TAnyConvertExtern(op))
    }
    ExternConvertAny => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TExternConvertAny(op))
    }
    ThrowRef => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TThrowRef(op))
    }

    // === Loads ===
    I32Load(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(I32LoadOp, memarg, addr))
    }
    I64Load(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(I64LoadOp, memarg, addr))
    }
    F32Load(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(F32LoadOp, memarg, addr))
    }
    F64Load(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(F64LoadOp, memarg, addr))
    }
    I32Load8S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(I32Load8SOp, memarg, addr))
    }
    I32Load8U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(I32Load8UOp, memarg, addr))
    }
    I32Load16S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(I32Load16SOp, memarg, addr))
    }
    I32Load16U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(I32Load16UOp, memarg, addr))
    }
    I64Load8S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(I64Load8SOp, memarg, addr))
    }
    I64Load8U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(I64Load8UOp, memarg, addr))
    }
    I64Load16S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(I64Load16SOp, memarg, addr))
    }
    I64Load16U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(I64Load16UOp, memarg, addr))
    }
    I64Load32S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(I64Load32SOp, memarg, addr))
    }
    I64Load32U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(I64Load32UOp, memarg, addr))
    }

    // === Stores ===
    I32Store(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStore(I32StoreOp, memarg, addr, value))
    }
    I64Store(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStore(I64StoreOp, memarg, addr, value))
    }
    F32Store(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStore(F32StoreOp, memarg, addr, value))
    }
    F64Store(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStore(F64StoreOp, memarg, addr, value))
    }
    I32Store8(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStore(I32Store8Op, memarg, addr, value))
    }
    I32Store16(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStore(I32Store16Op, memarg, addr, value))
    }
    I64Store8(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStore(I64Store8Op, memarg, addr, value))
    }
    I64Store16(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStore(I64Store16Op, memarg, addr, value))
    }
    I64Store32(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStore(I64Store32Op, memarg, addr, value))
    }

    // === Memory operations ===
    MemoryGrow(idx) => {
      let pages = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TMemoryGrow(idx, pages))
    }
    MemoryFill(idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let dest = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TMemoryFill(idx, dest, val, len))
    }
    MemoryCopy(dst, src) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let src_addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let dst_addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TMemoryCopy(dst, src, dst_addr, src_addr, len))
    }
    MemoryInit(data_idx, mem_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let src = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let dst = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TMemoryInit(data_idx, mem_idx, dst, src, len))
    }
    DataDrop(idx) => stack.push(TDataDrop(idx))

    // === Table operations ===
    TableGet(idx) => {
      let i = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TTableGet(idx, i))
    }
    TableSet(idx) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let i = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TTableSet(idx, i, val))
    }
    TableGrow(idx) => {
      let n = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TTableGrow(idx, val, n))
    }
    TableFill(idx) => {
      let n = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let i = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TTableFill(idx, i, val, n))
    }
    TableCopy(dst, src) => {
      let n = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let s = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let d = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TTableCopy(dst, src, d, s, n))
    }
    TableInit(elem_idx, table_idx) => {
      let n = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let s = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let d = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TTableInit(elem_idx, table_idx, d, s, n))
    }
    ElemDrop(idx) => stack.push(TElemDrop(idx))

    // === Select ===
    Select(types) => {
      let cond = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let val2 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let val1 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TSelect(types, cond, val1, val2))
    }

    // === Control flow ===
    Block(bt, body) => {
      let n_inputs = block_type_inputs(bt, env)
      let inputs = match pop_n(stack, n_inputs) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      // Create a new stack with inputs for the block body
      let body_stack : Array[TInstr] = []
      for input in inputs {
        body_stack.push(input)
      }
      for instr in body.0 {
        match instr_to_tinstr(instr, body_stack, env) {
          Ok(_) => ()
          Err(t) => return Err(t)
        }
      }
      stack.push(TBlock(bt, TExpr(body_stack)))
    }
    Loop(bt, body) => {
      let n_inputs = block_type_inputs(bt, env)
      let inputs = match pop_n(stack, n_inputs) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let body_stack = []
      for input in inputs {
        body_stack.push(input)
      }
      for instr in body.0 {
        match instr_to_tinstr(instr, body_stack, env) {
          Ok(_) => ()
          Err(t) => return Err(t)
        }
      }
      stack.push(TLoop(bt, TExpr(body_stack)))
    }
    If(bt, then_branch, else_branch) => {
      let cond = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let n_inputs = block_type_inputs(bt, env)
      let inputs = match pop_n(stack, n_inputs) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let then_stack : Array[TInstr] = []
      for input in inputs {
        then_stack.push(input)
      }
      for instr in then_branch {
        match instr_to_tinstr(instr, then_stack, env) {
          Ok(_) => ()
          Err(t) => return Err(t)
        }
      }
      let else_texpr : TExpr? = match else_branch {
        Some(else_instrs) => {
          let else_stack : Array[TInstr] = []
          for input in inputs {
            else_stack.push(input)
          }
          for instr in else_instrs {
            match instr_to_tinstr(instr, else_stack, env) {
              Ok(_) => ()
              Err(t) => return Err(t)
            }
          }
          Some(TExpr(else_stack))
        }
        None => None
      }
      stack.push(TIf(bt, cond, TExpr(then_stack), else_texpr))
    }
    TryTable(bt, catches, body) => {
      let n_inputs = block_type_inputs(bt, env)
      let inputs = match pop_n(stack, n_inputs) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let body_stack = []
      for input in inputs {
        body_stack.push(input)
      }
      for instr in body.0 {
        match instr_to_tinstr(instr, body_stack, env) {
          Ok(_) => ()
          Err(t) => return Err(t)
        }
      }
      stack.push(TTryTable(bt, catches, TExpr(body_stack)))
    }
    Throw(tag_idx) => {
      let n_args = match env.resolve_tag_functype(tag_idx) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
      let args = match pop_n(stack, n_args) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TThrow(tag_idx, args))
    }

    // === Branches ===
    Br(label) => {
      // Get the arity from label
      let arity = match env.get_label(label) {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBr(label, values))
    }
    BrIf(label) => {
      let cond = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arity = match env.get_label(label) {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBrIf(label, cond, values))
    }
    BrTable(labels, default) => {
      let idx = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arity = match env.get_label(default) {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBrTable(labels, default, idx, values))
    }
    BrOnNull(label) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arity = match env.get_label(label) {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBrOnNull(label, ref_, values))
    }
    BrOnNonNull(label) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arity = match env.get_label(label) {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBrOnNonNull(label, ref_, values))
    }
    BrOnCast(label, castop, ht1, ht2) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arity = match env.get_label(label) {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBrOnCast(label, castop, ht1, ht2, ref_, values))
    }
    BrOnCastFail(label, castop, ht1, ht2) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arity = match env.get_label(label) {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBrOnCastFail(label, castop, ht1, ht2, ref_, values))
    }
    Return => {
      let arity = match env.return_type {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TReturn(values))
    }

    // === Calls ===
    Call(func_idx) => {
      let n_args = match env.funcs.get(func_idx.0.reinterpret_as_int()) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
      let args = match pop_n(stack, n_args) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TCall(func_idx, args))
    }
    CallIndirect(type_idx, table_idx) => {
      let idx = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let n_args = match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
      let args = match pop_n(stack, n_args) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TCallIndirect(type_idx, table_idx, args, idx))
    }
    CallRef(type_idx) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let n_args = match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
      let args = match pop_n(stack, n_args) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TCallRef(type_idx, args, ref_))
    }
    ReturnCall(func_idx) => {
      let n_args = match env.funcs.get(func_idx.0.reinterpret_as_int()) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
      let args = match pop_n(stack, n_args) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TReturnCall(func_idx, args))
    }
    ReturnCallIndirect(type_idx, table_idx) => {
      let idx = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let n_args = match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
      let args = match pop_n(stack, n_args) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TReturnCallIndirect(type_idx, table_idx, args, idx))
    }
    ReturnCallRef(type_idx) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let n_args = match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
      let args = match pop_n(stack, n_args) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TReturnCallRef(type_idx, args, ref_))
    }

    // === GC: Structs ===
    StructNew(type_idx) => {
      let n_fields = match env.resolve_comptype(type_idx) {
        Some(StructCompType(fields)) => fields.length()
        _ => 0
      }
      let fields = match pop_n(stack, n_fields) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStructNew(type_idx, fields))
    }
    StructNewDefault(type_idx) => stack.push(TStructNewDefault(type_idx))
    StructGet(type_idx, field_idx) => {
      let struct_ref = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStructGet(type_idx, field_idx, struct_ref))
    }
    StructGetS(type_idx, field_idx) => {
      let struct_ref = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStructGetS(type_idx, field_idx, struct_ref))
    }
    StructGetU(type_idx, field_idx) => {
      let struct_ref = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStructGetU(type_idx, field_idx, struct_ref))
    }
    StructSet(type_idx, field_idx) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let struct_ref = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStructSet(type_idx, field_idx, struct_ref, val))
    }

    // === GC: Arrays ===
    ArrayNew(type_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let init = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TArrayNew(type_idx, init, len))
    }
    ArrayNewDefault(type_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TArrayNewDefault(type_idx, len))
    }
    ArrayNewFixed(type_idx, n) => {
      let elems = match pop_n(stack, n.0.reinterpret_as_int()) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TArrayNewFixed(type_idx, elems))
    }
    ArrayNewData(type_idx, data_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let offset = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TArrayNewData(type_idx, data_idx, offset, len))
    }
    ArrayNewElem(type_idx, elem_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let offset = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TArrayNewElem(type_idx, elem_idx, offset, len))
    }
    ArrayGet(type_idx) => {
      let idx = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TArrayGet(type_idx, arr, idx))
    }
    ArrayGetS(type_idx) => {
      let idx = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TArrayGetS(type_idx, arr, idx))
    }
    ArrayGetU(type_idx) => {
      let idx = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TArrayGetU(type_idx, arr, idx))
    }
    ArraySet(type_idx) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let idx = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TArraySet(type_idx, arr, idx, val))
    }
    ArrayFill(type_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let offset = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TArrayFill(type_idx, arr, offset, val, len))
    }
    ArrayCopy(dst_type, src_type) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let src_offset = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let src = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let dst_offset = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let dst = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TArrayCopy(dst_type, src_type, dst, dst_offset, src, src_offset, len),
      )
    }
    ArrayInitData(type_idx, data_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let src = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let dst = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TArrayInitData(type_idx, data_idx, arr, dst, src, len))
    }
    ArrayInitElem(type_idx, elem_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let src = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let dst = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TArrayInitElem(type_idx, elem_idx, arr, dst, src, len))
    }

    // === GC: Casts ===
    RefTest(nullable, ht) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TRefTest(nullable, ht, ref_))
    }
    RefCast(nullable, ht) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TRefCast(nullable, ht, ref_))
    }

    // === SIMD ===
    V128Load(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(V128LoadOp, memarg, addr))
    }
    V128Load8x8S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(V128Load8x8SOp, memarg, addr))
    }
    V128Load8x8U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(V128Load8x8UOp, memarg, addr))
    }
    V128Load16x4S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(V128Load16x4SOp, memarg, addr))
    }
    V128Load16x4U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(V128Load16x4UOp, memarg, addr))
    }
    V128Load32x2S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(V128Load32x2SOp, memarg, addr))
    }
    V128Load32x2U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(V128Load32x2UOp, memarg, addr))
    }
    V128Load8Splat(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(V128Load8SplatOp, memarg, addr))
    }
    V128Load16Splat(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(V128Load16SplatOp, memarg, addr))
    }
    V128Load32Splat(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(V128Load32SplatOp, memarg, addr))
    }
    V128Load64Splat(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(V128Load64SplatOp, memarg, addr))
    }
    V128Load32Zero(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(V128Load32ZeroOp, memarg, addr))
    }
    V128Load64Zero(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TLoad(V128Load64ZeroOp, memarg, addr))
    }
    V128Store(memarg) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TStore(V128StoreOp, memarg, addr, val))
    }
    V128Load8Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128LoadLane(V128Load8LaneOp, memarg, lane, addr, vec))
    }
    V128Load16Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128LoadLane(V128Load16LaneOp, memarg, lane, addr, vec))
    }
    V128Load32Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128LoadLane(V128Load32LaneOp, memarg, lane, addr, vec))
    }
    V128Load64Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128LoadLane(V128Load64LaneOp, memarg, lane, addr, vec))
    }
    V128Store8Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128StoreLane(V128Store8LaneOp, memarg, lane, addr, vec))
    }
    V128Store16Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128StoreLane(V128Store16LaneOp, memarg, lane, addr, vec))
    }
    V128Store32Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128StoreLane(V128Store32LaneOp, memarg, lane, addr, vec))
    }
    V128Store64Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128StoreLane(V128Store64LaneOp, memarg, lane, addr, vec))
    }

    // === SIMD: Splat ===
    I8x16Splat => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TI8x16Splat(val))
    }
    I16x8Splat => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TI16x8Splat(val))
    }
    I32x4Splat => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TI32x4Splat(val))
    }
    I64x2Splat => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TI64x2Splat(val))
    }
    F32x4Splat => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TF32x4Splat(val))
    }
    F64x2Splat => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TF64x2Splat(val))
    }

    // === SIMD: Extract lane ===
    I8x16ExtractLaneS(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TExtractLane(I8x16ExtractLaneSOp, lane, vec))
    }
    I8x16ExtractLaneU(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TExtractLane(I8x16ExtractLaneUOp, lane, vec))
    }
    I16x8ExtractLaneS(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TExtractLane(I16x8ExtractLaneSOp, lane, vec))
    }
    I16x8ExtractLaneU(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TExtractLane(I16x8ExtractLaneUOp, lane, vec))
    }
    I32x4ExtractLane(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TExtractLane(I32x4ExtractLaneOp, lane, vec))
    }
    I64x2ExtractLane(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TExtractLane(I64x2ExtractLaneOp, lane, vec))
    }
    F32x4ExtractLane(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TExtractLane(F32x4ExtractLaneOp, lane, vec))
    }
    F64x2ExtractLane(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TExtractLane(F64x2ExtractLaneOp, lane, vec))
    }

    // === SIMD: Replace lane ===
    I8x16ReplaceLane(lane) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TReplaceLane(I8x16ReplaceLaneOp, lane, vec, val))
    }
    I16x8ReplaceLane(lane) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TReplaceLane(I16x8ReplaceLaneOp, lane, vec, val))
    }
    I32x4ReplaceLane(lane) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TReplaceLane(I32x4ReplaceLaneOp, lane, vec, val))
    }
    I64x2ReplaceLane(lane) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TReplaceLane(I64x2ReplaceLaneOp, lane, vec, val))
    }
    F32x4ReplaceLane(lane) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TReplaceLane(F32x4ReplaceLaneOp, lane, vec, val))
    }
    F64x2ReplaceLane(lane) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TReplaceLane(F64x2ReplaceLaneOp, lane, vec, val))
    }

    // === SIMD: Shuffle/Swizzle ===
    I8x16Shuffle(
      l0,
      l1,
      l2,
      l3,
      l4,
      l5,
      l6,
      l7,
      l8,
      l9,
      l10,
      l11,
      l12,
      l13,
      l14,
      l15
    ) => {
      let v2 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v1 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TI8x16Shuffle(
          l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15, v1,
          v2,
        ),
      )
    }
    I8x16Swizzle => {
      let indices = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TI8x16Swizzle(vec, indices))
    }
    I8x16RelaxedSwizzle => {
      let indices = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TI8x16RelaxedSwizzle(vec, indices))
    }

    // === SIMD: Unary v128 -> v128 ===
    V128Not => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(V128NotOp, op))
    }
    I8x16Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I8x16AbsOp, op))
    }
    I8x16Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I8x16NegOp, op))
    }
    I8x16Popcnt => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I8x16PopcntOp, op))
    }
    I16x8Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I16x8AbsOp, op))
    }
    // === SIMD: Unary v128 -> v128 (continued) ===
    I16x8Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I16x8NegOp, op))
    }
    I32x4Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4AbsOp, op))
    }
    I32x4Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4NegOp, op))
    }
    I64x2Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64x2AbsOp, op))
    }
    I64x2Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64x2NegOp, op))
    }
    F32x4Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32x4AbsOp, op))
    }
    F32x4Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32x4NegOp, op))
    }
    F32x4Sqrt => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32x4SqrtOp, op))
    }
    F32x4Ceil => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32x4CeilOp, op))
    }
    F32x4Floor => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32x4FloorOp, op))
    }
    F32x4Trunc => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32x4TruncOp, op))
    }
    F32x4Nearest => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32x4NearestOp, op))
    }
    F64x2Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64x2AbsOp, op))
    }
    F64x2Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64x2NegOp, op))
    }
    F64x2Sqrt => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64x2SqrtOp, op))
    }
    F64x2Ceil => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64x2CeilOp, op))
    }
    F64x2Floor => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64x2FloorOp, op))
    }
    F64x2Trunc => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64x2TruncOp, op))
    }
    F64x2Nearest => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64x2NearestOp, op))
    }

    // === SIMD: v128 -> i32 (bitmask/alltrue) ===
    V128AnyTrue => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(V128AnyTrueOp, op))
    }
    I8x16AllTrue => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I8x16AllTrueOp, op))
    }
    I8x16Bitmask => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I8x16BitmaskOp, op))
    }
    I16x8AllTrue => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I16x8AllTrueOp, op))
    }
    I16x8Bitmask => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I16x8BitmaskOp, op))
    }
    I32x4AllTrue => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4AllTrueOp, op))
    }
    I32x4Bitmask => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4BitmaskOp, op))
    }
    I64x2AllTrue => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64x2AllTrueOp, op))
    }
    I64x2Bitmask => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64x2BitmaskOp, op))
    }

    // === SIMD: Extend (v128 -> v128) ===
    I16x8ExtendLowI8x16S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I16x8ExtendLowI8x16SOp, op))
    }
    I16x8ExtendHighI8x16S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I16x8ExtendHighI8x16SOp, op))
    }
    I16x8ExtendLowI8x16U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I16x8ExtendLowI8x16UOp, op))
    }
    I16x8ExtendHighI8x16U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I16x8ExtendHighI8x16UOp, op))
    }
    I32x4ExtendLowI16x8S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4ExtendLowI16x8SOp, op))
    }
    I32x4ExtendHighI16x8S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4ExtendHighI16x8SOp, op))
    }
    I32x4ExtendLowI16x8U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4ExtendLowI16x8UOp, op))
    }
    I32x4ExtendHighI16x8U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4ExtendHighI16x8UOp, op))
    }
    I64x2ExtendLowI32x4S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64x2ExtendLowI32x4SOp, op))
    }
    I64x2ExtendHighI32x4S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64x2ExtendHighI32x4SOp, op))
    }
    I64x2ExtendLowI32x4U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64x2ExtendLowI32x4UOp, op))
    }
    I64x2ExtendHighI32x4U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I64x2ExtendHighI32x4UOp, op))
    }

    // === SIMD: Pairwise add (v128 -> v128) ===
    I16x8ExtaddPairwiseI8x16S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I16x8ExtaddPairwiseI8x16SOp, op))
    }
    I16x8ExtaddPairwiseI8x16U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I16x8ExtaddPairwiseI8x16UOp, op))
    }
    I32x4ExtaddPairwiseI16x8S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4ExtaddPairwiseI16x8SOp, op))
    }
    I32x4ExtaddPairwiseI16x8U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4ExtaddPairwiseI16x8UOp, op))
    }

    // === SIMD: Conversion (v128 -> v128) ===
    F32x4DemoteF64x2Zero => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32x4DemoteF64x2ZeroOp, op))
    }
    F64x2PromoteLowF32x4 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64x2PromoteLowF32x4Op, op))
    }
    I32x4TruncSatF32x4S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4TruncSatF32x4SOp, op))
    }
    I32x4TruncSatF32x4U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4TruncSatF32x4UOp, op))
    }
    F32x4ConvertI32x4S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32x4ConvertI32x4SOp, op))
    }
    F32x4ConvertI32x4U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F32x4ConvertI32x4UOp, op))
    }
    I32x4TruncSatF64x2SZero => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4TruncSatF64x2SZeroOp, op))
    }
    I32x4TruncSatF64x2UZero => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4TruncSatF64x2UZeroOp, op))
    }
    F64x2ConvertLowI32x4S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64x2ConvertLowI32x4SOp, op))
    }
    F64x2ConvertLowI32x4U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(F64x2ConvertLowI32x4UOp, op))
    }

    // === SIMD: Relaxed truncation (v128 -> v128) ===
    I32x4RelaxedTruncF32x4S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4RelaxedTruncF32x4SOp, op))
    }
    I32x4RelaxedTruncF32x4U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4RelaxedTruncF32x4UOp, op))
    }
    I32x4RelaxedTruncZeroF64x2S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4RelaxedTruncZeroF64x2SOp, op))
    }
    I32x4RelaxedTruncZeroF64x2U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TUnary(I32x4RelaxedTruncZeroF64x2UOp, op))
    }

    // === SIMD: Binary bitwise (v128, v128 -> v128) ===
    V128And => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(V128AndOp, lhs, rhs))
    }
    V128Andnot => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(V128AndnotOp, lhs, rhs))
    }
    V128Or => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(V128OrOp, lhs, rhs))
    }
    V128Xor => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(V128XorOp, lhs, rhs))
    }

    // === SIMD: i8x16 comparisons ===
    I8x16Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16EqOp, lhs, rhs))
    }
    I8x16Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16NeOp, lhs, rhs))
    }
    I8x16LtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16LtSOp, lhs, rhs))
    }
    I8x16LtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16LtUOp, lhs, rhs))
    }
    I8x16GtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16GtSOp, lhs, rhs))
    }
    I8x16GtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16GtUOp, lhs, rhs))
    }
    I8x16LeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16LeSOp, lhs, rhs))
    }
    I8x16LeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16LeUOp, lhs, rhs))
    }
    I8x16GeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16GeSOp, lhs, rhs))
    }
    I8x16GeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16GeUOp, lhs, rhs))
    }

    // === SIMD: i16x8 comparisons ===
    I16x8Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8EqOp, lhs, rhs))
    }
    I16x8Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8NeOp, lhs, rhs))
    }
    I16x8LtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8LtSOp, lhs, rhs))
    }
    I16x8LtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8LtUOp, lhs, rhs))
    }
    I16x8GtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8GtSOp, lhs, rhs))
    }
    I16x8GtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8GtUOp, lhs, rhs))
    }
    I16x8LeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8LeSOp, lhs, rhs))
    }
    I16x8LeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8LeUOp, lhs, rhs))
    }
    I16x8GeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8GeSOp, lhs, rhs))
    }
    I16x8GeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8GeUOp, lhs, rhs))
    }

    // === SIMD: i32x4 comparisons ===
    I32x4Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4EqOp, lhs, rhs))
    }
    I32x4Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4NeOp, lhs, rhs))
    }
    I32x4LtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4LtSOp, lhs, rhs))
    }
    I32x4LtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4LtUOp, lhs, rhs))
    }
    I32x4GtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4GtSOp, lhs, rhs))
    }
    I32x4GtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4GtUOp, lhs, rhs))
    }
    I32x4LeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4LeSOp, lhs, rhs))
    }
    I32x4LeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4LeUOp, lhs, rhs))
    }
    I32x4GeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4GeSOp, lhs, rhs))
    }
    I32x4GeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4GeUOp, lhs, rhs))
    }

    // === SIMD: i64x2 comparisons ===
    I64x2Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64x2EqOp, lhs, rhs))
    }
    I64x2Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64x2NeOp, lhs, rhs))
    }
    I64x2LtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64x2LtSOp, lhs, rhs))
    }
    I64x2GtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64x2GtSOp, lhs, rhs))
    }
    I64x2LeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64x2LeSOp, lhs, rhs))
    }
    I64x2GeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64x2GeSOp, lhs, rhs))
    }

    // === SIMD: f32x4 comparisons ===
    F32x4Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4EqOp, lhs, rhs))
    }
    F32x4Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4NeOp, lhs, rhs))
    }
    F32x4Lt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4LtOp, lhs, rhs))
    }
    F32x4Gt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4GtOp, lhs, rhs))
    }
    F32x4Le => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4LeOp, lhs, rhs))
    }
    F32x4Ge => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4GeOp, lhs, rhs))
    }

    // === SIMD: f64x2 comparisons ===
    F64x2Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2EqOp, lhs, rhs))
    }
    F64x2Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2NeOp, lhs, rhs))
    }
    F64x2Lt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2LtOp, lhs, rhs))
    }
    F64x2Gt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2GtOp, lhs, rhs))
    }
    F64x2Le => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2LeOp, lhs, rhs))
    }
    F64x2Ge => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2GeOp, lhs, rhs))
    }

    // === SIMD: i8x16 arithmetic ===
    I8x16Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16AddOp, lhs, rhs))
    }
    I8x16AddSatS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16AddSatSOp, lhs, rhs))
    }
    I8x16AddSatU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16AddSatUOp, lhs, rhs))
    }
    I8x16Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16SubOp, lhs, rhs))
    }
    I8x16SubSatS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16SubSatSOp, lhs, rhs))
    }
    I8x16SubSatU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16SubSatUOp, lhs, rhs))
    }
    I8x16MinS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16MinSOp, lhs, rhs))
    }
    I8x16MinU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16MinUOp, lhs, rhs))
    }
    I8x16MaxS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16MaxSOp, lhs, rhs))
    }
    I8x16MaxU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16MaxUOp, lhs, rhs))
    }
    I8x16AvgrU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16AvgrUOp, lhs, rhs))
    }
    I8x16NarrowI16x8S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16NarrowI16x8SOp, lhs, rhs))
    }
    I8x16NarrowI16x8U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I8x16NarrowI16x8UOp, lhs, rhs))
    }

    // === SIMD: i16x8 arithmetic ===
    I16x8Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8AddOp, lhs, rhs))
    }
    I16x8AddSatS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8AddSatSOp, lhs, rhs))
    }
    I16x8AddSatU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8AddSatUOp, lhs, rhs))
    }
    I16x8Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8SubOp, lhs, rhs))
    }
    I16x8SubSatS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8SubSatSOp, lhs, rhs))
    }
    I16x8SubSatU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8SubSatUOp, lhs, rhs))
    }
    I16x8Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8MulOp, lhs, rhs))
    }
    I16x8MinS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8MinSOp, lhs, rhs))
    }
    I16x8MinU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8MinUOp, lhs, rhs))
    }
    I16x8MaxS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8MaxSOp, lhs, rhs))
    }
    I16x8MaxU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8MaxUOp, lhs, rhs))
    }
    I16x8AvgrU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8AvgrUOp, lhs, rhs))
    }
    I16x8Q15mulrSatS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8Q15mulrSatSOp, lhs, rhs))
    }
    I16x8NarrowI32x4S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8NarrowI32x4SOp, lhs, rhs))
    }
    I16x8NarrowI32x4U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8NarrowI32x4UOp, lhs, rhs))
    }
    I16x8ExtmulLowI8x16S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8ExtmulLowI8x16SOp, lhs, rhs))
    }
    I16x8ExtmulHighI8x16S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8ExtmulHighI8x16SOp, lhs, rhs))
    }
    I16x8ExtmulLowI8x16U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8ExtmulLowI8x16UOp, lhs, rhs))
    }
    I16x8ExtmulHighI8x16U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8ExtmulHighI8x16UOp, lhs, rhs))
    }

    // === SIMD: i32x4 arithmetic ===
    I32x4Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4AddOp, lhs, rhs))
    }
    I32x4Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4SubOp, lhs, rhs))
    }
    I32x4Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4MulOp, lhs, rhs))
    }
    I32x4MinS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4MinSOp, lhs, rhs))
    }
    I32x4MinU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4MinUOp, lhs, rhs))
    }
    I32x4MaxS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4MaxSOp, lhs, rhs))
    }
    I32x4MaxU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4MaxUOp, lhs, rhs))
    }
    I32x4DotI16x8S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4DotI16x8SOp, lhs, rhs))
    }
    I32x4ExtmulLowI16x8S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4ExtmulLowI16x8SOp, lhs, rhs))
    }
    I32x4ExtmulHighI16x8S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4ExtmulHighI16x8SOp, lhs, rhs))
    }
    I32x4ExtmulLowI16x8U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4ExtmulLowI16x8UOp, lhs, rhs))
    }
    I32x4ExtmulHighI16x8U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I32x4ExtmulHighI16x8UOp, lhs, rhs))
    }

    // === SIMD: i64x2 arithmetic ===
    I64x2Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64x2AddOp, lhs, rhs))
    }
    I64x2Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64x2SubOp, lhs, rhs))
    }
    I64x2Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64x2MulOp, lhs, rhs))
    }
    I64x2ExtmulLowI32x4S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64x2ExtmulLowI32x4SOp, lhs, rhs))
    }
    I64x2ExtmulHighI32x4S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64x2ExtmulHighI32x4SOp, lhs, rhs))
    }
    I64x2ExtmulLowI32x4U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64x2ExtmulLowI32x4UOp, lhs, rhs))
    }
    I64x2ExtmulHighI32x4U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I64x2ExtmulHighI32x4UOp, lhs, rhs))
    }

    // === SIMD: f32x4 arithmetic ===
    F32x4Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4AddOp, lhs, rhs))
    }
    F32x4Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4SubOp, lhs, rhs))
    }
    F32x4Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4MulOp, lhs, rhs))
    }
    F32x4Div => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4DivOp, lhs, rhs))
    }
    F32x4Min => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4MinOp, lhs, rhs))
    }
    F32x4Max => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4MaxOp, lhs, rhs))
    }
    F32x4Pmin => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4PminOp, lhs, rhs))
    }
    F32x4Pmax => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4PmaxOp, lhs, rhs))
    }

    // === SIMD: f64x2 arithmetic ===
    F64x2Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2AddOp, lhs, rhs))
    }
    F64x2Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2SubOp, lhs, rhs))
    }
    F64x2Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2MulOp, lhs, rhs))
    }
    F64x2Div => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2DivOp, lhs, rhs))
    }
    F64x2Min => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2MinOp, lhs, rhs))
    }
    F64x2Max => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2MaxOp, lhs, rhs))
    }
    F64x2Pmin => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2PminOp, lhs, rhs))
    }
    F64x2Pmax => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2PmaxOp, lhs, rhs))
    }

    // === SIMD: Relaxed binary ===
    F32x4RelaxedMin => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4RelaxedMinOp, lhs, rhs))
    }
    F32x4RelaxedMax => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F32x4RelaxedMaxOp, lhs, rhs))
    }
    F64x2RelaxedMin => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2RelaxedMinOp, lhs, rhs))
    }
    F64x2RelaxedMax => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(F64x2RelaxedMaxOp, lhs, rhs))
    }
    I16x8RelaxedQ15mulrS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8RelaxedQ15mulrSOp, lhs, rhs))
    }
    I16x8RelaxedDotI8x16I7x16S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TBinary(I16x8RelaxedDotI8x16I7x16SOp, lhs, rhs))
    }

    // === SIMD: Shift (v128, i32 -> v128) ===
    I8x16Shl => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Shift(I8x16ShlOp, vec, shift))
    }
    I8x16ShrS => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Shift(I8x16ShrSOp, vec, shift))
    }
    I8x16ShrU => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Shift(I8x16ShrUOp, vec, shift))
    }
    I16x8Shl => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Shift(I16x8ShlOp, vec, shift))
    }
    I16x8ShrS => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Shift(I16x8ShrSOp, vec, shift))
    }
    I16x8ShrU => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Shift(I16x8ShrUOp, vec, shift))
    }
    I32x4Shl => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Shift(I32x4ShlOp, vec, shift))
    }
    I32x4ShrS => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Shift(I32x4ShrSOp, vec, shift))
    }
    I32x4ShrU => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Shift(I32x4ShrUOp, vec, shift))
    }
    I64x2Shl => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Shift(I64x2ShlOp, vec, shift))
    }
    I64x2ShrS => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Shift(I64x2ShrSOp, vec, shift))
    }
    I64x2ShrU => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Shift(I64x2ShrUOp, vec, shift))
    }

    // === SIMD: Ternary (v128, v128, v128 -> v128) ===
    V128Bitselect => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v2 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v1 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Ternary(V128BitselectOp, v1, v2, c))
    }
    I8x16RelaxedLaneselect => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v2 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v1 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Ternary(I8x16RelaxedLaneselectOp, v1, v2, c))
    }
    I16x8RelaxedLaneselect => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v2 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v1 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Ternary(I16x8RelaxedLaneselectOp, v1, v2, c))
    }
    I32x4RelaxedLaneselect => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v2 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v1 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Ternary(I32x4RelaxedLaneselectOp, v1, v2, c))
    }
    I64x2RelaxedLaneselect => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v2 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v1 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Ternary(I64x2RelaxedLaneselectOp, v1, v2, c))
    }
    F32x4RelaxedMadd => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let b = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let a = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Ternary(F32x4RelaxedMaddOp, a, b, c))
    }
    F32x4RelaxedNmadd => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let b = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let a = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Ternary(F32x4RelaxedNmaddOp, a, b, c))
    }
    F64x2RelaxedMadd => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let b = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let a = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Ternary(F64x2RelaxedMaddOp, a, b, c))
    }
    F64x2RelaxedNmadd => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let b = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let a = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Ternary(F64x2RelaxedNmaddOp, a, b, c))
    }
    I32x4RelaxedDotI8x16I7x16AddS => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let b = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let a = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TV128Ternary(I32x4RelaxedDotI8x16I7x16AddSOp, a, b, c))
    }
  }
  Ok(())
}

// ============================================================================
// TExpr -> Expr helpers
// ============================================================================

///|
fn tinstr_to_instr(tinstr : TInstr, instrs : Array[Instruction]) -> Unit {
  match tinstr {
    // === Constants ===
    TI32Const(v) => instrs.push(I32Const(v))
    TI64Const(v) => instrs.push(I64Const(v))
    TF32Const(v) => instrs.push(F32Const(v))
    TF64Const(v) => instrs.push(F64Const(v))
    TRefNull(ht) => instrs.push(RefNull(ht))
    TRefFunc(idx) => instrs.push(RefFunc(idx))
    TV128Const(
      b0,
      b1,
      b2,
      b3,
      b4,
      b5,
      b6,
      b7,
      b8,
      b9,
      b10,
      b11,
      b12,
      b13,
      b14,
      b15
    ) =>
      instrs.push(
        V128Const(
          b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15,
        ),
      )

    // === Nullary ===
    TUnreachable => instrs.push(Unreachable)
    TNop => instrs.push(Nop)
    TLocalGet(idx) => instrs.push(LocalGet(idx))
    TGlobalGet(idx) => instrs.push(GlobalGet(idx))
    TMemorySize(idx) => instrs.push(MemorySize(idx))
    TTableSize(idx) => instrs.push(TableSize(idx))

    // === Unary ===
    TUnary(op, child) => {
      tinstr_to_instr(child, instrs)
      instrs.push(unary_op_to_instr(op))
    }
    TDrop(child) => {
      tinstr_to_instr(child, instrs)
      instrs.push(Drop)
    }
    TLocalSet(idx, child) => {
      tinstr_to_instr(child, instrs)
      instrs.push(LocalSet(idx))
    }
    TLocalTee(idx, child) => {
      tinstr_to_instr(child, instrs)
      instrs.push(LocalTee(idx))
    }
    TGlobalSet(idx, child) => {
      tinstr_to_instr(child, instrs)
      instrs.push(GlobalSet(idx))
    }
    TRefIsNull(child) => {
      tinstr_to_instr(child, instrs)
      instrs.push(RefIsNull)
    }
    TRefAsNonNull(child) => {
      tinstr_to_instr(child, instrs)
      instrs.push(RefAsNonNull)
    }
    TI31GetS(child) => {
      tinstr_to_instr(child, instrs)
      instrs.push(I31GetS)
    }
    TI31GetU(child) => {
      tinstr_to_instr(child, instrs)
      instrs.push(I31GetU)
    }
    TRefI31(child) => {
      tinstr_to_instr(child, instrs)
      instrs.push(RefI31)
    }
    TArrayLen(child) => {
      tinstr_to_instr(child, instrs)
      instrs.push(ArrayLen)
    }
    TAnyConvertExtern(child) => {
      tinstr_to_instr(child, instrs)
      instrs.push(AnyConvertExtern)
    }
    TExternConvertAny(child) => {
      tinstr_to_instr(child, instrs)
      instrs.push(ExternConvertAny)
    }
    TThrowRef(child) => {
      tinstr_to_instr(child, instrs)
      instrs.push(ThrowRef)
    }

    // === Binary ===
    TBinary(op, lhs, rhs) => {
      tinstr_to_instr(lhs, instrs)
      tinstr_to_instr(rhs, instrs)
      instrs.push(binary_op_to_instr(op))
    }
    TRefEq(lhs, rhs) => {
      tinstr_to_instr(lhs, instrs)
      tinstr_to_instr(rhs, instrs)
      instrs.push(RefEq)
    }
    TStore(op, memarg, addr, value) => {
      tinstr_to_instr(addr, instrs)
      tinstr_to_instr(value, instrs)
      instrs.push(store_op_to_instr(op, memarg))
    }

    // === Load ===
    TLoad(op, memarg, addr) => {
      tinstr_to_instr(addr, instrs)
      instrs.push(load_op_to_instr(op, memarg))
    }

    // === Memory operations ===
    TMemoryGrow(idx, pages) => {
      tinstr_to_instr(pages, instrs)
      instrs.push(MemoryGrow(idx))
    }
    TMemoryFill(idx, dest, val, len) => {
      tinstr_to_instr(dest, instrs)
      tinstr_to_instr(val, instrs)
      tinstr_to_instr(len, instrs)
      instrs.push(MemoryFill(idx))
    }
    TMemoryCopy(dst, src, dst_addr, src_addr, len) => {
      tinstr_to_instr(dst_addr, instrs)
      tinstr_to_instr(src_addr, instrs)
      tinstr_to_instr(len, instrs)
      instrs.push(MemoryCopy(dst, src))
    }
    TMemoryInit(data_idx, mem_idx, dst, src, len) => {
      tinstr_to_instr(dst, instrs)
      tinstr_to_instr(src, instrs)
      tinstr_to_instr(len, instrs)
      instrs.push(MemoryInit(data_idx, mem_idx))
    }
    TDataDrop(idx) => instrs.push(DataDrop(idx))

    // === Table operations ===
    TTableGet(idx, i) => {
      tinstr_to_instr(i, instrs)
      instrs.push(TableGet(idx))
    }
    TTableSet(idx, i, val) => {
      tinstr_to_instr(i, instrs)
      tinstr_to_instr(val, instrs)
      instrs.push(TableSet(idx))
    }
    TTableGrow(idx, val, n) => {
      tinstr_to_instr(val, instrs)
      tinstr_to_instr(n, instrs)
      instrs.push(TableGrow(idx))
    }
    TTableFill(idx, i, val, n) => {
      tinstr_to_instr(i, instrs)
      tinstr_to_instr(val, instrs)
      tinstr_to_instr(n, instrs)
      instrs.push(TableFill(idx))
    }
    TTableCopy(dst, src, d, s, n) => {
      tinstr_to_instr(d, instrs)
      tinstr_to_instr(s, instrs)
      tinstr_to_instr(n, instrs)
      instrs.push(TableCopy(dst, src))
    }
    TTableInit(elem_idx, table_idx, d, s, n) => {
      tinstr_to_instr(d, instrs)
      tinstr_to_instr(s, instrs)
      tinstr_to_instr(n, instrs)
      instrs.push(TableInit(elem_idx, table_idx))
    }
    TElemDrop(idx) => instrs.push(ElemDrop(idx))

    // === Calls ===
    TCall(func_idx, args) => {
      for arg in args {
        tinstr_to_instr(arg, instrs)
      }
      instrs.push(Call(func_idx))
    }
    TCallIndirect(type_idx, table_idx, args, idx) => {
      for arg in args {
        tinstr_to_instr(arg, instrs)
      }
      tinstr_to_instr(idx, instrs)
      instrs.push(CallIndirect(type_idx, table_idx))
    }
    TCallRef(type_idx, args, ref_) => {
      for arg in args {
        tinstr_to_instr(arg, instrs)
      }
      tinstr_to_instr(ref_, instrs)
      instrs.push(CallRef(type_idx))
    }
    TReturnCall(func_idx, args) => {
      for arg in args {
        tinstr_to_instr(arg, instrs)
      }
      instrs.push(ReturnCall(func_idx))
    }
    TReturnCallIndirect(type_idx, table_idx, args, idx) => {
      for arg in args {
        tinstr_to_instr(arg, instrs)
      }
      tinstr_to_instr(idx, instrs)
      instrs.push(ReturnCallIndirect(type_idx, table_idx))
    }
    TReturnCallRef(type_idx, args, ref_) => {
      for arg in args {
        tinstr_to_instr(arg, instrs)
      }
      tinstr_to_instr(ref_, instrs)
      instrs.push(ReturnCallRef(type_idx))
    }

    // === Control flow ===
    TBlock(bt, body) => {
      let body_instrs : Array[Instruction] = []
      for value in body.0 {
        tinstr_to_instr(value, body_instrs)
      }
      instrs.push(Block(bt, Expr(body_instrs)))
    }
    TLoop(bt, body) => {
      let body_instrs : Array[Instruction] = []
      for value in body.0 {
        tinstr_to_instr(value, body_instrs)
      }
      instrs.push(Loop(bt, Expr(body_instrs)))
    }
    TIf(bt, cond, then_branch, else_branch) => {
      tinstr_to_instr(cond, instrs)
      let then_instrs : Array[Instruction] = []
      for value in then_branch.0 {
        tinstr_to_instr(value, then_instrs)
      }
      let else_instrs : Array[Instruction]? = match else_branch {
        Some(else_body) => {
          let els : Array[Instruction] = []
          for value in else_body.0 {
            tinstr_to_instr(value, els)
          }
          Some(els)
        }
        None => None
      }
      instrs.push(If(bt, then_instrs, else_instrs))
    }
    TTryTable(bt, catches, body) => {
      let body_instrs : Array[Instruction] = []
      for value in body.0 {
        tinstr_to_instr(value, body_instrs)
      }
      instrs.push(TryTable(bt, catches, Expr(body_instrs)))
    }
    TThrow(tag_idx, args) => {
      for arg in args {
        tinstr_to_instr(arg, instrs)
      }
      instrs.push(Throw(tag_idx))
    }

    // === Branches ===
    TBr(label, values) => {
      for value in values {
        tinstr_to_instr(value, instrs)
      }
      instrs.push(Br(label))
    }
    TBrIf(label, cond, values) => {
      for value in values {
        tinstr_to_instr(value, instrs)
      }
      tinstr_to_instr(cond, instrs)
      instrs.push(BrIf(label))
    }
    TBrTable(labels, default, idx, values) => {
      for value in values {
        tinstr_to_instr(value, instrs)
      }
      tinstr_to_instr(idx, instrs)
      instrs.push(BrTable(labels, default))
    }
    TBrOnNull(label, ref_, values) => {
      for value in values {
        tinstr_to_instr(value, instrs)
      }
      tinstr_to_instr(ref_, instrs)
      instrs.push(BrOnNull(label))
    }
    TBrOnNonNull(label, ref_, values) => {
      for value in values {
        tinstr_to_instr(value, instrs)
      }
      tinstr_to_instr(ref_, instrs)
      instrs.push(BrOnNonNull(label))
    }
    TBrOnCast(label, castop, ht1, ht2, ref_, values) => {
      for value in values {
        tinstr_to_instr(value, instrs)
      }
      tinstr_to_instr(ref_, instrs)
      instrs.push(BrOnCast(label, castop, ht1, ht2))
    }
    TBrOnCastFail(label, castop, ht1, ht2, ref_, values) => {
      for value in values {
        tinstr_to_instr(value, instrs)
      }
      tinstr_to_instr(ref_, instrs)
      instrs.push(BrOnCastFail(label, castop, ht1, ht2))
    }
    TReturn(values) => {
      for value in values {
        tinstr_to_instr(value, instrs)
      }
      instrs.push(Return)
    }
    // === Select ===
    TSelect(types, cond, val1, val2) => {
      tinstr_to_instr(val1, instrs)
      tinstr_to_instr(val2, instrs)
      tinstr_to_instr(cond, instrs)
      instrs.push(Select(types))
    }

    // === GC: Structs ===
    TStructNew(type_idx, fields) => {
      for field in fields {
        tinstr_to_instr(field, instrs)
      }
      instrs.push(StructNew(type_idx))
    }
    TStructNewDefault(type_idx) => instrs.push(StructNewDefault(type_idx))
    TStructGet(type_idx, field_idx, struct_ref) => {
      tinstr_to_instr(struct_ref, instrs)
      instrs.push(StructGet(type_idx, field_idx))
    }
    TStructGetS(type_idx, field_idx, struct_ref) => {
      tinstr_to_instr(struct_ref, instrs)
      instrs.push(StructGetS(type_idx, field_idx))
    }
    TStructGetU(type_idx, field_idx, struct_ref) => {
      tinstr_to_instr(struct_ref, instrs)
      instrs.push(StructGetU(type_idx, field_idx))
    }
    TStructSet(type_idx, field_idx, struct_ref, val) => {
      tinstr_to_instr(struct_ref, instrs)
      tinstr_to_instr(val, instrs)
      instrs.push(StructSet(type_idx, field_idx))
    }

    // === GC: Arrays ===
    TArrayNew(type_idx, init, len) => {
      tinstr_to_instr(init, instrs)
      tinstr_to_instr(len, instrs)
      instrs.push(ArrayNew(type_idx))
    }
    TArrayNewDefault(type_idx, len) => {
      tinstr_to_instr(len, instrs)
      instrs.push(ArrayNewDefault(type_idx))
    }
    TArrayNewFixed(type_idx, elems) => {
      for elem in elems {
        tinstr_to_instr(elem, instrs)
      }
      instrs.push(
        ArrayNewFixed(type_idx, U32(elems.length().reinterpret_as_uint())),
      )
    }
    TArrayNewData(type_idx, data_idx, offset, len) => {
      tinstr_to_instr(offset, instrs)
      tinstr_to_instr(len, instrs)
      instrs.push(ArrayNewData(type_idx, data_idx))
    }
    TArrayNewElem(type_idx, elem_idx, offset, len) => {
      tinstr_to_instr(offset, instrs)
      tinstr_to_instr(len, instrs)
      instrs.push(ArrayNewElem(type_idx, elem_idx))
    }
    TArrayGet(type_idx, arr, idx) => {
      tinstr_to_instr(arr, instrs)
      tinstr_to_instr(idx, instrs)
      instrs.push(ArrayGet(type_idx))
    }
    TArrayGetS(type_idx, arr, idx) => {
      tinstr_to_instr(arr, instrs)
      tinstr_to_instr(idx, instrs)
      instrs.push(ArrayGetS(type_idx))
    }
    TArrayGetU(type_idx, arr, idx) => {
      tinstr_to_instr(arr, instrs)
      tinstr_to_instr(idx, instrs)
      instrs.push(ArrayGetU(type_idx))
    }
    TArraySet(type_idx, arr, idx, val) => {
      tinstr_to_instr(arr, instrs)
      tinstr_to_instr(idx, instrs)
      tinstr_to_instr(val, instrs)
      instrs.push(ArraySet(type_idx))
    }
    TArrayFill(type_idx, arr, offset, val, len) => {
      tinstr_to_instr(arr, instrs)
      tinstr_to_instr(offset, instrs)
      tinstr_to_instr(val, instrs)
      tinstr_to_instr(len, instrs)
      instrs.push(ArrayFill(type_idx))
    }
    TArrayCopy(dst_type, src_type, dst, dst_offset, src, src_offset, len) => {
      tinstr_to_instr(dst, instrs)
      tinstr_to_instr(dst_offset, instrs)
      tinstr_to_instr(src, instrs)
      tinstr_to_instr(src_offset, instrs)
      tinstr_to_instr(len, instrs)
      instrs.push(ArrayCopy(dst_type, src_type))
    }
    TArrayInitData(type_idx, data_idx, arr, dst, src, len) => {
      tinstr_to_instr(arr, instrs)
      tinstr_to_instr(dst, instrs)
      tinstr_to_instr(src, instrs)
      tinstr_to_instr(len, instrs)
      instrs.push(ArrayInitData(type_idx, data_idx))
    }
    TArrayInitElem(type_idx, elem_idx, arr, dst, src, len) => {
      tinstr_to_instr(arr, instrs)
      tinstr_to_instr(dst, instrs)
      tinstr_to_instr(src, instrs)
      tinstr_to_instr(len, instrs)
      instrs.push(ArrayInitElem(type_idx, elem_idx))
    }

    // === GC: Casts ===
    TRefTest(nullable, ht, ref_) => {
      tinstr_to_instr(ref_, instrs)
      instrs.push(RefTest(nullable, ht))
    }
    TRefCast(nullable, ht, ref_) => {
      tinstr_to_instr(ref_, instrs)
      instrs.push(RefCast(nullable, ht))
    }

    // === SIMD: Splat ===
    TI8x16Splat(val) => {
      tinstr_to_instr(val, instrs)
      instrs.push(I8x16Splat)
    }
    TI16x8Splat(val) => {
      tinstr_to_instr(val, instrs)
      instrs.push(I16x8Splat)
    }
    TI32x4Splat(val) => {
      tinstr_to_instr(val, instrs)
      instrs.push(I32x4Splat)
    }
    TI64x2Splat(val) => {
      tinstr_to_instr(val, instrs)
      instrs.push(I64x2Splat)
    }
    TF32x4Splat(val) => {
      tinstr_to_instr(val, instrs)
      instrs.push(F32x4Splat)
    }
    TF64x2Splat(val) => {
      tinstr_to_instr(val, instrs)
      instrs.push(F64x2Splat)
    }

    // === SIMD: Extract lane ===
    TExtractLane(op, lane, vec) => {
      tinstr_to_instr(vec, instrs)
      instrs.push(extract_lane_op_to_instr(op, lane))
    }

    // === SIMD: Replace lane ===
    TReplaceLane(op, lane, vec, val) => {
      tinstr_to_instr(vec, instrs)
      tinstr_to_instr(val, instrs)
      instrs.push(replace_lane_op_to_instr(op, lane))
    }

    // === SIMD: Shuffle ===
    TI8x16Shuffle(
      l0,
      l1,
      l2,
      l3,
      l4,
      l5,
      l6,
      l7,
      l8,
      l9,
      l10,
      l11,
      l12,
      l13,
      l14,
      l15,
      v1,
      v2
    ) => {
      tinstr_to_instr(v1, instrs)
      tinstr_to_instr(v2, instrs)
      instrs.push(
        I8x16Shuffle(
          l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15,
        ),
      )
    }

    // === SIMD: Swizzle ===
    TI8x16Swizzle(vec, indices) => {
      tinstr_to_instr(vec, instrs)
      tinstr_to_instr(indices, instrs)
      instrs.push(I8x16Swizzle)
    }
    TI8x16RelaxedSwizzle(vec, indices) => {
      tinstr_to_instr(vec, instrs)
      tinstr_to_instr(indices, instrs)
      instrs.push(I8x16RelaxedSwizzle)
    }

    // === SIMD: Shift ===
    TV128Shift(op, vec, shift) => {
      tinstr_to_instr(vec, instrs)
      tinstr_to_instr(shift, instrs)
      instrs.push(v128_shift_op_to_instr(op))
    }

    // === SIMD: Ternary ===
    TV128Ternary(op, v1, v2, v3) => {
      tinstr_to_instr(v1, instrs)
      tinstr_to_instr(v2, instrs)
      tinstr_to_instr(v3, instrs)
      instrs.push(v128_ternary_op_to_instr(op))
    }

    // === SIMD: Lane load ===
    TV128LoadLane(op, memarg, lane, addr, vec) => {
      tinstr_to_instr(addr, instrs)
      tinstr_to_instr(vec, instrs)
      instrs.push(v128_load_lane_op_to_instr(op, memarg, lane))
    }

    // === SIMD: Lane store ===
    TV128StoreLane(op, memarg, lane, addr, vec) => {
      tinstr_to_instr(addr, instrs)
      tinstr_to_instr(vec, instrs)
      instrs.push(v128_store_lane_op_to_instr(op, memarg, lane))
    }
  }
}

// ============================================================================
// Op to Instruction helpers
// ============================================================================

///|
fn unary_op_to_instr(op : UnaryOp) -> Instruction {
  match op {
    I32EqzOp => I32Eqz
    I64EqzOp => I64Eqz
    I32ClzOp => I32Clz
    I32CtzOp => I32Ctz
    I32PopcntOp => I32Popcnt
    I64ClzOp => I64Clz
    I64CtzOp => I64Ctz
    I64PopcntOp => I64Popcnt
    F32AbsOp => F32Abs
    F32NegOp => F32Neg
    F32CeilOp => F32Ceil
    F32FloorOp => F32Floor
    F32TruncOp => F32Trunc
    F32NearestOp => F32Nearest
    F32SqrtOp => F32Sqrt
    F64AbsOp => F64Abs
    F64NegOp => F64Neg
    F64CeilOp => F64Ceil
    F64FloorOp => F64Floor
    F64TruncOp => F64Trunc
    F64NearestOp => F64Nearest
    F64SqrtOp => F64Sqrt
    I32WrapI64Op => I32WrapI64
    I32TruncF32SOp => I32TruncF32S
    I32TruncF32UOp => I32TruncF32U
    I32TruncF64SOp => I32TruncF64S
    I32TruncF64UOp => I32TruncF64U
    I64ExtendI32SOp => I64ExtendI32S
    I64ExtendI32UOp => I64ExtendI32U
    I64TruncF32SOp => I64TruncF32S
    I64TruncF32UOp => I64TruncF32U
    I64TruncF64SOp => I64TruncF64S
    I64TruncF64UOp => I64TruncF64U
    F32ConvertI32SOp => F32ConvertI32S
    F32ConvertI32UOp => F32ConvertI32U
    F32ConvertI64SOp => F32ConvertI64S
    F32ConvertI64UOp => F32ConvertI64U
    F32DemoteF64Op => F32DemoteF64
    F64ConvertI32SOp => F64ConvertI32S
    F64ConvertI32UOp => F64ConvertI32U
    F64ConvertI64SOp => F64ConvertI64S
    F64ConvertI64UOp => F64ConvertI64U
    F64PromoteF32Op => F64PromoteF32
    I32ReinterpretF32Op => I32ReinterpretF32
    I64ReinterpretF64Op => I64ReinterpretF64
    F32ReinterpretI32Op => F32ReinterpretI32
    F64ReinterpretI64Op => F64ReinterpretI64
    I32Extend8SOp => I32Extend8S
    I32Extend16SOp => I32Extend16S
    I64Extend8SOp => I64Extend8S
    I64Extend16SOp => I64Extend16S
    I64Extend32SOp => I64Extend32S
    I32TruncSatF32SOp => I32TruncSatF32S
    I32TruncSatF32UOp => I32TruncSatF32U
    I32TruncSatF64SOp => I32TruncSatF64S
    I32TruncSatF64UOp => I32TruncSatF64U
    I64TruncSatF32SOp => I64TruncSatF32S
    I64TruncSatF32UOp => I64TruncSatF32U
    I64TruncSatF64SOp => I64TruncSatF64S
    I64TruncSatF64UOp => I64TruncSatF64U
    // SIMD v128 -> v128
    V128NotOp => V128Not
    I8x16AbsOp => I8x16Abs
    I8x16NegOp => I8x16Neg
    I8x16PopcntOp => I8x16Popcnt
    I16x8AbsOp => I16x8Abs
    I16x8NegOp => I16x8Neg
    I32x4AbsOp => I32x4Abs
    I32x4NegOp => I32x4Neg
    I64x2AbsOp => I64x2Abs
    I64x2NegOp => I64x2Neg
    F32x4AbsOp => F32x4Abs
    F32x4NegOp => F32x4Neg
    F32x4SqrtOp => F32x4Sqrt
    F32x4CeilOp => F32x4Ceil
    F32x4FloorOp => F32x4Floor
    F32x4TruncOp => F32x4Trunc
    F32x4NearestOp => F32x4Nearest
    F64x2AbsOp => F64x2Abs
    F64x2NegOp => F64x2Neg
    F64x2SqrtOp => F64x2Sqrt
    F64x2CeilOp => F64x2Ceil
    F64x2FloorOp => F64x2Floor
    F64x2TruncOp => F64x2Trunc
    F64x2NearestOp => F64x2Nearest
    // SIMD v128 -> i32
    V128AnyTrueOp => V128AnyTrue
    I8x16AllTrueOp => I8x16AllTrue
    I8x16BitmaskOp => I8x16Bitmask
    I16x8AllTrueOp => I16x8AllTrue
    I16x8BitmaskOp => I16x8Bitmask
    I32x4AllTrueOp => I32x4AllTrue
    I32x4BitmaskOp => I32x4Bitmask
    I64x2AllTrueOp => I64x2AllTrue
    I64x2BitmaskOp => I64x2Bitmask
    // SIMD extend
    I16x8ExtendLowI8x16SOp => I16x8ExtendLowI8x16S
    I16x8ExtendHighI8x16SOp => I16x8ExtendHighI8x16S
    I16x8ExtendLowI8x16UOp => I16x8ExtendLowI8x16U
    I16x8ExtendHighI8x16UOp => I16x8ExtendHighI8x16U
    I32x4ExtendLowI16x8SOp => I32x4ExtendLowI16x8S
    I32x4ExtendHighI16x8SOp => I32x4ExtendHighI16x8S
    I32x4ExtendLowI16x8UOp => I32x4ExtendLowI16x8U
    I32x4ExtendHighI16x8UOp => I32x4ExtendHighI16x8U
    I64x2ExtendLowI32x4SOp => I64x2ExtendLowI32x4S
    I64x2ExtendHighI32x4SOp => I64x2ExtendHighI32x4S
    I64x2ExtendLowI32x4UOp => I64x2ExtendLowI32x4U
    I64x2ExtendHighI32x4UOp => I64x2ExtendHighI32x4U
    // SIMD pairwise add
    I16x8ExtaddPairwiseI8x16SOp => I16x8ExtaddPairwiseI8x16S
    I16x8ExtaddPairwiseI8x16UOp => I16x8ExtaddPairwiseI8x16U
    I32x4ExtaddPairwiseI16x8SOp => I32x4ExtaddPairwiseI16x8S
    I32x4ExtaddPairwiseI16x8UOp => I32x4ExtaddPairwiseI16x8U
    // SIMD conversion
    F32x4DemoteF64x2ZeroOp => F32x4DemoteF64x2Zero
    F64x2PromoteLowF32x4Op => F64x2PromoteLowF32x4
    I32x4TruncSatF32x4SOp => I32x4TruncSatF32x4S
    I32x4TruncSatF32x4UOp => I32x4TruncSatF32x4U
    F32x4ConvertI32x4SOp => F32x4ConvertI32x4S
    F32x4ConvertI32x4UOp => F32x4ConvertI32x4U
    I32x4TruncSatF64x2SZeroOp => I32x4TruncSatF64x2SZero
    I32x4TruncSatF64x2UZeroOp => I32x4TruncSatF64x2UZero
    F64x2ConvertLowI32x4SOp => F64x2ConvertLowI32x4S
    F64x2ConvertLowI32x4UOp => F64x2ConvertLowI32x4U
    // SIMD relaxed truncation
    I32x4RelaxedTruncF32x4SOp => I32x4RelaxedTruncF32x4S
    I32x4RelaxedTruncF32x4UOp => I32x4RelaxedTruncF32x4U
    I32x4RelaxedTruncZeroF64x2SOp => I32x4RelaxedTruncZeroF64x2S
    I32x4RelaxedTruncZeroF64x2UOp => I32x4RelaxedTruncZeroF64x2U
  }
}

///|
fn binary_op_to_instr(op : BinaryOp) -> Instruction {
  match op {
    I32EqOp => I32Eq
    I32NeOp => I32Ne
    I32LtSOp => I32LtS
    I32LtUOp => I32LtU
    I32GtSOp => I32GtS
    I32GtUOp => I32GtU
    I32LeSOp => I32LeS
    I32LeUOp => I32LeU
    I32GeSOp => I32GeS
    I32GeUOp => I32GeU
    I64EqOp => I64Eq
    I64NeOp => I64Ne
    I64LtSOp => I64LtS
    I64LtUOp => I64LtU
    I64GtSOp => I64GtS
    I64GtUOp => I64GtU
    I64LeSOp => I64LeS
    I64LeUOp => I64LeU
    I64GeSOp => I64GeS
    I64GeUOp => I64GeU
    F32EqOp => F32Eq
    F32NeOp => F32Ne
    F32LtOp => F32Lt
    F32GtOp => F32Gt
    F32LeOp => F32Le
    F32GeOp => F32Ge
    F64EqOp => F64Eq
    F64NeOp => F64Ne
    F64LtOp => F64Lt
    F64GtOp => F64Gt
    F64LeOp => F64Le
    F64GeOp => F64Ge
    I32AddOp => I32Add
    I32SubOp => I32Sub
    I32MulOp => I32Mul
    I32DivSOp => I32DivS
    I32DivUOp => I32DivU
    I32RemSOp => I32RemS
    I32RemUOp => I32RemU
    I32AndOp => I32And
    I32OrOp => I32Or
    I32XorOp => I32Xor
    I32ShlOp => I32Shl
    I32ShrSOp => I32ShrS
    I32ShrUOp => I32ShrU
    I32RotlOp => I32Rotl
    I32RotrOp => I32Rotr
    I64AddOp => I64Add
    I64SubOp => I64Sub
    I64MulOp => I64Mul
    I64DivSOp => I64DivS
    I64DivUOp => I64DivU
    I64RemSOp => I64RemS
    I64RemUOp => I64RemU
    I64AndOp => I64And
    I64OrOp => I64Or
    I64XorOp => I64Xor
    I64ShlOp => I64Shl
    I64ShrSOp => I64ShrS
    I64ShrUOp => I64ShrU
    I64RotlOp => I64Rotl
    I64RotrOp => I64Rotr
    F32AddOp => F32Add
    F32SubOp => F32Sub
    F32MulOp => F32Mul
    F32DivOp => F32Div
    F32MinOp => F32Min
    F32MaxOp => F32Max
    F32CopysignOp => F32Copysign
    F64AddOp => F64Add
    F64SubOp => F64Sub
    F64MulOp => F64Mul
    F64DivOp => F64Div
    F64MinOp => F64Min
    F64MaxOp => F64Max
    F64CopysignOp => F64Copysign
    // SIMD bitwise
    V128AndOp => V128And
    V128AndnotOp => V128Andnot
    V128OrOp => V128Or
    V128XorOp => V128Xor
    // SIMD i8x16 comparisons
    I8x16EqOp => I8x16Eq
    I8x16NeOp => I8x16Ne
    I8x16LtSOp => I8x16LtS
    I8x16LtUOp => I8x16LtU
    I8x16GtSOp => I8x16GtS
    I8x16GtUOp => I8x16GtU
    I8x16LeSOp => I8x16LeS
    I8x16LeUOp => I8x16LeU
    I8x16GeSOp => I8x16GeS
    I8x16GeUOp => I8x16GeU
    // SIMD i16x8 comparisons
    I16x8EqOp => I16x8Eq
    I16x8NeOp => I16x8Ne
    I16x8LtSOp => I16x8LtS
    I16x8LtUOp => I16x8LtU
    I16x8GtSOp => I16x8GtS
    I16x8GtUOp => I16x8GtU
    I16x8LeSOp => I16x8LeS
    I16x8LeUOp => I16x8LeU
    I16x8GeSOp => I16x8GeS
    I16x8GeUOp => I16x8GeU
    // SIMD i32x4 comparisons
    I32x4EqOp => I32x4Eq
    I32x4NeOp => I32x4Ne
    I32x4LtSOp => I32x4LtS
    I32x4LtUOp => I32x4LtU
    I32x4GtSOp => I32x4GtS
    I32x4GtUOp => I32x4GtU
    I32x4LeSOp => I32x4LeS
    I32x4LeUOp => I32x4LeU
    I32x4GeSOp => I32x4GeS
    I32x4GeUOp => I32x4GeU
    // SIMD i64x2 comparisons
    I64x2EqOp => I64x2Eq
    I64x2NeOp => I64x2Ne
    I64x2LtSOp => I64x2LtS
    I64x2GtSOp => I64x2GtS
    I64x2LeSOp => I64x2LeS
    I64x2GeSOp => I64x2GeS
    // SIMD f32x4 comparisons
    F32x4EqOp => F32x4Eq
    F32x4NeOp => F32x4Ne
    F32x4LtOp => F32x4Lt
    F32x4GtOp => F32x4Gt
    F32x4LeOp => F32x4Le
    F32x4GeOp => F32x4Ge
    // SIMD f64x2 comparisons
    F64x2EqOp => F64x2Eq
    F64x2NeOp => F64x2Ne
    F64x2LtOp => F64x2Lt
    F64x2GtOp => F64x2Gt
    F64x2LeOp => F64x2Le
    F64x2GeOp => F64x2Ge
    // SIMD i8x16 arithmetic
    I8x16AddOp => I8x16Add
    I8x16AddSatSOp => I8x16AddSatS
    I8x16AddSatUOp => I8x16AddSatU
    I8x16SubOp => I8x16Sub
    I8x16SubSatSOp => I8x16SubSatS
    I8x16SubSatUOp => I8x16SubSatU
    I8x16MinSOp => I8x16MinS
    I8x16MinUOp => I8x16MinU
    I8x16MaxSOp => I8x16MaxS
    I8x16MaxUOp => I8x16MaxU
    I8x16AvgrUOp => I8x16AvgrU
    I8x16NarrowI16x8SOp => I8x16NarrowI16x8S
    I8x16NarrowI16x8UOp => I8x16NarrowI16x8U
    // SIMD i16x8 arithmetic
    I16x8AddOp => I16x8Add
    I16x8AddSatSOp => I16x8AddSatS
    I16x8AddSatUOp => I16x8AddSatU
    I16x8SubOp => I16x8Sub
    I16x8SubSatSOp => I16x8SubSatS
    I16x8SubSatUOp => I16x8SubSatU
    I16x8MulOp => I16x8Mul
    I16x8MinSOp => I16x8MinS
    I16x8MinUOp => I16x8MinU
    I16x8MaxSOp => I16x8MaxS
    I16x8MaxUOp => I16x8MaxU
    I16x8AvgrUOp => I16x8AvgrU
    I16x8Q15mulrSatSOp => I16x8Q15mulrSatS
    I16x8NarrowI32x4SOp => I16x8NarrowI32x4S
    I16x8NarrowI32x4UOp => I16x8NarrowI32x4U
    I16x8ExtmulLowI8x16SOp => I16x8ExtmulLowI8x16S
    I16x8ExtmulHighI8x16SOp => I16x8ExtmulHighI8x16S
    I16x8ExtmulLowI8x16UOp => I16x8ExtmulLowI8x16U
    I16x8ExtmulHighI8x16UOp => I16x8ExtmulHighI8x16U
    // SIMD i32x4 arithmetic
    I32x4AddOp => I32x4Add
    I32x4SubOp => I32x4Sub
    I32x4MulOp => I32x4Mul
    I32x4MinSOp => I32x4MinS
    I32x4MinUOp => I32x4MinU
    I32x4MaxSOp => I32x4MaxS
    I32x4MaxUOp => I32x4MaxU
    I32x4DotI16x8SOp => I32x4DotI16x8S
    I32x4ExtmulLowI16x8SOp => I32x4ExtmulLowI16x8S
    I32x4ExtmulHighI16x8SOp => I32x4ExtmulHighI16x8S
    I32x4ExtmulLowI16x8UOp => I32x4ExtmulLowI16x8U
    I32x4ExtmulHighI16x8UOp => I32x4ExtmulHighI16x8U
    // SIMD i64x2 arithmetic
    I64x2AddOp => I64x2Add
    I64x2SubOp => I64x2Sub
    I64x2MulOp => I64x2Mul
    I64x2ExtmulLowI32x4SOp => I64x2ExtmulLowI32x4S
    I64x2ExtmulHighI32x4SOp => I64x2ExtmulHighI32x4S
    I64x2ExtmulLowI32x4UOp => I64x2ExtmulLowI32x4U
    I64x2ExtmulHighI32x4UOp => I64x2ExtmulHighI32x4U
    // SIMD f32x4 arithmetic
    F32x4AddOp => F32x4Add
    F32x4SubOp => F32x4Sub
    F32x4MulOp => F32x4Mul
    F32x4DivOp => F32x4Div
    F32x4MinOp => F32x4Min
    F32x4MaxOp => F32x4Max
    F32x4PminOp => F32x4Pmin
    F32x4PmaxOp => F32x4Pmax
    // SIMD f64x2 arithmetic
    F64x2AddOp => F64x2Add
    F64x2SubOp => F64x2Sub
    F64x2MulOp => F64x2Mul
    F64x2DivOp => F64x2Div
    F64x2MinOp => F64x2Min
    F64x2MaxOp => F64x2Max
    F64x2PminOp => F64x2Pmin
    F64x2PmaxOp => F64x2Pmax
    // SIMD relaxed
    F32x4RelaxedMinOp => F32x4RelaxedMin
    F32x4RelaxedMaxOp => F32x4RelaxedMax
    F64x2RelaxedMinOp => F64x2RelaxedMin
    F64x2RelaxedMaxOp => F64x2RelaxedMax
    I16x8RelaxedQ15mulrSOp => I16x8RelaxedQ15mulrS
    I16x8RelaxedDotI8x16I7x16SOp => I16x8RelaxedDotI8x16I7x16S
  }
}

///|
fn load_op_to_instr(op : LoadOp, memarg : MemArg) -> Instruction {
  match op {
    I32LoadOp => I32Load(memarg)
    I64LoadOp => I64Load(memarg)
    F32LoadOp => F32Load(memarg)
    F64LoadOp => F64Load(memarg)
    I32Load8SOp => I32Load8S(memarg)
    I32Load8UOp => I32Load8U(memarg)
    I32Load16SOp => I32Load16S(memarg)
    I32Load16UOp => I32Load16U(memarg)
    I64Load8SOp => I64Load8S(memarg)
    I64Load8UOp => I64Load8U(memarg)
    I64Load16SOp => I64Load16S(memarg)
    I64Load16UOp => I64Load16U(memarg)
    I64Load32SOp => I64Load32S(memarg)
    I64Load32UOp => I64Load32U(memarg)
    V128LoadOp => V128Load(memarg)
    V128Load8x8SOp => V128Load8x8S(memarg)
    V128Load8x8UOp => V128Load8x8U(memarg)
    V128Load16x4SOp => V128Load16x4S(memarg)
    V128Load16x4UOp => V128Load16x4U(memarg)
    V128Load32x2SOp => V128Load32x2S(memarg)
    V128Load32x2UOp => V128Load32x2U(memarg)
    V128Load8SplatOp => V128Load8Splat(memarg)
    V128Load16SplatOp => V128Load16Splat(memarg)
    V128Load32SplatOp => V128Load32Splat(memarg)
    V128Load64SplatOp => V128Load64Splat(memarg)
    V128Load32ZeroOp => V128Load32Zero(memarg)
    V128Load64ZeroOp => V128Load64Zero(memarg)
  }
}

///|
fn store_op_to_instr(op : StoreOp, memarg : MemArg) -> Instruction {
  match op {
    I32StoreOp => I32Store(memarg)
    I64StoreOp => I64Store(memarg)
    F32StoreOp => F32Store(memarg)
    F64StoreOp => F64Store(memarg)
    I32Store8Op => I32Store8(memarg)
    I32Store16Op => I32Store16(memarg)
    I64Store8Op => I64Store8(memarg)
    I64Store16Op => I64Store16(memarg)
    I64Store32Op => I64Store32(memarg)
    V128StoreOp => V128Store(memarg)
  }
}

///|
fn extract_lane_op_to_instr(op : ExtractLaneOp, lane : LaneIdx) -> Instruction {
  match op {
    I8x16ExtractLaneSOp => I8x16ExtractLaneS(lane)
    I8x16ExtractLaneUOp => I8x16ExtractLaneU(lane)
    I16x8ExtractLaneSOp => I16x8ExtractLaneS(lane)
    I16x8ExtractLaneUOp => I16x8ExtractLaneU(lane)
    I32x4ExtractLaneOp => I32x4ExtractLane(lane)
    I64x2ExtractLaneOp => I64x2ExtractLane(lane)
    F32x4ExtractLaneOp => F32x4ExtractLane(lane)
    F64x2ExtractLaneOp => F64x2ExtractLane(lane)
  }
}

///|
fn replace_lane_op_to_instr(op : ReplaceLaneOp, lane : LaneIdx) -> Instruction {
  match op {
    I8x16ReplaceLaneOp => I8x16ReplaceLane(lane)
    I16x8ReplaceLaneOp => I16x8ReplaceLane(lane)
    I32x4ReplaceLaneOp => I32x4ReplaceLane(lane)
    I64x2ReplaceLaneOp => I64x2ReplaceLane(lane)
    F32x4ReplaceLaneOp => F32x4ReplaceLane(lane)
    F64x2ReplaceLaneOp => F64x2ReplaceLane(lane)
  }
}

///|
fn v128_shift_op_to_instr(op : V128ShiftOp) -> Instruction {
  match op {
    I8x16ShlOp => I8x16Shl
    I8x16ShrSOp => I8x16ShrS
    I8x16ShrUOp => I8x16ShrU
    I16x8ShlOp => I16x8Shl
    I16x8ShrSOp => I16x8ShrS
    I16x8ShrUOp => I16x8ShrU
    I32x4ShlOp => I32x4Shl
    I32x4ShrSOp => I32x4ShrS
    I32x4ShrUOp => I32x4ShrU
    I64x2ShlOp => I64x2Shl
    I64x2ShrSOp => I64x2ShrS
    I64x2ShrUOp => I64x2ShrU
  }
}

///|
fn v128_ternary_op_to_instr(op : V128TernaryOp) -> Instruction {
  match op {
    V128BitselectOp => V128Bitselect
    I8x16RelaxedLaneselectOp => I8x16RelaxedLaneselect
    I16x8RelaxedLaneselectOp => I16x8RelaxedLaneselect
    I32x4RelaxedLaneselectOp => I32x4RelaxedLaneselect
    I64x2RelaxedLaneselectOp => I64x2RelaxedLaneselect
    F32x4RelaxedMaddOp => F32x4RelaxedMadd
    F32x4RelaxedNmaddOp => F32x4RelaxedNmadd
    F64x2RelaxedMaddOp => F64x2RelaxedMadd
    F64x2RelaxedNmaddOp => F64x2RelaxedNmadd
    I32x4RelaxedDotI8x16I7x16AddSOp => I32x4RelaxedDotI8x16I7x16AddS
  }
}

///|
fn v128_load_lane_op_to_instr(
  op : V128LoadLaneOp,
  memarg : MemArg,
  lane : LaneIdx,
) -> Instruction {
  match op {
    V128Load8LaneOp => V128Load8Lane(memarg, lane)
    V128Load16LaneOp => V128Load16Lane(memarg, lane)
    V128Load32LaneOp => V128Load32Lane(memarg, lane)
    V128Load64LaneOp => V128Load64Lane(memarg, lane)
  }
}

///|
fn v128_store_lane_op_to_instr(
  op : V128StoreLaneOp,
  memarg : MemArg,
  lane : LaneIdx,
) -> Instruction {
  match op {
    V128Store8LaneOp => V128Store8Lane(memarg, lane)
    V128Store16LaneOp => V128Store16Lane(memarg, lane)
    V128Store32LaneOp => V128Store32Lane(memarg, lane)
    V128Store64LaneOp => V128Store64Lane(memarg, lane)
  }
}

///|
fn tlocals_to_locals(tlocals : Array[ValType]) -> Array[Locals] {
  if tlocals.length() == 0 {
    return []
  }
  let end = tlocals.length()
  let mut current = tlocals[0]
  let mut count = 1U
  let acc = []
  loop 1 {
    n if n == end => {
      acc.push(Locals(count, current))
      break acc
    }
    n => {
      let next = tlocals[n]
      if current == next {
        count = count + 1
      } else {
        acc.push(Locals(count, current))
        count = 1
        current = next
      }
      continue n + 1
    }
  }
}

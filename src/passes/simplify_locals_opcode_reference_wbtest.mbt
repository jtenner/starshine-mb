///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences_opcode_reference(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int32) {
  let normalized : Array[@lib.Instruction] = []
  let mut rewrite_count = 0
  for instr in instrs {
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) => {
        let (body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences_opcode_reference(
          body,
        )
        normalized.push(
          @lib.Instruction::block(block_type, @lib.Expr::new(body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        let (body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences_opcode_reference(
          body,
        )
        normalized.push(
          @lib.Instruction::loop_(block_type, @lib.Expr::new(body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        let (body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences_opcode_reference(
          body,
        )
        normalized.push(
          @lib.Instruction::try_table(block_type, catches, @lib.Expr::new(body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.If(block_type, then_body, else_body) => {
        let (then_body, then_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences_opcode_reference(
          then_body,
        )
        rewrite_count = rewrite_count + then_rewrites
        let else_body = match else_body {
          Some(body) => {
            let (body, else_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences_opcode_reference(
              body,
            )
            rewrite_count = rewrite_count + else_rewrites
            Some(body)
          }
          None => None
        }
        normalized.push(@lib.Instruction::if_(block_type, then_body, else_body))
      }
      _ => normalized.push(instr)
    }
  }
  let (three_local_rewritten, three_local_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences_flat(
    normalized,
  )
  let (rewritten, bitselect_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_alternating_bitselect_recurrences_flat(
    three_local_rewritten,
  )
  (rewritten, rewrite_count + three_local_rewrites + bitselect_rewrites)
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_alternating_simd_recurrences_opcode_reference(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int32) {
  let normalized : Array[@lib.Instruction] = []
  let mut rewrite_count = 0
  for instr in instrs {
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_alternating_simd_recurrences_opcode_reference(
          body,
        )
        normalized.push(
          @lib.Instruction::block(block_type, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_alternating_simd_recurrences_opcode_reference(
          body,
        )
        normalized.push(
          @lib.Instruction::loop_(block_type, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_alternating_simd_recurrences_opcode_reference(
          body,
        )
        normalized.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(rewritten_body),
          ),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.If(block_type, then_body, else_body) => {
        let (rewritten_then, then_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_alternating_simd_recurrences_opcode_reference(
          then_body,
        )
        rewrite_count = rewrite_count + then_rewrites
        let rewritten_else = match else_body {
          Some(body) => {
            let (rewritten_body, else_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_alternating_simd_recurrences_opcode_reference(
              body,
            )
            rewrite_count = rewrite_count + else_rewrites
            Some(rewritten_body)
          }
          None => None
        }
        normalized.push(
          @lib.Instruction::if_(block_type, rewritten_then, rewritten_else),
        )
      }
      _ => normalized.push(instr)
    }
  }
  let (rewritten, flat_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_alternating_simd_recurrences_flat(
    normalized,
  )
  (rewritten, rewrite_count + flat_rewrites)
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_split_i32x4_rotate_temporaries_opcode_reference(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int32) {
  run_hot_pipeline_raw_simplify_locals_rewrite_split_i32x4_rotate_temporaries_nested_opcode_reference(
    instrs, instrs,
  )
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_commutative_simd_carriers_opcode_reference(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int32) {
  let normalized : Array[@lib.Instruction] = []
  let mut rewrite_count = 0
  for instr in instrs {
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_commutative_simd_carriers_opcode_reference(
          body,
        )
        normalized.push(
          @lib.Instruction::block(block_type, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_commutative_simd_carriers_opcode_reference(
          body,
        )
        normalized.push(
          @lib.Instruction::loop_(block_type, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_commutative_simd_carriers_opcode_reference(
          body,
        )
        normalized.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(rewritten_body),
          ),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.If(block_type, then_body, else_body) => {
        let (rewritten_then, then_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_commutative_simd_carriers_opcode_reference(
          then_body,
        )
        rewrite_count = rewrite_count + then_rewrites
        let rewritten_else = match else_body {
          Some(body) => {
            let (rewritten_body, else_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_commutative_simd_carriers_opcode_reference(
              body,
            )
            rewrite_count = rewrite_count + else_rewrites
            Some(rewritten_body)
          }
          None => None
        }
        normalized.push(
          @lib.Instruction::if_(block_type, rewritten_then, rewritten_else),
        )
      }
      _ => normalized.push(instr)
    }
  }
  let (rewritten, flat_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_commutative_simd_carriers_flat(
    normalized,
  )
  (rewritten, rewrite_count + flat_rewrites)
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_split_i32x4_rotate_temporaries_nested_opcode_reference(
  instrs : Array[@lib.Instruction],
  all_instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int32) {
  let normalized : Array[@lib.Instruction] = []
  let mut rewrite_count = 0
  for instr in instrs {
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_split_i32x4_rotate_temporaries_nested_opcode_reference(
          body, all_instrs,
        )
        normalized.push(
          @lib.Instruction::block(block_type, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_split_i32x4_rotate_temporaries_nested_opcode_reference(
          body, all_instrs,
        )
        normalized.push(
          @lib.Instruction::loop_(block_type, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_split_i32x4_rotate_temporaries_nested_opcode_reference(
          body, all_instrs,
        )
        normalized.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(rewritten_body),
          ),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.If(block_type, then_body, else_body) => {
        let (rewritten_then, then_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_split_i32x4_rotate_temporaries_nested_opcode_reference(
          then_body, all_instrs,
        )
        rewrite_count = rewrite_count + then_rewrites
        let rewritten_else = match else_body {
          Some(body) => {
            let (rewritten_body, else_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_split_i32x4_rotate_temporaries_nested_opcode_reference(
              body, all_instrs,
            )
            rewrite_count = rewrite_count + else_rewrites
            Some(rewritten_body)
          }
          None => None
        }
        normalized.push(
          @lib.Instruction::if_(block_type, rewritten_then, rewritten_else),
        )
      }
      _ => normalized.push(instr)
    }
  }
  let (rewritten, flat_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_split_i32x4_rotate_temporaries_flat(
    normalized, all_instrs,
  )
  (rewritten, rewrite_count + flat_rewrites)
}

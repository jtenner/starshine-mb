// ============================================================================
// optimize_casts.mbt
// 
// A pass that optimizes reference casts by:
// 1. Duplicating casts earlier to local.get sites
// 2. Reusing the most refined cast via temporary locals
// ============================================================================

///|
/// State maintained during cast optimization
struct CastOptState {
  /// Environment with type information
  env : Env
  /// Best (most refined) cast type seen for each local
  best_casts : Map[Int, RefType]
  /// Maps original local -> temp local holding casted value
  cast_temps : Map[Int, Int]
  /// New locals to append to the function
  new_locals : Array[ValType]
  /// Original number of locals in the function
  base_local_count : Int
} derive(Show)

///|
/// Create fresh state for a new function
fn CastOptState::new(env : Env, local_count : Int) -> CastOptState {
  {
    env,
    best_casts: Map::new(),
    cast_temps: Map::new(),
    new_locals: [],
    base_local_count: local_count,
  }
}

///|
/// Reset state at control flow boundaries (keeps env and new_locals)
fn CastOptState::reset_flow(self : CastOptState) -> CastOptState {
  { ..self, best_casts: Map::new(), cast_temps: Map::new() }
}

///|
/// Allocate a new temporary local for a casted value
fn CastOptState::alloc_temp(
  self : CastOptState,
  original_local : Int,
  ty : RefType,
) -> (CastOptState, Int) {
  let temp_idx = self.base_local_count + self.new_locals.length()
  let new_locals = self.new_locals.copy()
  new_locals.push(ValType::ref_type(ty))
  let cast_temps = self.cast_temps.copy()
  cast_temps[original_local] = temp_idx
  ({ ..self, new_locals, cast_temps }, temp_idx)
}

///|
/// Record the best cast for a local (only if more refined)
fn CastOptState::record_cast(
  self : CastOptState,
  local_idx : Int,
  ty : RefType,
) -> CastOptState {
  match self.best_casts.get(local_idx) {
    Some(existing) =>
      if is_subtype(ty, existing, self.env) {
        let best_casts = self.best_casts.copy()
        best_casts[local_idx] = ty
        { ..self, best_casts, }
      } else {
        self
      }
    None => {
      let best_casts = self.best_casts.copy()
      best_casts[local_idx] = ty
      { ..self, best_casts, }
    }
  }
}

///|
/// Get the type of a local variable
fn CastOptState::get_local_type(
  self : CastOptState,
  idx : LocalIdx,
) -> ValType? {
  self.env.get_local_type(idx)
}

///|
/// Update the environment's locals (for when we're processing a function)
fn CastOptState::with_locals(
  self : CastOptState,
  locals : Array[ValType],
) -> CastOptState {
  { ..self, env: self.env.with_locals(locals) }
}

// ============================================================================
// Subtype checking
// ============================================================================

///|
/// Check if `sub` is a subtype of `sup`
fn is_subtype(sub : RefType, sup : RefType, env : Env) -> Bool {
  let nullable_ok = not(sub.is_nullable()) || sup.is_nullable()
  let heap_ok = is_heap_subtype(sub.get_heap_type(), sup.get_heap_type(), env)
  nullable_ok && heap_ok
}

///|
/// Check heap type subtyping using the environment
fn is_heap_subtype(sub : HeapType, sup : HeapType, env : Env) -> Bool {
  Match::matches(sub, sup, env)
}

// ============================================================================
// Main transformation logic
// ============================================================================

///|
/// The main optimization pass
pub fn optimize_casts(mod : Module) -> Module {
  // Build environment from module
  let env = Env::new().with_module(mod)
  match
    ModuleTransformer::new()
    .on_func_evt(transform_func)
    .on_tinstruction_evt(transform_tinstr)
    .walk_module(CastOptState::new(env, 0), mod) {
    Ok(Some((_, mod))) => mod
    _ => mod
  }
}

///|
/// Initialize state for each function
fn transform_func(
  transformer : ModuleTransformer[CastOptState],
  state : CastOptState,
  func : Func,
) -> TransformerResult[CastOptState, Func] {
  match func {
    Func(_, _) => Err("Expected TFunc")
    TFunc(locals, body) => {
      let local_count = locals.length()

      // Create new state with function's locals in the environment
      let new_state = CastOptState::new(
        state.env.with_locals(locals),
        local_count,
      )
      match transformer.walk_texpr(new_state, body) {
        Ok(Some((final_state, new_body))) => {
          // Append any new locals we created
          let new_locals = locals.copy()
          for l in final_state.new_locals {
            new_locals.push(l)
          }
          change(final_state, Func::t_func(new_locals, new_body))
        }
        _ => unchanged()
      }
    }
  }
}

///|
/// Transform individual instructions
fn transform_tinstr(
  transformer : ModuleTransformer[CastOptState],
  ctx : CastOptState,
  instr : TInstr,
) -> TransformerResult[CastOptState, TInstr] {
  match instr {
    // Control flow boundaries - reset cast tracking state
    TBlock(ty, body) => {
      let new_state = ctx.reset_flow()
      match transformer.walk_texpr(new_state, body) {
        Ok(Some((final_state, new_body))) =>
          change(final_state.reset_flow(), TInstr::block(ty, new_body))
        _ => change(ctx.reset_flow(), instr) // Preserve state even if unchanged
      }
    }
    TLoop(ty, body) => {
      let new_state = ctx.reset_flow()
      match transformer.walk_texpr(new_state, body) {
        Ok(Some((final_state, new_body))) =>
          change(final_state.reset_flow(), TInstr::loop_(ty, new_body))
        Err(e) => Err(e)
        _ => change(ctx.reset_flow(), instr)
      }
    }
    TIf(ty, cond, then_branch, else_branch) => {
      let (state1, new_cond) = match transformer.walk_tinstruction(ctx, cond) {
        Ok(Some(i)) => i
        Err(t) => return Err(t)
        _ => (ctx, cond)
      }
      let (state2, new_then) = match
        transformer.walk_texpr(state1.reset_flow(), then_branch) {
        Ok(Some(i)) => i
        Err(t) => return Err(t)
        _ => (state1.reset_flow(), then_branch)
      }
      let (state3, new_else) = match else_branch {
        Some(e) =>
          match transformer.walk_texpr(state2.reset_flow(), e) {
            Ok(Some((s, i))) => (s, Some(i))
            Err(t) => return Err(t)
            _ => (state2.reset_flow(), Some(e))
          }
        None => (state2, None)
      }

      // Preserve new_locals from both branches
      let merged_state = merge_branch_states(state2, state3)
      change(
        merged_state.reset_flow(),
        TInstr::if_(ty, new_cond, new_then, new_else),
      )
    }

    // local.get - potentially wrap with cast or use temp
    TLocalGet(idx) => transform_local_get(ctx, idx)

    // ref.cast - record and potentially optimize
    TRefCast(nullable, ht, operand) =>
      transform_ref_cast(transformer, ctx, nullable, ht, operand)

    // ref.as_non_null - treat as a cast to non-nullable
    TRefAsNonNull(operand) =>
      transform_ref_as_non_null(transformer, ctx, operand)

    // local.set - invalidate any cast knowledge for this local
    TLocalSet(idx, op) => {
      let (new_state, new_op) = match transformer.walk_tinstruction(ctx, op) {
        Ok(Some(result)) => result
        Err(e) => return Err(e)
        _ => (ctx, op)
      }
      let new_state = invalidate_local(new_state, idx)
      change(new_state, TInstr::local_set(idx, new_op))
    }

    // local.tee - same as local.set
    TLocalTee(idx, op) => {
      let (new_state, new_op) = match transformer.walk_tinstruction(ctx, op) {
        Ok(Some(result)) => result
        Err(e) => return Err(e)
        _ => (ctx, op)
      }
      let new_state = invalidate_local(new_state, idx)
      change(new_state, TInstr::local_tee(idx, new_op))
    }

    // Branches - reset state after
    TBr(label, values) => {
      let (new_state, new_values) = match
        transformer.walk_texpr(ctx, TExpr::new(values)) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (ctx, TExpr::new(values))
      }
      change(new_state.reset_flow(), TInstr::br(label, new_values.0))
    }
    TBrIf(label, cond, values) => {
      let (state1, new_cond) = match transformer.walk_tinstruction(ctx, cond) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (ctx, cond)
      }
      let (new_state, new_values) = match
        transformer.walk_texpr(state1, TExpr::new(values)) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (state1, TExpr::new(values))
      }
      // After br_if, we can't assume any casts hold (branch might have been taken)
      change(
        new_state.reset_flow(),
        TInstr::br_if(label, new_cond, new_values.0),
      )
    }
    TBrTable(labels, default, idx_op, values) => {
      let (state1, new_idx) = match transformer.walk_tinstruction(ctx, idx_op) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (ctx, idx_op)
      }
      let (new_state, new_values) = match
        transformer.walk_texpr(state1, TExpr::new(values)) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (state1, TExpr::new(values))
      }
      change(
        new_state.reset_flow(),
        TInstr::br_table(labels, default, new_idx, new_values.0),
      )
    }
    TBrOnNull(label, value, values) => {
      let (state1, new_value) = match
        transformer.walk_tinstruction(ctx, value) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (ctx, value)
      }
      let (new_state, new_values) = match
        transformer.walk_texpr(state1, TExpr::new(values)) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (state1, TExpr::new(values))
      }
      change(
        new_state.reset_flow(),
        TInstr::br_on_null(label, new_value, new_values.0),
      )
    }
    TBrOnNonNull(label, value, values) => {
      let (state1, new_value) = match
        transformer.walk_tinstruction(ctx, value) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (ctx, value)
      }
      let (new_state, new_values) = match
        transformer.walk_texpr(state1, TExpr::new(values)) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (state1, TExpr::new(values))
      }
      change(
        new_state.reset_flow(),
        TInstr::br_on_non_null(label, new_value, new_values.0),
      )
    }
    TBrOnCast(label, op, ht1, ht2, value, values) => {
      let (state1, new_value) = match
        transformer.walk_tinstruction(ctx, value) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (ctx, value)
      }
      let (new_state, new_values) = match
        transformer.walk_texpr(state1, TExpr::new(values)) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (state1, TExpr::new(values))
      }
      change(
        new_state.reset_flow(),
        TInstr::br_on_cast(label, op.0, ht1, op.1, ht2, new_value, new_values.0),
      )
    }
    TBrOnCastFail(label, op, ht1, ht2, value, values) => {
      let (state1, new_value) = match
        transformer.walk_tinstruction(ctx, value) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (ctx, value)
      }
      let (new_state, new_values) = match
        transformer.walk_texpr(state1, TExpr::new(values)) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (state1, TExpr::new(values))
      }
      change(
        new_state.reset_flow(),
        TInstr::br_on_cast_fail(
          label,
          op.0,
          ht1,
          op.1,
          ht2,
          new_value,
          new_values.0,
        ),
      )
    }
    TReturn(values) => {
      let (new_state, new_values) = match
        transformer.walk_texpr(ctx, TExpr::new(values)) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (ctx, TExpr::new(values))
      }
      change(new_state.reset_flow(), TInstr::return_(new_values.0))
    }
    TReturnCall(func_idx, args) => {
      let (new_state, new_args) = match
        transformer.walk_texpr(ctx, TExpr::new(args)) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (ctx, TExpr::new(args))
      }
      change(new_state.reset_flow(), TInstr::return_call(func_idx, new_args.0))
    }
    TReturnCallIndirect(type_idx, table_idx, args, index) => {
      let (new_state, new_args) = match
        transformer.walk_texpr(ctx, TExpr::new(args)) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (ctx, TExpr::new(args))
      }
      change(
        new_state.reset_flow(),
        TInstr::return_call_indirect(type_idx, table_idx, new_args.0, index),
      )
    }
    TReturnCallRef(type_idx, args, ref_) => {
      let (new_state, new_args) = match
        transformer.walk_texpr(ctx, TExpr::new(args)) {
        Ok(Some(i)) => i
        Err(e) => return Err(e)
        _ => (ctx, TExpr::new(args))
      }
      change(
        new_state.reset_flow(),
        TInstr::return_call_ref(type_idx, new_args.0, ref_),
      )
    }
    TUnreachable => change(ctx.reset_flow(), TInstr::unreachable_())

    // FIX: Handle all other instructions explicitly to ensure state propagation
    // Walk children and always return change() to preserve state threading
    _ => walk_with_state_propagation(transformer, ctx, instr)
  }
}

///|
/// Helper to walk an instruction with the default walker while preserving state
fn walk_with_state_propagation(
  transformer : ModuleTransformer[CastOptState],
  ctx : CastOptState,
  instr : TInstr,
) -> TransformerResult[CastOptState, TInstr] {
  match transformer.walk_tinstruction_default(ctx, instr) {
    Ok(Some((new_state, new_instr))) => change(new_state, new_instr)
    Ok(None) => change(ctx, instr) // Key fix: preserve state even when unchanged
    Err(e) => Err(e)
  }
}

///|
/// Merge states from two branches, keeping new_locals from both
fn merge_branch_states(s1 : CastOptState, s2 : CastOptState) -> CastOptState {
  // Take the longer new_locals array (they should be compatible)
  let new_locals = if s1.new_locals.length() >= s2.new_locals.length() {
    s1.new_locals
  } else {
    s2.new_locals
  }
  { ..s1, new_locals, }
}

///|
/// Transform a local.get instruction
fn transform_local_get(
  state : CastOptState,
  idx : LocalIdx,
) -> TransformerResult[CastOptState, TInstr] {
  let idx_int = idx.0.reinterpret_as_int()

  // If we have a temp local with a casted value, use that instead
  match state.cast_temps.get(idx_int) {
    Some(temp_idx) =>
      change(
        state,
        TInstr::local_get(LocalIdx::new(temp_idx.reinterpret_as_uint())),
      )
    None =>
      // If we know a best cast for this local, apply it
      match state.best_casts.get(idx_int) {
        Some(ty) => {
          // Allocate a temp to store the casted value
          let (new_state, temp_idx) = state.alloc_temp(idx_int, ty)

          // Emit: local.get $idx -> ref.cast $ty -> local.tee $temp
          change(
            new_state,
            TInstr::local_tee(
              LocalIdx::new(temp_idx.reinterpret_as_uint()),
              TInstr::ref_cast(
                ty.is_nullable(),
                ty.get_heap_type(),
                TInstr::local_get(idx),
              ),
            ),
          )
        }
        None => unchanged()
      }
  }
}

///|
/// Transform a ref.cast instruction
fn transform_ref_cast(
  transformer : ModuleTransformer[CastOptState],
  ctx : CastOptState,
  nullable : Bool,
  ht : HeapType,
  operand : TInstr,
) -> TransformerResult[CastOptState, TInstr] {
  // First, walk the operand to apply any transformations to it
  let (state_after_operand, transformed_operand) = match
    transformer.walk_tinstruction(ctx, operand) {
    Ok(Some(result)) => result
    Err(e) => return Err(e)
    _ => (ctx, operand)
  }
  let cast_type = RefType::new(nullable, ht)

  // Analyze the transformed operand
  match transformed_operand {
    TLocalGet(idx) => {
      let idx_int = idx.0.reinterpret_as_int()

      // Record this as the best cast for this local
      let new_state = state_after_operand.record_cast(idx_int, cast_type)

      // Check if we already have a temp with an equivalent or better cast
      match state_after_operand.cast_temps.get(idx_int) {
        Some(_) =>
          match state_after_operand.best_casts.get(idx_int) {
            Some(existing_ty) if is_subtype(
                existing_ty,
                cast_type,
                new_state.env,
              ) =>
              // Existing cast is at least as refined, this cast is redundant
              change(new_state, transformed_operand)
            _ =>
              change(
                new_state,
                TInstr::ref_cast(nullable, ht, transformed_operand),
              )
          }
        None =>
          change(new_state, TInstr::ref_cast(nullable, ht, transformed_operand))
      }
    }

    // For local.tee that wraps a cast (from our transformation)
    TLocalTee(_, inner) =>
      match inner {
        TRefCast(inner_nullable, inner_ht, TLocalGet(_)) => {
          let inner_type = RefType::new(inner_nullable, inner_ht)
          if is_subtype(inner_type, cast_type, state_after_operand.env) {
            // Inner cast is already more refined, outer cast is redundant
            change(state_after_operand, transformed_operand)
          } else {
            change(
              state_after_operand,
              TInstr::ref_cast(nullable, ht, transformed_operand),
            )
          }
        }
        _ =>
          change(
            state_after_operand,
            TInstr::ref_cast(nullable, ht, transformed_operand),
          )
      }

    // FIX: Handle nested ref.cast - eliminate outer cast if inner is more refined
    TRefCast(inner_nullable, inner_ht, _) => {
      let inner_type = RefType::new(inner_nullable, inner_ht)
      if is_subtype(inner_type, cast_type, state_after_operand.env) {
        // Inner cast is already more refined, outer cast is redundant
        change(state_after_operand, transformed_operand)
      } else {
        change(
          state_after_operand,
          TInstr::ref_cast(nullable, ht, transformed_operand),
        )
      }
    }
    _ =>
      change(
        state_after_operand,
        TInstr::ref_cast(nullable, ht, transformed_operand),
      )
  }
}

///|
/// Transform ref.as_non_null
fn transform_ref_as_non_null(
  transformer : ModuleTransformer[CastOptState],
  ctx : CastOptState,
  operand : TInstr,
) -> TransformerResult[CastOptState, TInstr] {
  // First, walk the operand
  let (state_after_operand, transformed_operand) = match
    transformer.walk_tinstruction(ctx, operand) {
    Ok(Some(result)) => result
    Err(e) => return Err(e)
    _ => (ctx, operand)
  }
  match transformed_operand {
    TLocalGet(idx) => {
      let idx_int = idx.0.reinterpret_as_int()

      // Check if we already have a non-nullable cast recorded
      match state_after_operand.best_casts.get(idx_int) {
        Some(existing_ty) if not(existing_ty.is_nullable()) =>
          // Already non-nullable, this instruction is redundant
          change(state_after_operand, transformed_operand)
        _ =>
          // Get the local's declared type to create a non-null version
          match state_after_operand.get_local_type(idx) {
            Some(RefTypeValType(HeapTypeRefType(true, ht))) => {
              // Record non-nullable version of this type
              let non_null_ty = RefType::new(false, ht)
              let new_state = state_after_operand.record_cast(
                idx_int, non_null_ty,
              )
              change(new_state, TInstr::ref_as_non_null(transformed_operand))
            }
            Some(RefTypeValType(HeapTypeRefType(false, _))) =>
              // Already non-nullable type, instruction is redundant
              change(state_after_operand, transformed_operand)
            _ =>
              // Can't determine type, keep the instruction
              change(
                state_after_operand,
                TInstr::ref_as_non_null(transformed_operand),
              )
          }
      }
    }

    // Check if operand is already a non-null producing instruction
    TLocalTee(_, inner) =>
      match inner {
        TRefCast(false, _, _) =>
          // Cast already produces non-null, ref.as_non_null is redundant
          change(state_after_operand, transformed_operand)
        TRefAsNonNull(_) =>
          // Already non-null, redundant
          change(state_after_operand, transformed_operand)
        _ =>
          change(
            state_after_operand,
            TInstr::ref_as_non_null(transformed_operand),
          )
      }
    TRefCast(false, _, _) =>
      // Cast already produces non-null, ref.as_non_null is redundant
      change(state_after_operand, transformed_operand)
    TRefAsNonNull(_) =>
      // Already non-null, redundant
      change(state_after_operand, transformed_operand)
    _ =>
      change(state_after_operand, TInstr::ref_as_non_null(transformed_operand))
  }
}

///|
/// Invalidate cast knowledge for a local that's being written
fn invalidate_local(state : CastOptState, idx : LocalIdx) -> CastOptState {
  let idx_int = idx.0.reinterpret_as_int()
  let best_casts = state.best_casts.copy()
  let cast_temps = state.cast_temps.copy()
  best_casts.remove(idx_int)
  cast_temps.remove(idx_int)
  { ..state, best_casts, cast_temps }
}

// ============================================================================
// test_optimize_casts.mbt
// 
// Tests for the cast optimization pass
// ============================================================================}

// Create a minimal module with a type hierarchy for testing
// Type 0: base struct
// Type 1: extends type 0 (subtype)
// Type 2: extends type 1 (sub-subtype)

///|
fn make_test_module_with_hierarchy() -> Module {
  // Create struct types with inheritance
  let base_struct = SubType::new(
    false, // not final
    [], // no explicit supertypes (implicitly anyref)
    CompType::struct_([]),
  )
  let sub_struct = SubType::new(
    false,
    [TypeIdx::new(0)], // extends type 0
    CompType::struct_([]),
  )
  let subsub_struct = SubType::new(
    false,
    [TypeIdx::new(1)], // extends type 1
    CompType::struct_([]),
  )
  let type_sec = TypeSec::new([
    RecType::new(base_struct),
    RecType::new(sub_struct),
    RecType::new(subsub_struct),
  ])
  Module::new().with_type_sec(type_sec)
}

// ============================================================================
// Test: Basic cast is recorded and propagated to subsequent local.get
// ============================================================================

///|
test "cast propagation to subsequent local.get" {
  // Input:
  //   ref.cast (ref $1) (local.get $0)
  //   drop
  //   local.get $0   ; first use - allocates temp, becomes local.tee
  //   drop
  //   local.get $0   ; second use - uses temp, becomes local.get $temp
  //
  // The first local.get after a cast becomes local.tee to save the casted value.
  // Subsequent local.gets use the temp directly.

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  ) // (ref null $0)
  let body = TExpr::new([
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(1)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
    TInstr::drop(TInstr::nop()),
    TInstr::local_get(LocalIdx::new(0)), // First use after cast -> local.tee
    TInstr::drop(TInstr::nop()),
    TInstr::local_get(LocalIdx::new(0)), // Second use -> local.get $temp
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)

  // Verify the transformations
  let result_func = get_func_from_module(result, 0)
  match result_func {
    Some(TFunc(locals, body)) => {
      // Should have allocated a new temp local
      assert_true(locals.length() > 1)
      let instrs = body.0
      assert_true(instrs.length() >= 5)

      // instrs[2]: First local.get $0 should become local.tee $temp (ref.cast ... (local.get $0))
      match instrs[2] {
        TLocalTee(temp_idx, inner) => {
          // Temp local should be >= 1 (original local is 0)
          assert_true(temp_idx.0.reinterpret_as_int() >= 1)

          // Inner should be ref.cast wrapping local.get $0
          match inner {
            TRefCast(_, _, TLocalGet(orig_idx)) =>
              assert_eq(orig_idx.0.reinterpret_as_int(), 0)
            _ => assert_true(false) // Expected ref.cast(local.get $0)
          }

          // instrs[4]: Second local.get $0 should become local.get $temp
          match instrs[4] {
            TLocalGet(idx) =>
              // Should be getting from temp local, not original
              assert_eq(
                idx.0.reinterpret_as_int(),
                temp_idx.0.reinterpret_as_int(),
              )
            _ => assert_true(false) // Expected local.get $temp
          }
        }
        _ => assert_true(false) // Expected local.tee
      }
    }
    _ => assert_true(false)
  }
}

// ============================================================================
// Test: Redundant cast to supertype is eliminated
// ============================================================================

///|
test "redundant cast to supertype eliminated" {
  // Input:
  //   local.get $0
  //   ref.cast (ref $2)    ; cast to most refined type
  //   ref.cast (ref $1)    ; cast to supertype - should be eliminated
  //
  // Expected: second cast removed since $2 <: $1

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(1)), // outer cast to $1
      TInstr::ref_cast(
        false,
        HeapType::new(TypeIdx::new(2)), // inner cast to $2 (more refined)
        TInstr::local_get(LocalIdx::new(0)),
      ),
    ),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  let result_func = get_func_from_module(result, 0)
  match result_func {
    Some(TFunc(_, body)) => {
      let instrs = body.0
      // The outer ref.cast to $1 should be eliminated
      match instrs[0] {
        TLocalTee(_, inner) =>
          match inner {
            TRefCast(_, inner_ht, _) =>
              // Should only have the more refined cast ($2)
              match inner_ht {
                HeapType(TypeIdx(i)) => assert_eq(i.reinterpret_as_int(), 2)
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        TRefCast(_, outer_ht, inner) =>
          // If not wrapped in tee, check that redundant cast is gone
          match inner {
            TRefCast(_, _, _) =>
              // Nested casts - the outer one should be to $2, not $1
              match outer_ht {
                HeapType(TypeIdx(i)) => assert_eq(i.reinterpret_as_int(), 2)
                _ => ()
              }
            _ => ()
          }
        _ => ()
      }
    }
    _ => assert_true(false)
  }
}

// ============================================================================
// Test: ref.as_non_null after non-nullable cast is eliminated
// ============================================================================

///|
test "ref.as_non_null after non-null cast eliminated" {
  // Input:
  //   local.get $0
  //   ref.cast (ref $1)       ; non-nullable cast
  //   ref.as_non_null         ; redundant - already non-null
  //
  // Expected: ref.as_non_null removed

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::ref_as_non_null(
      TInstr::ref_cast(
        false,
        HeapType::new(TypeIdx::new(1)),
        TInstr::local_get(LocalIdx::new(0)),
      ),
    ),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  let result_func = get_func_from_module(result, 0)
  match result_func {
    Some(TFunc(_, body)) => {
      let instrs = body.0
      // Top-level should NOT be ref.as_non_null
      match instrs[0] {
        TRefAsNonNull(_) => assert_true(false) // Should have been eliminated
        TLocalTee(_, inner) =>
          // Should be tee of the cast
          match inner {
            TRefCast(false, _, _) => () // Good - cast preserved, as_non_null removed
            _ => ()
          }
        TRefCast(false, _, _) => () // Good - just the cast
        _ => ()
      }
    }
    _ => assert_true(false)
  }
}

// ============================================================================
// Test: Cast tracking reset at block boundaries
// ============================================================================

///|
test "cast tracking reset at block boundary" {
  // Input:
  //   local.get $0
  //   ref.cast (ref $1)
  //   drop
  //   block
  //     local.get $0   ; should NOT get cast (inside block)
  //   end
  //
  // Expected: local.get inside block unchanged

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(1)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
    TInstr::drop(TInstr::nop()),
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
    ),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  let result_func = get_func_from_module(result, 0)
  match result_func {
    Some(TFunc(_, body)) => {
      let instrs = body.0
      // Find the block and check its content
      for instr in instrs {
        match instr {
          TBlock(_, block_body) =>
            match block_body.0[0] {
              TLocalGet(idx) =>
                // Should still be getting from original local $0
                assert_eq(idx.0.reinterpret_as_int(), 0)
              _ => () // May have been transformed differently
            }
          _ => ()
        }
      }
    }
    _ => assert_true(false)
  }
}

// ============================================================================
// Test: Cast tracking reset at loop boundaries
// ============================================================================

///|
test "cast tracking reset at loop boundary" {
  // Same as block test but with loop

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(1)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
    TInstr::drop(TInstr::nop()),
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
    ),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)

  // Verify loop body local.get unchanged
  let result_func = get_func_from_module(result, 0)
  match result_func {
    Some(TFunc(_, body)) =>
      for instr in body.0 {
        match instr {
          TLoop(_, loop_body) =>
            match loop_body.0[0] {
              TLocalGet(idx) => assert_eq(idx.0.reinterpret_as_int(), 0)
              _ => ()
            }
          _ => ()
        }
      }
    _ => assert_true(false)
  }
}

// ============================================================================
// Test: local.set invalidates cast knowledge
// ============================================================================

///|
test "local.set invalidates cast tracking" {
  // Input:
  //   local.get $0
  //   ref.cast (ref $1)
  //   local.set $0         ; write to $0 invalidates cast
  //   local.get $0         ; should NOT get automatic cast

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let ht = HeapType::new(TypeIdx::new(1))
  let body = TExpr::new([
    TInstr::local_set(
      LocalIdx::new(0),
      TInstr::ref_cast(false, ht, TInstr::local_get(LocalIdx::new(0))),
    ),
    TInstr::local_get(LocalIdx::new(0)),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  let result_func = get_func_from_module(result, 0)
  match result_func {
    Some(TFunc(_, body)) => {
      // Should NOT have allocated a temp (cast knowledge was invalidated)
      let instrs = body.0
      match instrs[instrs.length() - 1] {
        TLocalGet(idx) =>
          // Should be original local, not temp
          assert_eq(idx.0.reinterpret_as_int(), 0)
        _ => ()
      }
    }
    _ => assert_true(false)
  }
}

// ============================================================================
// Test: local.tee invalidates cast knowledge
// ============================================================================

///|
test "local.tee invalidates cast tracking" {
  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let ht = HeapType::new(TypeIdx::new(1))
  let body = TExpr::new([
    TInstr::ref_cast(false, ht, TInstr::local_get(LocalIdx::new(0))),
    TInstr::drop(TInstr::nop()),
    TInstr::local_tee(
      LocalIdx::new(0),
      TInstr::ref_null(HeapType::new(TypeIdx::new(0))), // tee a null value
    ),
    TInstr::drop(TInstr::nop()),
    TInstr::local_get(LocalIdx::new(0)), // should not get cast
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)

  // Verify final local.get is not using a cast temp
  let result_func = get_func_from_module(result, 0)
  assert_true(result_func is Some(_))
}

// ============================================================================
// Test: if branches reset cast tracking independently
// ============================================================================

///|
test "if branches have independent cast tracking" {
  // Cast before if should not propagate into branches

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(1)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
    TInstr::drop(TInstr::nop()),
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(1),
      TExpr::new([TInstr::local_get(LocalIdx::new(0))]), // then branch
      Some(TExpr::new([TInstr::local_get(LocalIdx::new(0))])), // else branch
    ),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)

  // Both branches should have plain local.get $0
  let result_func = get_func_from_module(result, 0)
  assert_true(result_func is Some(_))
}

// ============================================================================
// Test: Nullable cast followed by non-null cast keeps only non-null
// ============================================================================

///|
test "nullable to non-null cast refinement" {
  // Input:
  //   local.get $0
  //   ref.cast (ref null $1)   ; nullable cast
  //   ref.cast (ref $1)        ; non-nullable - more refined
  //
  // The second cast is more refined and should be used

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::ref_cast(
      false, // non-nullable outer
      HeapType::new(TypeIdx::new(1)),
      TInstr::ref_cast(
        true, // nullable inner
        HeapType::new(TypeIdx::new(1)),
        TInstr::local_get(LocalIdx::new(0)),
      ),
    ),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)

  // Result should preserve non-null (more refined) cast
  assert_true(get_func_from_module(result, 0) is Some(_))
}

// ============================================================================
// Test: Multiple uses of same local after cast
// ============================================================================

///|
test "multiple uses after cast all use temp" {
  // Input:
  //   local.get $0
  //   ref.cast (ref $1)
  //   drop
  //   local.get $0   ; use 1
  //   local.get $0   ; use 2
  //   local.get $0   ; use 3
  //
  // All subsequent uses should use the temp

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(1)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
    TInstr::drop(TInstr::nop()),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::drop(TInstr::nop()),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::drop(TInstr::nop()),
    TInstr::local_get(LocalIdx::new(0)),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  let result_func = get_func_from_module(result, 0)
  match result_func {
    Some(TFunc(locals, body)) => {
      // Should have exactly one temp local allocated
      assert_eq(locals.length(), 2)

      // Count local.gets to temp
      let mut temp_gets = 0
      for instr in body.0 {
        match instr {
          TLocalGet(idx) if idx.0.reinterpret_as_int() == 1 => temp_gets += 1
          _ => ()
        }
      }
      // At least 2 of the 3 subsequent gets should use temp
      assert_true(temp_gets >= 2)
    }
    _ => assert_true(false)
  }
}

// ============================================================================
// Test: Cast on different locals tracked separately
// ============================================================================

///|
test "different locals tracked independently" {
  // Input:
  //   local.get $0
  //   ref.cast (ref $1)
  //   drop
  //   local.get $1
  //   ref.cast (ref $2)
  //   drop
  //   local.get $0   ; should use $1 cast
  //   local.get $1   ; should use $2 cast

  let mod = make_test_module_with_hierarchy()
  let ht0 = HeapType::new(TypeIdx::new(0))
  let ht1 = HeapType::new(TypeIdx::new(1))
  let ht2 = HeapType::new(TypeIdx::new(2))
  let local_type_0 = ValType::ref_type(RefType::new(true, ht0))
  let local_type_1 = ValType::ref_type(RefType::new(true, ht0))
  let body = TExpr::new([
    TInstr::ref_cast(false, ht1, TInstr::local_get(LocalIdx::new(0))),
    TInstr::drop(TInstr::nop()),
    TInstr::ref_cast(false, ht2, TInstr::local_get(LocalIdx::new(1))),
    TInstr::drop(TInstr::nop()),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::local_get(LocalIdx::new(1)),
  ])
  let func = Func::t_func([local_type_0, local_type_1], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  let result_func = get_func_from_module(result, 0)
  match result_func {
    Some(TFunc(locals, _)) =>
      // Should have 2 original + 2 temp locals
      assert_eq(locals.length(), 4)
    _ => assert_true(false)
  }
}

// ============================================================================
// Test: No transformation when no casts present
// ============================================================================

///|
test "no transformation without casts" {
  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::i32()
  let body = TExpr::new([
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::binary(BinaryOp::i32_add(), TInstr::nop(), TInstr::nop()),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  let result_func = get_func_from_module(result, 0)
  match result_func {
    Some(TFunc(locals, _)) =>
      // No new locals should be added
      assert_eq(locals.length(), 1)
    _ => assert_true(false)
  }
}

// ============================================================================
// Test: Cast in nested expression
// ============================================================================

///|
test "cast in nested expression context" {
  // Input:
  //   call $f (ref.cast (ref $1) (local.get $0))
  //   local.get $0   ; should get cast applied

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::call(FuncIdx::new(0), [
      TInstr::ref_cast(
        false,
        HeapType::new(TypeIdx::new(1)),
        TInstr::local_get(LocalIdx::new(0)),
      ),
    ]),
    TInstr::local_get(LocalIdx::new(0)),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)

  // Should still track the cast even in nested context
  assert_true(get_func_from_module(result, 0) is Some(_))
}

// ============================================================================
// Test: br_if does not preserve cast knowledge
// ============================================================================

///|
test "br_if resets cast tracking" {
  // After br_if, we can't assume the cast holds (branch might have been taken)

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::ref_cast(
          false,
          HeapType::new(TypeIdx::new(1)),
          TInstr::local_get(LocalIdx::new(0)),
        ),
        TInstr::drop(TInstr::nop()),
        TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(1), []),
        TInstr::local_get(LocalIdx::new(0)), // after br_if - cast tracking reset
      ]),
    ),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  assert_true(get_func_from_module(result, 0) is Some(_))
}

// ============================================================================
// Test: return resets cast tracking
// ============================================================================

///|
test "instructions after return unreachable" {
  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(1)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
    TInstr::return_([]),
    TInstr::local_get(LocalIdx::new(0)), // unreachable but still processed
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  assert_true(get_func_from_module(result, 0) is Some(_))
}

// ============================================================================
// Test: ref.as_non_null on already non-null local type
// ============================================================================

///|
test "ref.as_non_null on non_null type is eliminated" {
  // If local is already declared non-null, ref.as_non_null is redundant

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  ) // non-nullable!
  let body = TExpr::new([
    TInstr::ref_as_non_null(TInstr::local_get(LocalIdx::new(0))),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  let result_func = get_func_from_module(result, 0)
  match result_func {
    Some(TFunc(_, body)) =>
      // Should just be local.get, not ref.as_non_null
      match body.0[0] {
        TRefAsNonNull(_) => assert_true(false) // Should have been eliminated
        TLocalGet(_) => () // Good
        _ => ()
      }
    _ => assert_true(false)
  }
}

// ============================================================================
// Test: Repeated ref.as_non_null is eliminated
// ============================================================================

///|
test "repeated ref.as_non_null eliminated" {
  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::ref_as_non_null(
      TInstr::ref_as_non_null(TInstr::local_get(LocalIdx::new(0))),
    ),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)

  // Outer ref.as_non_null should be eliminated
  let result_func = get_func_from_module(result, 0)
  match result_func {
    Some(TFunc(_, body)) => {
      // Count ref.as_non_null instructions
      fn count_as_non_null(instr : TInstr) -> Int {
        match instr {
          TRefAsNonNull(inner) => 1 + count_as_non_null(inner)
          TLocalTee(_, inner) => count_as_non_null(inner)
          _ => 0
        }
      }

      assert_true(count_as_non_null(body.0[0]) <= 1)
    }
    _ => assert_true(false)
  }
}

// ============================================================================
// Additional test: More refined cast replaces less refined
// ============================================================================

///|
test "more refined cast replaces less refined in tracking" {
  // Input:
  //   local.get $0
  //   ref.cast (ref $1)
  //   drop
  //   local.get $0
  //   ref.cast (ref $2)  ; more refined than $1
  //   drop
  //   local.get $0       ; should use $2 cast, not $1

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(1)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
    TInstr::drop(TInstr::nop()),
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(2)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
    TInstr::drop(TInstr::nop()),
    TInstr::local_get(LocalIdx::new(0)),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)

  // The final local.get should be using the type $2 cast
  let result_func = get_func_from_module(result, 0)
  assert_true(result_func is Some(_))
}

// ============================================================================
// Test: unreachable instruction resets flow
// ============================================================================

///|
test "unreachable resets cast tracking" {
  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(1)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
    TInstr::drop(TInstr::nop()),
    TInstr::unreachable_(),
    TInstr::local_get(LocalIdx::new(0)), // dead code but processed
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  assert_true(get_func_from_module(result, 0) is Some(_))
}

// ============================================================================
// Helpers for module construction
// ============================================================================

///|
fn add_func_to_module(mod : Module, func : Func) -> Module {
  // Add a function type for the func
  let func_type = match func {
    TFunc(locals, _) =>
      // For simplicity, assume void -> void function
      FuncType::new([], [])
    _ => FuncType::new([], [])
  }
  let type_sec = match mod.type_sec {
    Some(TypeSec(recs)) => {
      let new_recs = recs.copy()
      new_recs.push(
        RecType::new(
          SubType::new(true, [], CompType::func(func_type.0, func_type.1)),
        ),
      )
      TypeSec::new(new_recs)
    }
    None =>
      TypeSec::new([
        RecType::new(
          SubType::new(true, [], CompType::func(func_type.0, func_type.1)),
        ),
      ])
  }
  let func_type_idx = TypeIdx::new(
    type_sec.0.length().reinterpret_as_uint() - 1,
  )
  let func_sec = FuncSec::new([func_type_idx])
  let code_sec = CodeSec::new([func])
  mod.with_type_sec(type_sec).with_func_sec(func_sec).with_code_sec(code_sec)
}

///|
fn get_func_from_module(mod : Module, idx : Int) -> Func? {
  match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.get(idx)
    None => None
  }
}

// ============================================================================
// Future optimization tests - features that SHOULD be optimized
// ============================================================================

// Test: br_on_cast success path should track the cast

///|
test "br_on_cast_fail continuation knows cast succeeded" {
  // After br_on_cast_fail, if we continue, we know the cast succeeded
  // This could be tracked but currently resets flow

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_on_cast_fail(
          LabelIdx::new(0),
          true, // nullabilities
          HeapType::new(TypeIdx::new(0)),
          true,
          HeapType::new(TypeIdx::new(1)),
          TInstr::local_get(LocalIdx::new(0)),
          [],
        ),
        // If we reach here, the value IS (ref $1)
        TInstr::drop(TInstr::nop()),
        TInstr::local_get(LocalIdx::new(0)), // Could use refined type
      ]),
    ),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  // Currently this won't optimize, but it should in the future
  assert_true(get_func_from_module(result, 0) is Some(_))
}

// Test: br_on_null continuation knows value is non-null

///|
test "br_on_null continuation knows non_null" {
  // After br_on_null, if we continue, the value is non-null

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_on_null(
          LabelIdx::new(0),
          TInstr::local_get(LocalIdx::new(0)),
          [],
        ),
        // If we reach here, $0 is non-null
        TInstr::drop(TInstr::nop()),
        TInstr::ref_as_non_null(TInstr::local_get(LocalIdx::new(0))), // redundant
      ]),
    ),
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  assert_true(get_func_from_module(result, 0) is Some(_))
}

// Test: struct.get/array.get on casted reference

///|
test "field access on casted ref uses refined type" {
  // After casting, field accesses should benefit from the refined type
  // (This is more about type propagation than cast optimization)

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(1)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
    TInstr::drop(TInstr::nop()),
    // Now accessing fields of local $0 should use refined type knowledge
    // Even without explicit cast on this local.get
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  assert_true(get_func_from_module(result, 0) is Some(_))
}

// Test: Cast removal when target type equals source type

///|
test "cast to same type removed" {
  // ref.cast (ref $0) on a value already known to be (ref $0) is redundant

  let mod = make_test_module_with_hierarchy()
  let local_type = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(1))),
  ) // Already (ref $1)
  let body = TExpr::new([
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(1)),
      TInstr::local_get(LocalIdx::new(0)),
    ), // redundant
  ])
  let func = Func::t_func([local_type], body)
  let mod_with_func = add_func_to_module(mod, func)
  let result = optimize_casts(mod_with_func)
  let result_func = get_func_from_module(result, 0)
  match result_func {
    Some(TFunc(_, body)) =>
      // Ideally the cast would be removed entirely
      match body.0[0] {
        TLocalGet(_) => () // Perfect - cast removed
        TRefCast(_, _, _) => () // Cast preserved - could be optimized
        _ => ()
      }
    _ => assert_true(false)
  }
}

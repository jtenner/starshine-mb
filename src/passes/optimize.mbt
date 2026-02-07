///|
pub(all) enum ModulePass {
  AbstractTypeRefining(AbstractTypeRefiningPassProps)
  AlignmentLowering
  AvoidReinterprets
  CoalesceLocals
  CodeFolding
  CodePushing
  ConstHoisting
  ConstantFieldPropagation
  DataflowOptimization
  Directize(Bool)
  OptimizeCasts
  DeNaN
  RemoveUnused
}

///|
fn apply_ir_transformer_pass(
  ctx : IRContext,
  mod : Module,
  pass : ModuleTransformer[IRContext],
) -> Result[Module, String] {
  match pass.walk_module(ctx, mod) {
    Ok(Some((_, new_mod))) => Ok(new_mod)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
  }
}

///|
pub fn optimize_module(
  mod : Module,
  passes : Array[ModulePass],
) -> Result[Module, String] {
  let mut mod = mod
  let ctx = IRContext::new()
  ctx.set_mod(mod)
  mod = match
    apply_ir_transformer_pass(
      ctx,
      mod,
      wrap_unit_func_pass(lift_to_texpr_pass()),
    ) {
    Ok(new_mod) => new_mod
    Err(e) => return Err(e)
  }
  ctx.set_mod(mod)
  for pass in passes {
    ctx.set_mod(mod)
    mod = match pass {
      AbstractTypeRefining(props) =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            abstract_type_refining(mod, props.traps_never_happen),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      AlignmentLowering =>
        match
          apply_ir_transformer_pass(ctx, mod, alignment_lowering_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      AvoidReinterprets =>
        match
          apply_ir_transformer_pass(ctx, mod, avoid_reinterprets_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      CoalesceLocals =>
        match apply_ir_transformer_pass(ctx, mod, coalesce_locals_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      CodeFolding =>
        match apply_ir_transformer_pass(ctx, mod, code_folding_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      CodePushing =>
        match apply_ir_transformer_pass(ctx, mod, code_pushing_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      ConstHoisting =>
        match apply_ir_transformer_pass(ctx, mod, const_hoisting_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      ConstantFieldPropagation =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            constant_field_propagation_ir_pass(mod),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      DataflowOptimization =>
        match
          apply_ir_transformer_pass(ctx, mod, dataflow_optimization_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      Directize(initial_immutable) =>
        match directize_ir_pass(mod, initial_immutable) {
          Ok(pass) =>
            match apply_ir_transformer_pass(ctx, mod, pass) {
              Ok(new_mod) => new_mod
              Err(e) => return Err(e)
            }
          Err(e) => return Err(e)
        }
      OptimizeCasts =>
        match apply_ir_transformer_pass(ctx, mod, optimize_casts_ir_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      DeNaN =>
        match run_denam(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      RemoveUnused =>
        match remove_unused(mod) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
    }
    ctx.set_mod(mod)
  }
  Ok(mod)
}

///|
test "optimize_module runs AvoidReinterprets pass" {
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::unary(
        UnaryOp::i32_reinterpret_f32(),
        TInstr::load(
          LoadOp::f32_load(),
          MemArg::new(0, None, 0),
          TInstr::i32_const(I32(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let optimized = match optimize_module(mod, [AvoidReinterprets]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  let CodeSec(funcs) = optimized.code_sec.unwrap()
  match funcs[0] {
    TFunc(_, TExpr(instrs)) =>
      match instrs[0] {
        TLoad(LoadOp::I32LoadOp, _, _) => ()
        _ => fail("expected reinterpret(load) to become i32.load")
      }
    _ => fail("expected TFunc")
  }
}

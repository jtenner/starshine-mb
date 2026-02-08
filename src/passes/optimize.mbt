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
  DeadCodeElimination
  DeadArgumentElimination
  DuplicateFunctionElimination
  Directize(Bool)
  OptimizeCasts
  DeNaN
  RemoveUnused
}

///|
pub struct OptimizeOptions {
  optimize_level : Int
  shrink_level : Int
}

///|
pub fn OptimizeOptions::new(
  optimize_level? : Int = 0,
  shrink_level? : Int = 0,
) -> OptimizeOptions {
  { optimize_level, shrink_level }
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
  optimize_module_with_options(mod, passes, OptimizeOptions::new())
}

///|
pub fn optimize_module_with_options(
  mod : Module,
  passes : Array[ModulePass],
  options : OptimizeOptions,
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
      DeadCodeElimination =>
        match
          apply_ir_transformer_pass(
            ctx,
            mod,
            dead_code_elimination_ir_pass(mod),
          ) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      DeadArgumentElimination =>
        match
          apply_ir_transformer_pass(ctx, mod, dead_argument_elim_pass(mod)) {
          Ok(new_mod) => new_mod
          Err(e) => return Err(e)
        }
      DuplicateFunctionElimination =>
        match duplicate_function_elimination(mod, options) {
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

///|
test "optimize_module runs DeadArgumentElimination pass" {
  let caller = Func::t_func(
    [],
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(9))])]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        single_rec_type(
          comp_type_sub_type(func_comp_type([ValType::i32()], [ValType::i32()])),
        ),
        single_rec_type(
          comp_type_sub_type(func_comp_type([], [ValType::i32()])),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = match optimize_module(mod, [DeadArgumentElimination]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr(instrs)), _])) => {
      let mut found = false
      for instr in instrs {
        match instr {
          TCall(_, args) => {
            found = true
            assert_eq(args.length(), 0)
          }
          _ => ()
        }
      }
      assert_true(found)
    }
    _ => fail("expected rewritten call")
  }
}

///|
test "optimize_module runs DeadCodeElimination pass" {
  let func = Func::t_func(
    [],
    TExpr::new([TInstr::unreachable_(), TInstr::i32_const(I32(7))]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let optimized = match optimize_module(mod, [DeadCodeElimination]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TUnreachable]))])) => ()
    _ => fail("expected dead tail after unreachable to be removed")
  }
}

///|
test "optimize_module runs DuplicateFunctionElimination pass" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let root = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), []),
      TInstr::call(FuncIdx::new(2), []),
    ]),
  )
  let dup_a = Func::t_func([], TExpr::new([TInstr::nop()]))
  let dup_b = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(CodeSec::new([root, dup_a, dup_b]))
  let optimized = match optimize_module(mod, [DuplicateFunctionElimination]) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
}

///|
test "optimize_module_with_options controls DuplicateFunctionElimination iterations" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let a1 = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(2), [])]))
  let a2 = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(3), [])]))
  let b1 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let b2 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(0),
      ]),
    )
    .with_code_sec(CodeSec::new([a1, a2, b1, b2]))
  let low = match
    optimize_module_with_options(
      mod,
      [DuplicateFunctionElimination],
      OptimizeOptions::new(optimize_level=0, shrink_level=0),
    ) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module_with_options error: \{e}")
  }
  match low.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 3)
    None => fail("expected code section")
  }
  let high = match
    optimize_module_with_options(
      mod,
      [DuplicateFunctionElimination],
      OptimizeOptions::new(optimize_level=2, shrink_level=0),
    ) {
    Ok(m) => m
    Err(e) => fail("unexpected optimize_module_with_options error: \{e}")
  }
  match high.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
}

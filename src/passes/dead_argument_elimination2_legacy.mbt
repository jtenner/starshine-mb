///|
// Adapt multiple legacy handlers to the HOT try_table representation. Handler
// bodies execute outside the protected region, and catch_ref preserves the
// original exception identity for rethrow. The ordinary single-handler path
// stays in legacy form.
priv struct Dae2LegacyState {
  env : @validate.Env
  types : HotPipelineLowerState
  locals : Array[@lib.ValType]
  params : Int
  needs_exception_identity : Bool
  mut changed : Bool
}

///|
fn dae2_legacy_label(
  labels : Array[Int],
  label : @lib.LabelIdx,
) -> @lib.LabelIdx {
  let @lib.LabelIdx(raw) = label
  @lib.LabelIdx::new(labels[raw.to_int()].reinterpret_as_uint())
}

///|
fn dae2_legacy_push_labels(labels : Array[Int]) -> Array[Int] {
  let next = [0]
  next.append(labels.map(fn(depth) { depth + 1 }))
  next
}

///|
fn dae2_legacy_block_type(
  state : Dae2LegacyState,
  results : Array[@lib.ValType],
) -> @lib.BlockType {
  match results {
    [] => @lib.BlockType::void_()
    [ty] => @lib.BlockType::val_type(ty)
    _ =>
      @lib.BlockType::type_idx(
        run_hot_pipeline_lower_intern_block_result_type_idx(
          state.types,
          results,
        ),
      )
  }
}

///|
fn dae2_legacy_local(
  state : Dae2LegacyState,
  ty : @lib.ValType,
) -> @lib.LocalIdx {
  let index = state.params + state.locals.length()
  state.locals.push(ty)
  @lib.LocalIdx::new(index.reinterpret_as_uint())
}

///|
fn dae2_legacy_catch(catch_ : @lib.Catch, labels : Array[Int]) -> @lib.Catch {
  match catch_ {
    @lib.Catch(tag, label) =>
      @lib.Catch::new(tag, dae2_legacy_label(labels, label))
    @lib.CatchRef(tag, label) =>
      @lib.Catch::ref_(tag, dae2_legacy_label(labels, label))
    @lib.CatchAll(label) => @lib.Catch::all(dae2_legacy_label(labels, label))
    @lib.CatchAllRef(label) =>
      @lib.Catch::all_ref(dae2_legacy_label(labels, label))
  }
}

///|
fn dae2_legacy_handlers(
  handlers : Array[@lib.ResumeHandler],
  labels : Array[Int],
) -> Array[@lib.ResumeHandler] {
  handlers.map(fn(handler) {
    match handler {
      @lib.ResumeOnLabel(tag, label) =>
        @lib.ResumeHandler::on_label(tag, dae2_legacy_label(labels, label))
      @lib.ResumeOnSwitch(_) => handler
    }
  })
}

///|
fn dae2_legacy_body(
  state : Dae2LegacyState,
  instrs : Array[@lib.Instruction],
  labels : Array[Int],
  exceptions : Array[Int],
) -> Result[Array[@lib.Instruction], String] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    let next = match instr {
      @lib.Instruction::Br(label) =>
        @lib.Instruction::br(dae2_legacy_label(labels, label))
      @lib.Instruction::BrIf(label) =>
        @lib.Instruction::br_if(dae2_legacy_label(labels, label))
      @lib.Instruction::BrTable(targets, fallback) =>
        @lib.Instruction::br_table(
          targets.map(fn(label) { dae2_legacy_label(labels, label) }),
          dae2_legacy_label(labels, fallback),
        )
      @lib.Instruction::BrOnNull(label) =>
        @lib.Instruction::br_on_null(dae2_legacy_label(labels, label))
      @lib.Instruction::BrOnNonNull(label) =>
        @lib.Instruction::br_on_non_null(dae2_legacy_label(labels, label))
      @lib.Instruction::BrOnCast(label, flags, source, target) =>
        @lib.Instruction::br_on_cast(
          dae2_legacy_label(labels, label),
          flags.source_nullable(),
          source,
          flags.target_nullable(),
          target,
          source_exact=flags.source_exact(),
          target_exact=flags.target_exact(),
        )
      @lib.Instruction::BrOnCastFail(label, flags, source, target) =>
        @lib.Instruction::br_on_cast_fail(
          dae2_legacy_label(labels, label),
          flags.source_nullable(),
          source,
          flags.target_nullable(),
          target,
          source_exact=flags.source_exact(),
          target_exact=flags.target_exact(),
        )
      @lib.Instruction::BrOnCastDescEq(label, source, target) =>
        @lib.Instruction::br_on_cast_desc_eq(
          dae2_legacy_label(labels, label),
          source,
          target,
        )
      @lib.Instruction::BrOnCastDescEqFail(label, source, target) =>
        @lib.Instruction::br_on_cast_desc_eq_fail(
          dae2_legacy_label(labels, label),
          source,
          target,
        )
      @lib.Instruction::Block(bt, @lib.Expr(body))
      | @lib.Instruction::Loop(bt, @lib.Expr(body)) => {
        let rewritten = match
          dae2_legacy_body(
            state,
            body,
            dae2_legacy_push_labels(labels),
            exceptions,
          ) {
          Ok(body) => body
          Err(err) => return Err(err)
        }
        if instr is @lib.Instruction::Block(_, _) {
          @lib.Instruction::block(bt, @lib.Expr::new(rewritten))
        } else {
          @lib.Instruction::loop_(bt, @lib.Expr::new(rewritten))
        }
      }
      @lib.Instruction::If(bt, yes, no) => {
        let inner = dae2_legacy_push_labels(labels)
        let yes = match dae2_legacy_body(state, yes, inner, exceptions) {
          Ok(body) => body
          Err(err) => return Err(err)
        }
        let no = match no {
          Some(body) =>
            match dae2_legacy_body(state, body, inner, exceptions) {
              Ok(body) => Some(body)
              Err(err) => return Err(err)
            }
          None => None
        }
        @lib.Instruction::if_(bt, yes, no)
      }
      @lib.Instruction::TryTable(bt, catches, @lib.Expr(body)) => {
        let body = match
          dae2_legacy_body(
            state,
            body,
            dae2_legacy_push_labels(labels),
            exceptions,
          ) {
          Ok(body) => body
          Err(err) => return Err(err)
        }
        @lib.Instruction::try_table(
          bt,
          catches.map(fn(catch_) { dae2_legacy_catch(catch_, labels) }),
          @lib.Expr::new(body),
        )
      }
      @lib.Instruction::Try(bt, @lib.Expr(body), catches, delegate) =>
        if catches.length() <= 1 {
          let inner = dae2_legacy_push_labels(labels)
          let body = match dae2_legacy_body(state, body, inner, exceptions) {
            Ok(body) => body
            Err(err) => return Err(err)
          }
          let next_catches : Array[@lib.LegacyCatch] = []
          let handler_exceptions = [-1]
          handler_exceptions.append(exceptions)
          for catch_ in catches {
            let catch_body = match catch_ {
              @lib.LegacyCatch(_, @lib.Expr(body))
              | @lib.LegacyCatchAll(@lib.Expr(body)) => body
            }
            let rewritten = match
              dae2_legacy_body(state, catch_body, inner, handler_exceptions) {
              Ok(body) => body
              Err(err) => return Err(err)
            }
            next_catches.push(
              match catch_ {
                @lib.LegacyCatch(tag, _) =>
                  @lib.LegacyCatch::tagged(tag, @lib.Expr::new(rewritten))
                @lib.LegacyCatchAll(_) =>
                  @lib.LegacyCatch::all(@lib.Expr::new(rewritten))
              },
            )
          }
          @lib.Instruction::try_(
            bt,
            @lib.Expr::new(body),
            next_catches,
            delegate=delegate.map(fn(label) { dae2_legacy_label(labels, label) }),
          )
        } else {
          if delegate is Some(_) {
            return Err("dae2: legacy try mixes catches and delegate")
          }
          state.changed = true
          let count = catches.length()
          let (params, results) = match state.env.expand_blocktype(bt) {
            Ok(types) => types
            Err(err) => return Err(err)
          }
          let result_bt = dae2_legacy_block_type(state, results)
          let parameter_locals = params.map(fn(ty) {
            dae2_legacy_local(state, ty)
          })
          for i = parameter_locals.length() - 1; i >= 0; i = i - 1 {
            out.push(@lib.Instruction::local_set(parameter_locals[i]))
          }
          let body_labels = [count + 1]
          body_labels.append(labels.map(fn(depth) { depth + count + 2 }))
          let rewritten_body = match
            dae2_legacy_body(state, body, body_labels, exceptions) {
            Ok(body) => body
            Err(err) => return Err(err)
          }
          let protected_body = parameter_locals.map(fn(index) {
            @lib.Instruction::local_get(index)
          })
          protected_body.append(rewritten_body)
          let arms : Array[@lib.Catch] = []
          let payload_types : Array[Array[@lib.ValType]] = []
          for i = 0; i < count; i = i + 1 {
            let target = @lib.LabelIdx::new(i.reinterpret_as_uint())
            let payload = match catches[i] {
              @lib.LegacyCatch(tag, _) => {
                arms.push(
                  if state.needs_exception_identity {
                    @lib.Catch::ref_(tag, target)
                  } else {
                    @lib.Catch::new(tag, target)
                  },
                )
                match state.env.resolve_tag_functype(tag) {
                  Some(@lib.FuncType(params, _)) => params.copy()
                  None => return Err("dae2: invalid legacy catch tag")
                }
              }
              @lib.LegacyCatchAll(_) => {
                arms.push(
                  if state.needs_exception_identity {
                    @lib.Catch::all_ref(target)
                  } else {
                    @lib.Catch::all(target)
                  },
                )
                []
              }
            }
            if state.needs_exception_identity {
              payload.push(@lib.ValType::ref_null_exn())
            }
            payload_types.push(payload)
          }
          let mut nested = [
            @lib.Instruction::try_table(
              result_bt,
              arms,
              @lib.Expr::new(protected_body),
            ),
            @lib.Instruction::br(
              @lib.LabelIdx::new(count.reinterpret_as_uint()),
            ),
          ]
          for i = 0; i < count; i = i + 1 {
            let handler_labels = [count - 1 - i]
            handler_labels.append(labels.map(fn(depth) { depth + count - i }))
            let exception = if state.needs_exception_identity {
              Some(dae2_legacy_local(state, @lib.ValType::ref_null_exn()))
            } else {
              None
            }
            let handler_exceptions = [
              match exception {
                Some(@lib.LocalIdx(raw)) => raw.to_int()
                None => -1
              },
            ]
            handler_exceptions.append(exceptions)
            let catch_body = match catches[i] {
              @lib.LegacyCatch(_, @lib.Expr(body))
              | @lib.LegacyCatchAll(@lib.Expr(body)) => body
            }
            let handler_body = match
              dae2_legacy_body(
                state, catch_body, handler_labels, handler_exceptions,
              ) {
              Ok(body) => body
              Err(err) => return Err(err)
            }
            let next = [
              @lib.Instruction::block(
                dae2_legacy_block_type(state, payload_types[i]),
                @lib.Expr::new(nested),
              ),
            ]
            if exception is Some(index) {
              next.push(@lib.Instruction::local_set(index))
            }
            next.append(handler_body)
            next.push(
              @lib.Instruction::br(
                @lib.LabelIdx::new((count - 1 - i).reinterpret_as_uint()),
              ),
            )
            nested = next
          }
          @lib.Instruction::block(result_bt, @lib.Expr::new(nested))
        }
      @lib.Instruction::Rethrow(@lib.LabelIdx(depth)) => {
        let target = exceptions[depth.to_int()]
        if target >= 0 {
          out.push(
            @lib.Instruction::local_get(
              @lib.LocalIdx::new(target.reinterpret_as_uint()),
            ),
          )
          @lib.Instruction::throw_ref()
        } else {
          let mut retained = 0
          for i = 0; i < depth.to_int(); i = i + 1 {
            if exceptions[i] < 0 {
              retained += 1
            }
          }
          @lib.Instruction::rethrow(
            @lib.LabelIdx::new(retained.reinterpret_as_uint()),
          )
        }
      }
      @lib.Instruction::Resume(ty, handlers) =>
        @lib.Instruction::resume_(ty, dae2_legacy_handlers(handlers, labels))
      @lib.Instruction::ResumeThrow(ty, tag, handlers) =>
        @lib.Instruction::resume_throw(
          ty,
          tag,
          dae2_legacy_handlers(handlers, labels),
        )
      @lib.Instruction::ResumeThrowRef(ty, handlers) =>
        @lib.Instruction::resume_throw_ref(
          ty,
          dae2_legacy_handlers(handlers, labels),
        )
      _ => instr
    }
    out.push(next)
  }
  Ok(out)
}

///|
fn dae2_prepare_legacy_handlers(
  mod_ : @lib.Module,
) -> Result[@lib.Module, String] {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Ok(mod_)
  }
  let env = @validate.Env::new().with_module(mod_)
  let types : HotPipelineLowerState = {
    next_type_sec: mod_.type_sec,
    type_sec_changed: false,
  }
  let bodies : Array[@lib.Func] = []
  let imported = dae_imported_func_count(mod_)
  let mut changed = false
  for index = 0; index < funcs.length(); index = index + 1 {
    let @lib.Func(locals, @lib.Expr(body)) = funcs[index]
    let params = match
      env.get_functype_by_funcidx(
        @lib.FuncIdx::new((index + imported).reinterpret_as_uint()),
      ) {
      Some(@lib.FuncType(params, _)) => params.length()
      None => return Err("dae2: missing legacy function type")
    }
    let local_types = locals.iter().to_array()
    let state : Dae2LegacyState = {
      env,
      types,
      locals: local_types,
      params,
      needs_exception_identity: dae2_legacy_has_rethrow(body),
      changed: false,
    }
    let body = match dae2_legacy_body(state, body, [0], []) {
      Ok(body) => body
      Err(err) => return Err(err)
    }
    changed = changed || state.changed
    bodies.push(
      @lib.Func::new(@lib.Locals::from_types(local_types), @lib.Expr::new(body)),
    )
  }
  if !changed {
    return Ok(mod_)
  }
  let next = mod_.with_code_sec(@lib.CodeSec::new(bodies))
  let next = match types.next_type_sec {
    Some(types) => next.with_type_sec(types)
    None => next
  }
  match @validate.validate_module(next) {
    Ok(_) => Ok(next)
    Err(err) => Err("dae2: invalid legacy handler adaptation: \{err}")
  }
}

///|
fn dae2_legacy_has_rethrow(instrs : Array[@lib.Instruction]) -> Bool {
  // A nested handler can rethrow an outer exception. Retain all identities in
  // that function; do not infer a handler-local absence from its own body only.
  let work = [instrs]
  while !work.is_empty() {
    for instr in work.pop().unwrap() {
      match instr {
        @lib.Instruction::Rethrow(_) => return true
        @lib.Instruction::Block(_, @lib.Expr(body))
        | @lib.Instruction::Loop(_, @lib.Expr(body))
        | @lib.Instruction::TryTable(_, _, @lib.Expr(body)) => work.push(body)
        @lib.Instruction::If(_, yes, no) => {
          work.push(yes)
          if no is Some(body) {
            work.push(body)
          }
        }
        @lib.Instruction::Try(_, @lib.Expr(body), catches, _) => {
          work.push(body)
          for catch_ in catches {
            match catch_ {
              @lib.LegacyCatch(_, @lib.Expr(body))
              | @lib.LegacyCatchAll(@lib.Expr(body)) => work.push(body)
            }
          }
        }
        _ => ()
      }
    }
  }
  false
}

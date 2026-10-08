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
priv struct Dae2LegacyLabelWorkspace {
  heads : Array[Int]
  offset_prefixes : Array[Int]
}

///|
priv struct Dae2LegacyLabels {
  workspace : Dae2LegacyLabelWorkspace
  length : Int
}

///|
fn Dae2LegacyLabels::root() -> Dae2LegacyLabels {
  { workspace: { heads: [0], offset_prefixes: [0], }, length: 1, }
}

///|
fn Dae2LegacyLabels::push(
  self : Dae2LegacyLabels,
  head : Int,
  tail_offset : Int,
) -> Dae2LegacyLabels {
  let index = self.length
  let prefix = self.workspace.offset_prefixes[index - 1] + tail_offset
  if index < self.workspace.heads.length() {
    self.workspace.heads[index] = head
    self.workspace.offset_prefixes[index] = prefix
  } else {
    self.workspace.heads.push(head)
    self.workspace.offset_prefixes.push(prefix)
  }
  { workspace: self.workspace, length: index + 1, }
}

///|
fn Dae2LegacyLabels::resolve(self : Dae2LegacyLabels, depth : Int) -> Int {
  if depth < 0 || depth >= self.length {
    abort("invalid legacy label depth")
  }
  let ancestor = self.length - 1 - depth
  self.workspace.heads[ancestor] +
  self.workspace.offset_prefixes[self.length - 1] -
  self.workspace.offset_prefixes[ancestor]
}

///|
fn Dae2LegacyLabels::frame_count(self : Dae2LegacyLabels) -> Int {
  self.length
}

///|
fn dae2_legacy_label(
  labels : Dae2LegacyLabels,
  label : @lib.LabelIdx,
) -> @lib.LabelIdx {
  let @lib.LabelIdx(raw) = label
  @lib.LabelIdx::new(labels.resolve(raw.to_int()).reinterpret_as_uint())
}

///|
fn dae2_legacy_push_labels(labels : Dae2LegacyLabels) -> Dae2LegacyLabels {
  labels.push(0, 1)
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
fn dae2_legacy_catch(
  catch_ : @lib.Catch,
  labels : Dae2LegacyLabels,
) -> @lib.Catch {
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
  labels : Dae2LegacyLabels,
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
#valtype
priv struct Dae2LegacyExceptionFrame {
  source_label_count : Int
  local_id : Int
}

///|
fn dae2_legacy_body(
  state : Dae2LegacyState,
  instrs : Array[@lib.Instruction],
  labels : Dae2LegacyLabels,
  exceptions : Array[Dae2LegacyExceptionFrame],
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
          // Borrow one catch stack; push/pop avoids copying ancestor rows.
          let handler_exceptions = exceptions
          handler_exceptions.push({
            source_label_count: inner.frame_count(),
            local_id: -1,
          })
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
          ignore(handler_exceptions.pop())
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
          let body_labels = labels.push(count + 1, count + 2)
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
            let handler_labels = labels.push(count - 1 - i, count - i)
            let exception = if state.needs_exception_identity {
              Some(dae2_legacy_local(state, @lib.ValType::ref_null_exn()))
            } else {
              None
            }
            let handler_exceptions = exceptions
            handler_exceptions.push({
              source_label_count: handler_labels.frame_count(),
              local_id: match exception {
                Some(index) => index.0.to_int()
                None => -1
              },
            })
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
            ignore(handler_exceptions.pop())
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
        if depth >= labels.frame_count().reinterpret_as_uint() {
          return Err("invalid legacy rethrow label depth")
        }
        let target_prefix = labels.frame_count() - depth.reinterpret_as_int()
        let mut target = None
        for i = exceptions.length() - 1; i >= 0; i = i - 1 {
          if exceptions[i].source_label_count == target_prefix {
            target = Some(exceptions[i].local_id)
            break
          }
        }
        let local_id = match target {
          Some(id) => id
          None => return Err("legacy rethrow must target an active catch label")
        }
        if local_id >= 0 {
          out.push(
            @lib.Instruction::local_get(
              @lib.LocalIdx::new(local_id.reinterpret_as_uint()),
            ),
          )
          @lib.Instruction::throw_ref()
        } else {
          @lib.Instruction::rethrow(
            dae2_legacy_label(labels, @lib.LabelIdx::new(depth)),
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
fn dae2_legacy_unchanged_func(func : @lib.Func) -> @lib.Func {
  let @lib.Func(locals, body) = func
  let runs = locals.runs()
  for index in 0..<runs.length() {
    if runs[index].count == 0U ||
      (index > 0 && runs[index - 1].vt == runs[index].vt) {
      // Handler adaptation historically canonicalizes declaration groups in
      // every function of a changed module. Preserve those exact bytes while
      // retaining the original instruction span and avoiding expanded locals.
      return @lib.Func::new(@lib.Locals::new(runs), body)
    }
  }
  func
}

///|
#valtype
priv struct Dae2LegacySetup {
  env : @validate.Env
  types : HotPipelineLowerState
  bodies : Array[@lib.Func]
}

///|
fn Dae2LegacySetup::new(mod_ : @lib.Module) -> Dae2LegacySetup {
  {
    env: @validate.Env::new().with_module(mod_),
    types: { next_type_sec: mod_.type_sec, type_sec_changed: false, },
    bodies: [],
  }
}

///|
fn dae2_legacy_signature_param_count(
  idx : @lib.TypeIdx,
  arities : Array[Int],
  last_group_start : Int,
) -> Int {
  let slot = match idx {
    @lib.TypeIdx(raw) => raw.reinterpret_as_int()
    @lib.RecIdx(raw) => {
      let relative = raw.reinterpret_as_int()
      if relative < 0 || relative >= arities.length() - last_group_start {
        return -1
      }
      last_group_start + relative
    }
  }
  arities.get(slot).unwrap_or(-1)
}

///|
// Match Env::with_module's ordered function table, including its omission of
// unresolved/non-function signatures. This is O(types + declarations), without
// body feature scans or unrelated imported/defined member environments.
fn dae2_legacy_signature_param_counts(mod_ : @lib.Module) -> Array[Int] {
  let arities : Array[Int] = []
  let mut last_group_start = 0
  if mod_.type_sec is Some(@lib.TypeSec(groups)) {
    for group in groups {
      last_group_start = arities.length()
      match group {
        @lib.SingleRecType(subtype) =>
          arities.push(
            match subtype.get_comptype() {
              @lib.FuncCompType(params, _) => params.length()
              _ => -1
            },
          )
        @lib.GroupRecType(group) =>
          for subtype in group {
            arities.push(
              match subtype.get_comptype() {
                @lib.FuncCompType(params, _) => params.length()
                _ => -1
              },
            )
          }
      }
    }
  }
  let counts : Array[Int] = []
  if mod_.import_sec is Some(@lib.ImportSec(imports)) {
    for import_ in imports {
      if import_ is @lib.Import(_, _, @lib.FuncExternType(idx)) {
        let count = dae2_legacy_signature_param_count(
          idx, arities, last_group_start,
        )
        if count >= 0 {
          counts.push(count)
        }
      }
    }
  }
  if mod_.func_sec is Some(@lib.FuncSec(indices)) {
    for idx in indices {
      let count = dae2_legacy_signature_param_count(
        idx, arities, last_group_start,
      )
      if count >= 0 {
        counts.push(count)
      }
    }
  }
  counts
}

///|
fn dae2_prepare_legacy_handlers(
  mod_ : @lib.Module,
  setup_counts? : Array[Int]? = None,
) -> Result[@lib.Module, String] {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Ok(mod_)
  }
  if funcs.is_empty() {
    return Ok(mod_)
  }
  let params_by_function = dae2_legacy_signature_param_counts(mod_)
  let mut setup : Dae2LegacySetup? = None
  let imported = dae_imported_func_count(mod_)
  let mut changed = false
  for index = 0; index < funcs.length(); index = index + 1 {
    let @lib.Func(locals, @lib.Expr(body)) = funcs[index]
    let params = match params_by_function.get(index + imported) {
      Some(params) => params
      None => return Err("dae2: missing legacy function type")
    }
    if (dae2_handler_admission(body) & 2) == 0 {
      if setup is Some(owners) {
        owners.bodies.push(dae2_legacy_unchanged_func(funcs[index]))
      }
      continue
    }
    let owners = match setup {
      Some(owners) => owners
      None => {
        if setup_counts is Some(counts) {
          counts[0] += 1
          counts[1] += 1
          counts[2] += 1
        }
        let owners = Dae2LegacySetup::new(mod_)
        for prefix in 0..<index {
          owners.bodies.push(dae2_legacy_unchanged_func(funcs[prefix]))
        }
        setup = Some(owners)
        owners
      }
    }
    let local_types = locals.iter().to_array()
    let state : Dae2LegacyState = {
      env: owners.env,
      types: owners.types,
      locals: local_types,
      params,
      needs_exception_identity: dae2_legacy_has_rethrow(body),
      changed: false,
    }
    let body = match
      dae2_legacy_body(state, body, Dae2LegacyLabels::root(), []) {
      Ok(body) => body
      Err(err) => return Err(err)
    }
    changed = changed || state.changed
    owners.bodies.push(
      if state.changed {
        @lib.Func::new(
          @lib.Locals::from_types(local_types),
          @lib.Expr::new(body),
        )
      } else {
        dae2_legacy_unchanged_func(funcs[index])
      },
    )
  }
  if !changed {
    return Ok(mod_)
  }
  let owners = setup.unwrap()
  let next = mod_.with_code_sec(@lib.CodeSec::new(owners.bodies))
  let next = match owners.types.next_type_sec {
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

///|
fn dae2_known_local_throw_target(
  block_type : @lib.BlockType,
  catches : Array[@lib.Catch],
  body : Array[@lib.Instruction],
  env : @validate.Env,
  imported_tags : Int,
) -> @lib.LabelIdx? {
  let thrown = match body.last() {
    Some(@lib.Throw(tag)) => tag
    _ => return None
  }
  let @lib.TagIdx(raw_tag) = thrown
  // Two imported tags can denote the same exception identity. A locally
  // defined tag is fresh, so declaration-order matching by index is exact.
  if raw_tag.to_int() < imported_tags ||
    env.resolve_tag_functype(thrown) is None {
    return None
  }
  match env.expand_blocktype(block_type) {
    Ok((params, _)) if params.is_empty() => ()
    _ => return None
  }
  for index = 0; index + 1 < body.length(); index = index + 1 {
    match body[index] {
      @lib.Nop
      | @lib.I32Const(_)
      | @lib.I64Const(_)
      | @lib.F32Const(_)
      | @lib.F64Const(_)
      | @lib.RefNull(_)
      | @lib.RefFunc(_)
      | @lib.LocalGet(_)
      | @lib.GlobalGet(_) => ()
      // In particular, a call can raise an exception before the final throw.
      // Removing the protected region would change that earlier dispatch.
      _ => return None
    }
  }
  for catch_ in catches {
    match catch_ {
      @lib.Catch(tag, target) if tag == thrown => return Some(target)
      @lib.CatchRef(tag, _) if tag == thrown => return None
      @lib.CatchAll(target) => return Some(target)
      @lib.CatchAllRef(_) => return None
      _ => ()
    }
  }
  None
}

///|
fn dae2_fold_known_local_throws_body(
  body : Array[@lib.Instruction],
  env : @validate.Env,
  imported_tags : Int,
) -> (Array[@lib.Instruction], Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  for instr in body {
    let instr = pass_lower_map_children(instr, fn(children) {
      let (next, child_changed) = dae2_fold_known_local_throws_body(
        children, env, imported_tags,
      )
      changed = changed || child_changed
      next
    })
    match instr {
      @lib.TryTable(bt, catches, @lib.Expr(protected_body)) =>
        match
          dae2_known_local_throw_target(
            bt, catches, protected_body, env, imported_tags,
          ) {
          Some(target) => {
            for index = 0
                index + 1 < protected_body.length()
                index = index + 1 {
              out.push(protected_body[index])
            }
            // Catch targets are relative to the surrounding scope. Removing
            // the try_table therefore makes that same depth an ordinary br.
            // A catch-all target takes no payload; br discards excess values.
            // Reference-capturing handlers are excluded by the target proof.
            out.push(@lib.Instruction::br(target))
            changed = true
            continue
          }
          None => ()
        }
      _ => ()
    }
    out.push(instr)
  }
  (out, changed)
}

///|
fn dae2_body_has_exception_or_continuation(
  body : Array[@lib.Instruction],
) -> Bool {
  for instr in body {
    match instr {
      @lib.Try(_, _, _, _)
      | @lib.TryTable(_, _, _)
      | @lib.Throw(_)
      | @lib.ThrowRef
      | @lib.Rethrow(_)
      | @lib.Suspend(_)
      | @lib.Resume(_, _)
      | @lib.ResumeThrow(_, _, _)
      | @lib.ResumeThrowRef(_, _)
      | @lib.StackSwitch(_, _) => return true
      @lib.Block(_, @lib.Expr(children)) | @lib.Loop(_, @lib.Expr(children)) =>
        if dae2_body_has_exception_or_continuation(children) {
          return true
        }
      @lib.If(_, yes, no) => {
        if dae2_body_has_exception_or_continuation(yes) {
          return true
        }
        if no is Some(no) && dae2_body_has_exception_or_continuation(no) {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
// Body-scoped admission only: bit 1 identifies a possible known throw fold,
// bit 2 a legacy multi-handler adaptation. All nested handler bodies matter.
// Signature and tag proofs remain in the admitted transformations.
fn dae2_handler_admission(body : Array[@lib.Instruction]) -> Int {
  let mut flags = 0
  for instr in body {
    match instr {
      @lib.TryTable(_, _, @lib.Expr(child)) => {
        if child.last() is Some(@lib.Throw(_)) {
          flags = flags | 1
        }
        flags = flags | dae2_handler_admission(child)
      }
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        flags = flags | dae2_handler_admission(child)
      @lib.If(_, yes, no) => {
        flags = flags | dae2_handler_admission(yes)
        if no is Some(child) {
          flags = flags | dae2_handler_admission(child)
        }
      }
      @lib.Try(_, @lib.Expr(child), catches, _) => {
        if catches.length() > 1 {
          flags = flags | 2
        }
        flags = flags | dae2_handler_admission(child)
        for catch_ in catches {
          match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(child))
            | @lib.LegacyCatchAll(@lib.Expr(child)) =>
              flags = flags | dae2_handler_admission(child)
          }
        }
      }
      _ => ()
    }
  }
  flags
}

///|
fn dae2_fold_known_local_throws(mod_ : @lib.Module) -> @lib.Module {
  let bodies = match mod_.code_sec {
    Some(@lib.CodeSec(bodies)) => bodies
    None => return mod_
  }
  let env = @validate.Env::new().with_module(mod_)
  let imported_tags = @ir.hot_module_context_from_module(mod_).imported_tag_count
  let mut any_changed = false
  let next = bodies.map(fn(func) {
    let @lib.Func(locals, @lib.Expr(body)) = func
    if (dae2_handler_admission(body) & 1) == 0 {
      return func
    }
    let (body, changed) = dae2_fold_known_local_throws_body(
      body, env, imported_tags,
    )
    if !changed {
      return func
    }
    any_changed = true
    let body = if changed && !dae2_body_has_exception_or_continuation(body) {
      // Remove unused void scaffolding only after dispatch folding has
      // eliminated exception scopes. Preserve every result block type.
      run_hot_pipeline_raw_vacuum_flatten_unbranched_result_blocks(
        body,
        true,
        false,
        flatten_results=false,
      ).0
    } else {
      body
    }
    @lib.Func::new(locals, @lib.Expr::new(body))
  })
  if any_changed {
    mod_.with_code_sec(@lib.CodeSec::new(next))
  } else {
    mod_
  }
}

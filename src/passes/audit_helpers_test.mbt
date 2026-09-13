///|
fn audit_run(wat : String, pass : String) -> @lib.Module raise {
  let input = match @wast.wast_to_binary_module(wat, filename="audit.wat") {
    Ok(value) => value
    Err(err) => fail("invalid audit syntax: \{err}")
  }
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("invalid audit input: \{err}")
  }
  match run_hot_pipeline(input, HotPipelineOptions::new(), [pass]) {
    Ok(value) => value
    Err(err) => fail("audit pipeline: \{err}")
  }
}

///|
fn audit_body(mod_ : @lib.Module, index? : Int = 0) -> Array[@lib.Instruction] {
  let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[index]
  body
}

///|
fn audit_count(
  body : Array[@lib.Instruction],
  predicate : (@lib.Instruction) -> Bool,
) -> Int {
  let mut count = 0
  for instr in body {
    if predicate(instr) {
      count += 1
    }
    match instr {
      @lib.Block(_, @lib.Expr(nested))
      | @lib.Loop(_, @lib.Expr(nested))
      | @lib.TryTable(_, _, @lib.Expr(nested)) =>
        count += audit_count(nested, predicate)
      @lib.If(_, yes, no) => {
        count += audit_count(yes, predicate)
        count += audit_count(no.unwrap_or([]), predicate)
      }
      @lib.Try(_, @lib.Expr(nested), catches, _) => {
        count += audit_count(nested, predicate)
        for catch_ in catches {
          let body = match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(body))
            | @lib.LegacyCatchAll(@lib.Expr(body)) => body
          }
          count += audit_count(body, predicate)
        }
      }
      _ => ()
    }
  }
  count
}

///|
fn audit_run_module(input : @lib.Module, pass : String) -> @lib.Module raise {
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("invalid audit IR: \{err}")
  }
  match run_hot_pipeline(input, HotPipelineOptions::new(), [pass]) {
    Ok(value) => value
    Err(err) => fail("audit IR pipeline: \{err}")
  }
}

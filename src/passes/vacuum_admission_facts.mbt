///|
priv struct VacuumPrecleanAdmissionFacts {
  mut dropped_typeidx_block : Bool
  mut flattenable_exception : Bool
  mut legacy_try : Bool
  mut fresh_array_set : Bool
  mut dropped_simple_struct : Bool
  mut needs_type_context : Bool
}

///|
fn VacuumPrecleanAdmissionFacts::new(
  body : Array[@lib.Instruction],
) -> VacuumPrecleanAdmissionFacts {
  let facts = {
    dropped_typeidx_block: false,
    flattenable_exception: false,
    legacy_try: false,
    fresh_array_set: false,
    dropped_simple_struct: false,
    needs_type_context: false,
  }
  facts.scan(body)
  facts
}

///|
fn VacuumPrecleanAdmissionFacts::scan(
  self : VacuumPrecleanAdmissionFacts,
  body : Array[@lib.Instruction],
) -> Unit {
  for idx = 0; idx < body.length(); idx = idx + 1 {
    let instr = body[idx]
    if idx + 1 < body.length() &&
      instr is @lib.StructNew(_) &&
      body[idx + 1] is @lib.Drop {
      self.dropped_simple_struct = true
    }
    if idx + 2 < body.length() &&
      instr is @lib.Block(@lib.TypeIdxBlockType(_), _) &&
      body[idx + 1] is @lib.Drop &&
      body[idx + 2] is @lib.Drop {
      self.dropped_typeidx_block = true
    }
    if idx + 4 < body.length() {
      match (instr, body[idx + 1], body[idx + 2], body[idx + 4]) {
        (
          @lib.I32Const(@lib.I32(length)),
          @lib.ArrayNewDefault(new_type),
          @lib.I32Const(@lib.I32(index)),
          @lib.ArraySet(set_type),
        ) if new_type == set_type && index >= 0 && index < length =>
          self.fresh_array_set = true
        _ => ()
      }
    }
    match instr {
      @lib.Try(_, @lib.Expr(inner), _, _) => {
        // The original admission predicates keep legacy bodies opaque. Only
        // the exception-flattening proof inspects the legacy try's body.
        self.legacy_try = true
        if !self.flattenable_exception &&
          run_hot_pipeline_raw_vacuum_body_can_flatten_no_throw_exception_region(
            inner,
          ) {
          self.flattenable_exception = true
        }
      }
      @lib.TryTable(_, _, @lib.Expr(inner)) => {
        if run_hot_pipeline_raw_vacuum_body_is_static_null_throw_ref_trap(inner) {
          self.flattenable_exception = true
        }
        self.scan(inner)
      }
      @lib.Block(block_type, @lib.Expr(inner)) => {
        if block_type is @lib.TypeIdxBlockType(_) {
          self.needs_type_context = true
        }
        if !self.flattenable_exception &&
          block_type is @lib.VoidBlockType &&
          run_hot_pipeline_raw_vacuum_body_is_owner_targeted_no_throw_try_table(
            inner,
          ) {
          self.flattenable_exception = true
        }
        self.scan(inner)
      }
      @lib.Loop(_, @lib.Expr(inner)) => self.scan(inner)
      @lib.If(block_type, then_body, else_body) => {
        if block_type is @lib.TypeIdxBlockType(_) {
          self.needs_type_context = true
        }
        self.scan(then_body)
        match else_body {
          Some(inner) => self.scan(inner)
          None => ()
        }
      }
      _ => ()
    }
  }
}

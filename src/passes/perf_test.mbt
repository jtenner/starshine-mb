///|
fn perf_test_join_lines(lines : Array[String]) -> String {
  let out = StringBuilder::new()
  for i = 0; i < lines.length(); i = i + 1 {
    if i > 0 {
      out.write_string("\n")
    }
    out.write_string(lines[i])
  }
  out.to_string()
}

///|
fn perf_test_count_occurrences(text : String, needle : String) -> Int {
  if needle == "" {
    return 0
  }
  let mut count = 0
  let mut start = 0
  while start <= text.length() - needle.length() {
    let mut found : Int? = None
    let mut i = start
    while i <= text.length() - needle.length() {
      if text.sub(start=i, end=i + needle.length()).to_string() == needle {
        found = Some(i)
        break
      }
      i += 1
    }
    match found {
      Some(idx) => {
        count += 1
        start = idx + needle.length()
      }
      None => break
    }
  }
  count
}

///|
fn perf_test_make_large_void_if_return_ladder_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 800 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < repetitions {
    let tee_local = i % 200 + 1
    let set_local = i % 200 + 201
    out.write_string("    local.get 0\n")
    out.write_string("    if\n")
    out.write_string("      local.get 0\n")
    out.write_string("      call 0\n")
    out.write_string("      local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("      local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("      i32.const 1\n")
    out.write_string("      return\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    i32.const 0)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_single_root_value_if_ladder_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 800 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    block (result i32)\n")
  let mut i = 0
  while i < repetitions {
    let tee_local = i % 200 + 1
    let set_local = i % 200 + 301
    out.write_string("      block (result i32)\n")
    out.write_string("        local.get 0\n")
    out.write_string("        if (result i32)\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call 0\n")
    out.write_string("          local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("          i32.const 1\n")
    out.write_string("        else\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call 0\n")
    out.write_string("          local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("          i32.const 2\n")
    out.write_string("        end\n")
    out.write_string("      end\n")
    out.write_string("      drop\n")
    i = i + 1
  }
  out.write_string("      i32.const 0\n")
  out.write_string("    end)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_structured_return_ladder_module(repetitions : Int) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 56 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    local.set 0\n")
  out.write_string("    block (result i32)\n")
  out.write_string("      loop\n")
  let mut i = 0
  while i < repetitions {
    let read_local = i % 8
    let tee_local = i + 8
    let set_local = i + 20
    let spill_local = i + 32
    out.write_string("        local.get 0\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(read_local.to_string())
    out.write_string("\n")
    out.write_string("        if\n")
    out.write_string("          local.get ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("          call 0\n")
    out.write_string("          local.tee ")
    out.write_string((tee_local + 1).to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    if i < 3 {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          return\n")
    } else {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          drop\n")
    }
    out.write_string("        end\n")
    i = i + 1
  }
  out.write_string("        local.get 0\n")
  out.write_string("        br_if 0\n")
  out.write_string("        local.get 1\n")
  out.write_string("        call 0\n")
  out.write_string("        local.tee 48\n")
  out.write_string("        local.set 49\n")
  out.write_string("        local.get 48\n")
  out.write_string("        local.get 1\n")
  out.write_string("        local.get 0\n")
  out.write_string("        select\n")
  out.write_string("        br 1\n")
  out.write_string("      end\n")
  out.write_string("      i32.const 0\n")
  out.write_string("    end)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_multivalue_tail_ladder_module(
  repetitions : Int,
) -> String {
  let expr = StringBuilder::new()
  expr.write_string("(i32.const 0) (local.get 0)")
  let mut i = repetitions - 1
  while i >= 0 {
    let set_local = i + 2
    let next = StringBuilder::new()
    next.write_string("(if (result i32 i32) (i32.eq (local.get 1) (i32.const ")
    next.write_string(i.to_string())
    next.write_string(")) (then (local.get 0) (call 0) (local.set ")
    next.write_string(set_local.to_string())
    next.write_string(") (i32.const 1) (local.get ")
    next.write_string(set_local.to_string())
    next.write_string(")) (else ")
    next.write_string(expr.to_string())
    next.write_string("))")
    expr.reset()
    expr.write_string(next.to_string())
    i = i - 1
  }

  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"id\" (func (param i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32 i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions + 64 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n    ")
  out.write_string(expr.to_string())
  out.write_string(")\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_multivalue_status_tail_ladder_module(
  repetitions : Int,
) -> String {
  let expr = StringBuilder::new()
  expr.write_string("(i32.const 0) (local.get 0)")
  let mut i = repetitions - 1
  while i >= 0 {
    let set_local = i + 2
    let status = if i % 2 == 0 { 0 } else { 1 }
    let next = StringBuilder::new()
    next.write_string("(if (result i32 i32) (i32.eq (local.get 1) (i32.const ")
    next.write_string(i.to_string())
    next.write_string(")) (then (local.get 0) (call 0) (local.set ")
    next.write_string(set_local.to_string())
    next.write_string(") (i32.const ")
    next.write_string(status.to_string())
    next.write_string(") (local.get ")
    next.write_string(set_local.to_string())
    next.write_string(") return) (else ")
    next.write_string(expr.to_string())
    next.write_string("))")
    expr.reset()
    expr.write_string(next.to_string())
    i = i - 1
  }

  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"id\" (func (param i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32 i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions + 64 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n    ")
  out.write_string(expr.to_string())
  out.write_string(")\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_sparse_multivalue_status_tail_ladder_module(
  repetitions : Int,
) -> String {
  let expr = StringBuilder::new()
  expr.write_string("(i32.const 0) (local.get 0)")
  let mut i = repetitions - 1
  while i >= 0 {
    let set_local = i + 2
    let scratch_local = repetitions + i + 18
    let status = if i % 2 == 0 { 0 } else { 1 }
    let next = StringBuilder::new()
    next.write_string("(if (result i32 i32) (i32.eq (local.get 1) (i32.const ")
    next.write_string(i.to_string())
    next.write_string(")) (then ")
    if i % 3 == 0 {
      next.write_string("(local.get 0) (call 0) (local.set ")
      next.write_string(set_local.to_string())
      next.write_string(") (i32.const ")
      next.write_string(status.to_string())
      next.write_string(") (local.get ")
      next.write_string(set_local.to_string())
      next.write_string(") return")
    } else {
      next.write_string("(local.get 0) (call 0) (local.set ")
      next.write_string(scratch_local.to_string())
      next.write_string(") (local.get ")
      next.write_string(scratch_local.to_string())
      next.write_string(") drop (i32.const ")
      next.write_string(status.to_string())
      next.write_string(") (local.get 0) return")
    }
    next.write_string(") (else ")
    next.write_string(expr.to_string())
    next.write_string("))")
    expr.reset()
    expr.write_string(next.to_string())
    i = i - 1
  }

  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"id\" (func (param i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32 i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions * 2 + 96 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n    ")
  out.write_string(expr.to_string())
  out.write_string(")\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_multivalue_call_ladder_module(
  repetitions : Int,
) -> String {
  let expr = StringBuilder::new()
  expr.write_string("(i32.const 0) (local.get 0)")
  let mut i = repetitions - 1
  while i >= 0 {
    let touched_local = i * 3 + 2
    let merged_local = i * 3 + 3
    let spilled_local = i * 3 + 4
    let next = StringBuilder::new()
    next.write_string("(if (result i32 i32) (i32.eq (local.get 1) (i32.const ")
    next.write_string(i.to_string())
    next.write_string(")) (then ")
    next.write_string("(local.get 0) (call 0) (local.set ")
    next.write_string(touched_local.to_string())
    next.write_string(") (local.get ")
    next.write_string(touched_local.to_string())
    next.write_string(") (local.get 1) (call 1) (local.set ")
    next.write_string(merged_local.to_string())
    next.write_string(") (local.get ")
    next.write_string(merged_local.to_string())
    next.write_string(") (local.get 0) (local.get 1) (call 2) (local.set ")
    next.write_string(spilled_local.to_string())
    next.write_string(") (local.get ")
    next.write_string(spilled_local.to_string())
    next.write_string(") drop (i32.const 1) (local.get ")
    next.write_string(spilled_local.to_string())
    next.write_string(")) (else ")
    next.write_string(expr.to_string())
    next.write_string("))")
    expr.reset()
    expr.write_string(next.to_string())
    i = i - 1
  }

  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"sink3\" (func (param i32 i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32 i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions * 3 + 64 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n    ")
  out.write_string(expr.to_string())
  out.write_string(")\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_straight_line_copy_call_tail_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (import \"env\" \"touch\" (func (param i32)))\n")
  out.write_string(
    "  (import \"env\" \"sink\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions + 16 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < repetitions {
    let target_local = i + 1
    if i % 2 == 0 {
      out.write_string("    local.get 0\n")
    } else {
      out.write_string("    i32.const ")
      out.write_string((1000 + i).to_string())
      out.write_string("\n")
    }
    out.write_string("    local.set ")
    out.write_string(target_local.to_string())
    out.write_string("\n")
    out.write_string("    local.get 0\n")
    out.write_string("    call 0\n")
    out.write_string("    local.get 0\n")
    out.write_string("    local.get ")
    out.write_string(target_local.to_string())
    out.write_string("\n")
    out.write_string("    call 1\n")
    out.write_string("    drop\n")
    i = i + 1
  }
  out.write_string("    local.get 0)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_straight_line_adjacent_tee_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"sink\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions + 32 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    i32.const 1\n")
  out.write_string("    call 0\n")
  out.write_string("    local.set 0\n")
  out.write_string("    local.get 0\n")
  out.write_string("    call 0\n")
  out.write_string("    drop\n")
  let mut i = 0
  while i < repetitions {
    out.write_string("    local.get 0\n")
    out.write_string("    call 0\n")
    out.write_string("    drop\n")
    out.write_string("    local.get 0\n")
    out.write_string("    i32.const ")
    out.write_string((1000 + i).to_string())
    out.write_string("\n")
    out.write_string("    call 1\n")
    out.write_string("    drop\n")
    i = i + 1
  }
  out.write_string("    local.get 0)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_straight_line_adjacent_drop_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"sink\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions + 32 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    i32.const 1\n")
  out.write_string("    call 0\n")
  out.write_string("    local.set 0\n")
  out.write_string("    local.get 0\n")
  out.write_string("    call 0\n")
  out.write_string("    drop\n")
  out.write_string("    i32.const 2\n")
  out.write_string("    call 0\n")
  out.write_string("    local.set 1\n")
  out.write_string("    local.get 1\n")
  out.write_string("    drop\n")
  let mut i = 0
  while i < repetitions {
    out.write_string("    local.get 0\n")
    out.write_string("    call 0\n")
    out.write_string("    drop\n")
    out.write_string("    local.get 0\n")
    out.write_string("    i32.const ")
    out.write_string((1000 + i).to_string())
    out.write_string("\n")
    out.write_string("    call 1\n")
    out.write_string("    drop\n")
    i = i + 1
  }
  out.write_string("    local.get 0)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_no_local_writes_module(
  repetitions : Int,
) -> String {
  let expr = StringBuilder::new()
  expr.write_string("(i32.const 0)")
  let mut i = repetitions - 1
  while i >= 0 {
    let next = StringBuilder::new()
    next.write_string(
      "(block (result i32) (if (result i32) (i32.eq (local.get 0) (i32.const ",
    )
    next.write_string(i.to_string())
    next.write_string(")) (then (local.get 1) drop (i32.const ")
    next.write_string((1000 + i).to_string())
    next.write_string(")) (else ")
    next.write_string(expr.to_string())
    next.write_string(")))")
    expr.reset()
    expr.write_string(next.to_string())
    i = i - 1
  }

  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    ")
  out.write_string(expr.to_string())
  out.write_string(")\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_structured_copy_call_tail_module(
  repetitions : Int,
) -> String {
  let expr = StringBuilder::new()
  expr.write_string("(i32.const 0)")
  let mut i = repetitions - 1
  while i >= 0 {
    let target_local = i + 2
    let next = StringBuilder::new()
    next.write_string("(if (result i32) (i32.eq (local.get 1) (i32.const ")
    next.write_string(i.to_string())
    next.write_string(")) (then ")
    if i % 2 == 0 {
      next.write_string("(local.get 0)")
    } else {
      next.write_string("(i32.const ")
      next.write_string((2000 + i).to_string())
      next.write_string(")")
    }
    next.write_string(" (local.set ")
    next.write_string(target_local.to_string())
    next.write_string(") (local.get 0) (call 0) (local.get 0) (local.get ")
    next.write_string(target_local.to_string())
    next.write_string(") (call 1) drop (i32.const 1)) (else ")
    next.write_string(expr.to_string())
    next.write_string("))")
    expr.reset()
    expr.write_string(next.to_string())
    i = i - 1
  }

  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (import \"env\" \"touch\" (func (param i32)))\n")
  out.write_string(
    "  (import \"env\" \"sink\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions + 64 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n    ")
  out.write_string(expr.to_string())
  out.write_string(")\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_large_equivalent_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions * 3 + 8 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    local.get 0\n")
  out.write_string("    local.set 1\n")
  let mut i = 0
  while i < repetitions {
    let copy_local = i * 3 + 2
    let spill_local = i * 3 + 3
    let merge_local = i * 3 + 4
    out.write_string("    block\n")
    out.write_string("      local.get 0\n")
    out.write_string("      if\n")
    out.write_string("        block\n")
    out.write_string("          local.get 1\n")
    out.write_string("          local.set ")
    out.write_string(copy_local.to_string())
    out.write_string("\n")
    out.write_string("        end\n")
    out.write_string("        block\n")
    out.write_string("          local.get ")
    out.write_string(copy_local.to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    out.write_string("        end\n")
    out.write_string("        local.get ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(merge_local.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(merge_local.to_string())
    out.write_string("\n")
    out.write_string("        drop\n")
    out.write_string("      else\n")
    out.write_string("        block\n")
    out.write_string("          local.get 1\n")
    out.write_string("          local.set ")
    out.write_string(copy_local.to_string())
    out.write_string("\n")
    out.write_string("        end\n")
    out.write_string("        block\n")
    out.write_string("          local.get ")
    out.write_string(copy_local.to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    out.write_string("        end\n")
    out.write_string("        local.get ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(merge_local.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(merge_local.to_string())
    out.write_string("\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 1)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_sparse_equivalent_module(
  local_count : Int,
  copy_pairs : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < local_count {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    local.get 0\n")
  out.write_string("    local.set 1\n")
  let mut churn_local = 2
  while churn_local < local_count {
    out.write_string("    i32.const ")
    out.write_string((1000 + churn_local).to_string())
    out.write_string("\n")
    out.write_string("    local.set ")
    out.write_string(churn_local.to_string())
    out.write_string("\n")
    out.write_string("    local.get ")
    out.write_string(churn_local.to_string())
    out.write_string("\n")
    out.write_string("    call 0\n")
    out.write_string("    drop\n")
    churn_local = churn_local + 1
  }
  let mut pair = 0
  while pair < copy_pairs {
    let target_local = pair + 2
    out.write_string("    block\n")
    out.write_string("      local.get 1\n")
    out.write_string("      local.set ")
    out.write_string(target_local.to_string())
    out.write_string("\n")
    out.write_string("      local.get ")
    out.write_string(target_local.to_string())
    out.write_string("\n")
    out.write_string("      drop\n")
    out.write_string("    end\n")
    pair = pair + 1
  }
  out.write_string("    local.get 1)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_structured_call_heavy_module(
  repetitions : Int,
  base_locals : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"sink3\" (func (param i32 i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions * 4 + base_locals {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < repetitions {
    let touched_local = i * 4 + 4
    let merged_local = i * 4 + 5
    let spilled_local = i * 4 + 6
    out.write_string("    local.get 0\n")
    out.write_string("    i32.const ")
    out.write_string(i.to_string())
    out.write_string("\n")
    out.write_string("    i32.eq\n")
    out.write_string("    if\n")
    out.write_string("      local.get 0\n")
    out.write_string("      call 0\n")
    out.write_string("      local.set ")
    out.write_string(touched_local.to_string())
    out.write_string("\n")
    out.write_string("      local.get 1\n")
    out.write_string("      local.get ")
    out.write_string(touched_local.to_string())
    out.write_string("\n")
    out.write_string("      call 1\n")
    out.write_string("      local.set ")
    out.write_string(merged_local.to_string())
    out.write_string("\n")
    out.write_string("      local.get ")
    out.write_string(merged_local.to_string())
    out.write_string("\n")
    out.write_string("      local.get 1\n")
    out.write_string("      local.get 0\n")
    out.write_string("      call 2\n")
    out.write_string("      local.set ")
    out.write_string(spilled_local.to_string())
    out.write_string("\n")
    out.write_string("      local.get ")
    out.write_string(spilled_local.to_string())
    out.write_string("\n")
    out.write_string("      return\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 1)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_giant_structured_call_heavy_module(
  repetitions : Int,
) -> String {
  perf_test_make_simplify_locals_structured_call_heavy_module(repetitions, 960)
}

///|
fn perf_test_make_simplify_locals_large_structured_call_heavy_module(
  repetitions : Int,
) -> String {
  perf_test_make_simplify_locals_structured_call_heavy_module(repetitions, 64)
}

///|
fn perf_test_make_simplify_locals_transformer_structured_call_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 92 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  let mut group = 0
  while group < 8 {
    out.write_string("    block\n")
    let mut inner = 0
    while inner < 3 {
      let i = group * 3 + inner
      let touched_local = 2 + i * 3
      let merged_local = 3 + i * 3
      let spilled_local = 4 + i * 3
      if inner == 1 {
        out.write_string("      block\n")
      }
      out.write_string("        local.get 0\n")
      out.write_string("        i32.const ")
      out.write_string(i.to_string())
      out.write_string("\n")
      out.write_string("        i32.eq\n")
      out.write_string("        if\n")
      out.write_string("          local.get 0\n")
      out.write_string("          call 0\n")
      out.write_string("          local.tee ")
      out.write_string(touched_local.to_string())
      out.write_string("\n")
      out.write_string("          drop\n")
      out.write_string("          local.get 1\n")
      out.write_string("          local.get ")
      out.write_string(touched_local.to_string())
      out.write_string("\n")
      out.write_string("          call 1\n")
      out.write_string("          local.set ")
      out.write_string(merged_local.to_string())
      out.write_string("\n")
      out.write_string("          local.get ")
      out.write_string(merged_local.to_string())
      out.write_string("\n")
      if i % 2 == 0 {
        out.write_string("          local.set ")
        out.write_string(spilled_local.to_string())
        out.write_string("\n")
        out.write_string("          local.get ")
        out.write_string(spilled_local.to_string())
        out.write_string("\n")
        out.write_string("          drop\n")
      } else {
        out.write_string("          drop\n")
      }
      out.write_string("          local.get 1\n")
      out.write_string("          drop\n")
      out.write_string("        end\n")
      if inner == 2 {
        out.write_string("      end\n")
      }
      inner = inner + 1
    }
    out.write_string("    end\n")
    group = group + 1
  }
  out.write_string("    local.get 1)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_small_loop_call_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 84 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  let mut loop_group = 0
  while loop_group < 2 {
    out.write_string("    loop\n")
    let mut inner = 0
    while inner < 7 {
      let i = loop_group * 7 + inner
      let a = 1 + i * 6
      let b = 2 + i * 6
      let c = 3 + i * 6
      let d = 4 + i * 6
      let e = 5 + i * 6
      let f = 6 + i * 6
      out.write_string("      local.get 0\n")
      out.write_string("      i32.const ")
      out.write_string(i.to_string())
      out.write_string("\n")
      out.write_string("      i32.eq\n")
      out.write_string("      if\n")
      out.write_string("        local.get 0\n")
      out.write_string("        call 0\n")
      out.write_string("        local.set ")
      out.write_string(a.to_string())
      out.write_string("\n")
      out.write_string("        local.get ")
      out.write_string(a.to_string())
      out.write_string("\n")
      out.write_string("        local.set ")
      out.write_string(b.to_string())
      out.write_string("\n")
      out.write_string("        local.get ")
      out.write_string(b.to_string())
      out.write_string("\n")
      out.write_string("        local.get 0\n")
      out.write_string("        call 1\n")
      out.write_string("        local.set ")
      out.write_string(c.to_string())
      out.write_string("\n")
      out.write_string("        local.get ")
      out.write_string(c.to_string())
      out.write_string("\n")
      out.write_string("        local.set ")
      out.write_string(d.to_string())
      out.write_string("\n")
      out.write_string("        local.get ")
      out.write_string(d.to_string())
      out.write_string("\n")
      out.write_string("        local.set ")
      out.write_string(e.to_string())
      out.write_string("\n")
      out.write_string("        local.get ")
      out.write_string(e.to_string())
      out.write_string("\n")
      out.write_string("        local.set ")
      out.write_string(f.to_string())
      out.write_string("\n")
      out.write_string("        local.get ")
      out.write_string(f.to_string())
      out.write_string("\n")
      out.write_string("        drop\n")
      out.write_string("      end\n")
      inner = inner + 1
    }
    out.write_string("    end\n")
    loop_group = loop_group + 1
  }
  out.write_string("    local.get 0)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_straight_line_builder_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 256 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < 41 {
    let touched_local = i * 4 + 4
    let merged_local = i * 4 + 5
    let copied_local = i * 4 + 6
    let spilled_local = i * 4 + 7
    out.write_string("    local.get 0\n")
    out.write_string("    call 0\n")
    out.write_string("    local.set ")
    out.write_string(touched_local.to_string())
    out.write_string("\n")
    out.write_string("    local.get ")
    out.write_string(touched_local.to_string())
    out.write_string("\n")
    out.write_string("    local.get 0\n")
    out.write_string("    call 1\n")
    out.write_string("    local.set ")
    out.write_string(merged_local.to_string())
    out.write_string("\n")
    out.write_string("    local.get ")
    out.write_string(merged_local.to_string())
    out.write_string("\n")
    out.write_string("    local.set ")
    out.write_string(copied_local.to_string())
    out.write_string("\n")
    out.write_string("    local.get ")
    out.write_string(copied_local.to_string())
    out.write_string("\n")
    out.write_string("    local.get ")
    out.write_string(touched_local.to_string())
    out.write_string("\n")
    out.write_string("    call 1\n")
    out.write_string("    local.set ")
    out.write_string(spilled_local.to_string())
    out.write_string("\n")
    out.write_string("    local.get ")
    out.write_string(spilled_local.to_string())
    out.write_string("\n")
    out.write_string("    drop\n")
    out.write_string("    local.get ")
    out.write_string(spilled_local.to_string())
    out.write_string("\n")
    out.write_string("    drop\n")
    out.write_string("    local.get ")
    out.write_string(copied_local.to_string())
    out.write_string("\n")
    out.write_string("    drop\n")
    out.write_string("    local.get ")
    out.write_string(touched_local.to_string())
    out.write_string("\n")
    out.write_string("    drop\n")
    i = i + 1
  }
  out.write_string("    local.get 0)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_huge_straight_line_call_builder_module() -> String {
  let out = StringBuilder::new()
  out.write_string(
    "(module\n  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 1024 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < 256 {
    let a = i * 4 + 1
    let b = a + 1
    let c = b + 1
    let d = c + 1
    out.write_string("    local.get 0\n")
    out.write_string("    call 0\n")
    out.write_string("    local.tee ")
    out.write_string(a.to_string())
    out.write_string("\n")
    out.write_string("    drop\n")
    out.write_string("    local.get ")
    out.write_string(a.to_string())
    out.write_string("\n")
    out.write_string("    call 0\n")
    out.write_string("    local.tee ")
    out.write_string(b.to_string())
    out.write_string("\n")
    out.write_string("    drop\n")
    out.write_string("    local.get ")
    out.write_string(b.to_string())
    out.write_string("\n")
    out.write_string("    call 0\n")
    out.write_string("    local.tee ")
    out.write_string(c.to_string())
    out.write_string("\n")
    out.write_string("    drop\n")
    out.write_string("    local.get ")
    out.write_string(c.to_string())
    out.write_string("\n")
    out.write_string("    call 0\n")
    out.write_string("    local.tee ")
    out.write_string(d.to_string())
    out.write_string("\n")
    out.write_string("    drop\n")
    out.write_string("    local.get ")
    out.write_string(d.to_string())
    out.write_string("\n")
    out.write_string("    drop\n")
    out.write_string("    local.get ")
    out.write_string(c.to_string())
    out.write_string("\n")
    out.write_string("    drop\n")
    out.write_string("    local.get ")
    out.write_string(b.to_string())
    out.write_string("\n")
    out.write_string("    drop\n")
    out.write_string("    local.get ")
    out.write_string(a.to_string())
    out.write_string("\n")
    out.write_string("    drop\n")
    i = i + 1
  }
  out.write_string("    local.get 0)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_lane_builder_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"array_length\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"check_range\" (func (param i32 i32 i32)))\n",
  )
  out.write_string("  (memory 1)\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 48 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  let mut lane_idx = 0
  while lane_idx < 16 {
    let tmp_local = lane_idx + 1
    let arr_local = 17 + lane_idx * 2
    let idx_local = arr_local + 1
    out.write_string("    local.get 0\n")
    out.write_string("    i32.const ")
    out.write_string(lane_idx.to_string())
    out.write_string("\n")
    out.write_string("    local.set ")
    out.write_string(idx_local.to_string())
    out.write_string("\n")
    out.write_string("    local.set ")
    out.write_string(arr_local.to_string())
    out.write_string("\n")
    out.write_string("    local.get ")
    out.write_string(idx_local.to_string())
    out.write_string("\n")
    out.write_string("    i32.const 0\n")
    out.write_string("    local.get ")
    out.write_string(arr_local.to_string())
    out.write_string("\n")
    out.write_string("    call 0\n")
    out.write_string("    i32.const 1\n")
    out.write_string("    i32.sub\n")
    out.write_string("    call 1\n")
    out.write_string("    local.get ")
    out.write_string(arr_local.to_string())
    out.write_string("\n")
    out.write_string("    local.get ")
    out.write_string(idx_local.to_string())
    out.write_string("\n")
    out.write_string("    i32.add\n")
    out.write_string("    i32.load8_u offset=8\n")
    out.write_string("    local.set ")
    out.write_string(tmp_local.to_string())
    out.write_string("\n")
    lane_idx = lane_idx + 1
  }
  out.write_string("    local.get 1\n")
  let mut tmp_local = 2
  while tmp_local <= 16 {
    out.write_string("    local.get ")
    out.write_string(tmp_local.to_string())
    out.write_string("\n")
    out.write_string("    i32.add\n")
    tmp_local = tmp_local + 1
  }
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_decode_structured_call_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 96 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    block (result i32)\n")
  out.write_string("      loop\n")
  let mut i = 0
  while i < 14 {
    let touched_local = i * 6 + 4
    let echoed_local = i * 6 + 5
    let copied_local = i * 6 + 6
    let merged_local = i * 6 + 7
    let spilled_local = i * 6 + 8
    let out_local = i * 6 + 9
    out.write_string("        block\n")
    out.write_string("          local.get 0\n")
    out.write_string("          i32.const ")
    out.write_string(i.to_string())
    out.write_string("\n")
    out.write_string("          i32.eq\n")
    out.write_string("          if\n")
    out.write_string("            local.get 0\n")
    out.write_string("            call 0\n")
    out.write_string("            local.set ")
    out.write_string(touched_local.to_string())
    out.write_string("\n")
    out.write_string("            local.get ")
    out.write_string(touched_local.to_string())
    out.write_string("\n")
    out.write_string("            call 0\n")
    out.write_string("            local.set ")
    out.write_string(echoed_local.to_string())
    out.write_string("\n")
    out.write_string("            local.get ")
    out.write_string(echoed_local.to_string())
    out.write_string("\n")
    out.write_string("            local.set ")
    out.write_string(copied_local.to_string())
    out.write_string("\n")
    out.write_string("            local.get ")
    out.write_string(copied_local.to_string())
    out.write_string("\n")
    out.write_string("            local.get 1\n")
    out.write_string("            call 1\n")
    out.write_string("            local.set ")
    out.write_string(merged_local.to_string())
    out.write_string("\n")
    out.write_string("            local.get ")
    out.write_string(merged_local.to_string())
    out.write_string("\n")
    out.write_string("            local.get ")
    out.write_string(touched_local.to_string())
    out.write_string("\n")
    out.write_string("            call 1\n")
    out.write_string("            local.set ")
    out.write_string(spilled_local.to_string())
    out.write_string("\n")
    out.write_string("            local.get ")
    out.write_string(spilled_local.to_string())
    out.write_string("\n")
    out.write_string("            local.set ")
    out.write_string(out_local.to_string())
    out.write_string("\n")
    out.write_string("            local.get ")
    out.write_string(copied_local.to_string())
    out.write_string("\n")
    out.write_string("            drop\n")
    out.write_string("            local.get ")
    out.write_string(out_local.to_string())
    out.write_string("\n")
    out.write_string("            return\n")
    out.write_string("          end\n")
    out.write_string("        end\n")
    i = i + 1
  }
  out.write_string("      end\n")
  out.write_string("      local.get 1\n")
  out.write_string("      br 0\n")
  out.write_string("    end)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_branchy_decode_fanout_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 208 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  let mut group = 0
  while group < 12 {
    out.write_string("    block\n")
    out.write_string("      block\n")
    let mut inner = 0
    while inner < 5 {
      let i = group * 5 + inner
      let touched_local = i * 2 + 4
      let merged_local = i * 2 + 5
      out.write_string("        local.get 0\n")
      out.write_string("        i32.const ")
      out.write_string(i.to_string())
      out.write_string("\n")
      out.write_string("        i32.eq\n")
      out.write_string("        if\n")
      out.write_string("          local.get 0\n")
      out.write_string("          call 0\n")
      out.write_string("          local.tee ")
      out.write_string(touched_local.to_string())
      out.write_string("\n")
      out.write_string("          drop\n")
      out.write_string("          local.get ")
      out.write_string(touched_local.to_string())
      out.write_string("\n")
      out.write_string("          local.get 1\n")
      out.write_string("          call 1\n")
      out.write_string("          local.set ")
      out.write_string(merged_local.to_string())
      out.write_string("\n")
      out.write_string("          local.get ")
      out.write_string(merged_local.to_string())
      out.write_string("\n")
      if i < 8 {
        out.write_string("          return\n")
      } else {
        out.write_string("          drop\n")
      }
      out.write_string("        end\n")
      inner = inner + 1
    }
    out.write_string("      end\n")
    out.write_string("    end\n")
    group = group + 1
  }
  out.write_string("    local.get 1)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_stringview_trim_loop_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 40 {
    out.write_string(" i32")
    local_idx += 1
  }
  out.write_string(")\n")
  out.write_string("    loop\n")
  let mut arm = 0
  while arm < 3 {
    let base = arm * 8 + 2
    let a = base
    let b = base + 1
    let c = base + 2
    let d = base + 3
    let e = base + 4
    let f = base + 5
    out.write_string("      local.get 0\n")
    out.write_string("      i32.const ")
    out.write_string(arm.to_string())
    out.write_string("\n")
    out.write_string("      i32.eq\n")
    out.write_string("      if\n")
    out.write_string("        local.get 0\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(a.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(b.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(a.to_string())
    out.write_string("\n")
    out.write_string("        local.tee ")
    out.write_string(c.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(d.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(c.to_string())
    out.write_string("\n")
    out.write_string("        local.get 1\n")
    out.write_string("        call 1\n")
    out.write_string("        local.set ")
    out.write_string(e.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(e.to_string())
    out.write_string("\n")
    out.write_string("        call 0\n")
    out.write_string("        drop\n")
    out.write_string("        local.get ")
    out.write_string(b.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(d.to_string())
    out.write_string("\n")
    out.write_string("        call 1\n")
    out.write_string("        local.set ")
    out.write_string(f.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(e.to_string())
    out.write_string("\n")
    out.write_string("        drop\n")
    out.write_string("        local.get ")
    out.write_string(f.to_string())
    out.write_string("\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    arm += 1
  }
  out.write_string("    end\n")
  out.write_string("    local.get 2\n")
  out.write_string("    drop\n")
  out.write_string("    local.get 10\n")
  out.write_string("    drop\n")
  out.write_string("    local.get 18\n")
  out.write_string("    drop\n")
  out.write_string("    local.get 1)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_transformer_catch_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 200 {
    out.write_string(" i32")
    local_idx += 1
  }
  out.write_string(")\n")
  let mut group = 0
  while group < 12 {
    out.write_string("    block\n")
    let mut inner = 0
    while inner < 3 {
      if inner < 2 {
        out.write_string("      block\n")
      }
      let arm = group * 3 + inner
      let touched_local = 2 + arm * 2
      let merged_local = touched_local + 1
      let spilled_local = 90 + arm % 8
      out.write_string("        local.get 0\n")
      out.write_string("        i32.const ")
      out.write_string(arm.to_string())
      out.write_string("\n")
      out.write_string("        i32.eq\n")
      out.write_string("        if\n")
      out.write_string("          local.get 0\n")
      out.write_string("          call 0\n")
      out.write_string("          local.set ")
      out.write_string(touched_local.to_string())
      out.write_string("\n")
      out.write_string("          local.get 1\n")
      out.write_string("          local.get ")
      out.write_string(touched_local.to_string())
      out.write_string("\n")
      out.write_string("          call 1\n")
      out.write_string("          local.set ")
      out.write_string(merged_local.to_string())
      out.write_string("\n")
      out.write_string("          local.get ")
      out.write_string(merged_local.to_string())
      out.write_string("\n")
      out.write_string("          call 0\n")
      out.write_string("          drop\n")
      out.write_string("          local.get ")
      out.write_string(touched_local.to_string())
      out.write_string("\n")
      out.write_string("          local.get ")
      out.write_string(merged_local.to_string())
      out.write_string("\n")
      out.write_string("          drop\n")
      out.write_string("          drop\n")
      if arm < 8 {
        out.write_string("          local.get ")
        out.write_string(merged_local.to_string())
        out.write_string("\n")
        out.write_string("          local.set ")
        out.write_string(spilled_local.to_string())
        out.write_string("\n")
      }
      if arm < 12 {
        out.write_string("          i32.const ")
        out.write_string((arm + 1).to_string())
        out.write_string("\n")
        out.write_string("          return\n")
      } else {
        out.write_string("          i32.const 0\n")
        out.write_string("          drop\n")
      }
      out.write_string("        end\n")
      if inner < 2 {
        out.write_string("      end\n")
      }
      inner += 1
    }
    out.write_string("    end\n")
    group += 1
  }
  out.write_string("    local.get 1)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_dense_structured_call_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"sink3\" (func (param i32 i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 416 {
    out.write_string(" i32")
    local_idx += 1
  }
  out.write_string(")\n")
  out.write_string("    loop\n")
  let mut group = 0
  while group < 18 {
    out.write_string("      block\n")
    out.write_string("        block\n")
    let mut inner = 0
    while inner < 3 {
      let arm = group * 3 + inner
      let touched_local = arm * 5 + 4
      let echoed_local = touched_local + 1
      let merged_local = touched_local + 2
      let spilled_local = touched_local + 3
      let sink_local = touched_local + 4
      out.write_string("          local.get 0\n")
      out.write_string("          i32.const ")
      out.write_string(arm.to_string())
      out.write_string("\n")
      out.write_string("          i32.eq\n")
      out.write_string("          if\n")
      out.write_string("            local.get 0\n")
      out.write_string("            call 0\n")
      out.write_string("            local.set ")
      out.write_string(touched_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get ")
      out.write_string(touched_local.to_string())
      out.write_string("\n")
      out.write_string("            call 0\n")
      out.write_string("            local.set ")
      out.write_string(echoed_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get ")
      out.write_string(echoed_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get 1\n")
      out.write_string("            call 1\n")
      out.write_string("            local.set ")
      out.write_string(merged_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get ")
      out.write_string(touched_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get ")
      out.write_string(merged_local.to_string())
      out.write_string("\n")
      out.write_string("            call 1\n")
      out.write_string("            local.set ")
      out.write_string(spilled_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get ")
      out.write_string(spilled_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get 1\n")
      out.write_string("            local.get 0\n")
      out.write_string("            call 2\n")
      out.write_string("            local.set ")
      out.write_string(sink_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get ")
      out.write_string(sink_local.to_string())
      out.write_string("\n")
      out.write_string("            drop\n")
      out.write_string("            local.get ")
      out.write_string(spilled_local.to_string())
      out.write_string("\n")
      out.write_string("            drop\n")
      out.write_string("          end\n")
      inner += 1
    }
    out.write_string("        end\n")
    out.write_string("      end\n")
    group += 1
  }
  out.write_string("    end\n")
  out.write_string("    local.get 1)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_loop_heavy_validator_call_module(
  repetitions : Int,
  base_locals : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"sink3\" (func (param i32 i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions * 4 + base_locals {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < repetitions {
    let touched_local = i * 4 + 4
    let merged_local = i * 4 + 5
    let spilled_local = i * 4 + 6
    out.write_string("    block\n")
    out.write_string("      loop\n")
    out.write_string("        local.get 0\n")
    out.write_string("        i32.const ")
    out.write_string(i.to_string())
    out.write_string("\n")
    out.write_string("        i32.eq\n")
    out.write_string("        if\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call 0\n")
    out.write_string("          local.set ")
    out.write_string(touched_local.to_string())
    out.write_string("\n")
    out.write_string("          local.get 1\n")
    out.write_string("          local.get ")
    out.write_string(touched_local.to_string())
    out.write_string("\n")
    out.write_string("          call 1\n")
    out.write_string("          local.set ")
    out.write_string(merged_local.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(merged_local.to_string())
    out.write_string("\n")
    out.write_string("          local.get 1\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call 2\n")
    out.write_string("          local.set ")
    out.write_string(spilled_local.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(spilled_local.to_string())
    out.write_string("\n")
    out.write_string("          return\n")
    out.write_string("        end\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 1)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_parserish_call_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"sink3\" (func (param i32 i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 308 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    loop\n")
  let mut group = 0
  while group < 6 {
    out.write_string("      block\n")
    let mut inner = 0
    while inner < 4 {
      let i = group * 4 + inner
      let touched_local = i * 4 + 4
      let copied_local = i * 4 + 5
      let merged_local = i * 4 + 6
      let spilled_local = i * 4 + 7
      out.write_string("        local.get 0\n")
      out.write_string("        i32.const ")
      out.write_string(i.to_string())
      out.write_string("\n")
      out.write_string("        i32.eq\n")
      out.write_string("        if\n")
      out.write_string("          local.get 0\n")
      out.write_string("          call 0\n")
      out.write_string("          local.set ")
      out.write_string(touched_local.to_string())
      out.write_string("\n")
      out.write_string("          local.get ")
      out.write_string(touched_local.to_string())
      out.write_string("\n")
      out.write_string("          local.set ")
      out.write_string(copied_local.to_string())
      out.write_string("\n")
      out.write_string("          local.get 1\n")
      out.write_string("          local.get ")
      out.write_string(copied_local.to_string())
      out.write_string("\n")
      out.write_string("          call 1\n")
      out.write_string("          local.set ")
      out.write_string(merged_local.to_string())
      out.write_string("\n")
      out.write_string("          local.get ")
      out.write_string(merged_local.to_string())
      out.write_string("\n")
      out.write_string("          local.set ")
      out.write_string(spilled_local.to_string())
      out.write_string("\n")
      out.write_string("          local.get ")
      out.write_string(spilled_local.to_string())
      out.write_string("\n")
      out.write_string("          local.get 1\n")
      out.write_string("          local.get 0\n")
      out.write_string("          call 2\n")
      out.write_string("          local.set ")
      out.write_string(spilled_local.to_string())
      out.write_string("\n")
      out.write_string("          local.get ")
      out.write_string(spilled_local.to_string())
      out.write_string("\n")
      out.write_string("          i32.const 1\n")
      out.write_string("          i32.add\n")
      out.write_string("          local.set ")
      out.write_string(copied_local.to_string())
      out.write_string("\n")
      out.write_string("          local.get ")
      out.write_string(copied_local.to_string())
      out.write_string("\n")
      out.write_string("          i32.const 1\n")
      out.write_string("          i32.sub\n")
      out.write_string("          return\n")
      out.write_string("        end\n")
      inner = inner + 1
    }
    out.write_string("      end\n")
    group = group + 1
  }
  out.write_string("    end\n")
  out.write_string("    local.get 1)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_parserish_two_loop_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"sink3\" (func (param i32 i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 344 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    loop\n")
  out.write_string("      loop\n")
  let mut group = 0
  while group < 7 {
    out.write_string("        block\n")
    let mut inner = 0
    while inner < 4 {
      let i = group * 4 + inner
      let touched_local = i * 4 + 4
      let copied_local = i * 4 + 5
      let merged_local = i * 4 + 6
      let spilled_local = i * 4 + 7
      out.write_string("          local.get 0\n")
      out.write_string("          i32.const ")
      out.write_string(i.to_string())
      out.write_string("\n")
      out.write_string("          i32.eq\n")
      out.write_string("          if\n")
      out.write_string("            local.get 0\n")
      out.write_string("            call 0\n")
      out.write_string("            local.set ")
      out.write_string(touched_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get ")
      out.write_string(touched_local.to_string())
      out.write_string("\n")
      out.write_string("            local.set ")
      out.write_string(copied_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get 1\n")
      out.write_string("            local.get ")
      out.write_string(copied_local.to_string())
      out.write_string("\n")
      out.write_string("            call 1\n")
      out.write_string("            local.set ")
      out.write_string(merged_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get ")
      out.write_string(merged_local.to_string())
      out.write_string("\n")
      out.write_string("            local.set ")
      out.write_string(spilled_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get ")
      out.write_string(spilled_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get 1\n")
      out.write_string("            local.get 0\n")
      out.write_string("            call 2\n")
      out.write_string("            local.set ")
      out.write_string(spilled_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get ")
      out.write_string(spilled_local.to_string())
      out.write_string("\n")
      out.write_string("            i32.const 1\n")
      out.write_string("            i32.add\n")
      out.write_string("            local.set ")
      out.write_string(copied_local.to_string())
      out.write_string("\n")
      out.write_string("            local.get ")
      out.write_string(copied_local.to_string())
      out.write_string("\n")
      out.write_string("            i32.const 1\n")
      out.write_string("            i32.sub\n")
      out.write_string("            return\n")
      out.write_string("          end\n")
      inner = inner + 1
    }
    out.write_string("        end\n")
    group = group + 1
  }
  out.write_string("      end\n")
  out.write_string("    end\n")
  out.write_string("    local.get 1)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_giant_structured_local_churn_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions * 7 + 640 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    local.get 0\n")
  out.write_string("    call 0\n")
  out.write_string("    local.set 600\n")
  let mut i = 0
  while i < repetitions {
    let start_local = i * 7 + 8
    let end_local = i * 7 + 9
    let span_local = i * 7 + 10
    let tee_local = i * 7 + 11
    let merge_local = i * 7 + 12
    let spill_local = i * 7 + 13
    let call_local = i * 7 + 14
    out.write_string("    block\n")
    out.write_string("      local.get 1\n")
    out.write_string("      local.set ")
    out.write_string(start_local.to_string())
    out.write_string("\n")
    out.write_string("      local.get 0\n")
    out.write_string("      local.set ")
    out.write_string(end_local.to_string())
    out.write_string("\n")
    out.write_string("      local.get ")
    out.write_string(end_local.to_string())
    out.write_string("\n")
    out.write_string("      local.get ")
    out.write_string(start_local.to_string())
    out.write_string("\n")
    out.write_string("      i32.sub\n")
    out.write_string("      local.tee ")
    out.write_string(span_local.to_string())
    out.write_string("\n")
    out.write_string("      i32.const ")
    out.write_string((i % 11).to_string())
    out.write_string("\n")
    out.write_string("      i32.ge_s\n")
    out.write_string("      if\n")
    out.write_string("        local.get ")
    out.write_string(end_local.to_string())
    out.write_string("\n")
    out.write_string("        local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(merge_local.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(merge_local.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(span_local.to_string())
    out.write_string("\n")
    out.write_string("        i32.add\n")
    out.write_string("        local.set ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    out.write_string("        drop\n")
    if i % 3 == 0 {
      out.write_string("        local.get 0\n")
      out.write_string("        call 0\n")
      out.write_string("        local.set ")
      out.write_string(call_local.to_string())
      out.write_string("\n")
      out.write_string("        local.get ")
      out.write_string(call_local.to_string())
      out.write_string("\n")
      out.write_string("        drop\n")
    }
    out.write_string("      else\n")
    out.write_string("        br 0\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 600)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_low_local_decision_ladder_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i64)))\n",
  )
  out.write_string("  (func (param i32) (result i64)\n")
  out.write_string("    (local i32)\n")
  out.write_string("    local.get 0\n")
  out.write_string("    local.tee 1\n")
  let mut i = 0
  while i < repetitions {
    out.write_string("    i32.const ")
    out.write_string((i % 97).to_string())
    out.write_string("\n")
    out.write_string("    i32.eq\n")
    out.write_string("    if (result i64)\n")
    out.write_string("      local.get 1\n")
    out.write_string("      call 0\n")
    out.write_string("    else\n")
    out.write_string("      local.get 1\n")
    i = i + 1
  }
  out.write_string("    call 0\n")
  let mut close_idx = 0
  while close_idx < repetitions {
    out.write_string("    end\n")
    close_idx = close_idx + 1
  }
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_branch_dense_structured_call_heavy_module(
  repetitions : Int,
  extra_locals : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < extra_locals {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    local.get 0\n")
  out.write_string("    local.set 1\n")
  out.write_string("    local.get 0\n")
  out.write_string("    local.set 2\n")
  out.write_string("    local.get 0\n")
  out.write_string("    call 0\n")
  out.write_string("    local.set 3\n")
  let mut i = 0
  while i < repetitions {
    let then_local = if i % 3 == 0 { 1 } else if i % 3 == 1 { 2 } else { 3 }
    let else_local = if i % 2 == 0 { 2 } else { 3 }
    out.write_string("    local.get 1\n")
    out.write_string("    i32.const ")
    out.write_string((i % 113).to_string())
    out.write_string("\n")
    out.write_string("    i32.eq\n")
    out.write_string("    if (result i32)\n")
    out.write_string("      local.get ")
    out.write_string(then_local.to_string())
    out.write_string("\n")
    out.write_string("      call 0\n")
    out.write_string("    else\n")
    out.write_string("      local.get ")
    out.write_string(else_local.to_string())
    out.write_string("\n")
    out.write_string("      call 0\n")
    out.write_string("    end\n")
    out.write_string("    drop\n")
    i = i + 1
  }
  out.write_string("    local.get 3\n")
  out.write_string("    call 0\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_block_rich_structured_call_heavy_module(
  repetitions : Int,
  extra_locals : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < extra_locals {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    local.get 0\n")
  out.write_string("    local.set 1\n")
  out.write_string("    local.get 0\n")
  out.write_string("    call 0\n")
  out.write_string("    local.set 2\n")
  out.write_string("    local.get 0\n")
  out.write_string("    call 0\n")
  out.write_string("    local.set 3\n")
  let mut i = 0
  while i < repetitions {
    let then_local = if i % 3 == 0 { 2 } else if i % 3 == 1 { 3 } else { 1 }
    let else_local = if i % 2 == 0 { 3 } else { 2 }
    out.write_string("    block\n")
    out.write_string("      local.get 1\n")
    out.write_string("      i32.const ")
    out.write_string((i % 127).to_string())
    out.write_string("\n")
    out.write_string("      i32.eq\n")
    out.write_string("      if\n")
    out.write_string("        local.get ")
    out.write_string(then_local.to_string())
    out.write_string("\n")
    out.write_string("        call 0\n")
    out.write_string("        local.set 4\n")
    out.write_string("        local.get 4\n")
    out.write_string("        call 0\n")
    out.write_string("        drop\n")
    out.write_string("      else\n")
    out.write_string("        local.get ")
    out.write_string(else_local.to_string())
    out.write_string("\n")
    out.write_string("        call 0\n")
    out.write_string("        local.set 5\n")
    out.write_string("        local.get 5\n")
    out.write_string("        call 0\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 2\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_simplify_locals_call_dense_structured_walker_module(
  repetitions : Int,
  extra_locals : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < extra_locals {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    local.get 0\n")
  out.write_string("    local.set 2\n")
  out.write_string("    local.get 1\n")
  out.write_string("    local.set 3\n")
  out.write_string("    local.get 0\n")
  out.write_string("    call 0\n")
  out.write_string("    local.set 4\n")
  out.write_string("    loop\n")
  let mut i = 0
  while i < repetitions {
    out.write_string("      local.get 2\n")
    out.write_string("      i32.const ")
    out.write_string((i % 191).to_string())
    out.write_string("\n")
    out.write_string("      i32.eq\n")
    out.write_string("      if\n")
    out.write_string("        local.get 4\n")
    out.write_string("        call 0\n")
    out.write_string("        drop\n")
    out.write_string("        local.get 3\n")
    out.write_string("        local.get 4\n")
    out.write_string("        call 1\n")
    out.write_string("        drop\n")
    out.write_string("        local.get 4\n")
    out.write_string("        call 0\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    i = i + 1
  }
  out.write_string("    end\n")
  out.write_string("    local.get 4\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_structured_return_ladder_with_condition_child_if_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 56 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    local.set 0\n")
  out.write_string("    block (result i32)\n")
  out.write_string("      loop\n")
  let mut i = 0
  while i < repetitions {
    let read_local = i % 8
    let tee_local = i + 8
    let set_local = i + 20
    let spill_local = i + 32
    out.write_string("        local.get 0\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(read_local.to_string())
    out.write_string("\n")
    out.write_string("        if\n")
    out.write_string("          local.get ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("          call 0\n")
    out.write_string("          local.tee ")
    out.write_string((tee_local + 1).to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    if i < 3 {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          return\n")
    } else {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          drop\n")
    }
    out.write_string("        end\n")
    i = i + 1
  }
  out.write_string("        local.get 0\n")
  out.write_string("        if (result i32)\n")
  out.write_string("          i32.const 1\n")
  out.write_string("        else\n")
  out.write_string("          i32.const 0\n")
  out.write_string("        end\n")
  out.write_string("        if\n")
  out.write_string("          local.get 1\n")
  out.write_string("          call 0\n")
  out.write_string("          drop\n")
  out.write_string("        end\n")
  out.write_string("        local.get 0\n")
  out.write_string("        br_if 0\n")
  out.write_string("        local.get 1\n")
  out.write_string("        call 0\n")
  out.write_string("        local.tee 48\n")
  out.write_string("        local.set 49\n")
  out.write_string("        local.get 48\n")
  out.write_string("        local.get 1\n")
  out.write_string("        local.get 0\n")
  out.write_string("        select\n")
  out.write_string("        br 1\n")
  out.write_string("      end\n")
  out.write_string("      i32.const 0\n")
  out.write_string("    end)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_structured_return_ladder_with_guard_carrier_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 56 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    local.set 0\n")
  out.write_string("    block (result i32)\n")
  out.write_string("      loop\n")
  let mut i = 0
  while i < repetitions {
    let read_local = i % 8
    let tee_local = i + 8
    let set_local = i + 20
    let spill_local = i + 32
    out.write_string("        local.get 0\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(read_local.to_string())
    out.write_string("\n")
    out.write_string("        if\n")
    out.write_string("          local.get ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("          call 0\n")
    out.write_string("          local.tee ")
    out.write_string((tee_local + 1).to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    if i < 3 {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          return\n")
    } else {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          drop\n")
    }
    out.write_string("        end\n")
    i = i + 1
  }
  out.write_string("        block (result i32)\n")
  out.write_string("          block\n")
  out.write_string("            local.get 0\n")
  out.write_string("            if (result i32)\n")
  out.write_string("              i32.const 1\n")
  out.write_string("            else\n")
  out.write_string("              local.get 1\n")
  out.write_string("              call 0\n")
  out.write_string("              local.tee 48\n")
  out.write_string("              local.set 49\n")
  out.write_string("              local.get 48\n")
  out.write_string("            end\n")
  out.write_string("            br_if 0\n")
  out.write_string("            local.get 1\n")
  out.write_string("            call 0\n")
  out.write_string("            local.tee 50\n")
  out.write_string("            local.set 51\n")
  out.write_string("            local.get 50\n")
  out.write_string("            drop\n")
  out.write_string("          end\n")
  out.write_string("          local.get 1\n")
  out.write_string("          call 0\n")
  out.write_string("          local.tee 52\n")
  out.write_string("          br 0\n")
  out.write_string("        end\n")
  out.write_string("        local.set 53\n")
  out.write_string("        local.get 53\n")
  out.write_string("        local.get 1\n")
  out.write_string("        local.get 0\n")
  out.write_string("        select\n")
  out.write_string("        br 1\n")
  out.write_string("      end\n")
  out.write_string("      i32.const 0\n")
  out.write_string("    end)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_structured_return_ladder_with_false_prefix_guard_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 56 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    local.set 0\n")
  out.write_string("    block (result i32)\n")
  out.write_string("      loop\n")
  let mut i = 0
  while i < repetitions {
    let read_local = i % 8
    let tee_local = i + 8
    let set_local = i + 20
    let spill_local = i + 32
    out.write_string("        local.get 0\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(read_local.to_string())
    out.write_string("\n")
    out.write_string("        if\n")
    out.write_string("          local.get ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("          call 0\n")
    out.write_string("          local.tee ")
    out.write_string((tee_local + 1).to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    if i < 3 {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          return\n")
    } else {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          drop\n")
    }
    out.write_string("        end\n")
    i = i + 1
  }
  out.write_string("        block (result i32)\n")
  out.write_string("          block\n")
  out.write_string("            local.get 1\n")
  out.write_string("            drop\n")
  out.write_string("            local.get 0\n")
  out.write_string("            if (result i32)\n")
  out.write_string("              i32.const 1\n")
  out.write_string("            else\n")
  out.write_string("              local.get 1\n")
  out.write_string("              call 0\n")
  out.write_string("              local.tee 48\n")
  out.write_string("              local.set 49\n")
  out.write_string("              local.get 48\n")
  out.write_string("            end\n")
  out.write_string("            br_if 0\n")
  out.write_string("            local.get 1\n")
  out.write_string("            call 0\n")
  out.write_string("            local.tee 50\n")
  out.write_string("            local.set 51\n")
  out.write_string("            local.get 50\n")
  out.write_string("            drop\n")
  out.write_string("          end\n")
  out.write_string("          local.get 1\n")
  out.write_string("          call 0\n")
  out.write_string("          local.tee 52\n")
  out.write_string("          br 0\n")
  out.write_string("        end\n")
  out.write_string("        local.set 53\n")
  out.write_string("        local.get 53\n")
  out.write_string("        local.get 1\n")
  out.write_string("        local.get 0\n")
  out.write_string("        select\n")
  out.write_string("        br 1\n")
  out.write_string("      end\n")
  out.write_string("      i32.const 0\n")
  out.write_string("    end)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_unique_loop_select_return_ladder_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 56 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    local.set 0\n")
  out.write_string("    block (result i32)\n")
  out.write_string("      loop\n")
  let mut i = 0
  while i < 4 {
    let tee_local = i + 8
    let set_local = i + 20
    let spill_local = i + 32
    out.write_string("        local.get 0\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        if\n")
    out.write_string("          local.get ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("          call 0\n")
    out.write_string("          local.tee ")
    out.write_string((tee_local + 1).to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    if i < 3 {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          return\n")
    } else {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          drop\n")
    }
    out.write_string("        end\n")
    i = i + 1
  }
  let mut j = 0
  while j < 28 {
    let tee_local = j % 6 + 40
    let set_local = j % 6 + 46
    out.write_string("        local.get 1\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    j = j + 1
  }
  out.write_string("        local.get 0\n")
  out.write_string("        br_if 0\n")
  out.write_string("        local.get 1\n")
  out.write_string("        call 0\n")
  out.write_string("        local.tee 52\n")
  out.write_string("        local.set 53\n")
  out.write_string("        local.get 52\n")
  out.write_string("        local.get 1\n")
  out.write_string("        local.get 0\n")
  out.write_string("        select\n")
  out.write_string("        br 1\n")
  out.write_string("      end\n")
  out.write_string("      i32.const 0\n")
  out.write_string("    end)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_mid_unique_loop_select_return_ladder_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 56 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    local.set 0\n")
  out.write_string("    block (result i32)\n")
  out.write_string("      loop\n")
  let mut i = 0
  while i < 4 {
    let tee_local = i + 8
    let set_local = i + 20
    let spill_local = i + 32
    out.write_string("        local.get 0\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        if\n")
    out.write_string("          local.get ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("          call 0\n")
    out.write_string("          local.tee ")
    out.write_string((tee_local + 1).to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    if i < 3 {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          return\n")
    } else {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          drop\n")
    }
    out.write_string("        end\n")
    i = i + 1
  }
  let mut j = 0
  while j < 7 {
    let tee_local = j % 6 + 40
    let set_local = j % 6 + 46
    out.write_string("        local.get 1\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    j = j + 1
  }
  let mut k = 0
  while k < 21 {
    let set_local = k % 6 + 46
    out.write_string("        local.get 1\n")
    out.write_string("        call 0\n")
    out.write_string("        local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    k = k + 1
  }
  out.write_string("        local.get 0\n")
  out.write_string("        br_if 0\n")
  out.write_string("        local.get 1\n")
  out.write_string("        call 0\n")
  out.write_string("        local.tee 52\n")
  out.write_string("        local.set 53\n")
  out.write_string("        local.get 52\n")
  out.write_string("        local.get 1\n")
  out.write_string("        local.get 0\n")
  out.write_string("        select\n")
  out.write_string("        br 1\n")
  out.write_string("      end\n")
  out.write_string("      i32.const 0\n")
  out.write_string("    end)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_large_result_br_table_dispatch_ladder_module(
  depth : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    block $exit (result i32)\n")
  let mut level = depth - 1
  while level >= 0 {
    out.write_string("      block $b")
    out.write_string(level.to_string())
    out.write_string("\n")
    level = level - 1
  }
  out.write_string("        local.get 0\n")
  out.write_string("        br_table")
  for level = 0; level < depth; level = level + 1 {
    out.write_string(" $b")
    out.write_string(level.to_string())
  }
  out.write_string(" $b")
  out.write_string((depth - 1).to_string())
  out.write_string("\n")
  for case_idx = 0; case_idx < depth; case_idx = case_idx + 1 {
    out.write_string("      end\n")
    out.write_string("      i32.const 1\n")
    out.write_string("      i32.const 0\n")
    out.write_string("      local.get 1\n")
    out.write_string("      i32.const ")
    out.write_string(case_idx.to_string())
    out.write_string("\n")
    out.write_string("      i32.eq\n")
    out.write_string("      select\n")
    if case_idx + 1 < depth {
      out.write_string("      br $exit\n")
    }
  }
  out.write_string("    end\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_large_br_table_return_ladder_hot_skip_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 160 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    local.set 0\n")
  let mut i = 0
  while i < repetitions {
    let tee_local = 8 + i % 40
    let set_local = 56 + i % 40
    let spill_local = 104 + i % 40
    out.write_string("    local.get 0\n")
    out.write_string("    call 0\n")
    out.write_string("    local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("    local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("    block\n")
    out.write_string("      local.get ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("      call 0\n")
    out.write_string("      if\n")
    out.write_string("        local.get ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        call 0\n")
    out.write_string("        local.set ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    out.write_string("        call 0\n")
    out.write_string("        drop\n")
    out.write_string("        local.get 0\n")
    out.write_string("        if\n")
    out.write_string("          local.get ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    out.write_string("          return\n")
    out.write_string("        end\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    block $exit (result i32)\n")
  let mut depth = 5
  while depth >= 0 {
    out.write_string("      block $b")
    out.write_string(depth.to_string())
    out.write_string(" (result i32)\n")
    depth = depth - 1
  }
  out.write_string("        i32.const 0\n")
  out.write_string("        local.get 1\n")
  out.write_string("        br_table")
  for case_idx = 0; case_idx < 6; case_idx = case_idx + 1 {
    out.write_string(" $b")
    out.write_string(case_idx.to_string())
  }
  out.write_string(" $b5\n")
  for case_idx = 0; case_idx < 6; case_idx = case_idx + 1 {
    out.write_string("      end\n")
    out.write_string("      local.get ")
    out.write_string((8 + case_idx).to_string())
    out.write_string("\n")
    out.write_string("      local.get 1\n")
    out.write_string("      i32.const ")
    out.write_string(case_idx.to_string())
    out.write_string("\n")
    out.write_string("      i32.eq\n")
    out.write_string("      select\n")
    if case_idx + 1 < 6 {
      out.write_string("      br $exit\n")
    }
  }
  out.write_string("    end)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_large_typed_br_table_encoder_ladder_module(
  depth : Int,
  tails_per_case : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  for local_idx = 0; local_idx < 1800; local_idx = local_idx + 1 {
    out.write_string(" i32")
  }
  out.write_string(")\n")
  out.write_string("    block $exit (result i32)\n")
  let mut level = depth - 1
  while level >= 0 {
    out.write_string("      block $b")
    out.write_string(level.to_string())
    out.write_string(" (result i32)\n")
    level = level - 1
  }
  out.write_string("        i32.const 0\n")
  out.write_string("        local.get 1\n")
  out.write_string("        br_table")
  for case_idx = 0; case_idx < depth; case_idx = case_idx + 1 {
    out.write_string(" $b")
    out.write_string(case_idx.to_string())
  }
  out.write_string(" $b")
  out.write_string((depth - 1).to_string())
  out.write_string("\n")
  for case_idx = 0; case_idx < depth; case_idx = case_idx + 1 {
    out.write_string("      end\n")
    for tail_idx = 0; tail_idx < tails_per_case; tail_idx = tail_idx + 1 {
      let local_base = 2 + (case_idx * tails_per_case + tail_idx) * 6
      let tee_a = local_base
      let set_a = local_base + 1
      let tee_b = local_base + 2
      let set_b = local_base + 3
      let spill = local_base + 4
      out.write_string("      drop\n")
      out.write_string("        block (result i32)\n")
      out.write_string("          block\n")
      out.write_string("            local.get 0\n")
      out.write_string("            call 0\n")
      out.write_string("            local.tee ")
      out.write_string(tee_a.to_string())
      out.write_string("\n")
      out.write_string("            local.set ")
      out.write_string(set_a.to_string())
      out.write_string("\n")
      out.write_string("            local.get ")
      out.write_string(set_a.to_string())
      out.write_string("\n")
      out.write_string("            call 0\n")
      out.write_string("            i32.eqz\n")
      out.write_string("            if\n")
      out.write_string("              local.get ")
      out.write_string(tee_a.to_string())
      out.write_string("\n")
      out.write_string("              br 1\n")
      out.write_string("            end\n")
      out.write_string("            local.get 1\n")
      out.write_string("            call 0\n")
      out.write_string("            local.tee ")
      out.write_string(tee_b.to_string())
      out.write_string("\n")
      out.write_string("            local.set ")
      out.write_string(set_b.to_string())
      out.write_string("\n")
      out.write_string("            local.get ")
      out.write_string(set_b.to_string())
      out.write_string("\n")
      out.write_string("            call 0\n")
      out.write_string("            local.set ")
      out.write_string(spill.to_string())
      out.write_string("\n")
      out.write_string("            local.get ")
      out.write_string(spill.to_string())
      out.write_string("\n")
      out.write_string("            i32.eqz\n")
      out.write_string("            if\n")
      out.write_string("              local.get ")
      out.write_string(tee_b.to_string())
      out.write_string("\n")
      out.write_string("              br 1\n")
      out.write_string("            end\n")
      out.write_string("          end\n")
      out.write_string("          local.get ")
      out.write_string(tee_b.to_string())
      out.write_string("\n")
      out.write_string("          return\n")
      out.write_string("        end\n")
    }
    out.write_string("      drop\n")
    out.write_string("      local.get 0\n")
    out.write_string("      call 0\n")
    out.write_string("      drop\n")
    out.write_string("      i32.const ")
    out.write_string(case_idx.to_string())
    out.write_string("\n")
    if case_idx + 1 < depth {
      out.write_string("      br $exit\n")
    }
  }
  out.write_string("    end)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_large_value_if_branch_ladder_module(
  case_count : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32)\n")
  out.write_string("    local.get 0\n")
  out.write_string("    drop)\n")
  out.write_string("  (func (param i32) (result i64)\n")
  out.write_string("    (local i32)\n")
  let depth = 10
  let mut level = depth - 1
  while level >= 0 {
    out.write_string("    block $b")
    out.write_string(level.to_string())
    out.write_string("\n")
    level = level - 1
  }
  let ladder = StringBuilder::new()
  ladder.write_string("        local.get 0\n")
  ladder.write_string("        call 0\n")
  ladder.write_string("        i64.const 9999\n")
  let mut case_idx = case_count - 1
  while case_idx >= 0 {
    let next = StringBuilder::new()
    next.write_string("      local.get 1\n")
    next.write_string("      i32.const ")
    next.write_string(case_idx.to_string())
    next.write_string("\n")
    next.write_string("      i32.eq\n")
    next.write_string("      if (result i64)\n")
    if case_idx % 64 == 0 {
      next.write_string("        local.get 0\n")
      next.write_string("        call 0\n")
      next.write_string("        i64.const ")
      next.write_string((1000 + case_idx).to_string())
      next.write_string("\n")
    } else if case_idx % 3 == 0 {
      next.write_string("        local.get 0\n")
      next.write_string("        call 0\n")
      next.write_string("        br $b")
      next.write_string((case_idx % depth).to_string())
      next.write_string("\n")
    } else {
      next.write_string("        br $b")
      next.write_string((case_idx % depth).to_string())
      next.write_string("\n")
    }
    next.write_string("      else\n")
    next.write_string(ladder.to_string())
    next.write_string("      end\n")
    ladder.reset()
    ladder.write_string(next.to_string())
    case_idx = case_idx - 1
  }
  out.write_string("      local.get 0\n")
  out.write_string("      local.tee 1\n")
  out.write_string("      drop\n")
  out.write_string(ladder.to_string())
  out.write_string("      return\n")
  for level = 0; level < depth; level = level + 1 {
    out.write_string("    end\n")
    if level + 1 < depth {
      out.write_string("    i64.const ")
      out.write_string((200 + level).to_string())
      out.write_string("\n")
      out.write_string("    return\n")
    }
  }
  out.write_string("    i64.const 300)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_large_drop_heavy_branch_ladder_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  for local_idx = 0; local_idx < 500; local_idx = local_idx + 1 {
    out.write_string(" i32")
  }
  out.write_string(")\n")
  for i = 0; i < repetitions; i = i + 1 {
    let local_base = 2 + i * 10
    let tee_a = local_base
    let set_a = local_base + 1
    let tee_b = local_base + 2
    let set_b = local_base + 3
    let tee_c = local_base + 4
    let set_c = local_base + 5
    let tee_d = local_base + 6
    let set_d = local_base + 7
    let tee_e = local_base + 8
    let set_e = local_base + 9
    out.write_string("    block\n")
    out.write_string("      block\n")
    out.write_string("        local.get 0\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(tee_a.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(set_a.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(set_a.to_string())
    out.write_string("\n")
    out.write_string("        if\n")
    out.write_string("          local.get ")
    out.write_string(tee_a.to_string())
    out.write_string("\n")
    out.write_string("          call 0\n")
    out.write_string("          local.tee ")
    out.write_string(tee_b.to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(set_b.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(tee_b.to_string())
    out.write_string("\n")
    out.write_string("          call 0\n")
    out.write_string("          drop\n")
    out.write_string("          local.get ")
    out.write_string(set_b.to_string())
    out.write_string("\n")
    out.write_string("          if\n")
    out.write_string("            local.get ")
    out.write_string(tee_b.to_string())
    out.write_string("\n")
    out.write_string("            call 0\n")
    out.write_string("            local.tee ")
    out.write_string(tee_c.to_string())
    out.write_string("\n")
    out.write_string("            local.set ")
    out.write_string(set_c.to_string())
    out.write_string("\n")
    out.write_string("            local.get ")
    out.write_string(tee_c.to_string())
    out.write_string("\n")
    out.write_string("            call 0\n")
    out.write_string("            drop\n")
    out.write_string("            br 1\n")
    out.write_string("          end\n")
    out.write_string("        end\n")
    out.write_string("        local.get 1\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(tee_d.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(set_d.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(set_d.to_string())
    out.write_string("\n")
    out.write_string("        if\n")
    out.write_string("          local.get ")
    out.write_string(tee_d.to_string())
    out.write_string("\n")
    out.write_string("          call 0\n")
    out.write_string("          local.tee ")
    out.write_string(tee_e.to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(set_e.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(tee_e.to_string())
    out.write_string("\n")
    out.write_string("          call 0\n")
    out.write_string("          drop\n")
    out.write_string("          br 1\n")
    out.write_string("        end\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
  }
  out.write_string("    local.get 0)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_large_tagged_result_prefix_ladder_module(
  case_count : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  for local_idx = 0; local_idx < 520; local_idx = local_idx + 1 {
    out.write_string(" i32")
  }
  out.write_string(")\n")
  let ladder = StringBuilder::new()
  ladder.write_string("        i32.const 9999\n")
  let mut local_base = 2
  let mut case_idx = case_count - 1
  while case_idx >= 0 {
    let next = StringBuilder::new()
    let local_a = local_base
    let local_b = local_base + 1
    let local_c = local_base + 2
    let local_d = local_base + 3
    let local_e = local_base + 4
    let local_f = local_base + 5
    next.write_string("    block $b")
    next.write_string(case_idx.to_string())
    next.write_string(" (result i32)\n")
    next.write_string("      local.get 0\n")
    next.write_string("      i32.const ")
    next.write_string(case_idx.to_string())
    next.write_string("\n")
    next.write_string("      i32.eq\n")
    next.write_string("      if (result i32)\n")
    next.write_string("        local.get 1\n")
    next.write_string("        call 0\n")
    next.write_string("        local.tee ")
    next.write_string(local_a.to_string())
    next.write_string("\n")
    next.write_string("        local.set ")
    next.write_string(local_b.to_string())
    next.write_string("\n")
    next.write_string("        local.get ")
    next.write_string(local_b.to_string())
    next.write_string("\n")
    next.write_string("        call 0\n")
    next.write_string("        local.tee ")
    next.write_string(local_c.to_string())
    next.write_string("\n")
    next.write_string("        local.set ")
    next.write_string(local_d.to_string())
    next.write_string("\n")
    next.write_string("        local.get ")
    next.write_string(local_d.to_string())
    next.write_string("\n")
    next.write_string("        call 0\n")
    next.write_string("        local.tee ")
    next.write_string(local_e.to_string())
    next.write_string("\n")
    next.write_string("        local.set ")
    next.write_string(local_f.to_string())
    next.write_string("\n")
    next.write_string("        local.get ")
    next.write_string(local_f.to_string())
    next.write_string("\n")
    next.write_string("        i32.eqz\n")
    next.write_string("        if\n")
    next.write_string("          local.get ")
    next.write_string(local_a.to_string())
    next.write_string("\n")
    next.write_string("          drop\n")
    next.write_string("        end\n")
    next.write_string("        local.get ")
    next.write_string(local_e.to_string())
    next.write_string("\n")
    next.write_string("        i32.eqz\n")
    next.write_string("        if\n")
    next.write_string("          local.get ")
    next.write_string(local_c.to_string())
    next.write_string("\n")
    next.write_string("          drop\n")
    next.write_string("        end\n")
    next.write_string("        local.get ")
    next.write_string(local_a.to_string())
    next.write_string("\n")
    next.write_string("        local.get ")
    next.write_string(local_c.to_string())
    next.write_string("\n")
    next.write_string("        i32.add\n")
    next.write_string("        local.get ")
    next.write_string(local_e.to_string())
    next.write_string("\n")
    next.write_string("        i32.add\n")
    next.write_string("        i32.const ")
    next.write_string((1000 + case_idx).to_string())
    next.write_string("\n")
    next.write_string("        i32.add\n")
    next.write_string("      else\n")
    next.write_string(ladder.to_string())
    next.write_string("      end\n")
    next.write_string("      drop\n")
    next.write_string("      local.get 1\n")
    next.write_string("      call 0\n")
    next.write_string("    end\n")
    ladder.reset()
    ladder.write_string(next.to_string())
    local_base = local_base + 6
    case_idx = case_idx - 1
  }
  out.write_string(ladder.to_string())
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_moderate_control_ladder_module(repetitions : Int) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  for local_idx = 0; local_idx < 480; local_idx = local_idx + 1 {
    out.write_string(" i32")
  }
  out.write_string(")\n")
  for i = 0; i < repetitions; i = i + 1 {
    let a = i % 120 + 1
    let b = i % 120 + 121
    let c = i % 120 + 241
    let d = i % 120 + 361
    out.write_string("    block\n")
    out.write_string("      local.get 0\n")
    out.write_string("      call 0\n")
    out.write_string("      local.tee ")
    out.write_string(a.to_string())
    out.write_string("\n")
    out.write_string("      local.set ")
    out.write_string(b.to_string())
    out.write_string("\n")
    out.write_string("      local.get 0\n")
    out.write_string("      if\n")
    out.write_string("        local.get ")
    out.write_string(b.to_string())
    out.write_string("\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(c.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(d.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(c.to_string())
    out.write_string("\n")
    out.write_string("        if\n")
    out.write_string("          local.get ")
    out.write_string(d.to_string())
    out.write_string("\n")
    out.write_string("          call 0\n")
    out.write_string("          local.tee ")
    out.write_string(a.to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(b.to_string())
    out.write_string("\n")
    out.write_string("          i32.const 0\n")
    out.write_string("          drop\n")
    out.write_string("        else\n")
    out.write_string("          local.get ")
    out.write_string(a.to_string())
    out.write_string("\n")
    out.write_string("          call 0\n")
    out.write_string("          local.tee ")
    out.write_string(c.to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(d.to_string())
    out.write_string("\n")
    out.write_string("          i32.const 1\n")
    out.write_string("          return\n")
    out.write_string("        end\n")
    out.write_string("      else\n")
    out.write_string("        local.get ")
    out.write_string(a.to_string())
    out.write_string("\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(c.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(d.to_string())
    out.write_string("\n")
    out.write_string("        i32.const 2\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
  }
  out.write_string("    local.get 0)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_nested_constructor_hot_skip_module() -> String {
  (
    #| (module
    #|   (func (param i32) (result i32)
    #|     local.get 0)
    #|   (func (param i32) (result i32)
    #|     local.get 0)
    #|   (func (param i32) (result i32)
    #|     local.get 0)
    #|   (func (param i32) (result i32)
    #|     local.get 0)
    #|   (func (param i32) (result i32)
    #|     local.get 0)
    #|   (func (param i32 i32) (result i32)
    #|     local.get 0
    #|     local.get 1
    #|     i32.add)
    #|   (func (param i32 i32) (result i32)
    #|     (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|     block
    #|       block
    #|         local.get 0
    #|         call 0
    #|         local.tee 3
    #|         i32.const 1
    #|         i32.eq
    #|         if
    #|           local.get 0
    #|           call 1
    #|           local.tee 4
    #|           i32.const 0
    #|           i32.gt_s
    #|           if
    #|             local.get 4
    #|             local.get 1
    #|             call 5
    #|             local.set 5
    #|           else
    #|             local.get 4
    #|             i32.const 1
    #|             i32.eq
    #|             if
    #|               local.get 4
    #|               call 2
    #|               local.set 5
    #|             end
    #|           end
    #|           local.get 4
    #|           call 3
    #|           local.tee 6
    #|           local.set 7
    #|           br 1
    #|         else
    #|           local.get 0
    #|           call 1
    #|           local.tee 6
    #|           local.set 7
    #|           br 0
    #|         end
    #|         unreachable
    #|       end
    #|       local.get 6
    #|       call 3
    #|       local.set 8
    #|       local.get 7
    #|       local.get 8
    #|       call 5
    #|       local.tee 9
    #|       local.set 10
    #|       return
    #|     end
    #|     local.get 7))
    #|
  )
}

///|
fn perf_test_make_if_only_no_run_candidate_module(repetitions : Int) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 128 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < repetitions {
    let set_local = i % 64 + 1
    out.write_string("    local.get 0\n")
    out.write_string("    if\n")
    out.write_string("      local.get 0\n")
    out.write_string("      call 0\n")
    out.write_string("      local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("    else\n")
    out.write_string("      local.get 0\n")
    out.write_string("      call 0\n")
    out.write_string("      drop\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 0)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
test "perf session records hot allocation deltas dumps and checkpoints" {
  let lines : Array[String] = []
  let perf = HotPerfSession::new(
    trace=fn(line) { lines.push(line) },
    dump_options=HotPerfDumpOptions::new(hot_func=true, cfg=true),
  )
  let func = @ir.HotFunc::new()
  let before = perf_snapshot_hot_func(func)
  let const_ = @ir.hot_build_const_i32(func, @lib.I32(9))
  @ir.hot_root_append(func, const_)
  let after = perf_snapshot_hot_func(func)

  perf_count_hot_alloc_delta(perf, before, after)
  let cfg = @ir.cfg_build(func)
  perf_count_cfg_build(perf)
  perf_count_traversal_visit(perf, count=@ir.cfg_block_count(cfg))
  perf_dump_hot_func(perf, func, "after-build")
  perf_dump_cfg(perf, cfg, "after-build")
  perf_validation_checkpoint(perf, "after-build")

  let counters = perf_counters(perf)
  assert_eq(counters.node_allocs, 1)
  assert_eq(counters.child_span_allocs, 0)
  assert_eq(counters.side_table_allocs, 1)
  assert_eq(counters.cfg_builds, 1)
  assert_eq(counters.traversal_visits, @ir.cfg_block_count(cfg))

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("perf:dump hot-func label=after-build"))
  assert_true(text.contains("perf:dump cfg label=after-build"))
  assert_true(text.contains("perf:checkpoint name=after-build"))
}

///|
test "pass require cfg records a single cfg build and optional cfg dump" {
  let lines : Array[String] = []
  let perf = HotPerfSession::new(
    trace=fn(line) { lines.push(line) },
    dump_options=HotPerfDumpOptions::new(cfg=true),
  )
  let func = pass_test_lift_first_func(
    "(module (func (result i32) i32.const 9))",
  )
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("test"),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    perf=Some(perf),
  )

  ignore(pass_require_cfg(ctx, func))
  ignore(pass_require_cfg(ctx, func))

  let counters = perf_counters(perf)
  assert_eq(counters.cfg_builds, 1)
  let text = perf_test_join_lines(lines)
  assert_true(text.contains("perf:timer name=analysis:cfg"))
  assert_true(text.contains("perf:dump cfg label=analysis:cfg"))
}

///|
test "run hot pipeline emits perf timing and checkpoint lines while dumps stay opt in" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let options = HotPipelineOptions::new(
    verify_policy=HotPipelineVerifyPolicy::after_each_pass(),
    trace=Some(trace),
    perf=Some(perf),
  )

  match
    pass_test_run_pipeline(
      "(module (func (result i32) nop i32.const 9))",
      ["vacuum"],
      options~,
    ) {
    Ok(_) => ()
    Err(err) => fail("expected perf pipeline success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("perf:timer name=lift"))
  assert_true(text.contains("perf:timer name=pass:vacuum"))
  assert_true(text.contains("perf:timer name=lower"))
  assert_true(text.contains("perf:timer name=validate:final-module"))
  assert_true(text.contains("perf:checkpoint name=verify after lift"))
  assert_true(text.contains("perf:counters label=pipeline:done"))
  assert_false(text.contains("perf:dump"))
}

///|
test "run hot pipeline omits hot verify checkpoints under final-module-only policy" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) nop i32.const 9))",
      ["vacuum"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected final-module-only perf pipeline success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_false(text.contains("perf:checkpoint name=verify after lift"))
  assert_false(text.contains("perf:timer name=verify:after-lift"))
  assert_false(text.contains("perf:checkpoint name=verify before lower"))
  assert_false(text.contains("perf:timer name=verify:before-lower"))
  assert_true(text.contains("perf:timer name=validate:final-module"))
}

///|
test "run hot pipeline skips lower when a hot pass leaves the function unchanged" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 9))",
      ["vacuum"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected unchanged hot pipeline success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("perf:timer name=lift"))
  assert_true(text.contains("perf:timer name=pass:vacuum"))
  assert_false(text.contains("perf:timer name=lower"))
}

///|
test "ssa-nomerge skips ssa analysis when there are no local writes" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 9))",
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected no-write ssa-nomerge success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_false(text.contains("perf:timer name=analysis:ssa"))
}

///|
test "ssa-nomerge skips raw lift when the original function has no local writes" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 9))",
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected raw-skip ssa-nomerge success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("pass[ssa-nomerge]:skip-raw"))
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:ssa-nomerge"))
}

///|
test "precompute raw-folds scalar constants without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 0 i32.const 2 i32.and i32.const 1 i32.or))",
      ["precompute"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected raw precompute scalar fold success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("i32.and"), msg=pretty)
  assert_false(pretty.contains("i32.or"), msg=pretty)
  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains("pass[precompute]:skip-raw reason=raw-scalar-folds"),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:precompute"), msg=text)
}

///|
test "remove-unused-names skips raw lift when the original function has no candidate control flow" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_if_only_no_run_candidate_module(256)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-names"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected raw-skip remove-unused-names success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-names]:skip-raw reason=no-remove-unused-names-candidates",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:remove-unused-names"))
}

///|
test "remove-unused-brs skips raw lift when the original function has no candidate control flow" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 9))",
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected raw-skip remove-unused-brs success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("pass[remove-unused-brs]:skip-raw"))
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:remove-unused-brs"))
}

///|
test "remove-unused-brs rewrites decision ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32 i32) (result i32)
    #|     (block (result i32)
    #|       (block
    #|         (block
    #|           local.get 0
    #|           br_table 0 1
    #|         )
    #|         local.get 1
    #|         i32.const 0
    #|         i32.eq
    #|         if (result i32)
    #|           i32.const 1
    #|         else
    #|           i32.const 0
    #|         end
    #|         br 1
    #|         )
    #|       local.get 1
    #|       i32.const 1
    #|       i32.eq
    #|       if (result i32)
    #|         i32.const 1
    #|       else
    #|         i32.const 0
    #|       end
    #|     )))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected raw decision-ladder remove-unused-brs success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=decision-ladder-selects",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:remove-unused-brs"))
}

///|
test "remove-unused-brs skips large void-if return ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_large_void_if_return_ladder_module(1000)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected large void-if return ladder raw remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=large-void-if-return-ladder-noop",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(
    text.contains("perf:timer name=pass:remove-unused-brs"),
    msg=text,
  )
}

///|
test "remove-unused-brs leaves single-root value-if ladders unchanged after lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_single_root_value_if_ladder_module(160)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected single-root value-if remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_false(text.contains("pass[remove-unused-brs]:skip-hot"), msg=text)
  assert_true(
    text.contains("pass[remove-unused-brs]:done changed=false"),
    msg=text,
  )
  assert_true(text.contains("perf:timer name=lift"), msg=text)
  assert_true(text.contains("perf:timer name=pass:remove-unused-brs"), msg=text)
}

///|
test "remove-unused-brs skips structured return ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_structured_return_ladder_module(6)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected structured return ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=structured-return-ladder-noop",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:remove-unused-brs"))
}

///|
test "remove-unused-brs skips unique loop-select return ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_unique_loop_select_return_ladder_module()

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected unique loop-select return ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=unique-loop-select-return-ladder-noop",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:remove-unused-brs"))
}

///|
test "remove-unused-brs skips mid unique loop-select return ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_mid_unique_loop_select_return_ladder_module()

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected mid unique loop-select return ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=unique-loop-select-return-ladder-noop",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(
    text.contains("perf:timer name=pass:remove-unused-brs"),
    msg=text,
  )
}

///|
test "remove-unused-brs skips nested constructor ladders after lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_nested_constructor_hot_skip_module()

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nested constructor ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-hot reason=nested-constructor-return-ladder-noop",
    ),
  )
  assert_true(text.contains("perf:timer name=lift"))
  assert_true(text.contains("perf:timer name=pass:remove-unused-brs"))
}

///|
test "remove-unused-brs skips wider structured return ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_structured_return_ladder_module(17)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected wider structured return ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=structured-return-ladder-noop",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:remove-unused-brs"))
}

///|
test "remove-unused-brs lifts structured return ladders when a condition-child value if still needs select rewriting" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_structured_return_ladder_with_condition_child_if_module(
    6,
  )
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected structured return ladder with condition-child rewrite success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_false(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=structured-return-ladder-noop",
    ),
    msg=text,
  )
  assert_true(text.contains("perf:timer name=lift"), msg=text)
  assert_true(text.contains("perf:timer name=pass:remove-unused-brs"), msg=text)

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("(if (I32) (local.get (Local 0))"), msg=pretty)
}

///|
test "remove-unused-brs lifts structured return ladders when a carried guard block still needs hot rewriting" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_structured_return_ladder_with_guard_carrier_module(
    6,
  )
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected structured return ladder with carried guard rewrite success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_false(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=structured-return-ladder-noop",
    ),
    msg=text,
  )
  assert_true(text.contains("perf:timer name=lift"), msg=text)
  assert_true(text.contains("perf:timer name=pass:remove-unused-brs"), msg=text)

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("(if (Void)"), msg=pretty)
  assert_false(pretty.contains("br_if"), msg=pretty)
}

///|
test "remove-unused-brs skips structured return ladders when a false prefix guard candidate cannot rewrite" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_structured_return_ladder_with_false_prefix_guard_module(
    6,
  )

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected false prefix-guard structured ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=structured-return-ladder-noop",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(
    text.contains("perf:timer name=pass:remove-unused-brs"),
    msg=text,
  )
}

///|
test "remove-unused-brs does not build use-def when rewriting tail returns" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 9 return))",
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tail-return remove-unused-brs success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("perf:timer name=lift"))
  assert_true(text.contains("perf:timer name=pass:remove-unused-brs"))
  assert_false(text.contains("perf:timer name=analysis:use-def"))
}

///|
test "remove-unused-brs trims one mutation step from tail branch payload if cleanup" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (block (result i32) (br 0 (if (result i32) (local.get 0) (then (i32.const 1)) (else (i32.const 0)))))))",
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tail-branch-payload remove-unused-brs success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  let mutations = perf_test_count_occurrences(
    text, "pass[remove-unused-brs]:mutated revision=",
  )
  assert_true(
    mutations <= 3,
    msg="unexpected mutation churn: \{mutations}\n\{text}",
  )
}

///|
test "remove-unused-brs rewrites br_table continuation wrappers in one mutation" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32 i32) (result i32)
    #|     (local i32 i32)
    #|     (block $exit
    #|       (return
    #|         (block $carry (result i32)
    #|           (block $b4
    #|             (block $b3
    #|               (block $b0
    #|                 (block $b1
    #|                   (block $b2
    #|                     (br_table $b0 $b1 $b2 $b3 $b4
    #|                       (i32.sub
    #|                         (local.get 1)
    #|                         (i32.const 2))))
    #|                   (br $exit))
    #|                 (br $exit))
    #|               (br $exit))
    #|             (local.set 2 (i32.const 7))
    #|             (br $carry (local.get 2)))
    #|           (drop (local.get 0))
    #|           (i32.const 0))
    #|       ))
    #|     (local.set 3 (i32.const 9))
    #|     (local.get 3)))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected br_table continuation-wrapper remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  let mutations = perf_test_count_occurrences(
    text, "pass[remove-unused-brs]:mutated revision=",
  )
  assert_false(text.contains("pass[remove-unused-brs]:skip-raw"), msg=text)
  assert_true(
    text.contains("pass[remove-unused-brs]:done changed=true"),
    msg=text,
  )
  assert_true(
    mutations <= 2,
    msg="unexpected mutation churn: \{mutations}\n\{text}",
  )
}

///|
test "remove-unused-brs skips prefix-root scans for nested block dispatch ladders" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (block $exit
    #|       (return
    #|         (block $carry (result i32)
    #|           (block $b3
    #|             (block $b2
    #|               (block $b1
    #|                 (block $b0
    #|                   (br_table $b0 $b1 $b2 $b3 $b3 (local.get 0)))
    #|                 (br $carry (i32.const 11)))
    #|               (br $carry (i32.const 22)))
    #|             (br $carry (i32.const 33)))
    #|           (i32.const 44))))))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nested block dispatch remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_false(text.contains("pass[remove-unused-brs]:skip-raw"), msg=text)
  assert_true(
    text.contains("pass[remove-unused-brs]:done changed=false"),
    msg=text,
  )
  assert_false(text.contains("rub-prefix-root reject=guard-op"), msg=text)
}

///|
test "remove-unused-brs skips result-prefix scans for nested block dispatch ladders" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (block $exit (result i32)
    #|       (block $inner
    #|         (block $b2
    #|           (block $b1
    #|             (block $b0
    #|               (br_table $inner $b0 $b1 $b2 $b2 (local.get 0)))
    #|             (br $exit (i32.const 11)))
    #|           (br $exit (i32.const 22)))
    #|         (br $exit (i32.const 33)))
    #|       (i32.const 44))))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nested result-block dispatch remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_false(text.contains("pass[remove-unused-brs]:skip-raw"), msg=text)
  assert_true(
    text.contains("pass[remove-unused-brs]:done changed=false"),
    msg=text,
  )
  assert_false(text.contains("rub-result-prefix reject=guard-op"), msg=text)
}

///|
test "remove-unused-brs skips large result br_table dispatch ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_large_result_br_table_dispatch_ladder_module(48)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected large result br_table dispatch remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=large-result-br-table-dispatch-ladder-noop",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(
    text.contains("perf:timer name=pass:remove-unused-brs"),
    msg=text,
  )
}

///|
test "remove-unused-brs skips large br_table return ladders after lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_large_br_table_return_ladder_hot_skip_module(36)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected large br_table return ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-hot reason=large-br-table-return-ladder-noop",
    ),
    msg=text,
  )
  assert_true(text.contains("perf:timer name=lift"), msg=text)
  assert_true(text.contains("perf:timer name=pass:remove-unused-brs"), msg=text)
}

///|
test "remove-unused-brs skips large typed br_table encoder ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_large_typed_br_table_encoder_ladder_module(48, 6)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected large typed br_table encoder ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=large-typed-br-table-encoder-ladder-noop",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(
    text.contains("perf:timer name=pass:remove-unused-brs"),
    msg=text,
  )
}

///|
test "remove-unused-brs skips large value-if branch ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_large_value_if_branch_ladder_module(320)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected large value-if branch ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=large-value-if-branch-ladder-noop",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(
    text.contains("perf:timer name=pass:remove-unused-brs"),
    msg=text,
  )
}

///|
test "remove-unused-brs skips large drop-heavy branch ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_large_drop_heavy_branch_ladder_module(45)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected large drop-heavy branch ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=large-drop-heavy-branch-ladder-noop",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(
    text.contains("perf:timer name=pass:remove-unused-brs"),
    msg=text,
  )
}

///|
test "remove-unused-brs skips large tagged result-prefix ladders after lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_large_tagged_result_prefix_ladder_module(72)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected large tagged result-prefix ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-hot reason=large-tagged-result-prefix-ladder-noop",
    ),
    msg=text,
  )
  assert_true(text.contains("perf:timer name=lift"), msg=text)
  assert_true(text.contains("perf:timer name=pass:remove-unused-brs"), msg=text)
}

///|
test "remove-unused-brs skips moderate control ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_moderate_control_ladder_module(60)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected moderate control ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=moderate-control-ladder-noop",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(
    text.contains("perf:timer name=pass:remove-unused-brs"),
    msg=text,
  )
}

///|
test "simplify-locals rewrites multivalue tail ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_multivalue_tail_ladder_module(12)
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multivalue tail ladder simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=multivalue-tail-local-get-ladder",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:simplify-locals"))
  assert_false(
    pretty.contains(
      "(local.set (Local 2))(i32.const I32(1))(local.get (Local 2))",
    ),
    msg=pretty,
  )
}

///|
test "simplify-locals rewrites multivalue status tail ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_multivalue_status_tail_ladder_module(
    12,
  )
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multivalue status tail ladder simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=multivalue-tail-local-get-ladder",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:simplify-locals"))
  assert_false(
    pretty.contains(
      "(local.set (Local 2))(i32.const I32(0))(local.get (Local 2))",
    ),
    msg=pretty,
  )
}

///|
test "simplify-locals rewrites small multivalue status tail ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_multivalue_status_tail_ladder_module(
    12,
  )
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected small multivalue status tail ladder simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=multivalue-tail-local-get-ladder",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:simplify-locals"))
  assert_false(
    pretty.contains(
      "(local.set (Local 2))(i32.const I32(0))(local.get (Local 2))",
    ),
    msg=pretty,
  )
}

///|
test "simplify-locals rewrites sparse multivalue status tail ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_sparse_multivalue_status_tail_ladder_module(
    15,
  )
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected sparse multivalue status tail ladder simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=multivalue-tail-local-get-ladder",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:simplify-locals"))
  assert_false(
    pretty.contains(
      "(local.set (Local 2))(i32.const I32(0))(local.get (Local 2))return",
    ),
    msg=pretty,
  )
}

///|
test "simplify-locals skips multivalue call-heavy ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_multivalue_call_ladder_module(12)

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected multivalue call-heavy ladder simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=multivalue-call-heavy-ladder",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals rewrites straight-line pure call tails without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_straight_line_copy_call_tail_module(
    96,
  )
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected straight-line call tail simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=straight-line-pure-copy-call-tail",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:simplify-locals"))
  assert_eq(perf_test_count_occurrences(pretty, "local.set"), 0, msg=pretty)
}

///|
test "simplify-locals rewrites giant straight-line adjacent tees without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_straight_line_adjacent_tee_module(
    640,
  )
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected giant straight-line adjacent tee simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=straight-line-adjacent-local-tee",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
  assert_eq(perf_test_count_occurrences(pretty, "local.set"), 0, msg=pretty)
  assert_true(pretty.contains("local.tee"), msg=pretty)
}

///|
test "simplify-locals drops dead adjacent local set/get pairs without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_straight_line_adjacent_drop_module(
    640,
  )
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected giant straight-line adjacent drop simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=straight-line-adjacent-local-tee",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.tee"), msg=pretty)
}

///|
test "simplify-locals rewrites straight-line lane builders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_lane_builder_module()
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected straight-line lane builder simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=straight-line-lane-builder",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
  assert_eq(perf_test_count_occurrences(pretty, "local.tee"), 16, msg=pretty)
  assert_false(pretty.contains("nop"), msg=pretty)
}

///|
test "simplify-locals skips large read-only local ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_no_local_writes_module(256)

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected no-local-write simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains("pass[simplify-locals]:skip-raw reason=no-local-writes"),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals rewrites structured pure call tails without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_structured_copy_call_tail_module(
    96,
  )
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected structured call tail simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=structured-pure-copy-call-tail",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:simplify-locals"))
  assert_eq(perf_test_count_occurrences(pretty, "local.set"), 0, msg=pretty)
}

///|
test "simplify-locals skips equivalent cleanup on giant structured copy webs" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_large_equivalent_module(96)

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected giant equivalent simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  let skipped_raw = text.contains(
    "pass[simplify-locals]:skip-raw reason=structured-pure-copy-call-tail",
  )
  if skipped_raw {
    assert_false(text.contains("perf:timer name=lift"), msg=text)
    assert_false(
      text.contains("perf:timer name=pass:simplify-locals"),
      msg=text,
    )
  } else {
    assert_true(text.contains("perf:timer name=lift"), msg=text)
    assert_true(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
  }
  assert_false(
    text.contains("perf:timer name=detail:simplify-locals:equivalent-cleanup"),
    msg=text,
  )
  assert_false(
    text.contains("perf:timer name=detail:simplify-locals:late-dead-cleanup"),
    msg=text,
  )
}

///|
test "simplify-locals skips equivalent cleanup on large structured copy webs" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_large_equivalent_module(32)

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected large equivalent simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  let skipped_raw = text.contains(
    "pass[simplify-locals]:skip-raw reason=structured-pure-copy-call-tail",
  )
  if skipped_raw {
    assert_false(text.contains("perf:timer name=lift"), msg=text)
    assert_false(
      text.contains("perf:timer name=pass:simplify-locals"),
      msg=text,
    )
  } else {
    assert_true(text.contains("perf:timer name=lift"), msg=text)
    assert_true(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
  }
  assert_false(
    text.contains("perf:timer name=detail:simplify-locals:equivalent-cleanup"),
    msg=text,
  )
  assert_false(
    text.contains("perf:timer name=detail:simplify-locals:late-dead-cleanup"),
    msg=text,
  )
}

///|
test "simplify-locals skips equivalent cleanup on sparse medium copy helpers" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_sparse_equivalent_module(60, 8)

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected sparse medium equivalent simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("perf:timer name=lift"), msg=text)
  assert_true(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
  assert_false(
    text.contains("perf:timer name=detail:simplify-locals:equivalent-cleanup"),
    msg=text,
  )
  assert_false(
    text.contains("perf:timer name=detail:simplify-locals:late-dead-cleanup"),
    msg=text,
  )
}

///|
test "simplify-locals skips giant structured call-heavy validators without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_giant_structured_call_heavy_module(
    96,
  )

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected giant structured call-heavy simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=giant-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips large structured call-heavy walkers without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_large_structured_call_heavy_module(
    96,
  )

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected large structured call-heavy simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=giant-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips medium structured call-heavy decoders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_structured_call_heavy_module(
    88, 16,
  )

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected medium structured call-heavy simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=giant-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips smaller structured call-heavy decoders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_structured_call_heavy_module(
    84, 16,
  )

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected smaller structured call-heavy simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=giant-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips medium structured call-heavy reducers without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_structured_call_heavy_module(
    48, 64,
  )

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected medium structured reducer simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=medium-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips compact structured call-heavy printers without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_structured_call_heavy_module(44, 1)

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected compact structured printer simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=medium-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips transformer-shaped structured call walkers without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_transformer_structured_call_module()

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected transformer-shaped simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=transformer-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips small-loop call-heavy kernels without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_small_loop_call_module()

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected small-loop simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains("pass[simplify-locals]:skip-raw reason=small-loop-call-heavy"),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips straight-line builder churn without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_straight_line_builder_module()

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected straight-line builder simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=straight-line-builder-churn",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips huge straight-line call builders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_huge_straight_line_call_builder_module()

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected huge straight-line builder simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=huge-straight-line-call-builder",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips decode-shaped structured call walkers without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_decode_structured_call_module()

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected decode-shaped simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=decode-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips branchy decode fanout without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_branchy_decode_fanout_module()

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected branchy decode simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=branchy-decode-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips stringview trim loops without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_stringview_trim_loop_module()

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected stringview trim simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=stringview-trim-loop-churn",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips transformer catch walkers without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_transformer_catch_module()

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected transformer catch simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=transformer-catch-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips dense structured call helpers without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_dense_structured_call_module()

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected dense structured simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=dense-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips loop-heavy validator call walkers without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_loop_heavy_validator_call_module(
    64, 96,
  )

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected loop-heavy validator simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=validator-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips compact loop-heavy call walkers without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_loop_heavy_validator_call_module(
    28, 64,
  )

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected compact loop-heavy simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=loop-heavy-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips medium loop-heavy call walkers without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_loop_heavy_validator_call_module(
    40, 96,
  )

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected medium loop-heavy simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=loop-heavy-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips parser-shaped local churn without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_parserish_call_module()

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected parser-shaped simplify-locals success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=parser-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips two-loop parser-shaped local churn without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_parserish_two_loop_module()

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected two-loop parser-shaped simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=parser-structured-call-heavy",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips giant structured local churn without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_giant_structured_local_churn_module(
    96,
  )

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected giant structured local churn simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=giant-structured-local-churn",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips low-local decision ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_low_local_decision_ladder_module(
    80,
  )

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected low-local decision ladder simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=low-local-decision-ladder-noop",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips branch-dense structured call-heavy ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_branch_dense_structured_call_heavy_module(
    96, 64,
  )

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected branch-dense structured call-heavy simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=branch-dense-structured-call-heavy-noop",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips block-rich structured call-heavy ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_block_rich_structured_call_heavy_module(
    32, 128,
  )

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected block-rich structured call-heavy simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=block-rich-structured-call-heavy-noop",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals skips call-dense structured walkers without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_simplify_locals_call_dense_structured_walker_module(
    64, 192,
  )

  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected call-dense structured walker simplify-locals success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=call-dense-structured-walker-noop",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "ssa-nomerge rewrites straight-line local traffic without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 5 local.set 0 local.get 0))",
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected straight-line raw ssa-nomerge success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[ssa-nomerge]:skip-raw reason=straight-line-local-writes",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=analysis:ssa"))
}

///|
test "dead-code-elimination skips raw lift for straight-line value-returning functions" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 9))",
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected raw-skip dead-code-elimination success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:dead-code-elimination"))
}

///|
test "dead-code-elimination skips raw lift for straight-line void direct calls" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (type (func)) (import \"env\" \"ping\" (func (type 0))) (func call 0))",
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected raw-skip dead-code-elimination direct-call success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:dead-code-elimination"))
}

///|
test "dead-code-elimination skips raw lift for branchless void structured control" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (param i32) local.get 0 if nop else nop end))",
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected structured raw-skip dead-code-elimination success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:dead-code-elimination"))
}

///|
test "dead-code-elimination skips raw lift for branchless typed final if" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 7
    #|     else
    #|       i32.const 9
    #|     end))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected typed raw-skip dead-code-elimination success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:dead-code-elimination"))
}

///|
test "dead-code-elimination skips raw lift for branchless typed final if after impure dropped call" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (type (func (result i32)))
    #|   (import "env" "next" (func (type 0)))
    #|   (func (param i32) (result i32)
    #|     call 0
    #|     drop
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 7
    #|     else
    #|       i32.const 9
    #|     end))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected impure-drop typed raw-skip dead-code-elimination success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:dead-code-elimination"))
}

///|
test "dead-code-elimination skips raw lift for branchy typed final control with only live typed results" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     local.get 0
    #|     if (result i32)
    #|       block (result i32)
    #|         i32.const 7
    #|         br 0
    #|       end
    #|     else
    #|       block (result i32)
    #|         i32.const 9
    #|         br 0
    #|       end
    #|     end))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected branchy typed raw-skip dead-code-elimination success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:dead-code-elimination"))
}

///|
test "dead-code-elimination does not skip raw lift for nonfallthrough typed final if" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 7
    #|       return
    #|     else
    #|       i32.const 9
    #|       return
    #|     end
    #|     unreachable))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nonfallthrough typed dead-code-elimination success without raw skip, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_false(
    text.contains(
      "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
    ),
  )
  assert_true(text.contains("perf:timer name=lift"))
  assert_true(text.contains("perf:timer name=pass:dead-code-elimination"))
}

///|
test "dead-code-elimination does not skip raw lift for straight-line dead drops" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 1 drop i32.const 7))",
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-drop dead-code-elimination success without raw skip, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_false(
    text.contains(
      "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
    ),
  )
  assert_true(text.contains("perf:timer name=lift"))
  assert_true(text.contains("perf:timer name=pass:dead-code-elimination"))
}

///|
test "ssa-nomerge rewrites structured early-return locals without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     local.get 0
    #|     if
    #|       i32.const 7
    #|       local.set 1
    #|       local.get 1
    #|       return
    #|     else
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected structured raw ssa-nomerge success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes"),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=analysis:ssa"))
}

///|
test "ssa-nomerge rewrites block-target branches without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 0
    #|     local.set 1
    #|     block
    #|       local.get 0
    #|       if
    #|         i32.const 7
    #|         local.set 1
    #|         br 1
    #|       end
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected block-branch raw ssa-nomerge success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes"),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=analysis:ssa"))
}

///|
test "heap-store-optimization skips raw lift when the original function has no HSO candidates" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 9))",
      ["heap-store-optimization"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected raw-skip HSO success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("pass[heap-store-optimization]:skip-raw"))
  assert_false(text.contains("pass[heap-store-optimization]:func"))
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=analysis:effects"))
  assert_false(text.contains("perf:timer name=analysis:module-context"))
  assert_false(text.contains("perf:timer name=pass:heap-store-optimization"))
}

///|
test "heap-store-optimization skips raw lift when struct allocations cannot feed struct.set" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (type (struct (field (mut i32)))) (func (result i32) (local (ref null 0)) (local.set 0 (struct.new_default 0)) i32.const 7))",
      ["heap-store-optimization"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected allocation-only raw-skip HSO success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[heap-store-optimization]:skip-raw reason=no-heap-store-candidates",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=analysis:module-context"))
  assert_false(text.contains("perf:timer name=analysis:effects"))
}

///|
test "heap-store-optimization aggregates identical raw-skip trace lines across functions" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let input =
    #| (module
    #|   (func (result i32) i32.const 1)
    #|   (func (result i32) i32.const 2))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["heap-store-optimization"],
      options=HotPipelineOptions::new(trace=Some(trace)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected aggregated HSO raw-skip success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_eq(
    perf_test_count_occurrences(
      text, "pass[heap-store-optimization]:skip-raw reason=no-heap-store-candidates",
    ),
    1,
  )
  assert_false(text.contains("pass[heap-store-optimization]:func"))
}

///|
test "pick-load-signs skips raw lift when the original function has no narrow load candidates" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) i32.const 9))",
      ["pick-load-signs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected raw-skip pick-load-signs success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[pick-load-signs]:skip-raw reason=no-pick-load-signs-candidates",
    ),
  )
  assert_false(text.contains("pass[pick-load-signs]:func"))
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=analysis:use-def"))
  assert_false(text.contains("perf:timer name=pass:pick-load-signs"))
}

///|
test "pick-load-signs skips raw lift when narrow loads have no extension surface" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local $x i32) i32.const 0 i32.load8_u local.set $x local.get $x))",
      ["pick-load-signs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected raw-skip pick-load-signs no-extension success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[pick-load-signs]:skip-raw reason=no-pick-load-signs-candidates",
    ),
  )
  assert_false(text.contains("pass[pick-load-signs]:func"))
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=analysis:use-def"))
}

///|
test "pick-load-signs aggregates identical raw-skip trace lines across functions" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (result i32) i32.const 1)
    #|   (func (result i32) i32.const 2))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["pick-load-signs"],
      options=HotPipelineOptions::new(trace=Some(trace)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected aggregated pick-load-signs raw-skip success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_eq(
    perf_test_count_occurrences(
      text, "pass[pick-load-signs]:skip-raw reason=no-pick-load-signs-candidates",
    ),
    1,
  )
  assert_false(text.contains("pass[pick-load-signs]:func"))
}

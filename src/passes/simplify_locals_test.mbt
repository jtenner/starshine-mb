///|
fn simplify_locals_test_count_substring(text : String, needle : String) -> Int {
  if needle.length() == 0 {
    return 0
  }
  let mut count = 0
  let limit = text.length() - needle.length()
  let mut i = 0
  while i <= limit {
    if text.sub(start=i, end=i + needle.length()).to_string() == needle {
      count += 1
      i += needle.length()
    } else {
      i += 1
    }
  }
  count
}

///|
fn simplify_locals_test_make_large_structured_raw_repro() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func $use (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $side (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32) (local")
  let mut local_count = 0
  while local_count < 128 {
    out.write_string(" i32")
    local_count = local_count + 1
  }
  out.write_string(")\n")
  out.write_string("    block\n")
  let mut i = 0
  while i < 40 {
    let local_idx = 2 + i
    out.write_string("      i32.const ")
    out.write_string((100 + i).to_string())
    out.write_string("\n")
    out.write_string("      local.set ")
    out.write_string(local_idx.to_string())
    out.write_string("\n")
    out.write_string("      local.get 0\n")
    out.write_string("      drop\n")
    out.write_string("      local.get ")
    out.write_string(local_idx.to_string())
    out.write_string("\n")
    out.write_string("      call $use\n")
    out.write_string("      drop\n")
    i = i + 1
  }
  out.write_string("      local.get 0\n")
  out.write_string("      call $side\n")
  out.write_string("      local.set 126\n")
  out.write_string("      local.get 1\n")
  out.write_string("      local.get 126\n")
  out.write_string("      i32.lt_s\n")
  out.write_string("      if\n")
  out.write_string("        nop\n")
  out.write_string("      end\n")
  out.write_string("    end\n")
  out.write_string("    i32.const 0\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn simplify_locals_test_make_large_validator_structured_copy_repro() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func $use (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $side (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32) (local")
  let mut local_count = 0
  while local_count < 256 {
    out.write_string(" i32")
    local_count = local_count + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < 48 {
    let base = 2 + i
    let copy = 50 + i
    let branch = 98 + i
    out.write_string("    block\n")
    out.write_string("      loop\n")
    out.write_string("        local.get 0\n")
    out.write_string("        call $side\n")
    out.write_string("        local.set ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get 1\n")
    out.write_string("        if\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call $side\n")
    out.write_string("          local.set ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          call $use\n")
    out.write_string("          drop\n")
    out.write_string("        end\n")
    out.write_string("        local.get 1\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 0\n")
  out.write_string("    call $side\n")
  out.write_string("    local.set 250\n")
  out.write_string("    local.get 250\n")
  out.write_string("    call $use\n")
  out.write_string("    drop\n")
  out.write_string("    local.get 250\n")
  out.write_string("    local.set 251\n")
  out.write_string("    (local.set 252\n")
  out.write_string("      (call $side\n")
  out.write_string("        (local.get 0)\n")
  out.write_string("      )\n")
  out.write_string("    )\n")
  out.write_string("    local.get 251\n")
  out.write_string("    call $use\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn simplify_locals_test_make_large_validator_structured_if_copy_repro() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func $use (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $side (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32) (local")
  let mut local_count = 0
  while local_count < 256 {
    out.write_string(" i32")
    local_count = local_count + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < 48 {
    let base = 2 + i
    let copy = 50 + i
    let branch = 98 + i
    out.write_string("    block\n")
    out.write_string("      loop\n")
    out.write_string("        local.get 0\n")
    out.write_string("        call $side\n")
    out.write_string("        local.set ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get 1\n")
    out.write_string("        if\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call $side\n")
    out.write_string("          local.set ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          call $use\n")
    out.write_string("          drop\n")
    out.write_string("        end\n")
    out.write_string("        local.get 1\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 0\n")
  out.write_string("    call $side\n")
  out.write_string("    local.set 250\n")
  out.write_string("    local.get 250\n")
  out.write_string("    call $use\n")
  out.write_string("    drop\n")
  out.write_string("    local.get 250\n")
  out.write_string("    local.set 251\n")
  out.write_string("    local.get 1\n")
  out.write_string("    if\n")
  out.write_string("      local.get 0\n")
  out.write_string("      call $side\n")
  out.write_string("      local.set 252\n")
  out.write_string("      local.get 252\n")
  out.write_string("      call $use\n")
  out.write_string("      drop\n")
  out.write_string("    end\n")
  out.write_string("    local.get 251\n")
  out.write_string("    call $use\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn simplify_locals_test_make_large_validator_structured_condition_temp_repro() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func $use (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $side (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32) (local")
  let mut local_count = 0
  while local_count < 256 {
    out.write_string(" i32")
    local_count = local_count + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < 48 {
    let base = 2 + i
    let copy = 50 + i
    let branch = 98 + i
    out.write_string("    block\n")
    out.write_string("      loop\n")
    out.write_string("        local.get 0\n")
    out.write_string("        call $side\n")
    out.write_string("        local.set ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get 1\n")
    out.write_string("        if\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call $side\n")
    out.write_string("          local.set ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          call $use\n")
    out.write_string("          drop\n")
    out.write_string("        end\n")
    out.write_string("        local.get 1\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 0\n")
  out.write_string("    call $side\n")
  out.write_string("    local.set 250\n")
  out.write_string("    local.get 1\n")
  out.write_string("    local.get 250\n")
  out.write_string("    i32.lt_s\n")
  out.write_string("    if\n")
  out.write_string("      nop\n")
  out.write_string("    end\n")
  out.write_string("    i32.const 0\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn simplify_locals_test_make_large_validator_structured_loop_temp_repro() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (memory 1)\n")
  out.write_string("  (func $use (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $touch (param i32) nop)\n")
  out.write_string("  (func $side (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32) (local")
  let mut local_count = 0
  while local_count < 256 {
    out.write_string(" i32")
    local_count = local_count + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < 48 {
    let base = 2 + i
    let copy = 50 + i
    let branch = 98 + i
    out.write_string("    block\n")
    out.write_string("      loop\n")
    out.write_string("        local.get 0\n")
    out.write_string("        call $side\n")
    out.write_string("        local.set ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get 1\n")
    out.write_string("        if\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call $side\n")
    out.write_string("          local.set ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          call $use\n")
    out.write_string("          drop\n")
    out.write_string("        end\n")
    out.write_string("        local.get 1\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    loop $loop\n")
  out.write_string("      local.get 1\n")
  out.write_string("      local.set 249\n")
  out.write_string("      local.get 0\n")
  out.write_string("      call $touch\n")
  out.write_string("      local.get 0\n")
  out.write_string("      call $side\n")
  out.write_string("      local.set 250\n")
  out.write_string("      local.get 249\n")
  out.write_string("      local.get 250\n")
  out.write_string("      i32.lt_s\n")
  out.write_string("      if\n")
  out.write_string("        local.get 249\n")
  out.write_string("        i32.const 1\n")
  out.write_string("        i32.add\n")
  out.write_string("        local.set 251\n")
  out.write_string("        local.get 0\n")
  out.write_string("        local.get 251\n")
  out.write_string("        i32.store align=1\n")
  out.write_string("        nop\n")
  out.write_string("        br $loop\n")
  out.write_string("      else\n")
  out.write_string("        nop\n")
  out.write_string("      end\n")
  out.write_string("    end\n")
  out.write_string("    i32.const 0\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn simplify_locals_test_make_large_validator_structured_multiuse_temp_repro() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func $use (param i32) nop)\n")
  out.write_string("  (func $id (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $side (param i32) (result i32) local.get 0)\n")
  out.write_string("  (memory 1)\n")
  out.write_string("  (func (param i32 i32) (result i32) (local")
  let mut local_count = 0
  while local_count < 256 {
    out.write_string(" i32")
    local_count = local_count + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < 48 {
    let base = 2 + i
    let copy = 50 + i
    let branch = 98 + i
    out.write_string("    block\n")
    out.write_string("      loop\n")
    out.write_string("        local.get 0\n")
    out.write_string("        call $side\n")
    out.write_string("        local.set ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        local.get 1\n")
    out.write_string("        if\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call $side\n")
    out.write_string("          local.set ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          call $use\n")
    out.write_string("        end\n")
    out.write_string("        local.get 1\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 0\n")
  out.write_string("    i32.load align=1\n")
  out.write_string("    local.set 250\n")
  out.write_string("    local.get 250\n")
  out.write_string("    call $use\n")
  out.write_string("    local.get 250\n")
  out.write_string("    call $id\n")
  out.write_string("    local.set 251\n")
  out.write_string("    local.get 251\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn simplify_locals_test_make_large_validator_structured_leading_condition_temp_repro() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (type $ind (func (param i32 i32) (result i32)))\n")
  out.write_string(
    "  (func $callee (type $ind) (param i32 i32) (result i32) local.get 0 local.get 1 i32.add)\n",
  )
  out.write_string("  (func $pred (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $pred2 (param i32 i32) (result i32) local.get 1)\n")
  out.write_string("  (func $use (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $touch (param i32) nop)\n")
  out.write_string("  (func $side (param i32) (result i32) local.get 0)\n")
  out.write_string("  (memory 1)\n")
  out.write_string("  (table 1 funcref)\n")
  out.write_string("  (elem (i32.const 0) $callee)\n")
  out.write_string("  (func (param i32 i32) (result i32) (local")
  let mut local_count = 0
  while local_count < 256 {
    out.write_string(" i32")
    local_count = local_count + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < 48 {
    let base = 2 + i
    let copy = 50 + i
    let branch = 98 + i
    out.write_string("    block\n")
    out.write_string("      loop\n")
    out.write_string("        local.get 0\n")
    out.write_string("        call $side\n")
    out.write_string("        local.set ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get 1\n")
    out.write_string("        if\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call $side\n")
    out.write_string("          local.set ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          call $use\n")
    out.write_string("          drop\n")
    out.write_string("        end\n")
    out.write_string("        local.get 1\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 0\n")
  out.write_string("    call $touch\n")
  out.write_string("    local.get 0\n")
  out.write_string("    local.get 1\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    call_indirect (type $ind)\n")
  out.write_string("    local.set 250\n")
  out.write_string("    block (result i32)\n")
  out.write_string("      local.get 0\n")
  out.write_string("      local.get 250\n")
  out.write_string("      call $pred2\n")
  out.write_string("      i32.const 1\n")
  out.write_string("      i32.eq\n")
  out.write_string("      if (result i32)\n")
  out.write_string("        local.get 0\n")
  out.write_string("      else\n")
  out.write_string("        i32.const 0\n")
  out.write_string("      end\n")
  out.write_string("    end\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn simplify_locals_test_make_large_validator_structured_block_result_tee_repro() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (type $ind (func (param i32 i32) (result i32)))\n")
  out.write_string(
    "  (func $callee (type $ind) (param i32 i32) (result i32) local.get 0 local.get 1 i32.add)\n",
  )
  out.write_string("  (func $pred (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $pred2 (param i32 i32) (result i32) local.get 1)\n")
  out.write_string("  (func $use (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $touch (param i32) nop)\n")
  out.write_string("  (func $side (param i32) (result i32) local.get 0)\n")
  out.write_string("  (memory 1)\n")
  out.write_string("  (table 1 funcref)\n")
  out.write_string("  (elem (i32.const 0) $callee)\n")
  out.write_string("  (func (param i32 i32) (result i32) (local")
  let mut local_count = 0
  while local_count < 256 {
    out.write_string(" i32")
    local_count = local_count + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < 48 {
    let base = 2 + i
    let copy = 50 + i
    let branch = 98 + i
    out.write_string("    block\n")
    out.write_string("      loop\n")
    out.write_string("        local.get 0\n")
    out.write_string("        call $side\n")
    out.write_string("        local.set ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get 1\n")
    out.write_string("        if\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call $side\n")
    out.write_string("          local.set ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          call $use\n")
    out.write_string("          drop\n")
    out.write_string("        end\n")
    out.write_string("        local.get 1\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 0\n")
  out.write_string("    call $touch\n")
  out.write_string("    local.get 0\n")
  out.write_string("    local.get 1\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    call_indirect (type $ind)\n")
  out.write_string("    local.set 250\n")
  out.write_string("    block (result i32)\n")
  out.write_string("      local.get 0\n")
  out.write_string("      local.get 250\n")
  out.write_string("      call $pred2\n")
  out.write_string("      i32.const 1\n")
  out.write_string("      i32.eq\n")
  out.write_string("      if (result i32)\n")
  out.write_string("        local.get 0\n")
  out.write_string("      else\n")
  out.write_string("        i32.const 0\n")
  out.write_string("      end\n")
  out.write_string("    end\n")
  out.write_string("    local.set 251\n")
  out.write_string("    local.get 251\n")
  out.write_string("    local.get 251\n")
  out.write_string("    i32.add\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn simplify_locals_test_make_large_validator_structured_if_condition_tee_repro() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (type $ind (func (param i32 i32) (result i32)))\n")
  out.write_string(
    "  (func $callee (type $ind) (param i32 i32) (result i32) local.get 0 local.get 1 i32.add)\n",
  )
  out.write_string("  (func $pred (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $pred2 (param i32 i32) (result i32) local.get 1)\n")
  out.write_string("  (func $use (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $touch (param i32) nop)\n")
  out.write_string("  (func $side (param i32) (result i32) local.get 0)\n")
  out.write_string("  (memory 1)\n")
  out.write_string("  (table 1 funcref)\n")
  out.write_string("  (elem (i32.const 0) $callee)\n")
  out.write_string("  (func (param i32 i32) (result i32) (local")
  let mut local_count = 0
  while local_count < 256 {
    out.write_string(" i32")
    local_count = local_count + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < 48 {
    let base = 2 + i
    let copy = 50 + i
    let branch = 98 + i
    out.write_string("    block\n")
    out.write_string("      loop\n")
    out.write_string("        local.get 0\n")
    out.write_string("        call $side\n")
    out.write_string("        local.set ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get 1\n")
    out.write_string("        if\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call $side\n")
    out.write_string("          local.set ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          call $use\n")
    out.write_string("          drop\n")
    out.write_string("        end\n")
    out.write_string("        local.get 1\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 0\n")
  out.write_string("    call $touch\n")
  out.write_string("    local.get 0\n")
  out.write_string("    local.get 1\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    call_indirect (type $ind)\n")
  out.write_string("    local.set 250\n")
  out.write_string("    block (result i32)\n")
  out.write_string("      local.get 0\n")
  out.write_string("      local.get 250\n")
  out.write_string("      call $pred2\n")
  out.write_string("      i32.const 1\n")
  out.write_string("      i32.eq\n")
  out.write_string("      if (result i32)\n")
  out.write_string("        local.get 0\n")
  out.write_string("      else\n")
  out.write_string("        i32.const 0\n")
  out.write_string("      end\n")
  out.write_string("    end\n")
  out.write_string("    local.set 251\n")
  out.write_string("    nop\n")
  out.write_string("    local.get 251\n")
  out.write_string("    i32.load offset=12 align=1\n")
  out.write_string("    if\n")
  out.write_string("      local.get 251\n")
  out.write_string("      call $use\n")
  out.write_string("      drop\n")
  out.write_string("    end\n")
  out.write_string("    local.get 251\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn simplify_locals_test_make_large_validator_structured_effectful_copy_condition_repro() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (type $ind (func (param i32 i32 i32) (result i32)))\n")
  out.write_string(
    "  (func $callee (type $ind) (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i32.add i32.add)\n",
  )
  out.write_string("  (func $pred (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $use (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $touch (param i32) nop)\n")
  out.write_string("  (func $side (param i32) (result i32) local.get 0)\n")
  out.write_string("  (memory 1)\n")
  out.write_string("  (table 1 funcref)\n")
  out.write_string("  (elem (i32.const 0) $callee)\n")
  out.write_string("  (func (param i32 i32) (result i32) (local")
  let mut local_count = 0
  while local_count < 256 {
    out.write_string(" i32")
    local_count = local_count + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < 48 {
    let base = 2 + i
    let copy = 50 + i
    let branch = 98 + i
    out.write_string("    block\n")
    out.write_string("      loop\n")
    out.write_string("        local.get 0\n")
    out.write_string("        call $side\n")
    out.write_string("        local.set ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get 1\n")
    out.write_string("        if\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call $side\n")
    out.write_string("          local.set ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          call $use\n")
    out.write_string("          drop\n")
    out.write_string("        end\n")
    out.write_string("        local.get 1\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 0\n")
  out.write_string("    i32.load offset=32 align=1\n")
  out.write_string("    local.set 250\n")
  out.write_string("    local.get 0\n")
  out.write_string("    i32.load align=1\n")
  out.write_string("    i32.const 1\n")
  out.write_string("    i32.gt_s\n")
  out.write_string("    if\n")
  out.write_string("      nop\n")
  out.write_string("      local.get 0\n")
  out.write_string("      local.get 0\n")
  out.write_string("      i32.load align=1\n")
  out.write_string("      i32.const 1\n")
  out.write_string("      i32.sub\n")
  out.write_string("      i32.store align=1\n")
  out.write_string("      local.get 250\n")
  out.write_string("      call $touch\n")
  out.write_string("    else\n")
  out.write_string("      local.get 0\n")
  out.write_string("      call $touch\n")
  out.write_string("    end\n")
  out.write_string("    local.get 250\n")
  out.write_string("    local.set 251\n")
  out.write_string("    local.get 251\n")
  out.write_string("    local.get 1\n")
  out.write_string("    local.get 251\n")
  out.write_string("    i32.load offset=8 align=1\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    call_indirect (type $ind)\n")
  out.write_string("    call $pred\n")
  out.write_string("    i32.const 1\n")
  out.write_string("    i32.eq\n")
  out.write_string("    if\n")
  out.write_string("      local.get 250\n")
  out.write_string("      call $touch\n")
  out.write_string("    end\n")
  out.write_string("    local.get 250\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn simplify_locals_test_make_large_validator_structured_returning_call_tail_repro() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (type $ind (func (param i32 i32 i32) (result i32)))\n")
  out.write_string(
    "  (func $callee (type $ind) (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i32.add i32.add)\n",
  )
  out.write_string("  (func $pred (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $use (param i32) (result i32) local.get 0)\n")
  out.write_string(
    "  (func $builder (param i32 i32 i32 i64 i64 i32 i64 i32 i32 i32) (result i32) local.get 0)\n",
  )
  out.write_string("  (func $side (param i32) (result i32) local.get 0)\n")
  out.write_string("  (memory 1)\n")
  out.write_string("  (table 1 funcref)\n")
  out.write_string("  (elem (i32.const 0) $callee)\n")
  out.write_string("  (func (param i32 i32) (result i32) (local")
  let mut local_count = 0
  while local_count < 256 {
    out.write_string(" i32")
    local_count = local_count + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < 48 {
    let base = 2 + i
    let copy = 50 + i
    let branch = 98 + i
    out.write_string("    block\n")
    out.write_string("      loop\n")
    out.write_string("        local.get 0\n")
    out.write_string("        call $side\n")
    out.write_string("        local.set ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get 1\n")
    out.write_string("        if\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call $side\n")
    out.write_string("          local.set ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          call $use\n")
    out.write_string("          drop\n")
    out.write_string("        end\n")
    out.write_string("        local.get 1\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 0\n")
  out.write_string("    i32.load offset=32 align=1\n")
  out.write_string("    local.set 250\n")
  out.write_string("    local.get 250\n")
  out.write_string("    local.set 251\n")
  out.write_string("    local.get 251\n")
  out.write_string("    local.get 1\n")
  out.write_string("    local.get 251\n")
  out.write_string("    i32.load offset=8 align=1\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    call_indirect (type $ind)\n")
  out.write_string("    call $pred\n")
  out.write_string("    i32.const 1\n")
  out.write_string("    i32.eq\n")
  out.write_string("    if\n")
  out.write_string("      i32.const 10000\n")
  out.write_string("      local.set 255\n")
  out.write_string("      i32.const 0\n")
  out.write_string("      local.set 252\n")
  out.write_string("      i32.const 0\n")
  out.write_string("      local.set 253\n")
  out.write_string("      i32.const 0\n")
  out.write_string("      local.set 254\n")
  out.write_string("      nop\n")
  out.write_string("      local.get 254\n")
  out.write_string("      local.get 252\n")
  out.write_string("      local.get 253\n")
  out.write_string("      i64.const 4294967296\n")
  out.write_string("      i64.const 4294967296\n")
  out.write_string("      i32.const -1\n")
  out.write_string("      i64.const 4294967296\n")
  out.write_string("      i32.const -1\n")
  out.write_string("      i32.const -1\n")
  out.write_string("      local.get 255\n")
  out.write_string("      call $builder\n")
  out.write_string("      drop\n")
  out.write_string("      local.get 250\n")
  out.write_string("      return\n")
  out.write_string("    else\n")
  out.write_string("      local.get 250\n")
  out.write_string("      call $use\n")
  out.write_string("      drop\n")
  out.write_string("    end\n")
  out.write_string("    local.get 250\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn simplify_locals_test_make_large_validator_structured_const_fanout_repro() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (type $ind (func (param i32 i32 i32) (result i32)))\n")
  out.write_string(
    "  (func $callee (type $ind) (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i32.add i32.add)\n",
  )
  out.write_string("  (func $pred (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $use (param i32) (result i32) local.get 0)\n")
  out.write_string(
    "  (func $wide (param i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) (result i32) local.get 0)\n",
  )
  out.write_string("  (func $side (param i32) (result i32) local.get 0)\n")
  out.write_string("  (memory 1)\n")
  out.write_string("  (table 1 funcref)\n")
  out.write_string("  (elem (i32.const 0) $callee)\n")
  out.write_string("  (func (param i32 i32) (result i32) (local")
  let mut local_count = 0
  while local_count < 256 {
    out.write_string(" i32")
    local_count = local_count + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < 48 {
    let base = 2 + i
    let copy = 50 + i
    let branch = 98 + i
    out.write_string("    block\n")
    out.write_string("      loop\n")
    out.write_string("        local.get 0\n")
    out.write_string("        call $side\n")
    out.write_string("        local.set ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get 1\n")
    out.write_string("        if\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call $side\n")
    out.write_string("          local.set ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          call $use\n")
    out.write_string("          drop\n")
    out.write_string("        end\n")
    out.write_string("        local.get 1\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 0\n")
  out.write_string("    i32.load offset=32 align=1\n")
  out.write_string("    local.set 250\n")
  out.write_string("    local.get 250\n")
  out.write_string("    local.set 251\n")
  out.write_string("    local.get 251\n")
  out.write_string("    local.get 1\n")
  out.write_string("    local.get 251\n")
  out.write_string("    i32.load offset=8 align=1\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    call_indirect (type $ind)\n")
  out.write_string("    call $pred\n")
  out.write_string("    i32.const 1\n")
  out.write_string("    i32.eq\n")
  out.write_string("    if\n")
  out.write_string("      i32.const 10000\n")
  out.write_string("      local.set 244\n")
  out.write_string("      i32.const 10000\n")
  out.write_string("      local.set 245\n")
  out.write_string("      i32.const 0\n")
  out.write_string("      local.set 246\n")
  out.write_string("      i32.const 10000\n")
  out.write_string("      local.set 247\n")
  out.write_string("      i32.const 10000\n")
  out.write_string("      local.set 248\n")
  out.write_string("      i32.const 0\n")
  out.write_string("      local.set 249\n")
  out.write_string("      local.get 250\n")
  out.write_string("      local.set 252\n")
  out.write_string("      i32.const 0\n")
  out.write_string("      local.set 253\n")
  out.write_string("      i32.const 10000\n")
  out.write_string("      local.set 254\n")
  out.write_string("      i32.const 10000\n")
  out.write_string("      local.set 255\n")
  out.write_string("      nop\n")
  out.write_string("      local.get 255\n")
  out.write_string("      local.get 246\n")
  out.write_string("      local.get 249\n")
  out.write_string("      local.get 244\n")
  out.write_string("      local.get 245\n")
  out.write_string("      local.get 247\n")
  out.write_string("      local.get 248\n")
  out.write_string("      local.get 252\n")
  out.write_string("      local.get 253\n")
  out.write_string("      local.get 254\n")
  out.write_string("      call $wide\n")
  out.write_string("      drop\n")
  out.write_string("      local.get 250\n")
  out.write_string("      return\n")
  out.write_string("    else\n")
  out.write_string("      local.get 250\n")
  out.write_string("      call $use\n")
  out.write_string("      drop\n")
  out.write_string("    end\n")
  out.write_string("    local.get 250\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn simplify_locals_test_make_large_validator_structured_returning_const_fanout_repro() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (type $ind (func (param i32 i32 i32) (result i32)))\n")
  out.write_string(
    "  (func $callee (type $ind) (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i32.add i32.add)\n",
  )
  out.write_string("  (func $pred (param i32) (result i32) local.get 0)\n")
  out.write_string("  (func $use (param i32) (result i32) local.get 0)\n")
  out.write_string(
    "  (func $wide (param i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) (result i32) local.get 0)\n",
  )
  out.write_string("  (func $side (param i32) (result i32) local.get 0)\n")
  out.write_string("  (memory 1)\n")
  out.write_string("  (table 1 funcref)\n")
  out.write_string("  (elem (i32.const 0) $callee)\n")
  out.write_string("  (func (param i32 i32) (result i32) (local")
  let mut local_count = 0
  while local_count < 256 {
    out.write_string(" i32")
    local_count = local_count + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < 48 {
    let base = 2 + i
    let copy = 50 + i
    let branch = 98 + i
    out.write_string("    block\n")
    out.write_string("      loop\n")
    out.write_string("        local.get 0\n")
    out.write_string("        call $side\n")
    out.write_string("        local.set ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get ")
    out.write_string(base.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(copy.to_string())
    out.write_string("\n")
    out.write_string("        call $use\n")
    out.write_string("        drop\n")
    out.write_string("        local.get 1\n")
    out.write_string("        if\n")
    out.write_string("          local.get 0\n")
    out.write_string("          call $side\n")
    out.write_string("          local.set ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          local.get ")
    out.write_string(branch.to_string())
    out.write_string("\n")
    out.write_string("          call $use\n")
    out.write_string("          drop\n")
    out.write_string("        end\n")
    out.write_string("        local.get 1\n")
    out.write_string("        drop\n")
    out.write_string("      end\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    local.get 0\n")
  out.write_string("    i32.load offset=32 align=1\n")
  out.write_string("    local.set 250\n")
  out.write_string("    local.get 250\n")
  out.write_string("    local.set 251\n")
  out.write_string("    local.get 251\n")
  out.write_string("    call $use\n")
  out.write_string("    drop\n")
  out.write_string("    local.get 250\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    i32.eq\n")
  out.write_string("    if (result i32)\n")
  out.write_string("      local.get 250\n")
  out.write_string("      call $use\n")
  out.write_string("      drop\n")
  out.write_string("      i32.const 0\n")
  out.write_string("      local.set 244\n")
  out.write_string("      i32.const 0\n")
  out.write_string("      local.set 245\n")
  out.write_string("      i32.const 10000\n")
  out.write_string("      local.set 246\n")
  out.write_string("      i32.const 10000\n")
  out.write_string("      local.set 247\n")
  out.write_string("      i32.const 10000\n")
  out.write_string("      local.set 248\n")
  out.write_string("      i32.const 0\n")
  out.write_string("      local.set 249\n")
  out.write_string("      i32.const 10000\n")
  out.write_string("      local.set 252\n")
  out.write_string("      i32.const 10000\n")
  out.write_string("      local.set 253\n")
  out.write_string("      i32.const 10000\n")
  out.write_string("      nop\n")
  out.write_string("      i32.const 0\n")
  out.write_string("      i32.const -1\n")
  out.write_string("      i32.const -1\n")
  out.write_string("      i32.const -1\n")
  out.write_string("      i32.const -1\n")
  out.write_string("      i32.const -1\n")
  out.write_string("      i32.const 10000\n")
  out.write_string("      i32.const 0\n")
  out.write_string("      local.get 244\n")
  out.write_string("      local.get 245\n")
  out.write_string("      local.get 246\n")
  out.write_string("      local.get 247\n")
  out.write_string("      local.get 248\n")
  out.write_string("      local.get 249\n")
  out.write_string("      local.get 252\n")
  out.write_string("      local.get 253\n")
  out.write_string("      call $wide\n")
  out.write_string("    else\n")
  out.write_string("      local.get 250\n")
  out.write_string("    end\n")
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
test "simplify-locals sinks a single-use local.set into the later get" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 local.get 0))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals sink success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_false(pretty.contains("local.get"))
  assert_true(pretty.contains("I32(1)"))
}

///|
test "simplify-locals sinks single-use if results into later call arguments" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $pred (param i32) (result i32) local.get 0) (func $use (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i32.add i32.add) (func (param i32 i32 i32) (result i32) (local i32) local.get 2 call $pred i32.const 1 i32.eq if (result i32) i32.const 7 else i32.const 9 end local.set 3 local.get 0 local.get 1 local.get 3 call $use))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected if-result call-arg simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(pretty.contains("local.set (Local 3)"), msg=pretty)
  assert_true(pretty.contains("if I32"), msg=pretty)
}

///|
test "simplify-locals sinks pure single-use locals into later call arguments" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $side (result i32) i32.const 7) (func $use (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i32.add i32.add) (func (param i32) (result i32) (local i32) i32.const 10000 local.set 1 local.get 0 call $side local.get 1 call $use))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected pure call-arg simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("I32(10000)"), msg=pretty)
}

///|
test "simplify-locals raw structured pure-tail shortcut still sinks effectful temps" {
  let input = simplify_locals_test_make_large_structured_raw_repro()
  let trace = match pass_test_capture_trace(input, ["simplify-locals"]) {
    Ok(trace) => trace
    Err(err) =>
      fail("expected traced raw-structured simplify-locals success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals]:skip-raw reason=structured-pure-copy-call-tail",
      )
    }),
    msg=trace.to_string(),
  )

  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected raw-structured simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(pretty.contains("local.set (Local 126)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 126)"), msg=pretty)
  assert_true(pretty.contains("call (Func 1)"), msg=pretty)
}

///|
test "simplify-locals validator structured skip still sinks copied locals" {
  let input = simplify_locals_test_make_large_validator_structured_copy_repro()
  let trace = match pass_test_capture_trace(input, ["simplify-locals"]) {
    Ok(trace) => trace
    Err(err) =>
      fail(
        "expected traced validator-structured simplify-locals success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals]:skip-raw reason=validator-structured-call-heavy",
      )
    }),
    msg=trace.to_string(),
  )

  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected validator-structured simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(pretty.contains("local.set (Local 251)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 251)"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
}

///|
test "simplify-locals validator structured skip sinks copied locals across a cleanup if" {
  let input = simplify_locals_test_make_large_validator_structured_if_copy_repro()
  let trace = match pass_test_capture_trace(input, ["simplify-locals"]) {
    Ok(trace) => trace
    Err(err) =>
      fail(
        "expected traced validator-structured cleanup-if simplify-locals success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals]:skip-raw reason=validator-structured-call-heavy",
      )
    }),
    msg=trace.to_string(),
  )

  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected validator-structured cleanup-if simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(pretty.contains("local.set (Local 251)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 251)"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
}

///|
test "simplify-locals validator structured skip keeps nop when sinking condition temps" {
  let input = simplify_locals_test_make_large_validator_structured_condition_temp_repro()
  let trace = match pass_test_capture_trace(input, ["simplify-locals"]) {
    Ok(trace) => trace
    Err(err) =>
      fail(
        "expected traced validator-structured condition-temp simplify-locals success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals]:skip-raw reason=validator-structured-call-heavy",
      )
    }),
    msg=trace.to_string(),
  )

  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected validator-structured condition-temp simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(pretty.contains("local.set (Local 250)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 250)"), msg=pretty)
  assert_true(
    simplify_locals_test_count_substring(pretty, "nop") >= 2,
    msg=pretty,
  )
  assert_true(pretty.contains("if"), msg=pretty)
}

///|
test "simplify-locals validator structured skip sinks loop temps into conditions and stores" {
  let input = simplify_locals_test_make_large_validator_structured_loop_temp_repro()
  let trace = match pass_test_capture_trace(input, ["simplify-locals"]) {
    Ok(trace) => trace
    Err(err) =>
      fail(
        "expected traced validator-structured loop-temp simplify-locals success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals]:skip-raw reason=validator-structured-call-heavy",
      )
    }),
    msg=trace.to_string(),
  )

  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected validator-structured loop-temp simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_false(pretty.contains("local.set (Local 250)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 250)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 251)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 251)"), msg=pretty)
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_true(pretty.contains("nop"), msg=pretty)
}

///|
test "simplify-locals validator structured skip tees multi-use effectful temps" {
  let input = simplify_locals_test_make_large_validator_structured_multiuse_temp_repro()
  let trace = match pass_test_capture_trace(input, ["simplify-locals"]) {
    Ok(trace) => trace
    Err(err) =>
      fail(
        "expected traced validator-structured multiuse-temp simplify-locals success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals]:skip-raw reason=validator-structured-call-heavy",
      )
    }),
    msg=trace.to_string(),
  )

  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected validator-structured multiuse-temp simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("local.tee (Local 250)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 250)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 251)"), msg=pretty)
  assert_true(
    simplify_locals_test_count_substring(pretty, "nop") >= 2,
    msg=pretty,
  )
}

///|
test "simplify-locals validator structured skip sinks leading condition temps into block bodies" {
  let input = simplify_locals_test_make_large_validator_structured_leading_condition_temp_repro()
  let trace = match pass_test_capture_trace(input, ["simplify-locals"]) {
    Ok(trace) => trace
    Err(err) =>
      fail(
        "expected traced validator-structured leading-condition simplify-locals success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals]:skip-raw reason=validator-structured-call-heavy",
      )
    }),
    msg=trace.to_string(),
  )

  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected validator-structured leading-condition simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(6U))
  assert_false(pretty.contains("local.set (Local 250)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 250)"), msg=pretty)
  assert_true(
    simplify_locals_test_count_substring(pretty, "nop") >= 2,
    msg=pretty,
  )
  assert_true(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "simplify-locals validator structured skip tees block result carriers after condition sinking" {
  let input = simplify_locals_test_make_large_validator_structured_block_result_tee_repro()
  let trace = match pass_test_capture_trace(input, ["simplify-locals"]) {
    Ok(trace) => trace
    Err(err) =>
      fail(
        "expected traced validator-structured block-result tee simplify-locals success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals]:skip-raw reason=validator-structured-call-heavy",
      )
    }),
    msg=trace.to_string(),
  )

  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected validator-structured block-result tee simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(6U))
  assert_true(pretty.contains("local.tee (Local 251)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 251)"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_true(
    simplify_locals_test_count_substring(pretty, "nop") >= 2,
    msg=pretty,
  )
}

///|
test "simplify-locals validator structured skip tees if-condition carriers with later local uses" {
  let input = simplify_locals_test_make_large_validator_structured_if_condition_tee_repro()
  let trace = match pass_test_capture_trace(input, ["simplify-locals"]) {
    Ok(trace) => trace
    Err(err) =>
      fail(
        "expected traced validator-structured if-condition tee simplify-locals success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals]:skip-raw reason=validator-structured-call-heavy",
      )
    }),
    msg=trace.to_string(),
  )

  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected validator-structured if-condition tee simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(6U))
  assert_true(pretty.contains("local.tee (Local 251)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 251)"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(
    simplify_locals_test_count_substring(pretty, "nop") >= 2,
    msg=pretty,
  )
}

///|
test "simplify-locals validator structured skip rewrites copied effectful temps inside later conditions" {
  let input = simplify_locals_test_make_large_validator_structured_effectful_copy_condition_repro()
  let trace = match pass_test_capture_trace(input, ["simplify-locals"]) {
    Ok(trace) => trace
    Err(err) =>
      fail(
        "expected traced validator-structured copied-effectful-condition simplify-locals success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals]:skip-raw reason=validator-structured-call-heavy",
      )
    }),
    msg=trace.to_string(),
  )

  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected validator-structured copied-effectful-condition simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  assert_true(pretty.contains("call_indirect"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 251)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 251)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 250)"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
}

///|
test "simplify-locals validator structured skip removes returning call-tail copy shuttles" {
  let input = simplify_locals_test_make_large_validator_structured_returning_call_tail_repro()
  let trace = match pass_test_capture_trace(input, ["simplify-locals"]) {
    Ok(trace) => trace
    Err(err) =>
      fail(
        "expected traced validator-structured returning-call-tail simplify-locals success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals]:skip-raw reason=validator-structured-call-heavy",
      )
    }),
    msg=trace.to_string(),
  )

  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected validator-structured returning-call-tail simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  assert_false(pretty.contains("local.set (Local 252)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 253)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 254)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 255)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 255)"), msg=pretty)
  assert_true(pretty.contains("call (Func 3)"), msg=pretty)
  assert_true(pretty.contains("I32(10000)"), msg=pretty)
}

///|
test "simplify-locals validator structured skip removes dense pure copy fanout shuttles" {
  let input = simplify_locals_test_make_large_validator_structured_const_fanout_repro()
  let trace = match pass_test_capture_trace(input, ["simplify-locals"]) {
    Ok(trace) => trace
    Err(err) =>
      fail(
        "expected traced validator-structured const-fanout simplify-locals success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals]:skip-raw reason=validator-structured-call-heavy",
      )
    }),
    msg=trace.to_string(),
  )

  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected validator-structured const-fanout simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  assert_false(pretty.contains("local.set (Local 244)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 245)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 246)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 247)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 248)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 249)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 252)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 253)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 254)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 255)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 244)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 255)"), msg=pretty)
  assert_true(pretty.contains("call (Func 3)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 250)"), msg=pretty)
  assert_true(
    simplify_locals_test_count_substring(pretty, "nop") >= 4,
    msg=pretty,
  )
}

///|
test "simplify-locals validator structured skip removes returning dense pure copy fanout shuttles" {
  let input = simplify_locals_test_make_large_validator_structured_returning_const_fanout_repro()
  let trace = match pass_test_capture_trace(input, ["simplify-locals"]) {
    Ok(trace) => trace
    Err(err) =>
      fail(
        "expected traced validator-structured returning-const-fanout simplify-locals success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals]:skip-raw reason=validator-structured-call-heavy",
      )
    }),
    msg=trace.to_string(),
  )

  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected validator-structured returning-const-fanout simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  assert_false(pretty.contains("local.set (Local 244)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 245)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 246)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 247)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 248)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 249)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 252)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 253)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 244)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 253)"), msg=pretty)
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("call (Func 3)"), msg=pretty)
  assert_true(
    simplify_locals_test_count_substring(pretty, "nop") >= 4,
    msg=pretty,
  )
}

///|
test "simplify-locals preserves if-condition tee carriers across encode roundtrip" {
  let input = simplify_locals_test_make_large_validator_structured_if_condition_tee_repro()
  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected validator-structured if-condition tee roundtrip simplify-locals success, got \{err}",
      )
  }

  let before = optimized.pretty_print_func(@lib.FuncIdx::new(6U))
  assert_true(before.contains("local.tee (Local 251)"), msg=before)
  assert_false(before.contains("local.set (Local 251)"), msg=before)

  let encoded = match @binary.encode_module(optimized) {
    Ok(bytes) => bytes
    Err(err) =>
      fail(
        "expected validator-structured if-condition tee encode success, got \{err}",
      )
  }
  let decoded = match @binary.decode_module(encoded) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected validator-structured if-condition tee decode success, got \{err}",
      )
  }

  let after = decoded.pretty_print_func(@lib.FuncIdx::new(6U))
  assert_true(after.contains("local.tee (Local 251)"), msg=after)
  assert_false(after.contains("local.set (Local 251)"), msg=after)
}

///|
test "simplify-locals erases block-result local shuttles after exact cleanup" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $ind (func (param i32 i32) (result i32))) (func $callee (type $ind) (param i32 i32) (result i32) (i32.add (local.get 0) (local.get 1))) (func $pred (param i32) (result i32) (local.get 0)) (table 1 funcref) (elem (i32.const 0) $callee) (func (param i32 i32) (result i32) (local i32 i32) (local.set 2 (call_indirect (type $ind) (local.get 0) (local.get 1) (i32.const 0))) (local.set 3 (block (result i32) (if (result i32) (i32.eq (call $pred (local.get 2)) (i32.const 1)) (then (local.get 0)) (else (i32.const 0))))) (local.get 3)))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected exact block-result shuttle simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(pretty.contains("local.set"), msg=pretty)
  assert_true(
    simplify_locals_test_count_substring(pretty, "nop") >= 2,
    msg=pretty,
  )
  assert_true(pretty.contains("block I32"), msg=pretty)
}

///|
test "simplify-locals does not move stacked multivalue if results out of place" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $exp (param i32 i32) (result i32 i32) local.get 0 i32.const 9) (func (param i32 i32) (result i32 i32) (local i32 i32) block (result i32) local.get 0 local.get 1 call $exp local.set 2 if (result i32) local.get 2 else i32.const 0 local.get 2 return end local.set 3 i32.const 1 local.get 3 return end i32.const 0 i32.const 0))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected stacked multivalue if-result simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("local.set (Local 3)"), msg=pretty)
  assert_false(pretty.contains("call (Func 0)\n    if I32"), msg=pretty)
}

///|
test "simplify-locals does not reorder sibling call args across local writes" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $use (param i32 i32) (result i32) local.get 0 local.get 1 i32.add) (func (param i32) (result i32) (local i32 i32) local.get 0 if (result i32) i32.const 7 local.set 2 i32.const 9 else local.get 1 end local.set 1 local.get 2 local.get 1 call $use))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected sibling-arg ordering simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
}

///|
test "simplify-locals does not sink loop-carried initializers into loop headers" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) i32.const 0 local.set 1 loop local.get 1 local.get 0 i32.lt_s if local.get 1 i32.const 1 i32.add local.set 1 br 1 end end local.get 1))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected loop-carried initializer simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 1)"), msg=pretty)
}

///|
test "simplify-locals sinks a multi-use local through a tee" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 local.get 0 local.get 0 i32.add))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals tee success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_true(pretty.contains("local.tee"))
}

///|
test "simplify-locals sinks pure local writes across trapping loads with a tee" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param i32 i32 i32) (result i32) (local i64) local.get 2 if (result i32) i64.const 7 local.set 3 local.get 0 i64.load local.get 3 i64.and local.get 1 i64.load local.get 3 i64.and i64.eq else i32.const 1 end))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected trapping-load tee simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.tee (Local 3)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 3)"), msg=pretty)
}

///|
test "simplify-locals sinks trapping reads across read-only traps with a tee" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param i32) (local i32 i32) local.get 0 i32.load align=1 local.set 1 local.get 0 i32.load offset=4 align=1 local.set 2 nop local.get 0 local.tee 0 local.get 1 i32.const 4 i32.mul i32.add i32.load align=1 drop local.get 1 i32.const 1 i32.add local.set 1))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected read-only trapping tee simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.tee (Local 1)"), msg=pretty)
}

///|
test "simplify-locals preserves tee-backed copied locals for later branch uses" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func $dec (param i32)) (func (param i32) (result i32) (local i32 i32 i32) local.get 0 local.set 1 local.get 1 i32.load offset=8 align=1 local.set 2 local.get 0 i32.load align=1 local.tee 3 i32.const 1 i32.gt_s if nop else local.get 3 i32.const 1 i32.eq if local.get 1 call $dec end end local.get 2))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected tee-backed branch-use simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("local.tee (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals rewrites same-arm tee aliases back to the source local" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $t1 (func (param i32) (result i32))) (type $t0 (func (param i32))) (type $t3 (func (param i32 i32 i32) (result i32))) (import \"m\" \"get_tag\" (func $get_tag (type $t1))) (import \"m\" \"incref\" (func $incref (type $t0))) (import \"m\" \"free\" (func $free (type $t0))) (import \"m\" \"decref\" (func $decref (type $t0))) (memory 1) (func $outer (param i32 i32 i32) (result i32) (local i32 i32 i32 i32 i32 i32) nop local.get 0 local.get 1 local.get 2 call $get_tag i32.const 1 i32.eq if (result i32) local.get 2 local.tee 4 i32.load offset=8 align=1 local.set 5 local.get 4 i32.load align=1 local.tee 6 i32.const 1 i32.gt_s if nop local.get 4 local.get 6 i32.const 1 i32.sub i32.store align=1 local.get 5 if local.get 5 call $incref end else local.get 6 i32.const 1 i32.eq if local.get 4 call $free end end local.get 5 else local.get 2 call $decref i32.const 0 end call $dummy) (func $dummy (type $t3) (param i32 i32 i32) (result i32) local.get 2))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected same-arm tee-alias simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  assert_true(pretty.contains("local.tee (Local 4)"), msg=pretty)
  assert_eq(
    simplify_locals_test_count_substring(pretty, "local.get (Local 4)"),
    1,
    msg=pretty,
  )
}

///|
test "simplify-locals does not sink trapping reads across memory writes" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param i32 i32) (result i32) (local i32) local.get 0 i32.load align=1 local.set 2 local.get 1 local.get 0 i32.store align=1 local.get 2))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected trapping-write barrier simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 2)"), msg=pretty)
}

///|
test "simplify-locals drops redundant self-tee sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param i32) (result i32) local.get 0) (func (param i32 i32) (result i32) (local i32 i32) local.get 0 call 0 local.tee 2 local.set 2 loop local.get 3 local.get 0 i32.lt_s if local.get 2 local.get 3 i32.const 1 i32.shl i32.add local.get 1 i32.store16 offset=8 local.get 3 i32.const 1 i32.add local.set 3 br 1 end end local.get 2))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected self-tee simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 2)"), msg=pretty)
}

///|
test "simplify-locals keeps multivalue local-set producers out of tee rewrites" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32 i32) (result i32 i32 i32) local.get 0 local.get 1 local.get 2) (func (param i32 i32 i32) (result i32) (local i32 i32 i32) local.get 0 local.get 1 local.get 2 call 0 local.set 5 local.set 4 local.set 3 local.get 3 local.get 3 i32.add))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected multivalue producer simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 3)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 3)"), msg=pretty)
}

///|
test "simplify-locals rewrites dead local.set roots" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 i32.const 7))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_true(pretty.contains("nop"))
  assert_false(pretty.contains("drop"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "simplify-locals rewrites dead local.tee roots" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.tee 0 drop i32.const 7))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"))
  assert_true(pretty.contains("nop"))
  assert_false(pretty.contains("drop"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "simplify-locals drops dead copied local.tee stores after writeback" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $id (param i32) (result i32) local.get 0) (func (result i32) (local i32 i32) i32.const 7 local.tee 1 local.set 0 local.get 0 call $id))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected copied-tee simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("Local 1"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "simplify-locals drops dead lowered call-result temps in conditions" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $f (param i32) (result i32) local.get 0) (func (param i32) (result i32) (local i32) local.get 0 call $f local.set 1 local.get 1 i32.const 0 i32.gt_s if (result i32) i32.const 1 else i32.const 0 end))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected condition-temp simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("i32.gt_s"), msg=pretty)
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 1)"), msg=pretty)
}

///|
test "simplify-locals removes overwritten pending local sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 i32.const 2 local.set 0 local.get 0))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected overwritten-set simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_false(pretty.contains("local.get"))
  assert_true(pretty.contains("drop"))
  assert_true(pretty.contains("I32(1)"))
  assert_true(pretty.contains("I32(2)"))
}

///|
test "simplify-locals keeps overwritten dead tee values as drops before the final dead write" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) i32.const 34 local.tee 0 drop i32.const 854 local.tee 0 drop))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected dead-tee overwrite simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(34)"), msg=pretty)
  assert_false(pretty.contains("I32(854)"), msg=pretty)
}

///|
test "simplify-locals sinks through empty linear block wrappers" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 80 local.set 0 block nop end local.get 0))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected empty-block simplify-locals sink success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("I32(80)"), msg=pretty)
}

///|
test "simplify-locals does not sink value reads across later writes to the source local" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) local.get 1 local.set 2 i32.const 9 local.set 1 local.get 2))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected source-local ordering simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
}

///|
test "simplify-locals does not sink captured local values past later writes" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) local.get 1 local.set 2 i32.const 7 local.set 1 local.get 2))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected local-conflict simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals keeps pending sinks across unrelated local traffic" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) i32.const 5 local.set 2 local.get 0 drop local.get 2))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected unrelated-local simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_true(pretty.contains("I32(5)"), msg=pretty)
}

///|
test "simplify-locals canonicalizes equivalent copies across adjacent blocks" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) block local.get 0 local.set 1 end local.get 1 local.get 0 i32.add))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected equivalent-copy simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("local.get 1"), msg=pretty)
}

///|
test "simplify-locals collapses drop of a sunk tee back into a set" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 local.get 0 drop local.get 0))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals drop-tee collapse success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_false(pretty.contains("local.tee"))
  assert_true(pretty.contains("I32(1)"))
}

///|
test "simplify-locals removes unreachable dead local defs outside the ssa overlay" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) block unreachable i32.const 1 local.set 0 end i32.const 7))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected unreachable dead-def simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "simplify-locals lifts matching block exits into a block result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) block $exit local.get 0 if i32.const 1 local.set 1 br $exit end i32.const 2 local.set 1 end local.get 1))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected block-return simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("block I32"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(2)"), msg=pretty)
}

///|
test "simplify-locals lifts block returns past live intervening local sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) block $exit local.get 0 if i32.const 7 local.set 1 i32.const 9 local.set 2 br $exit end i32.const 5 local.set 1 i32.const 11 local.set 2 end local.get 1 local.get 2 i32.add))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected intervening-set block-return simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 2)"), msg=pretty)
}

///|
test "simplify-locals lifts if-else local writes into an if result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected if-return simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(2)"), msg=pretty)
}

///|
test "simplify-locals keeps later reads alive when lifting if results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1 local.get 1 i32.add))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected multi-read if-return simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
}

///|
test "simplify-locals lifts reachable if-else arms even when the other arm is unreachable" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if unreachable else i32.const 9 local.set 1 end local.get 1))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected unreachable-arm simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "simplify-locals lifts one-armed if writes for defaultable locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 end local.get 1))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected one-armed simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "simplify-locals preserves then-arm nop when lifting one-armed if writes" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 42 local.set 1 end local.get 1 i32.const 1 i32.add local.set 1 local.get 1))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected one-armed nop-preserving simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("if I32 nop"), msg=pretty)
  assert_true(pretty.contains("I32(42)"), msg=pretty)
}

///|
test "simplify-locals keeps live then-arm roots when lifting one-armed if writes" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func $use (param i32 i32)) (func (param i32 i32) (result i32) (local i32) local.get 0 if local.get 0 local.get 1 call $use local.get 1 i32.const 0 i32.store local.get 1 i32.load local.set 2 end local.get 2))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected live-root one-armed simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
}

///|
test "simplify-locals lifts nested one-armed if writes inside consumed result ifs" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) local.get 0 i32.const 256 i32.lt_u if (result i32) local.get 0 local.set 1 i32.const 0 else local.get 0 i32.const 10 i32.lt_u if local.get 0 i32.const 1 i32.add local.set 1 end nop local.get 1 local.get 0 i32.shr_u local.set 1 local.get 0 end local.tee 2 local.get 0 i32.add))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested consumed-result one-armed simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("local.tee (Local 1)"), msg=pretty)
}

///|
test "simplify-locals skips one-armed if lifting for non-defaultable locals" {
  let non_defaultable = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::func())),
  )
  let nullable = @lib.ValType::funcref()
  let probe = @ir.HotFunc::new()
  let body_result_type = @ir.hot_type_intern_value(probe, non_defaultable)
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[
      @lib.ValType::i32(),
      non_defaultable,
      nullable,
    ]),
    body_result_type~,
  )
  ignore(@ir.hot_type_intern_value(func, non_defaultable))
  let condition = @ir.hot_build_local_get(func, 0)
  let lifted = @ir.hot_build_heap(
    func,
    [non_defaultable],
    @lib.Instruction::ref_as_non_null(),
    [@ir.hot_build_local_get(func, 2)],
  )
  let set = @ir.hot_build_local_set(func, 1, lifted)
  let if_id = @ir.hot_build_if(func, @lib.BlockType::void_(), condition, [set])
  @ir.hot_root_append(func, if_id)
  @ir.hot_root_append(func, @ir.hot_build_local_get(func, 1))
  let ctx = HotPassContext::new(
    simplify_locals_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected non-defaultable one-armed simplify-locals success, got \{err}",
      )
  }

  assert_eq(@ir.hot_root_count(func), 2)
  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::If => ()
    _ => fail("expected non-defaultable if to stay as a plain if root")
  }
  let then_region = @ir.hot_region_then_ref(func, @ir.hot_root_get(func, 0))
  match @ir.hot_node_get(func, @ir.hot_region_get(func, then_region, 0)).op {
    @ir.HotOp::LocalSet => ()
    _ => fail("expected non-defaultable then arm to keep the local.set")
  }
  match @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected trailing local.get to remain after the if")
  }
}

///|
test "simplify-locals lifts loop tail writes across the loop fallthrough" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) loop i32.const 9 local.set 0 end local.get 0))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected loop simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("loop"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "simplify-locals keeps shared tee children that remain referenced" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let shared = @ir.hot_build_const_i32(func, @lib.I32(1))
  let tee = @ir.hot_build_local_tee(func, 0, shared)
  let drop_tee = @ir.hot_build_drop(func, tee)
  let drop_shared = @ir.hot_build_drop(func, shared)
  @ir.hot_root_append(func, drop_tee)
  @ir.hot_root_append(func, drop_shared)
  let ctx = HotPassContext::new(
    simplify_locals_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected simplify-locals shared-child success, got \{err}")
  }

  assert_true(@ir.hot_node_is_live(func, shared))
}

///|
test "simplify-locals rehomes dead tee control labels before cleanup" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let carried_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
  )
  let carried_label = @ir.hot_control_node_label(func, carried_block)
  let tee = @ir.hot_build_local_tee(func, 0, carried_block)
  let drop_tee = @ir.hot_build_drop(func, tee)
  @ir.hot_root_append(func, drop_tee)
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(7)))
  let ctx = HotPassContext::new(
    simplify_locals_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected simplify-locals dead-tee control success, got \{err}")
  }

  match @ir.hot_node_get(func, tee).op {
    @ir.HotOp::Block => ()
    other => fail("expected tee slot to become a block, got \{other}")
  }
  assert_eq(@ir.hot_control_node_label(func, tee), carried_label)
  assert_eq(@ir.hot_label_owner(func, carried_label), tee)
  assert_false(@ir.hot_node_is_live(func, carried_block))
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected simplify-locals dead-tee control verify success, got \{err}",
      )
  }
}

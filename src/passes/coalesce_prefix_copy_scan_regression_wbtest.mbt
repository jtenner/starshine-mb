///|
fn cl_prefix_copy_scan_fixture(count : Int32) -> Array[@lib.Instruction] {
  let body : Array[@lib.Instruction] = []
  for dest in 1..<(count + 1) {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(dest.to_uint())))
  }
  body.push(
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new([])),
  )
  body
}

///|
test "coalesce prefix aliases do not rescan suffixes for immutable sources" {
  let body = cl_prefix_copy_scan_fixture(24)
  let gets = Array::make(25, 0)
  let sets = Array::make(25, 0)
  let tees = Array::make(25, 0)
  cl_count_syntactic_local_accesses(body, gets, sets, tees)
  let aliases = Array::make(25, -1)
  let visits = [0]
  cl_mark_loop_prefix_copy_aliases(
    body,
    aliases,
    sets,
    tees,
    Array::make(25, @lib.ValType::i32()),
    suffix_queries=Some(visits),
  )
  assert_eq(aliases[0], -1)
  for dest in 1..<25 {
    assert_eq(aliases[dest], 0)
  }
  assert_eq(body, cl_prefix_copy_scan_fixture(24))
  // Existing whole-body counts prove no source write exists, including nested
  // loops and handlers. Work must stay linear in this repeated-source prefix.
  assert_eq(visits[0], 0)
}

///|
// Frozen prefix admission, before the count-based source and destination gate.
fn cl_prefix_copy_scan_reference(
  instrs : Array[@lib.Instruction],
  alias_source : Array[Int32],
  sets : Array[Int32],
  tees : Array[Int32],
  types : Array[@lib.ValType],
) -> Unit {
  let seen = Array::make(types.length(), false)
  let mut idx = 0
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.Block(_, _)
      | @lib.Loop(_, _)
      | @lib.If(_, _, _)
      | @lib.Try(_, _, _, _)
      | @lib.TryTable(_, _, _)
      | @lib.Br(_)
      | @lib.BrIf(_)
      | @lib.BrTable(_, _) => return
      @lib.LocalGet(source_idx) if idx + 1 < instrs.length() => {
        let source = cl_local_idx_raw(source_idx)
        match instrs[idx + 1] {
          @lib.LocalSet(dest_idx) => {
            let dest = cl_local_idx_raw(dest_idx)
            if source >= 0 &&
              source < types.length() &&
              dest >= 0 &&
              dest < types.length() &&
              source != dest &&
              !seen[dest] &&
              types[source] == types[dest] &&
              !cl_instrs_suffix_writes_local(instrs, idx + 2, source) &&
              sets[dest] == 1 &&
              tees[dest] == 0 {
              alias_source[dest] = source
            }
            if source >= 0 && source < seen.length() {
              seen[source] = true
            }
            if dest >= 0 && dest < seen.length() {
              seen[dest] = true
            }
            idx += 1
          }
          _ => if source >= 0 && source < seen.length() { seen[source] = true }
        }
      }
      @lib.LocalSet(local_idx) | @lib.LocalTee(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < seen.length() {
          seen[raw] = true
        }
      }
      _ => ()
    }
    idx += 1
  }
}

///|
test "coalesce prefix aliases reject multiply written destinations without suffix scans" {
  let body = cl_prefix_copy_scan_fixture(16)
  for dest in 1..<17 {
    body.push(@lib.Instruction::i32_const(@lib.I32(9)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(dest.to_uint())))
  }
  // Keep the source mutable so only the destination-count gate can avoid the
  // query. A source overwrite is after the stopped prefix's loop boundary.
  body.push(@lib.Instruction::i32_const(@lib.I32(11)))
  body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  let gets = Array::make(17, 0)
  let sets = Array::make(17, 0)
  let tees = Array::make(17, 0)
  cl_count_syntactic_local_accesses(body, gets, sets, tees)
  let aliases = Array::make(17, -1)
  let visits = [0]
  cl_mark_loop_prefix_copy_aliases(
    body,
    aliases,
    sets,
    tees,
    Array::make(17, @lib.ValType::i32()),
    suffix_queries=Some(visits),
  )
  assert_eq(aliases, Array::make(17, -1))
  assert_eq(visits[0], 0)
}

///|
test "coalesce prefix count admission matches frozen scans across writes and control boundaries" {
  let fixtures = [
    "(module (func (param i32) (local i32) local.get 0 local.set 1 loop end local.get 1 drop))",
    "(module (func (param i64) (local i64) local.get 0 local.set 1 loop end local.get 1 drop))",
    "(module (func (param externref) (local externref) local.get 0 local.set 1 loop end local.get 1 drop))",
    "(module (func (param i32) (local i32) i32.const 3 local.set 0 local.get 0 local.set 1 loop end local.get 1 drop))",
    "(module (func (param i32) (local i32) i32.const 3 local.tee 0 drop local.get 0 local.set 1 loop end local.get 1 drop))",
    "(module (func (param i32) (local i32) local.get 0 local.set 1 i32.const 3 local.set 0 loop end local.get 1 drop))",
    "(module (func (param i32) (local i32) local.get 0 local.set 1 i32.const 3 local.tee 0 drop loop end local.get 1 drop))",
    "(module (func (param i32) (local i32) local.get 0 local.set 1 loop i32.const 3 local.set 0 end local.get 1 drop))",
    "(module (func (param i32) (local i32) local.get 0 local.set 1 block i32.const 3 local.set 0 end local.get 1 drop))",
    "(module (func (param i32) (local i32) local.get 0 local.set 1 local.get 0 if i32.const 3 local.set 0 else nop end local.get 1 drop))",
    "(module (func (param i32) (local i32) local.get 0 local.set 1 local.get 0 if nop else i32.const 3 local.set 0 end local.get 1 drop))",
    "(module (tag) (func (param i32) (local i32) local.get 0 local.set 1 block try_table (catch_all 0) i32.const 3 local.set 0 end end local.get 1 drop))",
    "(module (tag) (func (param i32) (local i32) local.get 0 local.set 1 (try (do nop) (catch_all i32.const 3 local.set 0)) local.get 1 drop))",
    "(module (func (param i32) (local i32) local.get 0 local.set 1 loop end i32.const 9 local.set 1 local.get 1 drop))",
    "(module (func (param i32) (local i32) local.get 0 local.set 1 loop end i32.const 9 local.tee 1 drop local.get 1 drop))",
    "(module (func (param i32) (local i32) local.get 1 drop local.get 0 local.set 1 loop end local.get 1 drop))",
    "(module (func (param i32) (local i32) loop end local.get 0 local.set 1 local.get 1 drop))",
    "(module (func (param i32) (local i32 i32) local.get 0 local.set 1 local.get 1 local.set 2 loop end local.get 2 drop))",
    "(module (func (param i32) (local i32) local.get 0 local.set 0 loop end))",
  ]
  for wat in fixtures {
    let input = pass_test_module_from_wat(wat)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let context = @ir.hot_module_context_from_module(input)
    let @lib.FuncType(params, _) = context.func_types[0]
    let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let types = cl_all_local_types(params, locals)
    let gets = Array::make(types.length(), 0)
    let sets = Array::make(types.length(), 0)
    let tees = Array::make(types.length(), 0)
    cl_count_syntactic_local_accesses(body, gets, sets, tees)
    let expected = Array::make(types.length(), -1)
    let actual = Array::make(types.length(), -1)
    cl_prefix_copy_scan_reference(body, expected, sets, tees, types)
    cl_mark_loop_prefix_copy_aliases(body, actual, sets, tees, types)
    assert_eq(actual, expected)
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "coalesce-locals",
    ]).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "coalesce prefix aliases reject an intentionally invalid cross-type copy" {
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let aliases = [-1, -1]
  cl_mark_loop_prefix_copy_aliases(body, aliases, [0, 1], [0, 0], [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
  ])
  assert_eq(aliases, [-1, -1])
}

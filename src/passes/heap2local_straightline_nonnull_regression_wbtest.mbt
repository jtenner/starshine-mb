///|
fn h2l_straightline_nonnull_source(
  second_fields~ : String = "(local.get $replacement) (struct.get $S 0 (local.get $owner)) (struct.get $S 1 (local.get $owner))",
  with_mark~ : Bool = false,
) -> String {
  "(module (type $Box (struct (field i32))) " +
  "(type $S (struct (field (ref $Box)) (field (ref $Box)) (field (ref $Box)))) " +
  (if with_mark {
    "(import \"env\" \"mark\" (func $mark (param (ref $Box)) (result (ref $Box)))) "
  } else {
    ""
  }) +
  "(func (export \"run\") (param $a (ref $Box)) (param $b (ref $Box)) " +
  "(param $c (ref $Box)) (param $replacement (ref $Box)) " +
  "(result (ref $Box) (ref $Box) (ref $Box)) (local $owner (ref null $S)) " +
  "(local.set $owner (struct.new $S (local.get $a) (local.get $b) (local.get $c))) " +
  "(local.set $owner (struct.new $S " +
  second_fields +
  ")) " +
  "(struct.get $S 0 (local.get $owner)) (struct.get $S 1 (local.get $owner)) " +
  "(struct.get $S 2 (local.get $owner))))"
}

///|
// Positive values identify distinct non-null reference arguments. Owner objects
// use separate ids; every unsupported opcode and every null assertion fails.
fn h2l_straightline_nonnull_values(
  mod_ : @lib.Module,
  args : Array[Int32],
  events~ : Array[Int32]? = None,
) -> Array[Int32] raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
  let locals = Array::make(args.length() + body_locals.length(), 0)
  for index in 0..<args.length() {
    locals[index] = args[index]
  }
  let objects : Array[Array[Int32]] = []
  let stack : Array[Int32] = []
  let mut steps = 0
  fn execute(instrs : Array[@lib.Instruction]) -> Unit raise {
    for instr in instrs {
      steps += 1
      assert_true(steps <= 256)
      match instr {
        @lib.Nop => ()
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          stack.push(locals[index.to_int()])
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack[stack.length() - 1]
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.RefNull(_) => stack.push(0)
        @lib.RefAsNonNull =>
          assert_true(
            stack[stack.length() - 1] != 0,
            msg="cleanup read an uninitialized non-null field",
          )
        @lib.Call(index) => {
          assert_eq(index, @lib.FuncIdx::new(0U))
          match events {
            Some(events) => events.push(stack[stack.length() - 1])
            None => fail("reference mark requires an observation array")
          }
        }
        @lib.StructNew(_) => {
          let fields = Array::make(3, 0)
          for field = 2; field >= 0; field = field - 1 {
            fields[field] = stack.pop().unwrap()
          }
          objects.push(fields)
          stack.push(99 + objects.length())
        }
        @lib.StructGet(_, @lib.U32(field)) => {
          let reference = stack.pop().unwrap()
          assert_true(reference >= 100 && reference < 100 + objects.length())
          stack.push(objects[reference - 100][field.to_int()])
        }
        @lib.Block(_, @lib.Expr(nested)) => execute(nested)
        _ => fail("unexpected straight-line reference instruction: \{instr}")
      }
    }
  }
  execute(body)
  stack
}

///|
test "heap2local straight-line non-null old reads survive local cleanup" {
  let input = pass_test_module_from_wat(h2l_straightline_nonnull_source())
  for
    passes in [
      ["heap2local"],
      ["heap2local", "simplify-locals"],
      ["heap2local", "simplify-locals", "coalesce-locals", "vacuum"],
    ] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), passes).unwrap()
    assert_true(@validate.validate_module(output) is Ok(_))
    for args in [[1, 2, 3, 4], [4, 1, 2, 3], [2, 2, 3, 4]] {
      let expected = [args[3], args[0], args[1]]
      @debug.assert_eq(h2l_straightline_nonnull_values(input, args), expected)
      @debug.assert_eq(h2l_straightline_nonnull_values(output, args), expected)
    }
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    fn heap_ops(instrs : Array[@lib.Instruction]) -> Int32 {
      let mut count = 0
      for instr in instrs {
        match instr {
          @lib.StructNew(_) | @lib.StructGet(_, _) => count += 1
          @lib.Block(_, @lib.Expr(nested)) => count += heap_ops(nested)
          _ => ()
        }
      }
      count
    }
    @debug.assert_eq(heap_ops(body), 0)
  }
}

///|
test "heap2local scalar field blocks retain one live control owner" {
  let input = pass_test_module_from_wat(h2l_straightline_nonnull_source())
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    heap2local_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(input)),
  )
  ignore(heap2local_run(ctx, func))
  let reachable = simplify_locals_build_reachable_nodes(func)
  for node_id in 0..<@ir.hot_node_count(func) {
    if !reachable[node_id] || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if @ir.hot_node_kind_is_control(func, node_id) {
      let label = @ir.hot_control_node_label(func, node_id)
      assert_eq(@ir.hot_label_owner(func, label), node_id)
    }
  }
}

///|
test "heap2local non-null field cycles preserve reference snapshots through cleanup" {
  let input = pass_test_module_from_wat(
    h2l_straightline_nonnull_source(
      second_fields="(struct.get $S 1 (local.get $owner)) (struct.get $S 2 (local.get $owner)) (struct.get $S 0 (local.get $owner))",
    ),
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "heap2local", "simplify-locals", "coalesce-locals", "vacuum",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  for args in [[1, 2, 3, 4], [4, 1, 2, 3], [2, 2, 3, 4], [2, 2, 2, 2]] {
    let expected = [args[1], args[2], args[0]]
    assert_eq(h2l_straightline_nonnull_values(input, args), expected)
    assert_eq(h2l_straightline_nonnull_values(decoded, args), expected)
  }
}

///|
test "heap2local non-null old-field operands run once in order through cleanup" {
  let input = pass_test_module_from_wat(
    h2l_straightline_nonnull_source(
      second_fields="(call $mark (local.get $replacement)) (call $mark (struct.get $S 0 (local.get $owner))) (call $mark (struct.get $S 1 (local.get $owner)))",
      with_mark=true,
    ),
  )
  for
    passes in [
      ["heap2local", "simplify-locals"],
      ["heap2local", "simplify-locals", "coalesce-locals", "vacuum"],
    ] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), passes).unwrap()
    ignore(@validate.validate_module(output).unwrap())
    for args in [[1, 2, 3, 4], [4, 1, 2, 3], [2, 2, 3, 4], [2, 2, 2, 2]] {
      let expected = [args[3], args[0], args[1]]
      for mod_ in [input, output] {
        let events : Array[Int32] = []
        assert_eq(
          h2l_straightline_nonnull_values(mod_, args, events=Some(events)),
          expected,
        )
        assert_eq(events, expected)
      }
    }
  }
}

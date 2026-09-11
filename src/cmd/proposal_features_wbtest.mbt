///|
fn cmd_proposal_fixture(order : @lib.AtomicOrder) -> Module {
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::atomic_fence(order~)]),
      ),
    ]),
  )
}

///|
test "cmd proposal feature flags distinguish atomic drafts and check copy-only inputs" {
  for
    entry in [
      (
        @lib.AtomicOrder::acq_rel(),
        ["--disable-relaxed-atomics", "--enable-acquire-release-atomics"],
        true,
      ),
      (
        @lib.AtomicOrder::relaxed(),
        ["--disable-acquire-release-atomics", "--enable-relaxed-atomics"],
        true,
      ),
      (@lib.AtomicOrder::relaxed(), ["--disable-relaxed-atomics"], false),
      (
        @lib.AtomicOrder::acq_rel(),
        ["--disable-acquire-release-atomics"],
        false,
      ),
      (
        @lib.AtomicOrder::relaxed(),
        ["--disable-relaxed-atomics", "--all-features"],
        true,
      ),
    ] {
    let (order, flags, accepted) = entry
    let input = encode_module(cmd_proposal_fixture(order)).unwrap()
    let writes : Array[Bytes] = []
    let io = CmdIO::new(read_file=fn(_) { Ok(input) }, write_file=fn(_, bytes) {
      writes.push(bytes)
      Ok(())
    })
    let args = ["input.wasm", "-o", "output.wasm"]
    args.append(flags)
    match run_cmd_with_adapter(args, io) {
      Ok(_) => assert_true(accepted)
      Err(err) => {
        assert_false(accepted)
        assert_true(err.to_string().contains("disabled feature"))
      }
    }
    @debug.assert_eq(writes.length(), if accepted { 1 } else { 0 })
  }
}

///|
test "runtime interface feature inference distinguishes the new atomic orders" {
  for
    entry in [
      (@lib.AtomicOrder::acq_rel(), "acquire-release-atomics"),
      (@lib.AtomicOrder::relaxed(), "relaxed-atomics"),
    ] {
    let (order, name) = entry
    let report = cmd_optimizer_runtime_interface_report_json(
      cmd_proposal_fixture(order),
    )
    assert_true(report.contains("\"features\":[\"" + name + "\"]"))
  }
}

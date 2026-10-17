///|
test "O4z caught command portfolio remains restricted to pure wasm presets" {
  for requested in [["optimize"], ["shrink"], ["optimize", "shrink"]] {
    assert_true(
      cmd_o4z_size_portfolio_enabled(CliInputFormat::wasm(), 4, 4, requested),
    )
  }
  for
    requested in [
      [],
      ["precompute"],
      ["optimize", "strip-debug"],
      ["strip-debug", "shrink"],
    ] {
    assert_false(
      cmd_o4z_size_portfolio_enabled(CliInputFormat::wasm(), 4, 4, requested),
    )
  }
  assert_false(
    cmd_o4z_size_portfolio_enabled(CliInputFormat::wasm(), 3, 4, ["optimize"]),
  )
  assert_false(
    cmd_o4z_size_portfolio_enabled(CliInputFormat::wasm(), 4, 3, ["optimize"]),
  )
  assert_false(
    cmd_o4z_size_portfolio_enabled(CliInputFormat::wat(), 4, 4, ["optimize"]),
  )
}

///|
test "O4z command boundary sees caught nested handlers and excludes uncaught try tables" {
  let tag = @lib.TagIdx::new(0U)
  let caught = @lib.Instruction::try_table(
    @lib.BlockType::void_(),
    [@lib.Catch::all(@lib.LabelIdx::new(0U))],
    @lib.Expr::new([@lib.Instruction::throw_(tag)]),
  )
  assert_true(cmd_instrs_have_caught_try_table([caught]))
  assert_true(
    cmd_instrs_have_caught_try_table([
      @lib.Instruction::try_(@lib.BlockType::void_(), @lib.Expr::new([]), [
        @lib.LegacyCatch::all(
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([caught]),
            ),
          ]),
        ),
      ]),
    ]),
  )
  assert_false(
    cmd_instrs_have_caught_try_table([
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [],
        @lib.Expr::new([@lib.Instruction::throw_(tag)]),
      ),
    ]),
  )
}

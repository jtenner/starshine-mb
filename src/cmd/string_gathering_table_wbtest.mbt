///|
test "dispatcher string-gathering preserves imported table initializer references" {
  let input = @passes.pass_test_module_from_wat(
    (
      #| (module
      #|   (import "env" "ref" (global funcref))
      #|   (global funcref (ref.null func))
      #|   (func (result stringref) (string.const "body")))
    ),
  ).with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::abs(@lib.AbsHeapType::func()),
          @lib.Limits::i32(1U, None),
        ),
        Some(
          @lib.Expr::new([@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))]),
        ),
      ),
    ]),
  )
  @validate.validate_module(input).unwrap()
  let wasm = encode_module_bytes(input)
  let writes : Array[Bytes] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tables.wasm"] },
    file_exists=fn(path) { path == "tables.wasm" },
    read_file=fn(path) {
      if path == "tables.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, bytes) {
      writes.push(bytes)
      Ok(())
    },
  )
  let summary = run_cmd_with_adapter(
    ["--string-gathering", "--out", "out.wasm", "tables.wasm"],
    io,
  ).unwrap()
  @debug.assert_eq(summary.resolved_passes, ["string-gathering"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0])
  @validate.validate_module(optimized).unwrap()
  @debug.assert_eq(optimized.table_sec, input.table_sec)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
      ])
    other =>
      fail("expected gathered function body, got \{@debug.to_string(other)}")
  }
}

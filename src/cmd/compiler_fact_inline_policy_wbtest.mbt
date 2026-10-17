///|
fn cmd_compiler_fact_never_inline_fixture() -> @lib.Module {
  @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (func $tiny (result i32)
      #|    i32.const 7)
      #|  (func (export "run") (result i32)
      #|    call $tiny))
    ),
  ).with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(functions=[
        @representation.FunctionFacts::new(
          0U,
          inline_policy=Some(@representation.InlinePolicy::never()),
        ),
      ]),
    ),
  )
}

///|
test "command forwards trusted compiler fact inline policy to inlining" {
  let input_bytes = encode_module_bytes(
    cmd_compiler_fact_never_inline_fixture(),
  )
  for policy in ["ignore", "hints", "trust"] {
    let writes : Array[Bytes] = []
    let io = CmdIO::new(
      list_candidates=fn() { ["inline-policy.wasm"] },
      file_exists=fn(path) { path == "inline-policy.wasm" },
      read_file=fn(path) {
        if path == "inline-policy.wasm" {
          Ok(input_bytes)
        } else {
          Err("missing input")
        }
      },
      write_file=fn(path, bytes) {
        if path == "out.wasm" {
          writes.push(bytes)
          Ok(())
        } else {
          Err("unexpected output path")
        }
      },
    )
    let summary = run_cmd_with_adapter(
      [
        "--inlining", "--compiler-facts", policy, "--out", "out.wasm", "inline-policy.wasm",
      ],
      io,
    ).unwrap()
    assert_eq(summary.resolved_passes, ["inlining"])
    assert_eq(writes.length(), 1)
    let output = decode_module_bytes(writes[0])
    ignore(@validate.validate_module(output).unwrap())
    let @lib.FuncSec(type_indices) = output.func_sec.unwrap()
    if policy == "trust" || policy == "hints" {
      assert_eq(type_indices.length(), 2)
      if policy == "trust" {
        assert_eq(output.compiler_fact_custom_section, None)
      }
      let rendered = output.pretty_print_defined_func(1U)
      assert_true(rendered.contains("call (Func 0)"), msg=rendered)
    } else {
      assert_eq(type_indices.length(), 1)
    }
  }
}

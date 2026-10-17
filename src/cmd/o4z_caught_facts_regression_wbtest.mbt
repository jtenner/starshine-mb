///|
fn cmd_o4z_caught_fact_fixture() -> @lib.Module {
  @passes.pass_test_module_from_wat(
    "(module (tag $e) (func $producer (result i32) i32.const 7) (func (export \"run\") (result i32) call $producer i32.const 7 i32.eq) (func (block $handler (try_table (catch_all $handler) (throw $e)))))",
  ).with_name_sec(
    @lib.NameSec::new(
      module_name=Some(@lib.Name::from_string("prepared-input")),
    ),
  )
}

///|
fn cmd_o4z_caught_value_fact(module_ : @lib.Module) -> @lib.Module {
  let sites = @binary.compiler_fact_module_opcode_sites(module_).unwrap()[1]
  let mut call_offset = None
  for site in sites {
    if site.1 is @lib.Call(_) {
      call_offset = Some(site.0)
      break
    }
  }
  module_.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(bodies=[
        @representation.FunctionBodyFacts::new(1U, sites=[
          @representation.ExpressionFact::new(
            @representation.ValueSite::new(
              @representation.CodeSite::new(1U, call_offset.unwrap()),
            ),
            @representation.ValueFacts::exact_value(
              @representation.FactValue::integer(
                @representation.IntConstant::new(
                  @representation.IntWidth::i32(),
                  7UL,
                ),
              ),
            ),
          ),
        ]),
      ]),
    ),
  )
}

///|
test "command caught O4z boundary retains trusted fact preparation" {
  let input = cmd_o4z_caught_value_fact(cmd_o4z_caught_fact_fixture())
  let input_bytes = encode_module_bytes(input)
  for policy in ["ignore", "hints", "trust"] {
    let writes : Array[Bytes] = []
    let io = CmdIO::new(
      list_candidates=fn() { ["caught.wasm"] },
      file_exists=fn(path) { path == "caught.wasm" },
      read_file=fn(path) {
        if path == "caught.wasm" {
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
    ignore(
      run_cmd_with_adapter(
        ["-O4z", "--compiler-facts", policy, "--out", "out.wasm", "caught.wasm"],
        io,
      ).unwrap(),
    )
    assert_eq(writes.length(), 1)
    let output = decode_module_bytes(writes[0])
    ignore(@validate.validate_module(output).unwrap())
    if policy == "trust" {
      assert_true(output.compiler_fact_custom_section is None)
      let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
      assert_false(body.any(instr => instr is @lib.I32Eq))
      assert_true(body.contains(@lib.Instruction::i32_const(1)))
      assert_true(body.contains(@lib.Instruction::call(@lib.FuncIdx::new(0U))))
    } else {
      assert_eq(writes[0], input_bytes)
    }
  }
}

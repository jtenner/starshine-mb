///|
test "Binaryen 132 grouped text imports retain logical function indices" {
  let sources = [
    "(module (import \"m\" (item $a \"a\" (func)) (item $b \"b\" (func))) (func (call $b) (call $a)))",
    "(module (import \"m\" (item \"a\") (item \"b\") (func)) (func (call 1) (call 0)))",
  ]
  for source in sources {
    let mod_ = match wast_to_binary_module(source) {
      Ok(value) => value
      Err(err) => fail("expected compact text imports: \{err}")
    }
    match mod_.import_sec {
      Some(@lib.ImportSec(imports)) => {
        assert_eq(imports.length(), 2)
        match (imports[0], imports[1]) {
          (@lib.Import(module_a, name_a, _), @lib.Import(module_b, name_b, _)) => {
            @debug.assert_eq(module_a, @lib.Name::new("m"))
            @debug.assert_eq(module_b, @lib.Name::new("m"))
            @debug.assert_eq(name_a, @lib.Name::new("a"))
            @debug.assert_eq(name_b, @lib.Name::new("b"))
          }
        }
      }
      _ => fail("expected flattened imports")
    }
    match mod_.code_sec {
      Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
        @debug.assert_eq(body, [
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        ])
      _ => fail("expected one body")
    }
  }
}

///|
test "Binaryen 132 mixed compact imports preserve each resource index space" {
  let source =
    #|(module
    #|  (import "m"
    #|    (item $g "g" (global i32))
    #|    (item $f "f" (func))
    #|    (item $t "t" (table 1 funcref))
    #|    (item $mem "mem" (memory 1))
    #|    (item $tag "tag" (tag)))
    #|  (export "g" (global $g))
    #|  (export "f" (func $f))
    #|  (export "t" (table $t))
    #|  (export "mem" (memory $mem))
    #|  (export "tag" (tag $tag)))
  let mod_ = match wast_to_binary_module(source) {
    Ok(value) => value
    Err(err) => fail("expected grouped resource imports: \{err}")
  }
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) => {
      assert_eq(imports.length(), 5)
      for i, name in ["g", "f", "t", "mem", "tag"] {
        let @lib.Import(_, actual, _) = imports[i]
        @debug.assert_eq(actual, @lib.Name::new(name))
      }
    }
    _ => fail("expected imports")
  }
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) => {
      let expected = [
        @lib.ExternIdx::global(@lib.GlobalIdx::new(0U)),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        @lib.ExternIdx::table(@lib.TableIdx::new(0U)),
        @lib.ExternIdx::mem(@lib.MemIdx::new(0U)),
        @lib.ExternIdx::tag(@lib.TagIdx::new(0U)),
      ]
      assert_eq(exports.length(), expected.length())
      for i, ex in exports {
        let @lib.Export(_, desc) = ex
        @debug.assert_eq(desc, expected[i])
      }
    }
    _ => fail("expected exports")
  }
}

///|
test "Binaryen 132 compact text rejects intentionally invalid mixed and misplaced descriptors" {
  let invalid = [
    "(module (import \"m\" (item \"a\" (func)) (item \"b\") (func)))", "(module (import \"m\" (item \"a\")))",
    "(module (import \"m\" (item \"a\" (func $misplaced))))", "(module (import \"m\" (item \"a\") (func $misplaced)))",
  ]
  for source in invalid {
    assert_true(wast_to_binary_module(source) is Err(_))
  }
}

///|
test "Binaryen 132 compact declarations resolve forward types and preserve item name mapping" {
  for
    declaration in [
      "(import \"m\" (item $first \"first\" (func (type $signature))) (item $second \"second\" (func (type $signature))))",
      "(import \"m\" (item $first \"first\") (item $second \"second\") (func (type $signature)))",
    ] {
    let source = "(module \{declaration} (type $signature (func (param i32) (result i32))) (func $run (result i32) i32.const 11 call $second call $first) (export \"run\" (func $run)))"
    let module_ = wast_to_binary_module(source).unwrap()
    @debug.assert_eq(
      module_.import_sec,
      Some(
        @lib.ImportSec::new([
          @lib.Import::new(
            @lib.Name::new("m"),
            @lib.Name::new("first"),
            @lib.ExternType::func(@lib.TypeIdx::new(0U)),
          ),
          @lib.Import::new(
            @lib.Name::new("m"),
            @lib.Name::new("second"),
            @lib.ExternType::func(@lib.TypeIdx::new(0U)),
          ),
        ]),
      ),
    )
    let @lib.Func(_, @lib.Expr(body)) = module_.code_sec.unwrap().0[0]
    @debug.assert_eq(body, [
      @lib.Instruction::i32_const(11),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ])
    @debug.assert_eq(
      module_.name_sec.unwrap().func_names,
      Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::new("first")),
          @lib.NameAssoc::new(1U, @lib.Name::new("second")),
          @lib.NameAssoc::new(2U, @lib.Name::new("run")),
        ]),
      ),
    )
  }
}

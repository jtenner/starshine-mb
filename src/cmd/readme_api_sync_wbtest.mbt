///|
fn ras_join_lines(lines : Array[String]) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < lines.length() {
    if i > 0 {
      out.write_string("\n")
    }
    out.write_string(lines[i])
    i += 1
  }
  out.to_string()
}

///|
test "parse_readme_api_verify_blocks extracts signature blocks with interface path" {
  let readme = ras_join_lines([
    "# Starshine", "", "<!-- README_API_VERIFY src/passes/pkg.generated.mbti -->",
    "```mbti", "pub fn optimize_module(Module, Array[ModulePass]) -> Result[Module, String]",
    "pub fn optimize_module_with_options(Module, Array[ModulePass], OptimizeOptions) -> Result[Module, String]",
    "```",
  ])
  let blocks = match parse_readme_api_verify_blocks(readme) {
    Ok(v) => v
    Err(e) => fail("expected parse success, got \{e}")
  }
  assert_eq(blocks.length(), 1)
  assert_eq(
    blocks[0],
    ReadmeApiVerifyBlock::new("src/passes/pkg.generated.mbti", [
      "pub fn optimize_module(Module, Array[ModulePass]) -> Result[Module, String]",
      "pub fn optimize_module_with_options(Module, Array[ModulePass], OptimizeOptions) -> Result[Module, String]",
    ]),
  )
}

///|
test "verify_readme_api_signatures reports missing interface file" {
  let readme = ras_join_lines([
    "<!-- README_API_VERIFY src/lib/pkg.generated.mbti -->", "```mbti", "pub fn type_idx_to_int(TypeIdx) -> Int",
    "```",
  ])
  match verify_readme_api_signatures(readme, []) {
    Ok(_) => fail("expected missing-interface diagnostic")
    Err(msg) => {
      assert_true(msg.contains("src/lib/pkg.generated.mbti"))
      assert_true(msg.contains("missing interface file"))
    }
  }
}

///|
test "verify_readme_api_signatures reports missing signature lines" {
  let readme = ras_join_lines([
    "<!-- README_API_VERIFY src/lib/pkg.generated.mbti -->", "```mbti", "pub fn type_idx_to_int(TypeIdx) -> Int",
    "```",
  ])
  let interfaces = [
    ("src/lib/pkg.generated.mbti", "pub fn something_else() -> Unit"),
  ]
  match verify_readme_api_signatures(readme, interfaces) {
    Ok(_) => fail("expected missing-signature diagnostic")
    Err(msg) => {
      assert_true(msg.contains("missing signature"))
      assert_true(msg.contains("type_idx_to_int"))
    }
  }
}

///|
test "verify_readme_api_signatures succeeds when every signature line exists in interface text" {
  let readme = ras_join_lines([
    "<!-- README_API_VERIFY src/lib/pkg.generated.mbti -->", "```mbti", "pub fn type_idx_to_int(TypeIdx) -> Int",
    "pub fn mapidx_to_int(MapIdx) -> Int", "```",
  ])
  let interfaces = [
    (
      "src/lib/pkg.generated.mbti",
      ras_join_lines([
        "pub fn type_idx_to_int(TypeIdx) -> Int", "pub fn mapidx_to_int(MapIdx) -> Int",
        "pub fn something_else() -> Unit",
      ]),
    ),
  ]
  match verify_readme_api_signatures(readme, interfaces) {
    Ok(_) => ()
    Err(msg) => fail("expected verification success, got \{msg}")
  }
}

///|
test "parse_readme_api_verify_blocks rejects marker without mbti code fence" {
  let readme = ras_join_lines([
    "<!-- README_API_VERIFY src/lib/pkg.generated.mbti -->", "```bash", "echo nope",
    "```",
  ])
  match parse_readme_api_verify_blocks(readme) {
    Ok(v) => fail("expected parse failure, got \{v}")
    Err(msg) => assert_true(msg.contains("```mbti"))
  }
}

///|
test "parse_readme_api_verify_blocks rejects readme without markers" {
  let readme = ras_join_lines(["# Starshine", "No markers here."])
  match parse_readme_api_verify_blocks(readme) {
    Ok(v) => fail("expected no-marker failure, got \{v}")
    Err(msg) => assert_true(msg.contains("no README_API_VERIFY blocks"))
  }
}

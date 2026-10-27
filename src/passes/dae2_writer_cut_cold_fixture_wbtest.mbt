///|
/// Bounded fixtures for the actual rewrite wrapper; no timed mode enters production.
fn dae2_writer_cut_cold_fixture(kind : Int32, width : Int32) -> @lib.Module {
  let text = StringBuilder()
  text.write_string(
    "(module (import \"m\" \"effect\" (func $effect (param i32) (result i32))) ",
  )
  text.write_string("(func $h (param i64) (result i32) i32.const 10) ")
  text.write_string(
    "(func (export \"run\") (param i32) (result i32) (local i32) ",
  )
  if kind == 1 {
    text.write_string("local.get 0 local.set 1 ")
  }
  for _ in 0..<width {
    match kind {
      0 => text.write_string("local.get 0 drop ")
      1 => text.write_string("local.get 1 drop ")
      2 =>
        text.write_string(
          "i32.const 3 call $effect loop nop end i32.const 1 i32.add call $effect drop ",
        )
      _ =>
        text.write_string(
          "local.get 0 if (result i32) i32.const 3 call $effect loop nop end i32.const 1 i32.add else i32.const 4 end call $effect drop ",
        )
    }
  }
  text.write_string(if kind == 1 { "local.get 1 " } else { "local.get 0 " })
  text.write_string("call $effect i64.extend_i32_s call $h))")
  pass_test_module_from_wat(text.to_string())
}

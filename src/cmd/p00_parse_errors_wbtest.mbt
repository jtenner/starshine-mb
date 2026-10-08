///|
test "P00 malformed scalar constants fail text fallback without output" {
  for kind in ["i32", "i64", "f32", "f64"] {
    let writes : Array[Bytes] = []
    let errors : Array[Bytes] = []
    let io = CmdIO::new(
      file_exists=fn(path) { path == "bad.wat" },
      read_file=fn(_) {
        Ok(
          bytes_from_string(
            "(module (func (result \{kind}) \{kind}.const banana))",
          ),
        )
      },
      lower_text_module=fn(_, _, _) { Err("adapter unavailable") },
      write_file=fn(_, bytes) {
        writes.push(bytes)
        Ok(())
      },
      write_stderr=fn(bytes) {
        errors.push(bytes)
        Ok(())
      },
    )
    @debug.assert_eq(
      run_cmd_exit_code_with_adapter(["--out", "out.wasm", "bad.wat"], io),
      1,
    )
    @debug.assert_eq(writes.length(), 0)
    @debug.assert_eq(errors.length(), 1)
    assert_true(
      bytes_to_ascii_string(errors[0]).contains("text lowering failed"),
    )
  }
}

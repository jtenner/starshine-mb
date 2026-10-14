///|
test "final invalid module dumps keep both failures" {
  let directory = "invalid-dump-two-\{@env.now()}"
  @sfs.create_dir(directory).unwrap()
  let module_ = @lib.Module::new()
  let first = run_hot_pipeline_dump_invalid_module(module_, directory~).unwrap()
  let second = run_hot_pipeline_dump_invalid_module(module_, directory~).unwrap()
  assert_true(first != second)
  let files = @sfs.list_files_recursive(directory).unwrap()
  assert_true(files.length() == 2)
  for path in files {
    @sfs.remove_file(path).unwrap()
    @sfs.remove_dir(path.replace(old="/module.wasm", new="")).unwrap()
  }
  @sfs.remove_dir(directory).unwrap()
}

///|
test "final invalid module dump reports a write failure" {
  let directory = "invalid-dump-error-\{@env.now()}"
  @sfs.create_dir(directory).unwrap()
  let blocked = "\{directory}/blocked"
  let module_ = @lib.Module::new()
  let bytes = @binary.encode_module(module_).unwrap()
  @sfs.create_dir(blocked).unwrap()
  match run_hot_pipeline_write_invalid_module(blocked, bytes) {
    Err(err) => assert_true(err.contains(blocked))
    Ok(path) => fail("expected dump failure, wrote \{path}")
  }
  @sfs.remove_dir(blocked).unwrap()
  @sfs.remove_dir(directory).unwrap()
}

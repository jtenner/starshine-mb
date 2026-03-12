///|
fn fs_test_tmp_path(label : String) -> String {
  "tmp-starshine-mini-fs-\{label}-\{@env.now()}"
}

///|
fn fs_test_bytes_from_string(text : String) -> Bytes {
  let out = @buffer.new(size_hint=text.length())
  for c in text {
    let code = c.to_int()
    if code >= 0 && code <= 255 {
      out.write_byte(code.to_byte())
    } else {
      out.write_byte('?'.to_int().to_byte())
    }
  }
  out.to_bytes()
}

///|
fn fs_test_remove_tree(root : String) -> Unit {
  if !@xfs.path_exists(root) {
    return
  }
  let entries = @xfs.read_dir(root) catch { _ => [] }
  for entry in entries {
    let path = "\{root}/\{entry}"
    if (@xfs.is_dir(path) catch { _ => false }) {
      fs_test_remove_tree(path)
    } else {
      ignore(remove_file(path))
    }
  }
  ignore(remove_dir(root))
}

///|
test "mini fs creates and removes directories" {
  let dir = fs_test_tmp_path("dir")
  ignore(remove_dir(dir))

  match create_dir(dir) {
    Ok(_) => ()
    Err(e) => fail("expected create_dir success, got \{e}")
  }
  assert_true(@xfs.path_exists(dir))

  match remove_dir(dir) {
    Ok(_) => ()
    Err(e) => fail("expected remove_dir success, got \{e}")
  }
  assert_false(@xfs.path_exists(dir))
}

///|
test "mini fs writes and deletes files" {
  let dir = fs_test_tmp_path("file")
  let path = "\{dir}/payload.bin"
  let payload = fs_test_bytes_from_string("mini fs payload\n")

  ignore(remove_file(path))
  ignore(remove_dir(dir))
  match create_dir(dir) {
    Ok(_) => ()
    Err(e) => fail("expected create_dir success, got \{e}")
  }

  match write_file_bytes(path, payload) {
    Ok(_) => ()
    Err(e) => {
      ignore(remove_dir(dir))
      fail("expected write_file_bytes success, got \{e}")
    }
  }
  let read_back = @xfs.read_file_to_bytes(path) catch {
    e => {
      ignore(remove_file(path))
      ignore(remove_dir(dir))
      fail("read_file_to_bytes failed: \{e}")
    }
  }
  assert_eq(read_back, payload)

  match remove_file(path) {
    Ok(_) => ()
    Err(e) => {
      ignore(remove_dir(dir))
      fail("expected remove_file success, got \{e}")
    }
  }
  assert_false(@xfs.path_exists(path))

  match remove_dir(dir) {
    Ok(_) => ()
    Err(e) => fail("expected remove_dir success, got \{e}")
  }
}

///|
test "mini fs recursively lists nested files for glob candidate expansion" {
  let root = fs_test_tmp_path("walk")
  let nested = "\{root}/nested"
  let deep = "\{nested}/deep"
  let sibling = "\{root}/sibling"
  let alpha = "\{root}/alpha.wasm"
  let beta = "\{nested}/beta.wat"
  let gamma = "\{deep}/gamma.wast"
  let delta = "\{sibling}/delta.txt"

  fs_test_remove_tree(root)
  match create_dir(root) {
    Ok(_) => ()
    Err(e) => fail("create root dir: \{e}")
  }
  match create_dir(nested) {
    Ok(_) => ()
    Err(e) => fail("create nested dir: \{e}")
  }
  match create_dir(deep) {
    Ok(_) => ()
    Err(e) => fail("create deep dir: \{e}")
  }
  match create_dir(sibling) {
    Ok(_) => ()
    Err(e) => fail("create sibling dir: \{e}")
  }
  match write_file_bytes(alpha, fs_test_bytes_from_string("alpha")) {
    Ok(_) => ()
    Err(e) => fail("write alpha file: \{e}")
  }
  match write_file_bytes(beta, fs_test_bytes_from_string("beta")) {
    Ok(_) => ()
    Err(e) => fail("write beta file: \{e}")
  }
  match write_file_bytes(gamma, fs_test_bytes_from_string("gamma")) {
    Ok(_) => ()
    Err(e) => fail("write gamma file: \{e}")
  }
  match write_file_bytes(delta, fs_test_bytes_from_string("delta")) {
    Ok(_) => ()
    Err(e) => fail("write delta file: \{e}")
  }

  match list_files_recursive(root) {
    Ok(files) => assert_eq(files, [alpha, beta, gamma, delta])
    Err(e) => fail("expected recursive list success, got \{e}")
  }

  fs_test_remove_tree(root)
}

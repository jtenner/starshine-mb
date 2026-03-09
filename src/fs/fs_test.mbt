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

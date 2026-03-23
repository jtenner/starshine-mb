///|
/// Minimal filesystem API for shared use across packages.
/// Backed by `moonbitlang/x/fs`, so it works on native and wasm (WASI runtime).

///|
fn fs_normalize_path(path : String) -> String {
  let out = StringBuilder::new()
  for c in path {
    if c == '\\' {
      out.write_char('/')
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn fs_join_path(dir : String, name : String) -> String {
  let normalized_dir = fs_normalize_path(dir)
  let normalized_name = fs_normalize_path(name)
  if normalized_dir.length() == 0 || normalized_dir == "." {
    normalized_name
  } else if normalized_dir[normalized_dir.length() - 1] == '/' {
    "\{normalized_dir}\{normalized_name}"
  } else {
    "\{normalized_dir}/\{normalized_name}"
  }
}

///|
fn fs_string_less_than(a : String, b : String) -> Bool {
  let mut i = 0
  let min_len = if a.length() < b.length() { a.length() } else { b.length() }
  while i < min_len {
    if a[i] < b[i] {
      return true
    }
    if a[i] > b[i] {
      return false
    }
    i += 1
  }
  a.length() < b.length()
}

///|
fn fs_sort_strings(values : Array[String]) -> Unit {
  let mut i = 1
  while i < values.length() {
    let current = values[i]
    let mut j = i
    while j > 0 && fs_string_less_than(current, values[j - 1]) {
      values[j] = values[j - 1]
      j -= 1
    }
    values[j] = current
    i += 1
  }
}

///|
fn fs_list_files_recursive_into(
  root : String,
  out : Array[String],
) -> Result[Unit, String] {
  let entries = @xfs.read_dir(root) catch {
    e => return Err("read_dir failed for \{root}: \{e}")
  }
  fs_sort_strings(entries)
  for entry in entries {
    if entry == "." || entry == ".." {
      continue
    }
    let path = fs_join_path(root, entry)
    let is_dir = @xfs.is_dir(path) catch {
      e => return Err("is_dir failed for \{path}: \{e}")
    }
    if is_dir {
      match fs_list_files_recursive_into(path, out) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      continue
    }
    let is_file = @xfs.is_file(path) catch {
      e => return Err("is_file failed for \{path}: \{e}")
    }
    if is_file {
      out.push(path)
    }
  }
  Ok(())
}

///|
pub fn create_dir(path : String) -> Result[Unit, String] {
  @xfs.create_dir(path) catch {
    e => return Err("create_dir failed for \{path}: \{e}")
  }
  Ok(())
}

///|
pub fn remove_dir(path : String) -> Result[Unit, String] {
  @xfs.remove_dir(path) catch {
    e => return Err("remove_dir failed for \{path}: \{e}")
  }
  Ok(())
}

///|
pub fn remove_file(path : String) -> Result[Unit, String] {
  @xfs.remove_file(path) catch {
    e => return Err("remove_file failed for \{path}: \{e}")
  }
  Ok(())
}

///|
pub fn write_file_bytes(path : String, bytes : Bytes) -> Result[Unit, String] {
  @xfs.write_bytes_to_file(path, bytes) catch {
    e => return Err("write_file_bytes failed for \{path}: \{e}")
  }
  Ok(())
}

///|
pub fn list_files_recursive(root : String) -> Result[Array[String], String] {
  let normalized_root = fs_normalize_path(root)
  let is_dir = @xfs.is_dir(normalized_root) catch {
    e => return Err("is_dir failed for \{normalized_root}: \{e}")
  }
  if !is_dir {
    let is_file = @xfs.is_file(normalized_root) catch {
      e => return Err("is_file failed for \{normalized_root}: \{e}")
    }
    if is_file {
      return Ok([normalized_root])
    }
    return Ok([])
  }
  let out = Array::new()
  match fs_list_files_recursive_into(normalized_root, out) {
    Ok(_) => Ok(out)
    Err(e) => Err(e)
  }
}

///|
pub fn read_file_sync(path : String) -> Result[String, String] {
  let bytes = @xfs.read_file_to_bytes(path) catch {
    e => return Err("read_file_to_bytes failed for \{path}: \{e}")
  }
  bytes.text() catch {
    e => Err("read_file_to_bytes->text failed for \{path}: \{e}")
  }
}

///|
/// Minimal filesystem API for shared use across packages.
/// Backed by `moonbitlang/x/fs`, so it works on native and wasm (WASI runtime).

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

///|
fn request(op : Int, ptr : Int, len : Int) -> Int = "__starshine_cli_v1" "request"

///|
fn response(ptr : Int, capacity : Int) -> Int = "__starshine_cli_v1" "response"

///|
fn exit(code : Int) -> Unit = "__starshine_cli_v1" "exit"

///|
extern "wasm" fn memory_size() -> Int =
  #|(func (result i32) memory.size)

///|
extern "wasm" fn memory_grow(pages : Int) -> Int =
  #|(func (param i32) (result i32) local.get 0 memory.grow)

///|
extern "wasm" fn store_byte(ptr : Int, value : Int) -> Unit =
  #|(func (param i32 i32) local.get 0 local.get 1 i32.store8)

///|
extern "wasm" fn load_byte(ptr : Int) -> Int =
  #|(func (param i32) (result i32) local.get 0 i32.load8_u)

///|
// Reserve pages after the compiler's static data. Reuse the same staging area.
let staging : Ref[(Int, Int)] = Ref::new((0, 0))

///|
fn reserve(length : Int) -> Result[Int, String] {
  if length < 0 || length > 0x7fff0000 {
    return Err("bulk CLI payload is too large")
  }
  let (base, capacity) = staging.val
  if length <= capacity && capacity > 0 {
    return Ok(base)
  }
  let pages = (length + 65535) / 65536
  let pages = if pages == 0 { 1 } else { pages }
  let current = memory_size()
  // memory.grow cannot move a reserved area. Only the area at the end can grow.
  let can_extend = capacity > 0 && base + capacity == current * 65536
  let extra = if can_extend { pages - capacity / 65536 } else { pages }
  if current < 0 || current > 32767 - extra {
    return Err("bulk CLI staging allocation is too large")
  }
  let previous = memory_grow(extra)
  if previous < 0 || previous > 32767 - extra {
    return Err("bulk CLI staging allocation failed")
  }
  let next_base = if can_extend { base } else { previous * 65536 }
  staging.val = (next_base, pages * 65536)
  Ok(next_base)
}

///|
fn exchange(op : Int, packet : Bytes) -> Result[(Int, Bytes), String] {
  let ptr = match reserve(packet.length()) {
    Ok(ptr) => ptr
    Err(error) => return Err(error)
  }
  for i = 0; i < packet.length(); i = i + 1 {
    store_byte(ptr + i, packet[i].to_int())
  }
  let size = request(op, ptr, packet.length())
  if size < 1 {
    return Err("invalid bulk CLI response length")
  }
  let ptr = match reserve(size) {
    Ok(ptr) => ptr
    Err(error) => return Err(error)
  }
  if response(ptr, size) != size {
    return Err("incomplete bulk CLI response")
  }
  let status = load_byte(ptr)
  let bytes = Bytes::makei(size - 1, fn(i) { load_byte(ptr + 1 + i).to_byte() })
  if status == 1 {
    Err(@utf8.decode_lossy(bytes))
  } else if status == 0 || status == 2 {
    Ok((status, bytes))
  } else {
    Err("invalid bulk CLI response status")
  }
}

///|
fn read(path : String) -> Result[Bytes, String] {
  match exchange(4, @utf8.encode(path)) {
    Ok((_, bytes)) => Ok(bytes)
    Err(error) => Err(error)
  }
}

///|
fn write(path : String, bytes : Bytes) -> Result[Unit, String] {
  let path = @utf8.encode(path)
  if path.length() > 0x7fff0000 - 4 ||
    bytes.length() > 0x7fff0000 - 4 - path.length() {
    return Err("bulk CLI write packet is too large")
  }
  let packet = @buffer.new(size_hint=4 + path.length() + bytes.length())
  packet.write_uint_le(path.length().to_uint())
  packet.write_bytes(path)
  packet.write_bytes(bytes)
  match exchange(5, packet.to_bytes()) {
    Ok(_) => Ok(())
    Err(error) => Err(error)
  }
}

///|
fn write_stream(op : Int, bytes : Bytes) -> Result[Unit, String] {
  if bytes.length() == 0 {
    return Ok(())
  }
  match exchange(op, bytes) {
    Ok(_) => Ok(())
    Err(error) => Err(error)
  }
}

///|
fn strings(bytes : Bytes) -> Result[Array[String], String] {
  let value = @json.parse(@utf8.decode_lossy(bytes)) catch {
    _ => return Err("invalid bulk CLI string array")
  }
  guard value is Array(items) else {
    return Err("invalid bulk CLI string array")
  }
  let out = []
  for item in items {
    guard item is String(value) else {
      return Err("invalid bulk CLI string array item")
    }
    out.push(value)
  }
  Ok(out)
}

///|
fn main {
  let io = @cmd.CmdIO::new(
    get_env=fn(name) {
      match exchange(2, @utf8.encode(name)) {
        Ok((0, bytes)) => Some(@utf8.decode_lossy(bytes))
        _ => None
      }
    },
    file_exists=fn(path) {
      match exchange(3, @utf8.encode(path)) {
        Ok((0, bytes)) => bytes.length() == 1 && bytes[0] == 1
        _ => false
      }
    },
    read_file=read,
    write_file=write,
    write_stdout=fn(bytes) { write_stream(7, bytes) },
    write_stderr=fn(bytes) { write_stream(8, bytes) },
    list_candidates=fn() {
      match exchange(6, b"") {
        Ok((_, bytes)) => strings(bytes).unwrap_or([])
        _ => []
      }
    },
  )
  let code = match exchange(1, b"") {
    Ok((_, bytes)) =>
      match strings(bytes) {
        Ok(args) => @cmd.run_cmd_exit_code_with_adapter(args, io)
        Err(error) => {
          ignore(write_stream(8, @utf8.encode(error)))
          1
        }
      }
    Err(error) => {
      ignore(write_stream(8, @utf8.encode(error)))
      1
    }
  }
  if code != 0 {
    exit(code)
  }
}

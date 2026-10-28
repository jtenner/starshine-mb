///|
extern "C" fn lifetime_configure(stage : Int) -> Unit = "lifetime_configure"

///|
extern "C" fn lifetime_live() -> Int = "lifetime_live"

///|
extern "C" fn lifetime_opens() -> Int = "lifetime_opens"

///|
extern "C" fn lifetime_closes() -> Int = "lifetime_closes"

///|
extern "C" fn lifetime_message(kind : Int) -> Bytes = "lifetime_message"

///|
test "read seek-end releases its stream" {
  lifetime_configure(2)
  for i = 0; i < 4; i = i + 1 {
    let message = try {
      ignore(read_file_to_bytes("resource-lifetime-fixture"))
      "unexpected success"
    } catch { IOError(message) => message }
    assert_eq(message, @unicode.to_utf8_string(lifetime_message(2)))
    assert_eq(lifetime_live(), 0)
    assert_eq(lifetime_opens(), i + 1)
    assert_eq(lifetime_closes(), i + 1)
  }
}

///|
test "read tell releases its stream" {
  lifetime_configure(3)
  for i = 0; i < 4; i = i + 1 {
    let message = try {
      ignore(read_file_to_bytes("resource-lifetime-fixture"))
      "unexpected success"
    } catch { IOError(message) => message }
    assert_eq(message, @unicode.to_utf8_string(lifetime_message(3)))
    assert_eq(lifetime_live(), 0)
    assert_eq(lifetime_opens(), i + 1)
    assert_eq(lifetime_closes(), i + 1)
  }
}

///|
test "read rewind releases its stream" {
  lifetime_configure(4)
  for i = 0; i < 4; i = i + 1 {
    let message = try {
      ignore(read_file_to_bytes("resource-lifetime-fixture"))
      "unexpected success"
    } catch { IOError(message) => message }
    assert_eq(message, @unicode.to_utf8_string(lifetime_message(4)))
    assert_eq(lifetime_live(), 0)
    assert_eq(lifetime_opens(), i + 1)
    assert_eq(lifetime_closes(), i + 1)
  }
}

///|
test "read short-read releases its stream" {
  lifetime_configure(5)
  for i = 0; i < 4; i = i + 1 {
    let message = try {
      ignore(read_file_to_bytes("resource-lifetime-fixture"))
      "unexpected success"
    } catch { IOError(message) => message }
    assert_eq(message, @unicode.to_utf8_string(lifetime_message(5)))
    assert_eq(lifetime_live(), 0)
    assert_eq(lifetime_opens(), i + 1)
    assert_eq(lifetime_closes(), i + 1)
  }
}

///|
test "write short-write releases its stream" {
  lifetime_configure(6)
  for i = 0; i < 4; i = i + 1 {
    let message = try {
      ignore(write_bytes_to_file("resource-lifetime-fixture", b"wasm"))
      "unexpected success"
    } catch { IOError(message) => message }
    assert_eq(message, @unicode.to_utf8_string(lifetime_message(6)))
    assert_eq(lifetime_live(), 0)
    assert_eq(lifetime_opens(), i + 1)
    assert_eq(lifetime_closes(), i + 1)
  }
}

///|
test "write flush releases its stream" {
  lifetime_configure(7)
  for i = 0; i < 4; i = i + 1 {
    let message = try {
      ignore(write_bytes_to_file("resource-lifetime-fixture", b"wasm"))
      "unexpected success"
    } catch { IOError(message) => message }
    assert_eq(message, @unicode.to_utf8_string(lifetime_message(7)))
    assert_eq(lifetime_live(), 0)
    assert_eq(lifetime_opens(), i + 1)
    assert_eq(lifetime_closes(), i + 1)
  }
}

///|
test "read open releases its stream" {
  lifetime_configure(1)
  for i = 0; i < 4; i = i + 1 {
    let message = try {
      ignore(read_file_to_bytes("resource-lifetime-fixture"))
      "unexpected success"
    } catch { IOError(message) => message }
    assert_eq(message, @unicode.to_utf8_string(lifetime_message(1)))
    assert_eq(lifetime_live(), 0)
    assert_eq(lifetime_opens(), 0)
    assert_eq(lifetime_closes(), 0)
  }
}

///|
test "write open releases its stream" {
  lifetime_configure(1)
  for i = 0; i < 4; i = i + 1 {
    let message = try {
      ignore(write_bytes_to_file("resource-lifetime-fixture", b"wasm"))
      "unexpected success"
    } catch { IOError(message) => message }
    assert_eq(message, @unicode.to_utf8_string(lifetime_message(1)))
    assert_eq(lifetime_live(), 0)
    assert_eq(lifetime_opens(), 0)
    assert_eq(lifetime_closes(), 0)
  }
}

///|
test "read close releases its stream" {
  lifetime_configure(8)
  for i = 0; i < 4; i = i + 1 {
    let message = try {
      ignore(read_file_to_bytes("resource-lifetime-fixture"))
      "unexpected success"
    } catch { IOError(message) => message }
    assert_eq(message, @unicode.to_utf8_string(lifetime_message(8)))
    assert_eq(lifetime_live(), 0)
    assert_eq(lifetime_opens(), i + 1)
    assert_eq(lifetime_closes(), i + 1)
  }
}

///|
test "write close releases its stream" {
  lifetime_configure(8)
  for i = 0; i < 4; i = i + 1 {
    let message = try {
      ignore(write_bytes_to_file("resource-lifetime-fixture", b"wasm"))
      "unexpected success"
    } catch { IOError(message) => message }
    assert_eq(message, @unicode.to_utf8_string(lifetime_message(8)))
    assert_eq(lifetime_live(), 0)
    assert_eq(lifetime_opens(), i + 1)
    assert_eq(lifetime_closes(), i + 1)
  }
}

///|
test "read success releases its stream" {
  lifetime_configure(0)
  for i = 0; i < 4; i = i + 1 {
    assert_eq(read_file_to_bytes("resource-lifetime-fixture"), b"wasm")
    assert_eq(lifetime_live(), 0)
    assert_eq(lifetime_opens(), i + 1)
    assert_eq(lifetime_closes(), i + 1)
  }
}

///|
test "write success releases its stream" {
  lifetime_configure(0)
  for i = 0; i < 4; i = i + 1 {
    write_bytes_to_file("resource-lifetime-fixture", b"wasm")
    assert_eq(lifetime_live(), 0)
    assert_eq(lifetime_opens(), i + 1)
    assert_eq(lifetime_closes(), i + 1)
  }
}

///|
// Hand-encoded modules exercise decoding, not just constructed element types.
// Core binary/modules.html#element-section assigns (ref func) to forms 0–3.
fn f1_module(
  segment : Array[Byte],
  consumer : Int32,
  nullable : Bool,
) -> Module {
  let rt : Array[Byte] = if nullable { [0x70] } else { [0x64, 0x70] }
  let types : Array[Byte] = [0x02, 0x60, 0x00, 0x00, 0x5e]
  types.append(rt)
  types.push(0x01) // mutable array field
  let imports : Array[Byte] = [0x01, 0x01, 0x6d, 0x01, 0x74, 0x01]
  imports.append(rt)
  imports.append([0x00, 0x01]) // imported table, min 1
  let body : Array[Byte] = [0x00] // no locals
  match consumer {
    0 =>
      body.append([0x41, 0x00, 0x41, 0x00, 0x41, 0x01, 0xfc, 0x0c, 0x00, 0x00])
    1 =>
      body.append([
        0xd0, 0x01, 0x41, 0x00, 0x41, 0x00, 0x41, 0x01, 0xfb, 0x13, 0x01, 0x00,
      ])
    _ => body.append([0x41, 0x00, 0x41, 0x01, 0xfb, 0x0a, 0x01, 0x00, 0x1a])
  }
  body.push(0x0b)
  let elems : Array[Byte] = [0x01]
  elems.append(segment)
  let codes : Array[Byte] = [0x01, body.length().to_byte()]
  codes.append(body)
  let bytes : Array[Byte] = [0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
  for
    (id, payload) in [
      (0x01, types),
      (0x02, imports),
      (0x03, [0x01, 0x00]),
      (0x09, elems),
      (0x0a, codes),
    ] {
    bytes.push(id.to_byte())
    bytes.push(payload.length().to_byte())
    bytes.append(payload)
  }
  @binary.decode_module(Bytes::from_array(bytes)).unwrap()
}

///|
fn f1_require_valid(mod_ : Module) -> Unit raise {
  match validate_module(mod_) {
    Ok(_) => ()
    Err(err) => fail(validation_error_message(err))
  }
}

///|
test "F1 decoded function-index forms 0-3 support nullable and non-null consumers" {
  let segments : Array[Array[Byte]] = [
    [0x00, 0x41, 0x00, 0x0b, 0x01, 0x00], // active implicit table
    [0x01, 0x00, 0x01, 0x00], // passive
    [0x02, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x01, 0x00], // active explicit table
    [0x03, 0x00, 0x01, 0x00], // declarative (consumption traps only at runtime)
  ]
  for segment in segments {
    for consumer in 0..<3 {
      for nullable in [false, true] {
        let mod_ = f1_module(segment, consumer, nullable)
        f1_require_valid(mod_)
        let bytes = @binary.encode_module(mod_).unwrap()
        f1_require_valid(@binary.decode_module(bytes).unwrap())
      }
    }
  }
}

///|
test "F1 passive function indices support non-null table.init" {
  f1_require_valid(f1_module([0x01, 0x00, 0x01, 0x00], 0, false))
}

///|
test "F1 passive function indices support non-null array.init_elem" {
  f1_require_valid(f1_module([0x01, 0x00, 0x01, 0x00], 1, false))
}

///|
test "F1 passive function indices support non-null array.new_elem" {
  f1_require_valid(f1_module([0x01, 0x00, 0x01, 0x00], 2, false))
}

///|
test "F1 explicitly nullable expressions intentionally reject non-null destinations" {
  // Both ref.func and ref.null initializers retain the explicit nullable type.
  let initializers : Array[Array[Byte]] = [
    [0xd2, 0x00, 0x0b],
    [0xd0, 0x70, 0x0b],
  ]
  for init in initializers {
    let segment : Array[Byte] = [0x05, 0x70, 0x01]
    segment.append(init)
    for consumer in 0..<3 {
      let expected = match consumer {
        0 => "table.init elem segment type does not match table element type"
        1 =>
          "array.init_elem elem segment type does not match array storage type"
        _ =>
          "array.new_elem elem segment type does not match array element reftype"
      }
      match validate_module(f1_module(segment, consumer, false)) {
        Ok(_) =>
          fail("nullable segment must not flow to a non-null destination")
        Err(err) =>
          assert_true(validation_error_message(err).contains(expected))
      }
      f1_require_valid(f1_module(segment, consumer, true))
    }
  }
}

///|
test "F1 active nullable expression segments intentionally reject non-null tables" {
  // Form 4 implies nullable funcref; form 6 explicitly supplies it.
  let segments : Array[Array[Byte]] = [
    [0x04, 0x41, 0x00, 0x0b, 0x01, 0xd2, 0x00, 0x0b],
    [0x06, 0x00, 0x41, 0x00, 0x0b, 0x70, 0x01, 0xd2, 0x00, 0x0b],
  ]
  for segment in segments {
    match validate_module(f1_module(segment, 0, false)) {
      Ok(_) => fail("nullable active segment must not flow to a non-null table")
      Err(err) =>
        assert_eq(
          validation_error_message(err),
          "elem.active: elem type does not match table element type",
        )
    }
    f1_require_valid(f1_module(segment, 0, true))
  }
}

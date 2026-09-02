///|
fn bridge_map_type(base : Int) -> @lib.TypeIdx {
  @lib.TypeIdx::new((base + 8).reinterpret_as_uint())
}

///|
fn bridge_map_get_field(
  output : Array[@lib.Instruction],
  base : Int,
  map_local : Int,
  field : UInt,
) -> Unit {
  let map_type = bridge_map_type(base)
  output.push(@lib.Instruction::local_get(bridge_array_local(map_local)))
  output.push(bridge_array_ref_cast(map_type))
  output.push(@lib.Instruction::struct_get(map_type, field))
}

///|
fn bridge_map_new_array_wrapper(base : Int) -> Array[@lib.Instruction] {
  let wrapper_type = bridge_array_wrapper_type(base)
  [
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::i32_const(@lib.I32::new(0)),
    @lib.Instruction::i32_const(@lib.I32::new(0)),
    @lib.Instruction::struct_new(wrapper_type),
  ]
}

///|
fn bridge_map_append_from_locals(
  output : Array[@lib.Instruction],
  base : Int,
  carrier : Int,
  wrapper_local : Int,
  item_local : Int,
  backing : Int,
  length : Int,
  capacity : Int,
  new_backing : Int,
) -> Unit {
  let wrapper_type = bridge_array_wrapper_type(base)
  let array_type = bridge_array_type(base, carrier)
  bridge_array_wrapper_get(output, wrapper_type, wrapper_local, 0U)
  output.push(@lib.Instruction::local_set(bridge_array_local(backing)))
  bridge_array_wrapper_get(output, wrapper_type, wrapper_local, 1U)
  output.push(@lib.Instruction::local_set(bridge_array_local(length)))
  bridge_array_wrapper_get(output, wrapper_type, wrapper_local, 2U)
  output.push(@lib.Instruction::local_set(bridge_array_local(capacity)))
  output.push(@lib.Instruction::local_get(bridge_array_local(backing)))
  output.push(@lib.Instruction::ref_is_null())
  output.push(@lib.Instruction::local_get(bridge_array_local(length)))
  output.push(@lib.Instruction::local_get(bridge_array_local(capacity)))
  output.push(@lib.Instruction::i32_ge_u())
  output.push(@lib.Instruction::i32_or())
  let grow : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(bridge_array_local(capacity)),
    @lib.Instruction::i32_const(@lib.I32::new(4)),
    @lib.Instruction::i32_lt_u(),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [@lib.Instruction::i32_const(@lib.I32::new(4))],
      Some([
        @lib.Instruction::local_get(bridge_array_local(capacity)),
        @lib.Instruction::i32_const(@lib.I32::new(2)),
        @lib.Instruction::i32_mul(),
      ]),
    ),
    @lib.Instruction::local_set(bridge_array_local(capacity)),
    @lib.Instruction::local_get(bridge_array_local(capacity)),
    @lib.Instruction::array_new_default(array_type),
    @lib.Instruction::local_set(bridge_array_local(new_backing)),
    @lib.Instruction::local_get(bridge_array_local(backing)),
    @lib.Instruction::ref_is_null(),
  ]
  let copy : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(bridge_array_local(new_backing)),
    bridge_array_ref_cast(array_type),
    @lib.Instruction::i32_const(@lib.I32::new(0)),
    @lib.Instruction::local_get(bridge_array_local(backing)),
    bridge_array_ref_cast(array_type),
    @lib.Instruction::i32_const(@lib.I32::new(0)),
    @lib.Instruction::local_get(bridge_array_local(length)),
    @lib.Instruction::array_copy(array_type, array_type),
  ]
  grow.push(@lib.Instruction::if_(@lib.BlockType::void_(), [], Some(copy)))
  bridge_array_wrapper_set_prefix(grow, wrapper_type, wrapper_local)
  grow.push(@lib.Instruction::local_get(bridge_array_local(new_backing)))
  grow.push(@lib.Instruction::struct_set(wrapper_type, 0U))
  bridge_array_wrapper_set_prefix(grow, wrapper_type, wrapper_local)
  grow.push(@lib.Instruction::local_get(bridge_array_local(capacity)))
  grow.push(@lib.Instruction::struct_set(wrapper_type, 2U))
  output.push(@lib.Instruction::if_(@lib.BlockType::void_(), grow, None))
  bridge_array_wrapper_get(output, wrapper_type, wrapper_local, 0U)
  output.push(bridge_array_ref_cast(array_type))
  output.push(@lib.Instruction::local_get(bridge_array_local(length)))
  output.push(@lib.Instruction::local_get(bridge_array_local(item_local)))
  output.push(@lib.Instruction::array_set(array_type))
  bridge_array_wrapper_set_prefix(output, wrapper_type, wrapper_local)
  output.push(@lib.Instruction::local_get(bridge_array_local(length)))
  output.push(@lib.Instruction::i32_const(@lib.I32::new(1)))
  output.push(@lib.Instruction::i32_add())
  output.push(@lib.Instruction::struct_set(wrapper_type, 1U))
}

///|
fn bridge_map_equal_instruction(carrier : Int) -> @lib.Instruction {
  match carrier {
    0 => @lib.Instruction::i32_eq()
    1 => @lib.Instruction::i64_eq()
    2 => @lib.Instruction::f32_eq()
    3 => @lib.Instruction::f64_eq()
    4 => @lib.Instruction::i8x16_eq()
    _ => @lib.Instruction::ref_eq()
  }
}

///|
fn bridge_map_empty_body(base : Int) -> @lib.Func {
  let body : Array[@lib.Instruction] = []
  for instruction in bridge_map_new_array_wrapper(base) {
    body.push(instruction)
  }
  for instruction in bridge_map_new_array_wrapper(base) {
    body.push(instruction)
  }
  body.push(@lib.Instruction::struct_new(bridge_map_type(base)))
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
}

///|
fn bridge_map_length_body(base : Int) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let body : Array[@lib.Instruction] = []
  bridge_map_get_field(body, base, 0, 0U)
  body.push(bridge_array_ref_cast(wrapper_type))
  body.push(@lib.Instruction::struct_get(wrapper_type, 1U))
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
}

///|
fn bridge_instructions_push_map_set(
  output : Array[@lib.Instruction],
  base : Int,
  key_carrier : Int,
  value_carrier : Int,
  scratch : Int,
) -> Unit {
  let map_local = scratch
  let key_local = scratch + 1 + key_carrier
  let value_local = scratch + 7 + value_carrier
  let keys = scratch + 13
  let values = scratch + 14
  let backing = scratch + 15
  let length = scratch + 16
  let capacity = scratch + 17
  let new_backing = scratch + 18
  output.push(@lib.Instruction::local_set(bridge_array_local(value_local)))
  output.push(@lib.Instruction::local_set(bridge_array_local(key_local)))
  output.push(@lib.Instruction::local_set(bridge_array_local(map_local)))
  bridge_map_get_field(output, base, map_local, 0U)
  output.push(@lib.Instruction::local_set(bridge_array_local(keys)))
  bridge_map_get_field(output, base, map_local, 1U)
  output.push(@lib.Instruction::local_set(bridge_array_local(values)))
  bridge_map_append_from_locals(
    output, base, key_carrier, keys, key_local, backing, length, capacity, new_backing,
  )
  bridge_map_append_from_locals(
    output, base, value_carrier, values, value_local, backing, length, capacity,
    new_backing,
  )
}

///|
fn bridge_map_set_body(
  base : Int,
  key_carrier : Int,
  value_carrier : Int,
) -> @lib.Func {
  let keys = 3
  let values = 4
  let backing = 5
  let length = 6
  let capacity = 7
  let new_backing = 8
  let body : Array[@lib.Instruction] = []
  bridge_map_get_field(body, base, 0, 0U)
  body.push(@lib.Instruction::local_set(bridge_array_local(keys)))
  bridge_map_get_field(body, base, 0, 1U)
  body.push(@lib.Instruction::local_set(bridge_array_local(values)))
  bridge_map_append_from_locals(
    body, base, key_carrier, keys, 1, backing, length, capacity, new_backing,
  )
  bridge_map_append_from_locals(
    body, base, value_carrier, values, 2, backing, length, capacity, new_backing,
  )
  @lib.Func::new(
    @lib.Locals::from_types([
      @lib.ValType::eqref_null(),
      @lib.ValType::eqref_null(),
      @lib.ValType::eqref_null(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::eqref_null(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
fn bridge_map_lookup_body(
  base : Int,
  key_carrier : Int,
  value_carrier : Int,
  operation : Int,
  none_type_index : Int,
  some_type_index : Int,
) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let key_array_type = bridge_array_type(base, key_carrier)
  let value_array_type = bridge_array_type(base, value_carrier)
  let none_type = @lib.TypeIdx::new(none_type_index.reinterpret_as_uint())
  let some_type = @lib.TypeIdx::new(some_type_index.reinterpret_as_uint())
  let keys = 2
  let values = 3
  let index = 4
  let body : Array[@lib.Instruction] = []
  bridge_map_get_field(body, base, 0, 0U)
  body.push(@lib.Instruction::local_set(bridge_array_local(keys)))
  bridge_map_get_field(body, base, 0, 1U)
  body.push(@lib.Instruction::local_set(bridge_array_local(values)))
  bridge_array_wrapper_get(body, wrapper_type, keys, 1U)
  body.push(@lib.Instruction::local_set(bridge_array_local(index)))
  let loop_body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(bridge_array_local(index)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(bridge_array_local(index)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::local_set(bridge_array_local(index)),
  ]
  bridge_array_wrapper_get(loop_body, wrapper_type, keys, 0U)
  loop_body.push(bridge_array_ref_cast(key_array_type))
  loop_body.push(@lib.Instruction::local_get(bridge_array_local(index)))
  loop_body.push(@lib.Instruction::array_get(key_array_type))
  loop_body.push(@lib.Instruction::local_get(bridge_array_local(1)))
  loop_body.push(bridge_map_equal_instruction(key_carrier))
  if key_carrier == 4 {
    loop_body.push(@lib.Instruction::i16x8_all_true())
  }
  let found : Array[@lib.Instruction] = []
  if operation == 2 {
    found.push(@lib.Instruction::i32_const(@lib.I32::new(1)))
  } else {
    bridge_array_wrapper_get(found, wrapper_type, values, 0U)
    found.push(bridge_array_ref_cast(value_array_type))
    found.push(@lib.Instruction::local_get(bridge_array_local(index)))
    found.push(@lib.Instruction::array_get(value_array_type))
    if operation == 1 {
      found.push(@lib.Instruction::struct_new(some_type))
    }
  }
  found.push(@lib.Instruction::return_())
  loop_body.push(@lib.Instruction::if_(@lib.BlockType::void_(), found, None))
  loop_body.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(loop_body),
        ),
      ]),
    ),
  )
  if operation == 0 {
    body.push(@lib.Instruction::unreachable_())
  } else if operation == 1 {
    body.push(@lib.Instruction::struct_new(none_type))
  } else {
    body.push(@lib.Instruction::i32_const(@lib.I32::new(0)))
  }
  @lib.Func::new(
    @lib.Locals::from_types([
      @lib.ValType::eqref_null(),
      @lib.ValType::eqref_null(),
      @lib.ValType::i32(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
fn emit_bridge_map_runtime_function(
  name : Bytes,
  base : Int,
  key_carrier : Int,
  value_carrier : Int,
  none_type : Int,
  some_type : Int,
) -> @lib.Func? {
  if name == b"dew_map_empty" {
    Some(bridge_map_empty_body(base))
  } else if name == b"dew_map_length" {
    Some(bridge_map_length_body(base))
  } else if name == b"dew_map_set" || name == b"dew_map_insert" {
    Some(bridge_map_set_body(base, key_carrier, value_carrier))
  } else if name == b"dew_map_get_unchecked" {
    Some(
      bridge_map_lookup_body(
        base, key_carrier, value_carrier, 0, none_type, some_type,
      ),
    )
  } else if name == b"dew_map_get" {
    Some(
      bridge_map_lookup_body(
        base, key_carrier, value_carrier, 1, none_type, some_type,
      ),
    )
  } else if name == b"dew_map_contains_key" {
    Some(
      bridge_map_lookup_body(
        base, key_carrier, value_carrier, 2, none_type, some_type,
      ),
    )
  } else {
    None
  }
}

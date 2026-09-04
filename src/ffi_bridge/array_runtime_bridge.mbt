///|
fn bridge_array_type(base : Int, carrier : Int) -> @lib.TypeIdx {
  @lib.TypeIdx::new((base + carrier).reinterpret_as_uint())
}

///|
fn bridge_array_wrapper_type(base : Int) -> @lib.TypeIdx {
  @lib.TypeIdx::new((base + 6).reinterpret_as_uint())
}

///|
fn bridge_array_ref_cast(type_ : @lib.TypeIdx) -> @lib.Instruction {
  @lib.Instruction::ref_cast(false, @lib.HeapType::new(type_))
}

///|
fn bridge_array_local(index : Int) -> @lib.LocalIdx {
  @lib.LocalIdx::new(index.reinterpret_as_uint())
}

///|
fn bridge_array_wrapper_get(
  output : Array[@lib.Instruction],
  wrapper_type : @lib.TypeIdx,
  local : Int,
  field : UInt,
) -> Unit {
  output.push(@lib.Instruction::local_get(bridge_array_local(local)))
  output.push(bridge_array_ref_cast(wrapper_type))
  output.push(@lib.Instruction::struct_get(wrapper_type, field))
}

///|
fn bridge_array_wrapper_set_prefix(
  output : Array[@lib.Instruction],
  wrapper_type : @lib.TypeIdx,
  local : Int,
) -> Unit {
  output.push(@lib.Instruction::local_get(bridge_array_local(local)))
  output.push(bridge_array_ref_cast(wrapper_type))
}

///|
fn bridge_array_new_body(base : Int, with_capacity : Bool) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::i32_const(@lib.I32::new(0)),
  ]
  if with_capacity {
    body.push(@lib.Instruction::local_get(bridge_array_local(0)))
  } else {
    body.push(@lib.Instruction::i32_const(@lib.I32::new(0)))
  }
  body.push(@lib.Instruction::struct_new(wrapper_type))
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
}

///|
fn bridge_array_make_body(base : Int, carrier : Int) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let array_type = bridge_array_type(base, carrier)
  @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::local_get(bridge_array_local(1)),
      @lib.Instruction::local_get(bridge_array_local(0)),
      @lib.Instruction::array_new(array_type),
      @lib.Instruction::local_get(bridge_array_local(0)),
      @lib.Instruction::local_get(bridge_array_local(0)),
      @lib.Instruction::struct_new(wrapper_type),
    ]),
  )
}

///|
fn bridge_array_field_body(base : Int, field : UInt) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let body : Array[@lib.Instruction] = []
  bridge_array_wrapper_get(body, wrapper_type, 0, field)
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
}

///|
fn bridge_array_backing_length_body(base : Int, carrier : Int) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let array_type = bridge_array_type(base, carrier)
  let body : Array[@lib.Instruction] = []
  bridge_array_wrapper_get(body, wrapper_type, 0, 0U)
  body.push(@lib.Instruction::local_tee(bridge_array_local(1)))
  body.push(@lib.Instruction::ref_is_null())
  body.push(
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [@lib.Instruction::i32_const(@lib.I32::new(0))],
      Some([
        @lib.Instruction::local_get(bridge_array_local(1)),
        bridge_array_ref_cast(array_type),
        @lib.Instruction::array_len(),
      ]),
    ),
  )
  @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::eqref_null()]),
    @lib.Expr::new(body),
  )
}

///|
pub fn instructions_push_array_push(
  values : Array[@lib.Instruction],
  base : Int,
  carrier : Int,
  scratch : Int,
) -> Unit {
  if carrier >= 6 {
    let pair = carrier - 6
    bridge_instructions_push_map_set(values, base, pair / 6, pair % 6, scratch)
    return
  }
  let wrapper = scratch
  let item = scratch + 1 + carrier
  let backing = scratch + 7
  let length = scratch + 8
  let capacity = scratch + 9
  let new_backing = scratch + 10
  values.push(@lib.Instruction::local_set(bridge_array_local(item)))
  values.push(@lib.Instruction::local_set(bridge_array_local(wrapper)))
  bridge_map_append_from_locals(
    values, base, carrier, wrapper, item, backing, length, capacity, new_backing,
  )
}

///|
/// Append one carrier-specific Array pop operation.
/// The caller must prove that carrier is in the range 0 through 5.
pub fn instructions_push_array_pop(
  values : Array[@lib.Instruction],
  base : Int,
  carrier : Int,
  scratch : Int,
) -> Unit {
  let wrapper_type = bridge_array_wrapper_type(base)
  let array_type = bridge_array_type(base, carrier)
  let none_type = @lib.TypeIdx::new((base + 10).reinterpret_as_uint())
  let some_type = @lib.TypeIdx::new((base + 11 + carrier).reinterpret_as_uint())
  let wrapper = scratch
  let length = scratch + 8
  values.push(@lib.Instruction::local_set(bridge_array_local(wrapper)))
  bridge_array_wrapper_get(values, wrapper_type, wrapper, 1U)
  values.push(@lib.Instruction::local_set(bridge_array_local(length)))
  values.push(@lib.Instruction::local_get(bridge_array_local(length)))
  values.push(@lib.Instruction::i32_eqz())
  let success : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(bridge_array_local(length)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::local_set(bridge_array_local(length)),
  ]
  bridge_array_wrapper_set_prefix(success, wrapper_type, wrapper)
  success.push(@lib.Instruction::local_get(bridge_array_local(length)))
  success.push(@lib.Instruction::struct_set(wrapper_type, 1U))
  bridge_array_wrapper_get(success, wrapper_type, wrapper, 0U)
  success.push(bridge_array_ref_cast(array_type))
  success.push(@lib.Instruction::local_get(bridge_array_local(length)))
  success.push(@lib.Instruction::array_get(array_type))
  success.push(@lib.Instruction::struct_new(some_type))
  values.push(
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::eqref_null()),
      [@lib.Instruction::struct_new(none_type)],
      Some(success),
    ),
  )
}

///|
fn bridge_array_push_body(base : Int, carrier : Int) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let array_type = bridge_array_type(base, carrier)
  let backing = 2
  let length = 3
  let capacity = 4
  let new_backing = 5
  let body : Array[@lib.Instruction] = []
  bridge_array_wrapper_get(body, wrapper_type, 0, 0U)
  body.push(@lib.Instruction::local_set(bridge_array_local(backing)))
  bridge_array_wrapper_get(body, wrapper_type, 0, 1U)
  body.push(@lib.Instruction::local_set(bridge_array_local(length)))
  bridge_array_wrapper_get(body, wrapper_type, 0, 2U)
  body.push(@lib.Instruction::local_set(bridge_array_local(capacity)))
  body.push(@lib.Instruction::local_get(bridge_array_local(backing)))
  body.push(@lib.Instruction::ref_is_null())
  body.push(@lib.Instruction::local_get(bridge_array_local(length)))
  body.push(@lib.Instruction::local_get(bridge_array_local(capacity)))
  body.push(@lib.Instruction::i32_ge_u())
  body.push(@lib.Instruction::i32_or())
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
  bridge_array_wrapper_set_prefix(grow, wrapper_type, 0)
  grow.push(@lib.Instruction::local_get(bridge_array_local(new_backing)))
  grow.push(@lib.Instruction::struct_set(wrapper_type, 0U))
  bridge_array_wrapper_set_prefix(grow, wrapper_type, 0)
  grow.push(@lib.Instruction::local_get(bridge_array_local(capacity)))
  grow.push(@lib.Instruction::struct_set(wrapper_type, 2U))
  body.push(@lib.Instruction::if_(@lib.BlockType::void_(), grow, None))
  bridge_array_wrapper_get(body, wrapper_type, 0, 0U)
  body.push(bridge_array_ref_cast(array_type))
  body.push(@lib.Instruction::local_get(bridge_array_local(length)))
  body.push(@lib.Instruction::local_get(bridge_array_local(1)))
  body.push(@lib.Instruction::array_set(array_type))
  bridge_array_wrapper_set_prefix(body, wrapper_type, 0)
  body.push(@lib.Instruction::local_get(bridge_array_local(length)))
  body.push(@lib.Instruction::i32_const(@lib.I32::new(1)))
  body.push(@lib.Instruction::i32_add())
  body.push(@lib.Instruction::struct_set(wrapper_type, 1U))
  @lib.Func::new(
    @lib.Locals::from_types([
      @lib.ValType::eqref_null(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::eqref_null(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
fn bridge_array_get_unchecked_body(base : Int, carrier : Int) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let array_type = bridge_array_type(base, carrier)
  let body : Array[@lib.Instruction] = []
  bridge_array_wrapper_get(body, wrapper_type, 0, 0U)
  body.push(bridge_array_ref_cast(array_type))
  body.push(@lib.Instruction::local_get(bridge_array_local(1)))
  body.push(@lib.Instruction::array_get(array_type))
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
}

///|
fn bridge_array_set_unchecked_body(base : Int, carrier : Int) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let array_type = bridge_array_type(base, carrier)
  let body : Array[@lib.Instruction] = []
  bridge_array_wrapper_get(body, wrapper_type, 0, 0U)
  body.push(bridge_array_ref_cast(array_type))
  body.push(@lib.Instruction::local_get(bridge_array_local(1)))
  body.push(@lib.Instruction::local_get(bridge_array_local(2)))
  body.push(@lib.Instruction::array_set(array_type))
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
}

///|
fn bridge_array_get_body(
  base : Int,
  carrier : Int,
  none_type_index : Int,
  some_type_index : Int,
) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let array_type = bridge_array_type(base, carrier)
  let none_type = @lib.TypeIdx::new(none_type_index.reinterpret_as_uint())
  let some_type = @lib.TypeIdx::new(some_type_index.reinterpret_as_uint())
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(bridge_array_local(1)),
  ]
  bridge_array_wrapper_get(body, wrapper_type, 0, 1U)
  body.push(@lib.Instruction::i32_lt_u())
  let success : Array[@lib.Instruction] = []
  bridge_array_wrapper_get(success, wrapper_type, 0, 0U)
  success.push(bridge_array_ref_cast(array_type))
  success.push(@lib.Instruction::local_get(bridge_array_local(1)))
  success.push(@lib.Instruction::array_get(array_type))
  success.push(@lib.Instruction::struct_new(some_type))
  body.push(
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::eqref_null()),
      success,
      Some([@lib.Instruction::struct_new(none_type)]),
    ),
  )
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
}

///|
fn bridge_array_pop_body(
  base : Int,
  carrier : Int,
  none_type_index : Int,
  some_type_index : Int,
) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let array_type = bridge_array_type(base, carrier)
  let none_type = @lib.TypeIdx::new(none_type_index.reinterpret_as_uint())
  let some_type = @lib.TypeIdx::new(some_type_index.reinterpret_as_uint())
  let length = 1
  let body : Array[@lib.Instruction] = []
  bridge_array_wrapper_get(body, wrapper_type, 0, 1U)
  body.push(@lib.Instruction::local_set(bridge_array_local(length)))
  body.push(@lib.Instruction::local_get(bridge_array_local(length)))
  body.push(@lib.Instruction::i32_eqz())
  let success : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(bridge_array_local(length)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::local_set(bridge_array_local(length)),
  ]
  bridge_array_wrapper_set_prefix(success, wrapper_type, 0)
  success.push(@lib.Instruction::local_get(bridge_array_local(length)))
  success.push(@lib.Instruction::struct_set(wrapper_type, 1U))
  bridge_array_wrapper_get(success, wrapper_type, 0, 0U)
  success.push(bridge_array_ref_cast(array_type))
  success.push(@lib.Instruction::local_get(bridge_array_local(length)))
  success.push(@lib.Instruction::array_get(array_type))
  success.push(@lib.Instruction::struct_new(some_type))
  body.push(
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::eqref_null()),
      [@lib.Instruction::struct_new(none_type)],
      Some(success),
    ),
  )
  @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::i32()]),
    @lib.Expr::new(body),
  )
}

///|
fn bridge_array_iter_body(base : Int) -> @lib.Func {
  let iterator_type = @lib.TypeIdx::new((base + 7).reinterpret_as_uint())
  @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::local_get(bridge_array_local(0)),
      @lib.Instruction::i32_const(@lib.I32::new(0)),
      @lib.Instruction::struct_new(iterator_type),
    ]),
  )
}

///|
fn bridge_array_iter_has_next_body(base : Int) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let iterator_type = @lib.TypeIdx::new((base + 7).reinterpret_as_uint())
  @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::local_get(bridge_array_local(0)),
      bridge_array_ref_cast(iterator_type),
      @lib.Instruction::struct_get(iterator_type, 1U),
      @lib.Instruction::local_get(bridge_array_local(0)),
      bridge_array_ref_cast(iterator_type),
      @lib.Instruction::struct_get(iterator_type, 0U),
      bridge_array_ref_cast(wrapper_type),
      @lib.Instruction::struct_get(wrapper_type, 1U),
      @lib.Instruction::i32_lt_u(),
    ]),
  )
}

///|
pub fn instructions_push_array_iter_next(
  values : Array[@lib.Instruction],
  base : Int,
  carrier : Int,
  local : Int,
) -> Unit {
  let wrapper_type = bridge_array_wrapper_type(base)
  let iterator_type = @lib.TypeIdx::new((base + 7).reinterpret_as_uint())
  let array_type = bridge_array_type(base, carrier)
  let none_type = @lib.TypeIdx::new((base + 10).reinterpret_as_uint())
  let some_type = @lib.TypeIdx::new((base + 11 + carrier).reinterpret_as_uint())
  let scratch = bridge_array_local(local)
  values.push(@lib.Instruction::local_set(scratch))
  let condition : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(scratch),
    bridge_array_ref_cast(iterator_type),
    @lib.Instruction::struct_get(iterator_type, 1U),
    @lib.Instruction::local_get(scratch),
    bridge_array_ref_cast(iterator_type),
    @lib.Instruction::struct_get(iterator_type, 0U),
    bridge_array_ref_cast(wrapper_type),
    @lib.Instruction::struct_get(wrapper_type, 1U),
    @lib.Instruction::i32_lt_u(),
  ]
  let success : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(scratch),
    bridge_array_ref_cast(iterator_type),
    @lib.Instruction::struct_get(iterator_type, 0U),
    bridge_array_ref_cast(wrapper_type),
    @lib.Instruction::struct_get(wrapper_type, 0U),
    bridge_array_ref_cast(array_type),
    @lib.Instruction::local_get(scratch),
    bridge_array_ref_cast(iterator_type),
    @lib.Instruction::local_get(scratch),
    bridge_array_ref_cast(iterator_type),
    @lib.Instruction::struct_get(iterator_type, 1U),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::struct_set(iterator_type, 1U),
    @lib.Instruction::local_get(scratch),
    bridge_array_ref_cast(iterator_type),
    @lib.Instruction::struct_get(iterator_type, 1U),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::array_get(array_type),
    @lib.Instruction::struct_new(some_type),
  ]
  values.append(condition)
  values.push(
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::eqref_null()),
      success,
      Some([@lib.Instruction::struct_new(none_type)]),
    ),
  )
}

///|
fn bridge_array_iter_next_option_body(base : Int, carrier : Int) -> @lib.Func {
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(bridge_array_local(0)),
  ]
  instructions_push_array_iter_next(body, base, carrier, 1)
  @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::eqref_null()]),
    @lib.Expr::new(body),
  )
}

///|
fn bridge_array_iter_next_body(base : Int, carrier : Int) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let iterator_type = @lib.TypeIdx::new((base + 7).reinterpret_as_uint())
  let array_type = bridge_array_type(base, carrier)
  let index = 1
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(bridge_array_local(0)),
    bridge_array_ref_cast(iterator_type),
    @lib.Instruction::struct_get(iterator_type, 1U),
    @lib.Instruction::local_set(bridge_array_local(index)),
    @lib.Instruction::local_get(bridge_array_local(0)),
    bridge_array_ref_cast(iterator_type),
    @lib.Instruction::local_get(bridge_array_local(index)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::struct_set(iterator_type, 1U),
    @lib.Instruction::local_get(bridge_array_local(0)),
    bridge_array_ref_cast(iterator_type),
    @lib.Instruction::struct_get(iterator_type, 0U),
    bridge_array_ref_cast(wrapper_type),
    @lib.Instruction::struct_get(wrapper_type, 0U),
    bridge_array_ref_cast(array_type),
    @lib.Instruction::local_get(bridge_array_local(index)),
    @lib.Instruction::array_get(array_type),
  ]
  @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::i32()]),
    @lib.Expr::new(body),
  )
}

///|
fn bridge_array_truncate_body(base : Int) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(bridge_array_local(1)),
  ]
  bridge_array_wrapper_get(body, wrapper_type, 0, 1U)
  body.push(@lib.Instruction::i32_lt_u())
  let truncate : Array[@lib.Instruction] = []
  bridge_array_wrapper_set_prefix(truncate, wrapper_type, 0)
  truncate.push(@lib.Instruction::local_get(bridge_array_local(1)))
  truncate.push(@lib.Instruction::struct_set(wrapper_type, 1U))
  body.push(@lib.Instruction::if_(@lib.BlockType::void_(), truncate, None))
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
}

///|
fn bridge_array_clear_body(base : Int) -> @lib.Func {
  let wrapper_type = bridge_array_wrapper_type(base)
  let body : Array[@lib.Instruction] = []
  bridge_array_wrapper_set_prefix(body, wrapper_type, 0)
  body.push(@lib.Instruction::i32_const(@lib.I32::new(0)))
  body.push(@lib.Instruction::struct_set(wrapper_type, 1U))
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
}

///|
fn emit_bridge_array_runtime_function(
  name : Bytes,
  base : Int,
  carrier : Int,
  none_type : Int,
  some_type : Int,
) -> @lib.Func? {
  if name == b"dew_array_new" {
    Some(bridge_array_new_body(base, false))
  } else if name == b"dew_array_with_capacity" {
    Some(bridge_array_new_body(base, true))
  } else if name == b"dew_array_make" {
    Some(bridge_array_make_body(base, carrier))
  } else if name == b"dew_array_length" {
    Some(bridge_array_field_body(base, 1U))
  } else if name == b"dew_array_capacity" {
    Some(bridge_array_field_body(base, 2U))
  } else if name == b"dew_array_backing_length_i32" {
    Some(bridge_array_backing_length_body(base, 0))
  } else if name == b"dew_array_backing_length_ref" {
    Some(bridge_array_backing_length_body(base, 5))
  } else if name == b"dew_array_push" {
    Some(bridge_array_push_body(base, carrier))
  } else if name == b"dew_array_get" {
    Some(bridge_array_get_body(base, carrier, none_type, some_type))
  } else if name == b"dew_array_get_unchecked" {
    Some(bridge_array_get_unchecked_body(base, carrier))
  } else if name == b"dew_array_set_unchecked" {
    Some(bridge_array_set_unchecked_body(base, carrier))
  } else if name == b"dew_array_pop" {
    Some(bridge_array_pop_body(base, carrier, none_type, some_type))
  } else if name == b"dew_array_iter" {
    Some(bridge_array_iter_body(base))
  } else if name == b"dew_array_iter_has_next" {
    Some(bridge_array_iter_has_next_body(base))
  } else if name == b"dew_array_iter_next" {
    Some(bridge_array_iter_next_body(base, carrier))
  } else if name == b"dew_array_iter_next_option" {
    Some(bridge_array_iter_next_option_body(base, carrier))
  } else if name == b"dew_array_truncate" {
    Some(bridge_array_truncate_body(base))
  } else if name == b"dew_array_clear" {
    Some(bridge_array_clear_body(base))
  } else {
    None
  }
}

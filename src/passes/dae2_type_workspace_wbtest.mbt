///|
test "DAE2 type workspace appends private signatures without changing source groups" {
  let original = @lib.TypeSec::new([
    @lib.RecType::group([
      @lib.SubType::comp_type(@lib.CompType::struct_([])),
      @lib.SubType::comp_type(@lib.CompType::func([], [])),
    ]),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  ])
  let saved = original
  let workspace = Dae2TypeWorkspace::new(original)
  let shared = @lib.TypeMetadata::new(shared=true)
  assert_eq(
    workspace.append_signature(
      [@lib.ValType::i64()],
      [@lib.ValType::i32()],
      shared,
    ),
    @lib.TypeIdx::new(3U),
  )
  assert_eq(workspace.flat_count, 4)
  assert_eq(original, saved)
  assert_eq(dae_type_sec_flattened_length(original), 3)
  let lower : HotPipelineLowerState = {
    next_type_sec: Some(workspace.types),
    type_sec_changed: false,
  }
  assert_eq(
    run_hot_pipeline_lower_intern_block_result_type_idx(lower, [
      @lib.ValType::i32(),
      @lib.ValType::i64(),
    ]),
    @lib.TypeIdx::new(4U),
  )
  workspace.adopt_lower_types(lower)
  assert_eq(workspace.flat_count, 5)
  assert_eq(
    workspace.append_signature(
      [],
      [@lib.ValType::i64()],
      @lib.TypeMetadata::new(),
    ),
    @lib.TypeIdx::new(5U),
  )
  assert_eq(workspace.flat_count, 6)
  let @lib.TypeSec(groups) = workspace.types
  assert_eq(groups.length(), 5)
  let private_ = match groups[2] {
    @lib.SingleRecType(subtype) => subtype
    _ => fail("expected private singleton signature")
  }
  assert_eq(private_.metadata(), shared)
  assert_eq(
    private_.get_comptype(),
    @lib.CompType::func([@lib.ValType::i64()], [@lib.ValType::i32()]),
  )
  assert_eq(dae_type_sec_flattened_length(original), 3)
}

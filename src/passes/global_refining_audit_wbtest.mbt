///|
test "audit global refining joins distinct shared heap observations" {
  let shared = @lib.TypeMetadata::new(shared=true)
  let input = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::struct_([]), metadata=shared),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::array(
            @lib.FieldType::new(
              @lib.StorageType::val_type(@lib.ValType::i32()),
              @lib.Mut::var_(),
            ),
          ),
          metadata=shared,
        ),
      ),
    ]),
  )
  let env = @validate.Env::new().with_module(input)
  let left = @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U)))
  let right = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let noted : Array[@lib.RefType?] = [None]
  let scratch = GrNominalAncestryScratch::new(env)
  gr_note_ref_type(noted, 0, left, env, scratch)
  gr_note_ref_type(noted, 0, right, env, scratch)
  assert_true(@validate.Match::matches(left, noted[0].unwrap(), env))
  assert_true(@validate.Match::matches(right, noted[0].unwrap(), env))
}

///|
test "Local CSE indexes argument-free idempotent annotations by function" {
  let flags = lcse_raw_idempotent_annotation_flags(
    Some(
      @lib.FuncAnnotationSec::new([
        @lib.FuncAnnotationAssoc::new(1U, [
          @lib.FuncAnnotation::new("binaryen.idempotent", args=["x"]),
        ]),
        @lib.FuncAnnotationAssoc::new(1U, [
          @lib.FuncAnnotation::new("binaryen.idempotent"),
        ]),
        @lib.FuncAnnotationAssoc::new(2U, [
          @lib.FuncAnnotation::new("binaryen.js.called"),
        ]),
        @lib.FuncAnnotationAssoc::new(5U, [
          @lib.FuncAnnotation::new("binaryen.idempotent"),
        ]),
      ]),
    ),
    3,
  )
  assert_eq(flags, [false, true, false])
}

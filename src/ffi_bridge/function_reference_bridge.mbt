///|
pub(all) struct FunctionReferenceBuilder {
  functions : Array[@lib.FuncIdx]
}

///|
pub fn function_reference_builder_new() -> FunctionReferenceBuilder {
  { functions: [] }
}

///|
pub fn FunctionReferenceBuilder::push(
  self : FunctionReferenceBuilder,
  function_index : Int,
) -> Unit {
  self.functions.push(
    @lib.FuncIdx::new(function_index.reinterpret_as_uint()),
  )
}

///|
pub fn module_with_declarative_functions(
  module_ : @lib.Module,
  builder : FunctionReferenceBuilder,
) -> @lib.Module {
  if builder.functions.length() == 0 {
    module_
  } else {
    module_.with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs(builder.functions),
        ),
      ]),
    )
  }
}

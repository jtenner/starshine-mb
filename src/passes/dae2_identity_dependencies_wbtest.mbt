///|
fn dae2_identity_dependency_ref(index : @lib.TypeIdx) -> @lib.ValType {
  @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(index), exact=true),
  )
}

///|
fn dae2_identity_dependency_cases() -> Array[@lib.SubType] {
  let ref0 = dae2_identity_dependency_ref(@lib.TypeIdx::new(0U))
  let ref1 = dae2_identity_dependency_ref(@lib.TypeIdx::rec(1U))
  let nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let packed = @lib.FieldType::new(
    @lib.StorageType::pack_type(@lib.PackType::i8()),
    @lib.Mut::var_(),
  )
  let field = @lib.FieldType::new(
    @lib.StorageType::val_type(ref1),
    @lib.Mut::const_(),
  )
  let metadata = @lib.TypeMetadata::new(
    describes=Some(@lib.TypeIdx::rec(0U)),
    descriptor=Some(@lib.TypeIdx::new(1U)),
    shared=true,
  )
  [
    @lib.SubType::new(
      false,
      [@lib.TypeIdx::new(0U), @lib.TypeIdx::rec(1U)],
      @lib.CompType::func(
        [@lib.ValType::i32(), ref0, ref1],
        [nullable, ref0],
      ),
      metadata~,
    ),
    @lib.SubType::comp_type(
      @lib.CompType::struct_([packed, field, field]),
      metadata~,
    ),
    @lib.SubType::comp_type(@lib.CompType::array(field), metadata~),
    @lib.SubType::comp_type(
      @lib.CompType::cont(@lib.TypeIdx::rec(1U)),
      metadata~,
    ),
    @lib.SubType::comp_type(@lib.CompType::array(packed)),
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i64(), @lib.ValType::externref()],
        [
          @lib.ValType::ref_type(
            @lib.RefType::new(
              true,
              @lib.HeapType::shared_abs(@lib.AbsHeapType::func()),
            ),
          ),
        ],
      ),
    ),
  ]
}

///|
// Keep the former dependency construction here as a differential reference.
fn dae2_identity_dependency_reference(
  types : @lib.TypeSec,
  total : Int32,
  embedded : Array[Bool],
) -> Dae2Graph {
  let graph = Dae2Graph::new()
  for _ in 0..<total {
    ignore(graph.location())
  }
  let @lib.TypeSec(groups) = types
  let mut base = 0
  for group in groups {
    let members = match group {
      @lib.SingleRecType(subtype) => [subtype]
      @lib.GroupRecType(members) => members
    }
    for offset in 0..<members.length() {
      let owner = base + offset
      graph.edge(owner, base)
      graph.edge(base, owner)
      ignore(
        dae2_identity_subtype(
          members[offset],
          fn(index) {
            graph.edge(owner, dae2_type_slot(index, base))
            index
          },
          embedded,
        ),
      )
    }
    base += members.length()
  }
  graph
}

///|
test "DAE2 identity dependency visitor retains every reference in order" {
  let expected = [
    [0, 11, 1, 0, 10, 1, 0, 11],
    [11, 11, 10, 1],
    [11, 10, 1],
    [11, 10, 1],
    [],
    [],
  ]
  for slot, subtype in dae2_identity_dependency_cases() {
    let actual : Array[Int32] = []
    let reference : Array[Int32] = []
    let embedded = [false]
    let reference_embedded = [false]
    dae2_identity_visit_subtype(
      subtype,
      fn(index) { actual.push(dae2_type_slot(index, 10)) },
      embedded,
    )
    ignore(
      dae2_identity_subtype(
        subtype,
        fn(index) {
          reference.push(dae2_type_slot(index, 10))
          index
        },
        reference_embedded,
      ),
    )
    assert_eq(actual, expected[slot])
    assert_eq(actual, reference)
    assert_eq(embedded, reference_embedded)
    assert_false(embedded[0])
  }
}

///|
test "DAE2 identity dependencies preserve complete rows and solved observations" {
  let cases = dae2_identity_dependency_cases()
  // The leading singletons give the group a nonzero base for relative indices.
  let types = @lib.TypeSec::new([
    @lib.RecType::new(cases[4]),
    @lib.RecType::new(cases[5]),
    @lib.RecType::group(cases),
  ])
  for seed in 0..<8 {
    let embedded = [false]
    let reference_embedded = [false]
    let actual = dae2_identity_dependencies(types, 8, embedded)
    let reference = dae2_identity_dependency_reference(
      types, 8, reference_embedded,
    )
    assert_eq(actual.edges, reference.edges)
    assert_eq(actual.next_edge, reference.next_edge)
    assert_eq(actual.first_edge, reference.first_edge)
    assert_eq(actual.last_edge, reference.last_edge)
    assert_eq(embedded, reference_embedded)
    actual.observe(seed)
    reference.observe(seed)
    actual.solve()
    reference.solve()
    assert_eq(actual.used, reference.used)
    assert_eq(actual.work, reference.work)
    assert_eq(actual.cursor, reference.cursor)
  }
}

///|
test "DAE2 identity dependency visitor flags embedded definitions and keeps later edges" {
  let embedded_value = @lib.ValType::ref_type(
    @lib.RefType::new(
      true,
      @lib.HeapType::def_type(
        @lib.DefType::new(
          @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
          0U,
        ),
      ),
    ),
  )
  let embedded_field = @lib.FieldType::new(
    @lib.StorageType::val_type(embedded_value),
    @lib.Mut::var_(),
  )
  for comp in [
    @lib.CompType::func([embedded_value], [embedded_value]),
    @lib.CompType::struct_([embedded_field]),
    @lib.CompType::array(embedded_field),
  ] {
    let types = @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(
          true,
          [@lib.TypeIdx::new(1U)],
          comp,
          metadata=@lib.TypeMetadata::new(
            describes=Some(@lib.TypeIdx::new(1U)),
            descriptor=Some(@lib.TypeIdx::new(0U)),
          ),
        ),
      ),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ])
    let embedded = [false]
    let reference_embedded = [false]
    let actual = dae2_identity_dependencies(types, 2, embedded)
    let reference = dae2_identity_dependency_reference(
      types, 2, reference_embedded,
    )
    assert_true(embedded[0])
    assert_eq(embedded, reference_embedded)
    assert_eq(actual.edges, reference.edges)
    assert_eq(actual.edges, [0, 0, 1, 0, 1, 1, 1])
    assert_eq(actual.first_edge, reference.first_edge)
    assert_eq(actual.last_edge, reference.last_edge)
    assert_eq(actual.next_edge, reference.next_edge)
    let graph = Dae2Graph::new()
    let info = Dae2Function::new(graph, [@lib.ValType::i32()], [])
    assert_false(graph.used[info.param_locations[0]])
    dae2_preserve_type_identity(types, graph, [info], [-1, 0])
    assert_true(graph.used[info.param_locations[0]])
    assert_true(graph.used[info.result_location])
  }
}

///|
test "DAE2 unchanged identity family keeps its solved graph" {
  let types = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
      ),
    ),
  ])
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(
    graph, [@lib.ValType::i32()], [@lib.ValType::i32()],
  )
  graph.observe(info.param_locations[0])
  graph.observe(info.result_location)
  graph.solve()
  let work = graph.work.copy()
  let cursor = graph.cursor
  dae2_preserve_type_identity(types, graph, [info], [0])
  assert_eq(graph.work, work)
  assert_eq(graph.cursor, cursor)
  assert_true(graph.edges.is_empty())
}

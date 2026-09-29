///|
fn dae2_type_append_reference(
  original : @lib.TypeSec,
  additions : Int,
) -> (@lib.TypeSec, Int) {
  let mut types = original
  let mut checksum = 0
  for index in 0..<additions {
    let @lib.TypeSec(groups) = types
    let next = groups.copy()
    // The previous production path also counts every group for each append.
    let slot = dae_type_sec_flattened_length(types)
    next.push(
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(
            [@lib.ValType::i32()],
            if index % 2 == 0 {
              []
            } else {
              [@lib.ValType::i32()]
            },
          ),
        ),
      ),
    )
    checksum += slot
    types = @lib.TypeSec::new(next)
  }
  (types, checksum)
}

///|
fn dae2_type_append_workspace(
  original : @lib.TypeSec,
  additions : Int,
) -> (@lib.TypeSec, Int) {
  let workspace = Dae2TypeWorkspace::new(original)
  let mut checksum = 0
  for index in 0..<additions {
    checksum += dae2_type_slot(
      workspace.append_signature(
        [@lib.ValType::i32()],
        if index % 2 == 0 {
          []
        } else {
          [@lib.ValType::i32()]
        },
        @lib.TypeMetadata::new(),
      ),
      0,
    )
  }
  (workspace.types, checksum)
}

///|
fn dae2_type_append_bench(
  it : @bench.T,
  additions : Int,
  workspace : Bool,
) -> Unit {
  let original = @lib.TypeSec::new(
    Array::makei(128, fn(_) {
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], [])))
    }),
  )
  let expected = dae2_type_append_reference(original, additions)
  let actual = dae2_type_append_workspace(original, additions)
  if actual != expected {
    abort("type workspace changed signature metadata or numbering")
  }
  let (actual_types, _) = actual
  @validate.validate_module(@lib.Module::new().with_type_sec(actual_types)).unwrap()
  let action = if workspace {
    dae2_type_append_workspace
  } else {
    dae2_type_append_reference
  }
  it.bench(fn() { it.keep(action(original, additions)) })
  if dae_type_sec_flattened_length(original) != 128 {
    abort("type workspace changed the input groups")
  }
}

///|
fn dae2_leaf_keep_reference(func : @ir.HotFunc, node : Int) -> Int {
  let children = @ir.hot_child_span(func, node).map(fn(child) { child })
  ignore(dae2_replace_children_if_changed(func, node, children))
  node
}

///|
fn dae2_leaf_keep_bench(it : @bench.T, leaves : Int, scalar : Bool) -> Unit {
  let func = @ir.HotFunc::new()
  let nodes = Array::makei(leaves, fn(index) {
    @ir.hot_build_const_i32(func, @lib.I32(index))
  })
  let revision = @ir.hot_revision_current(func)
  for node in nodes {
    if dae2_rewrite_leaf(func, node, @ir.hot_node_get(func, node), true) !=
      dae2_leaf_keep_reference(func, node) {
      abort("leaf rewrite changed a retained value")
    }
  }
  it.bench(fn() {
    let mut sum = 0
    for node in nodes {
      sum += if scalar {
        dae2_rewrite_leaf(func, node, @ir.hot_node_get(func, node), true)
      } else {
        dae2_leaf_keep_reference(func, node)
      }
    }
    it.keep(sum)
  })
  if @ir.hot_revision_current(func) != revision {
    abort("retained leaf benchmark mutated HOT")
  }
}

///|
test "bench DAE2 copied types additions=128" (it : @bench.T) {
  dae2_type_append_bench(it, 128, false)
}

///|
test "bench DAE2 owned types additions=128" (it : @bench.T) {
  dae2_type_append_bench(it, 128, true)
}

///|
test "bench DAE2 copied types additions=2048" (it : @bench.T) {
  dae2_type_append_bench(it, 2048, false)
}

///|
test "bench DAE2 owned types additions=2048" (it : @bench.T) {
  dae2_type_append_bench(it, 2048, true)
}

///|
test "bench DAE2 array leaf rewrite leaves=4096" (it : @bench.T) {
  dae2_leaf_keep_bench(it, 4096, false)
}

///|
test "bench DAE2 scalar leaf rewrite leaves=4096" (it : @bench.T) {
  dae2_leaf_keep_bench(it, 4096, true)
}

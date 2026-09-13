///|
// Runtime type identity includes the entire recursive group. Use canonical
// external identities and relative internal references as structural keys.
fn dae2_identity_value(
  value : @lib.ValType,
  remap : (@lib.TypeIdx) -> @lib.TypeIdx,
  embedded : Array[Bool],
) -> @lib.ValType {
  match value {
    @lib.RefTypeValType(rt) => {
      let heap = match rt.get_heap_type() {
        @lib.HeapType(index) => @lib.HeapType::new(remap(index))
        @lib.DefTypeHeapType(_) as heap => {
          // Embedded definitions do not have a module-owned identity closure.
          embedded[0] = true
          heap
        }
        heap => heap
      }
      @lib.ValType::ref_type(@lib.RefType::new(rt.is_nullable(), heap, exact=rt.is_exact()))
    }
    _ => value
  }
}

///|
fn dae2_identity_field(
  field : @lib.FieldType,
  remap : (@lib.TypeIdx) -> @lib.TypeIdx,
  embedded : Array[Bool],
) -> @lib.FieldType {
  let @lib.FieldType(storage, mutable_) = field
  let storage = match storage {
    @lib.ValTypeStorageType(value) =>
      @lib.StorageType::val_type(dae2_identity_value(value, remap, embedded))
    _ => storage
  }
  @lib.FieldType::new(storage, mutable_)
}

///|
fn dae2_identity_subtype(
  subtype : @lib.SubType,
  remap : (@lib.TypeIdx) -> @lib.TypeIdx,
  embedded : Array[Bool],
) -> @lib.SubType {
  let comp = match subtype.get_comptype() {
    @lib.FuncCompType(params, results) => @lib.CompType::func(
      params.map(fn(v) { dae2_identity_value(v, remap, embedded) }),
      results.map(fn(v) { dae2_identity_value(v, remap, embedded) }),
    )
    @lib.StructCompType(fields) => @lib.CompType::struct_(
      fields.map(fn(f) { dae2_identity_field(f, remap, embedded) }),
    )
    @lib.ArrayCompType(field) => @lib.CompType::array(dae2_identity_field(field, remap, embedded))
    @lib.ContCompType(target) => @lib.CompType::cont(remap(target))
  }
  let { describes, descriptor, shared, } = subtype.metadata()
  let metadata = @lib.TypeMetadata::new(
    describes=describes.map(remap), descriptor=descriptor.map(remap), shared~,
  )
  // A bare composite type has the binary meaning of a final subtype without
  // declared supertypes; singleton rec syntax does not change its identity.
  let final_ = match subtype {
    @lib.SubType(final_, _, _, _) => final_
    @lib.CompTypeSubType(_, _) => true
  }
  @lib.SubType::new(final_, subtype.super_types().map(remap), comp, metadata~)
}

///|
fn dae2_identity_partition(types : @lib.TypeSec) -> Array[Int] {
  let @lib.TypeSec(groups) = types
  let identities : Array[Int] = []
  let interned : @hashmap.HashMap[Array[@lib.SubType], Int] = @hashmap.new()
  let embedded = [false]
  for group in groups {
    let members = match group {
      @lib.SingleRecType(subtype) => [subtype]
      @lib.GroupRecType(members) => members
    }
    let base = identities.length()
    let end = base + members.length()
    let remap = fn(index : @lib.TypeIdx) -> @lib.TypeIdx {
      match index {
        @lib.RecIdx(_) => index
        @lib.TypeIdx(raw) => {
          let slot = raw.reinterpret_as_int()
          if slot >= base && slot < end {
            @lib.TypeIdx::rec((slot - base).reinterpret_as_uint())
          } else {
            @lib.TypeIdx::new(identities[slot].reinterpret_as_uint())
          }
        }
      }
    }
    let key = members.map(fn(subtype) { dae2_identity_subtype(subtype, remap, embedded) })
    let first = match interned.get(key) {
      Some(first) => first
      None => { interned.set(key, base); base }
    }
    for member = 0; member < members.length(); member = member + 1 {
      identities.push(first + member)
    }
  }
  identities
}

///|
fn dae2_identity_dependencies(
  types : @lib.TypeSec,
  total : Int,
  embedded : Array[Bool],
) -> Dae2Graph {
  let dependencies = Dae2Graph::new()
  for _ in 0..<total { ignore(dependencies.location()) }
  let @lib.TypeSec(groups) = types
  let mut base = 0
  for group in groups {
    let members = match group {
      @lib.SingleRecType(subtype) => [subtype]
      @lib.GroupRecType(members) => members
    }
    for offset = 0; offset < members.length(); offset = offset + 1 {
      let owner = base + offset
      // One member's identity depends on all siblings in its recursive group.
      dependencies.edge(owner, base)
      dependencies.edge(base, owner)
      ignore(dae2_identity_subtype(members[offset], fn(index) {
        dependencies.edge(owner, dae2_type_slot(index, base))
        index
      }, embedded))
    }
    base += members.length()
  }
  dependencies
}

///|
fn dae2_preserve_type_identity(
  types : @lib.TypeSec,
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  type_infos : Array[Int],
) -> Unit {
  if !type_infos.any(fn(index) { index >= 0 && dae2_signature_changes(graph, infos[index]) }) {
    return
  }
  let embedded = [false]
  let dependencies = dae2_identity_dependencies(types, type_infos.length(), embedded)
  if embedded[0] {
    // Type-section pruning through embedded definitions is intentionally
    // unsupported; private direct function signatures remain independently live.
    for index in type_infos {
      if index >= 0 {
        for location in infos[index].param_locations { graph.observe(location) }
        graph.observe(infos[index].result_location)
      }
    }
    graph.solve()
    return
  }
  let original = dae2_identity_partition(types)
  while true {
    let proposed = dae2_identity_partition(dae2_rewrite_type_section(types, graph, infos, type_infos))
    let old_representatives = Array::make(original.length(), -1)
    let new_representatives = Array::make(original.length(), -1)
    let mut conflict = false
    for index = 0; index < original.length(); index = index + 1 {
      let old_rep = old_representatives[original[index]]
      let new_rep = new_representatives[proposed[index]]
      if old_rep >= 0 && proposed[old_rep] != proposed[index] {
        dependencies.observe(old_rep)
        dependencies.observe(index)
        conflict = true
      }
      if new_rep >= 0 && original[new_rep] != original[index] {
        dependencies.observe(new_rep)
        dependencies.observe(index)
        conflict = true
      }
      old_representatives[original[index]] = index
      new_representatives[proposed[index]] = index
    }
    if !conflict { return }
    dependencies.solve()
    let before = graph.work.length()
    for index = 0; index < type_infos.length(); index = index + 1 {
      let info_index = type_infos[index]
      if dependencies.used[index] && info_index >= 0 {
        for location in infos[info_index].param_locations { graph.observe(location) }
        graph.observe(infos[info_index].result_location)
      }
    }
    graph.solve()
    if graph.work.length() == before {
      // A conservative full type closure is a bounded fallback if a future type
      // feature escapes the dependency inventory. It preserves all identities.
      for index in type_infos {
        if index >= 0 {
          for location in infos[index].param_locations { graph.observe(location) }
          graph.observe(infos[index].result_location)
        }
      }
      graph.solve()
      return
    }
  }
}

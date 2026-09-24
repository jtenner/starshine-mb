///|
fn gto_map_subtype_indices(
  subtype : @lib.SubType,
  rewrite : (@lib.TypeIdx) -> @lib.TypeIdx,
) -> @lib.SubType {
  let value = fn(vt : @lib.ValType) {
    match vt {
      @lib.RefTypeValType(r) =>
        match r.get_heap_type() {
          @lib.HeapType(t) =>
            @lib.ValType::ref_type(
              @lib.RefType::new(
                r.is_nullable(),
                @lib.HeapType::new(rewrite(t)),
                exact=r.is_exact(),
              ),
            )
          _ => vt
        }
      _ => vt
    }
  }
  let field = fn(f : @lib.FieldType) {
    let @lib.FieldType(storage, mutability) = f
    match storage {
      @lib.ValTypeStorageType(vt) =>
        @lib.FieldType::new(@lib.StorageType::val_type(value(vt)), mutability)
      _ => f
    }
  }
  let comp = match subtype.get_comptype() {
    @lib.StructCompType(fields) => @lib.CompType::struct_(fields.map(field))
    @lib.ArrayCompType(f) => @lib.CompType::array(field(f))
    @lib.FuncCompType(params, results) =>
      @lib.CompType::func(params.map(value), results.map(value))
    @lib.ContCompType(t) => @lib.CompType::cont(rewrite(t))
  }
  let metadata = @lib.TypeMetadata::new(
    describes=subtype.describes_type().map(rewrite),
    descriptor=subtype.descriptor_type().map(rewrite),
    shared=subtype.metadata().is_shared(),
  )
  match subtype {
    @lib.SubType(final_, supers, _, _) =>
      @lib.SubType::new(final_, supers.map(rewrite), comp, metadata~)
    @lib.CompTypeSubType(_, _) => @lib.SubType::new(true, [], comp, metadata~)
  }
}

///|
fn gto_remap_type_names(
  mod_ : @lib.Module,
  remap : Map[UInt, UInt],
) -> @lib.Module {
  let names = match mod_.name_sec {
    Some(n) => n
    None => return mod_
  }
  let type_names = names.type_names.map(fn(n) {
    dfe_rewrite_name_map_filtered(n, remap, true)
  })
  let field_names = names.field_names.map(fn(n) {
    let @lib.IndirectNameMap(entries) = n
    let seen : Map[UInt, Bool] = Map([])
    let out : Array[@lib.IndirectNameAssoc] = []
    for @lib.IndirectNameAssoc(t, fields) in entries {
      guard remap.get(t) is Some(next) else { continue }
      if seen.get(next) is None {
        out.push(@lib.IndirectNameAssoc::new(next, fields))
        seen[next] = true
      }
    }
    out.sort_by(fn(a, b) {
      let @lib.IndirectNameAssoc(a, _) = a
      let @lib.IndirectNameAssoc(b, _) = b
      a.compare(b)
    })
    @lib.IndirectNameMap::new(out)
  })
  mod_.with_name_sec(
    @lib.NameSec::new(
      module_name=names.module_name,
      func_names=names.func_names,
      local_names=names.local_names,
      label_names=names.label_names,
      type_names~,
      field_names~,
      table_names=names.table_names,
      memory_names=names.memory_names,
      global_names=names.global_names,
      elem_names=names.elem_names,
      data_names=names.data_names,
      tag_names=names.tag_names,
    ),
  )
}

///|
// Canonicalize original identities before changing layouts: two equivalent
// input recursion groups must remain equivalent after private types regroup.
fn gto_canonicalize_types(mod_ : @lib.Module) -> @lib.Module {
  let recs = match mod_.type_sec {
    Some(@lib.TypeSec(rs)) => rs
    None => return mod_
  }
  let canonical : Map[Array[@lib.SubType], Int] = Map([])
  let remap : Map[UInt, UInt] = Map([])
  let out : Array[@lib.RecType] = []
  let mut old_base = 0
  let mut next_base = 0
  for rec in recs {
    let group = match rec {
      @lib.SingleRecType(t) => [t]
      @lib.GroupRecType(g) => g
    }
    let normalized = group.map(fn(t) {
      gto_map_subtype_indices(t, fn(idx) {
        let absolute = dae2_type_slot(idx, old_base)
        if absolute >= old_base && absolute < old_base + group.length() {
          @lib.TypeIdx::rec((absolute - old_base).to_uint())
        } else {
          @lib.TypeIdx::new(
            remap.get(absolute.to_uint()).unwrap_or(absolute.to_uint()),
          )
        }
      })
    })
    let existing = canonical.get(normalized)
    let target = existing.unwrap_or(next_base)
    for i = 0; i < group.length(); i = i + 1 {
      remap[(old_base + i).to_uint()] = (target + i).to_uint()
    }
    if existing is None {
      canonical[normalized] = target
      let absolute = normalized.map(fn(t) {
        gto_map_subtype_indices(t, fn(idx) {
          match idx {
            @lib.RecIdx(i) => @lib.TypeIdx::new((target + i.to_int()).to_uint())
            _ => idx
          }
        })
      })
      out.push(
        if group.length() == 1 {
          @lib.RecType::new(absolute[0])
        } else {
          @lib.RecType::group(absolute)
        },
      )
      next_base += group.length()
    }
    old_base += group.length()
  }
  let next = dfe_rewrite_module_type_idxs(mod_, remap).with_type_sec(
    @lib.TypeSec::new(out),
  )
  gto_remap_type_names(next, remap)
}

///|
// Public groups retain their recursive identity. All private identities share
// one group, with distinct projection indices even when layouts become equal.
fn gto_regroup_private_types(
  mod_ : @lib.Module,
  public_ : Array[Bool],
  type_order : Array[Int],
) -> @lib.Module {
  let recs = mod_.type_sec.unwrap().0
  let live : Map[Int, Bool] = Map([])
  for i in gto_collect_type_order(mod_) {
    live[i] = true
  }
  let public_groups : Array[@lib.RecType] = []
  let private_types : Array[@lib.SubType] = []
  let private_old : Array[Int] = []
  let remap : Map[UInt, UInt] = Map([])
  let mut old_base = 0
  let mut new_base = 0
  for rec in recs {
    let group = match rec {
      @lib.SingleRecType(t) => [t]
      @lib.GroupRecType(g) => g
    }
    let absolute = group.map(fn(t) {
      gto_map_subtype_indices(t, fn(idx) {
        @lib.TypeIdx::new(dae2_type_slot(idx, old_base).to_uint())
      })
    })
    if public_[old_base] {
      for i = 0; i < group.length(); i = i + 1 {
        remap[(old_base + i).to_uint()] = (new_base + i).to_uint()
      }
      public_groups.push(
        if group.length() == 1 {
          @lib.RecType::new(absolute[0])
        } else {
          @lib.RecType::group(absolute)
        },
      )
      new_base += group.length()
    } else {
      for i, t in absolute {
        if live.get(old_base + i).unwrap_or(false) {
          private_types.push(t)
          private_old.push(old_base + i)
        }
      }
    }
    old_base += group.length()
  }
  if private_types.is_empty() {
    return mod_
  }
  // Reverse a queue-based topological order over child-to-parent edges.
  // Start independent roots in IR first-use order, as GlobalTypeRewriter does.
  let slots : Map[Int, Int] = Map([])
  for i, old in private_old {
    slots[old] = i
  }
  let predecessors : Array[Array[Int]] = private_types.map(fn(t) {
    let refs = t.super_types().copy()
    if t.describes_type() is Some(d) {
      refs.push(d)
    }
    let out : Array[Int] = []
    for p in refs {
      if slots.get(dae2_type_slot(p, 0)) is Some(slot) {
        out.push(slot)
      }
    }
    out
  })
  let incoming = Array::make(private_types.length(), 0)
  for ps in predecessors {
    for p in ps {
      incoming[p] += 1
    }
  }
  let queued = Array::make(private_types.length(), false)
  let queue : Array[Int] = []
  for old in type_order + private_old {
    if slots.get(old) is Some(i) && incoming[i] == 0 && !queued[i] {
      queue.push(i)
      queued[i] = true
    }
  }
  let mut cursor = 0
  while cursor < queue.length() {
    let i = queue[cursor]
    cursor += 1
    for p in predecessors[i] {
      incoming[p] -= 1
      if incoming[p] == 0 {
        queue.push(p)
      }
    }
  }
  if queue.length() != private_types.length() {
    return mod_
  }
  let order = queue.rev()
  let private_types = order.map(fn(i) { private_types[i] })
  let private_old = order.map(fn(i) { private_old[i] })
  for i, old in private_old {
    remap[old.to_uint()] = (new_base + i).to_uint()
  }
  let public_keys : Array[Array[@lib.SubType]] = []
  let mut base = 0
  for rec in public_groups {
    let group = match rec {
      @lib.SingleRecType(t) => [t]
      @lib.GroupRecType(g) => g
    }
    let next = group.map(fn(t) { dfe_rewrite_sub_type(t, remap) })
    public_keys.push(gto_group_key(next, base))
    base += group.length()
  }
  while public_keys.contains(
          gto_group_key(
            private_types.map(fn(t) { dfe_rewrite_sub_type(t, remap) }),
            new_base,
          ),
        ) {
    private_types.push(@lib.SubType::comp_type(@lib.CompType::struct_([])))
  }
  public_groups.push(
    if private_types.length() == 1 {
      @lib.RecType::new(private_types[0])
    } else {
      @lib.RecType::group(private_types)
    },
  )
  let next = dfe_rewrite_module_type_idxs(
    mod_.with_type_sec(@lib.TypeSec::new(public_groups)),
    remap,
  )
  gto_remap_type_names(next, remap)
}

///|
fn gto_group_key(
  group : Array[@lib.SubType],
  base : Int,
) -> Array[@lib.SubType] {
  group.map(fn(t) {
    gto_map_subtype_indices(t, fn(idx) {
      let absolute = dae2_type_slot(idx, base)
      if absolute >= base && absolute < base + group.length() {
        @lib.TypeIdx::rec((absolute - base).to_uint())
      } else {
        @lib.TypeIdx::new(absolute.to_uint())
      }
    })
  })
}

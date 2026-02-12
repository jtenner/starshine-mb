///|
let mrg_public_shape_owner = -1

///|
let mrg_max_topo_orders = 2048

///|
priv struct MRGFlatTypes {
  subtypes : Array[SubType]
  group_starts : Array[Int]
  groups : Array[Array[Int]]
  type_to_group : Array[Int]
}

///|
priv struct MRGHeapTypeInfo {
  flat : MRGFlatTypes
  private_types : Array[Int]
  public_types : Set[Int]
  public_groups : Array[Int]
  visibility_map : Map[Int, Bool]
}

///|
priv struct MRGFeatures {
  enabled : Bool
}

///|
fn MRGFeatures::new() -> MRGFeatures {
  { enabled: true }
}

///|
priv struct RecGroupShape {
  key : String
}

///|
priv struct ComparableRecGroupShape {
  key : String
}

///|
priv struct RecGroupInfo {
  id : Int
  is_public : Bool
  old_types : Array[Int]
  mut current_order : Array[Int]
  perm_orders : Array[Array[Int]]
  mut next_perm : Int
  mut brand_seed : Int
  mut brand : SubType?
  mut seen_shapes : Set[String]
  mut canonicalized : Bool
  sort_key : String
}

///|
priv struct GroupClassInfo {
  group_idx : Int
}

///|
priv struct DSU {
  parent : Array[Int]
  sizes : Array[Int]
}

///|
fn DSU::new(n : Int) -> DSU {
  let parent : Array[Int] = []
  let sizes : Array[Int] = []
  for i in 0..<n {
    parent.push(i)
    sizes.push(1)
  }
  { parent, sizes }
}

///|
fn DSU::find(self : DSU, x : Int) -> Int {
  let p = self.parent[x]
  if p == x {
    x
  } else {
    let root = self.find(p)
    self.parent[x] = root
    root
  }
}

///|
fn DSU::union(self : DSU, a : Int, b : Int) -> Int {
  let mut ra = self.find(a)
  let mut rb = self.find(b)
  if ra == rb {
    return ra
  }
  if self.sizes[ra] < self.sizes[rb] {
    let t = ra
    ra = rb
    rb = t
  }
  self.parent[rb] = ra
  self.sizes[ra] = self.sizes[ra] + self.sizes[rb]
  ra
}

///|
fn DSU::class_size(self : DSU, x : Int) -> Int {
  let r = self.find(x)
  self.sizes[r]
}

///|
fn mrg_resolve_type_idx(
  type_idx : TypeIdx,
  group_start : Int,
  total : Int,
) -> Int? {
  let idx = match type_idx {
    TypeIdx(i) => i.reinterpret_as_int()
    RecIdx(i) => group_start + i.reinterpret_as_int()
  }
  if idx < 0 || idx >= total {
    None
  } else {
    Some(idx)
  }
}

///|
fn mrg_collect_valtype_refs(
  out : Array[Int],
  vt : ValType,
  group_start : Int,
  total : Int,
) -> Unit {
  match vt {
    RefTypeValType(rt) =>
      match rt {
        HeapTypeRefType(_, ht) =>
          match ht {
            HeapType(type_idx) =>
              match mrg_resolve_type_idx(type_idx, group_start, total) {
                Some(idx) => out.push(idx)
                None => ()
              }
            _ => ()
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn mrg_collect_storage_type_refs(
  out : Array[Int],
  st : StorageType,
  group_start : Int,
  total : Int,
) -> Unit {
  match st {
    ValTypeStorageType(vt) =>
      mrg_collect_valtype_refs(out, vt, group_start, total)
    _ => ()
  }
}

///|
fn mrg_collect_subtype_refs(
  subtype : SubType,
  group_start : Int,
  total : Int,
) -> Array[Int] {
  let out : Array[Int] = []
  for super_idx in subtype.super_types() {
    match mrg_resolve_type_idx(super_idx, group_start, total) {
      Some(idx) => out.push(idx)
      None => ()
    }
  }
  match subtype.get_comptype() {
    FuncCompType(params, results) => {
      for p in params {
        mrg_collect_valtype_refs(out, p, group_start, total)
      }
      for r in results {
        mrg_collect_valtype_refs(out, r, group_start, total)
      }
    }
    StructCompType(fields) =>
      for field in fields {
        let FieldType(st, _) = field
        mrg_collect_storage_type_refs(out, st, group_start, total)
      }
    ArrayCompType(field) => {
      let FieldType(st, _) = field
      mrg_collect_storage_type_refs(out, st, group_start, total)
    }
  }
  out
}

///|
fn mrg_unique_sorted(values : Array[Int]) -> Array[Int] {
  let out = values.copy()
  out.sort()
  let dedup : Array[Int] = []
  for v in out {
    if dedup.is_empty() || dedup[dedup.length() - 1] != v {
      dedup.push(v)
    }
  }
  dedup
}

///|
fn mrg_flatten_types(type_sec : TypeSec) -> MRGFlatTypes {
  let TypeSec(recs) = type_sec
  let subtypes : Array[SubType] = []
  let group_starts : Array[Int] = []
  let groups : Array[Array[Int]] = []
  let type_to_group : Array[Int] = []
  let mut next = 0
  let mut g = 0
  for rec in recs {
    match rec {
      SingleRecType(st) => {
        subtypes.push(st)
        group_starts.push(next)
        groups.push([next])
        type_to_group.push(g)
        next += 1
      }
      GroupRecType(sts) => {
        let group : Array[Int] = []
        let start = next
        for st in sts {
          subtypes.push(st)
          group_starts.push(start)
          group.push(next)
          type_to_group.push(g)
          next += 1
        }
        groups.push(group)
      }
    }
    g += 1
  }
  { subtypes, group_starts, groups, type_to_group }
}

///|
fn mrg_collect_func_type_idx_by_func(mod : Module) -> Map[FuncIdx, TypeIdx] {
  let out : Map[FuncIdx, TypeIdx] = Map::new()
  let mut next : UInt = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(type_idx)) => {
            out[FuncIdx::new(next)] = type_idx
            next += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        out[FuncIdx::new(next)] = type_idx
        next += 1
      }
    None => ()
  }
  out
}

///|
fn mrg_collect_all_global_types(mod : Module) -> Array[GlobalType] {
  let out : Array[GlobalType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(global_type)) => out.push(global_type)
          _ => ()
        }
      }
    None => ()
  }
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(global_type, _) = global
        out.push(global_type)
      }
    None => ()
  }
  out
}

///|
fn mrg_collect_all_table_types(mod : Module) -> Array[TableType] {
  let out : Array[TableType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, TableExternType(table_type)) => out.push(table_type)
          _ => ()
        }
      }
    None => ()
  }
  match mod.table_sec {
    Some(TableSec(tables)) =>
      for table in tables {
        let Table(table_type, _) = table
        out.push(table_type)
      }
    None => ()
  }
  out
}

///|
fn mrg_collect_all_tag_types(mod : Module) -> Array[TagType] {
  let out : Array[TagType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, TagExternType(tag_type)) => out.push(tag_type)
          _ => ()
        }
      }
    None => ()
  }
  match mod.tag_sec {
    Some(TagSec(tags)) =>
      for tag in tags {
        out.push(tag)
      }
    None => ()
  }
  out
}

///|
fn mrg_mark_public_reftype(
  public_types : Set[Int],
  flat : MRGFlatTypes,
  rt : RefType,
) -> Unit {
  match rt {
    HeapTypeRefType(_, ht) =>
      match ht {
        HeapType(type_idx) =>
          match mrg_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
            Some(idx) => mrg_mark_public_type(public_types, flat, idx)
            None => ()
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn mrg_mark_public_valtype(
  public_types : Set[Int],
  flat : MRGFlatTypes,
  vt : ValType,
) -> Unit {
  match vt {
    RefTypeValType(rt) => mrg_mark_public_reftype(public_types, flat, rt)
    _ => ()
  }
}

///|
fn mrg_mark_public_type(
  public_types : Set[Int],
  flat : MRGFlatTypes,
  start_idx : Int,
) -> Unit {
  let stack : Array[Int] = [start_idx]
  while stack.length() > 0 {
    let curr = stack.pop().unwrap()
    if curr < 0 || curr >= flat.subtypes.length() || public_types.contains(curr) {
      continue
    }
    public_types.add(curr)
    let subtype = flat.subtypes[curr]
    for super_idx in subtype.super_types() {
      match
        mrg_resolve_type_idx(
          super_idx,
          flat.group_starts[curr],
          flat.subtypes.length(),
        ) {
        Some(next_idx) => stack.push(next_idx)
        None => ()
      }
    }
    match subtype.get_comptype() {
      FuncCompType(params, results) => {
        for p in params {
          match p {
            RefTypeValType(rt) =>
              match rt {
                HeapTypeRefType(_, ht) =>
                  match ht {
                    HeapType(type_idx) =>
                      match
                        mrg_resolve_type_idx(
                          type_idx,
                          flat.group_starts[curr],
                          flat.subtypes.length(),
                        ) {
                        Some(next_idx) => stack.push(next_idx)
                        None => ()
                      }
                    _ => ()
                  }
                _ => ()
              }
            _ => ()
          }
        }
        for r in results {
          match r {
            RefTypeValType(rt) =>
              match rt {
                HeapTypeRefType(_, ht) =>
                  match ht {
                    HeapType(type_idx) =>
                      match
                        mrg_resolve_type_idx(
                          type_idx,
                          flat.group_starts[curr],
                          flat.subtypes.length(),
                        ) {
                        Some(next_idx) => stack.push(next_idx)
                        None => ()
                      }
                    _ => ()
                  }
                _ => ()
              }
            _ => ()
          }
        }
      }
      StructCompType(fields) =>
        for field in fields {
          let FieldType(st, _) = field
          match st {
            ValTypeStorageType(vt) =>
              match vt {
                RefTypeValType(rt) =>
                  match rt {
                    HeapTypeRefType(_, ht) =>
                      match ht {
                        HeapType(type_idx) =>
                          match
                            mrg_resolve_type_idx(
                              type_idx,
                              flat.group_starts[curr],
                              flat.subtypes.length(),
                            ) {
                            Some(next_idx) => stack.push(next_idx)
                            None => ()
                          }
                        _ => ()
                      }
                    _ => ()
                  }
                _ => ()
              }
            _ => ()
          }
        }
      ArrayCompType(field) => {
        let FieldType(st, _) = field
        match st {
          ValTypeStorageType(vt) =>
            match vt {
              RefTypeValType(rt) =>
                match rt {
                  HeapTypeRefType(_, ht) =>
                    match ht {
                      HeapType(type_idx) =>
                        match
                          mrg_resolve_type_idx(
                            type_idx,
                            flat.group_starts[curr],
                            flat.subtypes.length(),
                          ) {
                          Some(next_idx) => stack.push(next_idx)
                          None => ()
                        }
                      _ => ()
                    }
                  _ => ()
                }
              _ => ()
            }
          _ => ()
        }
      }
    }
  }
}

///|
fn collect_heap_type_info(mod : Module) -> MRGHeapTypeInfo {
  let type_sec = match mod.type_sec {
    Some(type_sec) => type_sec
    None => {
      let flat : MRGFlatTypes = {
        subtypes: [],
        group_starts: [],
        groups: [],
        type_to_group: [],
      }
      return {
        flat,
        private_types: [],
        public_types: Set::new(),
        public_groups: [],
        visibility_map: Map::new(),
      }
    }
  }
  let flat = mrg_flatten_types(type_sec)
  let public_types : Set[Int] = Set::new()
  let func_types = mrg_collect_func_type_idx_by_func(mod)
  let global_types = mrg_collect_all_global_types(mod)
  let table_types = mrg_collect_all_table_types(mod)
  let tag_types = mrg_collect_all_tag_types(mod)
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(type_idx)) =>
            match mrg_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
              Some(idx) => mrg_mark_public_type(public_types, flat, idx)
              None => ()
            }
          Import(_, _, TagExternType(TagType(type_idx))) =>
            match mrg_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
              Some(idx) => mrg_mark_public_type(public_types, flat, idx)
              None => ()
            }
          Import(_, _, GlobalExternType(GlobalType(vt, _))) =>
            mrg_mark_public_valtype(public_types, flat, vt)
          Import(_, _, TableExternType(TableType(rt, _))) =>
            mrg_mark_public_reftype(public_types, flat, rt)
          _ => ()
        }
      }
    None => ()
  }
  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for export_ in exports {
        let Export(_, extern_idx) = export_
        match extern_idx {
          FuncExternIdx(func_idx) =>
            match func_types.get(func_idx) {
              Some(type_idx) =>
                match
                  mrg_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
                  Some(idx) => mrg_mark_public_type(public_types, flat, idx)
                  None => ()
                }
              None => ()
            }
          GlobalExternIdx(GlobalIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < global_types.length() {
              let GlobalType(vt, _) = global_types[idx]
              mrg_mark_public_valtype(public_types, flat, vt)
            }
          }
          TableExternIdx(TableIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < table_types.length() {
              let TableType(rt, _) = table_types[idx]
              mrg_mark_public_reftype(public_types, flat, rt)
            }
          }
          TagExternIdx(TagIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < tag_types.length() {
              let TagType(type_idx) = tag_types[idx]
              match mrg_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
                Some(type_i) => mrg_mark_public_type(public_types, flat, type_i)
                None => ()
              }
            }
          }
          _ => ()
        }
      }
    None => ()
  }

  // If a group is public-facing, keep every type in it immutable to preserve group shape.
  let initially_public : Array[Int] = []
  for idx in public_types {
    initially_public.push(idx)
  }
  for idx in initially_public {
    let g = flat.type_to_group[idx]
    for t in flat.groups[g] {
      public_types.add(t)
    }
  }
  let visibility_map : Map[Int, Bool] = Map::new()
  let private_types : Array[Int] = []
  for i in 0..<flat.subtypes.length() {
    let private = !public_types.contains(i)
    visibility_map[i] = private
    if private {
      private_types.push(i)
    }
  }
  let public_groups : Array[Int] = []
  for gi in 0..<flat.groups.length() {
    let mut is_public_group = false
    for idx in flat.groups[gi] {
      if public_types.contains(idx) {
        is_public_group = true
        break
      }
    }
    if is_public_group {
      public_groups.push(gi)
    }
  }
  {
    flat,
    private_types: mrg_unique_sorted(private_types),
    public_types,
    public_groups,
    visibility_map,
  }
}

///|
fn compute_type_indices_for_shape_ordering(flat : MRGFlatTypes) -> Array[Int] {
  let out : Array[Int] = []
  for i in 0..<flat.subtypes.length() {
    out.push(i)
  }
  out
}

///|
fn mrg_private_adjacency(
  private_types : Array[Int],
  flat : MRGFlatTypes,
) -> Map[Int, Array[Int]] {
  let private_set : Set[Int] = Set::new()
  for t in private_types {
    private_set.add(t)
  }
  let out : Map[Int, Array[Int]] = Map::new()
  for t in private_types {
    let refs = mrg_collect_subtype_refs(
      flat.subtypes[t],
      flat.group_starts[t],
      flat.subtypes.length(),
    )
    let nexts : Array[Int] = []
    for r in refs {
      if private_set.contains(r) {
        nexts.push(r)
      }
    }
    out[t] = mrg_unique_sorted(nexts)
  }
  out
}

///|
fn compute_sccs(
  private_types : Array[Int],
  adjacency : Map[Int, Array[Int]],
) -> Array[Array[Int]] {
  if private_types.is_empty() {
    return []
  }
  let nodes = mrg_unique_sorted(private_types)
  let visited : Set[Int] = Set::new()
  let order : Array[Int] = []
  for start in nodes {
    if visited.contains(start) {
      continue
    }
    let stack : Array[(Int, Bool)] = [(start, false)]
    while stack.length() > 0 {
      let (node, expanded) = stack.pop().unwrap()
      if expanded {
        order.push(node)
        continue
      }
      if visited.contains(node) {
        continue
      }
      visited.add(node)
      stack.push((node, true))
      let nexts = adjacency.get(node).unwrap_or([])
      for i in 0..<nexts.length() {
        let next = nexts[nexts.length() - 1 - i]
        if !visited.contains(next) {
          stack.push((next, false))
        }
      }
    }
  }
  let rev : Map[Int, Array[Int]] = Map::new()
  for n in nodes {
    rev[n] = []
  }
  for n in nodes {
    for m in adjacency.get(n).unwrap_or([]) {
      match rev.get(m) {
        Some(list) => list.push(n)
        None => rev[m] = [n]
      }
    }
  }
  for n in nodes {
    let list = rev.get(n).unwrap_or([])
    rev[n] = mrg_unique_sorted(list)
  }
  let assigned : Set[Int] = Set::new()
  let sccs : Array[Array[Int]] = []
  for i in 0..<order.length() {
    let node = order[order.length() - 1 - i]
    if assigned.contains(node) {
      continue
    }
    let component : Array[Int] = []
    let stack : Array[Int] = [node]
    assigned.add(node)
    while stack.length() > 0 {
      let curr = stack.pop().unwrap()
      component.push(curr)
      for prev in rev.get(curr).unwrap_or([]) {
        if !assigned.contains(prev) {
          assigned.add(prev)
          stack.push(prev)
        }
      }
    }
    sccs.push(mrg_unique_sorted(component))
  }
  sccs
}

///|
fn mrg_add_edge_unique(
  adjacency : Array[Array[Int]],
  from : Int,
  to : Int,
) -> Unit {
  if from < 0 ||
    from >= adjacency.length() ||
    to < 0 ||
    to >= adjacency.length() {
    return
  }
  for existing in adjacency[from] {
    if existing == to {
      return
    }
  }
  adjacency[from].push(to)
}

///|
fn create_type_order_graph(
  types_in_group : Array[Int],
  flat : MRGFlatTypes,
) -> Array[Array[Int]] {
  let adjacency : Array[Array[Int]] = []
  let pos_by_type : Map[Int, Int] = Map::new()
  for i in 0..<types_in_group.length() {
    adjacency.push([])
    pos_by_type[types_in_group[i]] = i
  }
  for i in 0..<types_in_group.length() {
    let t = types_in_group[i]
    let subtype = flat.subtypes[t]
    for super_idx in subtype.super_types() {
      match
        mrg_resolve_type_idx(
          super_idx,
          flat.group_starts[t],
          flat.subtypes.length(),
        ) {
        Some(super_abs) =>
          match pos_by_type.get(super_abs) {
            Some(super_pos) => mrg_add_edge_unique(adjacency, super_pos, i)
            None => ()
          }
        None => ()
      }
    }
  }
  for row in adjacency {
    row.sort()
  }
  adjacency
}

///|
fn mrg_all_topological_orders(
  types_in_group : Array[Int],
  adjacency : Array[Array[Int]],
) -> Array[Array[Int]] {
  let n = types_in_group.length()
  if n == 0 {
    return []
  }
  let indegree = Array::make(n, 0)
  for i in 0..<n {
    for to in adjacency[i] {
      indegree[to] = indegree[to] + 1
    }
  }
  let used = Array::make(n, false)
  let current : Array[Int] = []
  let out : Array[Array[Int]] = []
  fn dfs(
    types_in_group : Array[Int],
    adjacency : Array[Array[Int]],
    indegree : Array[Int],
    used : Array[Bool],
    current : Array[Int],
    out : Array[Array[Int]],
  ) -> Unit {
    if out.length() >= mrg_max_topo_orders {
      return
    }
    let n = types_in_group.length()
    if current.length() == n {
      let order : Array[Int] = []
      for pos in current {
        order.push(types_in_group[pos])
      }
      out.push(order)
      return
    }
    let candidates : Array[Int] = []
    for i in 0..<n {
      if !used[i] && indegree[i] == 0 {
        candidates.push(i)
      }
    }
    candidates.sort_by(fn(a, b) { types_in_group[a].compare(types_in_group[b]) })
    for c in candidates {
      used[c] = true
      current.push(c)
      for to in adjacency[c] {
        indegree[to] = indegree[to] - 1
      }
      dfs(types_in_group, adjacency, indegree, used, current, out)
      for to in adjacency[c] {
        indegree[to] = indegree[to] + 1
      }
      ignore(current.pop())
      used[c] = false
      if out.length() >= mrg_max_topo_orders {
        return
      }
    }
  }

  dfs(types_in_group, adjacency, indegree, used, current, out)
  if out.is_empty() {
    return [types_in_group.copy()]
  }
  out
}

///|
fn topo_sort_group(
  types_in_group : Array[Int],
  adjacency : Array[Array[Int]],
) -> Array[Int] {
  let orders = mrg_all_topological_orders(types_in_group, adjacency)
  if orders.is_empty() {
    let out = types_in_group.copy()
    out.sort()
    return out
  }
  orders[0]
}

///|
fn mrg_abs_heap_type_code(abs : AbsHeapType) -> String {
  match abs {
    ExnAbsHeapType => "exn"
    ArrayAbsHeapType => "array"
    StructAbsHeapType => "struct"
    I31AbsHeapType => "i31"
    EqAbsHeapType => "eq"
    AnyAbsHeapType => "any"
    ExternAbsHeapType => "extern"
    FuncAbsHeapType => "func"
    NoneAbsHeapType => "none"
    NoExternAbsHeapType => "noextern"
    NoFuncAbsHeapType => "nofunc"
    NoExnAbsHeapType => "noexn"
  }
}

///|
fn mrg_shape_typeidx(type_idx : TypeIdx, type_indices : Array[Int]) -> String {
  match type_idx {
    TypeIdx(i) => {
      let raw = i.reinterpret_as_int()
      if raw >= 0 && raw < type_indices.length() {
        "T" + type_indices[raw].to_string()
      } else {
        "T" + raw.to_string()
      }
    }
    RecIdx(i) => "R" + i.reinterpret_as_int().to_string()
  }
}

///|
fn mrg_shape_heaptype(ht : HeapType, type_indices : Array[Int]) -> String {
  match ht {
    AbsHeapTypeHeapType(abs) => "A(" + mrg_abs_heap_type_code(abs) + ")"
    HeapType(type_idx) => "H(" + mrg_shape_typeidx(type_idx, type_indices) + ")"
    DefTypeHeapType(dt) => "D(" + dt.to_string() + ")"
  }
}

///|
fn mrg_shape_reftype(rt : RefType, type_indices : Array[Int]) -> String {
  match rt {
    HeapTypeRefType(nullable, ht) =>
      "ref(" +
      nullable.to_string() +
      "," +
      mrg_shape_heaptype(ht, type_indices) +
      ")"
    AbsHeapTypeRefType(abs) => "absref(" + mrg_abs_heap_type_code(abs) + ")"
  }
}

///|
fn mrg_shape_valtype(vt : ValType, type_indices : Array[Int]) -> String {
  match vt {
    NumTypeValType(nt) => "num(" + nt.to_string() + ")"
    VecTypeValType => "vec"
    RefTypeValType(rt) => mrg_shape_reftype(rt, type_indices)
    BotValType => "bot"
  }
}

///|
fn mrg_shape_storage_type(
  st : StorageType,
  type_indices : Array[Int],
) -> String {
  match st {
    ValTypeStorageType(vt) => "val(" + mrg_shape_valtype(vt, type_indices) + ")"
    PackTypeStorageType(pt) => "pack(" + pt.to_string() + ")"
  }
}

///|
fn mrg_shape_subtype(st : SubType, type_indices : Array[Int]) -> String {
  let mut out = ""
  match st {
    SubType(final_, supers, ct) => {
      out = out + "sub(final=" + final_.to_string() + ";supers=["
      for i in 0..<supers.length() {
        if i > 0 {
          out = out + ","
        }
        out = out + mrg_shape_typeidx(supers[i], type_indices)
      }
      out = out + "];"
      match ct {
        FuncCompType(params, results) => {
          out = out + "func("
          for i in 0..<params.length() {
            if i > 0 {
              out = out + ","
            }
            out = out + mrg_shape_valtype(params[i], type_indices)
          }
          out = out + "->"
          for i in 0..<results.length() {
            if i > 0 {
              out = out + ","
            }
            out = out + mrg_shape_valtype(results[i], type_indices)
          }
          out = out + ")"
        }
        StructCompType(fields) => {
          out = out + "struct("
          for i in 0..<fields.length() {
            if i > 0 {
              out = out + ","
            }
            let FieldType(storage, mut_) = fields[i]
            out = out +
              "field(" +
              mrg_shape_storage_type(storage, type_indices) +
              "," +
              mut_.to_string() +
              ")"
          }
          out = out + ")"
        }
        ArrayCompType(field) => {
          let FieldType(storage, mut_) = field
          out = out +
            "array(" +
            mrg_shape_storage_type(storage, type_indices) +
            "," +
            mut_.to_string() +
            ")"
        }
      }
      out = out + ")"
    }
    CompTypeSubType(ct) => {
      out = out + "comp("
      match ct {
        FuncCompType(params, results) => {
          out = out + "func("
          for i in 0..<params.length() {
            if i > 0 {
              out = out + ","
            }
            out = out + mrg_shape_valtype(params[i], type_indices)
          }
          out = out + "->"
          for i in 0..<results.length() {
            if i > 0 {
              out = out + ","
            }
            out = out + mrg_shape_valtype(results[i], type_indices)
          }
          out = out + ")"
        }
        StructCompType(fields) => {
          out = out + "struct("
          for i in 0..<fields.length() {
            if i > 0 {
              out = out + ","
            }
            let FieldType(storage, mut_) = fields[i]
            out = out +
              "field(" +
              mrg_shape_storage_type(storage, type_indices) +
              "," +
              mut_.to_string() +
              ")"
          }
          out = out + ")"
        }
        ArrayCompType(field) => {
          let FieldType(storage, mut_) = field
          out = out +
            "array(" +
            mrg_shape_storage_type(storage, type_indices) +
            "," +
            mut_.to_string() +
            ")"
        }
      }
      out = out + ")"
    }
  }
  out
}

///|
fn rec_group_shape(
  types : Array[SubType],
  features : MRGFeatures,
) -> RecGroupShape {
  let mut key = "wasm3.0:" + features.enabled.to_string() + ":"
  for i in 0..<types.length() {
    if i > 0 {
      key = key + "|"
    }
    key = key + mrg_shape_subtype(types[i], [])
  }
  RecGroupShape::{ key, }
}

///|
fn comparable_shape(
  types : Array[SubType],
  features : MRGFeatures,
  type_indices : Array[Int],
) -> ComparableRecGroupShape {
  let base = rec_group_shape(types, features)
  ignore(base.key)
  let mut key = "wasm3.0:" + features.enabled.to_string() + ":"
  for i in 0..<types.length() {
    if i > 0 {
      key = key + "|"
    }
    key = key + mrg_shape_subtype(types[i], type_indices)
  }
  ComparableRecGroupShape::{ key, }
}

///|
fn mrg_rewrite_typeidx_for_shape(
  type_idx : TypeIdx,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  type_indices : Array[Int],
) -> TypeIdx {
  match mrg_resolve_type_idx(type_idx, group_start, total) {
    Some(abs_idx) =>
      match local_pos_by_old.get(abs_idx) {
        Some(pos) => TypeIdx::rec(pos.reinterpret_as_uint())
        None =>
          if abs_idx >= 0 && abs_idx < type_indices.length() {
            TypeIdx::new(type_indices[abs_idx].reinterpret_as_uint())
          } else {
            TypeIdx::new(abs_idx.reinterpret_as_uint())
          }
      }
    None => type_idx
  }
}

///|
fn mrg_rewrite_heaptype_for_shape(
  ht : HeapType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  type_indices : Array[Int],
) -> HeapType {
  match ht {
    HeapType(type_idx) =>
      HeapType::new(
        mrg_rewrite_typeidx_for_shape(
          type_idx, group_start, total, local_pos_by_old, type_indices,
        ),
      )
    _ => ht
  }
}

///|
fn mrg_rewrite_reftype_for_shape(
  rt : RefType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  type_indices : Array[Int],
) -> RefType {
  match rt {
    HeapTypeRefType(nullable, ht) =>
      RefType::new(
        nullable,
        mrg_rewrite_heaptype_for_shape(
          ht, group_start, total, local_pos_by_old, type_indices,
        ),
      )
    _ => rt
  }
}

///|
fn mrg_rewrite_valtype_for_shape(
  vt : ValType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  type_indices : Array[Int],
) -> ValType {
  match vt {
    RefTypeValType(rt) =>
      ValType::ref_type(
        mrg_rewrite_reftype_for_shape(
          rt, group_start, total, local_pos_by_old, type_indices,
        ),
      )
    _ => vt
  }
}

///|
fn mrg_rewrite_storage_for_shape(
  st : StorageType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  type_indices : Array[Int],
) -> StorageType {
  match st {
    ValTypeStorageType(vt) =>
      StorageType::val_type(
        mrg_rewrite_valtype_for_shape(
          vt, group_start, total, local_pos_by_old, type_indices,
        ),
      )
    _ => st
  }
}

///|
fn mrg_rewrite_subtype_for_shape(
  subtype : SubType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  type_indices : Array[Int],
) -> SubType {
  match subtype {
    SubType(is_final, supers, ct) => {
      let next_supers : Array[TypeIdx] = []
      for super_idx in supers {
        next_supers.push(
          mrg_rewrite_typeidx_for_shape(
            super_idx, group_start, total, local_pos_by_old, type_indices,
          ),
        )
      }
      let next_ct = match ct {
        FuncCompType(params, results) => {
          let next_params : Array[ValType] = []
          let next_results : Array[ValType] = []
          for p in params {
            next_params.push(
              mrg_rewrite_valtype_for_shape(
                p, group_start, total, local_pos_by_old, type_indices,
              ),
            )
          }
          for r in results {
            next_results.push(
              mrg_rewrite_valtype_for_shape(
                r, group_start, total, local_pos_by_old, type_indices,
              ),
            )
          }
          CompType::func(next_params, next_results)
        }
        StructCompType(fields) => {
          let next_fields : Array[FieldType] = []
          for field in fields {
            let FieldType(storage, mut_) = field
            next_fields.push(
              FieldType::new(
                mrg_rewrite_storage_for_shape(
                  storage, group_start, total, local_pos_by_old, type_indices,
                ),
                mut_,
              ),
            )
          }
          CompType::struct_(next_fields)
        }
        ArrayCompType(field) => {
          let FieldType(storage, mut_) = field
          CompType::array(
            FieldType::new(
              mrg_rewrite_storage_for_shape(
                storage, group_start, total, local_pos_by_old, type_indices,
              ),
              mut_,
            ),
          )
        }
      }
      SubType::new(is_final, next_supers, next_ct)
    }
    CompTypeSubType(ct) => {
      let next_ct = match ct {
        FuncCompType(params, results) => {
          let next_params : Array[ValType] = []
          let next_results : Array[ValType] = []
          for p in params {
            next_params.push(
              mrg_rewrite_valtype_for_shape(
                p, group_start, total, local_pos_by_old, type_indices,
              ),
            )
          }
          for r in results {
            next_results.push(
              mrg_rewrite_valtype_for_shape(
                r, group_start, total, local_pos_by_old, type_indices,
              ),
            )
          }
          CompType::func(next_params, next_results)
        }
        StructCompType(fields) => {
          let next_fields : Array[FieldType] = []
          for field in fields {
            let FieldType(storage, mut_) = field
            next_fields.push(
              FieldType::new(
                mrg_rewrite_storage_for_shape(
                  storage, group_start, total, local_pos_by_old, type_indices,
                ),
                mut_,
              ),
            )
          }
          CompType::struct_(next_fields)
        }
        ArrayCompType(field) => {
          let FieldType(storage, mut_) = field
          CompType::array(
            FieldType::new(
              mrg_rewrite_storage_for_shape(
                storage, group_start, total, local_pos_by_old, type_indices,
              ),
              mut_,
            ),
          )
        }
      }
      SubType::comp_type(next_ct)
    }
  }
}

///|
fn mrg_group_shape_subtypes(
  group : RecGroupInfo,
  flat : MRGFlatTypes,
  type_indices : Array[Int],
) -> Array[SubType] {
  let out : Array[SubType] = []
  let local_pos_by_old : Map[Int, Int] = Map::new()
  let brand_offset = if group.brand is Some(_) { 1 } else { 0 }
  for i in 0..<group.current_order.length() {
    local_pos_by_old[group.current_order[i]] = brand_offset + i
  }
  if group.brand is Some(brand) {
    out.push(brand)
  }
  for old_idx in group.current_order {
    out.push(
      mrg_rewrite_subtype_for_shape(
        flat.subtypes[old_idx],
        flat.group_starts[old_idx],
        flat.subtypes.length(),
        local_pos_by_old,
        type_indices,
      ),
    )
  }
  out
}

///|
fn mrg_group_shape_key(
  group : RecGroupInfo,
  flat : MRGFlatTypes,
  type_indices : Array[Int],
) -> String {
  let types = mrg_group_shape_subtypes(group, flat, type_indices)
  comparable_shape(types, MRGFeatures::new(), type_indices).key
}

///|
fn mrg_internal_ref_adjacency(
  types_in_scc : Array[Int],
  flat : MRGFlatTypes,
) -> Map[Int, Array[Int]] {
  let set : Set[Int] = Set::new()
  for t in types_in_scc {
    set.add(t)
  }
  let out : Map[Int, Array[Int]] = Map::new()
  for t in types_in_scc {
    let refs = mrg_collect_subtype_refs(
      flat.subtypes[t],
      flat.group_starts[t],
      flat.subtypes.length(),
    )
    let internal : Array[Int] = []
    for r in refs {
      if set.contains(r) {
        internal.push(r)
      }
    }
    out[t] = mrg_unique_sorted(internal)
  }
  out
}

///|
fn mrg_dfs_order(
  start : Int,
  nodes : Array[Int],
  adjacency : Map[Int, Array[Int]],
) -> Array[Int] {
  let visited : Set[Int] = Set::new()
  let order : Array[Int] = []
  let stack : Array[(Int, Bool)] = [(start, false)]
  while stack.length() > 0 {
    let (node, expanded) = stack.pop().unwrap()
    if expanded {
      continue
    }
    if visited.contains(node) {
      continue
    }
    visited.add(node)
    order.push(node)
    let nexts = adjacency.get(node).unwrap_or([])
    for i in 0..<nexts.length() {
      let next = nexts[nexts.length() - 1 - i]
      if !visited.contains(next) {
        stack.push((next, false))
      }
    }
  }
  let remaining = nodes.copy()
  remaining.sort()
  for node in remaining {
    if !visited.contains(node) {
      order.push(node)
    }
  }
  order
}

///|
fn mrg_order_to_perm(
  types_in_scc : Array[Int],
  order : Array[Int],
) -> Array[Int] {
  let pos : Map[Int, Int] = Map::new()
  for i in 0..<types_in_scc.length() {
    pos[types_in_scc[i]] = i
  }
  let perm : Array[Int] = []
  for t in order {
    match pos.get(t) {
      Some(p) => perm.push(p)
      None => ()
    }
  }
  perm
}

///|
fn mrg_apply_perm(types_in_scc : Array[Int], perm : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  for p in perm {
    if p >= 0 && p < types_in_scc.length() {
      out.push(types_in_scc[p])
    }
  }
  out
}

///|
fn get_canonical_permutation(
  types_in_scc : Array[Int],
  flat : MRGFlatTypes,
  type_indices : Array[Int],
) -> Array[Int] {
  if types_in_scc.length() <= 1 {
    return [0]
  }
  let nodes = types_in_scc.copy()
  let adjacency = mrg_internal_ref_adjacency(nodes, flat)
  let starts = nodes.copy()
  starts.sort()
  let perms : Array[Array[Int]] = []
  for start in starts {
    let order = mrg_dfs_order(start, nodes, adjacency)
    perms.push(mrg_order_to_perm(nodes, order))
  }
  let dedup_perm : Array[Array[Int]] = []
  for p in perms {
    let mut exists = false
    for q in dedup_perm {
      if q == p {
        exists = true
        break
      }
    }
    if !exists {
      dedup_perm.push(p)
    }
  }
  let classes : Map[String, Array[Array[Int]]] = Map::new()
  for p in dedup_perm {
    let ordered = mrg_apply_perm(nodes, p)
    let local_pos : Map[Int, Int] = Map::new()
    for i in 0..<ordered.length() {
      local_pos[ordered[i]] = i
    }
    let normalized : Array[SubType] = []
    for old_idx in ordered {
      normalized.push(
        mrg_rewrite_subtype_for_shape(
          flat.subtypes[old_idx],
          flat.group_starts[old_idx],
          flat.subtypes.length(),
          local_pos,
          type_indices,
        ),
      )
    }
    let key = comparable_shape(normalized, MRGFeatures::new(), type_indices).key
    match classes.get(key) {
      Some(v) => v.push(p)
      None => classes[key] = [p]
    }
  }
  let class_keys : Array[String] = []
  for k in classes {
    class_keys.push(k.0)
  }
  class_keys.sort()
  if class_keys.is_empty() {
    return [0]
  }

  // Stripe permutations across shape-equivalence classes.
  let striped : Array[Array[Int]] = []
  let mut layer = 0
  let mut progress = true
  while progress {
    progress = false
    for key in class_keys {
      let arr = classes.get(key).unwrap_or([])
      if layer < arr.length() {
        striped.push(arr[layer])
        progress = true
      }
    }
    layer += 1
  }
  if striped.is_empty() {
    return classes.get(class_keys[0]).unwrap()[0]
  }
  striped[0]
}

///|
fn mrg_make_brand_subtype(seed : Int) -> SubType {
  match seed % 8 {
    0 =>
      SubType::comp_type(
        CompType::struct_([
          FieldType::new(StorageType::val_type(ValType::i32()), Const),
        ]),
      )
    1 =>
      SubType::comp_type(
        CompType::struct_([
          FieldType::new(StorageType::val_type(ValType::i64()), Const),
        ]),
      )
    2 =>
      SubType::comp_type(
        CompType::struct_([
          FieldType::new(StorageType::val_type(ValType::f32()), Const),
        ]),
      )
    3 =>
      SubType::comp_type(
        CompType::struct_([
          FieldType::new(StorageType::val_type(ValType::f64()), Const),
        ]),
      )
    4 =>
      SubType::comp_type(
        CompType::array(
          FieldType::new(StorageType::val_type(ValType::i32()), Const),
        ),
      )
    5 =>
      SubType::comp_type(
        CompType::array(
          FieldType::new(StorageType::val_type(ValType::i64()), Const),
        ),
      )
    6 => SubType::comp_type(CompType::func([], []))
    _ => SubType::comp_type(CompType::func([ValType::i32()], []))
  }
}

///|
fn mrg_singleton_brand_distinct(
  brand : SubType,
  real : SubType,
  type_indices : Array[Int],
) -> Bool {
  let b = comparable_shape([brand], MRGFeatures::new(), type_indices).key
  let r = comparable_shape([real], MRGFeatures::new(), type_indices).key
  b != r
}

///|
fn mrg_reset_iteration(
  group : RecGroupInfo,
  flat : MRGFlatTypes,
  type_indices : Array[Int],
) -> RecGroupInfo {
  let out = group
  if out.perm_orders.is_empty() {
    return out
  }
  out.next_perm = 0
  out.current_order = out.perm_orders[0]
  out.seen_shapes = Set::new()
  out.seen_shapes.add(mrg_group_shape_key(out, flat, type_indices))
  out
}

///|
fn advance_brand(
  group : RecGroupInfo,
  flat : MRGFlatTypes,
  type_indices : Array[Int],
) -> RecGroupInfo {
  let out = group
  let singleton_real = if out.old_types.length() == 1 {
    Some(flat.subtypes[out.old_types[0]])
  } else {
    None
  }
  let mut next_seed = out.brand_seed + 1
  while true {
    let brand = mrg_make_brand_subtype(next_seed)
    let ok = match singleton_real {
      Some(real) => mrg_singleton_brand_distinct(brand, real, type_indices)
      None => true
    }
    if ok {
      out.brand_seed = next_seed
      out.brand = Some(brand)
      return mrg_reset_iteration(out, flat, type_indices)
    }
    next_seed += 1
  }
  out
}

///|
fn permute(
  group : RecGroupInfo,
  flat : MRGFlatTypes,
  type_indices : Array[Int],
) -> RecGroupInfo {
  let out = group
  let mut idx = out.next_perm + 1
  while idx < out.perm_orders.length() {
    out.next_perm = idx
    out.current_order = out.perm_orders[idx]
    let key = mrg_group_shape_key(out, flat, type_indices)
    if !out.seen_shapes.contains(key) {
      out.seen_shapes.add(key)
      return out
    }
    idx += 1
  }
  advance_brand(out, flat, type_indices)
}

///|
fn GroupClassInfo::advance(
  self : GroupClassInfo,
  groups : Array[RecGroupInfo],
  flat : MRGFlatTypes,
  type_indices : Array[Int],
) -> Unit {
  let idx = self.group_idx
  groups[idx] = permute(groups[idx], flat, type_indices)
}

///|
fn mrg_compute_perm_orders(
  old_types : Array[Int],
  flat : MRGFlatTypes,
  type_indices : Array[Int],
) -> Array[Array[Int]] {
  let graph = create_type_order_graph(old_types, flat)
  let mut orders = mrg_all_topological_orders(old_types, graph)
  if orders.is_empty() {
    orders = [old_types.copy()]
  }
  let canonical_perm = get_canonical_permutation(old_types, flat, type_indices)
  let canonical_order = mrg_apply_perm(old_types, canonical_perm)
  let dedup : Array[Array[Int]] = []
  for order in orders {
    let mut seen = false
    for existing in dedup {
      if existing == order {
        seen = true
        break
      }
    }
    if !seen {
      dedup.push(order)
    }
  }
  dedup.sort_by(fn(a, b) {
    let key_a = comparable_shape(
        mrg_shape_subtypes_from_order(a, flat, type_indices),
        MRGFeatures::new(),
        type_indices,
      ).key
    let key_b = comparable_shape(
        mrg_shape_subtypes_from_order(b, flat, type_indices),
        MRGFeatures::new(),
        type_indices,
      ).key
    let cmp = key_a.compare(key_b)
    if cmp != 0 {
      cmp
    } else {
      a.to_string().compare(b.to_string())
    }
  })
  for i in 0..<dedup.length() {
    if dedup[i] == canonical_order {
      if i != 0 {
        let tmp = dedup[0]
        dedup[0] = dedup[i]
        dedup[i] = tmp
      }
      break
    }
  }
  dedup
}

///|
fn mrg_shape_subtypes_from_order(
  order : Array[Int],
  flat : MRGFlatTypes,
  type_indices : Array[Int],
) -> Array[SubType] {
  let local_pos : Map[Int, Int] = Map::new()
  for i in 0..<order.length() {
    local_pos[order[i]] = i
  }
  let out : Array[SubType] = []
  for old_idx in order {
    out.push(
      mrg_rewrite_subtype_for_shape(
        flat.subtypes[old_idx],
        flat.group_starts[old_idx],
        flat.subtypes.length(),
        local_pos,
        type_indices,
      ),
    )
  }
  out
}

///|
fn mrg_sort_key_for_group(
  old_types : Array[Int],
  flat : MRGFlatTypes,
  type_indices : Array[Int],
) -> String {
  let perm = get_canonical_permutation(old_types, flat, type_indices)
  let ordered = mrg_apply_perm(old_types, perm)
  comparable_shape(
    mrg_shape_subtypes_from_order(ordered, flat, type_indices),
    MRGFeatures::new(),
    type_indices,
  ).key
}

///|
fn mrg_remove_owner(shape_owner : Map[String, Int], owner : Int) -> Unit {
  let keys : Array[String] = []
  for entry in shape_owner {
    if entry.1 == owner {
      keys.push(entry.0)
    }
  }
  for key in keys {
    ignore(shape_owner.remove(key))
  }
}

///|
fn mrg_ensure_canonicalized(
  groups : Array[RecGroupInfo],
  idx : Int,
  flat : MRGFlatTypes,
  type_indices : Array[Int],
) -> Unit {
  let info = groups[idx]
  if info.canonicalized || info.old_types.is_empty() {
    return
  }
  let canonical_perm = get_canonical_permutation(
    info.old_types,
    flat,
    type_indices,
  )
  let canonical_order = mrg_apply_perm(info.old_types, canonical_perm)
  let out = info
  if !out.perm_orders.is_empty() {
    let reordered = out.perm_orders.copy()
    for i in 0..<reordered.length() {
      if reordered[i] == canonical_order {
        if i != 0 {
          let tmp = reordered[0]
          reordered[0] = reordered[i]
          reordered[i] = tmp
        }
        break
      }
    }
    out.current_order = reordered[0]
  } else {
    out.current_order = canonical_order
  }
  out.canonicalized = true
  groups[idx] = mrg_reset_iteration(out, flat, type_indices)
}

///|
fn update_shape(
  group_idx : Int,
  owner : Int,
  groups : Array[RecGroupInfo],
  dsu : DSU,
  flat : MRGFlatTypes,
  type_indices : Array[Int],
  stack : Array[Int],
  shape_owner : Map[String, Int],
) -> Unit {
  if owner == mrg_public_shape_owner {
    let root = dsu.find(group_idx)
    let nontrivial = dsu.class_size(root) > 1
    if !nontrivial {
      mrg_ensure_canonicalized(groups, group_idx, flat, type_indices)
    }
    GroupClassInfo::{ group_idx, }.advance(groups, flat, type_indices)
    stack.push(group_idx)
    return
  }
  let a_root = dsu.find(group_idx)
  let b_root = dsu.find(owner)
  let a_nontrivial = dsu.class_size(a_root) > 1
  let b_nontrivial = dsu.class_size(b_root) > 1
  if a_root == b_root {
    groups[group_idx] = advance_brand(groups[group_idx], flat, type_indices)
    groups[group_idx] = permute(groups[group_idx], flat, type_indices)
    stack.push(group_idx)
    stack.push(owner)
    return
  }
  if a_nontrivial && b_nontrivial {
    GroupClassInfo::{ group_idx, }.advance(groups, flat, type_indices)
    stack.push(group_idx)
    return
  }
  if a_nontrivial && !b_nontrivial {
    ignore(dsu.union(a_root, b_root))
    mrg_ensure_canonicalized(groups, group_idx, flat, type_indices)
    mrg_ensure_canonicalized(groups, owner, flat, type_indices)
    GroupClassInfo::{ group_idx, }.advance(groups, flat, type_indices)
    stack.push(group_idx)
    stack.push(owner)
    return
  }
  if !a_nontrivial && b_nontrivial {
    ignore(dsu.union(a_root, b_root))
    mrg_ensure_canonicalized(groups, group_idx, flat, type_indices)
    mrg_ensure_canonicalized(groups, owner, flat, type_indices)
    GroupClassInfo::{ group_idx, }.advance(groups, flat, type_indices)
    stack.push(group_idx)
    stack.push(owner)
    return
  }

  // Two unaffiliated singleton groups.
  mrg_ensure_canonicalized(groups, group_idx, flat, type_indices)
  mrg_ensure_canonicalized(groups, owner, flat, type_indices)
  ignore(dsu.union(group_idx, owner))
  GroupClassInfo::{ group_idx, }.advance(groups, flat, type_indices)
  mrg_remove_owner(shape_owner, group_idx)
  mrg_remove_owner(shape_owner, owner)
  stack.push(group_idx)
  stack.push(owner)
}

///|
fn update_shapes(
  groups : Array[RecGroupInfo],
  flat : MRGFlatTypes,
  type_indices : Array[Int],
) -> Unit {
  let shape_owner : Map[String, Int] = Map::new()
  let dsu = DSU::new(groups.length())
  let stack : Array[Int] = []
  for i in 0..<groups.length() {
    if groups[i].is_public {
      let key = mrg_group_shape_key(groups[i], flat, type_indices)
      shape_owner[key] = mrg_public_shape_owner
    }
  }
  for i in 0..<groups.length() {
    if !groups[i].is_public {
      stack.push(i)
    }
  }
  while stack.length() > 0 {
    let group_idx = stack.pop().unwrap()
    if groups[group_idx].is_public {
      continue
    }
    mrg_remove_owner(shape_owner, group_idx)
    let key = mrg_group_shape_key(groups[group_idx], flat, type_indices)
    match shape_owner.get(key) {
      None => shape_owner[key] = group_idx
      Some(owner) =>
        if owner == group_idx {
          shape_owner[key] = group_idx
        } else {
          if owner >= 0 {
            mrg_remove_owner(shape_owner, owner)
          }
          update_shape(
            group_idx, owner, groups, dsu, flat, type_indices, stack, shape_owner,
          )
        }
    }
  }
}

///|
fn mrg_group_dependencies(
  groups : Array[RecGroupInfo],
  old_to_group : Array[Int],
  flat : MRGFlatTypes,
) -> Array[Array[Int]] {
  let deps : Array[Array[Int]] = []
  for _ in 0..<groups.length() {
    deps.push([])
  }
  for gi in 0..<groups.length() {
    for old_idx in groups[gi].old_types {
      let refs = mrg_collect_subtype_refs(
        flat.subtypes[old_idx],
        flat.group_starts[old_idx],
        flat.subtypes.length(),
      )
      for r in refs {
        if r >= 0 && r < old_to_group.length() {
          let gj = old_to_group[r]
          if gj >= 0 && gj != gi {
            mrg_add_edge_unique(deps, gj, gi)
          }
        }
      }
    }
  }
  for row in deps {
    row.sort()
  }
  deps
}

///|
fn mrg_group_topo_order(
  groups : Array[RecGroupInfo],
  deps : Array[Array[Int]],
) -> Array[Int] {
  let n = groups.length()
  let indegree = Array::make(n, 0)
  for from in 0..<n {
    for to in deps[from] {
      indegree[to] = indegree[to] + 1
    }
  }
  let available : Array[Int] = []
  for i in 0..<n {
    if indegree[i] == 0 {
      available.push(i)
    }
  }
  available.sort_by(fn(a, b) {
    let sa = groups[a].sort_key
    let sb = groups[b].sort_key
    let cmp = sa.compare(sb)
    if cmp != 0 {
      cmp
    } else {
      groups[a].id.compare(groups[b].id)
    }
  })
  let out : Array[Int] = []
  while available.length() > 0 {
    let curr = available.pop().unwrap()
    out.push(curr)
    for to in deps[curr] {
      indegree[to] = indegree[to] - 1
      if indegree[to] == 0 {
        available.push(to)
      }
    }
    available.sort_by(fn(a, b) {
      let sa = groups[a].sort_key
      let sb = groups[b].sort_key
      let cmp = sa.compare(sb)
      if cmp != 0 {
        cmp
      } else {
        groups[a].id.compare(groups[b].id)
      }
    })
  }
  if out.length() < n {
    for i in 0..<n {
      let mut seen = false
      for v in out {
        if v == i {
          seen = true
          break
        }
      }
      if !seen {
        out.push(i)
      }
    }
  }
  out
}

///|
fn mrg_rewrite_typeidx_for_output(
  type_idx : TypeIdx,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[TypeIdx, String] {
  match mrg_resolve_type_idx(type_idx, group_start, total) {
    Some(abs_idx) =>
      match local_pos_by_old.get(abs_idx) {
        Some(pos) => Ok(TypeIdx::rec(pos.reinterpret_as_uint()))
        None =>
          match old_to_new.get(abs_idx) {
            Some(next_idx) => Ok(next_idx)
            None => Err("minimize_rec_groups: missing remap for external type")
          }
      }
    None => Ok(type_idx)
  }
}

///|
fn mrg_rewrite_heaptype_for_output(
  ht : HeapType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[HeapType, String] {
  match ht {
    HeapType(type_idx) =>
      match
        mrg_rewrite_typeidx_for_output(
          type_idx, group_start, total, local_pos_by_old, old_to_new,
        ) {
        Ok(next_idx) => Ok(HeapType::new(next_idx))
        Err(e) => Err(e)
      }
    _ => Ok(ht)
  }
}

///|
fn mrg_rewrite_reftype_for_output(
  rt : RefType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[RefType, String] {
  match rt {
    HeapTypeRefType(nullable, ht) =>
      match
        mrg_rewrite_heaptype_for_output(
          ht, group_start, total, local_pos_by_old, old_to_new,
        ) {
        Ok(next_ht) => Ok(RefType::new(nullable, next_ht))
        Err(e) => Err(e)
      }
    _ => Ok(rt)
  }
}

///|
fn mrg_rewrite_valtype_for_output(
  vt : ValType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[ValType, String] {
  match vt {
    RefTypeValType(rt) =>
      match
        mrg_rewrite_reftype_for_output(
          rt, group_start, total, local_pos_by_old, old_to_new,
        ) {
        Ok(next_rt) => Ok(ValType::ref_type(next_rt))
        Err(e) => Err(e)
      }
    _ => Ok(vt)
  }
}

///|
fn mrg_rewrite_storage_for_output(
  st : StorageType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[StorageType, String] {
  match st {
    ValTypeStorageType(vt) =>
      match
        mrg_rewrite_valtype_for_output(
          vt, group_start, total, local_pos_by_old, old_to_new,
        ) {
        Ok(next_vt) => Ok(StorageType::val_type(next_vt))
        Err(e) => Err(e)
      }
    _ => Ok(st)
  }
}

///|
fn mrg_rewrite_subtype_for_output(
  subtype : SubType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[SubType, String] {
  match subtype {
    SubType(is_final, supers, ct) => {
      let next_supers : Array[TypeIdx] = []
      for super_idx in supers {
        match
          mrg_rewrite_typeidx_for_output(
            super_idx, group_start, total, local_pos_by_old, old_to_new,
          ) {
          Ok(next_idx) => next_supers.push(next_idx)
          Err(e) => return Err(e)
        }
      }
      let next_ct = match ct {
        FuncCompType(params, results) => {
          let next_params : Array[ValType] = []
          let next_results : Array[ValType] = []
          for p in params {
            match
              mrg_rewrite_valtype_for_output(
                p, group_start, total, local_pos_by_old, old_to_new,
              ) {
              Ok(v) => next_params.push(v)
              Err(e) => return Err(e)
            }
          }
          for r in results {
            match
              mrg_rewrite_valtype_for_output(
                r, group_start, total, local_pos_by_old, old_to_new,
              ) {
              Ok(v) => next_results.push(v)
              Err(e) => return Err(e)
            }
          }
          CompType::func(next_params, next_results)
        }
        StructCompType(fields) => {
          let next_fields : Array[FieldType] = []
          for field in fields {
            let FieldType(storage, mut_) = field
            match
              mrg_rewrite_storage_for_output(
                storage, group_start, total, local_pos_by_old, old_to_new,
              ) {
              Ok(next_storage) =>
                next_fields.push(FieldType::new(next_storage, mut_))
              Err(e) => return Err(e)
            }
          }
          CompType::struct_(next_fields)
        }
        ArrayCompType(field) => {
          let FieldType(storage, mut_) = field
          let next_storage = match
            mrg_rewrite_storage_for_output(
              storage, group_start, total, local_pos_by_old, old_to_new,
            ) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          CompType::array(FieldType::new(next_storage, mut_))
        }
      }
      Ok(SubType::new(is_final, next_supers, next_ct))
    }
    CompTypeSubType(ct) => {
      let next_ct = match ct {
        FuncCompType(params, results) => {
          let next_params : Array[ValType] = []
          let next_results : Array[ValType] = []
          for p in params {
            match
              mrg_rewrite_valtype_for_output(
                p, group_start, total, local_pos_by_old, old_to_new,
              ) {
              Ok(v) => next_params.push(v)
              Err(e) => return Err(e)
            }
          }
          for r in results {
            match
              mrg_rewrite_valtype_for_output(
                r, group_start, total, local_pos_by_old, old_to_new,
              ) {
              Ok(v) => next_results.push(v)
              Err(e) => return Err(e)
            }
          }
          CompType::func(next_params, next_results)
        }
        StructCompType(fields) => {
          let next_fields : Array[FieldType] = []
          for field in fields {
            let FieldType(storage, mut_) = field
            match
              mrg_rewrite_storage_for_output(
                storage, group_start, total, local_pos_by_old, old_to_new,
              ) {
              Ok(next_storage) =>
                next_fields.push(FieldType::new(next_storage, mut_))
              Err(e) => return Err(e)
            }
          }
          CompType::struct_(next_fields)
        }
        ArrayCompType(field) => {
          let FieldType(storage, mut_) = field
          let next_storage = match
            mrg_rewrite_storage_for_output(
              storage, group_start, total, local_pos_by_old, old_to_new,
            ) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          CompType::array(FieldType::new(next_storage, mut_))
        }
      }
      Ok(SubType::comp_type(next_ct))
    }
  }
}

///|
fn rewrite_types(
  mod : Module,
  groups : Array[RecGroupInfo],
  flat : MRGFlatTypes,
) -> Result[Module, String] {
  if flat.subtypes.is_empty() {
    return Ok(mod)
  }
  let old_to_group = Array::make(flat.subtypes.length(), -1)
  for gi in 0..<groups.length() {
    for old_idx in groups[gi].old_types {
      old_to_group[old_idx] = gi
    }
  }
  let deps = mrg_group_dependencies(groups, old_to_group, flat)
  let group_order = mrg_group_topo_order(groups, deps)
  let old_to_new : Map[Int, TypeIdx] = Map::new()
  let mut next_index = 0
  for gi in group_order {
    let group = groups[gi]
    let brand_offset = if group.brand is Some(_) { 1 } else { 0 }
    for i in 0..<group.current_order.length() {
      old_to_new[group.current_order[i]] = TypeIdx::new(
        (next_index + brand_offset + i).reinterpret_as_uint(),
      )
    }
    next_index += brand_offset + group.current_order.length()
  }
  let new_recs : Array[RecType] = []
  for gi in group_order {
    let group = groups[gi]
    let local_pos_by_old : Map[Int, Int] = Map::new()
    let brand_offset = if group.brand is Some(_) { 1 } else { 0 }
    for i in 0..<group.current_order.length() {
      local_pos_by_old[group.current_order[i]] = brand_offset + i
    }
    let out_subtypes : Array[SubType] = []
    if group.brand is Some(brand) {
      out_subtypes.push(brand)
    }
    for old_idx in group.current_order {
      match
        mrg_rewrite_subtype_for_output(
          flat.subtypes[old_idx],
          flat.group_starts[old_idx],
          flat.subtypes.length(),
          local_pos_by_old,
          old_to_new,
        ) {
        Ok(subtype) => out_subtypes.push(subtype)
        Err(e) => return Err(e)
      }
    }
    if out_subtypes.length() == 1 {
      new_recs.push(RecType::new(out_subtypes[0]))
    } else {
      new_recs.push(RecType::group(out_subtypes))
    }
  }
  let new_type_sec = TypeSec::new(new_recs)
  let remapper = ModuleTransformer::new()
    .on_typeidx_evt(fn(_t, _, tidx : TypeIdx) {
      match tidx {
        TypeIdx(i) => {
          let raw = i.reinterpret_as_int()
          match old_to_new.get(raw) {
            Some(next_idx) => change((), next_idx)
            None => unchanged()
          }
        }
        RecIdx(_) => unchanged()
      }
    })
    .on_heaptype_evt(fn(_t, _, ht : HeapType) {
      match ht {
        HeapType(type_idx) => {
          let next_type = match type_idx {
            TypeIdx(i) => {
              let raw = i.reinterpret_as_int()
              match old_to_new.get(raw) {
                Some(next_idx) => next_idx
                None => type_idx
              }
            }
            RecIdx(_) => type_idx
          }
          change((), HeapType::new(next_type))
        }
        _ => unchanged()
      }
    })
    .on_typesec_evt(fn(_t, _, _ts : TypeSec) { change((), new_type_sec) })
  match remapper.walk_module((), mod) {
    Ok(Some((_, next_mod))) => Ok(next_mod)
    Ok(None) => Ok(mod.with_type_sec(new_type_sec))
    Err(e) => Err(e)
  }
}

///|
fn mrg_build_private_groups(
  sccs : Array[Array[Int]],
  flat : MRGFlatTypes,
  type_indices : Array[Int],
  next_id : Int,
) -> (Array[RecGroupInfo], Int) {
  let groups : Array[RecGroupInfo] = []
  let mut id = next_id
  for scc in sccs {
    let graph = create_type_order_graph(scc, flat)
    let initial_order = topo_sort_group(scc, graph)
    let perm_orders = mrg_compute_perm_orders(initial_order, flat, type_indices)
    let sort_key = mrg_sort_key_for_group(initial_order, flat, type_indices)
    let group = {
      id,
      is_public: false,
      old_types: initial_order,
      current_order: perm_orders[0],
      perm_orders,
      next_perm: 0,
      brand_seed: -1,
      brand: None,
      seen_shapes: Set::new(),
      canonicalized: false,
      sort_key,
    }
    groups.push(mrg_reset_iteration(group, flat, type_indices))
    id += 1
  }
  (groups, id)
}

///|
fn mrg_build_public_groups(
  info : MRGHeapTypeInfo,
  type_indices : Array[Int],
  next_id : Int,
) -> (Array[RecGroupInfo], Int) {
  let groups : Array[RecGroupInfo] = []
  let mut id = next_id
  let public_group_set : Set[Int] = Set::new()
  for g in info.public_groups {
    public_group_set.add(g)
  }
  for gi in 0..<info.flat.groups.length() {
    if !public_group_set.contains(gi) {
      continue
    }
    let order = info.flat.groups[gi].copy()
    let sort_key = "public:" + gi.to_string()
    let group = {
      id,
      is_public: true,
      old_types: order.copy(),
      current_order: order.copy(),
      perm_orders: [order.copy()],
      next_perm: 0,
      brand_seed: -1,
      brand: None,
      seen_shapes: Set::new(),
      canonicalized: true,
      sort_key,
    }
    groups.push(mrg_reset_iteration(group, info.flat, type_indices))
    id += 1
  }
  (groups, id)
}

///|
fn mrg_run(mod : Module) -> Result[Module, String] {
  let type_sec = match mod.type_sec {
    Some(type_sec) => type_sec
    None => return Ok(mod)
  }
  let TypeSec(recs) = type_sec
  if recs.is_empty() {
    return Ok(mod)
  }
  let info = collect_heap_type_info(mod)
  ignore(info.public_types.length())
  ignore(info.visibility_map.length())
  let flat = info.flat
  if flat.subtypes.is_empty() {
    return Ok(mod)
  }
  let type_indices = compute_type_indices_for_shape_ordering(flat)
  let adjacency = mrg_private_adjacency(info.private_types, flat)
  let sccs = compute_sccs(info.private_types, adjacency)
  let (public_groups, next_id) = mrg_build_public_groups(info, type_indices, 0)
  let (private_groups, _next_id) = mrg_build_private_groups(
    sccs, flat, type_indices, next_id,
  )
  let groups = public_groups.copy()
  for g in private_groups {
    groups.push(g)
  }
  update_shapes(groups, flat, type_indices)
  rewrite_types(mod, groups, flat)
}

///|
fn minimize_rec_groups(mod : Module) -> Result[Module, String] {
  mrg_run(mod)
}

///|
fn mrg_count_types(mod : Module) -> Int {
  match mod.type_sec {
    Some(TypeSec(recs)) => {
      let mut n = 0
      for rec in recs {
        match rec {
          SingleRecType(_) => n += 1
          GroupRecType(sts) => n += sts.length()
        }
      }
      n
    }
    None => 0
  }
}

///|
fn mrg_group_sizes(mod : Module) -> Array[Int] {
  let out : Array[Int] = []
  match mod.type_sec {
    Some(TypeSec(recs)) =>
      for rec in recs {
        match rec {
          SingleRecType(_) => out.push(1)
          GroupRecType(sts) => out.push(sts.length())
        }
      }
    None => ()
  }
  out
}

///|
fn mrg_group_shape_keys(mod : Module) -> Array[String] {
  let out : Array[String] = []
  match mod.type_sec {
    Some(TypeSec(recs)) => {
      let flat = mrg_flatten_types(TypeSec::new(recs))
      let type_indices = compute_type_indices_for_shape_ordering(flat)
      for group in flat.groups {
        let order = group.copy()
        let local_pos : Map[Int, Int] = Map::new()
        for i in 0..<order.length() {
          local_pos[order[i]] = i
        }
        let subtypes : Array[SubType] = []
        for idx in order {
          subtypes.push(
            mrg_rewrite_subtype_for_shape(
              flat.subtypes[idx],
              flat.group_starts[idx],
              flat.subtypes.length(),
              local_pos,
              type_indices,
            ),
          )
        }
        out.push(
          comparable_shape(subtypes, MRGFeatures::new(), type_indices).key,
        )
      }
    }
    None => ()
  }
  out
}

///|
fn mrg_has_unique_group_shapes(mod : Module) -> Bool {
  let seen : Set[String] = Set::new()
  for key in mrg_group_shape_keys(mod) {
    if seen.contains(key) {
      return false
    }
    seen.add(key)
  }
  true
}

///|
fn mrg_void_func_type() -> RecType {
  RecType::new(SubType::comp_type(CompType::func([], [])))
}

///|
fn mrg_mutual_pair_group() -> RecType {
  let a = SubType::comp_type(
    CompType::struct_([
      FieldType::new(
        StorageType::val_type(
          ValType::ref_type(RefType::new(true, HeapType::new(TypeIdx::rec(1)))),
        ),
        Const,
      ),
    ]),
  )
  let b = SubType::comp_type(
    CompType::struct_([
      FieldType::new(
        StorageType::val_type(
          ValType::ref_type(RefType::new(true, HeapType::new(TypeIdx::rec(0)))),
        ),
        Const,
      ),
    ]),
  )
  RecType::group([a, b])
}

///|
fn mrg_nonsymmetric_pair_group() -> RecType {
  let a = SubType::comp_type(
    CompType::struct_([
      FieldType::new(
        StorageType::val_type(
          ValType::ref_type(RefType::new(true, HeapType::new(TypeIdx::rec(1)))),
        ),
        Const,
      ),
    ]),
  )
  let b = SubType::comp_type(
    CompType::struct_([
      FieldType::new(
        StorageType::val_type(
          ValType::ref_type(RefType::new(true, HeapType::new(TypeIdx::rec(0)))),
        ),
        Const,
      ),
      FieldType::new(StorageType::val_type(ValType::i32()), Const),
    ]),
  )
  RecType::group([a, b])
}

///|
fn mrg_singleton_i32_struct() -> RecType {
  RecType::new(
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(StorageType::val_type(ValType::i32()), Const),
      ]),
    ),
  )
}

///|
fn mrg_singleton_empty_struct() -> RecType {
  RecType::new(SubType::comp_type(CompType::struct_([])))
}

///|
fn mrg_simple_module_with_types(type_recs : Array[RecType]) -> Module {
  let mut func_type_idx = 0
  for i in 0..<(type_recs.length() - 1) {
    match type_recs[i] {
      SingleRecType(_) => func_type_idx += 1
      GroupRecType(sts) => func_type_idx += sts.length()
    }
  }
  Module::new()
  .with_type_sec(TypeSec::new(type_recs))
  .with_func_sec(
    FuncSec::new([TypeIdx::new(func_type_idx.reinterpret_as_uint())]),
  )
  .with_code_sec(CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]))
}

///|
test "minimize_rec_groups keeps mutually recursive private pair in one group" {
  let mod = mrg_simple_module_with_types([
    mrg_mutual_pair_group(),
    mrg_void_func_type(),
  ])
  let out = match minimize_rec_groups(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected minimize_rec_groups error: \{e}")
  }
  assert_eq(mrg_group_sizes(out), [2, 1])
}

///|
test "minimize_rec_groups splits independent private SCCs" {
  let mod = mrg_simple_module_with_types([
    mrg_singleton_empty_struct(),
    mrg_singleton_empty_struct(),
    mrg_void_func_type(),
  ])
  let out = match minimize_rec_groups(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected minimize_rec_groups error: \{e}")
  }
  assert_eq(mrg_group_sizes(out).length(), 3)
  assert_true(mrg_has_unique_group_shapes(out))
}

///|
test "minimize_rec_groups orders supertype before subtype inside SCC" {
  let super_sub_group = RecType::group([
    SubType::new(
      false,
      [TypeIdx::rec(1)],
      CompType::struct_([
        FieldType::new(
          StorageType::val_type(
            ValType::ref_type(
              RefType::new(true, HeapType::new(TypeIdx::rec(1))),
            ),
          ),
          Const,
        ),
      ]),
    ),
    SubType::new(false, [TypeIdx::rec(0)], CompType::struct_([])),
  ])
  let mod = mrg_simple_module_with_types([super_sub_group, mrg_void_func_type()])
  let out = match minimize_rec_groups(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected minimize_rec_groups error: \{e}")
  }
  match out.type_sec {
    Some(TypeSec([GroupRecType(sts), SingleRecType(_)])) => {
      assert_eq(sts.length(), 2)
      assert_eq(sts[1].super_types().length(), 1)
      assert_eq(sts[1].super_types()[0], TypeIdx::rec(0))
    }
    _ => fail("expected first rec group with two subtypes")
  }
}

///|
test "minimize_rec_groups reserves public shapes and disambiguates private collisions" {
  let public_struct = mrg_singleton_i32_struct()
  let private_struct = mrg_singleton_i32_struct()
  let void_ty = mrg_void_func_type()
  let mod = Module::new()
    .with_type_sec(TypeSec::new([public_struct, private_struct, void_ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(
            ValType::ref_type(
              RefType::new(true, HeapType::new(TypeIdx::new(0))),
            ),
            false,
          ),
          Expr::new([
            Instruction::i32_const(I32(7)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("g"), ExternIdx::global(GlobalIdx::new(0))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
    .with_code_sec(
      CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
    )
  let out = match minimize_rec_groups(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected minimize_rec_groups error: \{e}")
  }
  assert_true(mrg_count_types(out) > 3)
  assert_true(mrg_has_unique_group_shapes(out))
}

///|
test "minimize_rec_groups resolves isomorphic private SCC collisions via permutation without brands" {
  let mod = mrg_simple_module_with_types([
    mrg_nonsymmetric_pair_group(),
    mrg_nonsymmetric_pair_group(),
    mrg_void_func_type(),
  ])
  let out = match minimize_rec_groups(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected minimize_rec_groups error: \{e}")
  }
  assert_eq(mrg_count_types(out), 5)
  assert_true(mrg_has_unique_group_shapes(out))
}

///|
test "minimize_rec_groups uses brand fallback when permutations are exhausted by automorphisms" {
  let mod = mrg_simple_module_with_types([
    mrg_mutual_pair_group(),
    mrg_mutual_pair_group(),
    mrg_mutual_pair_group(),
    mrg_void_func_type(),
  ])
  let out = match minimize_rec_groups(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected minimize_rec_groups error: \{e}")
  }
  assert_true(mrg_count_types(out) > 7)
  assert_true(mrg_has_unique_group_shapes(out))
}

///|
test "minimize_rec_groups singleton brand differs from singleton real type" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        mrg_singleton_i32_struct(),
        mrg_singleton_i32_struct(),
        mrg_void_func_type(),
      ]),
    )
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(
            ValType::ref_type(
              RefType::new(true, HeapType::new(TypeIdx::new(0))),
            ),
            false,
          ),
          Expr::new([
            Instruction::i32_const(I32(1)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("pubg"), ExternIdx::global(GlobalIdx::new(0))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
    .with_code_sec(
      CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
    )
  let out = match minimize_rec_groups(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected minimize_rec_groups error: \{e}")
  }
  match out.type_sec {
    Some(TypeSec(recs)) => {
      let mut saw_two_type_group = false
      for rec in recs {
        match rec {
          GroupRecType(sts) =>
            if sts.length() == 2 {
              saw_two_type_group = true
              assert_not_eq(sts[0], sts[1])
            }
          _ => ()
        }
      }
      assert_true(saw_two_type_group)
    }
    None => fail("expected type section")
  }
}

///|
test "minimize_rec_groups preserves distinct identity via non-colliding group shapes" {
  let a = mrg_singleton_empty_struct()
  let b = mrg_singleton_empty_struct()
  let void_ty = mrg_void_func_type()
  let mod = Module::new()
    .with_type_sec(TypeSec::new([a, b, void_ty]))
    .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::ref_test(
                false,
                HeapType::new(TypeIdx::new(0)),
                TInstr::struct_new(TypeIdx::new(1), []),
              ),
            ),
          ]),
        ),
      ]),
    )
  let out = match minimize_rec_groups(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected minimize_rec_groups error: \{e}")
  }
  assert_true(mrg_has_unique_group_shapes(out))
}

///|
test "minimize_rec_groups is deterministic across repeated runs and declaration reordering" {
  let mod_a = mrg_simple_module_with_types([
    mrg_nonsymmetric_pair_group(),
    mrg_singleton_empty_struct(),
    mrg_void_func_type(),
  ])
  let once = match minimize_rec_groups(mod_a) {
    Ok(m) => m
    Err(e) => fail("unexpected minimize_rec_groups error: \{e}")
  }
  let twice = match minimize_rec_groups(once) {
    Ok(m) => m
    Err(e) => fail("unexpected minimize_rec_groups error on second run: \{e}")
  }
  assert_eq(once, twice)
  let mod_b = mrg_simple_module_with_types([
    mrg_singleton_empty_struct(),
    mrg_nonsymmetric_pair_group(),
    mrg_void_func_type(),
  ])
  let out_b = match minimize_rec_groups(mod_b) {
    Ok(m) => m
    Err(e) =>
      fail("unexpected minimize_rec_groups error on reordered input: \{e}")
  }
  assert_eq(mrg_group_shape_keys(once), mrg_group_shape_keys(out_b))
}

///|
test "minimize_rec_groups mixed stress module validates and has no remaining collisions" {
  let rec0 = mrg_nonsymmetric_pair_group()
  let rec1 = mrg_mutual_pair_group()
  let rec2 = mrg_singleton_i32_struct()
  let rec3 = mrg_singleton_empty_struct()
  let rec4 = mrg_void_func_type()
  let mod = Module::new()
    .with_type_sec(TypeSec::new([rec0, rec1, rec2, rec3, rec4]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(
            ValType::ref_type(
              RefType::new(true, HeapType::new(TypeIdx::new(4))),
            ),
            false,
          ),
          Expr::new([Instruction::ref_null(HeapType::new(TypeIdx::new(4)))]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("pubg"), ExternIdx::global(GlobalIdx::new(0))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(6)]))
    .with_code_sec(
      CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
    )
  let out = match minimize_rec_groups(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected minimize_rec_groups error: \{e}")
  }
  assert_true(mrg_has_unique_group_shapes(out))
  assert_eq(@validate.validate_module(out), Ok(()))
}

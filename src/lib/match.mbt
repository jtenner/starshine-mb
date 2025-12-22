pub trait Match {
  matches(Self, Self, Env) -> Bool
}

pub impl [T: Match] Match for Array[T] with matches(self, other, env) {
  if self.length() != other.length() { return false }
  for i in 0..<self.length() {
    if !self[i].matches(other[i], env) { return false }
  }
  true
}

pub impl Match for CompType with matches(self, other, env) {
  match (self, other) {
    (FuncCompType(p0, r0), FuncCompType(p1, r1)) =>
      Match::matches(p0, p1, env) && Match::matches(r0, r1, env)

    (StructCompType(fs0), StructCompType(fs1)) =>
      Match::matches(fs0, fs1, env)

    (ArrayCompType(f0), ArrayCompType(f1)) =>
      Match::matches(f0, f1, env)

    _ => false
  }
}

pub impl Match for ValType with matches(self, other, env) {
  match (self, other) {
    (BotValType, _) => true
    (_, BotValType) => true
    (RefTypeValType(r0), RefTypeValType(r1)) => r0.matches(r1, env)
    _ => self == other
  }
}

pub impl Match for RefType with matches(self, other, env) {
  let ht0 = self.get_heap_type()
  let ht1 = other.get_heap_type()

  // Heap type compatibility (start with equality; extend later)
  if !ht0.matches(ht1, env) { return false }

  // Nullability: non-null <: nullable
  let n0 = self.is_nullable()
  let n1 = other.is_nullable()
  (!n0 && n1) || (n0 == n1)
}

pub impl Match for FieldType with matches(self, other, env) {
  let FieldType(st0, mut0) = self
  let FieldType(st1, mut1) = other
  st0.matches(st1, env) && mut0 == mut1
}

pub impl Match for StorageType with matches(self, other, _) {
  self == other // or structural, if needed
}

pub impl Match for AbsHeapType with matches(self, other, _) {
  if self == other { return true }

  match (self, other) {
    // eq <: any
    (EqAbsHeapType, AnyAbsHeapType) => true

    // i31/struct/array <: eq
    (I31AbsHeapType, EqAbsHeapType) => true
    (StructAbsHeapType, EqAbsHeapType) => true
    (ArrayAbsHeapType, EqAbsHeapType) => true

    // none <: any
    (NoneAbsHeapType, AnyAbsHeapType) => true

    // “noX matches X” (i.e. noX <: X)
    (NoFuncAbsHeapType, FuncAbsHeapType) => true
    (NoExternAbsHeapType, ExternAbsHeapType) => true
    (NoExnAbsHeapType, ExnAbsHeapType) => true

    // If/when you add a true bottom heap type, handle it here.
    _ => false
  }
}
pub impl Match for HeapType with matches(self, other, env) {
  let fuel = env.global_types.length() + 16
  heaptype_matches_fuel(self, other, env, fuel)
}
fn heaptype_matches_fuel(
  h1: HeapType,
  h2: HeapType,
  env: Env,
  fuel: Int,
) -> Bool {
  if h1 == h2 { return true }
  if fuel <= 0 { return false }

  match (h1, h2) {
    (AbsHeapTypeHeapType(a1), AbsHeapTypeHeapType(a2)) =>
      a1.matches(a2, env)

    // Spec: defined type judgement
    (DefTypeHeapType(dt1), DefTypeHeapType(dt2)) =>
      deftype_matches_fuel(dt1, dt2, env, fuel - 1)

    // typeidx/recidx unfold on either side
    (HeapType(tidx), _) =>
      match env.resolve_subtype(tidx) {
        None => false
        Some(st1) => subtype_as_heap_fuel(st1, h2, env, fuel - 1)
      }

    (_, HeapType(tidx)) => heap_vs_typeidx_fuel(h1, tidx, env, fuel - 1)

    // deftype vs abs: use expansion-kind checks (struct/array/func → ...)
    (DefTypeHeapType(dt), AbsHeapTypeHeapType(abs)) =>
      deftype_matches_abs_fuel(dt, abs, env, fuel - 1)

    // abs vs deftype: conservative (generally false in subtype direction)
    (AbsHeapTypeHeapType(_), DefTypeHeapType(_)) => false

    _ => false
  }
}

fn subtype_as_heap_fuel(st: SubType, target: HeapType, env: Env, fuel: Int) -> Bool {
  if fuel <= 0 { return false }

  match st {
    CompTypeSubType(_) => false

    SubType(is_final, supers, ct) => {
      // 1) Direct shape match against abstract heap supertypes
      match target {
        AbsHeapTypeHeapType(abs) => {
          if comptype_matches_abs(ct, abs) { return true }
          // if final and direct failed => no subtyping via supertypes
          if is_final { return false }
        }
        _ => {
          if is_final {
            // final: only equal would have succeeded earlier via h1==h2
            // (we don't have an id to compare here), so stop.
            // Keep conservative.
            return false
          }
        }
      }

      // 2) Chase declared supertypes (typeuse*)
      for tu in supers {
        if heaptype_matches_fuel(HeapType(tu), target, env, fuel - 1) {
          return true
        }
      }

      false
    }
  }
}

fn comptype_matches_abs(ct: CompType, abs: AbsHeapType) -> Bool {
  match ct {
    StructCompType(_) =>
      abs == StructAbsHeapType || abs == EqAbsHeapType || abs == AnyAbsHeapType
    ArrayCompType(_) =>
      abs == ArrayAbsHeapType || abs == EqAbsHeapType || abs == AnyAbsHeapType
    FuncCompType(_, _) =>
      abs == FuncAbsHeapType || abs == AnyAbsHeapType
  }
}

fn heap_vs_typeidx_fuel(h: HeapType, target: TypeIdx, env: Env, fuel: Int) -> Bool {  if fuel <= 0 { return false }

  match h {
    AbsHeapTypeHeapType(_) => false

    HeapType(tidx1) =>
      typeidx_leq_typeidx_fuel(tidx1, target, env, fuel - 1, [])

    DefTypeHeapType(dt1) =>
      match dt1.project() {
        None => false
        Some(st1) => {
          let DefType(rt1, _) = dt1
          let env1 = env_with_rectype(env, rt1)
          match st1 {
            CompTypeSubType(_) => false
            SubType(is_final, supers, _) => {
              if is_final { return false }
              for tu in supers {
                if typeidx_leq_typeidx_fuel(tu, target, env1, fuel - 1, []) {
                  return true
                }
              }
              false
            }
          }
        }
      }
  }
}

fn deftype_matches_abs_fuel(
  dt: DefType,
  abs: AbsHeapType,
  _env: Env,
  fuel: Int,
) -> Bool {
  if fuel <= 0 { return false }

  // let DefType(rt, _) = dt
  // let env2 = env_with_rectype(env, rt)

  match dt.project() {
    None => false
    Some(st) =>
      match st.get_comptype() {
        StructCompType(_) =>
          abs == StructAbsHeapType ||
          abs == EqAbsHeapType ||
          abs == AnyAbsHeapType

        ArrayCompType(_) =>
          abs == ArrayAbsHeapType ||
          abs == EqAbsHeapType ||
          abs == AnyAbsHeapType

        FuncCompType(_, _) =>
          abs == FuncAbsHeapType ||
          abs == AnyAbsHeapType
      }
  }
}

fn env_with_rectype(env: Env, rt: RecType) -> Env {
  match rt {
    SingleRecType(st) => env_add_rec_group(env, [st])
    GroupRecType(sts) => env_add_rec_group(env, sts)
  }
}

// Adjust this to your preferred stack API (immut/mut)
fn env_add_rec_group(env: Env, group: Array[SubType]) -> Env {
  let rs = env.rec_stack.copy()
  rs.push(group)
  
  Env::{
    global_types: env.global_types,
    rec_stack: rs,
    funcs: env.funcs,
    tables: env.tables,
    mems: env.mems,
    globals: env.globals,
    elems: env.elems,
    datas: env.datas,
    tags: env.tags,
    locals: env.locals,
    labels: env.labels,
    return_type: env.return_type,
  }
}

pub impl Match for DefType with matches(self, other, env) {
  let fuel = env.global_types.length() + 16 // Int
  deftype_matches_fuel(self, other, env, fuel)
}

fn deftype_matches_fuel(
  dt1: DefType,
  dt2: DefType,
  env: Env,
  fuel: Int,
) -> Bool {
  // clos_C(dt1) == clos_C(dt2)
  if dt1 == dt2 { return true }
  if fuel <= 0 { return false }

  // Put dt1’s rectype in scope for any RecIdx references during unroll/chasing
  let DefType(rt1, _) = dt1
  let env1 = env_with_rectype(env, rt1)

  match dt1.project() {
    None => false
    Some(st1) =>
      match st1 {
        CompTypeSubType(_) => false
        SubType(is_final, supers, _) => {
          // final types have no proper subtypes
          if is_final { return false }

          let ht2 = DefTypeHeapType(dt2)

          for tu in supers {
            // “typeuse*[i] matches heaptype deftype2”
            if heaptype_matches_fuel(HeapType(tu), ht2, env1, fuel - 1) {
              return true
            }
          }

          false
        }
      }
  }
}

pub impl Match for Limits with matches(self, other, _) {
  match (self, other) {
    (I32Limits(n1, m1), I32Limits(n2, m2)) =>
      limits_range_matches_u64(n1.to_uint64(), m1.map(fn(x) { x.to_uint64() }),
                              n2.to_uint64(), m2.map(fn(x) { x.to_uint64() }))

    (I64Limits(n1, m1), I64Limits(n2, m2)) =>
      limits_range_matches_u64(n1, m1, n2, m2)

    _ => false
  }
}

// Implements: [n1..m1?] ≤ [n2..m2?]
fn limits_range_matches_u64(
  n1: UInt64,
  m1: UInt64?,
  n2: UInt64,
  m2: UInt64?,
) -> Bool {
  // n1 >= n2
  if n1 < n2 { return false }

  match (m1, m2) {
    // [n1..m1] ≤ [n2..m2] requires m1 <= m2
    (Some(x1), Some(x2)) => x1 <= x2

    // [n1..m1] ≤ [n2..∞] always (given n1>=n2)
    (Some(_), None) => true

    // [n1..∞] ≤ [n2..∞] ok
    (None, None) => true

    // [n1..∞] ≤ [n2..m2] impossible
    (None, Some(_)) => false
  }
}

pub impl Match for TagType with matches(self, other, env) {
  let TagType(a) = self
  let TagType(b) = other
  typeidx_leq_typeidx(a, b, env) && typeidx_leq_typeidx(b, a, env)
}

fn typeidx_leq_typeidx(a: TypeIdx, b: TypeIdx, env: Env) -> Bool {
  let fuel = env.global_types.length() + 16
  typeidx_leq_typeidx_fuel(a, b, env, fuel, [])
}

fn typeidx_leq_typeidx_fuel(
  a: TypeIdx,
  b: TypeIdx,
  env: Env,
  fuel: Int,
  visited: Array[TypeIdx],
) -> Bool {
  if a == b { return true }
  if fuel <= 0 { return false }

  // cycle guard
  for v in visited {
    if v == a { return false }
  }

  match env.resolve_subtype(a) {
    None => false
    Some(st) =>
      match st {
        CompTypeSubType(_) => false

        SubType(is_final, _, _) => {
          if is_final { return false }

          let visited2 = visited.copy()
          visited2.push(a)

          for s in st.super_types() {
            if typeidx_leq_typeidx_fuel(s, b, env, fuel - 1, visited2) {
              return true
            }
          }

          false
        }
      }
  }
}

pub impl Match for MemType with matches(self, other, env) {
  let MemType(l1) = self
  let MemType(l2) = other
  l1.matches(l2, env)
}

pub impl Match for GlobalType with matches(self, other, env) {
  let GlobalType(v1, m1) = self
  let GlobalType(v2, m2) = other

  // Always: valtype1 ≤ valtype2
  if !v1.matches(v2, env) { return false }

  match (m1, m2) {
    // const ≤ const (covariant already checked)
    (false, false) => true

    // mut ≤ mut requires invariance
    (true, true) => v2.matches(v1, env)

    // mixed mutability does not match
    _ => false
  }
}

pub impl Match for TableType with matches(self, other, env) {
  let TableType(rt1, lim1) = self
  let TableType(rt2, lim2) = other

  lim1.matches(lim2, env) && rt1.matches(rt2, env) && rt2.matches(rt1, env)
}

pub impl Match for ExternType with matches(self, other, env) {
  match (self, other) {
    (TagExternType(t1), TagExternType(t2)) => t1.matches(t2, env)

    (GlobalExternType(g1), GlobalExternType(g2)) => g1.matches(g2, env)

    (MemExternType(m1), MemExternType(m2)) => m1.matches(m2, env)

    (TableExternType(t1), TableExternType(t2)) => t1.matches(t2, env)

    // Spec says: func deftype1 ≤ func deftype2 iff deftype1 ≤ deftype2.
    (FuncExternType(ti1), FuncExternType(ti2)) => {
      // Optional: ensure both are actually function types
      if env.resolve_functype(ti1) is None { return false }
      if env.resolve_functype(ti2) is None { return false }

      typeidx_leq_typeidx(ti1, ti2, env)
    }

    _ => false
  }
}

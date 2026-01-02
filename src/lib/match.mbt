///|
pub trait Match {
  matches(Self, Self, Env) -> Bool
}

///|
pub trait DeclMatch {
  matches_decl(Self, Self, Env) -> Bool
}

///|
pub impl[T : Match] Match for Array[T] with matches(self, other, env) {
  if self.length() != other.length() {
    return false
  }
  for i in 0..<self.length() {
    if !self[i].matches(other[i], env) {
      return false
    }
  }
  true
}

///|
pub impl Match for CompType with matches(self, other, env) {
  match (self, other) {
    // self <: other
    (FuncCompType(p_self, r_self), FuncCompType(p_other, r_other)) =>
      // contravariant in params, covariant in results
      Match::matches(p_other, p_self, env) &&
      Match::matches(r_self, r_other, env)
    (StructCompType(fs0), StructCompType(fs1)) => Match::matches(fs0, fs1, env)
    (ArrayCompType(f0), ArrayCompType(f1)) => Match::matches(f0, f1, env)
    _ => false
  }
}

///|
pub impl Match for ValType with matches(self, other, env) {
  match (self, other) {
    (RefTypeValType(r0), RefTypeValType(r1)) => r0.matches(r1, env)
    _ => self == other
  }
}

///|
pub impl Match for RefType with matches(self, other, env) {
  let ht0 = self.get_heap_type()
  let ht1 = other.get_heap_type()

  // Heap type compatibility (start with equality; extend later)
  if !ht0.matches(ht1, env) {
    return false
  }

  // Nullability: non-null <: nullable
  let n0 = self.is_nullable()
  let n1 = other.is_nullable()
  (!n0 && n1) || n0 == n1
}

///|
pub impl Match for FieldType with matches(self, other, env) {
  let FieldType(st0, m0) = self
  let FieldType(st1, m1) = other
  match (m0, m1) {
    (Const, Const) => st0.matches(st1, env) // covariant
    (Var, Var) => st0.matches(st1, env) && st1.matches(st0, env) // invariant
    _ => false
  }
}

///|
pub impl Match for StorageType with matches(self, other, env) {
  match (self, other) {
    (ValTypeStorageType(v1), ValTypeStorageType(v2)) => v1.matches(v2, env)
    (PackTypeStorageType(p1), PackTypeStorageType(p2)) => p1 == p2
    _ => false
  }
}

pub impl Match for AbsHeapType with matches(self, other, _) {
  if self == other {
    return true
  }
  match (self, other) {
    // eq <: any
    (EqAbsHeapType, AnyAbsHeapType) => true

    // i31/struct/array <: eq
    (I31AbsHeapType, EqAbsHeapType) => true
    (StructAbsHeapType, EqAbsHeapType) => true
    (ArrayAbsHeapType, EqAbsHeapType) => true

    // i31/struct/array <: any (transitive via eq)
    (I31AbsHeapType, AnyAbsHeapType) => true
    (StructAbsHeapType, AnyAbsHeapType) => true
    (ArrayAbsHeapType, AnyAbsHeapType) => true

    // none <: all internal types
    (NoneAbsHeapType, AnyAbsHeapType) => true
    (NoneAbsHeapType, EqAbsHeapType) => true
    (NoneAbsHeapType, I31AbsHeapType) => true
    (NoneAbsHeapType, StructAbsHeapType) => true
    (NoneAbsHeapType, ArrayAbsHeapType) => true

    // nofunc <: func
    (NoFuncAbsHeapType, FuncAbsHeapType) => true

    // noextern <: extern
    (NoExternAbsHeapType, ExternAbsHeapType) => true

    // noexn <: exn
    (NoExnAbsHeapType, ExnAbsHeapType) => true

    _ => false
  }
}

///|
pub impl Match for HeapType with matches(self, other, env) {
  let fuel = env.global_types.length() + 16
  heaptype_matches_fuel(self, other, env, fuel)
}

///|
fn heaptype_matches_fuel(
  h1 : HeapType,
  h2 : HeapType,
  env : Env,
  fuel : Int,
) -> Bool {
  if h1 == h2 {
    return true
  }
  if fuel <= 0 {
    return false
  }
  match (h1, h2) {
    (AbsHeapTypeHeapType(a1), AbsHeapTypeHeapType(a2)) => a1.matches(a2, env)

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
  }
}

fn subtype_as_heap_fuel(
  st : SubType,
  target : HeapType,
  env : Env,
  fuel : Int,
) -> Bool {
  if fuel <= 0 {
    return false
  }
  
  let (is_final, supers, ct) = match st {
    CompTypeSubType(ct) => (false, [], ct)
    SubType(is_final, supers, ct) => (is_final, supers, ct)
  }

  // 1) Direct shape match against abstract heap supertypes
  match target {
    AbsHeapTypeHeapType(abs) => {
      if comptype_matches_abs(ct, abs) {
        return true
      }
      if is_final {
        return false
      }
    }
    _ =>
      if is_final {
        return false
      }
  }

  // 2) Chase declared supertypes
  for tu in supers {
    if heaptype_matches_fuel(HeapType(tu), target, env, fuel - 1) {
      return true
    }
  }
  false
}

///|
fn comptype_matches_abs(ct : CompType, abs : AbsHeapType) -> Bool {
  match ct {
    StructCompType(_) =>
      abs == StructAbsHeapType || abs == EqAbsHeapType || abs == AnyAbsHeapType
    ArrayCompType(_) =>
      abs == ArrayAbsHeapType || abs == EqAbsHeapType || abs == AnyAbsHeapType
    FuncCompType(_, _) => abs == FuncAbsHeapType || abs == AnyAbsHeapType
  }
}

///|
fn heap_vs_typeidx_fuel(
  h : HeapType,
  target : TypeIdx,
  env : Env,
  fuel : Int,
) -> Bool {
  if fuel <= 0 {
    return false
  }
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
              if is_final {
                return false
              }
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

///|
fn deftype_matches_abs_fuel(
  dt : DefType,
  abs : AbsHeapType,
  _env : Env,
  fuel : Int,
) -> Bool {
  if fuel <= 0 {
    return false
  }

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
        FuncCompType(_, _) => abs == FuncAbsHeapType || abs == AnyAbsHeapType
      }
  }
}

///|
fn env_with_rectype(env : Env, rt : RecType) -> Env {
  match rt {
    SingleRecType(st) => env_add_rec_group(env, [st])
    GroupRecType(sts) => env_add_rec_group(env, sts)
  }
}

// Adjust this to your preferred stack API (immut/mut)

///|
fn env_add_rec_group(env : Env, group : Array[SubType]) -> Env {
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

///|
pub impl Match for DefType with matches(self, other, env) {
  let fuel = env.global_types.length() + 16 // Int
  deftype_matches_fuel(self, other, env, fuel)
}

///|
fn deftype_matches_fuel(
  dt1 : DefType,
  dt2 : DefType,
  env : Env,
  fuel : Int,
) -> Bool {
  // clos_C(dt1) == clos_C(dt2)
  if dt1 == dt2 {
    return true
  }
  if fuel <= 0 {
    return false
  }

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
          if is_final {
            return false
          }
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

///|
pub impl Match for Limits with matches(self, other, _) {
  match (self, other) {
    (I32Limits(n1, m1), I32Limits(n2, m2)) =>
      limits_range_matches_u64(
        n1.to_uint64(),
        m1.map(fn(x) { x.to_uint64() }),
        n2.to_uint64(),
        m2.map(fn(x) { x.to_uint64() }),
      )
    (I64Limits(n1, m1), I64Limits(n2, m2)) =>
      limits_range_matches_u64(n1, m1, n2, m2)
    _ => false
  }
}

// Implements: [n1..m1?] ≤ [n2..m2?]

///|
fn limits_range_matches_u64(
  n1 : UInt64,
  m1 : UInt64?,
  n2 : UInt64,
  m2 : UInt64?,
) -> Bool {
  // n1 >= n2
  if n1 < n2 {
    return false
  }
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

///|
pub impl Match for TagType with matches(self, other, env) {
  let TagType(a) = self
  let TagType(b) = other
  typeidx_leq_typeidx(a, b, env) && typeidx_leq_typeidx(b, a, env)
}

///|
fn typeidx_leq_typeidx(a : TypeIdx, b : TypeIdx, env : Env) -> Bool {
  let fuel = env.global_types.length() + 16
  typeidx_leq_typeidx_fuel(a, b, env, fuel, [])
}

///|
fn typeidx_leq_typeidx_fuel(
  a : TypeIdx,
  b : TypeIdx,
  env : Env,
  fuel : Int,
  visited : Array[TypeIdx],
) -> Bool {
  if a == b {
    return true
  }
  if fuel <= 0 {
    return false
  }

  // cycle guard
  for v in visited {
    if v == a {
      return false
    }
  }
  match env.resolve_subtype(a) {
    None => false
    Some(st) =>
      match st {
        CompTypeSubType(_) => false
        SubType(is_final, _, _) => {
          if is_final {
            return false
          }
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

///|
pub impl Match for MemType with matches(self, other, env) {
  let MemType(l1) = self
  let MemType(l2) = other
  l1.matches(l2, env)
}

///|
pub impl Match for GlobalType with matches(self, other, env) {
  let GlobalType(v1, m1) = self
  let GlobalType(v2, m2) = other

  // Always: valtype1 ≤ valtype2
  if !v1.matches(v2, env) {
    return false
  }
  match (m1, m2) {
    // const ≤ const (covariant already checked)
    (false, false) => true

    // mut ≤ mut requires invariance
    (true, true) => v2.matches(v1, env)

    // mixed mutability does not match
    _ => false
  }
}

///|
pub impl Match for TableType with matches(self, other, env) {
  let TableType(rt1, lim1) = self
  let TableType(rt2, lim2) = other
  lim1.matches(lim2, env) && rt1.matches(rt2, env) && rt2.matches(rt1, env)
}

///|
pub impl Match for ExternType with matches(self, other, env) {
  match (self, other) {
    (TagExternType(t1), TagExternType(t2)) => t1.matches(t2, env)
    (GlobalExternType(g1), GlobalExternType(g2)) => g1.matches(g2, env)
    (MemExternType(m1), MemExternType(m2)) => m1.matches(m2, env)
    (TableExternType(t1), TableExternType(t2)) => t1.matches(t2, env)

    // Spec says: func deftype1 ≤ func deftype2 iff deftype1 ≤ deftype2.
    (FuncExternType(ti1), FuncExternType(ti2)) => {
      // Optional: ensure both are actually function types
      if env.resolve_functype(ti1) is None {
        return false
      }
      if env.resolve_functype(ti2) is None {
        return false
      }
      typeidx_leq_typeidx(ti1, ti2, env)
    }
    _ => false
  }
}

// =============================================================================
// AbsHeapType Tests
// =============================================================================

///|
test "AbsHeapType: reflexivity" {
  let env = empty_env()
  assert_true(AnyAbsHeapType.matches(AnyAbsHeapType, env))
  assert_true(EqAbsHeapType.matches(EqAbsHeapType, env))
  assert_true(I31AbsHeapType.matches(I31AbsHeapType, env))
  assert_true(StructAbsHeapType.matches(StructAbsHeapType, env))
  assert_true(ArrayAbsHeapType.matches(ArrayAbsHeapType, env))
  assert_true(FuncAbsHeapType.matches(FuncAbsHeapType, env))
  assert_true(ExternAbsHeapType.matches(ExternAbsHeapType, env))
  assert_true(NoneAbsHeapType.matches(NoneAbsHeapType, env))
  assert_true(NoFuncAbsHeapType.matches(NoFuncAbsHeapType, env))
  assert_true(NoExternAbsHeapType.matches(NoExternAbsHeapType, env))
  assert_true(NoExnAbsHeapType.matches(NoExnAbsHeapType, env))
}

///|
test "AbsHeapType: eq <: any" {
  let env = empty_env()
  assert_true(EqAbsHeapType.matches(AnyAbsHeapType, env))
  assert_false(AnyAbsHeapType.matches(EqAbsHeapType, env))
}

///|
test "AbsHeapType: i31/struct/array <: eq" {
  let env = empty_env()
  assert_true(I31AbsHeapType.matches(EqAbsHeapType, env))
  assert_true(StructAbsHeapType.matches(EqAbsHeapType, env))
  assert_true(ArrayAbsHeapType.matches(EqAbsHeapType, env))

  // reverse should not hold
  assert_false(EqAbsHeapType.matches(I31AbsHeapType, env))
  assert_false(EqAbsHeapType.matches(StructAbsHeapType, env))
  assert_false(EqAbsHeapType.matches(ArrayAbsHeapType, env))
}

///|
test "AbsHeapType: none <: any" {
  let env = empty_env()
  assert_true(NoneAbsHeapType.matches(AnyAbsHeapType, env))
  assert_false(AnyAbsHeapType.matches(NoneAbsHeapType, env))
}

///|
test "AbsHeapType: noX <: X (bottom types)" {
  let env = empty_env()
  assert_true(NoFuncAbsHeapType.matches(FuncAbsHeapType, env))
  assert_true(NoExternAbsHeapType.matches(ExternAbsHeapType, env))
  assert_true(NoExnAbsHeapType.matches(ExnAbsHeapType, env))

  // reverse should not hold
  assert_false(FuncAbsHeapType.matches(NoFuncAbsHeapType, env))
  assert_false(ExternAbsHeapType.matches(NoExternAbsHeapType, env))
  assert_false(ExnAbsHeapType.matches(NoExnAbsHeapType, env))
}

///|
test "AbsHeapType: unrelated types don't match" {
  let env = empty_env()
  assert_false(FuncAbsHeapType.matches(ExternAbsHeapType, env))
  assert_false(ExternAbsHeapType.matches(FuncAbsHeapType, env))
  assert_false(I31AbsHeapType.matches(FuncAbsHeapType, env))
  assert_false(StructAbsHeapType.matches(ArrayAbsHeapType, env))
}

// =============================================================================
// Limits Tests
// =============================================================================

///|
test "Limits: reflexivity" {
  let env = empty_env()
  let l1 = I32Limits(10, Some(100))
  let l2 = I64Limits(10UL, Some(100UL))
  assert_true(l1.matches(l1, env))
  assert_true(l2.matches(l2, env))
}

///|
test "Limits: n1 >= n2 required" {
  let env = empty_env()
  // [10..100] matches [5..100] (10 >= 5)
  assert_true(I32Limits(10, Some(100)).matches(I32Limits(5, Some(100)), env))
  // [5..100] does not match [10..100] (5 < 10)
  assert_false(I32Limits(5, Some(100)).matches(I32Limits(10, Some(100)), env))
}

///|
test "Limits: m1 <= m2 required when both bounded" {
  let env = empty_env()
  // [10..50] matches [10..100] (50 <= 100)
  assert_true(I32Limits(10, Some(50)).matches(I32Limits(10, Some(100)), env))
  // [10..100] does not match [10..50] (100 > 50)
  assert_false(I32Limits(10, Some(100)).matches(I32Limits(10, Some(50)), env))
}

///|
test "Limits: bounded matches unbounded" {
  let env = empty_env()
  // [10..100] matches [10..∞]
  assert_true(I32Limits(10, Some(100)).matches(I32Limits(10, None), env))
}

///|
test "Limits: unbounded matches unbounded" {
  let env = empty_env()
  assert_true(I32Limits(10, None).matches(I32Limits(10, None), env))
  assert_true(I32Limits(10, None).matches(I32Limits(5, None), env))
}

///|
test "Limits: unbounded does not match bounded" {
  let env = empty_env()
  // [10..∞] does not match [10..100]
  assert_false(I32Limits(10, None).matches(I32Limits(10, Some(100)), env))
}

///|
test "Limits: i32 vs i64 don't match" {
  let env = empty_env()
  assert_false(
    I32Limits(10, Some(100)).matches(I64Limits(10UL, Some(100UL)), env),
  )
  assert_false(
    I64Limits(10UL, Some(100UL)).matches(I32Limits(10, Some(100)), env),
  )
}

// =============================================================================
// MemType Tests
// =============================================================================

///|
test "MemType: delegates to limits" {
  let env = empty_env()
  let m1 = MemType(I32Limits(1, Some(10)))
  let m2 = MemType(I32Limits(1, Some(20)))
  let m3 = MemType(I32Limits(2, Some(10)))
  assert_true(m1.matches(m1, env))
  assert_true(m1.matches(m2, env)) // [1..10] <: [1..20]
  assert_false(m2.matches(m1, env)) // [1..20] not <: [1..10]
  assert_false(m1.matches(m3, env)) // min mismatch
}

// =============================================================================
// StorageType Tests
// =============================================================================

///|
test "StorageType: equality based" {
  let env = empty_env()
  // Assuming storage types like PackTypeStorageType(I8PackType), PackTypeStorageType(I16PackType), ValTypeStorageType
  let s1 = PackTypeStorageType(I8PackType)
  let s2 = PackTypeStorageType(I16PackType)
  assert_true(s1.matches(s1, env))
  assert_true(s2.matches(s2, env))
  assert_false(s1.matches(s2, env))
}

// =============================================================================
// FieldType Tests
// =============================================================================

///|
test "FieldType: const is covariant" {
  let env = empty_env()
  let st = PackTypeStorageType(I8PackType)
  let f1 = FieldType(st, Const)
  let f2 = FieldType(st, Const)
  assert_true(f1.matches(f2, env))
}

///|
test "FieldType: var is invariant" {
  let env = empty_env()
  let st = PackTypeStorageType(I8PackType)
  let f1 = FieldType(st, Var)
  let f2 = FieldType(st, Var)
  assert_true(f1.matches(f2, env))
}

///|
test "FieldType: const vs var don't match" {
  let env = empty_env()
  let st = PackTypeStorageType(I8PackType)
  let const_field = FieldType(st, Const)
  let var_field = FieldType(st, Var)
  assert_false(const_field.matches(var_field, env))
  assert_false(var_field.matches(const_field, env))
}

// =============================================================================
// ValType Tests
// =============================================================================

///|
test "ValType: primitive types use equality" {
  let env = empty_env()
  assert_true(
    NumTypeValType(I32NumType).matches(NumTypeValType(I32NumType), env),
  )
  assert_true(
    NumTypeValType(I64NumType).matches(NumTypeValType(I64NumType), env),
  )
  assert_true(
    NumTypeValType(F32NumType).matches(NumTypeValType(F32NumType), env),
  )
  assert_true(
    NumTypeValType(F64NumType).matches(NumTypeValType(F64NumType), env),
  )
  assert_false(
    NumTypeValType(I32NumType).matches(NumTypeValType(I64NumType), env),
  )
  assert_false(
    NumTypeValType(F32NumType).matches(NumTypeValType(F64NumType), env),
  )
}

///|
test "ValType: ref types delegate to RefType matching" {
  let env = empty_env()
  // (ref null any) matches (ref null any)
  let rt1 = HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType))
  let rt2 = HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType))
  assert_true(RefTypeValType(rt1).matches(RefTypeValType(rt2), env))
}

// =============================================================================
// RefType Tests
// =============================================================================

///|
test "RefType: nullability - non-null <: nullable" {
  let env = empty_env()
  let non_null = HeapTypeRefType(false, AbsHeapTypeHeapType(AnyAbsHeapType))
  let nullable = HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType))
  assert_true(non_null.matches(nullable, env))
  assert_false(nullable.matches(non_null, env))
}

///|
test "RefType: same nullability" {
  let env = empty_env()
  let null1 = HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType))
  let null2 = HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType))
  let non1 = HeapTypeRefType(false, AbsHeapTypeHeapType(AnyAbsHeapType))
  let non2 = HeapTypeRefType(false, AbsHeapTypeHeapType(AnyAbsHeapType))
  assert_true(null1.matches(null2, env))
  assert_true(non1.matches(non2, env))
}

///|
test "RefType: heap type subtyping with nullability" {
  let env = empty_env()
  // (ref null eq) <: (ref null any)
  let ref_eq = HeapTypeRefType(true, AbsHeapTypeHeapType(EqAbsHeapType))
  let ref_any = HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType))
  assert_true(ref_eq.matches(ref_any, env))
  assert_false(ref_any.matches(ref_eq, env))
}

///|
test "RefType: non-null subtype matches nullable supertype" {
  let env = empty_env()
  // (ref eq) <: (ref null any)
  let ref_eq_nonnull = HeapTypeRefType(
    false,
    AbsHeapTypeHeapType(EqAbsHeapType),
  )
  let ref_any_null = HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType))
  assert_true(ref_eq_nonnull.matches(ref_any_null, env))
}

// =============================================================================
// HeapType Tests (wrapping AbsHeapType)
// =============================================================================

///|
test "HeapType: abs heap type matching" {
  let env = empty_env()
  let h1 = AbsHeapTypeHeapType(EqAbsHeapType)
  let h2 = AbsHeapTypeHeapType(AnyAbsHeapType)
  assert_true(h1.matches(h2, env))
  assert_false(h2.matches(h1, env))
}

// =============================================================================
// Array[T] Tests
// =============================================================================

///|
test "Array: empty arrays match" {
  let env = empty_env()
  let arr1 : Array[ValType] = []
  let arr2 : Array[ValType] = []
  assert_true(Match::matches(arr1, arr2, env))
}

///|
test "Array: length mismatch" {
  let env = empty_env()
  let arr1 = [NumTypeValType(I32NumType)]
  let arr2 = [NumTypeValType(I32NumType), NumTypeValType(I64NumType)]
  assert_false(Match::matches(arr1, arr2, env))
}

///|
test "Array: element-wise matching" {
  let env = empty_env()
  let arr1 = [NumTypeValType(I32NumType), NumTypeValType(I64NumType)]
  let arr2 = [NumTypeValType(I32NumType), NumTypeValType(I64NumType)]
  let arr3 = [NumTypeValType(I32NumType), NumTypeValType(F64NumType)]
  assert_true(Match::matches(arr1, arr2, env))
  assert_false(Match::matches(arr1, arr3, env))
}

// =============================================================================
// CompType Tests
// =============================================================================

///|
test "CompType: FuncCompType - contravariant params, covariant results" {
  let env = empty_env()

  // For functions: (p1 -> r1) <: (p2 -> r2) iff p2 <: p1 and r1 <: r2
  // Using ref types for subtyping examples
  let ref_any = RefTypeValType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType)),
  )
  let ref_eq = RefTypeValType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(EqAbsHeapType)),
  )

  // func(any) -> eq  <:  func(eq) -> any
  // params: eq <: any (contravariant check)
  // results: eq <: any (covariant check)
  let f1 = FuncCompType([ref_any], [ref_eq])
  let f2 = FuncCompType([ref_eq], [ref_any])
  assert_true(f1.matches(f2, env))
  assert_false(f2.matches(f1, env))
}

///|
test "CompType: FuncCompType - reflexivity" {
  let env = empty_env()
  let f = FuncCompType([NumTypeValType(I32NumType)], [
    NumTypeValType(I64NumType),
  ])
  assert_true(f.matches(f, env))
}

///|
test "CompType: FuncCompType - param count mismatch" {
  let env = empty_env()
  let f1 = FuncCompType([NumTypeValType(I32NumType)], [])
  let f2 = FuncCompType(
    [NumTypeValType(I32NumType), NumTypeValType(I64NumType)],
    [],
  )
  assert_false(f1.matches(f2, env))
}

///|
test "CompType: StructCompType - field matching" {
  let env = empty_env()
  let s1 = StructCompType([FieldType(PackTypeStorageType(I8PackType), Const)])
  let s2 = StructCompType([FieldType(PackTypeStorageType(I8PackType), Const)])
  let s3 = StructCompType([FieldType(PackTypeStorageType(I16PackType), Const)])
  assert_true(s1.matches(s2, env))
  assert_false(s1.matches(s3, env))
}

///|
test "CompType: ArrayCompType - field matching" {
  let env = empty_env()
  let a1 = ArrayCompType(FieldType(PackTypeStorageType(I8PackType), Const))
  let a2 = ArrayCompType(FieldType(PackTypeStorageType(I8PackType), Const))
  let a3 = ArrayCompType(FieldType(PackTypeStorageType(I8PackType), Var))
  assert_true(a1.matches(a2, env))
  assert_false(a1.matches(a3, env))
}

///|
test "CompType: different kinds don't match" {
  let env = empty_env()
  let func = FuncCompType([], [])
  let struct_ = StructCompType([])
  let array = ArrayCompType(FieldType(PackTypeStorageType(I8PackType), Const))
  assert_false(func.matches(struct_, env))
  assert_false(struct_.matches(array, env))
  assert_false(array.matches(func, env))
}

// =============================================================================
// GlobalType Tests
// =============================================================================

///|
test "GlobalType: const is covariant" {
  let env = empty_env()
  let ref_eq = RefTypeValType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(EqAbsHeapType)),
  )
  let ref_any = RefTypeValType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType)),
  )
  let g1 = GlobalType(ref_eq, false) // const
  let g2 = GlobalType(ref_any, false) // const

  // (const eq) <: (const any)
  assert_true(g1.matches(g2, env))
  assert_false(g2.matches(g1, env))
}

///|
test "GlobalType: mut is invariant" {
  let env = empty_env()
  let ref_eq = RefTypeValType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(EqAbsHeapType)),
  )
  let ref_any = RefTypeValType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType)),
  )
  let g1 = GlobalType(ref_eq, true) // mut
  let g2 = GlobalType(ref_any, true) // mut

  // (mut eq) does not match (mut any) - invariant
  assert_false(g1.matches(g2, env))
  assert_false(g2.matches(g1, env))
}

///|
test "GlobalType: mut self-match" {
  let env = empty_env()
  let g = GlobalType(NumTypeValType(I32NumType), true)
  assert_true(g.matches(g, env))
}

///|
test "GlobalType: const vs mut don't match" {
  let env = empty_env()
  let const_g = GlobalType(NumTypeValType(I32NumType), false)
  let mut_g = GlobalType(NumTypeValType(I32NumType), true)
  assert_false(const_g.matches(mut_g, env))
  assert_false(mut_g.matches(const_g, env))
}

// =============================================================================
// TableType Tests
// =============================================================================

///|
test "TableType: limits and reftype must match" {
  let env = empty_env()
  let rt = HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType))
  let t1 = TableType(rt, I32Limits(0, Some(100)))
  let t2 = TableType(rt, I32Limits(0, Some(200)))

  // limits: [0..100] <: [0..200]
  // reftype must be invariant
  assert_true(t1.matches(t2, env))
}

///|
test "TableType: reftype is invariant" {
  let env = empty_env()
  let rt_func = HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType))
  let rt_any = HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType))
  let limits = I32Limits(0, Some(100))
  let t1 = TableType(rt_func, limits)
  let t2 = TableType(rt_any, limits)

  // Even though func might be a subtype, table element type is invariant
  assert_false(t1.matches(t2, env))
  assert_false(t2.matches(t1, env))
}

// =============================================================================
// TagType Tests
// =============================================================================

///|
test "TagType: requires bidirectional typeidx matching" {
  let env = empty_env()
  // Assuming typeidx 0 exists and matches itself
  let t1 = TagType(TypeIdx(0))
  let t2 = TagType(TypeIdx(0))
  assert_true(t1.matches(t2, env))
}

// =============================================================================
// ExternType Tests
// =============================================================================

///|
test "ExternType: different kinds don't match" {
  let env = empty_env()
  let mem = MemExternType(MemType(I32Limits(1, None)))
  let global = GlobalExternType(GlobalType(NumTypeValType(I32NumType), false))
  assert_false(mem.matches(global, env))
  assert_false(global.matches(mem, env))
}

///|
test "ExternType: MemExternType delegates to MemType" {
  let env = empty_env()
  let m1 = MemExternType(MemType(I32Limits(1, Some(10))))
  let m2 = MemExternType(MemType(I32Limits(1, Some(20))))
  assert_true(m1.matches(m2, env))
  assert_false(m2.matches(m1, env))
}

///|
test "ExternType: GlobalExternType delegates to GlobalType" {
  let env = empty_env()
  let g1 = GlobalExternType(GlobalType(NumTypeValType(I32NumType), false))
  let g2 = GlobalExternType(GlobalType(NumTypeValType(I32NumType), false))
  assert_true(g1.matches(g2, env))
}

///|
test "ExternType: TableExternType delegates to TableType" {
  let env = empty_env()
  let rt = HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType))
  let t1 = TableExternType(TableType(rt, I32Limits(0, Some(10))))
  let t2 = TableExternType(TableType(rt, I32Limits(0, Some(10))))
  assert_true(t1.matches(t2, env))
}

// =============================================================================
// Edge Cases & Integration Tests
// =============================================================================

///|
test "transitive subtyping: i31 <: eq <: any" {
  let env = empty_env()
  // i31 <: eq
  assert_true(I31AbsHeapType.matches(EqAbsHeapType, env))
  // eq <: any
  assert_true(EqAbsHeapType.matches(AnyAbsHeapType, env))
  // i31 <: any (transitively, though not directly in AbsHeapType.matches)
  // This should work through HeapType matching
  let h_i31 = AbsHeapTypeHeapType(I31AbsHeapType)
  let h_any = AbsHeapTypeHeapType(AnyAbsHeapType)
  assert_true(h_i31.matches(h_any, env))
}

///|
test "complex function type subtyping" {
  let env = empty_env()

  // func(ref null any, ref null any) -> (ref null eq)
  // <:
  // func(ref null eq, ref null eq) -> (ref null any)
  let ref_any = RefTypeValType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType)),
  )
  let ref_eq = RefTypeValType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(EqAbsHeapType)),
  )
  let f1 = FuncCompType([ref_any, ref_any], [ref_eq])
  let f2 = FuncCompType([ref_eq, ref_eq], [ref_any])
  assert_true(f1.matches(f2, env))
}

///|
test "nested ref type in struct field" {
  let env = empty_env()

  // const field with ref type - covariant
  let ref_eq = HeapTypeRefType(true, AbsHeapTypeHeapType(EqAbsHeapType))
  let ref_any = HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType))
  let st_eq = ValTypeStorageType(RefTypeValType(ref_eq))
  let st_any = ValTypeStorageType(RefTypeValType(ref_any))
  let f1 = FieldType(st_eq, Const)
  let f2 = FieldType(st_any, Const)
  assert_true(f1.matches(f2, env))
  assert_false(f2.matches(f1, env))
}

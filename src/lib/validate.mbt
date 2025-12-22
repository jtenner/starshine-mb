
///|
pub fn diff(rt1 : RefType, rt2 : RefType) -> Result[RefType, String] {
  let ht1 = rt1.get_heap_type()
  let ht2 = rt2.get_heap_type()
  if ht1 != ht2 {
    return Err("Heap Types differ")
  }
  if rt2.is_nullable() {
    // (ref null? ht) \ (ref null ht) = (ref ht)
    Ok(HeapTypeRefType(false, ht1))
  } else {
    // (ref null? ht) \ (ref ht) = (ref null? ht)
    Ok(HeapTypeRefType(rt1.is_nullable(), ht1))
  }
}


pub trait Validate {
  validate(Self, Env) -> Bool
}

pub trait ValidateMax {
  validate_max(Self, Env, UInt64) -> Bool
}

pub impl Validate for NumType with validate(_, _) {
  true
}

pub impl Validate for TypeIdx with validate(self, env) {
  env.resolve_typeidx_subtype(self) is Some(_)
}
pub impl Validate for HeapType with validate(self, env) {
  match self {
    AbsHeapTypeHeapType(abs) => abs.validate(env)
    HeapType(tidx) => tidx.validate(env)
    DefTypeHeapType(dt) => dt.validate(env)
  }
}

pub impl Validate for DefType with validate(self, env) {
  let DefType(rt, _) = self
  let env2 = env_with_rectype(env, rt)
  match self.project() {
    Some(st) => st.validate(env2)
    None => false
  }
}

pub impl Validate for AbsHeapType with validate(_, _) {
  true
}

pub impl Validate for ValType with validate(self, env) {
  match self {
    RefTypeValType(rt) => rt.validate(env)
    VecTypeValType => true
    NumTypeValType(nt) => nt.validate(env)
    BotValType => true
  }
}

pub impl [T : Validate] Validate for Array[T] with validate(self, env) {
  for v in self {
    if !v.validate(env) { return false }
  }
  true
}

///|
pub impl Validate for BlockType with validate(self, env) {
  match self {
    ValTypeBlockType(vt) => vt.validate(env)
    EmptyBlockType => true
    TypeIdxBlockType(tidx) =>
      env.resolve_typeidx_subtype(tidx) is Some(st) &&
      st.get_comptype() is FuncCompType(_, _)
  }
}

pub impl Validate for FuncType with validate(self, env) {
  let FuncType(t0, t1) = self
  Validate::validate(t0, env) && Validate::validate(t1, env)
}

pub impl Validate for CompType with validate(self, env) {
  match self {
    StructCompType(fts) => Validate::validate(fts, env)
    ArrayCompType(ft) => ft.validate(env)
    FuncCompType(v0, v1) => Validate::validate(v0, env) && Validate::validate(v1, env)
  }
}

pub impl Validate for RefType with validate(self, env) {
  match self {
    HeapTypeRefType(_, ht) => ht.validate(env)
    AbsHeapTypeRefType(abs) => abs.validate(env)
  }
}

pub impl Validate for FieldType with validate(self, env) {
  let FieldType(st, _) = self
  st.validate(env)
}

pub impl Validate for StorageType with validate(self, env) {
  match self {
    ValTypeStorageType(vt) => vt.validate(env)
    PackTypeStorageType(_) => true
  }
}

pub impl Validate for RecType with validate(self, env) {
  match self {
    SingleRecType(st) => st.validate(env)
    GroupRecType(sts) => Validate::validate(sts, env)
  }
}

pub impl Validate for SubType with validate(self, env) {
  match self {
    SubType(_, matches, ct) => {
      for m in matches {
        let valid = m.validate(env) &&
          env.resolve_subtype(m) is Some(t) &&
          ct.matches(t.get_comptype(), env)
        if !valid { return false }
      }
      true
    }
    CompTypeSubType(ct) => ct.validate(env)
  }
}

pub impl ValidateMax for Limits with validate_max(self, _, k) {
  match self {
    I32Limits(n, m) => {
      let n = n.to_uint64()
      n <= k && (m is None || (m is Some(m) && n <= m.to_uint64() && m.to_uint64() <= k))
    }
    I64Limits(n, m) => n <= k && (m is None || (m is Some(m) && n <= m && m <= k)) 
  }
}

pub impl Validate for LabelIdx with validate(self, env) {
  let LabelIdx(i) = self
  i < env.labels.length().reinterpret_as_uint()
}

pub impl Validate for TagIdx with validate(self, env) {
  let TagIdx(i) = self
  i < env.tags.length().reinterpret_as_uint()
}

pub impl Validate for TagType with validate(self, env) {
  let TagType(tidx) = self

  if !tidx.validate(env) { return false }

  match env.resolve_comptype(tidx) {
    Some(FuncCompType(params, results)) => {
      Validate::validate(params, env) && Validate::validate(results, env)
    }
    _ => false
  }
}

pub impl Validate for TagSec with validate(self, env) {
  let TagSec(t) = self
  Validate::validate(t, env)
}

pub impl Validate for Catch with validate(self, env) {
  match self {
    Catch(t, l) => t.validate(env) && l.validate(env)
    CatchRef(t, l) => t.validate(env) && l.validate(env)
    CatchAll(l) => l.validate(env)
    CatchAllRef(l) => l.validate(env)
  }
}

pub impl Validate for GlobalType with validate(self, env) {
  let GlobalType(vt, _) = self
  vt.validate(env)
}

pub impl Validate for MemType with validate(self, env) {
  let MemType(lim) = self
  lim.validate_max(env, 65536)
}

pub impl Validate for TableType with validate(self, env) {
  let TableType(rt, lim) = self
  rt.validate(env) && lim.validate_max(env, 4294967295)
}

pub impl Validate for ExternType with validate(self, env) {
  match self {
    TagExternType(tt) => tt.validate(env)
    GlobalExternType(gt) => gt.validate(env)
    MemExternType(mt) => mt.validate(env)
    TableExternType(tt) => tt.validate(env)
    FuncExternType(tidx) => env.resolve_functype(tidx) is Some(_)
  }
}


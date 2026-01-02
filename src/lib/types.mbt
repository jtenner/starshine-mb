///|
pub struct S33(UInt) derive(Eq)

///|
pub struct I32(Int) derive(Eq, Arbitrary)

///|
pub struct I64(Int64) derive(Eq, Arbitrary)

///|
pub struct F32(Float) derive(Eq, Arbitrary)

///|
pub struct F64(Double) derive(Eq, Arbitrary)

///|
pub struct U32(UInt) derive(Eq, Arbitrary)

///|
pub struct U64(UInt64) derive(Eq, Arbitrary)

///|
pub enum NumType {
  F32NumType
  F64NumType
  I32NumType
  I64NumType
} derive(Eq, Arbitrary)

///|
pub enum AbsHeapType {
  ExnAbsHeapType
  ArrayAbsHeapType
  StructAbsHeapType
  I31AbsHeapType
  EqAbsHeapType
  AnyAbsHeapType
  ExternAbsHeapType
  FuncAbsHeapType
  NoneAbsHeapType
  NoExternAbsHeapType
  NoFuncAbsHeapType
  NoExnAbsHeapType
} derive(Eq, Arbitrary)

///|
pub enum HeapType {
  AbsHeapTypeHeapType(AbsHeapType)
  HeapType(TypeIdx)
  DefTypeHeapType(DefType)
} derive(Eq)

///|
pub enum RefType {
  HeapTypeRefType(Bool, HeapType)
  AbsHeapTypeRefType(AbsHeapType)
} derive(Arbitrary)

///|
pub enum ValType {
  NumTypeValType(NumType)
  VecTypeValType
  RefTypeValType(RefType)
  BotValType
} derive(Eq)

///|
pub type ResultType = Array[ValType]

///|
pub enum PackType {
  I16PackType
  I8PackType
} derive(Eq, Arbitrary)

///|
pub enum StorageType {
  ValTypeStorageType(ValType)
  PackTypeStorageType(PackType)
} derive(Eq, Arbitrary)

///|
pub struct FieldType(StorageType, Mut) derive(Eq, Arbitrary)

///|
pub enum Mut {
  Const
  Var
} derive(Arbitrary, Eq)

///|
pub enum TypeIdx {
  TypeIdx(UInt)
  RecIdx(UInt)
} derive(Eq)

///|
pub struct FuncIdx(UInt) derive(Eq, Arbitrary)

///|
pub struct TableIdx(UInt) derive(Eq, Arbitrary)

///|
pub struct MemIdx(UInt) derive(Eq, Arbitrary)

///|
pub struct GlobalIdx(UInt) derive(Eq, Arbitrary)

///|
pub struct TagIdx(UInt) derive(Eq, Arbitrary)

///|
pub struct ElemIdx(UInt) derive(Eq, Arbitrary)

///|
pub struct DataIdx(UInt) derive(Eq, Arbitrary)

///|
pub struct LocalIdx(UInt) derive(Eq, Arbitrary)

///|
pub struct LabelIdx(UInt) derive(Eq, Arbitrary)

///|
pub struct LaneIdx(Byte) derive(Eq)

///|
pub enum CompType {
  ArrayCompType(FieldType)
  StructCompType(Array[FieldType])
  FuncCompType(ResultType, ResultType)
} derive(Eq)

///|
pub enum SubType {
  SubType(Bool, Array[TypeIdx], CompType)
  CompTypeSubType(CompType)
} derive(Eq)

///|
pub enum RecType {
  SingleRecType(SubType)
  GroupRecType(Array[SubType])
}

///|
pub struct DefType(RecType, UInt) derive(Eq)

///|
pub enum Limits {
  I32Limits(UInt, UInt?)
  I64Limits(UInt64, UInt64?)
} derive(Eq)

///|
pub struct TagType(TypeIdx) derive(Eq, Arbitrary)

///|
pub struct GlobalType(ValType, Bool) derive(Eq, Arbitrary)

///|
pub struct MemType(Limits) derive(Eq, Arbitrary)

///|
pub struct TableType(RefType, Limits) derive(Eq, Arbitrary)

///|
pub enum ExternType {
  FuncExternType(TypeIdx)
  TableExternType(TableType)
  MemExternType(MemType)
  GlobalExternType(GlobalType)
  TagExternType(TagType)
} derive(Eq, Arbitrary)

///|
pub enum ExternIdx {
  FuncExternIdx(FuncIdx)
  TableExternIdx(TableIdx)
  MemExternIdx(MemIdx)
  GlobalExternIdx(GlobalIdx)
  TagExternIdx(TagIdx)
} derive(Eq, Arbitrary)

///|
pub enum ElemMode {
  Passive
  Active(TableIdx, Expr)
  Declarative
} derive(Eq, Arbitrary)

///|
pub enum ElemKind {
  FuncsElemKind(Array[FuncIdx])
  FuncExprsElemKind(Array[Expr])
  TypedExprsElemKind(RefType, Array[Expr])
} derive(Eq, Arbitrary)

///|
pub struct Elem(ElemMode, ElemKind) derive(Eq)

///|
pub struct Expr(Array[Instruction]) derive(Eq)

///|
pub struct Import(Name, Name, ExternType) derive(Eq, Arbitrary)

///|
pub struct Table(TableType, Expr?) derive(Eq, Arbitrary)

///|
pub struct Global(GlobalType, Expr) derive(Eq, Arbitrary)

///|
pub struct Export(Name, ExternIdx) derive(Eq, Arbitrary)

///|
pub struct Locals(UInt, ValType) derive(Eq)

///|
pub enum DataMode {
  Active(MemIdx, Expr)
  Passive
} derive(Eq, Arbitrary)

///|
pub struct Data(DataMode, Bytes) derive(Eq)

///|
pub struct Name(StringView) derive(Eq)

///|
pub struct Module(
  Array[CustomSec],
  TypeSec?,
  ImportSec?,
  FuncSec?,
  TableSec?,
  MemSec?,
  TagSec?,
  GlobalSec?,
  ExportSec?,
  StartSec?,
  ElemSec?,
  DataCntSec?,
  CodeSec?,
  DataSec?
)

///|
pub struct FuncType(Array[ValType], Array[ValType])

///|
pub struct Env {
  global_types : Array[SubType]
  rec_stack : Stack[Array[SubType]]
  funcs : Array[FuncType]
  tables : Array[TableType]
  mems : Array[MemType]
  globals : Array[GlobalType]
  elems : Array[Elem]
  datas : Array[Data]
  tags : Array[TagType]
  locals : Array[ValType]
  labels : Stack[Array[ValType]]
  return_type : Array[ValType]?
}

///|
pub struct Func(Array[Locals], Expr) derive(Eq)

///|
pub impl @quickcheck.Arbitrary for CompType with arbitrary(t, state) {
  match state.next_uint() % 3 {
    1 => StructCompType(array_of_arbitrary(5, t, state))
    2 =>
      FuncCompType(
        array_of_arbitrary(5, t, state),
        array_of_arbitrary(5, t, state),
      )
    _ => ArrayCompType(@quickcheck.Arbitrary::arbitrary(t, state))
  }
}

///|
pub impl @quickcheck.Arbitrary for RecType with arbitrary(t, state) {
  if (state.next_uint() & 1) == 1 {
    SingleRecType(@quickcheck.Arbitrary::arbitrary(t, state))
  } else {
    GroupRecType(array_of_arbitrary(5, t, state))
  }
}

///|
pub impl @quickcheck.Arbitrary for HeapType with arbitrary(size, st) {
  if (st.next_uint() & 1) == 1 {
    AbsHeapTypeHeapType(@quickcheck.Arbitrary::arbitrary(size, st))
  } else {
    HeapType(@quickcheck.Arbitrary::arbitrary(size, st))
  }
  // Def types are not arbitrary
}

///|
pub impl @quickcheck.Arbitrary for ValType with arbitrary(size, st) {
  match st.next_uint() % 3 {
    0 => NumTypeValType(@quickcheck.Arbitrary::arbitrary(size, st))
    1 => VecTypeValType
    2 => RefTypeValType(@quickcheck.Arbitrary::arbitrary(size, st))
    _ => VecTypeValType
  }
}

///|
pub impl @quickcheck.Arbitrary for TypeIdx with arbitrary(_, st) {
  TypeIdx(st.next_uint())
  // recursive indexes are not arbitrary
}

///|
pub impl @quickcheck.Arbitrary for LaneIdx with arbitrary(_, state) {
  let b : Byte = (state.next_uint() % 16).to_byte()
  LaneIdx(b)
}

///|
pub impl @quickcheck.Arbitrary for SubType with arbitrary(t, st) {
  if st.next_uint() % 2 == 1 {
    SubType(
      st.next_uint() % 2 == 1,
      array_of_arbitrary(1, t, st),
      @quickcheck.Arbitrary::arbitrary(t, st),
    )
  } else {
    CompTypeSubType(@quickcheck.Arbitrary::arbitrary(t, st))
  }
}

///|
pub impl @quickcheck.Arbitrary for DefType with arbitrary(t, state) {
  let s = @quickcheck.Arbitrary::arbitrary(t, state)
  match s {
    SingleRecType(_) => DefType(s, 0)
    GroupRecType(g) => {
      let idx = state.next_uint() % g.length().reinterpret_as_uint()
      DefType(s, idx)
    }
  }
}

///|
pub impl @quickcheck.Arbitrary for Limits with arbitrary(_, state) {
  if (state.next_uint() & 1) == 1 {
    if (state.next_uint() & 1) == 1 {
      I32Limits(state.next_uint(), None)
    } else {
      let a : UInt = state.next_uint()
      let b : UInt = state.next_uint()
      let min = if a > b { b } else { a }
      let max = if a > b { a } else { b }
      I32Limits(min, Some(max))
    }
  } else if (state.next_uint() & 1) == 1 {
    I64Limits(state.next_uint64(), None)
  } else {
    let a : UInt64 = state.next_uint64()
    let b : UInt64 = state.next_uint64()
    let min = if a > b { b } else { a }
    let max = if a > b { a } else { b }
    I64Limits(min, Some(max))
  }
}

///|
pub impl @quickcheck.Arbitrary for Elem with arbitrary(size, state) {
  match state.next_uint() % 8 {
    // 0x00: Active(table 0) + FuncsElemKind
    0 => {
      let expr = @quickcheck.Arbitrary::arbitrary(size, state)
      let funcs = array_of_arbitrary(5, size, state)
      Elem(Active(TableIdx(0), expr), FuncsElemKind(funcs))
    }
    // 0x01: Passive + FuncsElemKind
    1 => {
      let funcs = array_of_arbitrary(5, size, state)
      Elem(Passive, FuncsElemKind(funcs))
    }
    // 0x02: Active(any table) + FuncsElemKind
    2 => {
      let ti : TableIdx = @quickcheck.Arbitrary::arbitrary(size, state)
      let expr = @quickcheck.Arbitrary::arbitrary(size, state)
      let funcs = array_of_arbitrary(5, size, state)
      Elem(Active(ti, expr), FuncsElemKind(funcs))
    }
    // 0x03: Declarative + FuncsElemKind
    3 => {
      let funcs = array_of_arbitrary(5, size, state)
      Elem(Declarative, FuncsElemKind(funcs))
    }
    // 0x04: Active(table 0) + FuncExprsElemKind
    4 => {
      let expr = @quickcheck.Arbitrary::arbitrary(size, state)
      let exprs = array_of_arbitrary(3, size, state)
      Elem(Active(TableIdx(0), expr), FuncExprsElemKind(exprs))
    }
    // 0x05: Passive + TypedExprsElemKind (covers FuncExprsElemKind too)
    5 => {
      let rt : RefType = @quickcheck.Arbitrary::arbitrary(size, state)
      let exprs = array_of_arbitrary(3, size, state)
      Elem(Passive, TypedExprsElemKind(rt, exprs))
    }
    // 0x06: Active(any table) + FuncExprsElemKind
    6 => {
      let ti : TableIdx = @quickcheck.Arbitrary::arbitrary(size, state)
      let expr = @quickcheck.Arbitrary::arbitrary(size, state)
      let exprs = array_of_arbitrary(3, size, state)
      Elem(Active(ti, expr), FuncExprsElemKind(exprs))
    }
    // 0x07: Declarative + TypedExprsElemKind
    _ => {
      let rt : RefType = @quickcheck.Arbitrary::arbitrary(size, state)
      let exprs = array_of_arbitrary(3, size, state)
      Elem(Declarative, TypedExprsElemKind(rt, exprs))
    }
  }
}

///|
pub impl @quickcheck.Arbitrary for Expr with arbitrary(t, state) {
  Expr([
    @quickcheck.Arbitrary::arbitrary(t, state),
    @quickcheck.Arbitrary::arbitrary(t, state),
    @quickcheck.Arbitrary::arbitrary(t, state),
  ])
}

///|
pub impl @quickcheck.Arbitrary for Locals with arbitrary(t, state) {
  let count = state.next_positive_int() % 3 + 1
  Locals(
    count.reinterpret_as_uint(),
    @quickcheck.Arbitrary::arbitrary(t, state),
  )
}

///|
pub impl @quickcheck.Arbitrary for Func with arbitrary(t, state) {
  let elems = []
  let count = state.next_positive_int() % 4 + 1
  loop count {
    0 => break ()
    n => {
      elems.push(@quickcheck.Arbitrary::arbitrary(t, state))
      continue n - 1
    }
  }
  Func(elems, @quickcheck.Arbitrary::arbitrary(t, state))
}

///|
pub impl @quickcheck.Arbitrary for Data with arbitrary(t, state) {
  let size = state.next_positive_int() % 10 + 1
  Data(
    @quickcheck.Arbitrary::arbitrary(t, state),
    @quickcheck.Arbitrary::arbitrary(size, state),
  )
}

///|
pub impl @quickcheck.Arbitrary for Name with arbitrary(_, state) {
  let count = state.next_positive_int() % 5
  let sb = StringBuilder::new(size_hint=count)
  loop (count, state.next_positive_int() % 91799) {
    (0, _) => break
    (n, i) if (i >= 32 && i <= 126) ||
      (i >= 160 && i <= 172) ||
      (i >= 174 && i <= 887) ||
      (i >= 890 && i <= 895) ||
      (i >= 900 && i <= 906) ||
      (i >= 908 && i <= 908) ||
      (i >= 910 && i <= 929) ||
      (i >= 931 && i <= 1327) ||
      (i >= 1329 && i <= 1366) ||
      (i >= 1369 && i <= 1418) ||
      (i >= 1421 && i <= 1423) ||
      (i >= 1425 && i <= 1479) ||
      (i >= 1488 && i <= 1514) ||
      (i >= 1519 && i <= 1524) ||
      (i >= 1542 && i <= 1563) ||
      (i >= 1565 && i <= 1756) ||
      (i >= 1758 && i <= 1805) ||
      (i >= 1808 && i <= 1866) ||
      (i >= 1869 && i <= 1969) ||
      (i >= 1984 && i <= 2042) ||
      (i >= 2045 && i <= 2093) ||
      (i >= 2096 && i <= 2110) ||
      (i >= 2112 && i <= 2139) ||
      (i >= 2142 && i <= 2142) ||
      (i >= 2144 && i <= 2154) ||
      (i >= 2160 && i <= 2191) ||
      (i >= 2199 && i <= 2273) ||
      (i >= 2275 && i <= 2435) ||
      (i >= 2437 && i <= 2444) ||
      (i >= 2447 && i <= 2448) ||
      (i >= 2451 && i <= 2472) ||
      (i >= 2474 && i <= 2480) ||
      (i >= 2482 && i <= 2482) ||
      (i >= 2486 && i <= 2489) ||
      (i >= 2492 && i <= 2500) ||
      (i >= 2503 && i <= 2504) ||
      (i >= 2507 && i <= 2510) ||
      (i >= 2519 && i <= 2519) ||
      (i >= 2524 && i <= 2525) ||
      (i >= 2527 && i <= 2531) ||
      (i >= 2534 && i <= 2558) ||
      (i >= 2561 && i <= 2563) ||
      (i >= 2565 && i <= 2570) ||
      (i >= 2575 && i <= 2576) ||
      (i >= 2579 && i <= 2600) ||
      (i >= 2602 && i <= 2608) ||
      (i >= 2610 && i <= 2611) ||
      (i >= 2613 && i <= 2614) ||
      (i >= 2616 && i <= 2617) ||
      (i >= 2620 && i <= 2620) ||
      (i >= 2622 && i <= 2626) ||
      (i >= 2631 && i <= 2632) ||
      (i >= 2635 && i <= 2637) ||
      (i >= 2641 && i <= 2641) ||
      (i >= 2649 && i <= 2652) ||
      (i >= 2654 && i <= 2654) ||
      (i >= 2662 && i <= 2678) ||
      (i >= 2689 && i <= 2691) ||
      (i >= 2693 && i <= 2701) ||
      (i >= 2703 && i <= 2705) ||
      (i >= 2707 && i <= 2728) ||
      (i >= 2730 && i <= 2736) ||
      (i >= 2738 && i <= 2739) ||
      (i >= 2741 && i <= 2745) ||
      (i >= 2748 && i <= 2757) ||
      (i >= 2759 && i <= 2761) ||
      (i >= 2763 && i <= 2765) ||
      (i >= 2768 && i <= 2768) ||
      (i >= 2784 && i <= 2787) ||
      (i >= 2790 && i <= 2801) ||
      (i >= 2809 && i <= 2815) ||
      (i >= 2817 && i <= 2819) ||
      (i >= 2821 && i <= 2828) ||
      (i >= 2831 && i <= 2832) ||
      (i >= 2835 && i <= 2856) ||
      (i >= 2858 && i <= 2864) ||
      (i >= 2866 && i <= 2867) ||
      (i >= 2869 && i <= 2873) ||
      (i >= 2876 && i <= 2884) ||
      (i >= 2887 && i <= 2888) ||
      (i >= 2891 && i <= 2893) ||
      (i >= 2901 && i <= 2903) ||
      (i >= 2908 && i <= 2909) ||
      (i >= 2911 && i <= 2915) ||
      (i >= 2918 && i <= 2935) ||
      (i >= 2946 && i <= 2947) ||
      (i >= 2949 && i <= 2954) ||
      (i >= 2958 && i <= 2960) ||
      (i >= 2962 && i <= 2965) ||
      (i >= 2969 && i <= 2970) ||
      (i >= 2972 && i <= 2972) ||
      (i >= 2974 && i <= 2975) ||
      (i >= 2979 && i <= 2980) ||
      (i >= 2984 && i <= 2986) ||
      (i >= 2990 && i <= 3001) ||
      (i >= 3006 && i <= 3010) ||
      (i >= 3014 && i <= 3016) ||
      (i >= 3018 && i <= 3021) ||
      (i >= 3024 && i <= 3024) ||
      (i >= 3031 && i <= 3031) ||
      (i >= 3046 && i <= 3066) ||
      (i >= 3072 && i <= 3084) ||
      (i >= 3086 && i <= 3088) ||
      (i >= 3090 && i <= 3112) ||
      (i >= 3114 && i <= 3129) ||
      (i >= 3132 && i <= 3140) ||
      (i >= 3142 && i <= 3144) ||
      (i >= 3146 && i <= 3149) ||
      (i >= 3157 && i <= 3158) ||
      (i >= 3160 && i <= 3162) ||
      (i >= 3164 && i <= 3165) ||
      (i >= 3168 && i <= 3171) ||
      (i >= 3174 && i <= 3183) ||
      (i >= 3191 && i <= 3212) ||
      (i >= 3214 && i <= 3216) ||
      (i >= 3218 && i <= 3240) ||
      (i >= 3242 && i <= 3251) ||
      (i >= 3253 && i <= 3257) ||
      (i >= 3260 && i <= 3268) ||
      (i >= 3270 && i <= 3272) ||
      (i >= 3274 && i <= 3277) ||
      (i >= 3285 && i <= 3286) ||
      (i >= 3292 && i <= 3294) ||
      (i >= 3296 && i <= 3299) ||
      (i >= 3302 && i <= 3311) ||
      (i >= 3313 && i <= 3315) ||
      (i >= 3328 && i <= 3340) ||
      (i >= 3342 && i <= 3344) ||
      (i >= 3346 && i <= 3396) ||
      (i >= 3398 && i <= 3400) ||
      (i >= 3402 && i <= 3407) ||
      (i >= 3412 && i <= 3427) ||
      (i >= 3430 && i <= 3455) ||
      (i >= 3457 && i <= 3459) ||
      (i >= 3461 && i <= 3478) ||
      (i >= 3482 && i <= 3505) ||
      (i >= 3507 && i <= 3515) ||
      (i >= 3517 && i <= 3517) ||
      (i >= 3520 && i <= 3526) ||
      (i >= 3530 && i <= 3530) ||
      (i >= 3535 && i <= 3540) ||
      (i >= 3542 && i <= 3542) ||
      (i >= 3544 && i <= 3551) ||
      (i >= 3558 && i <= 3567) ||
      (i >= 3570 && i <= 3572) ||
      (i >= 3585 && i <= 3642) ||
      (i >= 3647 && i <= 3675) ||
      (i >= 3713 && i <= 3714) ||
      (i >= 3716 && i <= 3716) ||
      (i >= 3718 && i <= 3722) ||
      (i >= 3724 && i <= 3747) ||
      (i >= 3749 && i <= 3749) ||
      (i >= 3751 && i <= 3773) ||
      (i >= 3776 && i <= 3780) ||
      (i >= 3782 && i <= 3782) ||
      (i >= 3784 && i <= 3790) ||
      (i >= 3792 && i <= 3801) ||
      (i >= 3804 && i <= 3807) ||
      (i >= 3840 && i <= 3911) ||
      (i >= 3913 && i <= 3948) ||
      (i >= 3953 && i <= 3991) ||
      (i >= 3993 && i <= 4028) ||
      (i >= 4030 && i <= 4044) ||
      (i >= 4046 && i <= 4058) ||
      (i >= 4096 && i <= 4293) ||
      (i >= 4295 && i <= 4295) ||
      (i >= 4301 && i <= 4301) ||
      (i >= 4304 && i <= 4680) ||
      (i >= 4682 && i <= 4685) ||
      (i >= 4688 && i <= 4694) ||
      (i >= 4696 && i <= 4696) ||
      (i >= 4698 && i <= 4701) ||
      (i >= 4704 && i <= 4744) ||
      (i >= 4746 && i <= 4749) ||
      (i >= 4752 && i <= 4784) ||
      (i >= 4786 && i <= 4789) ||
      (i >= 4792 && i <= 4798) ||
      (i >= 4800 && i <= 4800) ||
      (i >= 4802 && i <= 4805) ||
      (i >= 4808 && i <= 4822) ||
      (i >= 4824 && i <= 4880) ||
      (i >= 4882 && i <= 4885) ||
      (i >= 4888 && i <= 4954) ||
      (i >= 4957 && i <= 4988) ||
      (i >= 4992 && i <= 5017) ||
      (i >= 5024 && i <= 5109) ||
      (i >= 5112 && i <= 5117) ||
      (i >= 5120 && i <= 5788) ||
      (i >= 5792 && i <= 5880) ||
      (i >= 5888 && i <= 5909) ||
      (i >= 5919 && i <= 5942) ||
      (i >= 5952 && i <= 5971) ||
      (i >= 5984 && i <= 5996) ||
      (i >= 5998 && i <= 6000) ||
      (i >= 6002 && i <= 6003) ||
      (i >= 6016 && i <= 6109) ||
      (i >= 6112 && i <= 6121) ||
      (i >= 6128 && i <= 6137) ||
      (i >= 6144 && i <= 6157) ||
      (i >= 6159 && i <= 6169) ||
      (i >= 6176 && i <= 6264) ||
      (i >= 6272 && i <= 6314) ||
      (i >= 6320 && i <= 6389) ||
      (i >= 6400 && i <= 6430) ||
      (i >= 6432 && i <= 6443) ||
      (i >= 6448 && i <= 6459) ||
      (i >= 6464 && i <= 6464) ||
      (i >= 6468 && i <= 6509) ||
      (i >= 6512 && i <= 6516) ||
      (i >= 6528 && i <= 6571) ||
      (i >= 6576 && i <= 6601) ||
      (i >= 6608 && i <= 6618) ||
      (i >= 6622 && i <= 6683) ||
      (i >= 6686 && i <= 6750) ||
      (i >= 6752 && i <= 6780) ||
      (i >= 6783 && i <= 6793) ||
      (i >= 6800 && i <= 6809) ||
      (i >= 6816 && i <= 6829) ||
      (i >= 6832 && i <= 6877) ||
      (i >= 6880 && i <= 6891) ||
      (i >= 6912 && i <= 6988) ||
      (i >= 6990 && i <= 7155) ||
      (i >= 7164 && i <= 7223) ||
      (i >= 7227 && i <= 7241) ||
      (i >= 7245 && i <= 7306) ||
      (i >= 7312 && i <= 7354) ||
      (i >= 7357 && i <= 7367) ||
      (i >= 7376 && i <= 7418) ||
      (i >= 7424 && i <= 7957) ||
      (i >= 7960 && i <= 7965) ||
      (i >= 7968 && i <= 8005) ||
      (i >= 8008 && i <= 8013) ||
      (i >= 8016 && i <= 8023) ||
      (i >= 8025 && i <= 8025) ||
      (i >= 8027 && i <= 8027) ||
      (i >= 8029 && i <= 8029) ||
      (i >= 8031 && i <= 8061) ||
      (i >= 8064 && i <= 8116) ||
      (i >= 8118 && i <= 8132) ||
      (i >= 8134 && i <= 8147) ||
      (i >= 8150 && i <= 8155) ||
      (i >= 8157 && i <= 8175) ||
      (i >= 8178 && i <= 8180) ||
      (i >= 8182 && i <= 8190) ||
      (i >= 8192 && i <= 8202) ||
      (i >= 8208 && i <= 8233) ||
      (i >= 8239 && i <= 8287) ||
      (i >= 8304 && i <= 8305) ||
      (i >= 8308 && i <= 8334) ||
      (i >= 8336 && i <= 8348) ||
      (i >= 8352 && i <= 8385) ||
      (i >= 8400 && i <= 8432) ||
      (i >= 8448 && i <= 8587) ||
      (i >= 8592 && i <= 9257) ||
      (i >= 9280 && i <= 9290) ||
      (i >= 9312 && i <= 11123) ||
      (i >= 11126 && i <= 11507) ||
      (i >= 11513 && i <= 11557) ||
      (i >= 11559 && i <= 11559) ||
      (i >= 11565 && i <= 11565) ||
      (i >= 11568 && i <= 11623) ||
      (i >= 11631 && i <= 11632) ||
      (i >= 11647 && i <= 11670) ||
      (i >= 11680 && i <= 11686) ||
      (i >= 11688 && i <= 11694) ||
      (i >= 11696 && i <= 11702) ||
      (i >= 11704 && i <= 11710) ||
      (i >= 11712 && i <= 11718) ||
      (i >= 11720 && i <= 11726) ||
      (i >= 11728 && i <= 11734) ||
      (i >= 11736 && i <= 11742) ||
      (i >= 11744 && i <= 11869) ||
      (i >= 11904 && i <= 11929) ||
      (i >= 11931 && i <= 12019) ||
      (i >= 12032 && i <= 12245) ||
      (i >= 12272 && i <= 12351) ||
      (i >= 12353 && i <= 12438) ||
      (i >= 12441 && i <= 12543) ||
      (i >= 12549 && i <= 12591) ||
      (i >= 12593 && i <= 12686) ||
      (i >= 12688 && i <= 12773) ||
      (i >= 12783 && i <= 12830) ||
      (i >= 12832 && i <= 42124) ||
      (i >= 42128 && i <= 42182) ||
      (i >= 42192 && i <= 42539) ||
      (i >= 42560 && i <= 42743) ||
      (i >= 42752 && i <= 42972) ||
      (i >= 42993 && i <= 43052) ||
      (i >= 43056 && i <= 43065) ||
      (i >= 43072 && i <= 43127) ||
      (i >= 43136 && i <= 43205) ||
      (i >= 43214 && i <= 43225) ||
      (i >= 43232 && i <= 43347) ||
      (i >= 43359 && i <= 43388) ||
      (i >= 43392 && i <= 43469) ||
      (i >= 43471 && i <= 43481) ||
      (i >= 43486 && i <= 43518) ||
      (i >= 43520 && i <= 43574) ||
      (i >= 43584 && i <= 43597) ||
      (i >= 43600 && i <= 43609) ||
      (i >= 43612 && i <= 43714) ||
      (i >= 43739 && i <= 43766) ||
      (i >= 43777 && i <= 43782) ||
      (i >= 43785 && i <= 43790) ||
      (i >= 43793 && i <= 43798) ||
      (i >= 43808 && i <= 43814) ||
      (i >= 43816 && i <= 43822) ||
      (i >= 43824 && i <= 43883) ||
      (i >= 43888 && i <= 44013) ||
      (i >= 44016 && i <= 44025) ||
      (i >= 44032 && i <= 55203) ||
      (i >= 55216 && i <= 55238) ||
      (i >= 55243 && i <= 55291) ||
      (i >= 63744 && i <= 64109) ||
      (i >= 64112 && i <= 64217) ||
      (i >= 64256 && i <= 64262) ||
      (i >= 64275 && i <= 64279) ||
      (i >= 64285 && i <= 64310) ||
      (i >= 64312 && i <= 64316) ||
      (i >= 64318 && i <= 64318) ||
      (i >= 64320 && i <= 64321) ||
      (i >= 64323 && i <= 64324) ||
      (i >= 64326 && i <= 64975) ||
      (i >= 65008 && i <= 65049) ||
      (i >= 65056 && i <= 65106) ||
      (i >= 65108 && i <= 65126) ||
      (i >= 65128 && i <= 65131) ||
      (i >= 65136 && i <= 65140) ||
      (i >= 65142 && i <= 65276) ||
      (i >= 65281 && i <= 65470) ||
      (i >= 65474 && i <= 65479) ||
      (i >= 65482 && i <= 65487) ||
      (i >= 65490 && i <= 65495) ||
      (i >= 65498 && i <= 65500) ||
      (i >= 65504 && i <= 65510) ||
      (i >= 65512 && i <= 65518) ||
      (i >= 65532 && i <= 65533) ||
      (i >= 65536 && i <= 65547) ||
      (i >= 65549 && i <= 65574) ||
      (i >= 65576 && i <= 65594) ||
      (i >= 65596 && i <= 65597) ||
      (i >= 65599 && i <= 65613) ||
      (i >= 65616 && i <= 65629) ||
      (i >= 65664 && i <= 65786) ||
      (i >= 65792 && i <= 65794) ||
      (i >= 65799 && i <= 65843) ||
      (i >= 65847 && i <= 65934) ||
      (i >= 65936 && i <= 65948) ||
      (i >= 65952 && i <= 65952) ||
      (i >= 66000 && i <= 66045) ||
      (i >= 66176 && i <= 66204) ||
      (i >= 66208 && i <= 66256) ||
      (i >= 66272 && i <= 66299) ||
      (i >= 66304 && i <= 66339) ||
      (i >= 66349 && i <= 66378) ||
      (i >= 66384 && i <= 66426) ||
      (i >= 66432 && i <= 66461) ||
      (i >= 66463 && i <= 66499) ||
      (i >= 66504 && i <= 66517) ||
      (i >= 66560 && i <= 66717) ||
      (i >= 66720 && i <= 66729) ||
      (i >= 66736 && i <= 66771) ||
      (i >= 66776 && i <= 66811) ||
      (i >= 66816 && i <= 66855) ||
      (i >= 66864 && i <= 66915) ||
      (i >= 66927 && i <= 66938) ||
      (i >= 66940 && i <= 66954) ||
      (i >= 66956 && i <= 66962) ||
      (i >= 66964 && i <= 66965) ||
      (i >= 66967 && i <= 66977) ||
      (i >= 66979 && i <= 66993) ||
      (i >= 66995 && i <= 67001) ||
      (i >= 67003 && i <= 67004) ||
      (i >= 67008 && i <= 67059) ||
      (i >= 67072 && i <= 67382) ||
      (i >= 67392 && i <= 67413) ||
      (i >= 67424 && i <= 67431) ||
      (i >= 67456 && i <= 67461) ||
      (i >= 67463 && i <= 67504) ||
      (i >= 67506 && i <= 67514) ||
      (i >= 67584 && i <= 67589) ||
      (i >= 67592 && i <= 67592) ||
      (i >= 67594 && i <= 67637) ||
      (i >= 67639 && i <= 67640) ||
      (i >= 67644 && i <= 67644) ||
      (i >= 67647 && i <= 67669) ||
      (i >= 67671 && i <= 67742) ||
      (i >= 67751 && i <= 67759) ||
      (i >= 67808 && i <= 67826) ||
      (i >= 67828 && i <= 67829) ||
      (i >= 67835 && i <= 67867) ||
      (i >= 67871 && i <= 67897) ||
      (i >= 67903 && i <= 67929) ||
      (i >= 67968 && i <= 68023) ||
      (i >= 68028 && i <= 68047) ||
      (i >= 68050 && i <= 68099) ||
      (i >= 68101 && i <= 68102) ||
      (i >= 68108 && i <= 68115) ||
      (i >= 68117 && i <= 68119) ||
      (i >= 68121 && i <= 68149) ||
      (i >= 68152 && i <= 68154) ||
      (i >= 68159 && i <= 68168) ||
      (i >= 68176 && i <= 68184) ||
      (i >= 68192 && i <= 68255) ||
      (i >= 68288 && i <= 68326) ||
      (i >= 68331 && i <= 68342) ||
      (i >= 68352 && i <= 68405) ||
      (i >= 68409 && i <= 68437) ||
      (i >= 68440 && i <= 68466) ||
      (i >= 68472 && i <= 68497) ||
      (i >= 68505 && i <= 68508) ||
      (i >= 68521 && i <= 68527) ||
      (i >= 68608 && i <= 68680) ||
      (i >= 68736 && i <= 68786) ||
      (i >= 68800 && i <= 68850) ||
      (i >= 68858 && i <= 68903) ||
      (i >= 68912 && i <= 68921) ||
      (i >= 68928 && i <= 68965) ||
      (i >= 68969 && i <= 68997) ||
      (i >= 69006 && i <= 69007) ||
      (i >= 69216 && i <= 69246) ||
      (i >= 69248 && i <= 69289) ||
      (i >= 69291 && i <= 69293) ||
      (i >= 69296 && i <= 69297) ||
      (i >= 69314 && i <= 69319) ||
      (i >= 69328 && i <= 69336) ||
      (i >= 69370 && i <= 69415) ||
      (i >= 69424 && i <= 69465) ||
      (i >= 69488 && i <= 69513) ||
      (i >= 69552 && i <= 69579) ||
      (i >= 69600 && i <= 69622) ||
      (i >= 69632 && i <= 69709) ||
      (i >= 69714 && i <= 69749) ||
      (i >= 69759 && i <= 69820) ||
      (i >= 69822 && i <= 69826) ||
      (i >= 69840 && i <= 69864) ||
      (i >= 69872 && i <= 69881) ||
      (i >= 69888 && i <= 69940) ||
      (i >= 69942 && i <= 69959) ||
      (i >= 69968 && i <= 70006) ||
      (i >= 70016 && i <= 70111) ||
      (i >= 70113 && i <= 70132) ||
      (i >= 70144 && i <= 70161) ||
      (i >= 70163 && i <= 70209) ||
      (i >= 70272 && i <= 70278) ||
      (i >= 70280 && i <= 70280) ||
      (i >= 70282 && i <= 70285) ||
      (i >= 70287 && i <= 70301) ||
      (i >= 70303 && i <= 70313) ||
      (i >= 70320 && i <= 70378) ||
      (i >= 70384 && i <= 70393) ||
      (i >= 70400 && i <= 70403) ||
      (i >= 70405 && i <= 70412) ||
      (i >= 70415 && i <= 70416) ||
      (i >= 70419 && i <= 70440) ||
      (i >= 70442 && i <= 70448) ||
      (i >= 70450 && i <= 70451) ||
      (i >= 70453 && i <= 70457) ||
      (i >= 70459 && i <= 70468) ||
      (i >= 70471 && i <= 70472) ||
      (i >= 70475 && i <= 70477) ||
      (i >= 70480 && i <= 70480) ||
      (i >= 70487 && i <= 70487) ||
      (i >= 70493 && i <= 70499) ||
      (i >= 70502 && i <= 70508) ||
      (i >= 70512 && i <= 70516) ||
      (i >= 70528 && i <= 70537) ||
      (i >= 70539 && i <= 70539) ||
      (i >= 70542 && i <= 70542) ||
      (i >= 70544 && i <= 70581) ||
      (i >= 70583 && i <= 70592) ||
      (i >= 70594 && i <= 70594) ||
      (i >= 70597 && i <= 70597) ||
      (i >= 70599 && i <= 70602) ||
      (i >= 70604 && i <= 70613) ||
      (i >= 70615 && i <= 70616) ||
      (i >= 70625 && i <= 70626) ||
      (i >= 70656 && i <= 70747) ||
      (i >= 70749 && i <= 70753) ||
      (i >= 70784 && i <= 70855) ||
      (i >= 70864 && i <= 70873) ||
      (i >= 71040 && i <= 71093) ||
      (i >= 71096 && i <= 71133) ||
      (i >= 71168 && i <= 71236) ||
      (i >= 71248 && i <= 71257) ||
      (i >= 71264 && i <= 71276) ||
      (i >= 71296 && i <= 71353) ||
      (i >= 71360 && i <= 71369) ||
      (i >= 71376 && i <= 71395) ||
      (i >= 71424 && i <= 71450) ||
      (i >= 71453 && i <= 71467) ||
      (i >= 71472 && i <= 71494) ||
      (i >= 71680 && i <= 71739) ||
      (i >= 71840 && i <= 71922) ||
      (i >= 71935 && i <= 71942) ||
      (i >= 71945 && i <= 71945) ||
      (i >= 71948 && i <= 71955) ||
      (i >= 71957 && i <= 71958) ||
      (i >= 71960 && i <= 71989) ||
      (i >= 71991 && i <= 71992) ||
      (i >= 71995 && i <= 72006) ||
      (i >= 72016 && i <= 72025) ||
      (i >= 72096 && i <= 72103) ||
      (i >= 72106 && i <= 72151) ||
      (i >= 72154 && i <= 72164) ||
      (i >= 72192 && i <= 72263) ||
      (i >= 72272 && i <= 72354) ||
      (i >= 72368 && i <= 72440) ||
      (i >= 72448 && i <= 72457) ||
      (i >= 72544 && i <= 72551) ||
      (i >= 72640 && i <= 72673) ||
      (i >= 72688 && i <= 72697) ||
      (i >= 72704 && i <= 72712) ||
      (i >= 72714 && i <= 72758) ||
      (i >= 72760 && i <= 72773) ||
      (i >= 72784 && i <= 72812) ||
      (i >= 72816 && i <= 72847) ||
      (i >= 72850 && i <= 72871) ||
      (i >= 72873 && i <= 72886) ||
      (i >= 72960 && i <= 72966) ||
      (i >= 72968 && i <= 72969) ||
      (i >= 72971 && i <= 73014) ||
      (i >= 73018 && i <= 73018) ||
      (i >= 73020 && i <= 73021) ||
      (i >= 73023 && i <= 73031) ||
      (i >= 73040 && i <= 73049) ||
      (i >= 73056 && i <= 73061) ||
      (i >= 73063 && i <= 73064) ||
      (i >= 73066 && i <= 73102) ||
      (i >= 73104 && i <= 73105) ||
      (i >= 73107 && i <= 73112) ||
      (i >= 73120 && i <= 73129) ||
      (i >= 73136 && i <= 73179) ||
      (i >= 73184 && i <= 73193) ||
      (i >= 73440 && i <= 73464) ||
      (i >= 73472 && i <= 73488) ||
      (i >= 73490 && i <= 73530) ||
      (i >= 73534 && i <= 73562) ||
      (i >= 73648 && i <= 73648) ||
      (i >= 73664 && i <= 73713) ||
      (i >= 73727 && i <= 74649) ||
      (i >= 74752 && i <= 74862) ||
      (i >= 74864 && i <= 74868) ||
      (i >= 74880 && i <= 75075) ||
      (i >= 77712 && i <= 77810) ||
      (i >= 77824 && i <= 78895) ||
      (i >= 78912 && i <= 78933) ||
      (i >= 78944 && i <= 82938) ||
      (i >= 82944 && i <= 83526) ||
      (i >= 90368 && i <= 90425) ||
      (i >= 92160 && i <= 92728) ||
      (i >= 92736 && i <= 92766) ||
      (i >= 92768 && i <= 92777) ||
      (i >= 92782 && i <= 92862) ||
      (i >= 92864 && i <= 92873) ||
      (i >= 92880 && i <= 92909) ||
      (i >= 92912 && i <= 92917) ||
      (i >= 92928 && i <= 92997) ||
      (i >= 93008 && i <= 93017) ||
      (i >= 93019 && i <= 93025) ||
      (i >= 93027 && i <= 93047) ||
      (i >= 93053 && i <= 93071) ||
      (i >= 93504 && i <= 93561) ||
      (i >= 93760 && i <= 93850) ||
      (i >= 93856 && i <= 93880) ||
      (i >= 93883 && i <= 93907) ||
      (i >= 93952 && i <= 94026) ||
      (i >= 94031 && i <= 94087) ||
      (i >= 94095 && i <= 94111) ||
      (i >= 94176 && i <= 94180) ||
      (i >= 94192 && i <= 94198) ||
      (i >= 94208 && i <= 101589) ||
      (i >= 101631 && i <= 101662) ||
      (i >= 101760 && i <= 101874) ||
      (i >= 110576 && i <= 110579) ||
      (i >= 110581 && i <= 110587) ||
      (i >= 110589 && i <= 110590) ||
      (i >= 110592 && i <= 110882) ||
      (i >= 110898 && i <= 110898) ||
      (i >= 110928 && i <= 110930) ||
      (i >= 110933 && i <= 110933) ||
      (i >= 110948 && i <= 110951) ||
      (i >= 110960 && i <= 111355) ||
      (i >= 113664 && i <= 113770) ||
      (i >= 113776 && i <= 113788) ||
      (i >= 113792 && i <= 113800) ||
      (i >= 113808 && i <= 113817) ||
      (i >= 113820 && i <= 113823) ||
      (i >= 117760 && i <= 118012) ||
      (i >= 118016 && i <= 118451) ||
      (i >= 118458 && i <= 118480) ||
      (i >= 118496 && i <= 118512) ||
      (i >= 118528 && i <= 118573) ||
      (i >= 118576 && i <= 118598) ||
      (i >= 118608 && i <= 118723) ||
      (i >= 118784 && i <= 119029) ||
      (i >= 119040 && i <= 119078) ||
      (i >= 119081 && i <= 119154) ||
      (i >= 119163 && i <= 119274) ||
      (i >= 119296 && i <= 119365) ||
      (i >= 119488 && i <= 119507) ||
      (i >= 119520 && i <= 119539) ||
      (i >= 119552 && i <= 119638) ||
      (i >= 119648 && i <= 119672) ||
      (i >= 119808 && i <= 119892) ||
      (i >= 119894 && i <= 119964) ||
      (i >= 119966 && i <= 119967) ||
      (i >= 119970 && i <= 119970) ||
      (i >= 119973 && i <= 119974) ||
      (i >= 119977 && i <= 119980) ||
      (i >= 119982 && i <= 119993) ||
      (i >= 119995 && i <= 119995) ||
      (i >= 119997 && i <= 120003) ||
      (i >= 120005 && i <= 120069) ||
      (i >= 120071 && i <= 120074) ||
      (i >= 120077 && i <= 120084) ||
      (i >= 120086 && i <= 120092) ||
      (i >= 120094 && i <= 120121) ||
      (i >= 120123 && i <= 120126) ||
      (i >= 120128 && i <= 120132) ||
      (i >= 120134 && i <= 120134) ||
      (i >= 120138 && i <= 120144) ||
      (i >= 120146 && i <= 120485) ||
      (i >= 120488 && i <= 120779) ||
      (i >= 120782 && i <= 121483) ||
      (i >= 121499 && i <= 121503) ||
      (i >= 121505 && i <= 121519) ||
      (i >= 122624 && i <= 122654) ||
      (i >= 122661 && i <= 122666) ||
      (i >= 122880 && i <= 122886) ||
      (i >= 122888 && i <= 122904) ||
      (i >= 122907 && i <= 122913) ||
      (i >= 122915 && i <= 122916) ||
      (i >= 122918 && i <= 122922) ||
      (i >= 122928 && i <= 122989) ||
      (i >= 123023 && i <= 123023) ||
      (i >= 123136 && i <= 123180) ||
      (i >= 123184 && i <= 123197) ||
      (i >= 123200 && i <= 123209) ||
      (i >= 123214 && i <= 123215) ||
      (i >= 123536 && i <= 123566) ||
      (i >= 123584 && i <= 123641) ||
      (i >= 123647 && i <= 123647) ||
      (i >= 124112 && i <= 124153) ||
      (i >= 124368 && i <= 124410) ||
      (i >= 124415 && i <= 124415) ||
      (i >= 124608 && i <= 124638) ||
      (i >= 124640 && i <= 124661) ||
      (i >= 124670 && i <= 124671) ||
      (i >= 124896 && i <= 124902) ||
      (i >= 124904 && i <= 124907) ||
      (i >= 124909 && i <= 124910) ||
      (i >= 124912 && i <= 124926) ||
      (i >= 124928 && i <= 125124) ||
      (i >= 125127 && i <= 125142) ||
      (i >= 125184 && i <= 125259) ||
      (i >= 125264 && i <= 125273) ||
      (i >= 125278 && i <= 125279) ||
      (i >= 126065 && i <= 126132) ||
      (i >= 126209 && i <= 126269) ||
      (i >= 126464 && i <= 126467) ||
      (i >= 126469 && i <= 126495) ||
      (i >= 126497 && i <= 126498) ||
      (i >= 126500 && i <= 126500) ||
      (i >= 126503 && i <= 126503) ||
      (i >= 126505 && i <= 126514) ||
      (i >= 126516 && i <= 126519) ||
      (i >= 126521 && i <= 126521) ||
      (i >= 126523 && i <= 126523) ||
      (i >= 126530 && i <= 126530) ||
      (i >= 126535 && i <= 126535) ||
      (i >= 126537 && i <= 126537) ||
      (i >= 126539 && i <= 126539) ||
      (i >= 126541 && i <= 126543) ||
      (i >= 126545 && i <= 126546) ||
      (i >= 126548 && i <= 126548) ||
      (i >= 126551 && i <= 126551) ||
      (i >= 126553 && i <= 126553) ||
      (i >= 126555 && i <= 126555) ||
      (i >= 126557 && i <= 126557) ||
      (i >= 126559 && i <= 126559) ||
      (i >= 126561 && i <= 126562) ||
      (i >= 126564 && i <= 126564) ||
      (i >= 126567 && i <= 126570) ||
      (i >= 126572 && i <= 126578) ||
      (i >= 126580 && i <= 126583) ||
      (i >= 126585 && i <= 126588) ||
      (i >= 126590 && i <= 126590) ||
      (i >= 126592 && i <= 126601) ||
      (i >= 126603 && i <= 126619) ||
      (i >= 126625 && i <= 126627) ||
      (i >= 126629 && i <= 126633) ||
      (i >= 126635 && i <= 126651) ||
      (i >= 126704 && i <= 126705) ||
      (i >= 126976 && i <= 127019) ||
      (i >= 127024 && i <= 127123) ||
      (i >= 127136 && i <= 127150) ||
      (i >= 127153 && i <= 127167) ||
      (i >= 127169 && i <= 127183) ||
      (i >= 127185 && i <= 127221) ||
      (i >= 127232 && i <= 127405) ||
      (i >= 127462 && i <= 127490) ||
      (i >= 127504 && i <= 127547) ||
      (i >= 127552 && i <= 127560) ||
      (i >= 127568 && i <= 127569) ||
      (i >= 127584 && i <= 127589) ||
      (i >= 127744 && i <= 128728) ||
      (i >= 128732 && i <= 128748) ||
      (i >= 128752 && i <= 128764) ||
      (i >= 128768 && i <= 128985) ||
      (i >= 128992 && i <= 129003) ||
      (i >= 129008 && i <= 129008) ||
      (i >= 129024 && i <= 129035) ||
      (i >= 129040 && i <= 129095) ||
      (i >= 129104 && i <= 129113) ||
      (i >= 129120 && i <= 129159) ||
      (i >= 129168 && i <= 129197) ||
      (i >= 129200 && i <= 129211) ||
      (i >= 129216 && i <= 129217) ||
      (i >= 129232 && i <= 129240) ||
      (i >= 129280 && i <= 129623) ||
      (i >= 129632 && i <= 129645) ||
      (i >= 129648 && i <= 129660) ||
      (i >= 129664 && i <= 129674) ||
      (i >= 129678 && i <= 129734) ||
      (i >= 129736 && i <= 129736) ||
      (i >= 129741 && i <= 129756) ||
      (i >= 129759 && i <= 129770) ||
      (i >= 129775 && i <= 129784) ||
      (i >= 129792 && i <= 129938) ||
      (i >= 129940 && i <= 130042) ||
      (i >= 131072 && i <= 173791) ||
      (i >= 173824 && i <= 178205) ||
      (i >= 178208 && i <= 183981) ||
      (i >= 183984 && i <= 191456) ||
      (i >= 191472 && i <= 192093) ||
      (i >= 194560 && i <= 195101) ||
      (i >= 196608 && i <= 201546) ||
      (i >= 201552 && i <= 210041) ||
      (i >= 917760 && i <= 917999) => {
      sb.write_char(i.unsafe_to_char())
      continue (n - 1, state.next_positive_int() % 91799)
    }
    (n, _) => continue (n, state.next_positive_int() % 91799)
  }
  Name(sb.to_string().to_string_view())
}

///|
pub struct CustomSec(Name, Bytes) derive(Eq)

///|
pub struct TypeSec(Array[RecType]) derive(Eq, Arbitrary)

///|
pub struct ImportSec(Array[Import]) derive(Eq, Arbitrary)

///|
pub struct FuncSec(Array[TypeIdx]) derive(Eq, Arbitrary)

///|
pub struct TableSec(Array[Table]) derive(Eq, Arbitrary)

///|
pub struct MemSec(Array[MemType]) derive(Eq, Arbitrary)

///|
pub struct GlobalSec(Array[Global]) derive(Eq, Arbitrary)

///|
pub struct ExportSec(Array[Export]) derive(Eq, Arbitrary)

///|
pub struct StartSec(FuncIdx) derive(Eq, Arbitrary)

///|
pub struct ElemSec(Array[Elem]) derive(Eq)

///|
pub struct DataCntSec(U32) derive(Eq, Arbitrary)

///|
pub struct TagSec(Array[TagType]) derive(Eq, Arbitrary)

///|
pub struct MemArg(U32, MemIdx?, U64)

///|
pub enum BlockType {
  EmptyBlockType
  ValTypeBlockType(ValType)
  TypeIdxBlockType(TypeIdx)
} derive(Eq, Arbitrary)

///|
pub enum Catch {
  Catch(TagIdx, LabelIdx)
  CatchRef(TagIdx, LabelIdx)
  CatchAll(LabelIdx)
  CatchAllRef(LabelIdx)
} derive(Eq, Arbitrary)

///|
pub struct CodeSec(Array[Func]) derive(Eq)

///|
pub struct DataSec(Array[Data]) derive(Eq)

///|
pub struct CastOp(Bool, Bool) derive(Eq, Arbitrary)

///|
pub enum Instruction {
  Unreachable
  Nop
  Block(BlockType, Expr)
  Loop(BlockType, Expr)
  If(BlockType, Array[Instruction], Array[Instruction]?)
  Throw(TagIdx)
  ThrowRef
  Br(LabelIdx)
  BrIf(LabelIdx)
  BrTable(Array[LabelIdx], LabelIdx)
  Return
  Call(FuncIdx)
  CallIndirect(TypeIdx, TableIdx)
  ReturnCall(FuncIdx)
  ReturnCallIndirect(TypeIdx, TableIdx)
  CallRef(TypeIdx)
  ReturnCallRef(TypeIdx)
  Drop
  Select(Array[ValType]?)
  TryTable(BlockType, Array[Catch], Expr)
  LocalGet(LocalIdx)
  LocalSet(LocalIdx)
  LocalTee(LocalIdx)
  GlobalGet(GlobalIdx)
  GlobalSet(GlobalIdx)
  TableGet(TableIdx)
  TableSet(TableIdx)
  I32Load(MemArg)
  I64Load(MemArg)
  F32Load(MemArg)
  F64Load(MemArg)
  I32Load8S(MemArg)
  I32Load8U(MemArg)
  I32Load16S(MemArg)
  I32Load16U(MemArg)
  I64Load8S(MemArg)
  I64Load8U(MemArg)
  I64Load16S(MemArg)
  I64Load16U(MemArg)
  I64Load32S(MemArg)
  I64Load32U(MemArg)
  I32Store(MemArg)
  I64Store(MemArg)
  F32Store(MemArg)
  F64Store(MemArg)
  I32Store8(MemArg)
  I32Store16(MemArg)
  I64Store8(MemArg)
  I64Store16(MemArg)
  I64Store32(MemArg)
  MemorySize(MemIdx)
  MemoryGrow(MemIdx)
  I32Const(I32)
  I64Const(I64)
  F32Const(F32)
  F64Const(F64)
  I32Eqz
  I32Eq
  I32Ne
  I32LtS
  I32LtU
  I32GtS
  I32GtU
  I32LeS
  I32LeU
  I32GeS
  I32GeU
  I64Eqz
  I64Eq
  I64Ne
  I64LtS
  I64LtU
  I64GtS
  I64GtU
  I64LeS
  I64LeU
  I64GeS
  I64GeU
  F32Eq
  F32Ne
  F32Lt
  F32Gt
  F32Le
  F32Ge
  F64Eq
  F64Ne
  F64Lt
  F64Gt
  F64Le
  F64Ge
  I32Clz
  I32Ctz
  I32Popcnt
  I32Add
  I32Sub
  I32Mul
  I32DivS
  I32DivU
  I32RemS
  I32RemU
  I32And
  I32Or
  I32Xor
  I32Shl
  I32ShrS
  I32ShrU
  I32Rotl
  I32Rotr
  I64Clz
  I64Ctz
  I64Popcnt
  I64Add
  I64Sub
  I64Mul
  I64DivS
  I64DivU
  I64RemS
  I64RemU
  I64And
  I64Or
  I64Xor
  I64Shl
  I64ShrS
  I64ShrU
  I64Rotl
  I64Rotr
  F32Abs
  F32Neg
  F32Ceil
  F32Floor
  F32Trunc
  F32Nearest
  F32Sqrt
  F32Add
  F32Sub
  F32Mul
  F32Div
  F32Min
  F32Max
  F32Copysign
  F64Abs
  F64Neg
  F64Ceil
  F64Floor
  F64Trunc
  F64Nearest
  F64Sqrt
  F64Add
  F64Sub
  F64Mul
  F64Div
  F64Min
  F64Max
  F64Copysign
  I32WrapI64
  I32TruncF32S
  I32TruncF32U
  I32TruncF64S
  I32TruncF64U
  I64ExtendI32S
  I64ExtendI32U
  I64TruncF32S
  I64TruncF32U
  I64TruncF64S
  I64TruncF64U
  F32ConvertI32S
  F32ConvertI32U
  F32ConvertI64S
  F32ConvertI64U
  F32DemoteF64
  F64ConvertI32S
  F64ConvertI32U
  F64ConvertI64S
  F64ConvertI64U
  F64PromoteF32
  I32ReinterpretF32
  I64ReinterpretF64
  F32ReinterpretI32
  F64ReinterpretI64
  I32Extend8S
  I32Extend16S
  I64Extend8S
  I64Extend16S
  I64Extend32S
  RefNull(HeapType)
  RefIsNull
  RefFunc(FuncIdx)
  RefEq
  RefAsNonNull
  BrOnNull(LabelIdx)
  BrOnNonNull(LabelIdx)
  StructNew(TypeIdx)
  StructNewDefault(TypeIdx)
  StructGet(TypeIdx, U32)
  StructGetS(TypeIdx, U32)
  StructGetU(TypeIdx, U32)
  StructSet(TypeIdx, U32)
  ArrayNew(TypeIdx)
  ArrayNewDefault(TypeIdx)
  ArrayNewFixed(TypeIdx, U32)
  ArrayNewData(TypeIdx, DataIdx)
  ArrayNewElem(TypeIdx, ElemIdx)
  ArrayGet(TypeIdx)
  ArrayGetS(TypeIdx)
  ArrayGetU(TypeIdx)
  ArraySet(TypeIdx)
  ArrayLen
  ArrayFill(TypeIdx)
  ArrayCopy(TypeIdx, TypeIdx)
  ArrayInitData(TypeIdx, DataIdx)
  ArrayInitElem(TypeIdx, ElemIdx)
  RefTest(Bool, HeapType)
  RefCast(Bool, HeapType)
  BrOnCast(LabelIdx, CastOp, HeapType, HeapType)
  BrOnCastFail(LabelIdx, CastOp, HeapType, HeapType)
  AnyConvertExtern
  ExternConvertAny
  RefI31
  I31GetS
  I31GetU
  I32TruncSatF32S
  I32TruncSatF32U
  I32TruncSatF64S
  I32TruncSatF64U
  I64TruncSatF32S
  I64TruncSatF32U
  I64TruncSatF64S
  I64TruncSatF64U
  MemoryInit(DataIdx, MemIdx)
  DataDrop(DataIdx)
  MemoryCopy(MemIdx, MemIdx)
  MemoryFill(MemIdx)
  TableInit(ElemIdx, TableIdx)
  ElemDrop(ElemIdx)
  TableCopy(TableIdx, TableIdx)
  TableGrow(TableIdx)
  TableSize(TableIdx)
  TableFill(TableIdx)
  V128Load(MemArg)
  V128Load8x8S(MemArg)
  V128Load8x8U(MemArg)
  V128Load16x4S(MemArg)
  V128Load16x4U(MemArg)
  V128Load32x2S(MemArg)
  V128Load32x2U(MemArg)
  V128Load8Splat(MemArg)
  V128Load16Splat(MemArg)
  V128Load32Splat(MemArg)
  V128Load64Splat(MemArg)
  V128Store(MemArg)
  V128Const(
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte
  )
  I8x16Shuffle(
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx
  )
  I8x16Swizzle
  I8x16Splat
  I16x8Splat
  I32x4Splat
  I64x2Splat
  F32x4Splat
  F64x2Splat
  I8x16ExtractLaneS(LaneIdx)
  I8x16ExtractLaneU(LaneIdx)
  I8x16ReplaceLane(LaneIdx)
  I16x8ExtractLaneS(LaneIdx)
  I16x8ExtractLaneU(LaneIdx)
  I16x8ReplaceLane(LaneIdx)
  I32x4ExtractLane(LaneIdx)
  I32x4ReplaceLane(LaneIdx)
  I64x2ExtractLane(LaneIdx)
  I64x2ReplaceLane(LaneIdx)
  F32x4ExtractLane(LaneIdx)
  F32x4ReplaceLane(LaneIdx)
  F64x2ExtractLane(LaneIdx)
  F64x2ReplaceLane(LaneIdx)
  I8x16Eq
  I8x16Ne
  I8x16LtS
  I8x16LtU
  I8x16GtS
  I8x16GtU
  I8x16LeS
  I8x16LeU
  I8x16GeS
  I8x16GeU
  I16x8Eq
  I16x8Ne
  I16x8LtS
  I16x8LtU
  I16x8GtS
  I16x8GtU
  I16x8LeS
  I16x8LeU
  I16x8GeS
  I16x8GeU
  I32x4Eq
  I32x4Ne
  I32x4LtS
  I32x4LtU
  I32x4GtS
  I32x4GtU
  I32x4LeS
  I32x4LeU
  I32x4GeS
  I32x4GeU
  F32x4Eq
  F32x4Ne
  F32x4Lt
  F32x4Gt
  F32x4Le
  F32x4Ge
  F64x2Eq
  F64x2Ne
  F64x2Lt
  F64x2Gt
  F64x2Le
  F64x2Ge
  V128Not
  V128And
  V128Andnot
  V128Or
  V128Xor
  V128Bitselect
  V128AnyTrue
  V128Load8Lane(MemArg, LaneIdx)
  V128Load16Lane(MemArg, LaneIdx)
  V128Load32Lane(MemArg, LaneIdx)
  V128Load64Lane(MemArg, LaneIdx)
  V128Store8Lane(MemArg, LaneIdx)
  V128Store16Lane(MemArg, LaneIdx)
  V128Store32Lane(MemArg, LaneIdx)
  V128Store64Lane(MemArg, LaneIdx)
  V128Load32Zero(MemArg)
  V128Load64Zero(MemArg)
  F32x4DemoteF64x2Zero
  F64x2PromoteLowF32x4
  I8x16Abs
  I8x16Neg
  I8x16Popcnt
  I8x16AllTrue
  I8x16Bitmask
  I8x16NarrowI16x8S
  I8x16NarrowI16x8U
  F32x4Ceil
  F32x4Floor
  F32x4Trunc
  F32x4Nearest
  I8x16Shl
  I8x16ShrS
  I8x16ShrU
  I8x16Add
  I8x16AddSatS
  I8x16AddSatU
  I8x16Sub
  I8x16SubSatS
  I8x16SubSatU
  F64x2Ceil
  F64x2Floor
  I8x16MinS
  I8x16MinU
  I8x16MaxS
  I8x16MaxU
  F64x2Trunc
  I8x16AvgrU
  I16x8ExtaddPairwiseI8x16S
  I16x8ExtaddPairwiseI8x16U
  I32x4ExtaddPairwiseI16x8S
  I32x4ExtaddPairwiseI16x8U
  I16x8Abs
  I16x8Neg
  I16x8Q15mulrSatS
  I16x8AllTrue
  I16x8Bitmask
  I16x8NarrowI32x4S
  I16x8NarrowI32x4U
  I16x8ExtendLowI8x16S
  I16x8ExtendHighI8x16S
  I16x8ExtendLowI8x16U
  I16x8ExtendHighI8x16U
  I16x8Shl
  I16x8ShrS
  I16x8ShrU
  I16x8Add
  I16x8AddSatS
  I16x8AddSatU
  I16x8Sub
  I16x8SubSatS
  I16x8SubSatU
  F64x2Nearest
  I16x8Mul
  I16x8MinS
  I16x8MinU
  I16x8MaxS
  I16x8MaxU
  I16x8AvgrU
  I16x8ExtmulLowI8x16S
  I16x8ExtmulHighI8x16S
  I16x8ExtmulLowI8x16U
  I16x8ExtmulHighI8x16U
  I32x4Abs
  I32x4Neg
  I32x4AllTrue
  I32x4Bitmask
  I32x4ExtendLowI16x8S
  I32x4ExtendHighI16x8S
  I32x4ExtendLowI16x8U
  I32x4ExtendHighI16x8U
  I32x4Shl
  I32x4ShrS
  I32x4ShrU
  I32x4Add
  I32x4Sub
  I32x4Mul
  I32x4MinS
  I32x4MinU
  I32x4MaxS
  I32x4MaxU
  I32x4DotI16x8S
  I32x4ExtmulLowI16x8S
  I32x4ExtmulHighI16x8S
  I32x4ExtmulLowI16x8U
  I32x4ExtmulHighI16x8U
  I64x2Abs
  I64x2Neg
  I64x2AllTrue
  I64x2Bitmask
  I64x2ExtendLowI32x4S
  I64x2ExtendHighI32x4S
  I64x2ExtendLowI32x4U
  I64x2ExtendHighI32x4U
  I64x2Shl
  I64x2ShrS
  I64x2ShrU
  I64x2Add
  I64x2Sub
  I64x2Mul
  I64x2Eq
  I64x2Ne
  I64x2LtS
  I64x2GtS
  I64x2LeS
  I64x2GeS
  I64x2ExtmulLowI32x4S
  I64x2ExtmulHighI32x4S
  I64x2ExtmulLowI32x4U
  I64x2ExtmulHighI32x4U
  F32x4Abs
  F32x4Neg
  F32x4Sqrt
  F32x4Add
  F32x4Sub
  F32x4Mul
  F32x4Div
  F32x4Min
  F32x4Max
  F32x4Pmin
  F32x4Pmax
  F64x2Abs
  F64x2Neg
  F64x2Sqrt
  F64x2Add
  F64x2Sub
  F64x2Mul
  F64x2Div
  F64x2Min
  F64x2Max
  F64x2Pmin
  F64x2Pmax
  I32x4TruncSatF32x4S
  I32x4TruncSatF32x4U
  F32x4ConvertI32x4S
  F32x4ConvertI32x4U
  I32x4TruncSatF64x2SZero
  I32x4TruncSatF64x2UZero
  F64x2ConvertLowI32x4S
  F64x2ConvertLowI32x4U
  I8x16RelaxedSwizzle
  I32x4RelaxedTruncF32x4S
  I32x4RelaxedTruncF32x4U
  I32x4RelaxedTruncZeroF64x2S
  I32x4RelaxedTruncZeroF64x2U
  F32x4RelaxedMadd
  F32x4RelaxedNmadd
  F64x2RelaxedMadd
  F64x2RelaxedNmadd
  I8x16RelaxedLaneselect
  I16x8RelaxedLaneselect
  I32x4RelaxedLaneselect
  I64x2RelaxedLaneselect
  F32x4RelaxedMin
  F32x4RelaxedMax
  F64x2RelaxedMin
  F64x2RelaxedMax
  I16x8RelaxedQ15mulrS
  I16x8RelaxedDotI8x16I7x16S
  I32x4RelaxedDotI8x16I7x16AddS
} derive(Eq)

///|
pub impl @quickcheck.Arbitrary for MemArg with arbitrary(t, state) {
  MemArg(
    U32(state.next_uint() % 64),
    @quickcheck.Arbitrary::arbitrary(t, state),
    @quickcheck.Arbitrary::arbitrary(t, state),
  )
}

///|
pub impl @quickcheck.Arbitrary for Instruction with arbitrary(t, state) {
  match state.next_uint() % 494 {
    0 => Unreachable
    1 => Nop
    2 =>
      Block(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    3 =>
      Loop(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    4 =>
      If(
        @quickcheck.Arbitrary::arbitrary(t, state),
        array_of_arbitrary(5, t, state),
        if (state.next_uint() & 1) == 1 {
          Some(array_of_arbitrary(5, t, state))
        } else {
          None
        },
      )
    5 => Throw(@quickcheck.Arbitrary::arbitrary(t, state))
    6 => ThrowRef
    7 => Br(@quickcheck.Arbitrary::arbitrary(t, state))
    8 => BrIf(@quickcheck.Arbitrary::arbitrary(t, state))
    9 =>
      BrTable(
        array_of_arbitrary(3, t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    10 => Return
    11 => Call(@quickcheck.Arbitrary::arbitrary(t, state))
    12 =>
      CallIndirect(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    13 => ReturnCall(@quickcheck.Arbitrary::arbitrary(t, state))
    14 =>
      ReturnCallIndirect(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    15 => CallRef(@quickcheck.Arbitrary::arbitrary(t, state))
    16 => ReturnCallRef(@quickcheck.Arbitrary::arbitrary(t, state))
    17 => Drop
    18 =>
      TryTable(
        @quickcheck.Arbitrary::arbitrary(t, state),
        array_of_arbitrary(4, t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    19 =>
      Select(
        if @quickcheck.Arbitrary::arbitrary(t, state) {
          Some(array_of_arbitrary(4, t, state))
        } else {
          None
        },
      )
    20 => LocalGet(@quickcheck.Arbitrary::arbitrary(t, state))
    21 => LocalSet(@quickcheck.Arbitrary::arbitrary(t, state))
    22 => LocalTee(@quickcheck.Arbitrary::arbitrary(t, state))
    23 => GlobalGet(@quickcheck.Arbitrary::arbitrary(t, state))
    24 => GlobalSet(@quickcheck.Arbitrary::arbitrary(t, state))
    25 => TableGet(@quickcheck.Arbitrary::arbitrary(t, state))
    26 => TableSet(@quickcheck.Arbitrary::arbitrary(t, state))
    27 => I32Load(@quickcheck.Arbitrary::arbitrary(t, state))
    28 => I64Load(@quickcheck.Arbitrary::arbitrary(t, state))
    29 => F32Load(@quickcheck.Arbitrary::arbitrary(t, state))
    30 => F64Load(@quickcheck.Arbitrary::arbitrary(t, state))
    31 => I32Load8S(@quickcheck.Arbitrary::arbitrary(t, state))
    32 => I32Load8U(@quickcheck.Arbitrary::arbitrary(t, state))
    33 => I32Load16S(@quickcheck.Arbitrary::arbitrary(t, state))
    34 => I32Load16U(@quickcheck.Arbitrary::arbitrary(t, state))
    35 => I64Load8S(@quickcheck.Arbitrary::arbitrary(t, state))
    36 => I64Load8U(@quickcheck.Arbitrary::arbitrary(t, state))
    37 => I64Load16S(@quickcheck.Arbitrary::arbitrary(t, state))
    38 => I64Load16U(@quickcheck.Arbitrary::arbitrary(t, state))
    39 => I64Load32S(@quickcheck.Arbitrary::arbitrary(t, state))
    40 => I64Load32U(@quickcheck.Arbitrary::arbitrary(t, state))
    41 => I32Store(@quickcheck.Arbitrary::arbitrary(t, state))
    42 => I64Store(@quickcheck.Arbitrary::arbitrary(t, state))
    43 => F32Store(@quickcheck.Arbitrary::arbitrary(t, state))
    44 => F64Store(@quickcheck.Arbitrary::arbitrary(t, state))
    45 => I32Store8(@quickcheck.Arbitrary::arbitrary(t, state))
    46 => I32Store16(@quickcheck.Arbitrary::arbitrary(t, state))
    47 => I64Store8(@quickcheck.Arbitrary::arbitrary(t, state))
    48 => I64Store16(@quickcheck.Arbitrary::arbitrary(t, state))
    49 => I64Store32(@quickcheck.Arbitrary::arbitrary(t, state))
    50 => MemorySize(@quickcheck.Arbitrary::arbitrary(t, state))
    51 => MemoryGrow(@quickcheck.Arbitrary::arbitrary(t, state))
    52 => I32Const(@quickcheck.Arbitrary::arbitrary(t, state))
    53 => I64Const(@quickcheck.Arbitrary::arbitrary(t, state))
    54 => F32Const(@quickcheck.Arbitrary::arbitrary(t, state))
    55 => F64Const(@quickcheck.Arbitrary::arbitrary(t, state))
    56 => I32Eqz
    57 => I32Eq
    58 => I32Ne
    59 => I32LtS
    60 => I32LtU
    61 => I32GtS
    62 => I32GtU
    63 => I32LeS
    64 => I32LeU
    65 => I32GeS
    66 => I32GeU
    67 => I64Eqz
    68 => I64Eq
    69 => I64Ne
    70 => I64LtS
    71 => I64LtU
    72 => I64GtS
    73 => I64GtU
    74 => I64LeS
    75 => I64LeU
    76 => I64GeS
    77 => I64GeU
    78 => F32Eq
    79 => F32Ne
    80 => F32Lt
    81 => F32Gt
    82 => F32Le
    83 => F32Ge
    84 => F64Eq
    85 => F64Ne
    86 => F64Lt
    87 => F64Gt
    88 => F64Le
    89 => F64Ge
    90 => I32Clz
    91 => I32Ctz
    92 => I32Popcnt
    93 => I32Add
    94 => I32Sub
    95 => I32Mul
    96 => I32DivS
    97 => I32DivU
    98 => I32RemS
    99 => I32RemU
    100 => I32And
    101 => I32Or
    102 => I32Xor
    103 => I32Shl
    104 => I32ShrS
    105 => I32ShrU
    106 => I32Rotl
    107 => I32Rotr
    108 => I64Clz
    109 => I64Ctz
    110 => I64Popcnt
    111 => I64Add
    112 => I64Sub
    113 => I64Mul
    114 => I64DivS
    115 => I64DivU
    116 => I64RemS
    117 => I64RemU
    118 => I64And
    119 => I64Or
    120 => I64Xor
    121 => I64Shl
    122 => I64ShrS
    123 => I64ShrU
    124 => I64Rotl
    125 => I64Rotr
    126 => F32Abs
    127 => F32Neg
    128 => F32Ceil
    129 => F32Floor
    130 => F32Trunc
    131 => F32Nearest
    132 => F32Sqrt
    133 => F32Add
    134 => F32Sub
    135 => F32Mul
    136 => F32Div
    137 => F32Min
    138 => F32Max
    139 => F32Copysign
    140 => F64Abs
    141 => F64Neg
    142 => F64Ceil
    143 => F64Floor
    144 => F64Trunc
    145 => F64Nearest
    146 => F64Sqrt
    147 => F64Add
    148 => F64Sub
    149 => F64Mul
    150 => F64Div
    151 => F64Min
    152 => F64Max
    153 => F64Copysign
    154 => I32WrapI64
    155 => I32TruncF32S
    156 => I32TruncF32U
    157 => I32TruncF64S
    158 => I32TruncF64U
    159 => I64ExtendI32S
    160 => I64ExtendI32U
    161 => I64TruncF32S
    162 => I64TruncF32U
    163 => I64TruncF64S
    164 => I64TruncF64U
    165 => F32ConvertI32S
    166 => F32ConvertI32U
    167 => F32ConvertI64S
    168 => F32ConvertI64U
    169 => F32DemoteF64
    170 => F64ConvertI32S
    171 => F64ConvertI32U
    172 => F64ConvertI64S
    173 => F64ConvertI64U
    174 => F64PromoteF32
    175 => I32ReinterpretF32
    176 => I64ReinterpretF64
    177 => F32ReinterpretI32
    178 => F64ReinterpretI64
    179 => I32Extend8S
    180 => I32Extend16S
    181 => I64Extend8S
    182 => I64Extend16S
    183 => I64Extend32S
    184 => RefNull(@quickcheck.Arbitrary::arbitrary(t, state))
    185 => RefIsNull
    186 => RefFunc(@quickcheck.Arbitrary::arbitrary(t, state))
    187 => RefEq
    188 => RefAsNonNull
    189 => BrOnNull(@quickcheck.Arbitrary::arbitrary(t, state))
    190 => BrOnNonNull(@quickcheck.Arbitrary::arbitrary(t, state))
    191 => StructNew(@quickcheck.Arbitrary::arbitrary(t, state))
    192 => StructNewDefault(@quickcheck.Arbitrary::arbitrary(t, state))
    193 =>
      StructGet(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    194 =>
      StructGetS(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    195 =>
      StructGetU(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    196 =>
      StructSet(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    197 => ArrayNew(@quickcheck.Arbitrary::arbitrary(t, state))
    198 => ArrayNewDefault(@quickcheck.Arbitrary::arbitrary(t, state))
    199 =>
      ArrayNewFixed(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    200 =>
      ArrayNewData(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    201 =>
      ArrayNewElem(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    202 => ArrayGet(@quickcheck.Arbitrary::arbitrary(t, state))
    203 => ArrayGetS(@quickcheck.Arbitrary::arbitrary(t, state))
    204 => ArrayGetU(@quickcheck.Arbitrary::arbitrary(t, state))
    205 => ArraySet(@quickcheck.Arbitrary::arbitrary(t, state))
    206 => ArrayLen
    207 => ArrayFill(@quickcheck.Arbitrary::arbitrary(t, state))
    208 =>
      ArrayCopy(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    209 =>
      ArrayInitData(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    210 =>
      ArrayInitElem(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    211 =>
      RefTest(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    212 =>
      RefCast(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    213 =>
      BrOnCast(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    214 =>
      BrOnCastFail(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    215 => AnyConvertExtern
    216 => ExternConvertAny
    217 => RefI31
    218 => I31GetS
    219 => I31GetU
    220 => I32TruncSatF32S
    221 => I32TruncSatF32U
    222 => I32TruncSatF64S
    223 => I32TruncSatF64U
    224 => I64TruncSatF32S
    225 => I64TruncSatF32U
    226 => I64TruncSatF64S
    227 => I64TruncSatF64U
    228 =>
      MemoryInit(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    229 => DataDrop(@quickcheck.Arbitrary::arbitrary(t, state))
    230 =>
      MemoryCopy(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    231 => MemoryFill(@quickcheck.Arbitrary::arbitrary(t, state))
    232 =>
      TableInit(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    233 => ElemDrop(@quickcheck.Arbitrary::arbitrary(t, state))
    234 =>
      TableCopy(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    235 => TableGrow(@quickcheck.Arbitrary::arbitrary(t, state))
    236 => TableSize(@quickcheck.Arbitrary::arbitrary(t, state))
    237 => TableFill(@quickcheck.Arbitrary::arbitrary(t, state))
    238 => V128Load(@quickcheck.Arbitrary::arbitrary(t, state))
    239 => V128Load8x8S(@quickcheck.Arbitrary::arbitrary(t, state))
    240 => V128Load8x8U(@quickcheck.Arbitrary::arbitrary(t, state))
    241 => V128Load16x4S(@quickcheck.Arbitrary::arbitrary(t, state))
    242 => V128Load16x4U(@quickcheck.Arbitrary::arbitrary(t, state))
    243 => V128Load32x2S(@quickcheck.Arbitrary::arbitrary(t, state))
    244 => V128Load32x2U(@quickcheck.Arbitrary::arbitrary(t, state))
    245 => V128Load8Splat(@quickcheck.Arbitrary::arbitrary(t, state))
    246 => V128Load16Splat(@quickcheck.Arbitrary::arbitrary(t, state))
    247 => V128Load32Splat(@quickcheck.Arbitrary::arbitrary(t, state))
    248 => V128Load64Splat(@quickcheck.Arbitrary::arbitrary(t, state))
    249 => V128Store(@quickcheck.Arbitrary::arbitrary(t, state))
    250 =>
      V128Const(
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
        (state.next_uint() % 256).to_byte(),
      )
    251 =>
      I8x16Shuffle(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    252 => I8x16Swizzle
    253 => I8x16Splat
    254 => I16x8Splat
    255 => I32x4Splat
    256 => I64x2Splat
    257 => F32x4Splat
    258 => F64x2Splat
    259 => I8x16ExtractLaneS(@quickcheck.Arbitrary::arbitrary(t, state))
    260 => I8x16ExtractLaneU(@quickcheck.Arbitrary::arbitrary(t, state))
    261 => I8x16ReplaceLane(@quickcheck.Arbitrary::arbitrary(t, state))
    262 => I16x8ExtractLaneS(@quickcheck.Arbitrary::arbitrary(t, state))
    263 => I16x8ExtractLaneU(@quickcheck.Arbitrary::arbitrary(t, state))
    264 => I16x8ReplaceLane(@quickcheck.Arbitrary::arbitrary(t, state))
    265 => I32x4ExtractLane(@quickcheck.Arbitrary::arbitrary(t, state))
    266 => I32x4ReplaceLane(@quickcheck.Arbitrary::arbitrary(t, state))
    267 => I64x2ExtractLane(@quickcheck.Arbitrary::arbitrary(t, state))
    268 => I64x2ReplaceLane(@quickcheck.Arbitrary::arbitrary(t, state))
    269 => F32x4ExtractLane(@quickcheck.Arbitrary::arbitrary(t, state))
    270 => F32x4ReplaceLane(@quickcheck.Arbitrary::arbitrary(t, state))
    271 => F64x2ExtractLane(@quickcheck.Arbitrary::arbitrary(t, state))
    272 => F64x2ReplaceLane(@quickcheck.Arbitrary::arbitrary(t, state))
    273 => I8x16Eq
    274 => I8x16Ne
    275 => I8x16LtS
    276 => I8x16LtU
    277 => I8x16GtS
    278 => I8x16GtU
    279 => I8x16LeS
    280 => I8x16LeU
    281 => I8x16GeS
    282 => I8x16GeU
    283 => I16x8Eq
    284 => I16x8Ne
    285 => I16x8LtS
    286 => I16x8LtU
    287 => I16x8GtS
    288 => I16x8GtU
    289 => I16x8LeS
    290 => I16x8LeU
    291 => I16x8GeS
    292 => I16x8GeU
    293 => I32x4Eq
    294 => I32x4Ne
    295 => I32x4LtS
    296 => I32x4LtU
    297 => I32x4GtS
    298 => I32x4GtU
    299 => I32x4LeS
    300 => I32x4LeU
    301 => I32x4GeS
    302 => I32x4GeU
    303 => F32x4Eq
    304 => F32x4Ne
    305 => F32x4Lt
    306 => F32x4Gt
    307 => F32x4Le
    308 => F32x4Ge
    309 => F64x2Eq
    310 => F64x2Ne
    311 => F64x2Lt
    312 => F64x2Gt
    313 => F64x2Le
    314 => F64x2Ge
    315 => V128Not
    316 => V128And
    317 => V128Andnot
    318 => V128Or
    319 => V128Xor
    320 => V128Bitselect
    321 => V128AnyTrue
    322 =>
      V128Load8Lane(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    323 =>
      V128Load16Lane(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    324 =>
      V128Load32Lane(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    325 =>
      V128Load64Lane(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    326 =>
      V128Store8Lane(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    327 =>
      V128Store16Lane(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    328 =>
      V128Store32Lane(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    329 =>
      V128Store64Lane(
        @quickcheck.Arbitrary::arbitrary(t, state),
        @quickcheck.Arbitrary::arbitrary(t, state),
      )
    330 => V128Load32Zero(@quickcheck.Arbitrary::arbitrary(t, state))
    331 => V128Load64Zero(@quickcheck.Arbitrary::arbitrary(t, state))
    332 => F32x4DemoteF64x2Zero
    333 => F64x2PromoteLowF32x4
    334 => I8x16Abs
    335 => I8x16Neg
    336 => I8x16Popcnt
    337 => I8x16AllTrue
    338 => I8x16Bitmask
    339 => I8x16NarrowI16x8S
    340 => I8x16NarrowI16x8U
    341 => F32x4Ceil
    342 => F32x4Floor
    343 => F32x4Trunc
    344 => F32x4Nearest
    345 => I8x16Shl
    346 => I8x16ShrS
    347 => I8x16ShrU
    348 => I8x16Add
    349 => I8x16AddSatS
    350 => I8x16AddSatU
    351 => I8x16Sub
    352 => I8x16SubSatS
    353 => I8x16SubSatU
    354 => F64x2Ceil
    355 => F64x2Floor
    356 => I8x16MinS
    357 => I8x16MinU
    358 => I8x16MaxS
    359 => I8x16MaxU
    360 => F64x2Trunc
    361 => I8x16AvgrU
    362 => I16x8ExtaddPairwiseI8x16S
    363 => I16x8ExtaddPairwiseI8x16U
    364 => I32x4ExtaddPairwiseI16x8S
    365 => I32x4ExtaddPairwiseI16x8U
    366 => I16x8Abs
    367 => I16x8Neg
    368 => I16x8Q15mulrSatS
    369 => I16x8AllTrue
    370 => I16x8Bitmask
    371 => I16x8NarrowI32x4S
    372 => I16x8NarrowI32x4U
    373 => I16x8ExtendLowI8x16S
    374 => I16x8ExtendHighI8x16S
    375 => I16x8ExtendLowI8x16U
    376 => I16x8ExtendHighI8x16U
    377 => I16x8Shl
    378 => I16x8ShrS
    379 => I16x8ShrU
    380 => I16x8Add
    381 => I16x8AddSatS
    382 => I16x8AddSatU
    383 => I16x8Sub
    384 => I16x8SubSatS
    385 => I16x8SubSatU
    386 => F64x2Nearest
    387 => I16x8Mul
    388 => I16x8MinS
    389 => I16x8MinU
    390 => I16x8MaxS
    391 => I16x8MaxU
    392 => I16x8AvgrU
    393 => I16x8ExtmulLowI8x16S
    394 => I16x8ExtmulHighI8x16S
    395 => I16x8ExtmulLowI8x16U
    396 => I16x8ExtmulHighI8x16U
    397 => I32x4Abs
    398 => I32x4Neg
    399 => I32x4AllTrue
    400 => I32x4Bitmask
    401 => I32x4ExtendLowI16x8S
    402 => I32x4ExtendHighI16x8S
    403 => I32x4ExtendLowI16x8U
    404 => I32x4ExtendHighI16x8U
    405 => I32x4Shl
    406 => I32x4ShrS
    407 => I32x4ShrU
    408 => I32x4Add
    409 => I32x4Sub
    410 => I32x4Mul
    411 => I32x4MinS
    412 => I32x4MinU
    413 => I32x4MaxS
    414 => I32x4MaxU
    415 => I32x4DotI16x8S
    416 => I32x4ExtmulLowI16x8S
    417 => I32x4ExtmulHighI16x8S
    418 => I32x4ExtmulLowI16x8U
    419 => I32x4ExtmulHighI16x8U
    420 => I64x2Abs
    421 => I64x2Neg
    422 => I64x2AllTrue
    423 => I64x2Bitmask
    424 => I64x2ExtendLowI32x4S
    425 => I64x2ExtendHighI32x4S
    426 => I64x2ExtendLowI32x4U
    427 => I64x2ExtendHighI32x4U
    428 => I64x2Shl
    429 => I64x2ShrS
    430 => I64x2ShrU
    431 => I64x2Add
    432 => I64x2Sub
    433 => I64x2Mul
    434 => I64x2Eq
    435 => I64x2Ne
    436 => I64x2LtS
    437 => I64x2GtS
    438 => I64x2LeS
    439 => I64x2GeS
    440 => I64x2ExtmulLowI32x4S
    441 => I64x2ExtmulHighI32x4S
    442 => I64x2ExtmulLowI32x4U
    443 => I64x2ExtmulHighI32x4U
    444 => F32x4Abs
    445 => F32x4Neg
    446 => F32x4Sqrt
    447 => F32x4Add
    448 => F32x4Sub
    449 => F32x4Mul
    450 => F32x4Div
    451 => F32x4Min
    452 => F32x4Max
    453 => F32x4Pmin
    454 => F32x4Pmax
    455 => F64x2Abs
    456 => F64x2Neg
    457 => F64x2Sqrt
    458 => F64x2Add
    459 => F64x2Sub
    460 => F64x2Mul
    461 => F64x2Div
    462 => F64x2Min
    463 => F64x2Max
    464 => F64x2Pmin
    465 => F64x2Pmax
    466 => I32x4TruncSatF32x4S
    467 => I32x4TruncSatF32x4U
    468 => F32x4ConvertI32x4S
    469 => F32x4ConvertI32x4U
    470 => I32x4TruncSatF64x2SZero
    471 => I32x4TruncSatF64x2UZero
    472 => F64x2ConvertLowI32x4S
    473 => F64x2ConvertLowI32x4U
    474 => I8x16RelaxedSwizzle
    475 => I32x4RelaxedTruncF32x4S
    476 => I32x4RelaxedTruncF32x4U
    477 => I32x4RelaxedTruncZeroF64x2S
    478 => I32x4RelaxedTruncZeroF64x2U
    479 => F32x4RelaxedMadd
    480 => F32x4RelaxedNmadd
    481 => F64x2RelaxedMadd
    482 => F64x2RelaxedNmadd
    483 => I8x16RelaxedLaneselect
    484 => I16x8RelaxedLaneselect
    485 => I32x4RelaxedLaneselect
    486 => I64x2RelaxedLaneselect
    487 => F32x4RelaxedMin
    488 => F32x4RelaxedMax
    489 => F64x2RelaxedMin
    490 => F64x2RelaxedMax
    491 => I16x8RelaxedQ15mulrS
    492 => I16x8RelaxedDotI8x16I7x16S
    493 => I32x4RelaxedDotI8x16I7x16AddS
    _ => Nop
  }
}

///|
pub impl @quickcheck.Arbitrary for ElemSec with arbitrary(t, state) {
  let elems = []
  let count = state.next_positive_int() % 4 + 1
  loop count {
    0 => break ()
    n => {
      elems.push(@quickcheck.Arbitrary::arbitrary(t, state))
      continue n - 1
    }
  }
  ElemSec(elems)
}

///|
pub impl @quickcheck.Arbitrary for CodeSec with arbitrary(t, state) {
  let elems = []
  let count = state.next_positive_int() % 4 + 1
  loop count {
    0 => break ()
    n => {
      elems.push(@quickcheck.Arbitrary::arbitrary(t, state))
      continue n - 1
    }
  }
  CodeSec(elems)
}

///|
pub impl @quickcheck.Arbitrary for DataSec with arbitrary(t, state) {
  let elems = []
  let count = state.next_positive_int() % 4 + 1
  loop count {
    0 => break ()
    n => {
      elems.push(@quickcheck.Arbitrary::arbitrary(t, state))
      continue n - 1
    }
  }
  DataSec(elems)
}

///|
pub impl @quickcheck.Arbitrary for CustomSec with arbitrary(size, st) {
  let name = @quickcheck.Arbitrary::arbitrary(size, st)
  let length = st.next_positive_int() % 19 + 1
  let buf = @buffer.new()
  let bytes = loop length {
    0 => buf.to_bytes()
    n => {
      buf.write_byte((st.next_positive_int() % 256).to_byte())
      continue n - 1
    }
  }
  CustomSec(name, bytes)
}

///|
pub impl @quickcheck.Arbitrary for Module with arbitrary(t, state) {
  Module(
    array_of_arbitrary(5, t, state),
    if state.next_positive_int() % 2 == 0 {
      Some(@quickcheck.Arbitrary::arbitrary(t, state))
    } else {
      None
    },
    if state.next_positive_int() % 2 == 0 {
      Some(@quickcheck.Arbitrary::arbitrary(t, state))
    } else {
      None
    },
    if state.next_positive_int() % 2 == 0 {
      Some(@quickcheck.Arbitrary::arbitrary(t, state))
    } else {
      None
    },
    if state.next_positive_int() % 2 == 0 {
      Some(@quickcheck.Arbitrary::arbitrary(t, state))
    } else {
      None
    },
    if state.next_positive_int() % 2 == 0 {
      Some(@quickcheck.Arbitrary::arbitrary(t, state))
    } else {
      None
    },
    if state.next_positive_int() % 2 == 0 {
      Some(@quickcheck.Arbitrary::arbitrary(t, state))
    } else {
      None
    },
    if state.next_positive_int() % 2 == 0 {
      Some(@quickcheck.Arbitrary::arbitrary(t, state))
    } else {
      None
    },
    if state.next_positive_int() % 2 == 0 {
      Some(@quickcheck.Arbitrary::arbitrary(t, state))
    } else {
      None
    },
    if state.next_positive_int() % 2 == 0 {
      Some(@quickcheck.Arbitrary::arbitrary(t, state))
    } else {
      None
    },
    if state.next_positive_int() % 2 == 0 {
      Some(@quickcheck.Arbitrary::arbitrary(t, state))
    } else {
      None
    },
    if state.next_positive_int() % 2 == 0 {
      Some(@quickcheck.Arbitrary::arbitrary(t, state))
    } else {
      None
    },
    if state.next_positive_int() % 2 == 0 {
      Some(@quickcheck.Arbitrary::arbitrary(t, state))
    } else {
      None
    },
    if state.next_positive_int() % 2 == 0 {
      Some(@quickcheck.Arbitrary::arbitrary(t, state))
    } else {
      None
    },
  )
}

///|
pub impl Eq for Module with equal(l, r) {
  let l_custom = l.0
  let r_custom = r.0
  if l_custom.length() != r_custom.length() {
    return false
  }
  for lc in l_custom {
    if !r_custom.contains(lc) {
      return false
    }
  }
  for rc in r_custom {
    if !l_custom.contains(rc) {
      return false
    }
  }
  l.1 == r.1 &&
  l.2 == r.2 &&
  l.3 == r.3 &&
  l.4 == r.4 &&
  l.5 == r.5 &&
  l.6 == r.6 &&
  l.7 == r.7 &&
  l.8 == r.8 &&
  l.9 == r.9 &&
  l.10 == r.10 &&
  l.11 == r.11 &&
  l.12 == r.12 &&
  l.13 == r.13
}

///|
pub impl Eq for RecType with equal(l, r) {
  match (l, r) {
    (SingleRecType(stl), GroupRecType([str])) => stl == str
    (GroupRecType([stl]), SingleRecType(str)) => stl == str
    (SingleRecType(stl), SingleRecType(str)) => stl == str
    (GroupRecType(stl), GroupRecType(str)) => stl == str
    _ => false
  }
}

///|
pub impl Eq for RefType with equal(l, r) {
  match (l, r) {
    (HeapTypeRefType(l0, l1), HeapTypeRefType(r0, r1)) => l0 == r0 && l1 == r1
    (AbsHeapTypeRefType(l0), AbsHeapTypeRefType(r0)) => l0 == r0
    (AbsHeapTypeRefType(l0), HeapTypeRefType(true, AbsHeapTypeHeapType(r0))) =>
      l0 == r0
    (HeapTypeRefType(true, AbsHeapTypeHeapType(l0)), AbsHeapTypeRefType(r0)) =>
      l0 == r0
    _ => false
  }
}

///|
pub impl Eq for MemArg with equal(l, r) {
  l.0 == r.0 &&
  l.1.unwrap_or(MemIdx(0)) == r.1.unwrap_or(MemIdx(0)) &&
  l.2 == r.2
}

///|
type Stack[T] = Array[T]

///|
fn Limits::mem_addr_bits(lim : Limits) -> Int {
  match lim {
    I32Limits(_, _) => 32
    I64Limits(_, _) => 64
  }
}

///|
pub fn[T : @quickcheck.Arbitrary] array_of_arbitrary(
  max : UInt,
  t : Int,
  state : @quickcheck/splitmix.RandomState,
) -> Array[T] {
  let count = state.next_uint() % max + 1
  let a = []
  loop count {
    0 => break a
    n => {
      a.push(@quickcheck.Arbitrary::arbitrary(t, state))
      continue n - 1
    }
  }
}

///|
pub fn RefType::is_nullable(rt : RefType) -> Bool {
  match rt {
    HeapTypeRefType(b, _) => b
    AbsHeapTypeRefType(_) => true
  }
}

///|
pub fn RefType::get_heap_type(rt : RefType) -> HeapType {
  match rt {
    HeapTypeRefType(_, ht) => ht
    AbsHeapTypeRefType(ahs) => AbsHeapTypeHeapType(ahs)
  }
}

///|
pub fn SubType::super_types(self : SubType) -> Array[TypeIdx] {
  match self {
    SubType(_, sts, _) => sts
    CompTypeSubType(_) => []
  }
}

///|
pub fn SubType::get_comptype(self : SubType) -> CompType {
  match self {
    SubType(_, _, ct) => ct
    CompTypeSubType(ct) => ct
  }
}

///|
pub fn RecType::get_subtype(self : RecType, idx : UInt) -> SubType? {
  match (self, idx) {
    (SingleRecType(st), 0) => Some(st)
    (GroupRecType(sts), i) => sts.get(i.reinterpret_as_int())
    _ => None
  }
}

///|
pub fn DefType::project(self : DefType) -> SubType? {
  let DefType(rt, n) = self
  match rt {
    SingleRecType(st) => if n == 0 { Some(st) } else { None }
    GroupRecType(sts) => sts.get(n.reinterpret_as_int())
  }
}

pub impl Show for FuncType with output(self, logger) {
  let FuncType(props, results) = self
  logger.write_string("FuncType {\n  props : ")
  props.output(logger)
  logger.write_string("\n  results : ")
  results.output(logger)
  logger.write_string("\n}")
}

///|
pub impl Show for Env with output(self, logger) {
  logger.write_string("Env {\n  global_types : ")
  self.global_types.output(logger)
  logger.write_string("\n  rec_stack : ")
  self.rec_stack.output(logger)
  logger.write_string("\n  funcs : ")
  self.funcs.output(logger)
  logger.write_string("\n  tables : ")
  self.tables.output(logger)
  logger.write_string("\n  mems : ")
  self.mems.output(logger)
  logger.write_string("\n  globals : ")
  self.globals.output(logger)
  logger.write_string("\n  elems : ")
  self.elems.output(logger)
  logger.write_string("\n  datas : ")
  self.datas.output(logger)
  logger.write_string("\n  tags : ")
  self.tags.output(logger)
  logger.write_string("\n  locals : ")
  self.locals.output(logger)
  logger.write_string("\n  labels : ")
  self.labels.output(logger)
  logger.write_string("\n  return_type : ")
  self.return_type.output(logger)
  logger.write_string("\n}")
}

///|
pub fn Env::resolve_subtype(env : Env, idx : TypeIdx) -> SubType? {
  match idx {
    TypeIdx(i) => env.global_types.get(i.reinterpret_as_int())
    RecIdx(j) => {
      let n = env.rec_stack.length()
      if n == 0 {
        return None
      }
      match env.rec_stack.get(n - 1) {
        None => None
        Some(group) => group.get(j.reinterpret_as_int())
      }
    }
  }
}

///|
pub fn Env::resolve_heaptype_subtype(env : Env, ht : HeapType) -> SubType? {
  match ht {
    AbsHeapTypeHeapType(_) => None
    HeapType(ti) => env.resolve_subtype(ti)
    DefTypeHeapType(dt) => dt.project()
  }
}

///|
pub fn Env::get_label(env : Env, idx : LabelIdx) -> Array[ValType]? {
  let LabelIdx(i) = idx
  env.labels.get(i.reinterpret_as_int())
}

///|
pub fn Env::get_tag(env : Env, idx : TagIdx) -> TagType? {
  let TagIdx(i) = idx
  env.tags.get(i.reinterpret_as_int())
}

///|
pub fn Env::resolve_comptype(env : Env, idx : TypeIdx) -> CompType? {
  match env.resolve_subtype(idx) {
    None => None
    Some(st) => Some(st.get_comptype())
  }
}

///|
pub fn Env::resolve_functype(env : Env, idx : TypeIdx) -> FuncType? {
  match env.resolve_comptype(idx) {
    Some(FuncCompType(ps, rs)) => Some(FuncType(ps, rs))
    _ => None
  }
}

///|
pub fn Env::resolve_tag_functype(env : Env, tagidx : TagIdx) -> FuncType? {
  match env.get_tag(tagidx) {
    None => None
    Some(TagType(tidx)) => env.resolve_functype(tidx)
  }
}

///|
pub fn Env::resolve_typeidx_subtype(env : Env, tidx : TypeIdx) -> SubType? {
  match tidx {
    TypeIdx(i) => env.global_types.get(i.reinterpret_as_int())
    RecIdx(j) => {
      let n = env.rec_stack.length()
      if n == 0 {
        return None
      }
      match env.rec_stack.get(n - 1) {
        None => None
        Some(group) => group.get(j.reinterpret_as_int())
      }
    }
  }
}

///|
fn Env::get_local_type(env : Env, idx : LocalIdx) -> ValType? {
  let LocalIdx(i) = idx
  env.locals.get(i.reinterpret_as_int())
}

///|
fn Env::get_global_type(env : Env, idx : GlobalIdx) -> GlobalType? {
  let GlobalIdx(i) = idx
  env.globals.get(i.reinterpret_as_int())
}

///|
fn i32_valtype() -> ValType {
  NumTypeValType(I32NumType)
}

///|
fn i64_valtype() -> ValType {
  NumTypeValType(I64NumType)
}

///|
fn ref_valtype(rt : RefType) -> ValType {
  RefTypeValType(rt)
}

///|
fn Env::get_table_type(env : Env, idx : TableIdx) -> TableType? {
  let TableIdx(i) = idx
  env.tables.get(i.reinterpret_as_int())
}

///|
fn Env::with_label(env : Env, ts : Array[ValType]) -> Env {
  let ls = env.labels.copy()
  ls.push(ts)
  Env::{
    ..env,
    labels: ls,
  }
}

///|
pub fn Env::with_labels(env : Env, labels : Stack[Array[ValType]]) -> Env {
  Env::{
    ..env,
    labels,
  }
}

///|
pub fn Env::with_return_type(env : Env, rt : Array[ValType]?) -> Env {
  Env::{
    ..env,
    return_type: rt,
  }
}

///|
pub fn Env::with_rectype(env : Env, rt : RecType) -> Env {
  let rs = env.rec_stack.copy()
  match rt {
    SingleRecType(st) => rs.push([st])
    GroupRecType(sts) => rs.push(sts)
  }
  Env::{
    ..env,
    rec_stack: rs,
  }
}

///|
fn Env::append_rectype_types(env : Env, rt : RecType) -> Env {
  let gts = env.global_types.copy()
  match rt {
    SingleRecType(st) => gts.push(st)
    GroupRecType(sts) =>
      for st in sts {
        gts.push(st)
      }
  }
  Env::{
    ..env,
    global_types: gts,
  }
}

///|
pub fn empty_env() -> Env {
  Env::{
    global_types: [],
    rec_stack: [],
    funcs: [],
    tables: [],
    mems: [],
    globals: [],
    elems: [],
    datas: [],
    tags: [],
    locals: [],
    labels: [],
    return_type: None,
  }
}

///|
fn Env::get_label_types(env : Env, idx : LabelIdx) -> Array[ValType]? {
  let LabelIdx(i) = idx
  let n = env.labels.length() // Int
  let ii = n - 1 - i.reinterpret_as_int()
  if ii < 0 {
    return None
  }
  env.labels.get(ii)
}

///|
fn Env::expand_blocktype(
  env : Env,
  bt : BlockType,
) -> Result[(Array[ValType], Array[ValType]), String] {
  match bt {
    EmptyBlockType => Ok(([], []))
    ValTypeBlockType(vt) => Ok(([], [vt]))
    TypeIdxBlockType(tidx) =>
      match env.resolve_functype(tidx) {
        None => Err("blocktype type index is not a function type")
        Some(FuncType(params, results)) => Ok((params, results))
      }
  }
}

///|
fn Env::get_functype_by_funcidx(env : Env, idx : FuncIdx) -> FuncType? {
  let FuncIdx(i) = idx
  env.funcs.get(i.reinterpret_as_int())
}

///|
fn Env::get_elem(env : Env, i : ElemIdx) -> Elem? {
  let ElemIdx(i) = i
  env.elems.get(i.reinterpret_as_int())
}

///|
fn Env::get_memtype(env : Env, idx : MemIdx) -> MemType? {
  let MemIdx(i) = idx
  env.mems.get(i.reinterpret_as_int())
}

///|
fn ref_null_exn_valtype() -> ValType {
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(ExnAbsHeapType)))
}

///|
fn funcref_valtype() -> ValType {
  // In core Wasm, call_indirect uses funcref.
  // Your encoding: AbsHeapTypeRefType(_) is nullable; funcref is (ref null func).
  RefTypeValType(AbsHeapTypeRefType(FuncAbsHeapType))
}

///|
pub fn[T : Eq] equals(a : Array[T], b : Array[T]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
fn Limits::addr_valtype(at : Limits) -> ValType {
  match at {
    I32Limits(_) => NumTypeValType(I32NumType)
    I64Limits(_) => NumTypeValType(I64NumType)
  }
}

///|
fn min_addr(a : Limits, b : Limits) -> Limits {
  match (a, b) {
    (I32Limits(_), _) => a
    (_, I32Limits(_)) => b
    _ => a
  }
}

///|
fn elem_reftype(e : Elem) -> RefType {
  match e {
    Elem(_, kind) =>
      match kind {
        FuncsElemKind(_) => AbsHeapTypeRefType(FuncAbsHeapType) // funcref
        FuncExprsElemKind(_) => AbsHeapTypeRefType(FuncAbsHeapType) // funcref
        TypedExprsElemKind(rt, _) => rt
      }
  }
}

///|
fn ref_null_valtype(ht : HeapType) -> ValType {
  RefTypeValType(HeapTypeRefType(true, ht))
}

///|
fn Env::has_func(env : Env, idx : FuncIdx) -> Bool {
  let FuncIdx(i) = idx
  i < env.funcs.length().reinterpret_as_uint()
}

///|
fn eqref_null_valtype() -> ValType {
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(EqAbsHeapType)))
}

///|
fn Env::resolve_struct_fields(
  env : Env,
  x : TypeIdx,
) -> Result[Array[FieldType], String] {
  match env.resolve_comptype(x) {
    None => Err("unknown type index")
    Some(ct) =>
      match ct {
        StructCompType(fs) => Ok(fs)
        _ => Err("type is not a struct")
      }
  }
}

///|
fn unpack_storage(st : StorageType) -> ValType {
  match st {
    ValTypeStorageType(vt) => vt
    PackTypeStorageType(_) => NumTypeValType(I32NumType)
  }
}

///|
fn is_packed(st : StorageType) -> Bool {
  match st {
    PackTypeStorageType(_) => true
    _ => false
  }
}

///|
fn u32_to_int(u : U32) -> Int {
  let U32(i) = u
  i.reinterpret_as_int()
}

///|
fn has_default(vt : ValType) -> Bool {
  match vt {
    NumTypeValType(_) => true
    VecTypeValType => true
    RefTypeValType(rt) => rt.is_nullable() // default is ref.null
    BotValType => true
  }
}

///|
fn get_struct_field(
  fields : Array[FieldType],
  i : U32,
) -> Result[FieldType, String] {
  let idx = u32_to_int(i)
  match fields.get(idx) {
    None => Err("struct field index out of range")
    Some(ft) => Ok(ft)
  }
}

///|
fn field_is_mutable(ft : FieldType) -> Bool {
  match ft {
    FieldType(_, Var) => true
    _ => false
  }
}

///|
fn vt_i32() -> ValType {
  NumTypeValType(I32NumType)
}

///|
fn vt_i64() -> ValType {
  NumTypeValType(I64NumType)
}

///|
fn vt_f32() -> ValType {
  NumTypeValType(F32NumType)
}

///|
fn vt_f64() -> ValType {
  NumTypeValType(F64NumType)
}

///|
fn vt_v128() -> ValType {
  VecTypeValType
}

///|
fn Env::has_data(env : Env, idx : DataIdx) -> Bool {
  let DataIdx(i) = idx
  i < env.datas.length().reinterpret_as_uint()
}

///|
fn min_addr_valtype(l1 : Limits, l2 : Limits) -> ValType {
  match (l1, l2) {
    (I64Limits(_, _), I64Limits(_, _)) => NumTypeValType(I64NumType)
    _ => NumTypeValType(I32NumType)
  }
}

///|
fn anyref_valtype() -> ValType {
  // (ref null any)
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType)))
}

///|
fn externref_valtype() -> ValType {
  // (ref null extern)
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(ExternAbsHeapType)))
}

///|
fn i31ref_valtype() -> ValType {
  // (ref i31) (non-null)
  RefTypeValType(HeapTypeRefType(false, AbsHeapTypeHeapType(I31AbsHeapType)))
}

///|
fn i31ref_nullable_valtype() -> ValType {
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(I31AbsHeapType)))
}

///|
fn Env::resolve_array_field(
  env : Env,
  x : TypeIdx,
) -> Result[FieldType, String] {
  match env.resolve_comptype(x) {
    None => Err("unknown type index")
    Some(ct) =>
      match ct {
        ArrayCompType(ft) => Ok(ft)
        _ => Err("type is not an array")
      }
  }
}

///|
fn ref_array_nonnull(x : TypeIdx) -> ValType {
  RefTypeValType(HeapTypeRefType(false, HeapType(x)))
}

///|
fn ref_array_nullable(x : TypeIdx) -> ValType {
  RefTypeValType(HeapTypeRefType(true, HeapType(x)))
}

///|
fn ref_null_array_of(x : TypeIdx) -> ValType {
  RefTypeValType(HeapTypeRefType(true, HeapType(x)))
}

///|
pub fn Env::push_tag(env : Env, t : TagType) -> Env {
  let tags = env.tags.copy()
  tags.push(t)
  Env::{
    ..env,
    tags,
  }
}

///|
pub fn Env::push_global(env : Env, gt : GlobalType) -> Env {
  let globals = env.globals.copy()
  globals.push(gt)
  Env::{
    ..env,
    globals,
  }
}

///|
pub fn Env::push_func(env : Env, ft : FuncType) -> Env {
  let funcs = env.funcs.copy()
  funcs.push(ft)
  Env::{
    ..env,
    funcs,
  }
}

///|
pub fn Env::push_mem(env : Env, mt : MemType) -> Env {
  let mems = env.mems.copy()
  mems.push(mt)
  Env::{
    ..env,
    mems,
  }
}

///|
pub fn Env::push_table(env : Env, tt : TableType) -> Env {
  let tables = env.tables.copy()
  tables.push(tt)
  Env::{
    ..env,
    tables,
  }
}

///|
fn Env::with_locals(env : Env, locals : Array[ValType]) -> Env {
  Env::{
    ..env,
    locals,
  }
}

///|
fn Env::with_funcs(env : Env, funcs : Array[FuncType]) -> Env {
  Env::{
    ..env,
    funcs,
  }
}

///|
fn Env::with_types(env : Env, global_types : Array[SubType]) -> Env {
  Env::{
    ..env,
    global_types,
  }
}

///|
fn Env::with_tables(env : Env, tables : Array[TableType]) -> Env {
  Env::{
    ..env,
    tables,
  }
}

///|
fn Env::with_globals(env : Env, globals : Array[GlobalType]) -> Env {
  Env::{
    ..env,
    globals,
  }
}

///|
fn Env::with_mems(env : Env, mems : Array[MemType]) -> Env {
  Env::{
    ..env,
    mems,
  }
}

///|
fn Env::with_tags(env : Env, tags : Array[TagType]) -> Env {
  Env::{
    ..env,
    tags,
  }
}

///|
pub fn Env::push_data(env : Env, d : Data) -> Env {
  let datas = env.datas.copy()
  datas.push(d)
  Env::{
    ..env,
    datas,
  }
}

///|
pub fn Env::push_elem(env : Env, e : Elem) -> Env {
  let elems = env.elems.copy()
  elems.push(e)
  Env::{
    ..env,
    elems,
  }
}

pub fn Env::with_elems(env : Env, elems: Array[Elem]) -> Env {
  Env::{
    ..env,
    elems,
  }
}

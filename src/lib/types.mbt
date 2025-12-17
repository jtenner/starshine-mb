pub struct S33(UInt64) derive(Arbitrary)
pub struct I32(Int) derive(Arbitrary)
pub struct I64(Int64) derive(Arbitrary)
pub struct F32(Float) derive(Arbitrary)
pub struct F64(Double) derive(Arbitrary)
pub struct U32(UInt) derive(Arbitrary)
pub struct U64(UInt64) derive(Arbitrary)


pub enum NumType {
  F32NumType
  F64NumType
  I32NumType
  I64NumType
} derive(Arbitrary)

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
} derive(Arbitrary)

pub enum HeapType {
  AbsHeapTypeHeapType(AbsHeapType)
  HeapType(S33)
} derive(Arbitrary)

pub enum RefType {
  HeapTypeRefType(Bool, HeapType)
  AbsHeapTypeRefType(AbsHeapType)
} derive(Arbitrary)

pub enum ValType {
  NumTypeValType(NumType)
  VecTypeValType
  RefTypeValType(RefType)
} derive(Arbitrary)

pub type ResultType = Array[ValType]

pub enum PackType {
  I16PackType
  I8PackType
} derive(Arbitrary)
pub enum StorageType {
  ValTypeStorageType(ValType)
  PackTypeStorageType(PackType)
} derive(Arbitrary)

pub struct FieldType(StorageType, Option[Bool]) derive(Arbitrary)

pub struct TypeIdx(UInt) derive(Arbitrary)
pub struct FuncIdx(UInt) derive(Arbitrary)
pub struct TableIdx(UInt) derive(Arbitrary)
pub struct MemIdx(UInt) derive(Arbitrary)
pub struct GlobalIdx(UInt) derive(Arbitrary)
pub struct TagIdx(UInt) derive(Arbitrary)
pub struct ElemIdx(UInt) derive(Arbitrary)
pub struct DataIdx(UInt) derive(Arbitrary)
pub struct LocalIdx(UInt) derive(Arbitrary)
pub struct LabelIdx(UInt) derive(Arbitrary)
pub struct LaneIdx(Byte) derive(Arbitrary)

pub enum CompType {
  ArrayCompType(FieldType)
  StructCompType(@list.List[FieldType])
  FuncCompType(ResultType, ResultType)
} derive(Arbitrary)

pub enum SubType {
  SubType(Bool, @list.List[TypeIdx], CompType)
  CompTypeSubType(CompType)
} derive(Arbitrary)

pub enum RecType {
  RecType(SubType)
  RecTypeSubTypes(@list.List[SubType])
} derive(Arbitrary)

pub enum Limits {
  I32Limits(UInt, Option[UInt])
  I64Limits(UInt64, Option[UInt64])
} derive(Arbitrary)

pub struct TagType(TypeIdx) derive(Arbitrary)
pub struct GlobalType(ValType, Bool) derive(Arbitrary)
pub struct MemType(Limits) derive(Arbitrary)
pub struct TableType(RefType, Limits) derive(Arbitrary)

pub enum ExternType {
  FuncExternType(TypeIdx)
  TableExternType(TableType)
  MemExternType(MemType)
  GlobalExternType(GlobalType)
  TagExternType(TagType)
} derive(Arbitrary)

pub enum ExternIdx {
  FuncExternIdx(FuncIdx)
  TableExternIdx(TableIdx)
  MemExternIdx(MemIdx)
  GlobalExternIdx(GlobalIdx)
  TagExternIdx(TagIdx)
} derive(Arbitrary)

pub enum ElemMode {
  Passive
  Active(TableIdx, Expr)
  Declarative
} derive(Arbitrary)
pub enum ElemKind {
  FuncsElemKind(@list.List[FuncIdx])
  FuncExprsElemKind(@list.List[Expr])
  TypedExprsElemKind(RefType, @list.List[Expr])
} derive(Arbitrary)
pub struct Elem(ElemMode, ElemKind) derive(Arbitrary)

pub struct Expr(@list.List[Instruction]) derive(Arbitrary)
pub struct Import(Name, Name, ExternType) derive(Arbitrary)
pub struct Table(TableType, Option[Expr]) derive(Arbitrary)
pub struct Global(GlobalType, Expr) derive(Arbitrary)
pub struct Export(Name, ExternIdx) derive(Arbitrary)
pub struct Locals(U32, ValType) derive(Arbitrary)
pub struct Func(@list.List[Locals], Expr) derive(Arbitrary)

pub enum DataMode {
  Active(MemIdx, Expr)
  Passive
} derive(Arbitrary)
pub struct Data(DataMode, Bytes) derive(Arbitrary)

pub struct Name(StringView)

pub impl @quickcheck.Arbitrary for Name with arbitrary(_, state) {
  let count = state.next_positive_int() % 100
  let sb = StringBuilder::new(size_hint = count)
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

pub struct CustomSec(Name, Bytes) derive(Arbitrary)
pub struct TypeSec(@list.List[RecType]) derive(Arbitrary)
pub struct ImportSec(@list.List[Import]) derive(Arbitrary)
pub struct FuncSec(@list.List[TypeIdx]) derive(Arbitrary)
pub struct TableSec(@list.List[Table]) derive(Arbitrary)
pub struct MemSec(@list.List[MemType]) derive(Arbitrary)
pub struct GlobalSec(@list.List[Global]) derive(Arbitrary)
pub struct ExportSec(@list.List[Export]) derive(Arbitrary)
pub struct StartSec(FuncIdx) derive(Arbitrary)
pub struct ElemSec(@list.List[Elem]) derive(Arbitrary)
pub struct CodeSec(@list.List[Func]) derive(Arbitrary)
pub struct DataSec(@list.List[Data]) derive(Arbitrary)
pub struct DataCntSec(U32) derive(Arbitrary)
pub struct TagSec(@list.List[TagType]) derive(Arbitrary)

pub enum BlockType {
  EmptyBlockType
  ValTypeBlockType(ValType)
  TypeIdxBlockType(TypeIdx)
} derive(Arbitrary)

pub enum Catch {
  Catch(TagIdx, LabelIdx)
  CatchRef(TagIdx, LabelIdx)
  CatchAll(LabelIdx)
  CatchAllRef(LabelIdx)
} derive(Arbitrary)

pub struct MemArg(U32, Option[MemIdx], U64) derive(Arbitrary)
pub struct CastOp(Bool, Bool) derive(Arbitrary)

///|
pub enum Instruction {
  Unreachable
  Nop
  Block(BlockType, Expr)
  Loop(BlockType, Expr)
  If(BlockType, Array[Instruction], Option[Array[Instruction]])
  Throw(TagIdx)
  ThrowRef
  Br(LabelIdx)
  BrIf(LabelIdx)
  BrTable(@list.List[LabelIdx], LabelIdx)
  Return
  Call(FuncIdx)
  CallIndirect(TypeIdx, TableIdx)
  ReturnCall(FuncIdx)
  ReturnCallIndirect(TypeIdx, TableIdx)
  CallRef(TypeIdx)
  ReturnCallRef(TypeIdx)
  Drop
  Select(@list.List[ValType]?)
  TryTable(BlockType, @list.List[Catch], Expr)
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
} derive(Arbitrary)

pub struct Module(
  Array[CustomSec],
  Option[TypeSec],
  Option[ImportSec],
  Option[FuncSec],
  Option[TableSec],
  Option[MemSec],
  Option[TagSec],
  Option[GlobalSec],
  Option[ExportSec],
  Option[StartSec],
  Option[ElemSec],
  Option[DataCntSec],
  Option[CodeSec],
  Option[DataSec]
) derive(Arbitrary)

pub impl Eq for Module with equal(l, r) {
  l.0 == r.0 && // TODO: check all the custom sections against each other, cross product
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

pub impl Eq for CustomSec with equal(l, r) {
  l.0 == r.0 && l.1 == r.1
}

pub impl Eq for TypeSec with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for ImportSec with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for FuncSec with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for TableSec with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for MemSec with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for TagSec with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for GlobalSec with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for ExportSec with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for StartSec with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for ElemSec with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for DataCntSec with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for CodeSec with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for DataSec with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for Name with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for RecType with equal(l, r) {
  match (l, r) {
    (RecType(stl), RecTypeSubTypes(More(str, tail~))) if tail == @list.empty() => stl == str
    (RecTypeSubTypes(More(stl, tail~)), RecType(str)) if tail == @list.empty() => stl == str
    (RecType(stl), RecType(str)) => stl == str
    (RecTypeSubTypes(stl), RecTypeSubTypes(str)) => stl == str
    _ => false
  }
}

pub impl Eq for Import with equal(l, r) {
  l.0 == r.0 &&
  l.1 == r.1 &&
  l.2 == r.2
}

pub impl Eq for TypeIdx with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for Table with equal(l, r) {
  l.0 == r.0 && l.1 == r.1
}

pub impl Eq for MemType with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for TagType with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for Global with equal(l, r) {
  l.0 == r.0 && l.1 == r.1
}

pub impl Eq for Export with equal(l, r) {
  l.0 == r.0 && l.1 == r.1
}

pub impl Eq for FuncIdx with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for Elem with equal(l, r) {
  l.0 == r.0 && l.1 == r.1
}

pub impl Eq for ElemMode with equal(l, r) {
  match (l, r) {
    (Active(l0, l1), Active(r0, r1)) => l0 == r0 && l1 == r1
    (Passive, Passive) => true
    (Declarative, Declarative) => true
    _ => false
  }
}

pub impl Eq for ElemKind  with equal(l, r) {
  match (l, r) {
    (FuncsElemKind(l), FuncsElemKind(r)) => l == r
    // Legacy element expressions: always (ref null func)
    (FuncExprsElemKind(l), FuncExprsElemKind(r)) => l == r
    // Typed element expressions
    (TypedExprsElemKind(l0, l1), TypedExprsElemKind(r0, r1)) => l0 == r0 && l1 == r1
    _ => false
  }
}

pub impl Eq for U32 with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for Func with equal(l, r) {
  l.0 == r.0 && l.1 == r.1
}

pub impl Eq for Data with equal(l, r) {
  l.0 == r.0 && l.1 == r.1
}

pub impl Eq for SubType with equal(l, r) {
  match (l, r) {
    (SubType(fl, stl, ctl), SubType(fr, str, ctr)) => fl == fr && stl == str && ctl == ctr
    (CompTypeSubType(ctl), CompTypeSubType(ctr)) => ctl == ctr
    _ => false
  }
}

///|
pub impl Eq for ExternType with equal(l, r) {
  match (l, r) {
    (FuncExternType(l), FuncExternType(r)) => l == r
    (TableExternType(l), TableExternType(r)) => l == r
    (MemExternType(l), MemExternType(r)) => l == r
    (GlobalExternType(l), GlobalExternType(r)) => l == r
    (TagExternType(l), TagExternType(r)) => l == r
    _ => false
  }
}

pub impl Eq for TableType with equal(l, r) {
  l.0 == r.0 && l.1 == r.1
}

pub impl Eq for Expr with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for Limits with equal(l, r) {
  match (l, r) {
    (I32Limits(l0, l1), I32Limits(r0, r1)) => l0 == r0 && l1 == r1
    (I64Limits(l0, l1), I64Limits(r0, r1)) => l0 == r0 && l1 == r1
    _ => false
  }
}

pub impl Eq for GlobalType with equal(l, r) {
  l.0 == r.0 && l.1 == r.1
}

pub impl Eq for ExternIdx with equal(l, r) {
  match (l, r) {
    (FuncExternIdx(l), FuncExternIdx(r)) => l == r
    (TableExternIdx(l), TableExternIdx(r)) => l == r
    (MemExternIdx(l), MemExternIdx(r)) => l == r
    (GlobalExternIdx(l), GlobalExternIdx(r)) => l == r
    (TagExternIdx(l), TagExternIdx(r)) => l == r
    _ => false
  }
}

pub impl Eq for Locals with equal(l, r) {
  l.0 == r.0 && l.1 == r.1
}

pub impl Eq for DataMode with equal(l, r) {
  match (l, r) {
    (Active(l0, l1), Active(r0, r1)) => l0 == r0 && l1 == r1
    (Passive, Passive) => true
    _ => false
  }
}

pub impl Eq for CompType with equal(l, r) {
  match (l, r) {
    (ArrayCompType(l), ArrayCompType(r)) => l == r
    (StructCompType(l), StructCompType(r)) => l == r
    (FuncCompType(l0, l1), FuncCompType(r0, r1)) => l0 == r0 && l1 == r1
    _ => false
  }
}

pub impl Eq for RefType with equal(l, r) {
  match (l, r) {
    (HeapTypeRefType(l0, l1), HeapTypeRefType(r0, r1)) => l0 == r0 && l1 == r1
    (AbsHeapTypeRefType(l0),   AbsHeapTypeRefType(r0)) => l0 == r0
    (AbsHeapTypeRefType(l0), HeapTypeRefType(true, AbsHeapTypeHeapType(r0))) => l0 == r0
    (HeapTypeRefType(true, AbsHeapTypeHeapType(l0)), AbsHeapTypeRefType(r0)) => l0 == r0
    _ => false
  }
}

pub impl Eq for ValType with equal(l, r) {
  match (l, r) {
    (VecTypeValType, VecTypeValType) => true
    (NumTypeValType(n0), NumTypeValType(n1)) => n0 == n1
    (RefTypeValType(r0), RefTypeValType(r1)) => r0 == r1
    _ => false
  }
}

pub impl Eq for TableIdx with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for MemIdx with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for GlobalIdx with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for TagIdx with equal(l, r) {
  l.0 == r.0
}

fn norm_mut(m : Option[Bool]) -> Bool {
  match m {
    None => false
    Some(b) => b
  }
}

pub impl Eq for FieldType with equal(l, r) {
  l.0 == r.0 && norm_mut(l.1) == norm_mut(r.1)
}

///|
pub impl Eq for HeapType with equal(l, r) {
  match (l, r) {
    (AbsHeapTypeHeapType(l), AbsHeapTypeHeapType(r)) => l == r
    (HeapType(l), HeapType(r)) => l == r
    _ => false
  }
}

pub impl Eq for AbsHeapType with equal(l, r) {
  match (l, r) {
    (ExnAbsHeapType,   ExnAbsHeapType) => true
    (ArrayAbsHeapType,   ArrayAbsHeapType) => true
    (StructAbsHeapType,   StructAbsHeapType) => true
    (I31AbsHeapType,   I31AbsHeapType) => true
    (EqAbsHeapType,   EqAbsHeapType) => true
    (AnyAbsHeapType,   AnyAbsHeapType) => true
    (ExternAbsHeapType,   ExternAbsHeapType) => true
    (FuncAbsHeapType,   FuncAbsHeapType) => true
    (NoneAbsHeapType,   NoneAbsHeapType) => true
    (NoExternAbsHeapType,   NoExternAbsHeapType) => true
    (NoFuncAbsHeapType,   NoFuncAbsHeapType) => true
    (NoExnAbsHeapType,   NoExnAbsHeapType) => true
    _ => false
  }
}

pub impl Eq for NumType with equal(l, r) {
  match (l, r) {
    (F32NumType,   F32NumType) => true
    (F64NumType,   F64NumType) => true
    (I32NumType,   I32NumType) => true
    (I64NumType,   I64NumType) => true
    _ => false
  }
}

pub impl Eq for StorageType with equal(l, r) {
  match (l, r) {
    (ValTypeStorageType(l), ValTypeStorageType(r)) => l == r
    (PackTypeStorageType(l),   PackTypeStorageType(r)) => l == r
    _ => false
  }
}

pub impl Eq for S33 with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for PackType with equal(l, r) {
  match (l, r) {
    (I8PackType, I8PackType) => true
    (I16PackType, I16PackType) => true
    _ => false
  }
}

pub impl Eq for BlockType with equal(l, r) {
  match (l, r) {
    (ValTypeBlockType(l), ValTypeBlockType(r)) => l == r
    (TypeIdxBlockType(l), TypeIdxBlockType(r)) => l == r
    (EmptyBlockType, EmptyBlockType) => true
    _ => false
  }
}

pub impl Eq for LabelIdx with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for Catch with equal(l, r) {
  match (l, r) {
    (Catch(l0, l1),   Catch(r0, r1)) => l0 == r0 && l1 == r1
    (CatchRef(l0, l1),   CatchRef(r0, r1)) => l0 == r0 && l1 == r1
    (CatchAll(l),   CatchAll(r)) => l == r
    (CatchAllRef(l),   CatchAllRef(r)) => l == r
    _ => false
  }
}

pub impl Eq for LocalIdx with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for MemArg with equal(l, r) {
  l.0 == r.0 && l.1.unwrap_or(MemIdx(0)) == r.1.unwrap_or(MemIdx(0)) && l.2 == r.2
}

pub impl Eq for ElemIdx with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for CastOp with equal(l, r) {
  l.0 == r.0 && l.1 == r.1
}

pub impl Eq for DataIdx with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for F32 with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for F64 with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for U64 with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for I32 with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for I64 with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for LaneIdx with equal(l, r) {
  l.0 == r.0
}

pub impl Eq for Instruction with equal(l, r) {
  match (l, r) {
    (Unreachable, Unreachable) => true
    (Nop, Nop) => true
    (Block(l0, l1), Block(r0, r1)) => l0 == r0 && l1 == r1
    (Loop(l0, l1), Loop(r0, r1)) => l0 == r0 && l1 == r1
    (If(l0, l1, l2), If(r0, r1, r2)) => l0 == r0 && l1 == r1 && l2 == r2
    (Throw(l), Throw(r)) => l == r
    (ThrowRef, ThrowRef) => true
    (Br(l), Br(r)) => l == r
    (BrIf(l), BrIf(r)) => l == r
    (BrTable(l0, l1), BrTable(r0, r1)) => l0 == r0 && l1 == r1
    (Return, Return) => true
    (Call(l), Call(r)) => l == r
    (CallIndirect(l0, l1), CallIndirect(r0, r1)) => l0 == r0 && l1 == r1
    (ReturnCall(l), ReturnCall(r)) => l == r
    (ReturnCallIndirect(l0, l1), ReturnCallIndirect(r0, r1)) => l0 == r0 && l1 == r1
    (CallRef(l), CallRef(r)) => l == r
    (ReturnCallRef(l), ReturnCallRef(r)) => l == r
    (Drop, Drop) => true
    (Select(l), Select(r)) => l == r
    (TryTable(l0, l1, l2), TryTable(r0, r1, r2)) => l0 == r0 && l1 == r1 && l2 == r2
    (LocalGet(l), LocalGet(r)) => l == r
    (LocalSet(l), LocalSet(r)) => l == r
    (LocalTee(l), LocalTee(r)) => l == r
    (GlobalGet(l), GlobalGet(r)) => l == r
    (GlobalSet(l), GlobalSet(r)) => l == r
    (TableGet(l), TableGet(r)) => l == r
    (TableSet(l), TableSet(r)) => l == r
    (I32Load(l), I32Load(r)) => l == r
    (I64Load(l), I64Load(r)) => l == r
    (F32Load(l), F32Load(r)) => l == r
    (F64Load(l), F64Load(r)) => l == r
    (I32Load8S(l), I32Load8S(r)) => l == r
    (I32Load8U(l), I32Load8U(r)) => l == r
    (I32Load16S(l), I32Load16S(r)) => l == r
    (I32Load16U(l), I32Load16U(r)) => l == r
    (I64Load8S(l), I64Load8S(r)) => l == r
    (I64Load8U(l), I64Load8U(r)) => l == r
    (I64Load16S(l), I64Load16S(r)) => l == r
    (I64Load16U(l), I64Load16U(r)) => l == r
    (I64Load32S(l), I64Load32S(r)) => l == r
    (I64Load32U(l), I64Load32U(r)) => l == r
    (I32Store(l), I32Store(r)) => l == r
    (I64Store(l), I64Store(r)) => l == r
    (F32Store(l), F32Store(r)) => l == r
    (F64Store(l), F64Store(r)) => l == r
    (I32Store8(l), I32Store8(r)) => l == r
    (I32Store16(l), I32Store16(r)) => l == r
    (I64Store8(l), I64Store8(r)) => l == r
    (I64Store16(l), I64Store16(r)) => l == r
    (I64Store32(l), I64Store32(r)) => l == r
    (MemorySize(l), MemorySize(r)) => l == r
    (MemoryGrow(l), MemoryGrow(r)) => l == r
    (I32Const(l), I32Const(r)) => l == r
    (I64Const(l), I64Const(r)) => l == r
    (F32Const(l), F32Const(r)) => l == r
    (F64Const(l), F64Const(r)) => l == r
    (I32Eqz, I32Eqz) => true
    (I32Eq, I32Eq) => true
    (I32Ne, I32Ne) => true
    (I32LtS, I32LtS) => true
    (I32LtU, I32LtU) => true
    (I32GtS, I32GtS) => true
    (I32GtU, I32GtU) => true
    (I32LeS, I32LeS) => true
    (I32LeU, I32LeU) => true
    (I32GeS, I32GeS) => true
    (I32GeU, I32GeU) => true
    (I64Eqz, I64Eqz) => true
    (I64Eq, I64Eq) => true
    (I64Ne, I64Ne) => true
    (I64LtS, I64LtS) => true
    (I64LtU, I64LtU) => true
    (I64GtS, I64GtS) => true
    (I64GtU, I64GtU) => true
    (I64LeS, I64LeS) => true
    (I64LeU, I64LeU) => true
    (I64GeS, I64GeS) => true
    (I64GeU, I64GeU) => true
    (F32Eq, F32Eq) => true
    (F32Ne, F32Ne) => true
    (F32Lt, F32Lt) => true
    (F32Gt, F32Gt) => true
    (F32Le, F32Le) => true
    (F32Ge, F32Ge) => true
    (F64Eq, F64Eq) => true
    (F64Ne, F64Ne) => true
    (F64Lt, F64Lt) => true
    (F64Gt, F64Gt) => true
    (F64Le, F64Le) => true
    (F64Ge, F64Ge) => true
    (I32Clz, I32Clz) => true
    (I32Ctz, I32Ctz) => true
    (I32Popcnt, I32Popcnt) => true
    (I32Add, I32Add) => true
    (I32Sub, I32Sub) => true
    (I32Mul, I32Mul) => true
    (I32DivS, I32DivS) => true
    (I32DivU, I32DivU) => true
    (I32RemS, I32RemS) => true
    (I32RemU, I32RemU) => true
    (I32And, I32And) => true
    (I32Or, I32Or) => true
    (I32Xor, I32Xor) => true
    (I32Shl, I32Shl) => true
    (I32ShrS, I32ShrS) => true
    (I32ShrU, I32ShrU) => true
    (I32Rotl, I32Rotl) => true
    (I32Rotr, I32Rotr) => true
    (I64Clz, I64Clz) => true
    (I64Ctz, I64Ctz) => true
    (I64Popcnt, I64Popcnt) => true
    (I64Add, I64Add) => true
    (I64Sub, I64Sub) => true
    (I64Mul, I64Mul) => true
    (I64DivS, I64DivS) => true
    (I64DivU, I64DivU) => true
    (I64RemS, I64RemS) => true
    (I64RemU, I64RemU) => true
    (I64And, I64And) => true
    (I64Or, I64Or) => true
    (I64Xor, I64Xor) => true
    (I64Shl, I64Shl) => true
    (I64ShrS, I64ShrS) => true
    (I64ShrU, I64ShrU) => true
    (I64Rotl, I64Rotl) => true
    (I64Rotr, I64Rotr) => true
    (F32Abs, F32Abs) => true
    (F32Neg, F32Neg) => true
    (F32Ceil, F32Ceil) => true
    (F32Floor, F32Floor) => true
    (F32Trunc, F32Trunc) => true
    (F32Nearest, F32Nearest) => true
    (F32Sqrt, F32Sqrt) => true
    (F32Add, F32Add) => true
    (F32Sub, F32Sub) => true
    (F32Mul, F32Mul) => true
    (F32Div, F32Div) => true
    (F32Min, F32Min) => true
    (F32Max, F32Max) => true
    (F32Copysign, F32Copysign) => true
    (F64Abs, F64Abs) => true
    (F64Neg, F64Neg) => true
    (F64Ceil, F64Ceil) => true
    (F64Floor, F64Floor) => true
    (F64Trunc, F64Trunc) => true
    (F64Nearest, F64Nearest) => true
    (F64Sqrt, F64Sqrt) => true
    (F64Add, F64Add) => true
    (F64Sub, F64Sub) => true
    (F64Mul, F64Mul) => true
    (F64Div, F64Div) => true
    (F64Min, F64Min) => true
    (F64Max, F64Max) => true
    (F64Copysign, F64Copysign) => true
    (I32WrapI64, I32WrapI64) => true
    (I32TruncF32S, I32TruncF32S) => true
    (I32TruncF32U, I32TruncF32U) => true
    (I32TruncF64S, I32TruncF64S) => true
    (I32TruncF64U, I32TruncF64U) => true
    (I64ExtendI32S, I64ExtendI32S) => true
    (I64ExtendI32U, I64ExtendI32U) => true
    (I64TruncF32S, I64TruncF32S) => true
    (I64TruncF32U, I64TruncF32U) => true
    (I64TruncF64S, I64TruncF64S) => true
    (I64TruncF64U, I64TruncF64U) => true
    (F32ConvertI32S, F32ConvertI32S) => true
    (F32ConvertI32U, F32ConvertI32U) => true
    (F32ConvertI64S, F32ConvertI64S) => true
    (F32ConvertI64U, F32ConvertI64U) => true
    (F32DemoteF64, F32DemoteF64) => true
    (F64ConvertI32S, F64ConvertI32S) => true
    (F64ConvertI32U, F64ConvertI32U) => true
    (F64ConvertI64S, F64ConvertI64S) => true
    (F64ConvertI64U, F64ConvertI64U) => true
    (F64PromoteF32, F64PromoteF32) => true
    (I32ReinterpretF32, I32ReinterpretF32) => true
    (I64ReinterpretF64, I64ReinterpretF64) => true
    (F32ReinterpretI32, F32ReinterpretI32) => true
    (F64ReinterpretI64, F64ReinterpretI64) => true
    (I32Extend8S, I32Extend8S) => true
    (I32Extend16S, I32Extend16S) => true
    (I64Extend8S, I64Extend8S) => true
    (I64Extend16S, I64Extend16S) => true
    (I64Extend32S, I64Extend32S) => true
    (RefNull(l), RefNull(r)) => l == r
    (RefIsNull, RefIsNull) => true
    (RefFunc(l), RefFunc(r)) => l == r
    (RefEq, RefEq) => true
    (RefAsNonNull, RefAsNonNull) => true
    (BrOnNull(l), BrOnNull(r)) => l == r
    (BrOnNonNull(l), BrOnNonNull(r)) => l == r
    (StructNew(l), StructNew(r)) => l == r
    (StructNewDefault(l), StructNewDefault(r)) => l == r
    (StructGet(l0, l1), StructGet(r0, r1)) => l0 == r0 && l1 == r1
    (StructGetS(l0, l1), StructGetS(r0, r1)) => l0 == r0 && l1 == r1
    (StructGetU(l0, l1), StructGetU(r0, r1)) => l0 == r0 && l1 == r1
    (StructSet(l0, l1), StructSet(r0, r1)) => l0 == r0 && l1 == r1
    (ArrayNew(l), ArrayNew(r)) => l == r
    (ArrayNewDefault(l), ArrayNewDefault(r)) => l == r
    (ArrayNewFixed(l0, l1), ArrayNewFixed(r0, r1)) => l0 == r0 && l1 == r1
    (ArrayNewData(l0, l1), ArrayNewData(r0, r1)) => l0 == r0 && l1 == r1
    (ArrayNewElem(l0, l1), ArrayNewElem(r0, r1)) => l0 == r0 && l1 == r1
    (ArrayGet(l), ArrayGet(r)) => l == r
    (ArrayGetS(l), ArrayGetS(r)) => l == r
    (ArrayGetU(l), ArrayGetU(r)) => l == r
    (ArraySet(l), ArraySet(r)) => l == r
    (ArrayLen, ArrayLen) => true
    (ArrayFill(l), ArrayFill(r)) => l == r
    (ArrayCopy(l0, l1), ArrayCopy(r0, r1)) => l0 == r0 && l1 == r1
    (ArrayInitData(l0, l1), ArrayInitData(r0, r1)) => l0 == r0 && l1 == r1
    (ArrayInitElem(l0, l1), ArrayInitElem(r0, r1)) => l0 == r0 && l1 == r1
    (RefTest(l0, l1), RefTest(r0, r1)) => l0 == r0 && l1 == r1
    (RefCast(l0, l1), RefCast(r0, r1)) => l0 == r0 && l1 == r1
    (BrOnCast(l0, l1, l2, l3), BrOnCast(r0, r1, r2, r3)) => l0 == r0 && l1 == r1 && l2 == r2 && l3 == r3
    (BrOnCastFail(l0, l1, l2, l3), BrOnCastFail(r0, r1, r2, r3)) => l0 == r0 && l1 == r1 && l2 == r2 && l3 == r3
    (AnyConvertExtern, AnyConvertExtern) => true
    (ExternConvertAny, ExternConvertAny) => true
    (RefI31, RefI31) => true
    (I31GetS, I31GetS) => true
    (I31GetU, I31GetU) => true
    (I32TruncSatF32S, I32TruncSatF32S) => true
    (I32TruncSatF32U, I32TruncSatF32U) => true
    (I32TruncSatF64S, I32TruncSatF64S) => true
    (I32TruncSatF64U, I32TruncSatF64U) => true
    (I64TruncSatF32S, I64TruncSatF32S) => true
    (I64TruncSatF32U, I64TruncSatF32U) => true
    (I64TruncSatF64S, I64TruncSatF64S) => true
    (I64TruncSatF64U, I64TruncSatF64U) => true
    (MemoryInit(l0, l1), MemoryInit(r0, r1)) => l0 == r0 && l1 == r1
    (DataDrop(l), DataDrop(r)) => l == r
    (MemoryCopy(l0, l1), MemoryCopy(r0, r1)) => l0 == r0 && l1 == r1
    (MemoryFill(l), MemoryFill(r)) => l == r
    (TableInit(l0, l1), TableInit(r0, r1)) => l0 == r0 && l1 == r1
    (ElemDrop(l), ElemDrop(r)) => l == r
    (TableCopy(l0, l1), TableCopy(r0, r1)) => l0 == r0 && l1 == r1
    (TableGrow(l), TableGrow(r)) => l == r
    (TableSize(l), TableSize(r)) => l == r
    (TableFill(l), TableFill(r)) => l == r
    (V128Load(l), V128Load(r)) => l == r
    (V128Load8x8S(l), V128Load8x8S(r)) => l == r
    (V128Load8x8U(l), V128Load8x8U(r)) => l == r
    (V128Load16x4S(l), V128Load16x4S(r)) => l == r
    (V128Load16x4U(l), V128Load16x4U(r)) => l == r
    (V128Load32x2S(l), V128Load32x2S(r)) => l == r
    (V128Load32x2U(l), V128Load32x2U(r)) => l == r
    (V128Load8Splat(l), V128Load8Splat(r)) => l == r
    (V128Load16Splat(l), V128Load16Splat(r)) => l == r
    (V128Load32Splat(l), V128Load32Splat(r)) => l == r
    (V128Load64Splat(l), V128Load64Splat(r)) => l == r
    (V128Store(l), V128Store(r)) => l == r
    (V128Const(l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15), V128Const(r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15)) =>
      l0 == r0 && l1 == r1 && l2 == r2 && l3 == r3 && l4 == r4 && l5 == r5 && l6 == r6 && l7 == r7 && l8 == r8 && l9 == r9 && l10 == r10 && l11 == r11 && l12 == r12 && l13 == r13 && l14 == r14 && l15 == r15
    (I8x16Shuffle(l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15), I8x16Shuffle(r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15)) =>
      l0 == r0 && l1 == r1 && l2 == r2 && l3 == r3 && l4 == r4 && l5 == r5 && l6 == r6 && l7 == r7 && l8 == r8 && l9 == r9 && l10 == r10 && l11 == r11 && l12 == r12 && l13 == r13 && l14 == r14 && l15 == r15
    (I8x16Swizzle, I8x16Swizzle) => true
    (I8x16Splat, I8x16Splat) => true
    (I16x8Splat, I16x8Splat) => true
    (I32x4Splat, I32x4Splat) => true
    (I64x2Splat, I64x2Splat) => true
    (F32x4Splat, F32x4Splat) => true
    (F64x2Splat, F64x2Splat) => true
    (I8x16ExtractLaneS(l), I8x16ExtractLaneS(r)) => l == r
    (I8x16ExtractLaneU(l), I8x16ExtractLaneU(r)) => l == r
    (I8x16ReplaceLane(l), I8x16ReplaceLane(r)) => l == r
    (I16x8ExtractLaneS(l), I16x8ExtractLaneS(r)) => l == r
    (I16x8ExtractLaneU(l), I16x8ExtractLaneU(r)) => l == r
    (I16x8ReplaceLane(l), I16x8ReplaceLane(r)) => l == r
    (I32x4ExtractLane(l), I32x4ExtractLane(r)) => l == r
    (I32x4ReplaceLane(l), I32x4ReplaceLane(r)) => l == r
    (I64x2ExtractLane(l), I64x2ExtractLane(r)) => l == r
    (I64x2ReplaceLane(l), I64x2ReplaceLane(r)) => l == r
    (F32x4ExtractLane(l), F32x4ExtractLane(r)) => l == r
    (F32x4ReplaceLane(l), F32x4ReplaceLane(r)) => l == r
    (F64x2ExtractLane(l), F64x2ExtractLane(r)) => l == r
    (F64x2ReplaceLane(l), F64x2ReplaceLane(r)) => l == r
    (I8x16Eq, I8x16Eq) => true
    (I8x16Ne, I8x16Ne) => true
    (I8x16LtS, I8x16LtS) => true
    (I8x16LtU, I8x16LtU) => true
    (I8x16GtS, I8x16GtS) => true
    (I8x16GtU, I8x16GtU) => true
    (I8x16LeS, I8x16LeS) => true
    (I8x16LeU, I8x16LeU) => true
    (I8x16GeS, I8x16GeS) => true
    (I8x16GeU, I8x16GeU) => true
    (I16x8Eq, I16x8Eq) => true
    (I16x8Ne, I16x8Ne) => true
    (I16x8LtS, I16x8LtS) => true
    (I16x8LtU, I16x8LtU) => true
    (I16x8GtS, I16x8GtS) => true
    (I16x8GtU, I16x8GtU) => true
    (I16x8LeS, I16x8LeS) => true
    (I16x8LeU, I16x8LeU) => true
    (I16x8GeS, I16x8GeS) => true
    (I16x8GeU, I16x8GeU) => true
    (I32x4Eq, I32x4Eq) => true
    (I32x4Ne, I32x4Ne) => true
    (I32x4LtS, I32x4LtS) => true
    (I32x4LtU, I32x4LtU) => true
    (I32x4GtS, I32x4GtS) => true
    (I32x4GtU, I32x4GtU) => true
    (I32x4LeS, I32x4LeS) => true
    (I32x4LeU, I32x4LeU) => true
    (I32x4GeS, I32x4GeS) => true
    (I32x4GeU, I32x4GeU) => true
    (F32x4Eq, F32x4Eq) => true
    (F32x4Ne, F32x4Ne) => true
    (F32x4Lt, F32x4Lt) => true
    (F32x4Gt, F32x4Gt) => true
    (F32x4Le, F32x4Le) => true
    (F32x4Ge, F32x4Ge) => true
    (F64x2Eq, F64x2Eq) => true
    (F64x2Ne, F64x2Ne) => true
    (F64x2Lt, F64x2Lt) => true
    (F64x2Gt, F64x2Gt) => true
    (F64x2Le, F64x2Le) => true
    (F64x2Ge, F64x2Ge) => true
    (V128Not, V128Not) => true
    (V128And, V128And) => true
    (V128Andnot, V128Andnot) => true
    (V128Or, V128Or) => true
    (V128Xor, V128Xor) => true
    (V128Bitselect, V128Bitselect) => true
    (V128AnyTrue, V128AnyTrue) => true
    (V128Load8Lane(l0, l1), V128Load8Lane(r0, r1)) => l0 == r0 && l1 == r1
    (V128Load16Lane(l0, l1), V128Load16Lane(r0, r1)) => l0 == r0 && l1 == r1
    (V128Load32Lane(l0, l1), V128Load32Lane(r0, r1)) => l0 == r0 && l1 == r1
    (V128Load64Lane(l0, l1), V128Load64Lane(r0, r1)) => l0 == r0 && l1 == r1
    (V128Store8Lane(l0, l1), V128Store8Lane(r0, r1)) => l0 == r0 && l1 == r1
    (V128Store16Lane(l0, l1), V128Store16Lane(r0, r1)) => l0 == r0 && l1 == r1
    (V128Store32Lane(l0, l1), V128Store32Lane(r0, r1)) => l0 == r0 && l1 == r1
    (V128Store64Lane(l0, l1), V128Store64Lane(r0, r1)) => l0 == r0 && l1 == r1
    (V128Load32Zero(l), V128Load32Zero(r)) => l == r
    (V128Load64Zero(l), V128Load64Zero(r)) => l == r
    (F32x4DemoteF64x2Zero, F32x4DemoteF64x2Zero) => true
    (F64x2PromoteLowF32x4, F64x2PromoteLowF32x4) => true
    (I8x16Abs, I8x16Abs) => true
    (I8x16Neg, I8x16Neg) => true
    (I8x16Popcnt, I8x16Popcnt) => true
    (I8x16AllTrue, I8x16AllTrue) => true
    (I8x16Bitmask, I8x16Bitmask) => true
    (I8x16NarrowI16x8S, I8x16NarrowI16x8S) => true
    (I8x16NarrowI16x8U, I8x16NarrowI16x8U) => true
    (F32x4Ceil, F32x4Ceil) => true
    (F32x4Floor, F32x4Floor) => true
    (F32x4Trunc, F32x4Trunc) => true
    (F32x4Nearest, F32x4Nearest) => true
    (I8x16Shl, I8x16Shl) => true
    (I8x16ShrS, I8x16ShrS) => true
    (I8x16ShrU, I8x16ShrU) => true
    (I8x16Add, I8x16Add) => true
    (I8x16AddSatS, I8x16AddSatS) => true
    (I8x16AddSatU, I8x16AddSatU) => true
    (I8x16Sub, I8x16Sub) => true
    (I8x16SubSatS, I8x16SubSatS) => true
    (I8x16SubSatU, I8x16SubSatU) => true
    (F64x2Ceil, F64x2Ceil) => true
    (F64x2Floor, F64x2Floor) => true
    (I8x16MinS, I8x16MinS) => true
    (I8x16MinU, I8x16MinU) => true
    (I8x16MaxS, I8x16MaxS) => true
    (I8x16MaxU, I8x16MaxU) => true
    (F64x2Trunc, F64x2Trunc) => true
    (I8x16AvgrU, I8x16AvgrU) => true
    (I16x8ExtaddPairwiseI8x16S, I16x8ExtaddPairwiseI8x16S) => true
    (I16x8ExtaddPairwiseI8x16U, I16x8ExtaddPairwiseI8x16U) => true
    (I32x4ExtaddPairwiseI16x8S, I32x4ExtaddPairwiseI16x8S) => true
    (I32x4ExtaddPairwiseI16x8U, I32x4ExtaddPairwiseI16x8U) => true
    (I16x8Abs, I16x8Abs) => true
    (I16x8Neg, I16x8Neg) => true
    (I16x8Q15mulrSatS, I16x8Q15mulrSatS) => true
    (I16x8AllTrue, I16x8AllTrue) => true
    (I16x8Bitmask, I16x8Bitmask) => true
    (I16x8NarrowI32x4S, I16x8NarrowI32x4S) => true
    (I16x8NarrowI32x4U, I16x8NarrowI32x4U) => true
    (I16x8ExtendLowI8x16S, I16x8ExtendLowI8x16S) => true
    (I16x8ExtendHighI8x16S, I16x8ExtendHighI8x16S) => true
    (I16x8ExtendLowI8x16U, I16x8ExtendLowI8x16U) => true
    (I16x8ExtendHighI8x16U, I16x8ExtendHighI8x16U) => true
    (I16x8Shl, I16x8Shl) => true
    (I16x8ShrS, I16x8ShrS) => true
    (I16x8ShrU, I16x8ShrU) => true
    (I16x8Add, I16x8Add) => true
    (I16x8AddSatS, I16x8AddSatS) => true
    (I16x8AddSatU, I16x8AddSatU) => true
    (I16x8Sub, I16x8Sub) => true
    (I16x8SubSatS, I16x8SubSatS) => true
    (I16x8SubSatU, I16x8SubSatU) => true
    (F64x2Nearest, F64x2Nearest) => true
    (I16x8Mul, I16x8Mul) => true
    (I16x8MinS, I16x8MinS) => true
    (I16x8MinU, I16x8MinU) => true
    (I16x8MaxS, I16x8MaxS) => true
    (I16x8MaxU, I16x8MaxU) => true
    (I16x8AvgrU, I16x8AvgrU) => true
    (I16x8ExtmulLowI8x16S, I16x8ExtmulLowI8x16S) => true
    (I16x8ExtmulHighI8x16S, I16x8ExtmulHighI8x16S) => true
    (I16x8ExtmulLowI8x16U, I16x8ExtmulLowI8x16U) => true
    (I16x8ExtmulHighI8x16U, I16x8ExtmulHighI8x16U) => true
    (I32x4Abs, I32x4Abs) => true
    (I32x4Neg, I32x4Neg) => true
    (I32x4AllTrue, I32x4AllTrue) => true
    (I32x4Bitmask, I32x4Bitmask) => true
    (I32x4ExtendLowI16x8S, I32x4ExtendLowI16x8S) => true
    (I32x4ExtendHighI16x8S, I32x4ExtendHighI16x8S) => true
    (I32x4ExtendLowI16x8U, I32x4ExtendLowI16x8U) => true
    (I32x4ExtendHighI16x8U, I32x4ExtendHighI16x8U) => true
    (I32x4Shl, I32x4Shl) => true
    (I32x4ShrS, I32x4ShrS) => true
    (I32x4ShrU, I32x4ShrU) => true
    (I32x4Add, I32x4Add) => true
    (I32x4Sub, I32x4Sub) => true
    (I32x4Mul, I32x4Mul) => true
    (I32x4MinS, I32x4MinS) => true
    (I32x4MinU, I32x4MinU) => true
    (I32x4MaxS, I32x4MaxS) => true
    (I32x4MaxU, I32x4MaxU) => true
    (I32x4DotI16x8S, I32x4DotI16x8S) => true
    (I32x4ExtmulLowI16x8S, I32x4ExtmulLowI16x8S) => true
    (I32x4ExtmulHighI16x8S, I32x4ExtmulHighI16x8S) => true
    (I32x4ExtmulLowI16x8U, I32x4ExtmulLowI16x8U) => true
    (I32x4ExtmulHighI16x8U, I32x4ExtmulHighI16x8U) => true
    (I64x2Abs, I64x2Abs) => true
    (I64x2Neg, I64x2Neg) => true
    (I64x2AllTrue, I64x2AllTrue) => true
    (I64x2Bitmask, I64x2Bitmask) => true
    (I64x2ExtendLowI32x4S, I64x2ExtendLowI32x4S) => true
    (I64x2ExtendHighI32x4S, I64x2ExtendHighI32x4S) => true
    (I64x2ExtendLowI32x4U, I64x2ExtendLowI32x4U) => true
    (I64x2ExtendHighI32x4U, I64x2ExtendHighI32x4U) => true
    (I64x2Shl, I64x2Shl) => true
    (I64x2ShrS, I64x2ShrS) => true
    (I64x2ShrU, I64x2ShrU) => true
    (I64x2Add, I64x2Add) => true
    (I64x2Sub, I64x2Sub) => true
    (I64x2Mul, I64x2Mul) => true
    (I64x2Eq, I64x2Eq) => true
    (I64x2Ne, I64x2Ne) => true
    (I64x2LtS, I64x2LtS) => true
    (I64x2GtS, I64x2GtS) => true
    (I64x2LeS, I64x2LeS) => true
    (I64x2GeS, I64x2GeS) => true
    (I64x2ExtmulLowI32x4S, I64x2ExtmulLowI32x4S) => true
    (I64x2ExtmulHighI32x4S, I64x2ExtmulHighI32x4S) => true
    (I64x2ExtmulLowI32x4U, I64x2ExtmulLowI32x4U) => true
    (I64x2ExtmulHighI32x4U, I64x2ExtmulHighI32x4U) => true
    (F32x4Abs, F32x4Abs) => true
    (F32x4Neg, F32x4Neg) => true
    (F32x4Sqrt, F32x4Sqrt) => true
    (F32x4Add, F32x4Add) => true
    (F32x4Sub, F32x4Sub) => true
    (F32x4Mul, F32x4Mul) => true
    (F32x4Div, F32x4Div) => true
    (F32x4Min, F32x4Min) => true
    (F32x4Max, F32x4Max) => true
    (F32x4Pmin, F32x4Pmin) => true
    (F32x4Pmax, F32x4Pmax) => true
    (F64x2Abs, F64x2Abs) => true
    (F64x2Neg, F64x2Neg) => true
    (F64x2Sqrt, F64x2Sqrt) => true
    (F64x2Add, F64x2Add) => true
    (F64x2Sub, F64x2Sub) => true
    (F64x2Mul, F64x2Mul) => true
    (F64x2Div, F64x2Div) => true
    (F64x2Min, F64x2Min) => true
    (F64x2Max, F64x2Max) => true
    (F64x2Pmin, F64x2Pmin) => true
    (F64x2Pmax, F64x2Pmax) => true
    (I32x4TruncSatF32x4S, I32x4TruncSatF32x4S) => true
    (I32x4TruncSatF32x4U, I32x4TruncSatF32x4U) => true
    (F32x4ConvertI32x4S, F32x4ConvertI32x4S) => true
    (F32x4ConvertI32x4U, F32x4ConvertI32x4U) => true
    (I32x4TruncSatF64x2SZero, I32x4TruncSatF64x2SZero) => true
    (I32x4TruncSatF64x2UZero, I32x4TruncSatF64x2UZero) => true
    (F64x2ConvertLowI32x4S, F64x2ConvertLowI32x4S) => true
    (F64x2ConvertLowI32x4U, F64x2ConvertLowI32x4U) => true
    (I8x16RelaxedSwizzle, I8x16RelaxedSwizzle) => true
    (I32x4RelaxedTruncF32x4S, I32x4RelaxedTruncF32x4S) => true
    (I32x4RelaxedTruncF32x4U, I32x4RelaxedTruncF32x4U) => true
    (I32x4RelaxedTruncZeroF64x2S, I32x4RelaxedTruncZeroF64x2S) => true
    (I32x4RelaxedTruncZeroF64x2U, I32x4RelaxedTruncZeroF64x2U) => true
    (F32x4RelaxedMadd, F32x4RelaxedMadd) => true
    (F32x4RelaxedNmadd, F32x4RelaxedNmadd) => true
    (F64x2RelaxedMadd, F64x2RelaxedMadd) => true
    (F64x2RelaxedNmadd, F64x2RelaxedNmadd) => true
    (I8x16RelaxedLaneselect, I8x16RelaxedLaneselect) => true
    (I16x8RelaxedLaneselect, I16x8RelaxedLaneselect) => true
    (I32x4RelaxedLaneselect, I32x4RelaxedLaneselect) => true
    (I64x2RelaxedLaneselect, I64x2RelaxedLaneselect) => true
    (F32x4RelaxedMin, F32x4RelaxedMin) => true
    (F32x4RelaxedMax, F32x4RelaxedMax) => true
    (F64x2RelaxedMin, F64x2RelaxedMin) => true
    (F64x2RelaxedMax, F64x2RelaxedMax) => true
    (I16x8RelaxedQ15mulrS, I16x8RelaxedQ15mulrS) => true
    (I16x8RelaxedDotI8x16I7x16S, I16x8RelaxedDotI8x16I7x16S) => true
    (I32x4RelaxedDotI8x16I7x16AddS, I32x4RelaxedDotI8x16I7x16AddS) => true
    _ => false
  }
}



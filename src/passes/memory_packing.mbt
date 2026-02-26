///| 
/// Copyright 2023 WebAssembly Community Group participants
/// 
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
/// 
///     http://www.apache.org/licenses/LICENSE-2.0
/// 
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an "AS IS" BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.
///

///|
pub(all) struct MemoryPackingPassProps {
  zero_filled_memory : Bool
  traps_never_happen : Bool
  max_data_segments : Int
} derive(Show, Eq)

///|
fn MemoryPackingPassProps::new(
  zero_filled_memory? : Bool = false,
  traps_never_happen? : Bool = false,
  max_data_segments? : Int = 100000,
) -> MemoryPackingPassProps {
  { zero_filled_memory, traps_never_happen, max_data_segments }
}

///|
const MEMORY_INIT_SIZE : Int = 10

///|
const MEMORY_FILL_SIZE : Int = 9

///|
const DATA_DROP_SIZE : Int = 3

///|
const MP_ACTIVE_ZERO_THRESHOLD : Int = 8

///|
const MP_U32_MAX : UInt64 = 0xFFFFFFFFUL

///|
const MP_U64_MAX : UInt64 = 0xFFFFFFFFFFFFFFFFUL

///|
priv struct MPRange {
  start : Int
  end : Int
  is_zero : Bool
} derive(Eq)

///|
fn MPRange::len(self : MPRange) -> Int {
  self.end - self.start
}

///|
priv struct MPModuleFeatures {
  segment_is_llvm_named : Bool
}

///|
fn MPModuleFeatures::new(
  segment_is_llvm_named? : Bool = false,
) -> MPModuleFeatures {
  { segment_is_llvm_named, }
}

///|
priv struct MPSegmentReferrers {
  memory_init_refs : Int
  data_drop_refs : Int
  gc_data_refs : Int
  passive_has_non_const_meminit : Bool
  has_any_non_drop_ref : Bool
}

///|
fn mp_empty_referrers() -> MPSegmentReferrers {
  {
    memory_init_refs: 0,
    data_drop_refs: 0,
    gc_data_refs: 0,
    passive_has_non_const_meminit: false,
    has_any_non_drop_ref: false,
  }
}

///|
priv struct MPSegmentTransform {
  transformed : Bool
  ranges : Array[MPRange]
  range_new_indices : Array[DataIdx?]
  new_single_index : DataIdx?
}

///|
fn mp_data_idx_to_int(idx : DataIdx) -> Int {
  let DataIdx(i) = idx
  i.reinterpret_as_int()
}

///|
fn mp_int_to_data_idx(idx : Int) -> DataIdx {
  DataIdx::new(idx.reinterpret_as_uint())
}

///|
fn mp_count_imported_funcs(mod : Module) -> UInt {
  let mut n : UInt = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn mp_count_imported_globals(mod : Module) -> UInt {
  let mut n : UInt = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn mp_count_imported_memories(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, MemExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn mp_collect_memory_limits(mod : Module) -> Array[Limits] {
  let out : Array[Limits] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, MemExternType(MemType(limits))) => out.push(limits)
          _ => ()
        }
      }
    None => ()
  }
  match mod.mem_sec {
    Some(MemSec(mems)) =>
      for mem in mems {
        let MemType(limits) = mem
        out.push(limits)
      }
    None => ()
  }
  out
}

///|
fn mp_is_memory64(limits : Limits) -> Bool {
  match limits {
    I64Limits(_, _) => true
    _ => false
  }
}

///|
fn mp_get_memory_limits(memories : Array[Limits], mi : MemIdx) -> Limits? {
  let MemIdx(raw) = mi
  memories.get(raw.reinterpret_as_int())
}

///|
priv enum MPConstOffset {
  I32(UInt)
  I64(UInt64)
}

///|
fn mp_const_offset_expr(expr : Expr) -> MPConstOffset? {
  match expr {
    Expr([I32Const(I32(v))]) =>
      Some(MPConstOffset::I32(v.reinterpret_as_uint()))
    Expr([I64Const(I64(v))]) =>
      Some(MPConstOffset::I64(v.reinterpret_as_uint64()))
    _ => None
  }
}

///|
fn mp_const_u64(instr : TInstr) -> UInt64? {
  match instr {
    TI32Const(I32(v)) => Some(v.reinterpret_as_uint().to_uint64())
    TI64Const(I64(v)) => Some(v.reinterpret_as_uint64())
    _ => None
  }
}

///|
fn mp_u64_add_saturating(a : UInt64, b : UInt64) -> UInt64 {
  let sum = a + b
  if sum < a {
    MP_U64_MAX
  } else {
    sum
  }
}

///|
fn saturating_add_start_offset(
  start : Int,
  base_offset_const : MPConstOffset,
) -> MPConstOffset {
  let add = if start <= 0 {
    0UL
  } else {
    start.reinterpret_as_uint().to_uint64()
  }
  match base_offset_const {
    MPConstOffset::I32(base) => {
      let sum = mp_u64_add_saturating(base.to_uint64(), add)
      if sum > MP_U32_MAX {
        MPConstOffset::I32(0xFFFFFFFFU)
      } else {
        MPConstOffset::I32(sum.to_uint())
      }
    }
    MPConstOffset::I64(base) =>
      MPConstOffset::I64(mp_u64_add_saturating(base, add))
  }
}

///|
fn mp_offset_const_to_expr(offset : MPConstOffset) -> Expr {
  match offset {
    MPConstOffset::I32(v) =>
      TExpr::new([TInstr::i32_const(I32(v.reinterpret_as_int()))]).to_expr()
    MPConstOffset::I64(v) =>
      TExpr::new([TInstr::i64_const(I64(v.reinterpret_as_int64()))]).to_expr()
  }
}

///|
fn mp_ptr_const_for_limits(limits : Limits, val : UInt64) -> TInstr {
  if mp_is_memory64(limits) {
    TInstr::i64_const(I64(val.reinterpret_as_int64()))
  } else {
    let v = if val > MP_U32_MAX { MP_U32_MAX } else { val }
    TInstr::i32_const(I32(v.to_uint().reinterpret_as_int()))
  }
}

///|
fn mp_ptr_add_for_limits(
  limits : Limits,
  base : TInstr,
  delta : UInt64,
) -> TInstr {
  if delta == 0UL {
    return base
  }
  if mp_is_memory64(limits) {
    TInstr::binary(
      BinaryOp::i64_add(),
      base,
      TInstr::i64_const(I64(delta.reinterpret_as_int64())),
    )
  } else {
    let d = if delta > MP_U32_MAX { MP_U32_MAX } else { delta }
    TInstr::binary(
      BinaryOp::i32_add(),
      base,
      TInstr::i32_const(I32(d.to_uint().reinterpret_as_int())),
    )
  }
}

///|
fn mp_compute_ranges(bytes : Bytes) -> Array[MPRange] {
  let ranges : Array[MPRange] = []
  let n = bytes.length()
  if n == 0 {
    return ranges
  }
  let mut start = 0
  let mut is_zero = bytes[0] == b'\x00'
  for i in 1..<n {
    let zero = bytes[i] == b'\x00'
    if zero != is_zero {
      ranges.push({ start, end: i, is_zero })
      start = i
      is_zero = zero
    }
  }
  ranges.push({ start, end: n, is_zero })
  ranges
}

///|
fn mp_merge_left_edge_zero(
  ranges : Array[MPRange],
  edge_threshold : Int,
) -> Array[MPRange] {
  if ranges.length() < 2 {
    return ranges
  }
  if !(ranges[0].is_zero && ranges[0].len() <= edge_threshold) {
    return ranges
  }
  let out : Array[MPRange] = []
  out.push({ start: ranges[0].start, end: ranges[1].end, is_zero: false })
  for i in 2..<ranges.length() {
    out.push(ranges[i])
  }
  out
}

///|
fn mp_merge_right_edge_zero(
  ranges : Array[MPRange],
  edge_threshold : Int,
) -> Array[MPRange] {
  if ranges.length() < 2 {
    return ranges
  }
  let last = ranges.length() - 1
  if !(ranges[last].is_zero && ranges[last].len() <= edge_threshold) {
    return ranges
  }
  let out : Array[MPRange] = []
  for i in 0..<(last - 1) {
    out.push(ranges[i])
  }
  out.push({
    start: ranges[last - 1].start,
    end: ranges[last].end,
    is_zero: false,
  })
  out
}

///|
fn mp_merge_small_interior_zeros(
  ranges : Array[MPRange],
  threshold : Int,
) -> Array[MPRange] {
  if ranges.length() < 3 {
    return ranges
  }
  for i in 1..<(ranges.length() - 1) {
    let curr = ranges[i]
    if !(curr.is_zero && curr.len() <= threshold) {
      continue
    }
    let left = ranges[i - 1]
    let right = ranges[i + 1]
    if left.is_zero || right.is_zero {
      continue
    }
    let out : Array[MPRange] = []
    for j in 0..<(i - 1) {
      out.push(ranges[j])
    }
    out.push({ start: left.start, end: right.end, is_zero: false })
    for j in (i + 2)..<ranges.length() {
      out.push(ranges[j])
    }
    return out
  }
  ranges
}

///|
fn mp_merge_small_zeros_passive(
  ranges : Array[MPRange],
  refs : MPSegmentReferrers,
) -> Array[MPRange] {
  let mut threshold = 2
  let mut edge_threshold = 0
  for _ in 0..<refs.memory_init_refs {
    threshold += MEMORY_FILL_SIZE + MEMORY_INIT_SIZE
    edge_threshold += MEMORY_FILL_SIZE
  }
  for _ in 0..<refs.data_drop_refs {
    threshold += DATA_DROP_SIZE
  }
  let mut current = ranges
  while true {
    let before = current
    current = mp_merge_left_edge_zero(current, edge_threshold)
    current = mp_merge_right_edge_zero(current, edge_threshold)
    current = mp_merge_small_interior_zeros(current, threshold)
    if current == before {
      break
    }
  }
  current
}

///|
fn mp_merge_small_zeros_active(ranges : Array[MPRange]) -> Array[MPRange] {
  let mut current = ranges
  while true {
    let before = current
    current = mp_merge_small_interior_zeros(current, MP_ACTIVE_ZERO_THRESHOLD)
    if current == before {
      break
    }
  }
  current
}

///|
fn mp_initial_memory_bytes(limits : Limits) -> UInt64 {
  let pages = match limits {
    I32Limits(min, _) => min.to_uint64()
    I64Limits(min, _) => min
  }
  if pages == 0UL {
    return 0UL
  }
  let shifted = pages << 16
  if shifted >> 16 != pages {
    MP_U64_MAX
  } else {
    shifted
  }
}

///|
fn mp_active_startup_may_trap(
  offset : MPConstOffset,
  size : Int,
  limits : Limits,
) -> Bool {
  let base = match offset {
    MPConstOffset::I32(v) => v.to_uint64()
    MPConstOffset::I64(v) => v
  }
  let size_u64 = if size <= 0 {
    0UL
  } else {
    size.reinterpret_as_uint().to_uint64()
  }
  let end = mp_u64_add_saturating(base, size_u64)
  let mem_bytes = mp_initial_memory_bytes(limits)
  end > mem_bytes
}

///|
fn mp_has_trailing_zero_range(ranges : Array[MPRange]) -> Bool {
  if ranges.is_empty() {
    false
  } else {
    ranges[ranges.length() - 1].is_zero
  }
}

///|
fn mp_preserve_active_trap_byte(ranges : Array[MPRange]) -> Array[MPRange] {
  if ranges.is_empty() {
    return ranges
  }
  let last = ranges.length() - 1
  if !ranges[last].is_zero || ranges[last].len() <= 0 {
    return ranges
  }
  let shrunk = {
    start: ranges[last].start,
    end: ranges[last].end - 1,
    is_zero: true,
  }
  let one = {
    start: ranges[last].end - 1,
    end: ranges[last].end,
    is_zero: false,
  }
  let out : Array[MPRange] = []
  for i in 0..<last {
    out.push(ranges[i])
  }
  if shrunk.len() > 0 {
    out.push(shrunk)
  }
  out.push(one)
  out
}

///|
fn calculate_ranges(
  mod : Module,
  segment : Data,
  referrers : MPSegmentReferrers,
  options : MemoryPackingPassProps,
) -> Array[MPRange] {
  let Data(mode, bytes) = segment
  let mut ranges = mp_compute_ranges(bytes)
  ranges = match mode {
    Passive => mp_merge_small_zeros_passive(ranges, referrers)
    Active(_, _) => mp_merge_small_zeros_active(ranges)
  }
  match mode {
    Active(mem_idx, offset_expr) =>
      if !options.traps_never_happen {
        match mp_const_offset_expr(offset_expr) {
          Some(offset_const) =>
            match mp_get_memory_limits(mp_collect_memory_limits(mod), mem_idx) {
              Some(limits) =>
                if mp_active_startup_may_trap(
                    offset_const,
                    bytes.length(),
                    limits,
                  ) &&
                  mp_has_trailing_zero_range(ranges) {
                  ranges = mp_preserve_active_trap_byte(ranges)
                }
              None => ()
            }
          None => ()
        }
      }
    _ => ()
  }
  ranges
}

///|
fn mp_segment_is_unsplit_identity(ranges : Array[MPRange], len : Int) -> Bool {
  match ranges {
    [{ start: 0, end: end_, is_zero: false }] => end_ == len
    _ => false
  }
}

///|
fn mp_count_non_zero_ranges(ranges : Array[MPRange]) -> Int {
  let mut n = 0
  for range in ranges {
    if !range.is_zero && range.len() > 0 {
      n += 1
    }
  }
  n
}

///|
fn mp_last_non_zero_range_idx(ranges : Array[MPRange]) -> Int {
  let mut idx = -1
  for i in 0..<ranges.length() {
    if !ranges[i].is_zero && ranges[i].len() > 0 {
      idx = i
    }
  }
  idx
}

///|
fn mp_reduce_ranges_to_capacity(
  ranges : Array[MPRange],
  capacity : Int,
) -> Array[MPRange] {
  let non_zero = mp_count_non_zero_ranges(ranges)
  if non_zero <= capacity {
    return ranges
  }
  let last_non_zero = mp_last_non_zero_range_idx(ranges)
  if last_non_zero < 0 {
    return ranges
  }
  if capacity <= 0 {
    return [
      { start: ranges[0].start, end: ranges[last_non_zero].end, is_zero: false },
    ]
  }
  let out : Array[MPRange] = []
  let mut seen_non_zero = 0
  let mut i = 0
  while i < ranges.length() {
    let r = ranges[i]
    if !r.is_zero && r.len() > 0 {
      if seen_non_zero == capacity - 1 {
        out.push({
          start: r.start,
          end: ranges[last_non_zero].end,
          is_zero: false,
        })
        break
      }
      out.push(r)
      seen_non_zero += 1
      i += 1
      continue
    }
    out.push(r)
    i += 1
  }
  while !out.is_empty() && out[out.length() - 1].is_zero {
    ignore(out.pop())
  }
  out
}

///|
fn can_split_segment(
  segment : Data,
  referrers : MPSegmentReferrers,
  module_features : MPModuleFeatures,
) -> Bool {
  let Data(mode, bytes) = segment
  if bytes.length() == 0 {
    return false
  }
  if referrers.gc_data_refs > 0 {
    return false
  }
  // Data segment names are not modeled in core IR; keep this flag plumbed
  // so callers can gate specific segments from split decisions.
  if module_features.segment_is_llvm_named {
    return false
  }
  match mode {
    Active(_, expr) => mp_const_offset_expr(expr) is Some(_)
    Passive => !referrers.passive_has_non_const_meminit
  }
}

///|
fn mp_ranges_to_non_zero_segments(
  segment : Data,
  ranges : Array[MPRange],
) -> Array[Data] {
  let Data(mode, bytes) = segment
  let out : Array[Data] = []
  match mode {
    Passive =>
      for range in ranges {
        if range.is_zero || range.len() <= 0 {
          continue
        }
        out.push(
          Data::new(
            DataMode::passive(),
            bytes[range.start:range.end].to_bytes(),
          ),
        )
      }
    Active(mem_idx, offset_expr) =>
      match mp_const_offset_expr(offset_expr) {
        Some(base_const) =>
          for range in ranges {
            if range.is_zero || range.len() <= 0 {
              continue
            }
            let offset = saturating_add_start_offset(range.start, base_const)
            out.push(
              Data::new(
                DataMode::active(mem_idx, mp_offset_const_to_expr(offset)),
                bytes[range.start:range.end].to_bytes(),
              ),
            )
          }
        None =>
          // Non-constant active offsets are not split in this pass.
          out.push(segment)
      }
  }
  out
}

///|
fn create_split_segments(
  segment : Data,
  ranges : Array[MPRange],
  limits : Int,
) -> Array[Data] {
  let capped = mp_reduce_ranges_to_capacity(ranges, limits)
  mp_ranges_to_non_zero_segments(segment, capped)
}

///|
fn make_gt_shifted_memory_size(
  mem : MemIdx,
  dest : TInstr,
  limits : Limits,
) -> TInstr {
  if mp_is_memory64(limits) {
    TInstr::binary(
      BinaryOp::i64_gt_u(),
      dest,
      TInstr::binary(
        BinaryOp::i64_shl(),
        TInstr::memory_size(mem),
        TInstr::i64_const(I64(16L)),
      ),
    )
  } else {
    TInstr::binary(
      BinaryOp::i32_gt_u(),
      dest,
      TInstr::binary(
        BinaryOp::i32_shl(),
        TInstr::memory_size(mem),
        TInstr::i32_const(I32(16)),
      ),
    )
  }
}

///|
fn emit_memory_fill(mem : MemIdx, dest : TInstr, len : TInstr) -> TInstr {
  TInstr::memory_fill(mem, dest, TInstr::i32_const(I32(0)), len)
}

///|
fn emit_memory_init(
  data_idx : DataIdx,
  mem : MemIdx,
  dest : TInstr,
  offset : TInstr,
  len : TInstr,
) -> TInstr {
  TInstr::memory_init(data_idx, mem, dest, offset, len)
}

///|
fn emit_data_drop(data_idx : DataIdx) -> TInstr {
  TInstr::data_drop(data_idx)
}

///|
fn ensure_drop_state_global(mod : Module) -> (Module, GlobalIdx) {
  let imported_globals = mp_count_imported_globals(mod)
  let existing_defined = match mod.global_sec {
    Some(GlobalSec(globals)) => globals.length().reinterpret_as_uint()
    None => 0U
  }
  let idx = GlobalIdx::new(imported_globals + existing_defined)
  let globals = match mod.global_sec {
    Some(GlobalSec(gs)) => gs.copy()
    None => []
  }
  globals.push(
    Global::new(
      GlobalType::new(ValType::i32(), true),
      TExpr::new([TInstr::i32_const(I32(0))]).to_expr(),
    ),
  )
  (mod.with_global_sec(GlobalSec::new(globals)), idx)
}

///|
fn collect_segment_referrers(mod : Module) -> Map[Int, MPSegmentReferrers] {
  let out : Map[Int, MPSegmentReferrers] = Map::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    fn update_ref(
      out : Map[Int, MPSegmentReferrers],
      idx : Int,
      f : (MPSegmentReferrers) -> MPSegmentReferrers,
    ) -> Unit {
      let curr = out.get(idx).unwrap_or(mp_empty_referrers())
      out[idx] = f(curr)
    }

    match instr {
      TMemoryInit(di, _, _, src, len) => {
        let idx = mp_data_idx_to_int(di)
        update_ref(out, idx, fn(r) {
          {
            memory_init_refs: r.memory_init_refs + 1,
            data_drop_refs: r.data_drop_refs,
            gc_data_refs: r.gc_data_refs,
            passive_has_non_const_meminit: r.passive_has_non_const_meminit ||
            !(mp_const_u64(src) is Some(_)) ||
            !(mp_const_u64(len) is Some(_)),
            has_any_non_drop_ref: true,
          }
        })
      }
      TDataDrop(di) => {
        let idx = mp_data_idx_to_int(di)
        update_ref(out, idx, fn(r) {
          {
            memory_init_refs: r.memory_init_refs,
            data_drop_refs: r.data_drop_refs + 1,
            gc_data_refs: r.gc_data_refs,
            passive_has_non_const_meminit: r.passive_has_non_const_meminit,
            has_any_non_drop_ref: r.has_any_non_drop_ref,
          }
        })
      }
      TArrayNewData(_, di, _, _) | TArrayInitData(_, di, _, _, _, _) => {
        let idx = mp_data_idx_to_int(di)
        update_ref(out, idx, fn(r) {
          {
            memory_init_refs: r.memory_init_refs,
            data_drop_refs: r.data_drop_refs,
            gc_data_refs: r.gc_data_refs + 1,
            passive_has_non_const_meminit: r.passive_has_non_const_meminit,
            has_any_non_drop_ref: true,
          }
        })
      }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_module((), mod))
  out
}

///|
fn drop_unused_segments(
  mod : Module,
  referrers : Map[Int, MPSegmentReferrers],
) -> Set[Int] {
  let removed : Set[Int] = Set::new()
  match mod.data_sec {
    Some(DataSec(datas)) =>
      for i in 0..<datas.length() {
        let refs = referrers.get(i).unwrap_or(mp_empty_referrers())
        match datas[i] {
          Data(Passive, _) => if !refs.has_any_non_drop_ref { removed.add(i) }
          _ => ()
        }
      }
    None => ()
  }
  removed
}

///|
fn mp_active_segment_indices(mod : Module) -> Set[Int] {
  let out : Set[Int] = Set::new()
  match mod.data_sec {
    Some(DataSec(datas)) =>
      for i in 0..<datas.length() {
        match datas[i] {
          Data(Active(_, _), _) => out.add(i)
          _ => ()
        }
      }
    None => ()
  }
  out
}

///|
fn mp_referrers_have_memory_init(
  referrers : Map[Int, MPSegmentReferrers],
) -> Bool {
  for idx in referrers.keys() {
    let refs = referrers.get(idx).unwrap_or(mp_empty_referrers())
    if refs.memory_init_refs > 0 {
      return true
    }
  }
  false
}

///|
fn mp_active_segments_have_data_drop_refs(
  active : Set[Int],
  referrers : Map[Int, MPSegmentReferrers],
) -> Bool {
  for idx in active {
    let refs = referrers.get(idx).unwrap_or(mp_empty_referrers())
    if refs.data_drop_refs > 0 {
      return true
    }
  }
  false
}

///|
fn mp_has_segment_ops_candidates(
  active : Set[Int],
  referrers : Map[Int, MPSegmentReferrers],
) -> Bool {
  mp_referrers_have_memory_init(referrers) ||
  mp_active_segments_have_data_drop_refs(active, referrers)
}

///|
fn mp_drop_and_unreachable(dest : TInstr, src : TInstr, len : TInstr) -> TInstr {
  TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::drop(dest),
      TInstr::drop(src),
      TInstr::drop(len),
      TInstr::unreachable_(),
    ]),
  )
}

///|
fn optimize_segment_ops(
  mod : Module,
  active : Set[Int],
  referrers : Map[Int, MPSegmentReferrers],
  memories : Array[Limits],
  data_segments : Array[Data],
) -> (Module, Bool) {
  let rewriter = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    instr,
  ) {
    let walked = match self.walk_tinstruction_default((), instr) {
      Ok(Some((_, out))) => out
      Ok(None) => instr
      Err(e) => return Err(e)
    }
    match walked {
      TDataDrop(di) =>
        if active.contains(mp_data_idx_to_int(di)) {
          change((), TInstr::nop())
        } else {
          unchanged()
        }
      TMemoryInit(di, mi, dest, src, len) => {
        let idx = mp_data_idx_to_int(di)
        if idx < 0 || idx >= data_segments.length() {
          return unchanged()
        }
        let seg_len = match data_segments[idx] {
          Data(_, bytes) => bytes.length()
        }
        match (mp_const_u64(src), mp_const_u64(len)) {
          (Some(src_u), Some(len_u)) => {
            let seg_len_u = seg_len.reinterpret_as_uint().to_uint64()
            let must_trap = src_u > seg_len_u ||
              len_u > seg_len_u ||
              src_u + len_u < src_u ||
              src_u + len_u > seg_len_u
            if must_trap {
              change((), mp_drop_and_unreachable(dest, src, len))
            } else if active.contains(idx) {
              let mem_limits = match mp_get_memory_limits(memories, mi) {
                Some(l) => l
                None => Limits::i32(0, None)
              }
              // Active segment refs are lowered to an explicit trap predicate.
              let src_non_zero = if src_u == 0UL {
                TInstr::i32_const(I32(0))
              } else {
                TInstr::i32_const(I32(1))
              }
              let len_non_zero = if len_u == 0UL {
                TInstr::i32_const(I32(0))
              } else {
                TInstr::i32_const(I32(1))
              }
              let cond = TInstr::binary(
                BinaryOp::i32_or(),
                make_gt_shifted_memory_size(mi, dest, mem_limits),
                TInstr::binary(BinaryOp::i32_or(), src_non_zero, len_non_zero),
              )
              change(
                (),
                TInstr::if_(
                  BlockType::void_(),
                  cond,
                  TExpr::new([TInstr::unreachable_()]),
                  None,
                ),
              )
            } else if len_u == 0UL {
              let refs = referrers.get(idx).unwrap_or(mp_empty_referrers())
              if refs.data_drop_refs > 0 {
                return unchanged()
              }
              let mem_limits = match mp_get_memory_limits(memories, mi) {
                Some(l) => l
                None => Limits::i32(0, None)
              }
              change(
                (),
                TInstr::if_(
                  BlockType::void_(),
                  make_gt_shifted_memory_size(mi, dest, mem_limits),
                  TExpr::new([TInstr::unreachable_()]),
                  None,
                ),
              )
            } else {
              unchanged()
            }
          }
          _ => unchanged()
        }
      }
      _ => unchanged()
    }
  })
  match rewriter.walk_module((), mod) {
    Ok(Some((_, out))) => (out, true)
    _ => (mod, false)
  }
}

///|
fn mp_collect_active_constant_spans(
  mod : Module,
) -> (Bool, Array[(UInt64, UInt64)]) {
  let spans : Array[(UInt64, UInt64)] = []
  match mod.data_sec {
    Some(DataSec(datas)) =>
      for data in datas {
        match data {
          Data(Active(_, offset_expr), bytes) =>
            match mp_const_offset_expr(offset_expr) {
              Some(offset) => {
                let start = match offset {
                  MPConstOffset::I32(v) => v.to_uint64()
                  MPConstOffset::I64(v) => v
                }
                let end = mp_u64_add_saturating(
                  start,
                  bytes.length().reinterpret_as_uint().to_uint64(),
                )
                spans.push((start, end))
              }
              None => return (false, [])
            }
          _ => ()
        }
      }
    None => ()
  }
  (true, spans)
}

///|
fn can_optimize(mod : Module, options : MemoryPackingPassProps) -> Bool {
  let memories = mp_collect_memory_limits(mod)
  if memories.length() == 0 || memories.length() > 1 {
    return false
  }
  let imported_mems = mp_count_imported_memories(mod)
  if imported_mems == 1 && !options.zero_filled_memory {
    return false
  }
  let data_len = match mod.data_sec {
    Some(DataSec(datas)) => datas.length()
    None => 0
  }
  if data_len > 1 {
    let (all_const, _) = mp_collect_active_constant_spans(mod)
    if !all_const {
      return false
    }
  }
  let (_, spans) = mp_collect_active_constant_spans(mod)
  for i in 0..<spans.length() {
    let (s0, e0) = spans[i]
    if e0 <= s0 {
      continue
    }
    for j in (i + 1)..<spans.length() {
      let (s1, e1) = spans[j]
      if e1 <= s1 {
        continue
      }
      if s0 < e1 && s1 < e0 {
        return false
      }
    }
  }
  true
}

///|
fn mp_transformed_intersections_start_zero(
  transform : MPSegmentTransform,
  src : UInt64,
  size : UInt64,
) -> Bool {
  if transform.ranges.is_empty() || size == 0UL {
    return false
  }
  let end = src + size
  let mut first_seen = false
  let mut first_is_zero = false
  for range in transform.ranges {
    let rs = range.start.reinterpret_as_uint().to_uint64()
    let re = range.end.reinterpret_as_uint().to_uint64()
    let isect_start = if rs > src { rs } else { src }
    let isect_end = if re < end { re } else { end }
    if isect_end > isect_start {
      first_seen = true
      first_is_zero = range.is_zero
      break
    }
  }
  first_seen && first_is_zero
}

///|
fn mp_segment_has_zero_range(transform : MPSegmentTransform) -> Bool {
  for range in transform.ranges {
    if range.is_zero && range.len() > 0 {
      return true
    }
  }
  false
}

///|
fn mp_needs_drop_state_global(
  mod : Module,
  transforms : Map[Int, MPSegmentTransform],
) -> Bool {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    state,
    instr,
  ) {
    let mut needed = state
    match instr {
      TMemoryInit(di, _, _, src, len) => {
        let idx = mp_data_idx_to_int(di)
        match transforms.get(idx) {
          Some(transform) if transform.transformed =>
            match (mp_const_u64(src), mp_const_u64(len)) {
              (Some(src_u), Some(len_u)) =>
                if len_u == 0UL ||
                  mp_transformed_intersections_start_zero(
                    transform, src_u, len_u,
                  ) {
                  needed = true
                }
              _ => if mp_segment_has_zero_range(transform) { needed = true }
            }
          _ => ()
        }
      }
      _ => ()
    }
    if needed {
      Ok(Some((true, instr)))
    } else {
      self.walk_tinstruction_default(false, instr)
    }
  })
  match walker.walk_module(false, mod) {
    Ok(Some((needed, _))) => needed
    Ok(None) => false
    Err(_) => false
  }
}

///|
priv struct MPReplacementPlan {
  transforms : Map[Int, MPSegmentTransform]
  removed_passive : Set[Int]
  drop_state_global : GlobalIdx?
  memory_limits : Array[Limits]
}

///|
fn create_replacements(
  mod : Module,
  transforms : Map[Int, MPSegmentTransform],
  removed_passive : Set[Int],
) -> (Module, MPReplacementPlan) {
  let needs_drop = mp_needs_drop_state_global(mod, transforms)
  let (mod, drop_state_global) = if needs_drop {
    let (m, idx) = ensure_drop_state_global(mod)
    (m, Some(idx))
  } else {
    (mod, None)
  }
  (
    mod,
    {
      transforms,
      removed_passive,
      drop_state_global,
      memory_limits: mp_collect_memory_limits(mod),
    },
  )
}

///|
priv struct MPRewriteFuncState {
  mut next_local : Int
  new_locals : Array[ValType]
}

///|
fn mp_alloc_local(state : MPRewriteFuncState, ty : ValType) -> LocalIdx {
  let idx = state.next_local
  state.next_local += 1
  state.new_locals.push(ty)
  LocalIdx::new(idx.reinterpret_as_uint())
}

///|
fn mp_range_dest_offset(range_start : UInt64, src_start : UInt64) -> UInt64 {
  if range_start <= src_start {
    0UL
  } else {
    range_start - src_start
  }
}

///|
fn mp_build_drop_check(
  mem : MemIdx,
  dest : TInstr,
  limits : Limits,
  drop_state_global : GlobalIdx?,
) -> TInstr {
  let mem_oob = make_gt_shifted_memory_size(mem, dest, limits)
  match drop_state_global {
    Some(drop_idx) =>
      TInstr::binary(
        BinaryOp::i32_or(),
        mem_oob,
        TInstr::binary(
          BinaryOp::i32_ne(),
          TInstr::global_get(drop_idx),
          TInstr::i32_const(I32(0)),
        ),
      )
    None => mem_oob
  }
}

///|
fn mp_build_memory_init_replacement(
  state : MPRewriteFuncState,
  plan : MPReplacementPlan,
  transform : MPSegmentTransform,
  old_di : DataIdx,
  mem : MemIdx,
  dest : TInstr,
  src : TInstr,
  len : TInstr,
) -> TInstr? {
  let src_u = match mp_const_u64(src) {
    Some(v) => v
    None => return None
  }
  let len_u = match mp_const_u64(len) {
    Some(v) => v
    None => return None
  }
  let limits = match mp_get_memory_limits(plan.memory_limits, mem) {
    Some(l) => l
    None => Limits::i32(0, None)
  }
  let seq : Array[TInstr] = []
  let mut base_dest = dest
  if !(mp_const_u64(dest) is Some(_)) {
    let temp = mp_alloc_local(state, limits.addr_valtype())
    seq.push(TInstr::local_set(temp, dest))
    base_dest = TInstr::local_get(temp)
  }
  if len_u == 0UL {
    let cond = mp_build_drop_check(
      mem,
      base_dest,
      limits,
      plan.drop_state_global,
    )
    seq.push(
      TInstr::if_(
        BlockType::void_(),
        cond,
        TExpr::new([TInstr::unreachable_()]),
        None,
      ),
    )
    return Some(TInstr::block(BlockType::void_(), TExpr::new(seq)))
  }
  let src_end = src_u + len_u
  let mut first_emitted = false
  for i in 0..<transform.ranges.length() {
    let range = transform.ranges[i]
    let rs = range.start.reinterpret_as_uint().to_uint64()
    let re = range.end.reinterpret_as_uint().to_uint64()
    let isect_start = if rs > src_u { rs } else { src_u }
    let isect_end = if re < src_end { re } else { src_end }
    if isect_end <= isect_start {
      continue
    }
    let chunk_len = isect_end - isect_start
    let written = mp_range_dest_offset(isect_start, src_u)
    let chunk_dest = mp_ptr_add_for_limits(limits, base_dest, written)
    if range.is_zero {
      if !first_emitted {
        match plan.drop_state_global {
          Some(drop_idx) =>
            seq.push(
              TInstr::if_(
                BlockType::void_(),
                TInstr::binary(
                  BinaryOp::i32_ne(),
                  TInstr::global_get(drop_idx),
                  TInstr::i32_const(I32(0)),
                ),
                TExpr::new([TInstr::unreachable_()]),
                None,
              ),
            )
          None => ()
        }
      }
      seq.push(
        emit_memory_fill(
          mem,
          chunk_dest,
          mp_ptr_const_for_limits(limits, chunk_len),
        ),
      )
    } else {
      let new_idx = match transform.range_new_indices[i] {
        Some(di) => di
        None => old_di
      }
      let offset_inside_split = isect_start - rs
      seq.push(
        emit_memory_init(
          new_idx,
          mem,
          chunk_dest,
          mp_ptr_const_for_limits(limits, offset_inside_split),
          mp_ptr_const_for_limits(limits, chunk_len),
        ),
      )
    }
    first_emitted = true
  }
  if seq.is_empty() {
    Some(TInstr::nop())
  } else if seq.length() == 1 {
    Some(seq[0])
  } else {
    Some(TInstr::block(BlockType::void_(), TExpr::new(seq)))
  }
}

///|
fn apply_replacements(
  mod : Module,
  plan : MPReplacementPlan,
) -> Result[Module, String] {
  let mut mod = mod
  let imported_funcs = mp_count_imported_funcs(mod)
  let env = Env::new().with_module(mod)
  match mod.code_sec {
    Some(CodeSec(funcs)) => {
      let new_funcs : Array[Func] = []
      for i in 0..<funcs.length() {
        let abs_idx = imported_funcs + i.reinterpret_as_uint()
        let param_count = match
          env.get_functype_by_funcidx(FuncIdx::new(abs_idx)) {
          Some(FuncType(params, _)) => params.length()
          None => 0
        }
        match funcs[i] {
          TFunc(locals, body) => {
            let init_state = {
              next_local: param_count + locals.length(),
              new_locals: [],
            }
            let rewriter = ModuleTransformer::new().on_tinstruction_evt(fn(
              self,
              state : MPRewriteFuncState,
              instr : TInstr,
            ) {
              let walked = match self.walk_tinstruction_default(state, instr) {
                Ok(Some((s, out))) => (s, out)
                Ok(None) => (state, instr)
                Err(e) => return Err(e)
              }
              let (state, curr) = walked
              match curr {
                TDataDrop(di) => {
                  let idx = mp_data_idx_to_int(di)
                  if plan.removed_passive.contains(idx) {
                    return change(state, TInstr::nop())
                  }
                  match plan.transforms.get(idx) {
                    Some(transform) if transform.transformed => {
                      let seq : Array[TInstr] = []
                      match plan.drop_state_global {
                        Some(drop_idx) =>
                          seq.push(
                            TInstr::global_set(
                              drop_idx,
                              TInstr::i32_const(I32(1)),
                            ),
                          )
                        None => ()
                      }
                      for maybe_idx in transform.range_new_indices {
                        match maybe_idx {
                          Some(new_idx) => seq.push(emit_data_drop(new_idx))
                          None => ()
                        }
                      }
                      if seq.is_empty() {
                        change(state, TInstr::nop())
                      } else if seq.length() == 1 {
                        change(state, seq[0])
                      } else {
                        change(
                          state,
                          TInstr::block(BlockType::void_(), TExpr::new(seq)),
                        )
                      }
                    }
                    Some(transform) =>
                      match transform.new_single_index {
                        Some(new_idx) if new_idx != di =>
                          change(state, TInstr::data_drop(new_idx))
                        _ => unchanged()
                      }
                    None => unchanged()
                  }
                }
                TMemoryInit(di, mi, dest, src, len) => {
                  let idx = mp_data_idx_to_int(di)
                  if plan.removed_passive.contains(idx) {
                    return change(state, TInstr::nop())
                  }
                  match plan.transforms.get(idx) {
                    Some(transform) if transform.transformed =>
                      match
                        mp_build_memory_init_replacement(
                          state, plan, transform, di, mi, dest, src, len,
                        ) {
                        Some(repl) => change(state, repl)
                        None => unchanged()
                      }
                    Some(transform) =>
                      match transform.new_single_index {
                        Some(new_idx) if new_idx != di =>
                          change(
                            state,
                            TInstr::memory_init(new_idx, mi, dest, src, len),
                          )
                        _ => unchanged()
                      }
                    None => unchanged()
                  }
                }
                TArrayNewData(ti, di, off, len) => {
                  let idx = mp_data_idx_to_int(di)
                  if plan.removed_passive.contains(idx) {
                    return unchanged()
                  }
                  match plan.transforms.get(idx) {
                    Some(transform) =>
                      match transform.new_single_index {
                        Some(new_idx) if new_idx != di =>
                          change(
                            state,
                            TInstr::array_new_data(ti, new_idx, off, len),
                          )
                        _ => unchanged()
                      }
                    None => unchanged()
                  }
                }
                TArrayInitData(ti, di, d, o, s, sz) => {
                  let idx = mp_data_idx_to_int(di)
                  if plan.removed_passive.contains(idx) {
                    return unchanged()
                  }
                  match plan.transforms.get(idx) {
                    Some(transform) =>
                      match transform.new_single_index {
                        Some(new_idx) if new_idx != di =>
                          change(
                            state,
                            TInstr::array_init_data(ti, new_idx, d, o, s, sz),
                          )
                        _ => unchanged()
                      }
                    None => unchanged()
                  }
                }
                _ => unchanged()
              }
            })
            let (final_state, new_body) = match
              rewriter.walk_texpr(init_state, body) {
              Ok(Some((s, rewritten))) => (s, rewritten)
              Ok(None) => (init_state, body)
              Err(e) => return Err(e)
            }
            let new_locals = locals.copy()
            for local_ty in final_state.new_locals {
              new_locals.push(local_ty)
            }
            new_funcs.push(Func::t_func(new_locals, new_body))
          }
          _ => new_funcs.push(funcs[i])
        }
      }
      mod = mod.with_code_sec(CodeSec::new(new_funcs))
    }
    None => ()
  }
  Ok(mod)
}

///|
fn mp_build_transforms_and_segments(
  mod : Module,
  referrers : Map[Int, MPSegmentReferrers],
  removed_passive : Set[Int],
  options : MemoryPackingPassProps,
) -> (Module, Map[Int, MPSegmentTransform]) {
  let mut mod = mod
  let datas = match mod.data_sec {
    Some(DataSec(ds)) => ds
    None => return (mod, Map::new())
  }
  let new_datas : Array[Data] = []
  let transforms : Map[Int, MPSegmentTransform] = Map::new()
  let features = MPModuleFeatures::new()
  for old_idx in 0..<datas.length() {
    let segment = datas[old_idx]
    if removed_passive.contains(old_idx) {
      transforms[old_idx] = {
        transformed: false,
        ranges: [],
        range_new_indices: [],
        new_single_index: None,
      }
      continue
    }
    let refs = referrers.get(old_idx).unwrap_or(mp_empty_referrers())
    let Data(_, bytes) = segment
    let can_split = can_split_segment(segment, refs, features)
    let base_identity = [{ start: 0, end: bytes.length(), is_zero: false }]
    let mut ranges = if can_split {
      calculate_ranges(mod, segment, refs, options)
    } else {
      base_identity
    }
    let remaining_capacity = options.max_data_segments - new_datas.length()
    ranges = mp_reduce_ranges_to_capacity(ranges, remaining_capacity)
    let transformed = can_split &&
      !mp_segment_is_unsplit_identity(ranges, bytes.length())
    if !transformed {
      let new_idx = mp_int_to_data_idx(new_datas.length())
      new_datas.push(segment)
      transforms[old_idx] = {
        transformed: false,
        ranges: base_identity,
        range_new_indices: [Some(new_idx)],
        new_single_index: Some(new_idx),
      }
      continue
    }
    let split_segments = create_split_segments(
      segment,
      ranges,
      options.max_data_segments - new_datas.length(),
    )
    let range_new_indices : Array[DataIdx?] = Array::make(ranges.length(), None)
    let mut split_cursor = 0
    for i in 0..<ranges.length() {
      let range = ranges[i]
      if range.is_zero || range.len() <= 0 {
        continue
      }
      if split_cursor < split_segments.length() {
        let new_idx = mp_int_to_data_idx(new_datas.length())
        range_new_indices[i] = Some(new_idx)
        new_datas.push(split_segments[split_cursor])
        split_cursor += 1
      }
    }
    transforms[old_idx] = {
      transformed: true,
      ranges,
      range_new_indices,
      new_single_index: None,
    }
  }
  mod = mod.with_data_sec(DataSec::new(new_datas))
  match mod.data_cnt_sec {
    Some(_) =>
      mod = mod.with_data_cnt_sec(
        DataCntSec::new(U32(new_datas.length().reinterpret_as_uint())),
      )
    None => ()
  }
  (mod, transforms)
}

///|
fn run_memory_packing_on_module(
  mod : Module,
  options : MemoryPackingPassProps,
  trace? : (String) -> Unit = fn(_) { () },
) -> Result[Module, String] {
  let mut mod = mod
  let data_count = match mod.data_sec {
    Some(DataSec(datas)) => datas.length()
    None => 0
  }
  trace(
    "start data_segments=\{data_count} zero_filled_memory=\{options.zero_filled_memory} traps_never_happen=\{options.traps_never_happen} max_data_segments=\{options.max_data_segments}",
  )
  if !can_optimize(mod, options) {
    trace("skip:cannot_optimize")
    return Ok(mod)
  }
  trace("collect_segment_referrers:start")
  let mut referrers = collect_segment_referrers(mod)
  trace("collect_segment_referrers:done refs=\{referrers.length()}")
  let active = mp_active_segment_indices(mod)
  let memories = mp_collect_memory_limits(mod)
  let data_segments = match mod.data_sec {
    Some(DataSec(datas)) => datas
    None => []
  }
  if mp_has_segment_ops_candidates(active, referrers) {
    trace("optimize_segment_ops:start")
    let (next_mod, changed) = optimize_segment_ops(
      mod, active, referrers, memories, data_segments,
    )
    mod = next_mod
    trace("optimize_segment_ops:done changed=\{changed}")
    if changed {
      trace("collect_segment_referrers:start post_segment_ops")
      referrers = collect_segment_referrers(mod)
      trace("collect_segment_referrers:done refs=\{referrers.length()}")
    }
  } else {
    trace("optimize_segment_ops:skip:no_candidates")
  }
  let removed_passive = drop_unused_segments(mod, referrers)
  trace("drop_unused_segments:done removed=\{removed_passive.length()}")
  trace("build_transforms:start")
  let (mod, transforms) = mp_build_transforms_and_segments(
    mod, referrers, removed_passive, options,
  )
  trace("build_transforms:done transforms=\{transforms.length()}")
  trace("create_replacements:start")
  let (mod, replacements) = create_replacements(
    mod, transforms, removed_passive,
  )
  trace("create_replacements:done")
  trace("apply_replacements:start")
  let out = apply_replacements(mod, replacements)
  match out {
    Ok(_) => trace("apply_replacements:done")
    Err(_) => ()
  }
  out
}

///|
fn memory_packing(
  mod : Module,
  options : MemoryPackingPassProps,
  trace? : (String) -> Unit = fn(_) { () },
) -> Result[Module, String] {
  run_memory_packing_on_module(mod, options, trace~)
}

// ============================================================
// Tests
// ============================================================

///|
fn mp_type_void() -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type([], [])))
}

///|
fn mp_make_module_with_data(
  mems : Array[MemType],
  datas : Array[Data],
  funcs? : Array[Func] = [],
) -> Module {
  let mut mod = Module::new()
    .with_mem_sec(MemSec::new(mems))
    .with_data_sec(DataSec::new(datas))
  if !funcs.is_empty() {
    mod = mod
      .with_type_sec(TypeSec::new([mp_type_void()]))
      .with_func_sec(FuncSec::new(Array::make(funcs.length(), TypeIdx::new(0))))
      .with_code_sec(CodeSec::new(funcs))
  }
  mod
}

///|
fn mp_run(
  mod : Module,
  options? : MemoryPackingPassProps = MemoryPackingPassProps::new(
    zero_filled_memory=true,
  ),
) -> Module {
  match run_memory_packing_on_module(mod, options) {
    Ok(out) => out
    Err(_) => mod
  }
}

///|
fn mp_first_body(mod : Module) -> TExpr {
  match mod.code_sec {
    Some(CodeSec([TFunc(_, body), ..])) => body
    _ => TExpr::new([])
  }
}

///|
fn mp_count_instr(body : TExpr, pred : (TInstr) -> Bool) -> Int {
  let mut n = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    if pred(instr) {
      n += 1
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  n
}

///|
fn mp_global_count(mod : Module) -> Int {
  match mod.global_sec {
    Some(GlobalSec(globals)) => globals.length()
    None => 0
  }
}

///|
test "memory packing gating: no memory leaves module unchanged" {
  let mod = Module::new().with_data_sec(
    DataSec::new([Data::new(DataMode::passive(), b"\x01\x00\x02")]),
  )
  let out = mp_run(mod)
  assert_eq(out, mod)
}

///|
test "memory packing gating: multi-memory leaves module unchanged" {
  let mod = Module::new()
    .with_mem_sec(
      MemSec::new([
        MemType::new(Limits::i32(1, None)),
        MemType::new(Limits::i32(1, None)),
      ]),
    )
    .with_data_sec(
      DataSec::new([Data::new(DataMode::passive(), b"\x01\x00\x02")]),
    )
  let out = mp_run(mod)
  assert_eq(out, mod)
}

///|
test "memory packing gating: imported memory requires zero-filled option" {
  let mod = Module::new()
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("mem"),
          ExternType::mem(MemType::new(Limits::i32(1, None))),
        ),
      ]),
    )
    .with_data_sec(
      DataSec::new([Data::new(DataMode::passive(), b"\x01\x00\x02")]),
    )
  let out = mp_run(
    mod,
    options=MemoryPackingPassProps::new(zero_filled_memory=false),
  )
  assert_eq(out, mod)
  let changed = mp_run(
    mod,
    options=MemoryPackingPassProps::new(zero_filled_memory=true),
  )
  assert_true(changed != mod)
}

///|
test "memory packing gating: non-const active offset with multiple segments leaves unchanged" {
  let data0 = Data::new(
    DataMode::active(
      MemIdx::new(0),
      Expr::new([Instruction::global_get(GlobalIdx::new(0))]),
    ),
    b"\x00\x00\x01",
  )
  let data1 = Data::new(
    DataMode::active(
      MemIdx::new(0),
      Expr::new([Instruction::i32_const(I32(10))]),
    ),
    b"\x01",
  )
  let mod = Module::new()
    .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), false),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
      ]),
    )
    .with_data_sec(DataSec::new([data0, data1]))
  let out = mp_run(mod)
  assert_eq(out, mod)
}

///|
test "memory packing gating: overlapping active segments leave module unchanged" {
  let d0 = Data::new(
    DataMode::active(
      MemIdx::new(0),
      Expr::new([Instruction::i32_const(I32(0))]),
    ),
    b"\x01\x02",
  )
  let d1 = Data::new(
    DataMode::active(
      MemIdx::new(0),
      Expr::new([Instruction::i32_const(I32(1))]),
    ),
    b"\x03\x04",
  )
  let mod = Module::new()
    .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
    .with_data_sec(DataSec::new([d0, d1]))
  let out = mp_run(mod)
  assert_eq(out, mod)
}

///|
test "memory packing splits passive segment around large zero ranges" {
  let data = Data::new(
    DataMode::passive(),
    b"\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02",
  )
  let body = TExpr::new([
    TInstr::memory_init(
      DataIdx::new(0),
      MemIdx::new(0),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(32)),
    ),
  ])
  let mod = mp_make_module_with_data(
    [MemType::new(Limits::i32(1, None))],
    [data],
    funcs=[Func::t_func([], body)],
  )
  let out = mp_run(mod)
  match out.data_sec {
    Some(DataSec(datas)) => {
      assert_eq(datas.length(), 2)
      match datas[0] {
        Data(_, bytes) => assert_eq(bytes, b"\x01")
      }
      match datas[1] {
        Data(_, bytes) => assert_eq(bytes, b"\x02")
      }
    }
    _ => fail("expected data section")
  }
}

///|
test "memory packing keeps small interior zero spans in passive segment" {
  let data = Data::new(DataMode::passive(), b"\x01\x00\x02")
  let body = TExpr::new([
    TInstr::memory_init(
      DataIdx::new(0),
      MemIdx::new(0),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(3)),
    ),
  ])
  let mod = mp_make_module_with_data(
    [MemType::new(Limits::i32(1, None))],
    [data],
    funcs=[Func::t_func([], body)],
  )
  let out = mp_run(mod)
  match out.data_sec {
    Some(DataSec(datas)) => assert_eq(datas.length(), 1)
    _ => fail("expected data section")
  }
}

///|
test "memory packing merges small passive edge zero ranges by edgeThreshold" {
  let bytes = b"\x00\x00\x01"
  let data = Data::new(DataMode::passive(), bytes)
  let body = TExpr::new([
    TInstr::memory_init(
      DataIdx::new(0),
      MemIdx::new(0),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(3)),
    ),
  ])
  let mod = mp_make_module_with_data(
    [MemType::new(Limits::i32(1, None))],
    [data],
    funcs=[Func::t_func([], body)],
  )
  let out = mp_run(mod)
  match out.data_sec {
    Some(DataSec(datas)) => {
      assert_eq(datas.length(), 1)
      match datas[0] {
        Data(_, got) => assert_eq(got, bytes)
      }
    }
    _ => fail("expected data section")
  }
}

///|
test "memory packing can_split_segment rejects llvm-named feature flag" {
  let segment = Data::new(
    DataMode::passive(),
    b"\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02",
  )
  let refs = {
    memory_init_refs: 1,
    data_drop_refs: 0,
    gc_data_refs: 0,
    passive_has_non_const_meminit: false,
    has_any_non_drop_ref: true,
  }
  assert_false(
    can_split_segment(
      segment,
      refs,
      MPModuleFeatures::new(segment_is_llvm_named=true),
    ),
  )
}

///|
test "memory packing keeps empty segments unsplit" {
  let data = Data::new(DataMode::passive(), b"")
  let body = TExpr::new([
    TInstr::memory_init(
      DataIdx::new(0),
      MemIdx::new(0),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(0)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        single_rec_type(
          comp_type_sub_type(func_comp_type([ValType::i32()], [])),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([], body)]))
    .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
    .with_data_sec(DataSec::new([data]))
  let out = mp_run(mod)
  match out.data_sec {
    Some(DataSec(datas)) => assert_eq(datas.length(), 1)
    _ => fail("expected data section")
  }
}

///|
test "memory packing active startup trap preservation keeps last byte when may trap" {
  let data = Data::new(
    DataMode::active(
      MemIdx::new(0),
      Expr::new([Instruction::i32_const(I32(65535))]),
    ),
    b"\x00\x00\x00\x00",
  )
  let mod = mp_make_module_with_data([MemType::new(Limits::i32(1, Some(1)))], [
    data,
  ])
  let out = mp_run(mod)
  match out.data_sec {
    Some(DataSec(datas)) => {
      // One byte must remain as non-zero-preserving write for startup trap parity.
      assert_true(datas.length() >= 1)
      let mut total = 0
      for data in datas {
        total += data.1.length()
      }
      assert_true(total >= 1)
    }
    _ => fail("expected data section")
  }
}

///|
test "memory packing active in-bounds zero payload can be removed" {
  let data = Data::new(
    DataMode::active(
      MemIdx::new(0),
      Expr::new([Instruction::i32_const(I32(0))]),
    ),
    b"\x00\x00\x00\x00",
  )
  let mod = mp_make_module_with_data([MemType::new(Limits::i32(1, Some(1)))], [
    data,
  ])
  let out = mp_run(mod)
  match out.data_sec {
    Some(DataSec(datas)) => assert_eq(datas.length(), 0)
    _ => fail("expected data section")
  }
}

///|
test "memory packing rewrites memory.init with zero/non-zero ranges" {
  let data = Data::new(
    DataMode::passive(),
    b"\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02",
  )
  let body = TExpr::new([
    TInstr::memory_init(
      DataIdx::new(0),
      MemIdx::new(0),
      TInstr::i32_const(I32(10)),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(32)),
    ),
  ])
  let mod = mp_make_module_with_data(
    [MemType::new(Limits::i32(1, None))],
    [data],
    funcs=[Func::t_func([], body)],
  )
  let out = mp_run(mod)
  let new_body = mp_first_body(out)
  let init_count = mp_count_instr(new_body, fn(i) {
    i is TMemoryInit(_, _, _, _, _)
  })
  let fill_count = mp_count_instr(new_body, fn(i) {
    i is TMemoryFill(_, _, _, _)
  })
  assert_true(init_count >= 1)
  assert_true(fill_count >= 1)
}

///|
test "memory packing keeps non-zero-only memory.init without fill" {
  let data = Data::new(DataMode::passive(), b"\x01\x02\x03")
  let body = TExpr::new([
    TInstr::memory_init(
      DataIdx::new(0),
      MemIdx::new(0),
      TInstr::i32_const(I32(10)),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(3)),
    ),
  ])
  let mod = mp_make_module_with_data(
    [MemType::new(Limits::i32(1, None))],
    [data],
    funcs=[Func::t_func([], body)],
  )
  let out = mp_run(mod)
  let new_body = mp_first_body(out)
  let init_count = mp_count_instr(new_body, fn(i) {
    i is TMemoryInit(_, _, _, _, _)
  })
  let fill_count = mp_count_instr(new_body, fn(i) {
    i is TMemoryFill(_, _, _, _)
  })
  assert_true(init_count >= 1)
  assert_eq(fill_count, 0)
}

///|
test "memory packing introduces temp local for non-const memory.init dest" {
  let data = Data::new(
    DataMode::passive(),
    b"\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02",
  )
  let body = TExpr::new([
    TInstr::memory_init(
      DataIdx::new(0),
      MemIdx::new(0),
      TInstr::local_get(LocalIdx::new(0)),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(32)),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        single_rec_type(
          comp_type_sub_type(func_comp_type([ValType::i32()], [])),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([], body)]))
    .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
    .with_data_sec(DataSec::new([data]))
  let out = mp_run(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(locals, body)])) => {
      assert_true(locals.length() >= 1)
      let set_count = mp_count_instr(body, fn(i) { i is TLocalSet(_, _) })
      assert_true(set_count >= 1)
    }
    _ => fail("expected tfunc")
  }
}

///|
test "memory packing zero-length memory.init emits explicit trap check" {
  let data = Data::new(DataMode::passive(), b"\x00\x00\x00")
  let body = TExpr::new([
    TInstr::memory_init(
      DataIdx::new(0),
      MemIdx::new(0),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(0)),
    ),
  ])
  let mod = mp_make_module_with_data(
    [MemType::new(Limits::i32(1, None))],
    [data],
    funcs=[Func::t_func([], body)],
  )
  let out = mp_run(mod)
  let body = mp_first_body(out)
  let if_count = mp_count_instr(body, fn(i) { i is TIf(_, _, _, _) })
  assert_true(if_count >= 1)
}

///|
test "memory packing creates drop-state global for fill-first rewrite and rewrites data.drop" {
  let data = Data::new(
    DataMode::passive(),
    b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02",
  )
  let body = TExpr::new([
    TInstr::memory_init(
      DataIdx::new(0),
      MemIdx::new(0),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(52)),
    ),
    TInstr::data_drop(DataIdx::new(0)),
  ])
  let mod = mp_make_module_with_data(
    [MemType::new(Limits::i32(1, None))],
    [data],
    funcs=[Func::t_func([], body)],
  )
  let out = mp_run(mod)
  assert_eq(mp_global_count(out), 1)
  let rewritten = mp_first_body(out)
  let global_gets = mp_count_instr(rewritten, fn(i) { i is TGlobalGet(_) })
  let global_sets = mp_count_instr(rewritten, fn(i) { i is TGlobalSet(_, _) })
  let drop_count = mp_count_instr(rewritten, fn(i) { i is TDataDrop(_) })
  assert_true(global_gets >= 1)
  assert_true(global_sets >= 1)
  assert_eq(drop_count, 2)
}

///|
test "memory packing avoids drop-state global when no fill-first hazard" {
  let data = Data::new(
    DataMode::passive(),
    b"\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02",
  )
  let body = TExpr::new([
    TInstr::memory_init(
      DataIdx::new(0),
      MemIdx::new(0),
      TInstr::i32_const(I32(8)),
      TInstr::i32_const(I32(31)),
      TInstr::i32_const(I32(1)),
    ),
  ])
  let mod = mp_make_module_with_data(
    [MemType::new(Limits::i32(1, None))],
    [data],
    funcs=[Func::t_func([], body)],
  )
  let out = mp_run(mod)
  assert_eq(mp_global_count(out), 0)
}

///|
test "memory packing drops passive segment only used by data.drop" {
  let data = Data::new(DataMode::passive(), b"\x01\x02")
  let body = TExpr::new([TInstr::data_drop(DataIdx::new(0))])
  let mod = mp_make_module_with_data(
    [MemType::new(Limits::i32(1, None))],
    [data],
    funcs=[Func::t_func([], body)],
  )
  let out = mp_run(mod)
  match out.data_sec {
    Some(DataSec(datas)) => assert_eq(datas.length(), 0)
    _ => fail("expected data section")
  }
  let body = mp_first_body(out)
  let drop_count = mp_count_instr(body, fn(i) { i is TDataDrop(_) })
  assert_eq(drop_count, 0)
}

///|
test "memory packing keeps passive segment referenced by memory.init" {
  let data = Data::new(DataMode::passive(), b"\x01\x02")
  let body = TExpr::new([
    TInstr::memory_init(
      DataIdx::new(0),
      MemIdx::new(0),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(2)),
    ),
  ])
  let mod = mp_make_module_with_data(
    [MemType::new(Limits::i32(1, None))],
    [data],
    funcs=[Func::t_func([], body)],
  )
  let out = mp_run(mod)
  match out.data_sec {
    Some(DataSec(datas)) => assert_true(datas.length() >= 1)
    _ => fail("expected data section")
  }
}

///|
test "memory packing respects max data segment limit by merging remaining ranges" {
  let data = Data::new(DataMode::passive(), b"\x01\x00\x02\x00\x03\x00\x04")
  let mod = mp_make_module_with_data([MemType::new(Limits::i32(1, None))], [
    data,
  ])
  let out = mp_run(
    mod,
    options=MemoryPackingPassProps::new(
      zero_filled_memory=true,
      max_data_segments=2,
    ),
  )
  match out.data_sec {
    Some(DataSec(datas)) => assert_true(datas.length() <= 2)
    _ => fail("expected data section")
  }
}

///|
pub fn memory_packing_summary() -> String {
  "Split active data segments around profitable zero ranges while preserving startup memory semantics."
}

///|
priv struct MpRange {
  is_zero : Bool
  start : Int
  end_ : Int
}

///|
fn MpRange::new(is_zero : Bool, start : Int, end_ : Int) -> MpRange {
  { is_zero, start, end_ }
}

///|
priv struct MpSpan {
  start : UInt64
  end_ : UInt64
}

///|
fn MpSpan::new(start : UInt64, end_ : UInt64) -> MpSpan {
  { start, end_ }
}

///|
priv enum MpBaseOffset {
  I32(UInt)
  I64(UInt64)
}

///|
fn mp_imported_mem_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.MemExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn mp_defined_mem_count(mod_ : @lib.Module) -> Int {
  match mod_.mem_sec {
    Some(@lib.MemSec(mems)) => mems.length()
    None => 0
  }
}

///|
fn mp_defined_memory_size_bytes(mod_ : @lib.Module) -> UInt64? {
  match mod_.mem_sec {
    Some(@lib.MemSec([@lib.MemType(@lib.I32Limits(initial, _))])) =>
      Some(initial.to_uint64() << 16)
    Some(@lib.MemSec([@lib.MemType(@lib.I64Limits(initial, _))])) =>
      Some(initial << 16)
    _ => None
  }
}

///|
fn mp_parse_base_offset(expr : @lib.Expr) -> MpBaseOffset? {
  match expr {
    @lib.Expr([@lib.I32Const(@lib.I32(value))]) =>
      Some(MpBaseOffset::I32(value.reinterpret_as_uint()))
    @lib.Expr([@lib.I64Const(@lib.I64(value))]) =>
      Some(MpBaseOffset::I64(value.reinterpret_as_uint64()))
    _ => None
  }
}

///|
fn mp_base_offset_u64(base : MpBaseOffset) -> UInt64 {
  match base {
    I32(value) => value.to_uint64()
    I64(value) => value
  }
}

///|
fn mp_shift_base_offset(base : MpBaseOffset, delta : Int) -> @lib.Expr {
  match base {
    I32(value) =>
      @lib.Expr::new([
        @lib.Instruction::i32_const(
          @lib.I32((value + delta.reinterpret_as_uint()).reinterpret_as_int()),
        ),
      ])
    I64(value) =>
      @lib.Expr::new([
        @lib.Instruction::i64_const(
          @lib.I64(
            (value + delta.reinterpret_as_uint().to_uint64()).reinterpret_as_int64(),
          ),
        ),
      ])
  }
}

///|
fn mp_slice_bytes(bytes : Bytes, start : Int, end_ : Int) -> Bytes {
  let out = @buffer.new(size_hint=end_ - start)
  for i = start; i < end_; i = i + 1 {
    out.write_byte(bytes[i])
  }
  out.to_bytes()
}

///|
fn mp_collect_ranges(bytes : Bytes) -> Array[MpRange] {
  let ranges : Array[MpRange] = []
  let mut start = 0
  while start < bytes.length() {
    let mut end_ = start
    while end_ < bytes.length() && bytes[end_] == 0 {
      end_ += 1
    }
    if end_ > start {
      ranges.push(MpRange::new(true, start, end_))
      start = end_
    }
    while end_ < bytes.length() && bytes[end_] != 0 {
      end_ += 1
    }
    if end_ > start {
      ranges.push(MpRange::new(false, start, end_))
      start = end_
    }
  }
  ranges
}

///|
fn mp_merge_small_zero_ranges(
  ranges : Array[MpRange],
  threshold : Int,
) -> Array[MpRange] {
  if ranges.is_empty() {
    return []
  }
  let merged : Array[MpRange] = [ranges[0]]
  let mut idx = 1
  while idx < ranges.length() {
    if idx + 1 < ranges.length() {
      let curr = ranges[idx]
      if curr.is_zero && curr.end_ - curr.start <= threshold {
        let left = merged[merged.length() - 1]
        let right = ranges[idx + 1]
        merged[merged.length() - 1] = MpRange::new(
          left.is_zero,
          left.start,
          right.end_,
        )
        idx += 2
        continue
      }
    }
    merged.push(ranges[idx])
    idx += 1
  }
  merged
}

///|
fn mp_preserve_trapping_top_byte(
  ranges : Array[MpRange],
  size : Int,
) -> Array[MpRange] {
  if ranges.is_empty() {
    return ranges
  }
  let preserved : Array[MpRange] = []
  for range in ranges {
    preserved.push(range)
  }
  let last_idx = preserved.length() - 1
  let last = preserved[last_idx]
  if last.is_zero {
    preserved[last_idx] = MpRange::new(true, last.start, last.end_ - 1)
    preserved.push(MpRange::new(false, size - 1, size))
  }
  preserved
}

///|
fn mp_should_preserve_trap(
  mod_ : @lib.Module,
  base : MpBaseOffset,
  size : Int,
) -> Bool {
  match mp_defined_memory_size_bytes(mod_) {
    Some(memory_size) => {
      let start = mp_base_offset_u64(base)
      let size_u = size.reinterpret_as_uint().to_uint64()
      let end_ = start + size_u
      end_ < start || end_ > memory_size
    }
    None => true
  }
}

///|
fn mp_active_rewrite(
  mod_ : @lib.Module,
  mem_idx : @lib.MemIdx,
  expr : @lib.Expr,
  bytes : Bytes,
) -> Array[@lib.Data] {
  if bytes.length() == 0 {
    return [@lib.Data::new(@lib.DataMode::active(mem_idx, expr), bytes)]
  }
  let base = match mp_parse_base_offset(expr) {
    Some(base) => base
    None => return [@lib.Data::new(@lib.DataMode::active(mem_idx, expr), bytes)]
  }
  let ranges = mp_collect_ranges(bytes)
  if ranges.is_empty() {
    return [@lib.Data::new(@lib.DataMode::active(mem_idx, expr), bytes)]
  }
  let mut merged = mp_merge_small_zero_ranges(ranges, 8)
  if mp_should_preserve_trap(mod_, base, bytes.length()) {
    merged = mp_preserve_trapping_top_byte(merged, bytes.length())
  }
  let rewritten : Array[@lib.Data] = []
  for range in merged {
    if range.is_zero || range.end_ <= range.start {
      continue
    }
    rewritten.push(
      @lib.Data::new(
        @lib.DataMode::active(mem_idx, mp_shift_base_offset(base, range.start)),
        mp_slice_bytes(bytes, range.start, range.end_),
      ),
    )
  }
  rewritten
}

///|
fn mp_can_optimize(mod_ : @lib.Module, datas : Array[@lib.Data]) -> Bool {
  let imported_mem_count = mp_imported_mem_count(mod_)
  if imported_mem_count != 0 {
    return false
  }
  if imported_mem_count + mp_defined_mem_count(mod_) != 1 {
    return false
  }
  if datas.length() <= 1 {
    return true
  }
  let spans : Array[MpSpan] = []
  for data in datas {
    match data {
      @lib.Data(@lib.Active(@lib.MemIdx(mem_idx), expr), bytes) => {
        if mem_idx != 0U {
          return false
        }
        let base = match mp_parse_base_offset(expr) {
          Some(base) => base
          None => return false
        }
        let start = mp_base_offset_u64(base)
        let end_ = start + bytes.length().reinterpret_as_uint().to_uint64()
        if end_ < start {
          return false
        }
        for span in spans {
          if start < span.end_ && span.start < end_ {
            return false
          }
        }
        spans.push(MpSpan::new(start, end_))
      }
      @lib.Data(@lib.Passive, _) => ()
    }
  }
  true
}

///|
pub fn memory_packing_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let datas = match mod_.data_sec {
    Some(@lib.DataSec(datas)) => datas
    None => return mod_
  }
  if !mp_can_optimize(mod_, datas) {
    return mod_
  }
  let rewritten : Array[@lib.Data] = []
  let mut changed = false
  for data in datas {
    let next = match data {
      @lib.Data(@lib.Active(mem_idx, expr), bytes) =>
        mp_active_rewrite(mod_, mem_idx, expr, bytes)
      @lib.Data(@lib.Passive, _) => [data]
    }
    if next.length() != 1 || next[0] != data {
      changed = true
    }
    for item in next {
      rewritten.push(item)
    }
  }
  if !changed {
    return mod_
  }
  let next_data_sec = if rewritten.is_empty() {
    None
  } else {
    Some(@lib.DataSec::new(rewritten))
  }
  let next_data_cnt_sec = match (mod_.data_cnt_sec, next_data_sec) {
    (Some(_), Some(@lib.DataSec(datas))) =>
      Some(@lib.DataCntSec::new(@lib.U32(datas.length().reinterpret_as_uint())))
    (Some(_), None) => Some(@lib.DataCntSec::new(@lib.U32(0U)))
    (None, _) => None
  }
  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    type_sec=mod_.type_sec,
    import_sec=mod_.import_sec,
    func_annotation_sec=mod_.func_annotation_sec,
    func_sec=mod_.func_sec,
    table_sec=mod_.table_sec,
    mem_sec=mod_.mem_sec,
    tag_sec=mod_.tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec=mod_.global_sec,
    export_sec=mod_.export_sec,
    start_sec=mod_.start_sec,
    elem_sec=mod_.elem_sec,
    data_cnt_sec=next_data_cnt_sec,
    code_sec=mod_.code_sec,
    data_sec=next_data_sec,
    name_sec=mod_.name_sec,
    raw_name_sec_payload=mod_.raw_name_sec_payload,
  )
}

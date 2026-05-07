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
priv struct MpDataUsage {
  has_non_drop : Bool
  has_drop : Bool
}

///|
fn MpDataUsage::new(has_non_drop : Bool, has_drop : Bool) -> MpDataUsage {
  { has_non_drop, has_drop }
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
    Some(@lib.MemSec([@lib.MemType(@lib.I32Limits(initial, _), _)])) =>
      Some(initial.to_uint64() << 16)
    Some(@lib.MemSec([@lib.MemType(@lib.I64Limits(initial, _), _)])) =>
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
fn mp_data_idx_slot(idx : @lib.DataIdx) -> Int {
  let @lib.DataIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn mp_mark_data_non_drop(
  usages : Array[MpDataUsage],
  idx : @lib.DataIdx,
) -> Unit {
  let slot = mp_data_idx_slot(idx)
  if slot < 0 || slot >= usages.length() {
    return
  }
  let usage = usages[slot]
  usages[slot] = MpDataUsage::new(true, usage.has_drop)
}

///|
fn mp_mark_data_drop(usages : Array[MpDataUsage], idx : @lib.DataIdx) -> Unit {
  let slot = mp_data_idx_slot(idx)
  if slot < 0 || slot >= usages.length() {
    return
  }
  let usage = usages[slot]
  usages[slot] = MpDataUsage::new(usage.has_non_drop, true)
}

///|
fn mp_collect_data_usage_expr(
  expr : @lib.Expr,
  usages : Array[MpDataUsage],
) -> Unit {
  let @lib.Expr(instrs) = expr
  for instr in instrs {
    mp_collect_data_usage_instr(instr, usages)
  }
}

///|
fn mp_collect_data_usage_instr(
  instr : @lib.Instruction,
  usages : Array[MpDataUsage],
) -> Unit {
  match instr {
    @lib.Block(_, body) | @lib.Loop(_, body) =>
      mp_collect_data_usage_expr(body, usages)
    @lib.If(_, then_body, else_body) => {
      for nested in then_body {
        mp_collect_data_usage_instr(nested, usages)
      }
      match else_body {
        Some(body) =>
          for nested in body {
            mp_collect_data_usage_instr(nested, usages)
          }
        None => ()
      }
    }
    @lib.TryTable(_, _, body) => mp_collect_data_usage_expr(body, usages)
    @lib.ArrayNewData(_, idx)
    | @lib.ArrayInitData(_, idx)
    | @lib.MemoryInit(idx, _) => mp_mark_data_non_drop(usages, idx)
    @lib.DataDrop(idx) => mp_mark_data_drop(usages, idx)
    _ => ()
  }
}

///|
fn mp_collect_data_usages(
  mod_ : @lib.Module,
  data_count : Int,
) -> Array[MpDataUsage] {
  let usages = Array::make(data_count, MpDataUsage::new(false, false))
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func_ in funcs {
        let @lib.Func(_, body) = func_
        mp_collect_data_usage_expr(body, usages)
      }
    None => ()
  }
  usages
}

///|
fn mp_rewrite_data_idx(idx : @lib.DataIdx, remap : Array[Int]) -> @lib.DataIdx {
  let slot = mp_data_idx_slot(idx)
  if slot < 0 || slot >= remap.length() {
    return idx
  }
  let next = remap[slot]
  if next < 0 {
    return idx
  }
  @lib.DataIdx::new(next.reinterpret_as_uint())
}

///|
fn mp_rewrite_data_expr(expr : @lib.Expr, remap : Array[Int]) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let rewritten : Array[@lib.Instruction] = []
  for instr in instrs {
    rewritten.push(mp_rewrite_data_instr(instr, remap))
  }
  @lib.Expr::new(rewritten)
}

///|
fn mp_rewrite_data_instr(
  instr : @lib.Instruction,
  remap : Array[Int],
) -> @lib.Instruction {
  match instr {
    @lib.Block(block_type, body) =>
      @lib.Instruction::block(block_type, mp_rewrite_data_expr(body, remap))
    @lib.Loop(block_type, body) =>
      @lib.Instruction::loop_(block_type, mp_rewrite_data_expr(body, remap))
    @lib.If(block_type, then_body, else_body) => {
      let rewritten_then : Array[@lib.Instruction] = []
      for nested in then_body {
        rewritten_then.push(mp_rewrite_data_instr(nested, remap))
      }
      let rewritten_else = match else_body {
        Some(body) => {
          let rewritten : Array[@lib.Instruction] = []
          for nested in body {
            rewritten.push(mp_rewrite_data_instr(nested, remap))
          }
          Some(rewritten)
        }
        None => None
      }
      @lib.Instruction::if_(block_type, rewritten_then, rewritten_else)
    }
    @lib.TryTable(block_type, catches, body) =>
      @lib.Instruction::try_table(
        block_type,
        catches,
        mp_rewrite_data_expr(body, remap),
      )
    @lib.ArrayNewData(type_idx, idx) =>
      @lib.Instruction::array_new_data(
        type_idx,
        mp_rewrite_data_idx(idx, remap),
      )
    @lib.ArrayInitData(type_idx, idx) =>
      @lib.Instruction::array_init_data(
        type_idx,
        mp_rewrite_data_idx(idx, remap),
      )
    @lib.MemoryInit(idx, mem_idx) =>
      @lib.Instruction::memory_init(mp_rewrite_data_idx(idx, remap), mem_idx)
    @lib.DataDrop(idx) => {
      let slot = mp_data_idx_slot(idx)
      if slot < 0 || slot >= remap.length() {
        return instr
      }
      let next = remap[slot]
      if next < 0 {
        return @lib.Instruction::nop()
      }
      @lib.Instruction::data_drop(@lib.DataIdx::new(next.reinterpret_as_uint()))
    }
    _ => instr
  }
}

///|
fn mp_rewrite_code_sec(
  code_sec : @lib.CodeSec?,
  remap : Array[Int],
) -> @lib.CodeSec? {
  match code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let rewritten : Array[@lib.Func] = []
      for func_ in funcs {
        let @lib.Func(locals, body) = func_
        rewritten.push(
          @lib.Func::new(locals, mp_rewrite_data_expr(body, remap)),
        )
      }
      Some(@lib.CodeSec::new(rewritten))
    }
    None => None
  }
}

///|
fn mp_data_rewrite_needed(
  remap : Array[Int],
  usages : Array[MpDataUsage],
) -> Bool {
  let mut idx = 0
  while idx < remap.length() {
    let usage = usages[idx]
    if (usage.has_non_drop || usage.has_drop) && remap[idx] != idx {
      return true
    }
    idx += 1
  }
  false
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
  let usages = mp_collect_data_usages(mod_, datas.length())
  let data_remap = Array::make(datas.length(), -1)
  let rewritten : Array[@lib.Data] = []
  let mut changed = false
  let mut idx = 0
  for data in datas {
    let next = match data {
      @lib.Data(@lib.Active(mem_idx, expr), bytes) =>
        mp_active_rewrite(mod_, mem_idx, expr, bytes)
      @lib.Data(@lib.Passive, _) => {
        let usage = usages[idx]
        if usage.has_non_drop {
          [data]
        } else {
          []
        }
      }
    }
    if next.length() != 1 || next[0] != data {
      changed = true
    }
    match data {
      @lib.Data(@lib.Passive, _) if next.length() == 1 =>
        data_remap[idx] = rewritten.length()
      _ => ()
    }
    for item in next {
      rewritten.push(item)
    }
    idx += 1
  }
  let needs_code_rewrite = mp_data_rewrite_needed(data_remap, usages)
  let next_code_sec = if needs_code_rewrite {
    changed = true
    mp_rewrite_code_sec(mod_.code_sec, data_remap)
  } else {
    mod_.code_sec
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
    (Some(_), None) => None
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
    code_sec=next_code_sec,
    data_sec=next_data_sec,
    name_sec=mod_.name_sec,
    raw_name_sec_payload=mod_.raw_name_sec_payload,
  )
}

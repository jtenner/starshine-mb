///|
pub fn memory_packing_summary() -> String {
  "Pack active and passive data segments around profitable zero ranges while preserving segment-user semantics."
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
fn mp_memory_type_size_bytes(mem_type : @lib.MemType) -> UInt64? {
  match mem_type {
    @lib.MemType(@lib.I32Limits(initial, _), _) =>
      Some(initial.to_uint64() << 16)
    @lib.MemType(@lib.I64Limits(initial, _), _) => Some(initial << 16)
  }
}

///|
fn mp_imported_memory_size_bytes(mod_ : @lib.Module) -> UInt64? {
  let mut found : UInt64? = None
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.MemExternType(mem_type)) =>
            match found {
              Some(_) => return None
              None => found = mp_memory_type_size_bytes(mem_type)
            }
          _ => ()
        }
      }
    None => ()
  }
  found
}

///|
fn mp_memory_size_bytes(mod_ : @lib.Module) -> UInt64? {
  match mod_.mem_sec {
    Some(@lib.MemSec([mem_type])) => mp_memory_type_size_bytes(mem_type)
    Some(_) => None
    None => mp_imported_memory_size_bytes(mod_)
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
    I32(value) => {
      let shifted = value.to_uint64() + delta.reinterpret_as_uint().to_uint64()
      let saturated = if shifted > 0xFFFF_FFFFUL {
        0xFFFF_FFFFUL
      } else {
        shifted
      }
      @lib.Expr::new([
        @lib.Instruction::i32_const(
          @lib.I32(saturated.to_uint().reinterpret_as_int()),
        ),
      ])
    }
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
  match mp_memory_size_bytes(mod_) {
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
fn mp_active_rewrite_fast_single_range(
  mem_idx : @lib.MemIdx,
  base : MpBaseOffset,
  bytes : Bytes,
  preserve_trap : Bool,
) -> Array[@lib.Data]? {
  let mut first = -1
  let mut last = -1
  let mut idx = 0
  while idx < bytes.length() {
    if bytes[idx] != 0 {
      if first < 0 {
        first = idx
      }
      last = idx
    }
    idx += 1
  }
  if first < 0 {
    if preserve_trap {
      return Some([
        @lib.Data::new(
          @lib.DataMode::active(
            mem_idx,
            mp_shift_base_offset(base, bytes.length() - 1),
          ),
          b"\x00",
        ),
      ])
    }
    return Some([])
  }

  let threshold = 8
  let mut zero_run = 0
  idx = first
  while idx <= last {
    if bytes[idx] == 0 {
      zero_run += 1
      if zero_run > threshold {
        return None
      }
    } else {
      zero_run = 0
    }
    idx += 1
  }

  let rewritten : Array[@lib.Data] = [
    @lib.Data::new(
      @lib.DataMode::active(mem_idx, mp_shift_base_offset(base, first)),
      mp_slice_bytes(bytes, first, last + 1),
    ),
  ]
  if preserve_trap && last + 1 < bytes.length() {
    rewritten.push(
      @lib.Data::new(
        @lib.DataMode::active(
          mem_idx,
          mp_shift_base_offset(base, bytes.length() - 1),
        ),
        b"\x00",
      ),
    )
  }
  Some(rewritten)
}

///|
fn mp_active_rewrite(
  mod_ : @lib.Module,
  mem_idx : @lib.MemIdx,
  expr : @lib.Expr,
  bytes : Bytes,
  traps_never_happen : Bool,
) -> Array[@lib.Data] {
  if bytes.length() == 0 {
    return [@lib.Data::new(@lib.DataMode::active(mem_idx, expr), bytes)]
  }
  let base = match mp_parse_base_offset(expr) {
    Some(base) => base
    None => return [@lib.Data::new(@lib.DataMode::active(mem_idx, expr), bytes)]
  }
  let preserve_trap = !traps_never_happen &&
    mp_should_preserve_trap(mod_, base, bytes.length())
  match
    mp_active_rewrite_fast_single_range(mem_idx, base, bytes, preserve_trap) {
    Some(rewritten) => return rewritten
    None => ()
  }
  let ranges = mp_collect_ranges(bytes)
  if ranges.is_empty() {
    return [@lib.Data::new(@lib.DataMode::active(mem_idx, expr), bytes)]
  }
  let mut merged = mp_merge_small_zero_ranges(ranges, 8)
  if preserve_trap {
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
fn mp_active_span_order(lhs : MpSpan, rhs : MpSpan) -> Int {
  if lhs.start < rhs.start {
    -1
  } else if lhs.start > rhs.start {
    1
  } else if lhs.end_ < rhs.end_ {
    -1
  } else if lhs.end_ > rhs.end_ {
    1
  } else {
    0
  }
}

///|
fn mp_active_spans_are_disjoint(spans : Array[MpSpan]) -> Bool {
  if spans.length() <= 1 {
    return true
  }
  spans.sort_by(mp_active_span_order)
  let mut idx = 1
  while idx < spans.length() {
    let prev = spans[idx - 1]
    let curr = spans[idx]
    if curr.start < prev.end_ && prev.start < curr.end_ {
      return false
    }
    idx += 1
  }
  true
}

///|
fn mp_can_optimize(
  mod_ : @lib.Module,
  datas : Array[@lib.Data],
  zero_filled_memory : Bool,
) -> Bool {
  let imported_mem_count = mp_imported_mem_count(mod_)
  if imported_mem_count != 0 && !zero_filled_memory {
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
        spans.push(MpSpan::new(start, end_))
      }
      @lib.Data(@lib.Passive, _) => ()
    }
  }
  mp_active_spans_are_disjoint(spans)
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
fn mp_data_segment_limit_exceeded(
  emitted_count : Int,
  candidate_count : Int,
  remaining_original_count : Int,
) -> Bool {
  emitted_count + candidate_count + remaining_original_count > 100000
}

///|
fn mp_needs_data_usage_scan(datas : Array[@lib.Data]) -> Bool {
  for data in datas {
    match data {
      @lib.Data(@lib.Passive, _) => return true
      _ => ()
    }
  }
  false
}

///|
priv struct MpSplitPart {
  start : Int
  end_ : Int
  data_idx : Int
}

///|
fn MpSplitPart::new(start : Int, end_ : Int, data_idx : Int) -> MpSplitPart {
  { start, end_, data_idx }
}

///|
priv struct MpSegmentPlan {
  remap : Int
  split_parts : Array[MpSplitPart]
  is_active : Bool
  was_split : Bool
  needs_drop_state : Bool
  data_size : Int
}

///|
fn MpSegmentPlan::new(
  remap : Int,
  split_parts : Array[MpSplitPart],
  is_active : Bool,
  was_split : Bool,
  needs_drop_state : Bool,
  data_size : Int,
) -> MpSegmentPlan {
  { remap, split_parts, is_active, was_split, needs_drop_state, data_size }
}

///|
priv struct MpPassiveUserScan {
  has_memory_init : Bool
  all_memory_init_const : Bool
  has_array_data : Bool
}

///|
fn MpPassiveUserScan::new(
  has_memory_init? : Bool = false,
  all_memory_init_const? : Bool = true,
  has_array_data? : Bool = false,
) -> MpPassiveUserScan {
  { has_memory_init, all_memory_init_const, has_array_data }
}

///|
fn mp_passive_scan_merge(
  lhs : MpPassiveUserScan,
  rhs : MpPassiveUserScan,
) -> MpPassiveUserScan {
  MpPassiveUserScan::new(
    has_memory_init=lhs.has_memory_init || rhs.has_memory_init,
    all_memory_init_const=lhs.all_memory_init_const && rhs.all_memory_init_const,
    has_array_data=lhs.has_array_data || rhs.has_array_data,
  )
}

///|
fn mp_instr_is_i32_const(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I32Const(_) => true
    _ => false
  }
}

///|
fn mp_instr_i32_const_value(instr : @lib.Instruction) -> Int? {
  match instr {
    @lib.I32Const(@lib.I32(value)) => Some(value)
    _ => None
  }
}

///|
fn mp_name_to_string(name : @lib.Name) -> String {
  let @lib.Name(text) = name
  text.to_owned()
}

///|
fn mp_string_starts_with(text : String, prefix : String) -> Bool {
  text.length() >= prefix.length() &&
  text.sub(start=0, end=prefix.length()).to_string() == prefix
}

///|
fn mp_data_name_for_idx(mod_ : @lib.Module, idx : Int) -> @lib.Name? {
  match mod_.name_sec {
    Some(name_sec) =>
      match name_sec.data_names {
        Some(@lib.NameMap(entries)) =>
          for entry in entries {
            let @lib.NameAssoc(raw_idx, name) = entry
            if raw_idx.reinterpret_as_int() == idx {
              return Some(name)
            }
          }
        None => ()
      }
    None => ()
  }
  None
}

///|
fn mp_data_name_has_prefix(
  mod_ : @lib.Module,
  idx : Int,
  prefix : String,
) -> Bool {
  match mp_data_name_for_idx(mod_, idx) {
    Some(name) => mp_string_starts_with(mp_name_to_string(name), prefix)
    None => false
  }
}

///|
fn mp_imported_global_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.GlobalExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn mp_defined_global_count(mod_ : @lib.Module) -> Int {
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => globals.length()
    None => 0
  }
}

///|
fn mp_append_drop_state_global(
  mod_ : @lib.Module,
  need_drop_state : Bool,
) -> (@lib.GlobalSec?, @lib.GlobalIdx?) {
  if !need_drop_state {
    return (mod_.global_sec, None)
  }
  let global_idx = @lib.GlobalIdx::new(
    (mp_imported_global_count(mod_) + mp_defined_global_count(mod_)).reinterpret_as_uint(),
  )
  let next_global = @lib.Global::new(
    @lib.GlobalType::new(@lib.ValType::i32(), true),
    @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
  )
  let globals : Array[@lib.Global] = []
  match mod_.global_sec {
    Some(@lib.GlobalSec(existing)) =>
      for global in existing {
        globals.push(global)
      }
    None => ()
  }
  globals.push(next_global)
  (Some(@lib.GlobalSec::new(globals)), Some(global_idx))
}

///|
fn mp_type_idx_flat_slot(idx : @lib.TypeIdx) -> Int? {
  match idx {
    @lib.TypeIdx(raw) => Some(raw.reinterpret_as_int())
    @lib.RecIdx(_) => None
  }
}

///|
fn mp_subtype_func_param_count(subtype : @lib.SubType) -> Int? {
  match subtype {
    @lib.CompTypeSubType(_, @lib.FuncCompType(params, _)) =>
      Some(params.length())
    @lib.SubType(_, _, _, @lib.FuncCompType(params, _)) => Some(params.length())
    _ => None
  }
}

///|
fn mp_type_sec_func_param_count(
  type_sec : @lib.TypeSec?,
  type_idx : @lib.TypeIdx,
) -> Int {
  let target = match mp_type_idx_flat_slot(type_idx) {
    Some(slot) => slot
    None => return 0
  }
  let mut flat = 0
  match type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      for rec in rec_types {
        match rec {
          @lib.SingleRecType(subtype) => {
            if flat == target {
              match mp_subtype_func_param_count(subtype) {
                Some(count) => return count
                None => return 0
              }
            }
            flat += 1
          }
          @lib.GroupRecType(subtypes) =>
            for subtype in subtypes {
              if flat == target {
                match mp_subtype_func_param_count(subtype) {
                  Some(count) => return count
                  None => return 0
                }
              }
              flat += 1
            }
        }
      }
    None => ()
  }
  0
}

///|
fn mp_defined_func_param_counts(mod_ : @lib.Module) -> Array[Int] {
  let counts : Array[Int] = []
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        counts.push(mp_type_sec_func_param_count(mod_.type_sec, type_idx))
      }
    None => ()
  }
  counts
}

///|
fn mp_passive_user_scan_instrs(
  instrs : Array[@lib.Instruction],
  target : Int,
) -> MpPassiveUserScan {
  let mut scan = MpPassiveUserScan::new()
  for i = 0; i < instrs.length(); i = i + 1 {
    let instr = instrs[i]
    match instr {
      @lib.MemoryInit(idx, _) if mp_data_idx_slot(idx) == target => {
        let has_const_source_size = i >= 2 &&
          mp_instr_is_i32_const(instrs[i - 2]) &&
          mp_instr_is_i32_const(instrs[i - 1])
        scan = mp_passive_scan_merge(
          scan,
          MpPassiveUserScan::new(
            has_memory_init=true,
            all_memory_init_const=has_const_source_size,
          ),
        )
      }
      @lib.ArrayNewData(_, idx) =>
        if mp_data_idx_slot(idx) == target {
          scan = mp_passive_scan_merge(
            scan,
            MpPassiveUserScan::new(has_array_data=true),
          )
        }
      @lib.ArrayInitData(_, idx) =>
        if mp_data_idx_slot(idx) == target {
          scan = mp_passive_scan_merge(
            scan,
            MpPassiveUserScan::new(has_array_data=true),
          )
        }
      @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) => {
        let @lib.Expr(body_instrs) = body
        scan = mp_passive_scan_merge(
          scan,
          mp_passive_user_scan_instrs(body_instrs, target),
        )
      }
      @lib.If(_, then_body, else_body) => {
        scan = mp_passive_scan_merge(
          scan,
          mp_passive_user_scan_instrs(then_body, target),
        )
        match else_body {
          Some(body) =>
            scan = mp_passive_scan_merge(
              scan,
              mp_passive_user_scan_instrs(body, target),
            )
          None => ()
        }
      }
      _ => ()
    }
  }
  scan
}

///|
fn mp_passive_user_scan(mod_ : @lib.Module, target : Int) -> MpPassiveUserScan {
  let mut scan = MpPassiveUserScan::new()
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func_ in funcs {
        let @lib.Func(_, @lib.Expr(instrs)) = func_
        scan = mp_passive_scan_merge(
          scan,
          mp_passive_user_scan_instrs(instrs, target),
        )
      }
    None => ()
  }
  scan
}

///|
fn mp_passive_can_split(mod_ : @lib.Module, target : Int) -> Bool {
  let scan = mp_passive_user_scan(mod_, target)
  scan.has_memory_init && scan.all_memory_init_const && !scan.has_array_data
}

///|
fn mp_passive_split_parts(
  bytes : Bytes,
  first_new_idx : Int,
) -> (Array[MpSplitPart], Bool, Bool) {
  if bytes.length() == 0 {
    return ([], false, false)
  }
  let ranges = mp_merge_small_zero_ranges(mp_collect_ranges(bytes), 8)
  let parts : Array[MpSplitPart] = []
  let mut omitted_zero = false
  for range in ranges {
    if range.is_zero {
      omitted_zero = true
    } else if range.end_ > range.start {
      parts.push(
        MpSplitPart::new(
          range.start,
          range.end_,
          first_new_idx + parts.length(),
        ),
      )
    }
  }
  let fill_first = omitted_zero && (parts.is_empty() || parts[0].start > 0)
  (parts, omitted_zero, fill_first)
}

///|
fn mp_name_map_from_entries(entries : Array[@lib.NameAssoc]) -> @lib.NameMap? {
  if entries.is_empty() {
    None
  } else {
    Some(@lib.NameMap::new(entries))
  }
}

///|
fn mp_suffixed_data_name(name : @lib.Name, suffix : Int) -> @lib.Name {
  @lib.Name::from_string(mp_name_to_string(name) + "." + suffix.to_string())
}

///|
fn mp_append_data_name_entries(
  entries : Array[@lib.NameAssoc],
  name : @lib.Name?,
  first_new_idx : Int,
  count : Int,
) -> Unit {
  match name {
    Some(name) =>
      for suffix = 0; suffix < count; suffix = suffix + 1 {
        let next_name = if suffix == 0 {
          name
        } else {
          mp_suffixed_data_name(name, suffix)
        }
        entries.push(
          @lib.NameAssoc::new(
            (first_new_idx + suffix).reinterpret_as_uint(),
            next_name,
          ),
        )
      }
    None => ()
  }
}

///|
fn mp_rewrite_name_sec(
  name_sec : @lib.NameSec?,
  data_name_entries : Array[@lib.NameAssoc],
) -> @lib.NameSec? {
  match name_sec {
    Some(sec) => {
      let {
        module_name,
        func_names,
        local_names,
        label_names,
        type_names,
        table_names,
        memory_names,
        global_names,
        elem_names,
        data_names: _data_names,
        field_names,
        tag_names,
      } = sec
      let next = @lib.NameSec::new(
        module_name~,
        func_names~,
        local_names~,
        label_names~,
        type_names~,
        table_names~,
        memory_names~,
        global_names~,
        elem_names~,
        data_names=mp_name_map_from_entries(data_name_entries),
        field_names~,
        tag_names~,
      )
      if next.module_name is None &&
        next.func_names is None &&
        next.local_names is None &&
        next.label_names is None &&
        next.type_names is None &&
        next.table_names is None &&
        next.memory_names is None &&
        next.global_names is None &&
        next.elem_names is None &&
        next.data_names is None &&
        next.field_names is None &&
        next.tag_names is None {
        None
      } else {
        Some(next)
      }
    }
    None => None
  }
}

///|
fn mp_plan_data_idx(
  idx : @lib.DataIdx,
  plans : Array[MpSegmentPlan],
) -> @lib.DataIdx {
  let slot = mp_data_idx_slot(idx)
  if slot < 0 || slot >= plans.length() {
    return idx
  }
  let next = plans[slot].remap
  if next < 0 {
    return idx
  }
  @lib.DataIdx::new(next.reinterpret_as_uint())
}

///|
fn mp_data_idx_from_int(idx : Int) -> @lib.DataIdx {
  @lib.DataIdx::new(idx.reinterpret_as_uint())
}

///|
fn mp_local_idx_from_int(idx : Int) -> @lib.LocalIdx {
  @lib.LocalIdx::new(idx.reinterpret_as_uint())
}

///|
fn mp_i32_const(value : Int) -> @lib.Instruction {
  @lib.Instruction::i32_const(@lib.I32(value))
}

///|
fn mp_append_dest_with_delta(
  out : Array[@lib.Instruction],
  dest : @lib.Instruction,
  delta : Int,
  tmp : @lib.LocalIdx?,
) -> Unit {
  match tmp {
    Some(tmp_local) => out.push(@lib.Instruction::local_get(tmp_local))
    None =>
      match mp_instr_i32_const_value(dest) {
        Some(value) => {
          out.push(mp_i32_const(value + delta))
          return
        }
        None => out.push(dest)
      }
  }
  if delta != 0 {
    out.push(mp_i32_const(delta))
    out.push(@lib.Instruction::i32_add())
  }
}

///|
fn mp_emit_drop_state_check(
  out : Array[@lib.Instruction],
  global_idx : @lib.GlobalIdx,
) -> Unit {
  out.push(@lib.Instruction::global_get(global_idx))
  out.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
  )
}

///|
fn mp_emit_memory_fill(
  out : Array[@lib.Instruction],
  dest : @lib.Instruction,
  src_start : Int,
  fill_start : Int,
  fill_end : Int,
  mem_idx : @lib.MemIdx,
  tmp : @lib.LocalIdx?,
) -> Unit {
  let len = fill_end - fill_start
  if len <= 0 {
    return
  }
  mp_append_dest_with_delta(out, dest, fill_start - src_start, tmp)
  out.push(mp_i32_const(0))
  out.push(mp_i32_const(len))
  out.push(@lib.Instruction::memory_fill(mem_idx))
}

///|
fn mp_emit_memory_init_part(
  out : Array[@lib.Instruction],
  dest : @lib.Instruction,
  src_start : Int,
  copy_start : Int,
  copy_end : Int,
  part : MpSplitPart,
  mem_idx : @lib.MemIdx,
  tmp : @lib.LocalIdx?,
) -> Unit {
  let len = copy_end - copy_start
  if len <= 0 {
    return
  }
  mp_append_dest_with_delta(out, dest, copy_start - src_start, tmp)
  out.push(mp_i32_const(copy_start - part.start))
  out.push(mp_i32_const(len))
  out.push(
    @lib.Instruction::memory_init(mp_data_idx_from_int(part.data_idx), mem_idx),
  )
}

///|
fn mp_append_passive_memory_init_replacement(
  out : Array[@lib.Instruction],
  plan : MpSegmentPlan,
  dest : @lib.Instruction,
  src_start : Int,
  size : Int,
  mem_idx : @lib.MemIdx,
  tmp : @lib.LocalIdx?,
  global_idx : @lib.GlobalIdx?,
) -> Unit {
  if size <= 0 {
    out.push(@lib.Instruction::nop())
    return
  }
  let src_end = src_start + size
  let mut cursor = src_start
  let mut emitted = false
  for part in plan.split_parts {
    if part.end_ <= src_start {
      continue
    }
    if part.start >= src_end {
      break
    }
    let fill_end = if part.start < src_end { part.start } else { src_end }
    if cursor < fill_end {
      match global_idx {
        Some(gi) if !emitted => mp_emit_drop_state_check(out, gi)
        _ => ()
      }
      mp_emit_memory_fill(out, dest, src_start, cursor, fill_end, mem_idx, tmp)
      emitted = true
      cursor = fill_end
    }
    let copy_start = if cursor > part.start { cursor } else { part.start }
    let copy_end = if part.end_ < src_end { part.end_ } else { src_end }
    if copy_start < copy_end {
      mp_emit_memory_init_part(
        out, dest, src_start, copy_start, copy_end, part, mem_idx, tmp,
      )
      emitted = true
      cursor = copy_end
    }
  }
  if cursor < src_end {
    match global_idx {
      Some(gi) if !emitted => mp_emit_drop_state_check(out, gi)
      _ => ()
    }
    mp_emit_memory_fill(out, dest, src_start, cursor, src_end, mem_idx, tmp)
    emitted = true
  }
  if !emitted {
    out.push(@lib.Instruction::nop())
  }
}

///|
priv struct MpMemoryInitOperands {
  dest_instrs : Array[@lib.Instruction]
  src_instr : @lib.Instruction
  size_instr : @lib.Instruction
}

///|
fn MpMemoryInitOperands::new(
  dest_instrs : Array[@lib.Instruction],
  src_instr : @lib.Instruction,
  size_instr : @lib.Instruction,
) -> MpMemoryInitOperands {
  { dest_instrs, src_instr, size_instr }
}

///|
fn mp_block_type_result_count(block_type : @lib.BlockType) -> Int? {
  match block_type {
    @lib.VoidBlockType => Some(0)
    @lib.ValTypeBlockType(_) => Some(1)
    @lib.TypeIdxBlockType(_) => None
  }
}

///|
fn mp_instr_stack_counts(instr : @lib.Instruction) -> (Int, Int)? {
  match instr {
    @lib.Nop => Some((0, 0))
    @lib.Unreachable => Some((0, 1))
    @lib.Block(block_type, _)
    | @lib.Loop(block_type, _)
    | @lib.TryTable(block_type, _, _) =>
      match mp_block_type_result_count(block_type) {
        Some(results) => Some((0, results))
        None => None
      }
    @lib.If(block_type, _, _) =>
      match mp_block_type_result_count(block_type) {
        Some(results) => Some((1, results))
        None => None
      }
    @lib.Drop => Some((1, 0))
    @lib.Select(_) => Some((3, 1))
    @lib.LocalGet(_)
    | @lib.GlobalGet(_)
    | @lib.MemorySize(_)
    | @lib.RefNull(_)
    | @lib.RefFunc(_)
    | @lib.StringConst(_)
    | @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      Some((0, 1))
    @lib.LocalSet(_)
    | @lib.GlobalSet(_)
    | @lib.TableSet(_)
    | @lib.BrIf(_)
    | @lib.BrOnNull(_)
    | @lib.BrOnNonNull(_) => Some((1, 0))
    @lib.LocalTee(_)
    | @lib.MemoryGrow(_)
    | @lib.TableGet(_)
    | @lib.RefIsNull
    | @lib.RefAsNonNull
    | @lib.AnyConvertExtern
    | @lib.ExternConvertAny
    | @lib.RefI31
    | @lib.I31GetS
    | @lib.I31GetU
    | @lib.I32Eqz
    | @lib.I64Eqz
    | @lib.I32Clz
    | @lib.I32Ctz
    | @lib.I32Popcnt
    | @lib.I64Clz
    | @lib.I64Ctz
    | @lib.I64Popcnt
    | @lib.F32Abs
    | @lib.F32Neg
    | @lib.F32Ceil
    | @lib.F32Floor
    | @lib.F32Trunc
    | @lib.F32Nearest
    | @lib.F32Sqrt
    | @lib.F64Abs
    | @lib.F64Neg
    | @lib.F64Ceil
    | @lib.F64Floor
    | @lib.F64Trunc
    | @lib.F64Nearest
    | @lib.F64Sqrt
    | @lib.I32WrapI64
    | @lib.I32TruncF32S
    | @lib.I32TruncF32U
    | @lib.I32TruncF64S
    | @lib.I32TruncF64U
    | @lib.I64ExtendI32S
    | @lib.I64ExtendI32U
    | @lib.I64TruncF32S
    | @lib.I64TruncF32U
    | @lib.I64TruncF64S
    | @lib.I64TruncF64U
    | @lib.F32ConvertI32S
    | @lib.F32ConvertI32U
    | @lib.F32ConvertI64S
    | @lib.F32ConvertI64U
    | @lib.F32DemoteF64
    | @lib.F64ConvertI32S
    | @lib.F64ConvertI32U
    | @lib.F64ConvertI64S
    | @lib.F64ConvertI64U
    | @lib.F64PromoteF32
    | @lib.I32ReinterpretF32
    | @lib.I64ReinterpretF64
    | @lib.F32ReinterpretI32
    | @lib.F64ReinterpretI64
    | @lib.I32Extend8S
    | @lib.I32Extend16S
    | @lib.I64Extend8S
    | @lib.I64Extend16S
    | @lib.I64Extend32S
    | @lib.RefTest(_, _)
    | @lib.RefCast(_, _, _)
    | @lib.RefTestDesc(_, _)
    | @lib.RefCastDescEq(_, _, _)
    | @lib.I32TruncSatF32S
    | @lib.I32TruncSatF32U
    | @lib.I32TruncSatF64S
    | @lib.I32TruncSatF64U
    | @lib.I64TruncSatF32S
    | @lib.I64TruncSatF32U
    | @lib.I64TruncSatF64S
    | @lib.I64TruncSatF64U
    | @lib.I8x16Splat
    | @lib.I16x8Splat
    | @lib.I32x4Splat
    | @lib.I64x2Splat
    | @lib.F32x4Splat
    | @lib.F64x2Splat => Some((1, 1))
    @lib.I32Load(_)
    | @lib.I64Load(_)
    | @lib.F32Load(_)
    | @lib.F64Load(_)
    | @lib.I32Load8S(_)
    | @lib.I32Load8U(_)
    | @lib.I32Load16S(_)
    | @lib.I32Load16U(_)
    | @lib.I64Load8S(_)
    | @lib.I64Load8U(_)
    | @lib.I64Load16S(_)
    | @lib.I64Load16U(_)
    | @lib.I64Load32S(_)
    | @lib.I64Load32U(_)
    | @lib.I32AtomicLoad(_)
    | @lib.I64AtomicLoad(_)
    | @lib.I32AtomicLoad8U(_)
    | @lib.I32AtomicLoad16U(_)
    | @lib.I64AtomicLoad8U(_)
    | @lib.I64AtomicLoad16U(_)
    | @lib.I64AtomicLoad32U(_)
    | @lib.V128Load(_)
    | @lib.V128Load8x8S(_)
    | @lib.V128Load8x8U(_)
    | @lib.V128Load16x4S(_)
    | @lib.V128Load16x4U(_)
    | @lib.V128Load32x2S(_)
    | @lib.V128Load32x2U(_)
    | @lib.V128Load8Splat(_)
    | @lib.V128Load16Splat(_)
    | @lib.V128Load32Splat(_)
    | @lib.V128Load64Splat(_) => Some((1, 1))
    @lib.I32Eq
    | @lib.I32Ne
    | @lib.I32LtS
    | @lib.I32LtU
    | @lib.I32GtS
    | @lib.I32GtU
    | @lib.I32LeS
    | @lib.I32LeU
    | @lib.I32GeS
    | @lib.I32GeU
    | @lib.I64Eq
    | @lib.I64Ne
    | @lib.I64LtS
    | @lib.I64LtU
    | @lib.I64GtS
    | @lib.I64GtU
    | @lib.I64LeS
    | @lib.I64LeU
    | @lib.I64GeS
    | @lib.I64GeU
    | @lib.F32Eq
    | @lib.F32Ne
    | @lib.F32Lt
    | @lib.F32Gt
    | @lib.F32Le
    | @lib.F32Ge
    | @lib.F64Eq
    | @lib.F64Ne
    | @lib.F64Lt
    | @lib.F64Gt
    | @lib.F64Le
    | @lib.F64Ge
    | @lib.I32Add
    | @lib.I32Sub
    | @lib.I32Mul
    | @lib.I32DivS
    | @lib.I32DivU
    | @lib.I32RemS
    | @lib.I32RemU
    | @lib.I32And
    | @lib.I32Or
    | @lib.I32Xor
    | @lib.I32Shl
    | @lib.I32ShrS
    | @lib.I32ShrU
    | @lib.I32Rotl
    | @lib.I32Rotr
    | @lib.I64Add
    | @lib.I64Sub
    | @lib.I64Mul
    | @lib.I64DivS
    | @lib.I64DivU
    | @lib.I64RemS
    | @lib.I64RemU
    | @lib.I64And
    | @lib.I64Or
    | @lib.I64Xor
    | @lib.I64Shl
    | @lib.I64ShrS
    | @lib.I64ShrU
    | @lib.I64Rotl
    | @lib.I64Rotr
    | @lib.F32Add
    | @lib.F32Sub
    | @lib.F32Mul
    | @lib.F32Div
    | @lib.F32Min
    | @lib.F32Max
    | @lib.F32Copysign
    | @lib.F64Add
    | @lib.F64Sub
    | @lib.F64Mul
    | @lib.F64Div
    | @lib.F64Min
    | @lib.F64Max
    | @lib.F64Copysign
    | @lib.RefEq => Some((2, 1))
    @lib.I32Store(_)
    | @lib.I64Store(_)
    | @lib.F32Store(_)
    | @lib.F64Store(_)
    | @lib.I32Store8(_)
    | @lib.I32Store16(_)
    | @lib.I64Store8(_)
    | @lib.I64Store16(_)
    | @lib.I64Store32(_)
    | @lib.I32AtomicStore(_)
    | @lib.I64AtomicStore(_)
    | @lib.I32AtomicStore8(_)
    | @lib.I32AtomicStore16(_)
    | @lib.I64AtomicStore8(_)
    | @lib.I64AtomicStore16(_)
    | @lib.I64AtomicStore32(_)
    | @lib.V128Store(_) => Some((2, 0))
    @lib.MemoryFill(_)
    | @lib.MemoryInit(_, _)
    | @lib.ArrayFill(_)
    | @lib.ArrayInitData(_, _)
    | @lib.ArrayInitElem(_, _) => Some((3, 0))
    @lib.MemoryCopy(_, _) | @lib.TableCopy(_, _) | @lib.ArrayCopy(_, _) =>
      Some((3, 0))
    @lib.DataDrop(_) | @lib.ElemDrop(_) | @lib.AtomicFence => Some((0, 0))
    _ => None
  }
}

///|
fn mp_find_value_start(out : Array[@lib.Instruction], end_ : Int) -> Int? {
  let mut need = 1
  let mut idx = end_ - 1
  while idx >= 0 {
    let counts = match mp_instr_stack_counts(out[idx]) {
      Some(counts) => counts
      None => return None
    }
    let (params, results) = counts
    if results > need {
      return None
    }
    need = need - results + params
    if need == 0 {
      return Some(idx)
    }
    idx = idx - 1
  }
  None
}

///|
fn mp_pop_three_operands(
  out : Array[@lib.Instruction],
) -> MpMemoryInitOperands? {
  if out.length() < 3 {
    return None
  }
  let len = out.length()
  let src_instr = out[len - 2]
  let size_instr = out[len - 1]
  match
    (mp_instr_i32_const_value(src_instr), mp_instr_i32_const_value(size_instr)) {
    (Some(_), Some(_)) => ()
    _ => return None
  }
  let dest_start = match mp_find_value_start(out, len - 2) {
    Some(start) => start
    None => return None
  }
  let dest_instrs : Array[@lib.Instruction] = []
  for idx = dest_start; idx < len - 2; idx = idx + 1 {
    dest_instrs.push(out[idx])
  }
  while out.length() > dest_start {
    ignore(out.pop())
  }
  Some(MpMemoryInitOperands::new(dest_instrs, src_instr, size_instr))
}

///|
fn mp_append_memory_init_operand_eval(
  out : Array[@lib.Instruction],
  instrs : Array[@lib.Instruction],
) -> Unit {
  for instr in instrs {
    out.push(instr)
  }
  out.push(@lib.Instruction::drop())
}

///|
fn mp_append_consumed_memory_init_operands(
  out : Array[@lib.Instruction],
  operands : MpMemoryInitOperands,
) -> Unit {
  mp_append_memory_init_operand_eval(out, operands.dest_instrs)
  out.push(operands.src_instr)
  out.push(@lib.Instruction::drop())
  out.push(operands.size_instr)
  out.push(@lib.Instruction::drop())
}

///|
fn mp_memory_init_dest_is_i32_const(
  operands : MpMemoryInitOperands,
) -> @lib.Instruction? {
  match operands.dest_instrs {
    [instr] =>
      match mp_instr_i32_const_value(instr) {
        Some(_) => Some(instr)
        None => None
      }
    _ => None
  }
}

///|
fn mp_memory_init_dest_is_trap_only(operands : MpMemoryInitOperands) -> Bool {
  let mut has_unreachable = false
  for instr in operands.dest_instrs {
    match instr {
      @lib.Unreachable => has_unreachable = true
      @lib.Drop | @lib.Nop => ()
      _ => return false
    }
  }
  has_unreachable
}

///|
fn mp_append_memory_init_dest(
  out : Array[@lib.Instruction],
  operands : MpMemoryInitOperands,
) -> Unit {
  for instr in operands.dest_instrs {
    out.push(instr)
  }
}

///|
fn mp_rewrite_active_memory_init(
  out : Array[@lib.Instruction],
  plan : MpSegmentPlan,
) -> Bool {
  let operands = match mp_pop_three_operands(out) {
    Some(operands) => operands
    None => return false
  }
  let src = match mp_instr_i32_const_value(operands.src_instr) {
    Some(value) => value
    None => abort("expected constant memory.init source operand")
  }
  let size = match mp_instr_i32_const_value(operands.size_instr) {
    Some(value) => value
    None => abort("expected constant memory.init size operand")
  }
  if mp_memory_init_dest_is_trap_only(operands) {
    out.push(@lib.Instruction::unreachable_())
    return true
  }
  mp_append_consumed_memory_init_operands(out, operands)
  if src < 0 || size < 0 || src + size < src || src + size > plan.data_size {
    out.push(@lib.Instruction::unreachable_())
  } else {
    out.push(@lib.Instruction::nop())
  }
  true
}

///|
fn mp_rewrite_passive_split_memory_init(
  out : Array[@lib.Instruction],
  plan : MpSegmentPlan,
  locals : @lib.Locals,
  param_count : Int,
  mem_idx : @lib.MemIdx,
  global_idx : @lib.GlobalIdx?,
) -> Bool {
  let operands = match mp_pop_three_operands(out) {
    Some(operands) => operands
    None => return false
  }
  let src = match mp_instr_i32_const_value(operands.src_instr) {
    Some(value) => value
    None => abort("expected constant memory.init source operand")
  }
  let size = match mp_instr_i32_const_value(operands.size_instr) {
    Some(value) => value
    None => abort("expected constant memory.init size operand")
  }
  if mp_memory_init_dest_is_trap_only(operands) {
    out.push(@lib.Instruction::unreachable_())
    return true
  }
  if src < 0 || size < 0 || src + size < src || src + size > plan.data_size {
    mp_append_consumed_memory_init_operands(out, operands)
    out.push(@lib.Instruction::unreachable_())
    return true
  }
  let const_dest = mp_memory_init_dest_is_i32_const(operands)
  let dest = match const_dest {
    Some(instr) => instr
    None => mp_i32_const(0)
  }
  let tmp = match const_dest {
    Some(_) => None
    None => {
      let tmp_local = mp_local_idx_from_int(param_count + locals.length())
      locals.push(@lib.ValType::i32())
      mp_append_memory_init_dest(out, operands)
      out.push(@lib.Instruction::local_set(tmp_local))
      Some(tmp_local)
    }
  }
  let effective_global = if plan.needs_drop_state { global_idx } else { None }
  mp_append_passive_memory_init_replacement(
    out, plan, dest, src, size, mem_idx, tmp, effective_global,
  )
  true
}

///|
fn mp_append_split_data_drop(
  out : Array[@lib.Instruction],
  plan : MpSegmentPlan,
  global_idx : @lib.GlobalIdx?,
) -> Unit {
  if plan.needs_drop_state {
    match global_idx {
      Some(gi) => {
        out.push(mp_i32_const(1))
        out.push(@lib.Instruction::global_set(gi))
      }
      None => ()
    }
  }
  if plan.split_parts.is_empty() {
    out.push(@lib.Instruction::nop())
    return
  }
  for part in plan.split_parts {
    out.push(@lib.Instruction::data_drop(mp_data_idx_from_int(part.data_idx)))
  }
}

///|
fn mp_rewrite_instrs_full(
  instrs : Array[@lib.Instruction],
  plans : Array[MpSegmentPlan],
  locals : @lib.Locals,
  param_count : Int,
  global_idx : @lib.GlobalIdx?,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.Block(block_type, body) =>
        out.push(
          @lib.Instruction::block(
            block_type,
            mp_rewrite_expr_full(body, plans, locals, param_count, global_idx),
          ),
        )
      @lib.Loop(block_type, body) =>
        out.push(
          @lib.Instruction::loop_(
            block_type,
            mp_rewrite_expr_full(body, plans, locals, param_count, global_idx),
          ),
        )
      @lib.TryTable(block_type, catches, body) =>
        out.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            mp_rewrite_expr_full(body, plans, locals, param_count, global_idx),
          ),
        )
      @lib.If(block_type, then_body, else_body) => {
        let rewritten_then = mp_rewrite_instrs_full(
          then_body, plans, locals, param_count, global_idx,
        )
        let rewritten_else = match else_body {
          Some(body) =>
            Some(
              mp_rewrite_instrs_full(
                body, plans, locals, param_count, global_idx,
              ),
            )
          None => None
        }
        out.push(
          @lib.Instruction::if_(block_type, rewritten_then, rewritten_else),
        )
      }
      @lib.ArrayNewData(type_idx, idx) =>
        out.push(
          @lib.Instruction::array_new_data(
            type_idx,
            mp_plan_data_idx(idx, plans),
          ),
        )
      @lib.ArrayInitData(type_idx, idx) =>
        out.push(
          @lib.Instruction::array_init_data(
            type_idx,
            mp_plan_data_idx(idx, plans),
          ),
        )
      @lib.MemoryInit(idx, mem_idx) => {
        let slot = mp_data_idx_slot(idx)
        if slot >= 0 && slot < plans.length() {
          let plan = plans[slot]
          if plan.is_active {
            if !mp_rewrite_active_memory_init(out, plan) {
              out.push(
                @lib.Instruction::memory_init(
                  mp_plan_data_idx(idx, plans),
                  mem_idx,
                ),
              )
            }
          } else if plan.was_split {
            if !mp_rewrite_passive_split_memory_init(
                out, plan, locals, param_count, mem_idx, global_idx,
              ) {
              out.push(
                @lib.Instruction::memory_init(
                  mp_plan_data_idx(idx, plans),
                  mem_idx,
                ),
              )
            }
          } else {
            out.push(
              @lib.Instruction::memory_init(
                mp_plan_data_idx(idx, plans),
                mem_idx,
              ),
            )
          }
        } else {
          out.push(instr)
        }
      }
      @lib.DataDrop(idx) => {
        let slot = mp_data_idx_slot(idx)
        if slot >= 0 && slot < plans.length() {
          let plan = plans[slot]
          if plan.is_active || plan.remap < 0 {
            out.push(@lib.Instruction::nop())
          } else if plan.was_split {
            mp_append_split_data_drop(out, plan, global_idx)
          } else {
            out.push(@lib.Instruction::data_drop(mp_plan_data_idx(idx, plans)))
          }
        } else {
          out.push(instr)
        }
      }
      _ => out.push(instr)
    }
  }
  out
}

///|
fn mp_rewrite_expr_full(
  expr : @lib.Expr,
  plans : Array[MpSegmentPlan],
  locals : @lib.Locals,
  param_count : Int,
  global_idx : @lib.GlobalIdx?,
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  @lib.Expr::new(
    mp_rewrite_instrs_full(instrs, plans, locals, param_count, global_idx),
  )
}

///|
fn mp_rewrite_code_sec_full(
  mod_ : @lib.Module,
  plans : Array[MpSegmentPlan],
  global_idx : @lib.GlobalIdx?,
) -> @lib.CodeSec? {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let param_counts = mp_defined_func_param_counts(mod_)
      let rewritten : Array[@lib.Func] = []
      for i = 0; i < funcs.length(); i = i + 1 {
        let @lib.Func(locals, body) = funcs[i]
        let next_locals = locals.copy()
        let param_count = if i < param_counts.length() {
          param_counts[i]
        } else {
          0
        }
        rewritten.push(
          @lib.Func::new(
            next_locals,
            mp_rewrite_expr_full(
              body, plans, next_locals, param_count, global_idx,
            ),
          ),
        )
      }
      Some(@lib.CodeSec::new(rewritten))
    }
    None => None
  }
}

///|
fn mp_should_skip_data_rewrite(mod_ : @lib.Module, idx : Int) -> Bool {
  mp_data_name_has_prefix(mod_, idx, "__llvm")
}

///|
pub fn memory_packing_run_module_pass(
  mod_ : @lib.Module,
  traps_never_happen? : Bool = false,
  zero_filled_memory? : Bool = false,
) -> @lib.Module {
  let datas = match mod_.data_sec {
    Some(@lib.DataSec(datas)) => datas
    None => return mod_
  }
  if !mp_can_optimize(mod_, datas, zero_filled_memory) {
    return mod_
  }
  let needs_data_usage_scan = mp_needs_data_usage_scan(datas)
  let usages = if needs_data_usage_scan {
    mp_collect_data_usages(mod_, datas.length())
  } else {
    Array::make(datas.length(), MpDataUsage::new(false, false))
  }
  let data_remap = Array::make(datas.length(), -1)
  let plans = Array::make(
    datas.length(),
    MpSegmentPlan::new(-1, [], false, false, false, 0),
  )
  let rewritten : Array[@lib.Data] = []
  let data_name_entries : Array[@lib.NameAssoc] = []
  let mut changed = false
  let mut need_drop_state = false

  for idx = 0; idx < datas.length(); idx = idx + 1 {
    let data = datas[idx]
    match data {
      @lib.Data(@lib.Active(mem_idx, expr), bytes) => {
        let next = if mp_should_skip_data_rewrite(mod_, idx) {
          [data]
        } else {
          mp_active_rewrite(mod_, mem_idx, expr, bytes, traps_never_happen)
        }
        if next.length() != 1 || next[0] != data {
          changed = true
        }
        let remaining_original_count = datas.length() - idx - 1
        let next = if mp_data_segment_limit_exceeded(
            rewritten.length(),
            next.length(),
            remaining_original_count,
          ) {
          [data]
        } else {
          next
        }
        let first_new_idx = rewritten.length()
        data_remap[idx] = if next.is_empty() { -1 } else { first_new_idx }
        plans[idx] = MpSegmentPlan::new(
          data_remap[idx],
          [],
          true,
          false,
          false,
          bytes.length(),
        )
        for item in next {
          rewritten.push(item)
        }
        mp_append_data_name_entries(
          data_name_entries,
          mp_data_name_for_idx(mod_, idx),
          first_new_idx,
          next.length(),
        )
      }
      @lib.Data(@lib.Passive, bytes) => {
        let usage = usages[idx]
        if mp_should_skip_data_rewrite(mod_, idx) {
          data_remap[idx] = rewritten.length()
          plans[idx] = MpSegmentPlan::new(
            data_remap[idx],
            [],
            false,
            false,
            false,
            bytes.length(),
          )
          rewritten.push(data)
          mp_append_data_name_entries(
            data_name_entries,
            mp_data_name_for_idx(mod_, idx),
            data_remap[idx],
            1,
          )
        } else if !usage.has_non_drop {
          changed = true
          plans[idx] = MpSegmentPlan::new(
            -1,
            [],
            false,
            false,
            false,
            bytes.length(),
          )
        } else if mp_passive_can_split(mod_, idx) {
          let (parts, omitted_zero, fill_first) = mp_passive_split_parts(
            bytes,
            rewritten.length(),
          )
          if omitted_zero &&
            !mp_data_segment_limit_exceeded(
              rewritten.length(),
              parts.length(),
              datas.length() - idx - 1,
            ) {
            changed = true
            data_remap[idx] = if parts.is_empty() {
              -1
            } else {
              parts[0].data_idx
            }
            plans[idx] = MpSegmentPlan::new(
              data_remap[idx],
              parts,
              false,
              true,
              fill_first,
              bytes.length(),
            )
            if fill_first {
              need_drop_state = true
            }
            let first_new_idx = rewritten.length()
            for part in plans[idx].split_parts {
              rewritten.push(
                @lib.Data::new(
                  @lib.DataMode::passive(),
                  mp_slice_bytes(bytes, part.start, part.end_),
                ),
              )
            }
            mp_append_data_name_entries(
              data_name_entries,
              mp_data_name_for_idx(mod_, idx),
              first_new_idx,
              parts.length(),
            )
          } else {
            data_remap[idx] = rewritten.length()
            plans[idx] = MpSegmentPlan::new(
              data_remap[idx],
              [],
              false,
              false,
              false,
              bytes.length(),
            )
            rewritten.push(data)
            mp_append_data_name_entries(
              data_name_entries,
              mp_data_name_for_idx(mod_, idx),
              data_remap[idx],
              1,
            )
          }
        } else {
          data_remap[idx] = rewritten.length()
          plans[idx] = MpSegmentPlan::new(
            data_remap[idx],
            [],
            false,
            false,
            false,
            bytes.length(),
          )
          rewritten.push(data)
          mp_append_data_name_entries(
            data_name_entries,
            mp_data_name_for_idx(mod_, idx),
            data_remap[idx],
            1,
          )
        }
      }
    }
  }

  let (next_global_sec, drop_state_global) = mp_append_drop_state_global(
    mod_, need_drop_state,
  )
  if need_drop_state {
    changed = true
  }
  let next_code_sec = mp_rewrite_code_sec_full(mod_, plans, drop_state_global)
  if next_code_sec != mod_.code_sec {
    changed = true
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
  let next_name_sec = mp_rewrite_name_sec(mod_.name_sec, data_name_entries)
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
    global_sec=next_global_sec,
    export_sec=mod_.export_sec,
    start_sec=mod_.start_sec,
    elem_sec=mod_.elem_sec,
    data_cnt_sec=next_data_cnt_sec,
    code_sec=next_code_sec,
    data_sec=next_data_sec,
    name_sec=next_name_sec,
    raw_name_sec_payload=None,
  )
}

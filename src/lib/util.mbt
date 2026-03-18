///|
fn locals_run_length(run : LocalRun) -> Int {
  run.count.reinterpret_as_int()
}

///|
fn locals_normalize_runs(runs : Array[LocalRun]) -> Array[LocalRun] {
  let out : Array[LocalRun] = []
  for run in runs {
    let { count, vt } = run
    if count == 0U {
      continue
    }
    match out.last() {
      Some(last) if last.vt == vt =>
        out[out.length() - 1] = { count: last.count + count, vt }
      _ => out.push({ count, vt })
    }
  }
  out
}

///|
fn locals_build_indices(runs : Array[LocalRun]) -> Array[Int] {
  let out : Array[Int] = []
  let mut next = 0
  for run in runs {
    out.push(next)
    next += locals_run_length(run)
  }
  out
}

///|
fn locals_indices_match_runs(
  runs : Array[LocalRun],
  indices : Array[Int],
) -> Bool {
  if indices.length() != runs.length() {
    return false
  }
  let mut next = 0
  for i in 0..<runs.length() {
    if indices[i] != next {
      return false
    }
    next += locals_run_length(runs[i])
  }
  true
}

///|
fn locals_run_index(starts : Array[Int], idx : Int) -> Int {
  let mut lo = 0
  let mut hi = starts.length() - 1
  let mut best = -1
  while lo <= hi {
    let mid = lo + (hi - lo) / 2
    if starts[mid] <= idx {
      best = mid
      lo = mid + 1
    } else {
      hi = mid - 1
    }
  }
  best
}

///|
pub fn Locals::copy(self : Locals) -> Locals {
  {
    runs: self.runs.copy(),
    indices: match self.indices {
      Some(indices) => Some(indices.copy())
      None => None
    },
  }
}

///|
pub fn Locals::runs(self : Locals) -> Array[LocalRun] {
  self.runs.copy()
}

///|
pub fn Locals::run_count(self : Locals) -> Int {
  self.runs.length()
}

///|
pub fn Locals::ensure_index(self : Locals) -> Array[Int] {
  match self.indices {
    Some(indices) if locals_indices_match_runs(self.runs, indices) => indices
    _ => {
      let indices = locals_build_indices(self.runs)
      self.indices = Some(indices)
      indices
    }
  }
}

///|
pub fn Locals::invalidate_indices(self : Locals) -> Unit {
  self.indices = None
}

///|
pub fn Locals::length(self : Locals) -> Int {
  let starts = self.ensure_index()
  if starts.is_empty() {
    return 0
  }
  let last = self.runs[starts.length() - 1]
  starts[starts.length() - 1] + locals_run_length(last)
}

///|
pub fn Locals::is_empty(self : Locals) -> Bool {
  self.runs.is_empty()
}

///|
pub fn Locals::at(self : Locals, idx : Int) -> ValType? {
  if idx < 0 {
    return None
  }
  let starts = self.ensure_index()
  if starts.is_empty() {
    return None
  }
  let run_idx = locals_run_index(starts, idx)
  if run_idx < 0 {
    return None
  }
  let run = self.runs[run_idx]
  let start = starts[run_idx]
  let end_ = start + locals_run_length(run)
  if idx >= end_ {
    return None
  }
  Some(run.vt)
}

///|
pub fn Locals::unsafe_get(self : Locals, idx : Int) -> ValType {
  match self.at(idx) {
    Some(vt) => vt
    None => abort("locals index out of bounds")
  }
}

///|
#alias("_[_]")
pub fn Locals::get(self : Locals, idx : Int) -> ValType {
  self.unsafe_get(idx)
}

///|
pub fn Locals::iter(self : Locals) -> Iter[ValType] {
  let runs = self.runs.copy()
  let mut run_idx = 0
  let mut remaining = 0
  let mut current : ValType? = None
  Iter::new(fn() {
    while remaining == 0 {
      if run_idx >= runs.length() {
        return None
      }
      let run = runs[run_idx]
      run_idx += 1
      remaining = locals_run_length(run)
      current = Some(run.vt)
    }
    remaining -= 1
    current
  })
}

///|
pub fn Locals::push_run(self : Locals, run : LocalRun) -> Unit {
  if run.count == 0U {
    return
  }
  match self.runs.last() {
    Some(last) if last.vt == run.vt =>
      self.runs[self.runs.length() - 1] = {
        count: last.count + run.count,
        vt: last.vt,
      }
    _ => self.runs.push(run)
  }
  self.invalidate_indices()
}

///|
pub fn Locals::push(self : Locals, vt : ValType) -> Unit {
  self.push_run(LocalRun::new(1U, vt))
}

///|
pub fn Locals::append(self : Locals, other : Locals) -> Unit {
  for run in other.runs {
    self.push_run(run)
  }
}

///|
pub fn Locals::append_types(self : Locals, types : Array[ValType]) -> Unit {
  for vt in types {
    self.push(vt)
  }
}

///|
pub fn Locals::without_prefix(self : Locals, count : Int) -> Locals {
  if count <= 0 {
    return self.copy()
  }
  let out : Array[LocalRun] = []
  let mut remaining = count
  for run in self.runs {
    let len = locals_run_length(run)
    if remaining >= len {
      remaining -= len
      continue
    }
    if remaining > 0 {
      out.push({ count: (len - remaining).reinterpret_as_uint(), vt: run.vt })
      remaining = 0
    } else {
      out.push(run)
    }
  }
  Locals::new(out)
}

///|
pub fn Locals::insert_run(self : Locals, run_idx : Int, run : LocalRun) -> Unit {
  let bounded = if run_idx < 0 {
    0
  } else if run_idx > self.runs.length() {
    self.runs.length()
  } else {
    run_idx
  }
  let next : Array[LocalRun] = []
  for i in 0..<bounded {
    next.push(self.runs[i])
  }
  next.push(run)
  for i = bounded; i < self.runs.length(); i = i + 1 {
    next.push(self.runs[i])
  }
  self.runs = locals_normalize_runs(next)
  self.invalidate_indices()
}

///|
pub fn Locals::remove_run(self : Locals, run_idx : Int) -> LocalRun? {
  if run_idx < 0 || run_idx >= self.runs.length() {
    return None
  }
  let removed = self.runs[run_idx]
  let next : Array[LocalRun] = []
  for i in 0..<self.runs.length() {
    if i != run_idx {
      next.push(self.runs[i])
    }
  }
  self.runs = locals_normalize_runs(next)
  self.invalidate_indices()
  Some(removed)
}

///|
pub fn Locals::set_run_count(
  self : Locals,
  run_idx : Int,
  count : UInt,
) -> Bool {
  if run_idx < 0 || run_idx >= self.runs.length() {
    return false
  }
  self.runs[run_idx] = { ..self.runs[run_idx], count, }
  self.runs = locals_normalize_runs(self.runs)
  self.invalidate_indices()
  true
}

///|
pub fn Locals::merge_adjacent_runs(self : Locals) -> Unit {
  self.runs = locals_normalize_runs(self.runs)
  self.invalidate_indices()
}

///|
pub fn Locals::set(self : Locals, idx : Int, vt : ValType) -> Bool {
  if idx < 0 {
    return false
  }
  let next : Array[LocalRun] = []
  let mut found = false
  let mut start = 0
  for run in self.runs {
    let len = locals_run_length(run)
    let end_ = start + len
    if found || idx < start || idx >= end_ {
      next.push(run)
      start = end_
      continue
    }
    let left_len = idx - start
    let right_len = end_ - idx - 1
    if left_len > 0 {
      next.push({ count: left_len.reinterpret_as_uint(), vt: run.vt })
    }
    next.push({ count: 1U, vt })
    if right_len > 0 {
      next.push({ count: right_len.reinterpret_as_uint(), vt: run.vt })
    }
    found = true
    start = end_
  }
  if !found {
    return false
  }
  self.runs = locals_normalize_runs(next)
  self.invalidate_indices()
  true
}

///|
#cfg(target="native")
#borrow(tv)
extern "c" fn trace_native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="llvm")
#borrow(tv)
extern "c" fn trace_native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="native")
fn trace_read_u64_timeval(bytes : Bytes, start : Int) -> UInt64 {
  let mut out = 0UL
  let mut i = 0
  while i < 8 {
    out = out | (bytes[start + i].to_uint64() << (i * 8))
    i += 1
  }
  out
}

///|
#cfg(target="llvm")
fn trace_read_u64_timeval(bytes : Bytes, start : Int) -> UInt64 {
  let mut out = 0UL
  let mut i = 0
  while i < 8 {
    out = out | (bytes[start + i].to_uint64() << (i * 8))
    i += 1
  }
  out
}

///|
#cfg(target="native")
pub fn trace_now_us() -> UInt64 {
  let tv = Bytes::new(16)
  if trace_native_gettimeofday(tv, 0UL) != 0 {
    return @env.now() * 1000UL
  }
  let sec = trace_read_u64_timeval(tv, 0)
  let usec = trace_read_u64_timeval(tv, 8)
  sec * 1000000UL + usec
}

///|
#cfg(target="llvm")
pub fn trace_now_us() -> UInt64 {
  let tv = Bytes::new(16)
  if trace_native_gettimeofday(tv, 0UL) != 0 {
    return @env.now() * 1000UL
  }
  let sec = trace_read_u64_timeval(tv, 0)
  let usec = trace_read_u64_timeval(tv, 8)
  sec * 1000000UL + usec
}

///|
#cfg(target="wasm")
fn trace_wasm_now_ms() -> UInt64 = "__moonbit_time_unstable" "now"

///|
#cfg(target="wasm-gc")
fn trace_wasm_now_ms() -> UInt64 = "__moonbit_time_unstable" "now"

///|
#cfg(target="wasm")
pub fn trace_now_us() -> UInt64 {
  trace_wasm_now_ms() * 1000UL
}

///|
#cfg(target="wasm-gc")
pub fn trace_now_us() -> UInt64 {
  trace_wasm_now_ms() * 1000UL
}

///|
#cfg(target="js")
pub fn trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
pub fn trace_now_ms() -> UInt64 {
  trace_now_us() / 1000UL
}

///|
pub fn trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  let end_ms = trace_now_ms()
  if end_ms >= start_ms {
    end_ms - start_ms
  } else {
    0UL
  }
}

///|
pub fn trace_elapsed_us_since(start_us : UInt64) -> UInt64 {
  let end_us = trace_now_us()
  if end_us >= start_us {
    end_us - start_us
  } else {
    0UL
  }
}

///|
pub fn trace_delta_us_to_ms(delta_us : UInt64) -> UInt64 {
  delta_us / 1000UL
}

///|
pub struct FunctionLocals {
  params : Array[ValType]
  body_locals : Locals
  all_locals : Locals
} derive(Eq, Hash, Debug)

///|
pub fn FunctionLocals::new(
  params : Array[ValType],
  body_locals : Locals,
) -> FunctionLocals {
  let all_locals = Locals::from_types(params)
  all_locals.append(body_locals)
  { params: params.copy(), body_locals: body_locals.copy(), all_locals }
}

///|
pub fn FunctionLocals::from_typed_func(
  declared_params : Array[ValType],
  typed_params : Array[ValType],
  typed_body_locals : Locals,
) -> Result[FunctionLocals, String] {
  if typed_params != declared_params {
    return Err("typed function params must match declared signature exactly")
  }
  Ok(FunctionLocals::new(typed_params, typed_body_locals))
}

///|
pub fn FunctionLocals::from_typed_func_for_pass(
  declared_params : Array[ValType],
  typed_params : Array[ValType],
  typed_body_locals : Locals,
) -> Result[FunctionLocals, String] {
  let params = if typed_params.is_empty() {
    declared_params
  } else {
    typed_params
  }
  Ok(FunctionLocals::new(params, typed_body_locals))
}

///|
pub fn FunctionLocals::from_local_decls(
  params : Array[ValType],
  local_decls : Locals,
) -> Result[FunctionLocals, String] {
  for run in local_decls.runs() {
    if !has_default(run.vt) {
      return Err("local type has no default value")
    }
  }
  Ok(FunctionLocals::new(params, local_decls))
}

///|
pub fn FunctionLocals::params(self : FunctionLocals) -> Array[ValType] {
  self.params.copy()
}

///|
pub fn FunctionLocals::body_locals(self : FunctionLocals) -> Locals {
  self.body_locals.copy()
}

///|
pub fn FunctionLocals::all_locals(self : FunctionLocals) -> Locals {
  self.all_locals.copy()
}

///|
pub fn FunctionLocals::param_count(self : FunctionLocals) -> Int {
  self.params.length()
}

///|
pub fn FunctionLocals::local_type(
  self : FunctionLocals,
  idx : LocalIdx,
) -> ValType? {
  let LocalIdx(raw) = idx
  self.all_locals.at(raw.reinterpret_as_int())
}

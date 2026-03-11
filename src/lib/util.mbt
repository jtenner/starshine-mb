///|
pub fn expand_locals(decls : Array[Locals]) -> Result[Array[ValType], String] {
  let out : Array[ValType] = []
  for d in decls {
    let Locals(n, vt) = d
    let count = n.reinterpret_as_int()
    if count < 0 {
      return Err("locals: negative count")
    }
    for _ in 0..<count {
      out.push(vt)
    }
  }
  Ok(out)
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
  body_locals : Array[ValType]
  all_locals : Array[ValType]
} derive(Eq, Hash, Debug)

///|
pub fn FunctionLocals::new(
  params : Array[ValType],
  body_locals : Array[ValType],
) -> FunctionLocals {
  let all_locals = params.copy()
  for vt in body_locals {
    all_locals.push(vt)
  }
  { params: params.copy(), body_locals: body_locals.copy(), all_locals }
}

///|
pub fn FunctionLocals::from_typed_func(
  declared_params : Array[ValType],
  typed_params : Array[ValType],
  typed_body_locals : Array[ValType],
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
  typed_body_locals : Array[ValType],
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
  local_decls : Array[Locals],
) -> Result[FunctionLocals, String] {
  let body_locals = match expand_locals(local_decls) {
    Ok(locals) => locals
    Err(e) => return Err(e)
  }
  for vt in body_locals {
    if !has_default(vt) {
      return Err("local type has no default value")
    }
  }
  Ok(FunctionLocals::new(params, body_locals))
}

///|
pub fn FunctionLocals::params(self : FunctionLocals) -> Array[ValType] {
  self.params.copy()
}

///|
pub fn FunctionLocals::body_locals(self : FunctionLocals) -> Array[ValType] {
  self.body_locals.copy()
}

///|
pub fn FunctionLocals::all_locals(self : FunctionLocals) -> Array[ValType] {
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
  self.all_locals.get(raw.reinterpret_as_int())
}

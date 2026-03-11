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
#cfg(target="native")
#borrow(tv)
extern "c" fn pass_trace_native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="llvm")
#borrow(tv)
extern "c" fn pass_trace_native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="native")
fn pass_trace_read_u64_timeval(bytes : Bytes, start : Int) -> UInt64 {
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
fn pass_trace_read_u64_timeval(bytes : Bytes, start : Int) -> UInt64 {
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
fn pass_trace_now_us() -> UInt64 {
  let tv = Bytes::new(16)
  if pass_trace_native_gettimeofday(tv, 0UL) != 0 {
    return @env.now() * 1000UL
  }
  let sec = pass_trace_read_u64_timeval(tv, 0)
  let usec = pass_trace_read_u64_timeval(tv, 8)
  sec * 1000000UL + usec
}

///|
#cfg(target="llvm")
fn pass_trace_now_us() -> UInt64 {
  let tv = Bytes::new(16)
  if pass_trace_native_gettimeofday(tv, 0UL) != 0 {
    return @env.now() * 1000UL
  }
  let sec = pass_trace_read_u64_timeval(tv, 0)
  let usec = pass_trace_read_u64_timeval(tv, 8)
  sec * 1000000UL + usec
}

///|
#cfg(target="wasm")
fn pass_trace_wasm_now_ms() -> UInt64 = "__moonbit_time_unstable" "now"

///|
#cfg(target="wasm-gc")
fn pass_trace_wasm_now_ms() -> UInt64 = "__moonbit_time_unstable" "now"

///|
#cfg(target="wasm")
fn pass_trace_now_us() -> UInt64 {
  pass_trace_wasm_now_ms() * 1000UL
}

///|
#cfg(target="wasm-gc")
fn pass_trace_now_us() -> UInt64 {
  pass_trace_wasm_now_ms() * 1000UL
}

///|
#cfg(target="js")
fn pass_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
fn pass_trace_now_ms() -> UInt64 {
  pass_trace_now_us() / 1000UL
}

///|
fn pass_trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  let end_ms = pass_trace_now_ms()
  if end_ms >= start_ms {
    end_ms - start_ms
  } else {
    0UL
  }
}

///|
fn pass_trace_elapsed_us_since(start_us : UInt64) -> UInt64 {
  let end_us = pass_trace_now_us()
  if end_us >= start_us {
    end_us - start_us
  } else {
    0UL
  }
}

///|
fn pass_trace_delta_us_to_ms(delta_us : UInt64) -> UInt64 {
  delta_us / 1000UL
}

///|
fn pass_trace_log_enabled(ordinal : Int, trace_all_funcs : Bool) -> Bool {
  ignore(ordinal)
  trace_all_funcs
}

///|
pub struct SquareMatrix[T] {
  storage : Map[UInt64, T]
  n : UInt
}

///|
fn[T] SquareMatrix::new(size? : UInt = 0) -> Self[T] {
  SquareMatrix::{
    storage: Map::new(capacity=(size * size).reinterpret_as_int()),
    n: size,
  }
}

///|
fn[T] SquareMatrix::get_or(
  self : SquareMatrix[T],
  or : T,
  x : UInt,
  y : UInt,
) -> Result[T, String] {
  let n = self.n
  if x >= n || y >= n {
    return Err("Index out of bounds")
  }
  let index = x.to_uint64() * n.to_uint64() + y.to_uint64()
  if self.storage.get(index) is Some(t) {
    Ok(t)
  } else {
    Ok(or)
  }
}

///|
fn uses(instr : TInstr) -> Set[LocalIdx] {
  let result = Set::new()
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      i : TInstr,
    ) {
      match i.kind {
        TInstrKind::TLocalGet(idx) => result.add(idx)
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), i))
    },
  )
  ignore(walker.walk_texpr_default((), TExpr::new([instr])))
  result
}

///|
fn defs(instr : TInstr) -> Set[LocalIdx] {
  let result = Set::new()
  match instr.kind {
    TInstrKind::TLocalSet(idx, _) => result.add(idx)
    _ => ()
  }
  result
}

///|
fn wrap_unit_func_pass(
  pass : ModuleTransformer[Unit, String],
) -> ModuleTransformer[IRContext, String] {
  ModuleTransformer::new().on_func_evt(fn(_, ctx : IRContext, func : Func) {
    match pass.walk_func((), func) {
      Ok((new_func, _)) => change(ctx, new_func)
      Err(e) => error(e)
    }
  })
}

///|
test "liveness: local.get is a use" {
  let x = LocalIdx::new(0)
  let instr = TInstr::local_get(x)
  let u = uses(instr)
  let d = defs(instr)
  assert_true(u.contains(x))
  assert_true(d.is_empty())
}

///|
test "liveness: local.set defines and value may use" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instr = TInstr::local_set(x, TInstr::local_get(y))
  let u = uses(instr)
  let d = defs(instr)
  assert_true(d.contains(x))
  assert_true(!d.contains(y))
  assert_true(u.contains(y))
  assert_true(!u.contains(x))
}

///|
test "liveness: nested expressions propagate uses" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instr = TInstr::unary(
    UnaryOp::i32_eqz(),
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::local_get(x),
      TInstr::local_get(y),
    ),
  )
  let u = uses(instr)
  let d = defs(instr)
  assert_true(u.contains(x))
  assert_true(u.contains(y))
  assert_true(d.is_empty())
}

///|
test "SquareMatrix::get_or returns bounds error" {
  let matrix : SquareMatrix[Int] = SquareMatrix::new(size=2)
  match matrix.get_or(0, 2, 0) {
    Ok(_) => fail("expected out-of-bounds access to return error")
    Err(e) => assert_eq(e, "Index out of bounds")
  }
}

///|
test "wrap_unit_func_pass propagates wrapped pass errors" {
  let bad = ModuleTransformer::new().on_func_evt(fn(_, _, _ : Func) {
    error("boom")
  })
  let wrapped = wrap_unit_func_pass(bad)
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], TExpr::new([TInstr::nop()]))]),
  )
  let ctx = IRContext::new()
  match wrapped.walk_module(ctx, mod) {
    Err(e) => assert_eq(e, "boom")
    _ => fail("expected wrapped pass error to propagate")
  }
}

///|
test "pass_trace_delta_us_to_ms floors microseconds to milliseconds" {
  assert_eq(pass_trace_delta_us_to_ms(0UL), 0UL)
  assert_eq(pass_trace_delta_us_to_ms(999UL), 0UL)
  assert_eq(pass_trace_delta_us_to_ms(1000UL), 1UL)
  assert_eq(pass_trace_delta_us_to_ms(2501UL), 2UL)
}

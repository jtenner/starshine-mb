///|
/// Linear-memory atomic operators. Memory indices and orders are independent
/// immediates; access alignment follows the access width even for memory64.
pub enum MemoryAtomicOp {
  I32AtomicLoad
  I64AtomicLoad
  I32AtomicLoad8U
  I32AtomicLoad16U
  I64AtomicLoad8U
  I64AtomicLoad16U
  I64AtomicLoad32U
  I32AtomicStore
  I64AtomicStore
  I32AtomicStore8
  I32AtomicStore16
  I64AtomicStore8
  I64AtomicStore16
  I64AtomicStore32
  I32AtomicRmwAdd
  I64AtomicRmwAdd
  I32AtomicRmw8AddU
  I32AtomicRmw16AddU
  I64AtomicRmw8AddU
  I64AtomicRmw16AddU
  I64AtomicRmw32AddU
  I32AtomicRmwSub
  I64AtomicRmwSub
  I32AtomicRmw8SubU
  I32AtomicRmw16SubU
  I64AtomicRmw8SubU
  I64AtomicRmw16SubU
  I64AtomicRmw32SubU
  I32AtomicRmwAnd
  I64AtomicRmwAnd
  I32AtomicRmw8AndU
  I32AtomicRmw16AndU
  I64AtomicRmw8AndU
  I64AtomicRmw16AndU
  I64AtomicRmw32AndU
  I32AtomicRmwOr
  I64AtomicRmwOr
  I32AtomicRmw8OrU
  I32AtomicRmw16OrU
  I64AtomicRmw8OrU
  I64AtomicRmw16OrU
  I64AtomicRmw32OrU
  I32AtomicRmwXor
  I64AtomicRmwXor
  I32AtomicRmw8XorU
  I32AtomicRmw16XorU
  I64AtomicRmw8XorU
  I64AtomicRmw16XorU
  I64AtomicRmw32XorU
  I32AtomicRmwXchg
  I64AtomicRmwXchg
  I32AtomicRmw8XchgU
  I32AtomicRmw16XchgU
  I64AtomicRmw8XchgU
  I64AtomicRmw16XchgU
  I64AtomicRmw32XchgU
  I32AtomicRmwCmpxchg
  I64AtomicRmwCmpxchg
  I32AtomicRmw8CmpxchgU
  I32AtomicRmw16CmpxchgU
  I64AtomicRmw8CmpxchgU
  I64AtomicRmw16CmpxchgU
  I64AtomicRmw32CmpxchgU
  MemoryAtomicNotify
  MemoryAtomicWait32
  MemoryAtomicWait64
} derive(Eq, Debug)

///|
fn memory_atomic_keyword(op : MemoryAtomicOp) -> String {
  match op {
    I32AtomicLoad => "i32.atomic.load"
    I64AtomicLoad => "i64.atomic.load"
    I32AtomicLoad8U => "i32.atomic.load8_u"
    I32AtomicLoad16U => "i32.atomic.load16_u"
    I64AtomicLoad8U => "i64.atomic.load8_u"
    I64AtomicLoad16U => "i64.atomic.load16_u"
    I64AtomicLoad32U => "i64.atomic.load32_u"
    I32AtomicStore => "i32.atomic.store"
    I64AtomicStore => "i64.atomic.store"
    I32AtomicStore8 => "i32.atomic.store8"
    I32AtomicStore16 => "i32.atomic.store16"
    I64AtomicStore8 => "i64.atomic.store8"
    I64AtomicStore16 => "i64.atomic.store16"
    I64AtomicStore32 => "i64.atomic.store32"
    I32AtomicRmwAdd => "i32.atomic.rmw.add"
    I64AtomicRmwAdd => "i64.atomic.rmw.add"
    I32AtomicRmw8AddU => "i32.atomic.rmw8.add_u"
    I32AtomicRmw16AddU => "i32.atomic.rmw16.add_u"
    I64AtomicRmw8AddU => "i64.atomic.rmw8.add_u"
    I64AtomicRmw16AddU => "i64.atomic.rmw16.add_u"
    I64AtomicRmw32AddU => "i64.atomic.rmw32.add_u"
    I32AtomicRmwSub => "i32.atomic.rmw.sub"
    I64AtomicRmwSub => "i64.atomic.rmw.sub"
    I32AtomicRmw8SubU => "i32.atomic.rmw8.sub_u"
    I32AtomicRmw16SubU => "i32.atomic.rmw16.sub_u"
    I64AtomicRmw8SubU => "i64.atomic.rmw8.sub_u"
    I64AtomicRmw16SubU => "i64.atomic.rmw16.sub_u"
    I64AtomicRmw32SubU => "i64.atomic.rmw32.sub_u"
    I32AtomicRmwAnd => "i32.atomic.rmw.and"
    I64AtomicRmwAnd => "i64.atomic.rmw.and"
    I32AtomicRmw8AndU => "i32.atomic.rmw8.and_u"
    I32AtomicRmw16AndU => "i32.atomic.rmw16.and_u"
    I64AtomicRmw8AndU => "i64.atomic.rmw8.and_u"
    I64AtomicRmw16AndU => "i64.atomic.rmw16.and_u"
    I64AtomicRmw32AndU => "i64.atomic.rmw32.and_u"
    I32AtomicRmwOr => "i32.atomic.rmw.or"
    I64AtomicRmwOr => "i64.atomic.rmw.or"
    I32AtomicRmw8OrU => "i32.atomic.rmw8.or_u"
    I32AtomicRmw16OrU => "i32.atomic.rmw16.or_u"
    I64AtomicRmw8OrU => "i64.atomic.rmw8.or_u"
    I64AtomicRmw16OrU => "i64.atomic.rmw16.or_u"
    I64AtomicRmw32OrU => "i64.atomic.rmw32.or_u"
    I32AtomicRmwXor => "i32.atomic.rmw.xor"
    I64AtomicRmwXor => "i64.atomic.rmw.xor"
    I32AtomicRmw8XorU => "i32.atomic.rmw8.xor_u"
    I32AtomicRmw16XorU => "i32.atomic.rmw16.xor_u"
    I64AtomicRmw8XorU => "i64.atomic.rmw8.xor_u"
    I64AtomicRmw16XorU => "i64.atomic.rmw16.xor_u"
    I64AtomicRmw32XorU => "i64.atomic.rmw32.xor_u"
    I32AtomicRmwXchg => "i32.atomic.rmw.xchg"
    I64AtomicRmwXchg => "i64.atomic.rmw.xchg"
    I32AtomicRmw8XchgU => "i32.atomic.rmw8.xchg_u"
    I32AtomicRmw16XchgU => "i32.atomic.rmw16.xchg_u"
    I64AtomicRmw8XchgU => "i64.atomic.rmw8.xchg_u"
    I64AtomicRmw16XchgU => "i64.atomic.rmw16.xchg_u"
    I64AtomicRmw32XchgU => "i64.atomic.rmw32.xchg_u"
    I32AtomicRmwCmpxchg => "i32.atomic.rmw.cmpxchg"
    I64AtomicRmwCmpxchg => "i64.atomic.rmw.cmpxchg"
    I32AtomicRmw8CmpxchgU => "i32.atomic.rmw8.cmpxchg_u"
    I32AtomicRmw16CmpxchgU => "i32.atomic.rmw16.cmpxchg_u"
    I64AtomicRmw8CmpxchgU => "i64.atomic.rmw8.cmpxchg_u"
    I64AtomicRmw16CmpxchgU => "i64.atomic.rmw16.cmpxchg_u"
    I64AtomicRmw32CmpxchgU => "i64.atomic.rmw32.cmpxchg_u"
    MemoryAtomicNotify => "memory.atomic.notify"
    MemoryAtomicWait32 => "memory.atomic.wait32"
    MemoryAtomicWait64 => "memory.atomic.wait64"
  }
}

///|
fn memory_atomic_width(op : MemoryAtomicOp) -> UInt64 {
  match op {
    I32AtomicLoad => 4UL
    I64AtomicLoad => 8UL
    I32AtomicLoad8U => 1UL
    I32AtomicLoad16U => 2UL
    I64AtomicLoad8U => 1UL
    I64AtomicLoad16U => 2UL
    I64AtomicLoad32U => 4UL
    I32AtomicStore => 4UL
    I64AtomicStore => 8UL
    I32AtomicStore8 => 1UL
    I32AtomicStore16 => 2UL
    I64AtomicStore8 => 1UL
    I64AtomicStore16 => 2UL
    I64AtomicStore32 => 4UL
    I32AtomicRmwAdd => 4UL
    I64AtomicRmwAdd => 8UL
    I32AtomicRmw8AddU => 1UL
    I32AtomicRmw16AddU => 2UL
    I64AtomicRmw8AddU => 1UL
    I64AtomicRmw16AddU => 2UL
    I64AtomicRmw32AddU => 4UL
    I32AtomicRmwSub => 4UL
    I64AtomicRmwSub => 8UL
    I32AtomicRmw8SubU => 1UL
    I32AtomicRmw16SubU => 2UL
    I64AtomicRmw8SubU => 1UL
    I64AtomicRmw16SubU => 2UL
    I64AtomicRmw32SubU => 4UL
    I32AtomicRmwAnd => 4UL
    I64AtomicRmwAnd => 8UL
    I32AtomicRmw8AndU => 1UL
    I32AtomicRmw16AndU => 2UL
    I64AtomicRmw8AndU => 1UL
    I64AtomicRmw16AndU => 2UL
    I64AtomicRmw32AndU => 4UL
    I32AtomicRmwOr => 4UL
    I64AtomicRmwOr => 8UL
    I32AtomicRmw8OrU => 1UL
    I32AtomicRmw16OrU => 2UL
    I64AtomicRmw8OrU => 1UL
    I64AtomicRmw16OrU => 2UL
    I64AtomicRmw32OrU => 4UL
    I32AtomicRmwXor => 4UL
    I64AtomicRmwXor => 8UL
    I32AtomicRmw8XorU => 1UL
    I32AtomicRmw16XorU => 2UL
    I64AtomicRmw8XorU => 1UL
    I64AtomicRmw16XorU => 2UL
    I64AtomicRmw32XorU => 4UL
    I32AtomicRmwXchg => 4UL
    I64AtomicRmwXchg => 8UL
    I32AtomicRmw8XchgU => 1UL
    I32AtomicRmw16XchgU => 2UL
    I64AtomicRmw8XchgU => 1UL
    I64AtomicRmw16XchgU => 2UL
    I64AtomicRmw32XchgU => 4UL
    I32AtomicRmwCmpxchg => 4UL
    I64AtomicRmwCmpxchg => 8UL
    I32AtomicRmw8CmpxchgU => 1UL
    I32AtomicRmw16CmpxchgU => 2UL
    I64AtomicRmw8CmpxchgU => 1UL
    I64AtomicRmw16CmpxchgU => 2UL
    I64AtomicRmw32CmpxchgU => 4UL
    MemoryAtomicNotify => 4UL
    MemoryAtomicWait32 => 4UL
    MemoryAtomicWait64 => 8UL
  }
}

///|
fn register_memory_atomic_keywords(
  map : @hashmap.HashMap[String, TokenType],
) -> Unit {
  map["i32.atomic.load"] = Opcode(MemoryAtomic(I32AtomicLoad))
  map["i64.atomic.load"] = Opcode(MemoryAtomic(I64AtomicLoad))
  map["i32.atomic.load8_u"] = Opcode(MemoryAtomic(I32AtomicLoad8U))
  map["i32.atomic.load16_u"] = Opcode(MemoryAtomic(I32AtomicLoad16U))
  map["i64.atomic.load8_u"] = Opcode(MemoryAtomic(I64AtomicLoad8U))
  map["i64.atomic.load16_u"] = Opcode(MemoryAtomic(I64AtomicLoad16U))
  map["i64.atomic.load32_u"] = Opcode(MemoryAtomic(I64AtomicLoad32U))
  map["i32.atomic.store"] = Opcode(MemoryAtomic(I32AtomicStore))
  map["i64.atomic.store"] = Opcode(MemoryAtomic(I64AtomicStore))
  map["i32.atomic.store8"] = Opcode(MemoryAtomic(I32AtomicStore8))
  map["i32.atomic.store16"] = Opcode(MemoryAtomic(I32AtomicStore16))
  map["i64.atomic.store8"] = Opcode(MemoryAtomic(I64AtomicStore8))
  map["i64.atomic.store16"] = Opcode(MemoryAtomic(I64AtomicStore16))
  map["i64.atomic.store32"] = Opcode(MemoryAtomic(I64AtomicStore32))
  map["i32.atomic.rmw.add"] = Opcode(MemoryAtomic(I32AtomicRmwAdd))
  map["i64.atomic.rmw.add"] = Opcode(MemoryAtomic(I64AtomicRmwAdd))
  map["i32.atomic.rmw8.add_u"] = Opcode(MemoryAtomic(I32AtomicRmw8AddU))
  map["i32.atomic.rmw16.add_u"] = Opcode(MemoryAtomic(I32AtomicRmw16AddU))
  map["i64.atomic.rmw8.add_u"] = Opcode(MemoryAtomic(I64AtomicRmw8AddU))
  map["i64.atomic.rmw16.add_u"] = Opcode(MemoryAtomic(I64AtomicRmw16AddU))
  map["i64.atomic.rmw32.add_u"] = Opcode(MemoryAtomic(I64AtomicRmw32AddU))
  map["i32.atomic.rmw.sub"] = Opcode(MemoryAtomic(I32AtomicRmwSub))
  map["i64.atomic.rmw.sub"] = Opcode(MemoryAtomic(I64AtomicRmwSub))
  map["i32.atomic.rmw8.sub_u"] = Opcode(MemoryAtomic(I32AtomicRmw8SubU))
  map["i32.atomic.rmw16.sub_u"] = Opcode(MemoryAtomic(I32AtomicRmw16SubU))
  map["i64.atomic.rmw8.sub_u"] = Opcode(MemoryAtomic(I64AtomicRmw8SubU))
  map["i64.atomic.rmw16.sub_u"] = Opcode(MemoryAtomic(I64AtomicRmw16SubU))
  map["i64.atomic.rmw32.sub_u"] = Opcode(MemoryAtomic(I64AtomicRmw32SubU))
  map["i32.atomic.rmw.and"] = Opcode(MemoryAtomic(I32AtomicRmwAnd))
  map["i64.atomic.rmw.and"] = Opcode(MemoryAtomic(I64AtomicRmwAnd))
  map["i32.atomic.rmw8.and_u"] = Opcode(MemoryAtomic(I32AtomicRmw8AndU))
  map["i32.atomic.rmw16.and_u"] = Opcode(MemoryAtomic(I32AtomicRmw16AndU))
  map["i64.atomic.rmw8.and_u"] = Opcode(MemoryAtomic(I64AtomicRmw8AndU))
  map["i64.atomic.rmw16.and_u"] = Opcode(MemoryAtomic(I64AtomicRmw16AndU))
  map["i64.atomic.rmw32.and_u"] = Opcode(MemoryAtomic(I64AtomicRmw32AndU))
  map["i32.atomic.rmw.or"] = Opcode(MemoryAtomic(I32AtomicRmwOr))
  map["i64.atomic.rmw.or"] = Opcode(MemoryAtomic(I64AtomicRmwOr))
  map["i32.atomic.rmw8.or_u"] = Opcode(MemoryAtomic(I32AtomicRmw8OrU))
  map["i32.atomic.rmw16.or_u"] = Opcode(MemoryAtomic(I32AtomicRmw16OrU))
  map["i64.atomic.rmw8.or_u"] = Opcode(MemoryAtomic(I64AtomicRmw8OrU))
  map["i64.atomic.rmw16.or_u"] = Opcode(MemoryAtomic(I64AtomicRmw16OrU))
  map["i64.atomic.rmw32.or_u"] = Opcode(MemoryAtomic(I64AtomicRmw32OrU))
  map["i32.atomic.rmw.xor"] = Opcode(MemoryAtomic(I32AtomicRmwXor))
  map["i64.atomic.rmw.xor"] = Opcode(MemoryAtomic(I64AtomicRmwXor))
  map["i32.atomic.rmw8.xor_u"] = Opcode(MemoryAtomic(I32AtomicRmw8XorU))
  map["i32.atomic.rmw16.xor_u"] = Opcode(MemoryAtomic(I32AtomicRmw16XorU))
  map["i64.atomic.rmw8.xor_u"] = Opcode(MemoryAtomic(I64AtomicRmw8XorU))
  map["i64.atomic.rmw16.xor_u"] = Opcode(MemoryAtomic(I64AtomicRmw16XorU))
  map["i64.atomic.rmw32.xor_u"] = Opcode(MemoryAtomic(I64AtomicRmw32XorU))
  map["i32.atomic.rmw.xchg"] = Opcode(MemoryAtomic(I32AtomicRmwXchg))
  map["i64.atomic.rmw.xchg"] = Opcode(MemoryAtomic(I64AtomicRmwXchg))
  map["i32.atomic.rmw8.xchg_u"] = Opcode(MemoryAtomic(I32AtomicRmw8XchgU))
  map["i32.atomic.rmw16.xchg_u"] = Opcode(MemoryAtomic(I32AtomicRmw16XchgU))
  map["i64.atomic.rmw8.xchg_u"] = Opcode(MemoryAtomic(I64AtomicRmw8XchgU))
  map["i64.atomic.rmw16.xchg_u"] = Opcode(MemoryAtomic(I64AtomicRmw16XchgU))
  map["i64.atomic.rmw32.xchg_u"] = Opcode(MemoryAtomic(I64AtomicRmw32XchgU))
  map["i32.atomic.rmw.cmpxchg"] = Opcode(MemoryAtomic(I32AtomicRmwCmpxchg))
  map["i64.atomic.rmw.cmpxchg"] = Opcode(MemoryAtomic(I64AtomicRmwCmpxchg))
  map["i32.atomic.rmw8.cmpxchg_u"] = Opcode(MemoryAtomic(I32AtomicRmw8CmpxchgU))
  map["i32.atomic.rmw16.cmpxchg_u"] = Opcode(
    MemoryAtomic(I32AtomicRmw16CmpxchgU),
  )
  map["i64.atomic.rmw8.cmpxchg_u"] = Opcode(MemoryAtomic(I64AtomicRmw8CmpxchgU))
  map["i64.atomic.rmw16.cmpxchg_u"] = Opcode(
    MemoryAtomic(I64AtomicRmw16CmpxchgU),
  )
  map["i64.atomic.rmw32.cmpxchg_u"] = Opcode(
    MemoryAtomic(I64AtomicRmw32CmpxchgU),
  )
  map["memory.atomic.notify"] = Opcode(MemoryAtomic(MemoryAtomicNotify))
  map["memory.atomic.wait32"] = Opcode(MemoryAtomic(MemoryAtomicWait32))
  map["memory.atomic.wait64"] = Opcode(MemoryAtomic(MemoryAtomicWait64))
  map["atomic.fence"] = Opcode(AtomicFence)
}

///|
fn WastParser::parse_memory_atomic(
  self : WastParser,
  op : MemoryAtomicOp,
) -> Instruction {
  let memory = self.try_parse_index()
  let order = match op {
    MemoryAtomicNotify | MemoryAtomicWait32 | MemoryAtomicWait64 => SeqCst
    _ => self.try_parse_atomic_order().unwrap_or(SeqCst)
  }
  MemoryAtomic(op, order, memory, self.parse_mem_arg(memory_atomic_width(op)))
}

///|
fn render_memory_atomic(
  op : MemoryAtomicOp,
  order : AtomicOrder,
  memory : Index?,
  memarg : MemArg,
) -> String {
  let index = match memory {
    Some(index) => " \{index_text(index)}"
    None => ""
  }
  let ordering = match op {
    MemoryAtomicNotify | MemoryAtomicWait32 | MemoryAtomicWait64 => ""
    _ => if order == SeqCst { "" } else { " \{atomic_order_text(order)}" }
  }
  "\{memory_atomic_keyword(op)}\{index}\{ordering}\{render_memarg(memarg)}"
}

///|
fn wt_memory_atomic(
  ctx : WTLowerCtx,
  op : MemoryAtomicOp,
  order : AtomicOrder,
  memory : Index?,
  memarg : MemArg,
) -> Result[@lib.Instruction, String] {
  let base = match wt_mem_arg(memarg) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let @lib.MemArg(align, _, offset) = base
  let memory : @lib.MemIdx? = match memory {
    None => None
    Some(index) =>
      match
        wt_resolve_named_or_num_index(
          index,
          ctx.mem_ids,
          ctx.next_mem_idx,
          "memory",
        ) {
        Ok(value) => Some(@lib.MemIdx::new(value))
        Err(err) => return Err(err)
      }
  }
  let ma = @lib.MemArg::new(align, memory, offset)
  Ok(
    match op {
      I32AtomicLoad =>
        @lib.Instruction::i32_atomic_load(ma, order=wt_atomic_order(order))
      I64AtomicLoad =>
        @lib.Instruction::i64_atomic_load(ma, order=wt_atomic_order(order))
      I32AtomicLoad8U =>
        @lib.Instruction::i32_atomic_load8_u(ma, order=wt_atomic_order(order))
      I32AtomicLoad16U =>
        @lib.Instruction::i32_atomic_load16_u(ma, order=wt_atomic_order(order))
      I64AtomicLoad8U =>
        @lib.Instruction::i64_atomic_load8_u(ma, order=wt_atomic_order(order))
      I64AtomicLoad16U =>
        @lib.Instruction::i64_atomic_load16_u(ma, order=wt_atomic_order(order))
      I64AtomicLoad32U =>
        @lib.Instruction::i64_atomic_load32_u(ma, order=wt_atomic_order(order))
      I32AtomicStore =>
        @lib.Instruction::i32_atomic_store(ma, order=wt_atomic_order(order))
      I64AtomicStore =>
        @lib.Instruction::i64_atomic_store(ma, order=wt_atomic_order(order))
      I32AtomicStore8 =>
        @lib.Instruction::i32_atomic_store8(ma, order=wt_atomic_order(order))
      I32AtomicStore16 =>
        @lib.Instruction::i32_atomic_store16(ma, order=wt_atomic_order(order))
      I64AtomicStore8 =>
        @lib.Instruction::i64_atomic_store8(ma, order=wt_atomic_order(order))
      I64AtomicStore16 =>
        @lib.Instruction::i64_atomic_store16(ma, order=wt_atomic_order(order))
      I64AtomicStore32 =>
        @lib.Instruction::i64_atomic_store32(ma, order=wt_atomic_order(order))
      I32AtomicRmwAdd =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_add(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmwAdd =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_add(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmw8AddU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_8_add_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmw16AddU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_16_add_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw8AddU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_8_add_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw16AddU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_16_add_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw32AddU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_32_add_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmwSub =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_sub(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmwSub =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_sub(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmw8SubU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_8_sub_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmw16SubU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_16_sub_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw8SubU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_8_sub_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw16SubU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_16_sub_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw32SubU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_32_sub_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmwAnd =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_and(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmwAnd =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_and(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmw8AndU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_8_and_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmw16AndU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_16_and_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw8AndU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_8_and_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw16AndU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_16_and_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw32AndU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_32_and_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmwOr =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_or(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmwOr =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_or(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmw8OrU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_8_or_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmw16OrU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_16_or_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw8OrU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_8_or_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw16OrU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_16_or_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw32OrU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_32_or_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmwXor =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_xor(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmwXor =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_xor(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmw8XorU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_8_xor_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmw16XorU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_16_xor_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw8XorU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_8_xor_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw16XorU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_16_xor_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw32XorU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_32_xor_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmwXchg =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_xchg(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmwXchg =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_xchg(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmw8XchgU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_8_xchg_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmw16XchgU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i32_16_xchg_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw8XchgU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_8_xchg_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw16XchgU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_16_xchg_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw32XchgU =>
        @lib.Instruction::atomic_rmw(
          @lib.AtomicRmwOp::i64_32_xchg_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmwCmpxchg =>
        @lib.Instruction::atomic_cmpxchg(
          @lib.AtomicCmpxchgOp::i32(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmwCmpxchg =>
        @lib.Instruction::atomic_cmpxchg(
          @lib.AtomicCmpxchgOp::i64(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmw8CmpxchgU =>
        @lib.Instruction::atomic_cmpxchg(
          @lib.AtomicCmpxchgOp::i32_8_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I32AtomicRmw16CmpxchgU =>
        @lib.Instruction::atomic_cmpxchg(
          @lib.AtomicCmpxchgOp::i32_16_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw8CmpxchgU =>
        @lib.Instruction::atomic_cmpxchg(
          @lib.AtomicCmpxchgOp::i64_8_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw16CmpxchgU =>
        @lib.Instruction::atomic_cmpxchg(
          @lib.AtomicCmpxchgOp::i64_16_u(),
          ma,
          order=wt_atomic_order(order),
        )
      I64AtomicRmw32CmpxchgU =>
        @lib.Instruction::atomic_cmpxchg(
          @lib.AtomicCmpxchgOp::i64_32_u(),
          ma,
          order=wt_atomic_order(order),
        )
      MemoryAtomicNotify => @lib.Instruction::memory_atomic_notify(ma)
      MemoryAtomicWait32 => @lib.Instruction::memory_atomic_wait32(ma)
      MemoryAtomicWait64 => @lib.Instruction::memory_atomic_wait64(ma)
    },
  )
}

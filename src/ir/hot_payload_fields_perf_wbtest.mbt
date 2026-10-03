///|
// Preserve the original by-value selector boundary in the reference.
fn payload_fields_owned_selector(node : HotNode) -> SideTableId? {
  match node.op {
    HotOp::Load
    | HotOp::Store
    | HotOp::RefTest
    | HotOp::RefCast
    | HotOp::RefTestDesc
    | HotOp::RefCastDescEq
    | HotOp::BrOnCast
    | HotOp::BrOnCastFail => Some(node.imm1)
    HotOp::Select
    | HotOp::Heap
    | HotOp::Continuation
    | HotOp::Unary
    | HotOp::Binary
    | HotOp::Compare
    | HotOp::Convert
    | HotOp::StringOp
    | HotOp::Simd => Some(node.imm0)
    HotOp::Atomic => Some(node.imm1)
    _ => None
  }
}

///|
fn payload_fields_owned_reference(func : HotFunc, id : NodeId) -> SideTableId? {
  payload_fields_owned_selector(hot_node_get(func, id))
}

///|
fn payload_fields_bench(
  it : @bench.T,
  width : Int,
  present : Bool,
  owned : Bool,
  query : Int,
) -> Unit raise {
  let func = HotFunc::new()
  let payload = hot_alloc_instr_payload(
    func,
    HotInstrPayload::new(@lib.Instruction::i32_add()),
  )
  let ids : Array[NodeId] = []
  for i in 0..<width {
    let id = hot_build_nop(func)
    // Isolated payload-query records; this is not a full-function typing fixture.
    let op = if !present {
      HotOp::Nop
    } else if i % 2 == 0 {
      HotOp::Binary
    } else {
      HotOp::Load
    }
    hot_node_set(func, id, {
      ..hot_node_get(func, id),
      op,
      imm0: payload,
      imm1: payload,
    })
    ids.push(id)
  }
  for id in ids {
    assert_eq(
      hot_node_exact_instr_payload_id(func, id),
      payload_fields_owned_reference(func, id),
    )
    assert_eq(
      hot_node_exact_instr(func, id),
      if present {
        Some(@lib.Instruction::i32_add())
      } else {
        None
      },
    )
    assert_true(hot_verify_node_exact_instr_payload(func, id))
  }
  let revision = hot_revision_current(func)
  it.bench(fn() {
    for id in ids {
      // Each query has its own lane; no repeated query is combined or reused.
      if query == 0 {
        it.keep(
          if owned {
            payload_fields_owned_reference(func, id)
          } else {
            hot_node_exact_instr_payload_id(func, id)
          },
        )
      } else if query == 1 {
        it.keep(
          if owned {
            match payload_fields_owned_reference(func, id) {
              Some(p) => Some(hot_instr_payload_get(func, p).instr)
              None => None
            }
          } else {
            hot_node_exact_instr(func, id)
          },
        )
      } else {
        it.keep(
          if owned {
            match payload_fields_owned_reference(func, id) {
              Some(p) => p >= 0 && p < func.instr_payloads.length()
              None => true
            }
          } else {
            hot_verify_node_exact_instr_payload(func, id)
          },
        )
      }
    }
  })
  assert_eq(hot_revision_current(func), revision)
}

///|
test "bench exact payload tiny payload id owned" (it : @bench.T) {
  payload_fields_bench(it, 1, true, true, 0)
}

///|
test "bench exact payload tiny payload id fields" (it : @bench.T) {
  payload_fields_bench(it, 1, true, false, 0)
}

///|
test "bench exact payload tiny payload instruction owned" (it : @bench.T) {
  payload_fields_bench(it, 1, true, true, 1)
}

///|
test "bench exact payload tiny payload instruction fields" (it : @bench.T) {
  payload_fields_bench(it, 1, true, false, 1)
}

///|
test "bench exact payload tiny payload verify owned" (it : @bench.T) {
  payload_fields_bench(it, 1, true, true, 2)
}

///|
test "bench exact payload tiny payload verify fields" (it : @bench.T) {
  payload_fields_bench(it, 1, true, false, 2)
}

///|
test "bench exact payload tiny absent id owned" (it : @bench.T) {
  payload_fields_bench(it, 1, false, true, 0)
}

///|
test "bench exact payload tiny absent id fields" (it : @bench.T) {
  payload_fields_bench(it, 1, false, false, 0)
}

///|
test "bench exact payload tiny absent instruction owned" (it : @bench.T) {
  payload_fields_bench(it, 1, false, true, 1)
}

///|
test "bench exact payload tiny absent instruction fields" (it : @bench.T) {
  payload_fields_bench(it, 1, false, false, 1)
}

///|
test "bench exact payload tiny absent verify owned" (it : @bench.T) {
  payload_fields_bench(it, 1, false, true, 2)
}

///|
test "bench exact payload tiny absent verify fields" (it : @bench.T) {
  payload_fields_bench(it, 1, false, false, 2)
}

///|
test "bench exact payload wide payload id owned" (it : @bench.T) {
  payload_fields_bench(it, 128, true, true, 0)
}

///|
test "bench exact payload wide payload id fields" (it : @bench.T) {
  payload_fields_bench(it, 128, true, false, 0)
}

///|
test "bench exact payload wide payload instruction owned" (it : @bench.T) {
  payload_fields_bench(it, 128, true, true, 1)
}

///|
test "bench exact payload wide payload instruction fields" (it : @bench.T) {
  payload_fields_bench(it, 128, true, false, 1)
}

///|
test "bench exact payload wide payload verify owned" (it : @bench.T) {
  payload_fields_bench(it, 128, true, true, 2)
}

///|
test "bench exact payload wide payload verify fields" (it : @bench.T) {
  payload_fields_bench(it, 128, true, false, 2)
}

///|
test "bench exact payload wide absent id owned" (it : @bench.T) {
  payload_fields_bench(it, 128, false, true, 0)
}

///|
test "bench exact payload wide absent id fields" (it : @bench.T) {
  payload_fields_bench(it, 128, false, false, 0)
}

///|
test "bench exact payload wide absent instruction owned" (it : @bench.T) {
  payload_fields_bench(it, 128, false, true, 1)
}

///|
test "bench exact payload wide absent instruction fields" (it : @bench.T) {
  payload_fields_bench(it, 128, false, false, 1)
}

///|
test "bench exact payload wide absent verify owned" (it : @bench.T) {
  payload_fields_bench(it, 128, false, true, 2)
}

///|
test "bench exact payload wide absent verify fields" (it : @bench.T) {
  payload_fields_bench(it, 128, false, false, 2)
}

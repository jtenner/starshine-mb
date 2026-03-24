///|
pub const HOT_FLAG_TERMINATOR : UInt = 1U

///|
pub const HOT_FLAG_CONTROL : UInt = 2U

///|
pub const HOT_FLAG_SIDE_EFFECT : UInt = 4U

///|
pub const HOT_FLAG_VALUE : UInt = 8U

///|
pub const HOT_FLAG_MAY_TRAP : UInt = 16U

///|
pub const HOT_FLAG_BRANCH : UInt = 32U

///|
pub const HOT_FLAG_CALL : UInt = 64U

///|
pub const HOT_FLAG_LOAD : UInt = 128U

///|
pub const HOT_FLAG_STORE : UInt = 256U

///|
pub const HOT_FLAG_THROWS : UInt = 512U

///|
pub const HOT_FLAG_HAS_EXCEPTIONAL_SUCC : UInt = 1024U

///|
fn hot_flags_include(bits : UInt, flag : UInt) -> Bool {
  (bits & flag) == flag
}

///|
pub fn hot_default_flags_for_op(op : HotOp) -> UInt {
  match op {
    HotOp::Nop => 0U
    HotOp::Unreachable => HOT_FLAG_TERMINATOR
    HotOp::Block | HotOp::Loop | HotOp::If | HotOp::Try | HotOp::TryTable =>
      HOT_FLAG_CONTROL
    HotOp::Br | HotOp::BrTable => HOT_FLAG_BRANCH | HOT_FLAG_TERMINATOR
    HotOp::BrIf
    | HotOp::BrOnNull
    | HotOp::BrOnNonNull
    | HotOp::BrOnCast
    | HotOp::BrOnCastFail => HOT_FLAG_BRANCH
    HotOp::Return => HOT_FLAG_TERMINATOR | HOT_FLAG_SIDE_EFFECT
    HotOp::Call | HotOp::CallIndirect | HotOp::CallRef =>
      HOT_FLAG_CALL |
      HOT_FLAG_SIDE_EFFECT |
      HOT_FLAG_MAY_TRAP |
      HOT_FLAG_HAS_EXCEPTIONAL_SUCC
    HotOp::ReturnCall | HotOp::ReturnCallIndirect | HotOp::ReturnCallRef =>
      HOT_FLAG_CALL |
      HOT_FLAG_SIDE_EFFECT |
      HOT_FLAG_MAY_TRAP |
      HOT_FLAG_HAS_EXCEPTIONAL_SUCC |
      HOT_FLAG_TERMINATOR
    HotOp::LocalGet
    | HotOp::GlobalGet
    | HotOp::Const
    | HotOp::Select
    | HotOp::RefNull
    | HotOp::RefIsNull
    | HotOp::RefFunc
    | HotOp::RefGetDesc
    | HotOp::RefTest
    | HotOp::RefTestDesc
    | HotOp::Unary
    | HotOp::Binary
    | HotOp::Compare
    | HotOp::Convert
    | HotOp::TupleMake
    | HotOp::TupleExtract
    | HotOp::StringOp => HOT_FLAG_VALUE
    HotOp::RefCast | HotOp::RefCastDescEq => HOT_FLAG_VALUE | HOT_FLAG_MAY_TRAP
    HotOp::Heap => HOT_FLAG_VALUE | HOT_FLAG_SIDE_EFFECT | HOT_FLAG_MAY_TRAP
    HotOp::LocalSet | HotOp::GlobalSet | HotOp::Drop => HOT_FLAG_SIDE_EFFECT
    HotOp::LocalTee => HOT_FLAG_SIDE_EFFECT | HOT_FLAG_VALUE
    HotOp::Load => HOT_FLAG_VALUE | HOT_FLAG_MAY_TRAP | HOT_FLAG_LOAD
    HotOp::Store => HOT_FLAG_SIDE_EFFECT | HOT_FLAG_MAY_TRAP | HOT_FLAG_STORE
    HotOp::MemorySize => HOT_FLAG_VALUE
    HotOp::MemoryGrow => HOT_FLAG_SIDE_EFFECT | HOT_FLAG_VALUE
    HotOp::MemoryCopy
    | HotOp::MemoryFill
    | HotOp::MemoryInit
    | HotOp::TableSet
    | HotOp::TableFill
    | HotOp::TableCopy
    | HotOp::TableInit =>
      HOT_FLAG_SIDE_EFFECT | HOT_FLAG_MAY_TRAP | HOT_FLAG_STORE
    HotOp::DataDrop | HotOp::ElemDrop => HOT_FLAG_SIDE_EFFECT
    HotOp::TableGet => HOT_FLAG_VALUE | HOT_FLAG_MAY_TRAP | HOT_FLAG_LOAD
    HotOp::TableSize => HOT_FLAG_VALUE
    HotOp::TableGrow => HOT_FLAG_SIDE_EFFECT | HOT_FLAG_VALUE
    HotOp::Throw | HotOp::Rethrow | HotOp::ThrowRef =>
      HOT_FLAG_SIDE_EFFECT |
      HOT_FLAG_THROWS |
      HOT_FLAG_HAS_EXCEPTIONAL_SUCC |
      HOT_FLAG_TERMINATOR
    HotOp::Delegate | HotOp::Catch | HotOp::CatchAll => 0U
    HotOp::Atomic | HotOp::Simd => 0U
  }
}

///|
pub fn hot_node_flags(func : HotFunc, node_id : NodeId) -> UInt {
  func.nodes[node_id].flags
}

///|
pub fn hot_node_has_flag(func : HotFunc, node_id : NodeId, flag : UInt) -> Bool {
  hot_flags_include(hot_node_flags(func, node_id), flag)
}

///|
pub fn hot_is_control_node(func : HotFunc, node_id : NodeId) -> Bool {
  hot_node_has_flag(func, node_id, HOT_FLAG_CONTROL)
}

///|
pub fn hot_is_terminator_node(func : HotFunc, node_id : NodeId) -> Bool {
  hot_node_has_flag(func, node_id, HOT_FLAG_TERMINATOR)
}

///|
pub fn hot_has_side_effect(func : HotFunc, node_id : NodeId) -> Bool {
  hot_node_has_flag(func, node_id, HOT_FLAG_SIDE_EFFECT)
}

///|
pub fn hot_may_trap(func : HotFunc, node_id : NodeId) -> Bool {
  hot_node_has_flag(func, node_id, HOT_FLAG_MAY_TRAP)
}

///|
pub fn hot_is_branch(func : HotFunc, node_id : NodeId) -> Bool {
  hot_node_has_flag(func, node_id, HOT_FLAG_BRANCH)
}

///|
pub fn hot_has_exceptional_succ(func : HotFunc, node_id : NodeId) -> Bool {
  hot_node_has_flag(func, node_id, HOT_FLAG_HAS_EXCEPTIONAL_SUCC)
}

///|
pub fn hot_node_may_throw_exception(func : HotFunc, node_id : NodeId) -> Bool {
  hot_node_has_flag(func, node_id, HOT_FLAG_THROWS) ||
  hot_has_exceptional_succ(func, node_id)
}

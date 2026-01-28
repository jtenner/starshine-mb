///|
struct NodeUsers {
  users : Map[NodeId, Array[NodeId]]
}

///|
pub fn NodeUsers::new() -> Self {
  { users: Map::new() }
}

///|
pub fn NodeUsers::add_user(self : Self, value : NodeId, user : NodeId) -> Unit {
  let arr = self.users.get_or_init(value, fn() { [] })
  arr.push(user)
}

///|
pub fn NodeUsers::remove_user(
  self : Self,
  value : NodeId,
  user : NodeId,
) -> Unit {
  match self.users.get(value) {
    Some(arr) =>
      for i = arr.length() - 1; i >= 0; i = i - 1 {
        if arr[i] == user {
          arr.remove(i) |> ignore
        }
      }
    None => ()
  }
}

///|
pub fn NodeUsers::remove_all_uses_of(self : Self, node : NodeId) -> Unit {
  self.users.remove(node)
}

///|
pub fn NodeUsers::get_users(self : Self, node : NodeId) -> Array[NodeId] {
  self.users.get(node).unwrap_or([])
}

///|
pub fn NodeUsers::num_uses(self : Self, node : NodeId) -> Int {
  self.get_users(node).length()
}

///|
pub fn NodeUsers::build(graph : Graph) -> Self {
  let u = NodeUsers::new()
  for node in graph.node_store.nodes {
    for v in node.values {
      u.add_user(v, node.id)
    }
  }
  u
}

///|
fn all_inputs_identical(node : Node) -> Bool {
  if node.values.length() <= 1 {
    return true
  }
  let first = node.values[0]
  for v in node.values {
    if v != first {
      return false
    }
  }
  true
}

///|
fn all_inputs_constant(graph : Graph, node : Node) -> Bool {
  for v in node.values {
    match graph.node_store.get(v) {
      Some(n) if not(n.is_const()) => return false
      None => return false
      _ => ()
    }
  }
  true
}

///|
fn[T : Eq + Hash] set_pop_any(s : @set.Set[T]) -> T {
  let it = s.iter()
  let v = it.next().unwrap()
  s.remove(v)
  v
}

///|
fn replace_all_uses(
  graph : Graph,
  users : NodeUsers,
  from : NodeId,
  to : NodeId,
  work : @set.Set[NodeId],
) -> Unit {
  if from == to {
    return
  }
  for user in users.get_users(from) {
    work.add(user)
    let n = match graph.node_store.get_mut(user) {
      Some(n) => n
      None => continue
    }
    for i in 0..<n.values.length() {
      if n.values[i] == from {
        n.values[i] = to
        users.add_user(to, user)
      }
    }
  }
  users.remove_all_uses_of(from)
}

///|
fn eval_unary(op : DataFlowUnaryOp, lit : DataFlowLiteral) -> DataFlowLiteral? {
  match (op, lit) {
    // i32 operations
    (EqZInt32, LitI32(x)) =>
      Some(DataFlowLiteral::i32(if x == 0 { 1 } else { 0 }))
    (ClzInt32, LitI32(x)) => Some(DataFlowLiteral::i32(x.clz()))
    (CtzInt32, LitI32(x)) => Some(DataFlowLiteral::i32(x.ctz()))
    (PopcntInt32, LitI32(x)) => Some(DataFlowLiteral::i32(x.popcnt()))
    // i64 operations
    (EqZInt64, LitI64(x)) =>
      Some(DataFlowLiteral::i32(if x == 0L { 1 } else { 0 }))
    (ClzInt64, LitI64(x)) => Some(DataFlowLiteral::i64(x.clz().to_int64()))
    (CtzInt64, LitI64(x)) => Some(DataFlowLiteral::i64(x.ctz().to_int64()))
    (PopcntInt64, LitI64(x)) =>
      Some(DataFlowLiteral::i64(x.popcnt().to_int64()))
    // Conversions
    (ExtendSInt32, LitI32(x)) => Some(DataFlowLiteral::i64(x.to_int64()))
    (ExtendUInt32, LitI32(x)) =>
      Some(
        DataFlowLiteral::i64(
          x.reinterpret_as_uint().to_uint64().reinterpret_as_int64(),
        ),
      )
    (WrapInt64, LitI64(x)) => Some(DataFlowLiteral::i32(x.to_int()))
    // f32 operations
    (NegFloat32, LitF32(x)) => Some(DataFlowLiteral::f32(-x))
    (AbsFloat32, LitF32(x)) => Some(DataFlowLiteral::f32(x.abs()))
    // f64 operations
    (NegFloat64, LitF64(x)) => Some(DataFlowLiteral::f64(-x))
    (AbsFloat64, LitF64(x)) => Some(DataFlowLiteral::f64(x.abs()))
    _ => None
  }
}

///|
fn eval_binary(
  op : DataFlowBinaryOp,
  a : DataFlowLiteral,
  b : DataFlowLiteral,
) -> DataFlowLiteral? {
  match (op, a, b) {
    // i32 arithmetic
    (AddInt32, LitI32(x), LitI32(y)) => Some(DataFlowLiteral::i32(x + y))
    (SubInt32, LitI32(x), LitI32(y)) => Some(DataFlowLiteral::i32(x - y))
    (MulInt32, LitI32(x), LitI32(y)) => Some(DataFlowLiteral::i32(x * y))
    (DivSInt32, LitI32(x), LitI32(y)) if y != 0 =>
      Some(DataFlowLiteral::i32(x / y))
    (DivUInt32, LitI32(x), LitI32(y)) if y != 0 => {
      let xu = x.reinterpret_as_uint()
      let yu = y.reinterpret_as_uint()
      Some(DataFlowLiteral::i32((xu / yu).reinterpret_as_int()))
    }
    (RemSInt32, LitI32(x), LitI32(y)) if y != 0 =>
      Some(DataFlowLiteral::i32(x % y))
    (RemUInt32, LitI32(x), LitI32(y)) if y != 0 => {
      let xu = x.reinterpret_as_uint()
      let yu = y.reinterpret_as_uint()
      Some(DataFlowLiteral::i32((xu % yu).reinterpret_as_int()))
    }
    // i32 bitwise
    (AndInt32, LitI32(x), LitI32(y)) => Some(DataFlowLiteral::i32(x & y))
    (OrInt32, LitI32(x), LitI32(y)) => Some(DataFlowLiteral::i32(x | y))
    (XorInt32, LitI32(x), LitI32(y)) => Some(DataFlowLiteral::i32(x ^ y))
    (ShlInt32, LitI32(x), LitI32(y)) =>
      Some(DataFlowLiteral::i32(x << (y & 31)))
    (ShrSInt32, LitI32(x), LitI32(y)) =>
      Some(DataFlowLiteral::i32(x >> (y & 31)))
    (ShrUInt32, LitI32(x), LitI32(y)) =>
      Some(
        DataFlowLiteral::i32(
          (x.reinterpret_as_uint() >> (y & 31)).reinterpret_as_int(),
        ),
      )
    (RotLInt32, LitI32(x), LitI32(y)) => {
      let k = y & 31
      let xu = x.reinterpret_as_uint()
      Some(
        DataFlowLiteral::i32(
          ((xu << k) | (xu >> (32 - k))).reinterpret_as_int(),
        ),
      )
    }
    (RotRInt32, LitI32(x), LitI32(y)) => {
      let k = y & 31
      let xu = x.reinterpret_as_uint()
      Some(
        DataFlowLiteral::i32(
          ((xu >> k) | (xu << (32 - k))).reinterpret_as_int(),
        ),
      )
    }
    // i32 comparisons
    (EqInt32, LitI32(x), LitI32(y)) =>
      Some(DataFlowLiteral::i32(if x == y { 1 } else { 0 }))
    (NeInt32, LitI32(x), LitI32(y)) =>
      Some(DataFlowLiteral::i32(if x != y { 1 } else { 0 }))
    (LtSInt32, LitI32(x), LitI32(y)) =>
      Some(DataFlowLiteral::i32(if x < y { 1 } else { 0 }))
    (LtUInt32, LitI32(x), LitI32(y)) =>
      Some(
        DataFlowLiteral::i32(
          if x.reinterpret_as_uint() < y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    (LeSInt32, LitI32(x), LitI32(y)) =>
      Some(DataFlowLiteral::i32(if x <= y { 1 } else { 0 }))
    (LeUInt32, LitI32(x), LitI32(y)) =>
      Some(
        DataFlowLiteral::i32(
          if x.reinterpret_as_uint() <= y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    (GtSInt32, LitI32(x), LitI32(y)) =>
      Some(DataFlowLiteral::i32(if x > y { 1 } else { 0 }))
    (GtUInt32, LitI32(x), LitI32(y)) =>
      Some(
        DataFlowLiteral::i32(
          if x.reinterpret_as_uint() > y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    (GeSInt32, LitI32(x), LitI32(y)) =>
      Some(DataFlowLiteral::i32(if x >= y { 1 } else { 0 }))
    (GeUInt32, LitI32(x), LitI32(y)) =>
      Some(
        DataFlowLiteral::i32(
          if x.reinterpret_as_uint() >= y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    // i64 arithmetic
    (AddInt64, LitI64(x), LitI64(y)) => Some(DataFlowLiteral::i64(x + y))
    (SubInt64, LitI64(x), LitI64(y)) => Some(DataFlowLiteral::i64(x - y))
    (MulInt64, LitI64(x), LitI64(y)) => Some(DataFlowLiteral::i64(x * y))
    (DivSInt64, LitI64(x), LitI64(y)) if y != 0L =>
      Some(DataFlowLiteral::i64(x / y))
    (DivUInt64, LitI64(x), LitI64(y)) if y != 0L => {
      let xu = x.reinterpret_as_uint64()
      let yu = y.reinterpret_as_uint64()
      Some(DataFlowLiteral::i64((xu / yu).reinterpret_as_int64()))
    }
    (RemSInt64, LitI64(x), LitI64(y)) if y != 0L =>
      Some(DataFlowLiteral::i64(x % y))
    (RemUInt64, LitI64(x), LitI64(y)) if y != 0L => {
      let xu = x.reinterpret_as_uint64()
      let yu = y.reinterpret_as_uint64()
      Some(DataFlowLiteral::i64((xu % yu).reinterpret_as_int64()))
    }
    // i64 bitwise
    (AndInt64, LitI64(x), LitI64(y)) => Some(DataFlowLiteral::i64(x & y))
    (OrInt64, LitI64(x), LitI64(y)) => Some(DataFlowLiteral::i64(x | y))
    (XorInt64, LitI64(x), LitI64(y)) => Some(DataFlowLiteral::i64(x ^ y))
    (ShlInt64, LitI64(x), LitI64(y)) =>
      Some(DataFlowLiteral::i64(x << y.land(63L).to_int()))
    (ShrSInt64, LitI64(x), LitI64(y)) =>
      Some(DataFlowLiteral::i64(x >> y.land(63L).to_int()))
    (ShrUInt64, LitI64(x), LitI64(y)) =>
      Some(
        DataFlowLiteral::i64(
          (x.reinterpret_as_uint64() >> y.land(63L).to_int()).reinterpret_as_int64(),
        ),
      )
    // i64 comparisons
    (EqInt64, LitI64(x), LitI64(y)) =>
      Some(DataFlowLiteral::i32(if x == y { 1 } else { 0 }))
    (NeInt64, LitI64(x), LitI64(y)) =>
      Some(DataFlowLiteral::i32(if x != y { 1 } else { 0 }))
    (LtSInt64, LitI64(x), LitI64(y)) =>
      Some(DataFlowLiteral::i32(if x < y { 1 } else { 0 }))
    (LtUInt64, LitI64(x), LitI64(y)) =>
      Some(
        DataFlowLiteral::i32(
          if x.reinterpret_as_uint64() < y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    (LeSInt64, LitI64(x), LitI64(y)) =>
      Some(DataFlowLiteral::i32(if x <= y { 1 } else { 0 }))
    (LeUInt64, LitI64(x), LitI64(y)) =>
      Some(
        DataFlowLiteral::i32(
          if x.reinterpret_as_uint64() <= y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    (GtSInt64, LitI64(x), LitI64(y)) =>
      Some(DataFlowLiteral::i32(if x > y { 1 } else { 0 }))
    (GtUInt64, LitI64(x), LitI64(y)) =>
      Some(
        DataFlowLiteral::i32(
          if x.reinterpret_as_uint64() > y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    (GeSInt64, LitI64(x), LitI64(y)) =>
      Some(DataFlowLiteral::i32(if x >= y { 1 } else { 0 }))
    (GeUInt64, LitI64(x), LitI64(y)) =>
      Some(
        DataFlowLiteral::i32(
          if x.reinterpret_as_uint64() >= y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    // f32 arithmetic
    (AddFloat32, LitF32(x), LitF32(y)) => Some(DataFlowLiteral::f32(x + y))
    (SubFloat32, LitF32(x), LitF32(y)) => Some(DataFlowLiteral::f32(x - y))
    (MulFloat32, LitF32(x), LitF32(y)) => Some(DataFlowLiteral::f32(x * y))
    (DivFloat32, LitF32(x), LitF32(y)) => Some(DataFlowLiteral::f32(x / y))
    // f64 arithmetic
    (AddFloat64, LitF64(x), LitF64(y)) => Some(DataFlowLiteral::f64(x + y))
    (SubFloat64, LitF64(x), LitF64(y)) => Some(DataFlowLiteral::f64(x - y))
    (MulFloat64, LitF64(x), LitF64(y)) => Some(DataFlowLiteral::f64(x * y))
    (DivFloat64, LitF64(x), LitF64(y)) => Some(DataFlowLiteral::f64(x / y))
    _ => None
  }
}

// Get constant value from a node if it's a constant

///|
fn get_const_value(graph : Graph, node_id : NodeId) -> DataFlowLiteral? {
  match graph.node_store.get(node_id) {
    Some({ expr: Some(Const(c)), .. }) => Some(c.value)
    _ => None
  }
}

// Check if a value is a power of 2

///|
fn is_power_of_2_i32(x : Int) -> Bool {
  x > 0 && (x & (x - 1)) == 0
}

///|
fn is_power_of_2_i64(x : Int64) -> Bool {
  x > 0L && (x & (x - 1L)) == 0L
}

// Get log2 of a power of 2

///|
fn log2_i32(x : Int) -> Int {
  31 - x.clz()
}

///|
fn log2_i64(x : Int64) -> Int64 {
  (63 - x.clz()).to_int64()
}

// Strength reduction: multiply by power of 2 -> shift

///|
fn try_strength_reduce(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  bin : BinaryExpr,
  work : Set[NodeId],
) -> Bool {
  match bin.op {
    // x * 2^n => x << n
    MulInt32 => {
      match get_const_value(graph, node.values[1]) {
        Some(LitI32(c)) if is_power_of_2_i32(c) => {
          let shift_amt = log2_i32(c)
          let shift_const = graph.make_const(DataFlowLiteral::i32(shift_amt))
          let new_expr = Expression::binary(
            BinaryExpr::new(
              DataFlowBinaryOp::shl_int32(),
              ExprId::new(node.values[0].0),
              ExprId::new(shift_const.0),
              WasmType::i32(),
            ),
          )
          let new_node = graph.add_node(
            Node::make_expr(NodeId::new(0), new_expr, node.origin),
          )
          match graph.node_store.get_mut(new_node) {
            Some(n) => {
              n.values.push(node.values[0])
              n.values.push(shift_const)
            }
            None => ()
          }
          replace_all_uses(graph, users, node.id, new_node, work)
          return true
        }
        _ => ()
      }
      // Check left operand too (commutativity)
      match get_const_value(graph, node.values[0]) {
        Some(LitI32(c)) if is_power_of_2_i32(c) => {
          let shift_amt = log2_i32(c)
          let shift_const = graph.make_const(DataFlowLiteral::i32(shift_amt))
          let new_expr = Expression::binary(
            BinaryExpr::new(
              DataFlowBinaryOp::shl_int32(),
              ExprId::new(node.values[1].0),
              ExprId::new(shift_const.0),
              WasmType::i32(),
            ),
          )
          let new_node = graph.add_node(
            Node::make_expr(NodeId::new(0), new_expr, node.origin),
          )
          match graph.node_store.get_mut(new_node) {
            Some(n) => {
              n.values.push(node.values[1])
              n.values.push(shift_const)
            }
            None => ()
          }
          replace_all_uses(graph, users, node.id, new_node, work)
          return true
        }
        _ => ()
      }
    }
    MulInt64 =>
      match get_const_value(graph, node.values[1]) {
        Some(LitI64(c)) if is_power_of_2_i64(c) => {
          let shift_amt = log2_i64(c)
          let shift_const = graph.make_const(DataFlowLiteral::i64(shift_amt))
          let new_expr = Expression::binary(
            BinaryExpr::new(
              DataFlowBinaryOp::shl_int64(),
              ExprId::new(node.values[0].0),
              ExprId::new(shift_const.0),
              WasmType::i64(),
            ),
          )
          let new_node = graph.add_node(
            Node::make_expr(NodeId::new(0), new_expr, node.origin),
          )
          match graph.node_store.get_mut(new_node) {
            Some(n) => {
              n.values.push(node.values[0])
              n.values.push(shift_const)
            }
            None => ()
          }
          replace_all_uses(graph, users, node.id, new_node, work)
          return true
        }
        _ => ()
      }
    // x / 2^n => x >> n (for unsigned)
    DivUInt32 =>
      match get_const_value(graph, node.values[1]) {
        Some(LitI32(c)) if is_power_of_2_i32(c) => {
          let shift_amt = log2_i32(c)
          let shift_const = graph.make_const(DataFlowLiteral::i32(shift_amt))
          let new_expr = Expression::binary(
            BinaryExpr::new(
              DataFlowBinaryOp::shr_u_int32(),
              ExprId::new(node.values[0].0),
              ExprId::new(shift_const.0),
              WasmType::i32(),
            ),
          )
          let new_node = graph.add_node(
            Node::make_expr(NodeId::new(0), new_expr, node.origin),
          )
          match graph.node_store.get_mut(new_node) {
            Some(n) => {
              n.values.push(node.values[0])
              n.values.push(shift_const)
            }
            None => ()
          }
          replace_all_uses(graph, users, node.id, new_node, work)
          return true
        }
        _ => ()
      }
    DivUInt64 =>
      match get_const_value(graph, node.values[1]) {
        Some(LitI64(c)) if is_power_of_2_i64(c) => {
          let shift_amt = log2_i64(c)
          let shift_const = graph.make_const(DataFlowLiteral::i64(shift_amt))
          let new_expr = Expression::binary(
            BinaryExpr::new(
              DataFlowBinaryOp::shr_u_int64(),
              ExprId::new(node.values[0].0),
              ExprId::new(shift_const.0),
              WasmType::i64(),
            ),
          )
          let new_node = graph.add_node(
            Node::make_expr(NodeId::new(0), new_expr, node.origin),
          )
          match graph.node_store.get_mut(new_node) {
            Some(n) => {
              n.values.push(node.values[0])
              n.values.push(shift_const)
            }
            None => ()
          }
          replace_all_uses(graph, users, node.id, new_node, work)
          return true
        }
        _ => ()
      }
    _ => ()
  }
  false
}

// Algebraic simplifications that don't require constant inputs

///|
fn try_simplify_binary(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  bin : BinaryExpr,
  work : Set[NodeId],
) -> Bool {
  let left_node = graph.node_store.get(node.values[0])
  let right_node = graph.node_store.get(node.values[1])

  // Try strength reduction first
  if try_strength_reduce(graph, users, node, bin, work) {
    return true
  }
  match (bin.op, left_node, right_node) {
    // x + 0 => x
    (AddInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. }))
    | (AddInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. }))
    | (AddFloat32, _, Some({ expr: Some(Const({ value: LitF32(0.0) })), .. }))
    | (AddFloat64, _, Some({ expr: Some(Const({ value: LitF64(0.0) })), .. })) => {
      replace_all_uses(graph, users, node.id, node.values[0], work)
      return true
    }
    // 0 + x => x
    (AddInt32, Some({ expr: Some(Const({ value: LitI32(0) })), .. }), _)
    | (AddInt64, Some({ expr: Some(Const({ value: LitI64(0L) })), .. }), _)
    | (AddFloat32, Some({ expr: Some(Const({ value: LitF32(0.0) })), .. }), _)
    | (AddFloat64, Some({ expr: Some(Const({ value: LitF64(0.0) })), .. }), _) => {
      replace_all_uses(graph, users, node.id, node.values[1], work)
      return true
    }
    // x - 0 => x
    (SubInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. }))
    | (SubInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. }))
    | (SubFloat32, _, Some({ expr: Some(Const({ value: LitF32(0.0) })), .. }))
    | (SubFloat64, _, Some({ expr: Some(Const({ value: LitF64(0.0) })), .. })) => {
      replace_all_uses(graph, users, node.id, node.values[0], work)
      return true
    }
    // x * 0 => 0
    (MulInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. } as zero))
    | (
      MulInt32,
      Some({ expr: Some(Const({ value: LitI32(0) })), .. } as zero),
      _,
    ) => {
      replace_all_uses(graph, users, node.id, zero.id, work)
      return true
    }
    (MulInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. } as zero)
    )
    | (
      MulInt64,
      Some({ expr: Some(Const({ value: LitI64(0L) })), .. } as zero),
      _,
    ) => {
      replace_all_uses(graph, users, node.id, zero.id, work)
      return true
    }
    // x * 1 => x
    (MulInt32, _, Some({ expr: Some(Const({ value: LitI32(1) })), .. }))
    | (MulInt64, _, Some({ expr: Some(Const({ value: LitI64(1L) })), .. }))
    | (MulFloat32, _, Some({ expr: Some(Const({ value: LitF32(1.0) })), .. }))
    | (MulFloat64, _, Some({ expr: Some(Const({ value: LitF64(1.0) })), .. })) => {
      replace_all_uses(graph, users, node.id, node.values[0], work)
      return true
    }
    // 1 * x => x
    (MulInt32, Some({ expr: Some(Const({ value: LitI32(1) })), .. }), _)
    | (MulInt64, Some({ expr: Some(Const({ value: LitI64(1L) })), .. }), _)
    | (MulFloat32, Some({ expr: Some(Const({ value: LitF32(1.0) })), .. }), _)
    | (MulFloat64, Some({ expr: Some(Const({ value: LitF64(1.0) })), .. }), _) => {
      replace_all_uses(graph, users, node.id, node.values[1], work)
      return true
    }
    // x / 1 => x
    (DivSInt32, _, Some({ expr: Some(Const({ value: LitI32(1) })), .. }))
    | (DivUInt32, _, Some({ expr: Some(Const({ value: LitI32(1) })), .. }))
    | (DivSInt64, _, Some({ expr: Some(Const({ value: LitI64(1L) })), .. }))
    | (DivUInt64, _, Some({ expr: Some(Const({ value: LitI64(1L) })), .. }))
    | (DivFloat32, _, Some({ expr: Some(Const({ value: LitF32(1.0) })), .. }))
    | (DivFloat64, _, Some({ expr: Some(Const({ value: LitF64(1.0) })), .. })) => {
      replace_all_uses(graph, users, node.id, node.values[0], work)
      return true
    }
    // x & 0 => 0
    (AndInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. } as zero))
    | (
      AndInt32,
      Some({ expr: Some(Const({ value: LitI32(0) })), .. } as zero),
      _,
    ) => {
      replace_all_uses(graph, users, node.id, zero.id, work)
      return true
    }
    (AndInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. } as zero)
    )
    | (
      AndInt64,
      Some({ expr: Some(Const({ value: LitI64(0L) })), .. } as zero),
      _,
    ) => {
      replace_all_uses(graph, users, node.id, zero.id, work)
      return true
    }
    // x & -1 => x (all bits set)
    (AndInt32, _, Some({ expr: Some(Const({ value: LitI32(-1) })), .. }))
    | (AndInt64, _, Some({ expr: Some(Const({ value: LitI64(-1L) })), .. })) => {
      replace_all_uses(graph, users, node.id, node.values[0], work)
      return true
    }
    (AndInt32, Some({ expr: Some(Const({ value: LitI32(-1) })), .. }), _)
    | (AndInt64, Some({ expr: Some(Const({ value: LitI64(-1L) })), .. }), _) => {
      replace_all_uses(graph, users, node.id, node.values[1], work)
      return true
    }
    // x | 0 => x
    (OrInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. }))
    | (OrInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. })) => {
      replace_all_uses(graph, users, node.id, node.values[0], work)
      return true
    }
    (OrInt32, Some({ expr: Some(Const({ value: LitI32(0) })), .. }), _)
    | (OrInt64, Some({ expr: Some(Const({ value: LitI64(0L) })), .. }), _) => {
      replace_all_uses(graph, users, node.id, node.values[1], work)
      return true
    }
    // x | -1 => -1 (all bits set)
    (OrInt32, _, Some({ expr: Some(Const({ value: LitI32(-1) })), .. } as ones))
    | (
      OrInt32,
      Some({ expr: Some(Const({ value: LitI32(-1) })), .. } as ones),
      _,
    ) => {
      replace_all_uses(graph, users, node.id, ones.id, work)
      return true
    }
    (OrInt64, _, Some({ expr: Some(Const({ value: LitI64(-1L) })), .. } as ones)
    )
    | (
      OrInt64,
      Some({ expr: Some(Const({ value: LitI64(-1L) })), .. } as ones),
      _,
    ) => {
      replace_all_uses(graph, users, node.id, ones.id, work)
      return true
    }
    // x ^ 0 => x
    (XorInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. }))
    | (XorInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. })) => {
      replace_all_uses(graph, users, node.id, node.values[0], work)
      return true
    }
    (XorInt32, Some({ expr: Some(Const({ value: LitI32(0) })), .. }), _)
    | (XorInt64, Some({ expr: Some(Const({ value: LitI64(0L) })), .. }), _) => {
      replace_all_uses(graph, users, node.id, node.values[1], work)
      return true
    }
    // x << 0 => x, x >> 0 => x
    (ShlInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. }))
    | (ShrSInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. }))
    | (ShrUInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. }))
    | (RotLInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. }))
    | (RotRInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. }))
    | (ShlInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. }))
    | (ShrSInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. }))
    | (ShrUInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. }))
    | (RotLInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. }))
    | (RotRInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. })) => {
      replace_all_uses(graph, users, node.id, node.values[0], work)
      return true
    }
    // 0 << x => 0, 0 >> x => 0
    (ShlInt32, Some({ expr: Some(Const({ value: LitI32(0) })), .. } as zero), _)
    | (
      ShrSInt32,
      Some({ expr: Some(Const({ value: LitI32(0) })), .. } as zero),
      _,
    )
    | (
      ShrUInt32,
      Some({ expr: Some(Const({ value: LitI32(0) })), .. } as zero),
      _,
    ) => {
      replace_all_uses(graph, users, node.id, zero.id, work)
      return true
    }
    (ShlInt64, Some({ expr: Some(Const({ value: LitI64(0L) })), .. } as zero), _
    )
    | (
      ShrSInt64,
      Some({ expr: Some(Const({ value: LitI64(0L) })), .. } as zero),
      _,
    )
    | (
      ShrUInt64,
      Some({ expr: Some(Const({ value: LitI64(0L) })), .. } as zero),
      _,
    ) => {
      replace_all_uses(graph, users, node.id, zero.id, work)
      return true
    }
    // x - x => 0, x ^ x => 0
    (SubInt32, _, _) | (XorInt32, _, _) if node.values[0] == node.values[1] => {
      let zero = graph.make_const(DataFlowLiteral::i32(0))
      replace_all_uses(graph, users, node.id, zero, work)
      return true
    }
    (SubInt64, _, _) | (XorInt64, _, _) if node.values[0] == node.values[1] => {
      let zero = graph.make_const(DataFlowLiteral::i64(0L))
      replace_all_uses(graph, users, node.id, zero, work)
      return true
    }
    (SubFloat32, _, _) if node.values[0] == node.values[1] => {
      let zero = graph.make_const(DataFlowLiteral::f32(0.0))
      replace_all_uses(graph, users, node.id, zero, work)
      return true
    }
    (SubFloat64, _, _) if node.values[0] == node.values[1] => {
      let zero = graph.make_const(DataFlowLiteral::f64(0.0))
      replace_all_uses(graph, users, node.id, zero, work)
      return true
    }
    // x & x => x, x | x => x
    (AndInt32, _, _) | (AndInt64, _, _) | (OrInt32, _, _) | (OrInt64, _, _) if node.values[0] ==
      node.values[1] => {
      replace_all_uses(graph, users, node.id, node.values[0], work)
      return true
    }
    // x == x => 1
    (EqInt32, _, _) | (EqInt64, _, _) if node.values[0] == node.values[1] => {
      let one = graph.make_const(DataFlowLiteral::i32(1))
      replace_all_uses(graph, users, node.id, one, work)
      return true
    }
    // x != x => 0
    (NeInt32, _, _) | (NeInt64, _, _) if node.values[0] == node.values[1] => {
      let zero = graph.make_const(DataFlowLiteral::i32(0))
      replace_all_uses(graph, users, node.id, zero, work)
      return true
    }
    // x <= x => 1, x >= x => 1
    (LeSInt32, _, _)
    | (LeUInt32, _, _)
    | (GeSInt32, _, _)
    | (GeUInt32, _, _)
    | (LeSInt64, _, _)
    | (LeUInt64, _, _)
    | (GeSInt64, _, _)
    | (GeUInt64, _, _) if node.values[0] == node.values[1] => {
      let one = graph.make_const(DataFlowLiteral::i32(1))
      replace_all_uses(graph, users, node.id, one, work)
      return true
    }
    // x < x => 0, x > x => 0
    (LtSInt32, _, _)
    | (LtUInt32, _, _)
    | (GtSInt32, _, _)
    | (GtUInt32, _, _)
    | (LtSInt64, _, _)
    | (LtUInt64, _, _)
    | (GtSInt64, _, _)
    | (GtUInt64, _, _) if node.values[0] == node.values[1] => {
      let zero = graph.make_const(DataFlowLiteral::i32(0))
      replace_all_uses(graph, users, node.id, zero, work)
      return true
    }
    // x / x => 1 (when x is known non-zero constant)
    (DivSInt32, _, _) | (DivUInt32, _, _) if node.values[0] == node.values[1] =>
      match get_const_value(graph, node.values[0]) {
        Some(LitI32(x)) if x != 0 => {
          let one = graph.make_const(DataFlowLiteral::i32(1))
          replace_all_uses(graph, users, node.id, one, work)
          return true
        }
        _ => ()
      }
    (DivSInt64, _, _) | (DivUInt64, _, _) if node.values[0] == node.values[1] =>
      match get_const_value(graph, node.values[0]) {
        Some(LitI64(x)) if x != 0L => {
          let one = graph.make_const(DataFlowLiteral::i64(1L))
          replace_all_uses(graph, users, node.id, one, work)
          return true
        }
        _ => ()
      }
    _ => ()
  }
  false
}

///|
fn try_simplify_unary(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  un : UnaryExpr,
  work : Set[NodeId],
) -> Bool {
  // Double negation: neg(neg(x)) => x
  match un.op {
    NegFloat32 | NegFloat64 =>
      match graph.node_store.get(node.values[0]) {
        Some({ expr: Some(Unary(inner)), values, .. }) if inner.op == un.op &&
          values.length() > 0 => {
          replace_all_uses(graph, users, node.id, values[0], work)
          return true
        }
        _ => ()
      }
    // eqz(eqz(x)) is NOT x in general (it's a double boolean conversion)
    // But we can simplify eqz of a known comparison result
    EqZInt32 =>
      match graph.node_store.get(node.values[0]) {
        Some({ expr: Some(Binary(b)), .. }) if b.op.is_relational() =>
          // eqz of comparison - flip the comparison
          match b.op.get_opposite() {
            Some(opposite_op) => {
              let new_expr = Expression::binary(
                BinaryExpr::new(opposite_op, b.left, b.right, b.result_type),
              )
              let input = graph.node_store.get(node.values[0])
              let new_node = graph.add_node(
                Node::make_expr(
                  NodeId::new(0),
                  new_expr,
                  match input {
                    Some(n) => n.origin
                    None => None
                  },
                ),
              )
              match (graph.node_store.get_mut(new_node), input) {
                (Some(n), Some(inp)) =>
                  for v in inp.values {
                    n.values.push(v)
                  }
                _ => ()
              }
              replace_all_uses(graph, users, node.id, new_node, work)
              return true
            }
            None => ()
          }
        _ => ()
      }
    _ => ()
  }
  false
}

///|
fn try_simplify_phi(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  work : @set.Set[NodeId],
) -> Bool {
  if not(node.is_phi()) || node.values.is_empty() {
    return false
  }

  // All inputs identical => replace with that input
  if all_inputs_identical(node) {
    replace_all_uses(graph, users, node.id, node.values[0], work)
    return true
  }

  // All inputs except self-references are identical
  let mut unique : NodeId? = None
  for v in node.values {
    if v == node.id {
      continue // skip self-reference
    }
    match unique {
      None => unique = Some(v)
      Some(u) if u != v => return false // found different values
      _ => ()
    }
  }
  match unique {
    Some(u) => {
      replace_all_uses(graph, users, node.id, u, work)
      true
    }
    None => false
  }
}

///|
fn try_simplify_zext(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  work : @set.Set[NodeId],
) -> Bool {
  if not(node.is_zext()) || node.values.is_empty() {
    return false
  }
  match graph.node_store.get(node.values[0]) {
    Some({ expr: Some(Const({ value: LitI32(v) })), .. }) =>
      // zext of 0 or 1 is just the value
      if v == 0 || v == 1 {
        replace_all_uses(graph, users, node.id, node.values[0], work)
        return true
      }
    // zext of a comparison result (already 0 or 1)
    Some({ expr: Some(Binary(b)), .. }) if b.op.is_relational() => {
      replace_all_uses(graph, users, node.id, node.values[0], work)
      return true
    }
    Some({ expr: Some(Unary(u)), .. }) if u.op.is_relational() => {
      replace_all_uses(graph, users, node.id, node.values[0], work)
      return true
    }
    _ => ()
  }
  false
}

///|
fn try_simplify_if(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  if_expr : IfExpr,
  work : Set[NodeId],
) -> Bool {
  // if(const_true, t, f) => t
  // if(const_false, t, f) => f
  match get_const_value(graph, node.values[0]) {
    Some(LitI32(c)) => {
      // Assuming values[0] = condition, values[1] = then_branch, values[2] = else_branch
      let replacement = if c != 0 { node.values[1] } else { node.values[2] }
      replace_all_uses(graph, users, node.id, replacement, work)
      return true
    }
    _ => ()
  }

  // if(c, x, x) => x (when both branches are identical)
  if node.values.length() >= 3 && node.values[1] == node.values[2] {
    replace_all_uses(graph, users, node.id, node.values[1], work)
    return true
  }

  // if(eqz(c), t, f) => if(c, f, t) - normalize to avoid double negation
  // (This creates a new node rather than just replacing)
  match graph.node_store.get(node.values[0]) {
    Some({ expr: Some(Unary(u)), values: cond_values, .. }) if u.op ==
      DataFlowUnaryOp::eq_z_int32() &&
      cond_values.length() > 0 &&
      if_expr.if_false is Some(if_false) => {
      // Swap branches and use inner condition
      let new_expr = Expression::if_(
        IfExpr::new(
          ExprId::new(cond_values[0].0),
          if_false, // swapped
          Some(if_expr.if_true), // swapped
          if_expr.result_type,
        ),
      )
      let new_node = graph.add_node(
        Node::make_expr(NodeId::new(0), new_expr, node.origin),
      )
      match graph.node_store.get_mut(new_node) {
        Some(n) => {
          n.values.push(cond_values[0]) // original condition
          n.values.push(node.values[2]) // swapped: was else, now then
          n.values.push(node.values[1]) // swapped: was then, now else
        }
        None => ()
      }
      replace_all_uses(graph, users, node.id, new_node, work)
      return true
    }
    _ => ()
  }
  false
}

///|
fn try_simplify_switch(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  switch_expr : SwitchExpr,
  work : Set[NodeId],
) -> Bool {
  // switch with constant condition => jump directly to target
  match get_const_value(graph, node.values[0]) {
    Some(LitI32(idx)) => {
      let case_count = switch_expr.targets.length()
      // values[0] is condition, values[1..] are case targets
      let target_idx = if idx >= 0 && idx < case_count {
        idx + 1 // +1 because values[0] is condition
      } else {
        // Default case (typically last)
        node.values.length() - 1
      }
      if target_idx < node.values.length() {
        replace_all_uses(graph, users, node.id, node.values[target_idx], work)
        return true
      }
    }
    _ => ()
  }

  // All cases point to same target => replace with that target
  if node.values.length() > 2 {
    let first_target = node.values[1]
    let mut all_same = true
    for i = 2; i < node.values.length(); i = i + 1 {
      if node.values[i] != first_target {
        all_same = false
        break
      }
    }
    if all_same {
      replace_all_uses(graph, users, node.id, first_target, work)
      return true
    }
  }
  false
}

///|
fn try_simplify_block(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  block_expr : BlockExpr,
  work : Set[NodeId],
) -> Bool {
  // Empty block with no result => can potentially be eliminated
  // (depends on context, may need to check for side effects)

  // Block with single expression => unwrap if safe
  if node.values.length() == 1 {
    let inner = match graph.node_store.get(node.values[0]) {
      Some(n) => n
      None => return false
    }
    // Only unwrap if inner doesn't reference the block label
    // and types match
    if block_expr.name is Some(name) &&
      not(references_label(graph, inner.id, name)) {
      replace_all_uses(graph, users, node.id, node.values[0], work)
      return true
    }
  }
  false
}

// Helper to check if a node or its children reference a specific label

///|
fn references_label(graph : Graph, node_id : NodeId, label : String) -> Bool {
  let node = match graph.node_store.get(node_id) {
    Some(n) => n
    None => return false
  }
  match node.expr {
    Some(Break(b)) => b.name == label
    Some(Block(b)) if b.name is Some(l) && l == label => false // Inner block shadows the label
    Some(Loop(l)) if l.name is Some(l) && l == label => false // Inner loop shadows the label
    _ => {
      // Check children
      for v in node.values {
        if references_label(graph, v, label) {
          return true
        }
      }
      false
    }
  }
}

///|
fn try_simplify_loop(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  loop_expr : LoopExpr,
  work : Set[NodeId],
) -> Bool {
  // Loop with no continues (no references to its label) => execute body once
  if node.values.length() > 0 {
    let body_id = node.values[0]
    if loop_expr.name is Some(name) &&
      not(references_label(graph, body_id, name)) {
      replace_all_uses(graph, users, node.id, body_id, work)
      return true
    }
  }

  // Loop where body is just a break => replace with break value
  match graph.node_store.get(node.values[0]) {
    Some({ expr: Some(Break(b)), values: break_values, .. }) if loop_expr.name
      is Some(name) &&
      b.name == name => {
      if break_values.length() > 0 {
        replace_all_uses(graph, users, node.id, break_values[0], work)
      }
      return true
    }
    _ => ()
  }
  false
}

///|
fn try_simplify_break(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  break_expr : BreakExpr,
  work : Set[NodeId],
) -> Bool {
  // Conditional break with constant condition
  if break_expr.condition is Some(_) && node.values.length() >= 2 {
    // Assuming values[0] = condition, values[1] = value (if any)
    match get_const_value(graph, node.values[0]) {
      Some(LitI32(0)) => {
        // Condition is false => break never taken, becomes nop or the value
        if node.values.length() > 1 {
          replace_all_uses(graph, users, node.id, node.values[1], work)
        } else {
          let nop = graph.add_node(
            Node::make_expr(NodeId::new(0), Expression::nop(), node.origin),
          )
          replace_all_uses(graph, users, node.id, nop, work)
        }
        return true
      }
      Some(LitI32(_)) =>
        // Condition is true => unconditional break
        // Convert to unconditional break (this is more of a normalization)
        ()
      _ => ()
    }
  }
  false
}

///|
fn try_simplify_drop(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  work : Set[NodeId],
) -> Bool {
  if node.values.is_empty() {
    return false
  }
  let dropped = match graph.node_store.get(node.values[0]) {
    Some(n) => n
    None => return false
  }

  // drop(const) => nop (constants have no side effects)
  if dropped.is_const() {
    let nop = graph.add_node(
      Node::make_expr(NodeId::new(0), Expression::nop(), node.origin),
    )
    replace_all_uses(graph, users, node.id, nop, work)
    return true
  }

  // drop(pure_expr) => nop
  if is_pure_expr(dropped) {
    let nop = graph.add_node(
      Node::make_expr(NodeId::new(0), Expression::nop(), node.origin),
    )
    replace_all_uses(graph, users, node.id, nop, work)
    return true
  }
  false
}

// Check if an expression is pure (no side effects)

///|
fn is_pure_expr(node : Node) -> Bool {
  match node.expr {
    Some(Const(_)) => true
    Some(Unary(_)) => true // Unary ops are pure
    Some(Binary(_)) => true // Binary ops are pure (assuming no trapping)
    Some(Select(_)) => true
    Some(LocalGet(_)) => true
    // These are NOT pure:
    // LocalSet, GlobalSet, Store, Call, etc.
    _ => false
  }
}

///|
fn try_simplify_local_set(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  local_set : LocalSetExpr,
  work : Set[NodeId],
) -> Bool {
  // local.set followed by local.get of same local with no intervening writes
  // This requires more complex analysis (use-def chains)

  // local.set x = local.get x => nop (setting to same value)
  if node.values.length() > 0 {
    match graph.node_store.get(node.values[0]) {
      Some({ expr: Some(LocalGet(lg)), .. }) if lg.index == local_set.index => {
        let nop = graph.add_node(
          Node::make_expr(NodeId::new(0), Expression::nop(), node.origin),
        )
        replace_all_uses(graph, users, node.id, nop, work)
        return true
      }
      _ => ()
    }
  }
  false
}

///|
fn try_simplify_return(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  work : Set[NodeId],
) -> Bool {
  // Return expressions don't have much to optimize directly,
  // but we can propagate constants through them
  // The value being returned would be optimized by other passes
  false
}

///|
fn try_simplify_generic(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  generic : GenericExpr,
  work : Set[NodeId],
) -> Bool {
  // GenericExpr optimization depends on what it represents
  // Common patterns:

  // Memory operations with constant addresses could be optimized
  // Call expressions with constant arguments might be inlined

  // For now, we don't optimize generic expressions
  false
}

// Updated try_fold_expr to handle all expression types

///|
fn try_fold_expr_comprehensive(
  graph : Graph,
  users : NodeUsers,
  node_id : NodeId,
  work : @set.Set[NodeId],
) -> Unit {
  let node = match graph.node_store.get(node_id) {
    Some(n) => n
    None => return
  }
  if not(node.is_expr()) {
    return
  }
  match node.expr {
    Some(Unary(u)) => {
      if try_simplify_unary(graph, users, node, u, work) {
        return
      }
      match graph.node_store.get(node.values[0]) {
        Some({ expr: Some(Const(c)), .. }) =>
          match eval_unary(u.op, c.value) {
            Some(v) => {
              let new_const = graph.make_const(v)
              replace_all_uses(graph, users, node_id, new_const, work)
            }
            None => ()
          }
        _ => ()
      }
    }
    Some(Binary(b)) => {
      if try_simplify_binary(graph, users, node, b, work) {
        return
      }
      let left = graph.node_store.get(node.values[0])
      let right = graph.node_store.get(node.values[1])
      match (left, right) {
        (
          Some({ expr: Some(Const(c1)), .. }),
          Some({ expr: Some(Const(c2)), .. }),
        ) =>
          match eval_binary(b.op, c1.value, c2.value) {
            Some(v) => {
              let new_const = graph.make_const(v)
              replace_all_uses(graph, users, node_id, new_const, work)
            }
            None => ()
          }
        _ => ()
      }
    }
    Some(Select(_)) =>
      match graph.node_store.get(node.values[2]) {
        Some({ expr: Some(Const({ value: LitI32(c) })), .. }) => {
          let replacement = if c != 0 { node.values[0] } else { node.values[1] }
          replace_all_uses(graph, users, node_id, replacement, work)
        }
        _ =>
          if node.values[0] == node.values[1] {
            replace_all_uses(graph, users, node_id, node.values[0], work)
          }
      }
    Some(If(if_expr)) => {
      let _ = try_simplify_if(graph, users, node, if_expr, work)

    }
    Some(Switch(switch_expr)) => {
      let _ = try_simplify_switch(graph, users, node, switch_expr, work)

    }
    Some(Block(block_expr)) => {
      let _ = try_simplify_block(graph, users, node, block_expr, work)

    }
    Some(Loop(loop_expr)) => {
      let _ = try_simplify_loop(graph, users, node, loop_expr, work)

    }
    Some(Break(break_expr)) => {
      let _ = try_simplify_break(graph, users, node, break_expr, work)

    }
    Some(Drop(_)) => {
      let _ = try_simplify_drop(graph, users, node, work)

    }
    Some(LocalSet(local_set)) => {
      let _ = try_simplify_local_set(graph, users, node, local_set, work)

    }
    Some(Return(_)) => {
      let _ = try_simplify_return(graph, users, node, work)

    }
    Some(Generic(generic)) => {
      let _ = try_simplify_generic(graph, users, node, generic, work)

    }
    Some(Nop)
    | Some(Unreachable)
    | Some(Const(_))
    | Some(LocalGet(_))
    | Some(Call(_)) =>
      // These don't need simplification
      ()
    None => ()
  }
}

// Update the GVN hash function to handle all expression types
// fn compute_expr_hash_comprehensive(expr : Expression) -> Int {
//   match expr {
//     Nop => 0
//     Unreachable => 1
//     Const(c) =>
//       match c.value {
//         LitI32(v) => 100 + v
//         LitI64(v) => 200 + v.to_int()
//         LitF32(v) => 300 + v.reinterpret_as_int()
//         LitF64(v) => 400 + v.reinterpret_as_int64().to_int()
//       }
//     Unary(u) => 1000 + unary_op_hash(u.op)
//     Binary(b) => 2000 + binary_op_hash(b.op)
//     Select(_) => 3000
//     If(_) => 4000
//     Block(b) => 5000 + b.label.0  // Include label in hash
//     Loop(l) => 6000 + l.label.0
//     Break(b) => 7000 + b.label.0
//     Switch(_) => 8000
//     LocalGet(lg) => 9000 + lg.index
//     LocalSet(ls) => 10000 + ls.index
//     Drop(_) => 11000
//     Return(_) => 12000
//     Generic(g) => 13000 + g.op_code  // Use opcode for differentiation
//   }
// }

///|
fn unary_op_hash(op : DataFlowUnaryOp) -> Int {
  match op {
    EqZInt32 => 0
    EqZInt64 => 1
    ClzInt32 => 2
    ClzInt64 => 3
    CtzInt32 => 4
    CtzInt64 => 5
    PopcntInt32 => 6
    PopcntInt64 => 7
    ExtendSInt32 => 8
    ExtendUInt32 => 9
    WrapInt64 => 10
    NegFloat32 => 11
    NegFloat64 => 12
    AbsFloat32 => 13
    AbsFloat64 => 14
  }
}

///|
pub fn optimize_graph(graph : Graph) -> Unit {
  let users = NodeUsers::build(graph)
  let work : @set.Set[NodeId] = @set.Set::from_array(
    graph.node_store.nodes.map(fn(n) { n.id }),
  )
  while not(work.is_empty()) {
    let id = set_pop_any(work)
    let node = match graph.node_store.get(id) {
      Some(n) => n
      None => continue
    }

    // Skip dead nodes (but keep vars as they may be function parameters)
    if users.num_uses(id) == 0 && not(node.is_var()) && not(node.is_bad()) {
      continue
    }

    // Phi simplification
    if node.is_phi() {
      if try_simplify_phi(graph, users, node, work) {
        continue
      }
    }

    // Expression simplification and constant folding
    if node.is_expr() && node.wasm_type.is_concrete() {
      try_fold_expr_comprehensive(graph, users, id, work)
      continue
    }

    // Zext simplification
    if node.is_zext() {
      if try_simplify_zext(graph, users, node, work) {
        continue
      }
    }
  }
}

// Additional optimization: Global Value Numbering (GVN) for CSE

///|
struct GVNKey {
  expr_hash : Int
  values : Array[NodeId]
} derive(Eq, Hash)

///|
fn compute_expr_hash(expr : Expression) -> Int {
  match expr {
    Nop => 0
    Unreachable => 1
    Const(c) =>
      match c.value {
        LitI32(v) => 100 + v
        LitI64(v) => 200 + v.to_int()
        LitF32(v) => 300 + v.reinterpret_as_int()
        LitF64(v) => 400 + v.reinterpret_as_int64().to_int()
      }
    Unary(u) =>
      match u.op {
        EqZInt32 => 1000
        EqZInt64 => 1001
        ClzInt32 => 1002
        ClzInt64 => 1003
        CtzInt32 => 1004
        CtzInt64 => 1005
        PopcntInt32 => 1006
        PopcntInt64 => 1007
        ExtendSInt32 => 1008
        ExtendUInt32 => 1009
        WrapInt64 => 1010
        NegFloat32 => 1011
        NegFloat64 => 1012
        AbsFloat32 => 1013
        AbsFloat64 => 1014
      }
    Binary(b) =>
      match b.op {
        AddInt32 => 2000
        SubInt32 => 2001
        MulInt32 => 2002
        DivSInt32 => 2003
        DivUInt32 => 2004
        RemSInt32 => 2005
        RemUInt32 => 2006
        AndInt32 => 2007
        OrInt32 => 2008
        XorInt32 => 2009
        ShlInt32 => 2010
        ShrSInt32 => 2011
        ShrUInt32 => 2012
        RotLInt32 => 2013
        RotRInt32 => 2014
        EqInt32 => 2015
        NeInt32 => 2016
        LtSInt32 => 2017
        LtUInt32 => 2018
        LeSInt32 => 2019
        LeUInt32 => 2020
        GtSInt32 => 2021
        GtUInt32 => 2022
        GeSInt32 => 2023
        GeUInt32 => 2024
        AddInt64 => 2100
        SubInt64 => 2101
        MulInt64 => 2102
        DivSInt64 => 2103
        DivUInt64 => 2104
        RemSInt64 => 2105
        RemUInt64 => 2106
        AndInt64 => 2107
        OrInt64 => 2108
        XorInt64 => 2109
        ShlInt64 => 2110
        ShrSInt64 => 2111
        ShrUInt64 => 2112
        RotLInt64 => 2113
        RotRInt64 => 2114
        EqInt64 => 2115
        NeInt64 => 2116
        LtSInt64 => 2117
        LtUInt64 => 2118
        LeSInt64 => 2119
        LeUInt64 => 2120
        GtSInt64 => 2121
        GtUInt64 => 2122
        GeSInt64 => 2123
        GeUInt64 => 2124
        AddFloat32 => 2200
        SubFloat32 => 2201
        MulFloat32 => 2202
        DivFloat32 => 2203
        AddFloat64 => 2300
        SubFloat64 => 2301
        MulFloat64 => 2302
        DivFloat64 => 2303
      }
    Select(_) => 3000
    _ => -1 // Not eligible for GVN
  }
}

///|
pub fn gvn_pass(graph : Graph) -> Unit {
  let users = NodeUsers::build(graph)
  let value_map : Map[GVNKey, NodeId] = Map::new()
  for node in graph.node_store.nodes {
    if not(node.is_expr()) {
      continue
    }
    match node.expr {
      Some(expr) => {
        let hash = compute_expr_hash(expr)
        if hash < 0 {
          continue
        }
        let key = { expr_hash: hash, values: node.values.copy() }
        match value_map.get(key) {
          Some(existing) if existing != node.id => {
            // Found duplicate - replace uses
            let work : Set[NodeId] = Set::new()
            replace_all_uses(graph, users, node.id, existing, work)
          }
          _ => value_map.set(key, node.id)
        }
      }
      None => ()
    }
  }
}

// Run all optimization passes

///|
pub fn optimize(graph : Graph) -> Unit {
  // Run multiple iterations until fixed point
  for _iter = 0; _iter < 10; _iter = _iter + 1 {
    let before = graph.debug_print()
    optimize_graph(graph)
    gvn_pass(graph)
    let after = graph.debug_print()
    if before == after {
      break
    }
  }
}

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
fn get_all_constant_values(
  graph : Graph,
  node : Node,
) -> Array[DataFlowLiteral]? {
  if not(all_inputs_constant(graph, node)) {
    return None
  }
  let values : Array[DataFlowLiteral] = []
  for v in node.values {
    match get_const_value(graph, v) {
      Some(lit) => values.push(lit)
      None => return None
    }
  }
  Some(values)
}

///|
fn[T : Eq + Hash] set_pop_any(s : @set.Set[T]) -> T {
  let it = s.iter()
  let v = it.next().unwrap()
  s.remove(v)
  v
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
    (SqrtFloat32, LitF32(x)) => Some(DataFlowLiteral::f32(x.sqrt()))
    (CeilFloat32, LitF32(x)) =>
      Some(DataFlowLiteral::f32(Float::from_double(x.to_double().ceil())))
    (FloorFloat32, LitF32(x)) =>
      Some(DataFlowLiteral::f32(Float::from_double(x.to_double().floor())))
    (TruncFloat32, LitF32(x)) =>
      Some(DataFlowLiteral::f32(Float::from_double(x.to_double().trunc())))
    (NearestFloat32, LitF32(x)) =>
      Some(DataFlowLiteral::f32(Float::from_double(x.to_double().round())))
    // f64 operations
    (NegFloat64, LitF64(x)) => Some(DataFlowLiteral::f64(-x))
    (AbsFloat64, LitF64(x)) => Some(DataFlowLiteral::f64(x.abs()))
    (SqrtFloat64, LitF64(x)) => Some(DataFlowLiteral::f64(x.sqrt()))
    (CeilFloat64, LitF64(x)) => Some(DataFlowLiteral::f64(x.ceil()))
    (FloorFloat64, LitF64(x)) => Some(DataFlowLiteral::f64(x.floor()))
    (TruncFloat64, LitF64(x)) => Some(DataFlowLiteral::f64(x.trunc()))
    (NearestFloat64, LitF64(x)) => Some(DataFlowLiteral::f64(x.round()))
    // Float to int conversions
    (TruncSFloat32ToInt32, LitF32(x)) =>
      Some(DataFlowLiteral::i32(x.to_double().trunc().to_int()))
    (TruncUFloat32ToInt32, LitF32(x)) =>
      Some(
        DataFlowLiteral::i32(
          x.to_double().trunc().to_uint().reinterpret_as_int(),
        ),
      )
    (TruncSFloat64ToInt32, LitF64(x)) =>
      Some(DataFlowLiteral::i32(x.trunc().to_int()))
    (TruncUFloat64ToInt32, LitF64(x)) =>
      Some(DataFlowLiteral::i32(x.trunc().to_uint().reinterpret_as_int()))
    (TruncSFloat32ToInt64, LitF32(x)) =>
      Some(DataFlowLiteral::i64(x.to_double().trunc().to_int64()))
    (TruncUFloat32ToInt64, LitF32(x)) =>
      Some(
        DataFlowLiteral::i64(
          x.to_double().trunc().to_uint64().reinterpret_as_int64(),
        ),
      )
    (TruncSFloat64ToInt64, LitF64(x)) =>
      Some(DataFlowLiteral::i64(x.trunc().to_int64()))
    (TruncUFloat64ToInt64, LitF64(x)) =>
      Some(DataFlowLiteral::i64(x.trunc().to_uint64().reinterpret_as_int64()))
    // Int to float conversions
    (ConvertSInt32ToFloat32, LitI32(x)) =>
      Some(DataFlowLiteral::f32(Float::from_double(x.to_double())))
    (ConvertUInt32ToFloat32, LitI32(x)) =>
      Some(
        DataFlowLiteral::f32(
          Float::from_double(x.reinterpret_as_uint().to_double()),
        ),
      )
    (ConvertSInt64ToFloat32, LitI64(x)) =>
      Some(DataFlowLiteral::f32(Float::from_double(x.to_double())))
    (ConvertUInt64ToFloat32, LitI64(x)) =>
      Some(
        DataFlowLiteral::f32(
          Float::from_double(x.reinterpret_as_uint64().to_double()),
        ),
      )
    (ConvertSInt32ToFloat64, LitI32(x)) =>
      Some(DataFlowLiteral::f64(x.to_double()))
    (ConvertUInt32ToFloat64, LitI32(x)) =>
      Some(DataFlowLiteral::f64(x.reinterpret_as_uint().to_double()))
    (ConvertSInt64ToFloat64, LitI64(x)) =>
      Some(DataFlowLiteral::f64(x.to_double()))
    (ConvertUInt64ToFloat64, LitI64(x)) =>
      Some(DataFlowLiteral::f64(x.reinterpret_as_uint64().to_double()))
    // Float promotions/demotions
    (PromoteFloat32, LitF32(x)) => Some(DataFlowLiteral::f64(x.to_double()))
    (DemoteFloat64, LitF64(x)) => Some(DataFlowLiteral::f32(Float::from_double(x)))
    // Reinterpret
    (ReinterpretFloat32, LitF32(x)) =>
      Some(DataFlowLiteral::i32(x.reinterpret_as_int()))
    (ReinterpretFloat64, LitF64(x)) =>
      Some(DataFlowLiteral::i64(x.reinterpret_as_int64()))
    (ReinterpretInt32, LitI32(x)) =>
      Some(DataFlowLiteral::f32(Float::from_int(x)))
    (ReinterpretInt64, LitI64(x)) =>
      Some(DataFlowLiteral::f64(x.reinterpret_as_double()))
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
    (RotLInt64, LitI64(x), LitI64(y)) => {
      let k = y.land(63L).to_int()
      let xu = x.reinterpret_as_uint64()
      Some(
        DataFlowLiteral::i64(
          ((xu << k) | (xu >> (64 - k))).reinterpret_as_int64(),
        ),
      )
    }
    (RotRInt64, LitI64(x), LitI64(y)) => {
      let k = y.land(63L).to_int()
      let xu = x.reinterpret_as_uint64()
      Some(
        DataFlowLiteral::i64(
          ((xu >> k) | (xu << (64 - k))).reinterpret_as_int64(),
        ),
      )
    }
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
    (MinFloat32, LitF32(x), LitF32(y)) =>
      Some(DataFlowLiteral::f32(if x < y { x } else { y }))
    (MaxFloat32, LitF32(x), LitF32(y)) =>
      Some(DataFlowLiteral::f32(if x > y { x } else { y }))
    (CopysignFloat32, LitF32(x), LitF32(y)) => {
      let x_abs = x.abs()
      let result = if y < 0.0 { -x_abs } else { x_abs }
      Some(DataFlowLiteral::f32(result))
    }
    // f32 comparisons
    (EqFloat32, LitF32(x), LitF32(y)) =>
      Some(DataFlowLiteral::i32(if x == y { 1 } else { 0 }))
    (NeFloat32, LitF32(x), LitF32(y)) =>
      Some(DataFlowLiteral::i32(if x != y { 1 } else { 0 }))
    (LtFloat32, LitF32(x), LitF32(y)) =>
      Some(DataFlowLiteral::i32(if x < y { 1 } else { 0 }))
    (LeFloat32, LitF32(x), LitF32(y)) =>
      Some(DataFlowLiteral::i32(if x <= y { 1 } else { 0 }))
    (GtFloat32, LitF32(x), LitF32(y)) =>
      Some(DataFlowLiteral::i32(if x > y { 1 } else { 0 }))
    (GeFloat32, LitF32(x), LitF32(y)) =>
      Some(DataFlowLiteral::i32(if x >= y { 1 } else { 0 }))
    // f64 arithmetic
    (AddFloat64, LitF64(x), LitF64(y)) => Some(DataFlowLiteral::f64(x + y))
    (SubFloat64, LitF64(x), LitF64(y)) => Some(DataFlowLiteral::f64(x - y))
    (MulFloat64, LitF64(x), LitF64(y)) => Some(DataFlowLiteral::f64(x * y))
    (DivFloat64, LitF64(x), LitF64(y)) => Some(DataFlowLiteral::f64(x / y))
    (MinFloat64, LitF64(x), LitF64(y)) =>
      Some(DataFlowLiteral::f64(if x < y { x } else { y }))
    (MaxFloat64, LitF64(x), LitF64(y)) =>
      Some(DataFlowLiteral::f64(if x > y { x } else { y }))
    (CopysignFloat64, LitF64(x), LitF64(y)) => {
      let x_abs = x.abs()
      let result = if y < 0.0 { -x_abs } else { x_abs }
      Some(DataFlowLiteral::f64(result))
    }
    // f64 comparisons
    (EqFloat64, LitF64(x), LitF64(y)) =>
      Some(DataFlowLiteral::i32(if x == y { 1 } else { 0 }))
    (NeFloat64, LitF64(x), LitF64(y)) =>
      Some(DataFlowLiteral::i32(if x != y { 1 } else { 0 }))
    (LtFloat64, LitF64(x), LitF64(y)) =>
      Some(DataFlowLiteral::i32(if x < y { 1 } else { 0 }))
    (LeFloat64, LitF64(x), LitF64(y)) =>
      Some(DataFlowLiteral::i32(if x <= y { 1 } else { 0 }))
    (GtFloat64, LitF64(x), LitF64(y)) =>
      Some(DataFlowLiteral::i32(if x > y { 1 } else { 0 }))
    (GeFloat64, LitF64(x), LitF64(y)) =>
      Some(DataFlowLiteral::i32(if x >= y { 1 } else { 0 }))
    _ => None
  }
}

///|
fn get_const_value(graph : Graph, node_id : NodeId) -> DataFlowLiteral? {
  match graph.node_store.get(node_id) {
    Some({ expr: Some(Const(c)), .. }) => Some(c.value)
    _ => None
  }
}

///|
fn is_power_of_2_i32(x : Int) -> Bool {
  x > 0 && (x & (x - 1)) == 0
}

///|
fn is_power_of_2_i64(x : Int64) -> Bool {
  x > 0L && (x & (x - 1L)) == 0L
}

///|
fn log2_i32(x : Int) -> Int {
  31 - x.clz()
}

///|
fn log2_i64(x : Int64) -> Int64 {
  (63 - x.clz()).to_int64()
}

///|
fn try_strength_reduce(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  bin : BinaryExpr,
  work : Set[NodeId],
) -> Bool {
  match bin.op {
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
          graph.replace_all_uses(users, node.id, new_node, work)
          return true
        }
        _ => ()
      }
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
          graph.replace_all_uses(users, node.id, new_node, work)
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
          graph.replace_all_uses(users, node.id, new_node, work)
          return true
        }
        _ => ()
      }
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
          graph.replace_all_uses(users, node.id, new_node, work)
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
          graph.replace_all_uses(users, node.id, new_node, work)
          return true
        }
        _ => ()
      }
    // x % (2^n) => x & (2^n - 1) for unsigned
    RemUInt32 =>
      match get_const_value(graph, node.values[1]) {
        Some(LitI32(c)) if is_power_of_2_i32(c) => {
          let mask = c - 1
          let mask_const = graph.make_const(DataFlowLiteral::i32(mask))
          let new_expr = Expression::binary(
            BinaryExpr::new(
              DataFlowBinaryOp::and_int32(),
              ExprId::new(node.values[0].0),
              ExprId::new(mask_const.0),
              WasmType::i32(),
            ),
          )
          let new_node = graph.add_node(
            Node::make_expr(NodeId::new(0), new_expr, node.origin),
          )
          match graph.node_store.get_mut(new_node) {
            Some(n) => {
              n.values.push(node.values[0])
              n.values.push(mask_const)
            }
            None => ()
          }
          graph.replace_all_uses(users, node.id, new_node, work)
          return true
        }
        _ => ()
      }
    RemUInt64 =>
      match get_const_value(graph, node.values[1]) {
        Some(LitI64(c)) if is_power_of_2_i64(c) => {
          let mask = c - 1L
          let mask_const = graph.make_const(DataFlowLiteral::i64(mask))
          let new_expr = Expression::binary(
            BinaryExpr::new(
              DataFlowBinaryOp::and_int64(),
              ExprId::new(node.values[0].0),
              ExprId::new(mask_const.0),
              WasmType::i64(),
            ),
          )
          let new_node = graph.add_node(
            Node::make_expr(NodeId::new(0), new_expr, node.origin),
          )
          match graph.node_store.get_mut(new_node) {
            Some(n) => {
              n.values.push(node.values[0])
              n.values.push(mask_const)
            }
            None => ()
          }
          graph.replace_all_uses(users, node.id, new_node, work)
          return true
        }
        _ => ()
      }
    _ => ()
  }
  false
}

// Reassociation: (a + C1) + C2 => a + (C1 + C2)

///|
fn try_reassociate(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  bin : BinaryExpr,
  work : Set[NodeId],
) -> Bool {
  // Check if right operand is constant
  let right_const = match get_const_value(graph, node.values[1]) {
    Some(c) => c
    None => return false
  }

  // Check if left operand is same binary op with a constant
  let left_node = match graph.node_store.get(node.values[0]) {
    Some(n) => n
    None => return false
  }
  match left_node.expr {
    Some(Binary(left_bin)) if left_bin.op == bin.op && bin.op.is_associative() => {
      match get_const_value(graph, left_node.values[1]) {
        Some(left_const) => {
          // Fold the two constants
          match eval_binary(bin.op, left_const, right_const) {
            Some(folded) => {
              let folded_const = graph.make_const(folded)
              let new_expr = Expression::binary(
                BinaryExpr::new(
                  bin.op,
                  ExprId::new(left_node.values[0].0),
                  ExprId::new(folded_const.0),
                  bin.result_type,
                ),
              )
              let new_node = graph.add_node(
                Node::make_expr(NodeId::new(0), new_expr, node.origin),
              )
              match graph.node_store.get_mut(new_node) {
                Some(n) => {
                  n.values.push(left_node.values[0])
                  n.values.push(folded_const)
                }
                None => ()
              }
              graph.replace_all_uses( users, node.id, new_node, work)
              return true
            }
            None => ()
          }
        }
        None => ()
      }
    }
    _ => ()
  }
  false
}

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

  // Try reassociation
  if try_reassociate(graph, users, node, bin, work) {
    return true
  }
  match (bin.op, left_node, right_node) {
    // x + 0 => x
    (AddInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. }))
    | (AddInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. }))
    | (AddFloat32, _, Some({ expr: Some(Const({ value: LitF32(0.0) })), .. }))
    | (AddFloat64, _, Some({ expr: Some(Const({ value: LitF64(0.0) })), .. })) => {
      graph.replace_all_uses( users, node.id, node.values[0], work)
      return true
    }
    // 0 + x => x
    (AddInt32, Some({ expr: Some(Const({ value: LitI32(0) })), .. }), _)
    | (AddInt64, Some({ expr: Some(Const({ value: LitI64(0L) })), .. }), _)
    | (AddFloat32, Some({ expr: Some(Const({ value: LitF32(0.0) })), .. }), _)
    | (AddFloat64, Some({ expr: Some(Const({ value: LitF64(0.0) })), .. }), _) => {
      graph.replace_all_uses(users, node.id, node.values[1], work)
      return true
    }
    // x - 0 => x
    (SubInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. }))
    | (SubInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. }))
    | (SubFloat32, _, Some({ expr: Some(Const({ value: LitF32(0.0) })), .. }))
    | (SubFloat64, _, Some({ expr: Some(Const({ value: LitF64(0.0) })), .. })) => {
      graph.replace_all_uses(users, node.id, node.values[0], work)
      return true
    }
    // x * 0 => 0
    (MulInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. } as zero))
    | (
      MulInt32,
      Some({ expr: Some(Const({ value: LitI32(0) })), .. } as zero),
      _,
    ) => {
      graph.replace_all_uses(users, node.id, zero.id, work)
      return true
    }
    (MulInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. } as zero)
    )
    | (
      MulInt64,
      Some({ expr: Some(Const({ value: LitI64(0L) })), .. } as zero),
      _,
    ) => {
      graph.replace_all_uses(users, node.id, zero.id, work)
      return true
    }
    // x * 1 => x
    (MulInt32, _, Some({ expr: Some(Const({ value: LitI32(1) })), .. }))
    | (MulInt64, _, Some({ expr: Some(Const({ value: LitI64(1L) })), .. }))
    | (MulFloat32, _, Some({ expr: Some(Const({ value: LitF32(1.0) })), .. }))
    | (MulFloat64, _, Some({ expr: Some(Const({ value: LitF64(1.0) })), .. })) => {
      graph.replace_all_uses(users, node.id, node.values[0], work)
      return true
    }
    // 1 * x => x
    (MulInt32, Some({ expr: Some(Const({ value: LitI32(1) })), .. }), _)
    | (MulInt64, Some({ expr: Some(Const({ value: LitI64(1L) })), .. }), _)
    | (MulFloat32, Some({ expr: Some(Const({ value: LitF32(1.0) })), .. }), _)
    | (MulFloat64, Some({ expr: Some(Const({ value: LitF64(1.0) })), .. }), _) => {
      graph.replace_all_uses(users, node.id, node.values[1], work)
      return true
    }
    // x * -1 => -x (for floats)
    (MulFloat32, _, Some({ expr: Some(Const({ value: LitF32(-1.0) })), .. }))
    | (MulFloat32, Some({ expr: Some(Const({ value: LitF32(-1.0) })), .. }), _) => {
      let new_expr = Expression::unary(
        UnaryExpr::new(
          DataFlowUnaryOp::neg_float32(),
          ExprId::new(
            if get_const_value(graph, node.values[0]) is None {
              node.values[0].0
            } else {
              node.values[1].0
            },
          ),
          WasmType::f32(),
        ),
      )
      let operand = if get_const_value(graph, node.values[0]) is None {
        node.values[0]
      } else {
        node.values[1]
      }
      let new_node = graph.add_node(
        Node::make_expr(NodeId::new(0), new_expr, node.origin),
      )
      match graph.node_store.get_mut(new_node) {
        Some(n) => n.values.push(operand)
        None => ()
      }
      graph.replace_all_uses(users, node.id, new_node, work)
      return true
    }
    (MulFloat64, _, Some({ expr: Some(Const({ value: LitF64(-1.0) })), .. }))
    | (MulFloat64, Some({ expr: Some(Const({ value: LitF64(-1.0) })), .. }), _) => {
      let new_expr = Expression::unary(
        UnaryExpr::new(
          DataFlowUnaryOp::neg_float64(),
          ExprId::new(
            if get_const_value(graph, node.values[0]) is None {
              node.values[0].0
            } else {
              node.values[1].0
            },
          ),
          WasmType::f64(),
        ),
      )
      let operand = if get_const_value(graph, node.values[0]) is None {
        node.values[0]
      } else {
        node.values[1]
      }
      let new_node = graph.add_node(
        Node::make_expr(NodeId::new(0), new_expr, node.origin),
      )
      match graph.node_store.get_mut(new_node) {
        Some(n) => n.values.push(operand)
        None => ()
      }
      graph.replace_all_uses(users, node.id, new_node, work)
      return true
    }
    // x / 1 => x
    (DivSInt32, _, Some({ expr: Some(Const({ value: LitI32(1) })), .. }))
    | (DivUInt32, _, Some({ expr: Some(Const({ value: LitI32(1) })), .. }))
    | (DivSInt64, _, Some({ expr: Some(Const({ value: LitI64(1L) })), .. }))
    | (DivUInt64, _, Some({ expr: Some(Const({ value: LitI64(1L) })), .. }))
    | (DivFloat32, _, Some({ expr: Some(Const({ value: LitF32(1.0) })), .. }))
    | (DivFloat64, _, Some({ expr: Some(Const({ value: LitF64(1.0) })), .. })) => {
      graph.replace_all_uses(users, node.id, node.values[0], work)
      return true
    }
    // x & 0 => 0
    (AndInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. } as zero))
    | (
      AndInt32,
      Some({ expr: Some(Const({ value: LitI32(0) })), .. } as zero),
      _,
    ) => {
      graph.replace_all_uses(users, node.id, zero.id, work)
      return true
    }
    (AndInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. } as zero)
    )
    | (
      AndInt64,
      Some({ expr: Some(Const({ value: LitI64(0L) })), .. } as zero),
      _,
    ) => {
      graph.replace_all_uses(users, node.id, zero.id, work)
      return true
    }
    // x & -1 => x
    (AndInt32, _, Some({ expr: Some(Const({ value: LitI32(-1) })), .. }))
    | (AndInt64, _, Some({ expr: Some(Const({ value: LitI64(-1L) })), .. })) => {
      graph.replace_all_uses(users, node.id, node.values[0], work)
      return true
    }
    (AndInt32, Some({ expr: Some(Const({ value: LitI32(-1) })), .. }), _)
    | (AndInt64, Some({ expr: Some(Const({ value: LitI64(-1L) })), .. }), _) => {
      graph.replace_all_uses(users, node.id, node.values[1], work)
      return true
    }
    // x | 0 => x
    (OrInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. }))
    | (OrInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. })) => {
      graph.replace_all_uses(users, node.id, node.values[0], work)
      return true
    }
    (OrInt32, Some({ expr: Some(Const({ value: LitI32(0) })), .. }), _)
    | (OrInt64, Some({ expr: Some(Const({ value: LitI64(0L) })), .. }), _) => {
      graph.replace_all_uses(users, node.id, node.values[1], work)
      return true
    }
    // x | -1 => -1
    (OrInt32, _, Some({ expr: Some(Const({ value: LitI32(-1) })), .. } as ones))
    | (
      OrInt32,
      Some({ expr: Some(Const({ value: LitI32(-1) })), .. } as ones),
      _,
    ) => {
      graph.replace_all_uses(users, node.id, ones.id, work)
      return true
    }
    (OrInt64, _, Some({ expr: Some(Const({ value: LitI64(-1L) })), .. } as ones)
    )
    | (
      OrInt64,
      Some({ expr: Some(Const({ value: LitI64(-1L) })), .. } as ones),
      _,
    ) => {
      graph.replace_all_uses(users, node.id, ones.id, work)
      return true
    }
    // x ^ 0 => x
    (XorInt32, _, Some({ expr: Some(Const({ value: LitI32(0) })), .. }))
    | (XorInt64, _, Some({ expr: Some(Const({ value: LitI64(0L) })), .. })) => {
      graph.replace_all_uses(users, node.id, node.values[0], work)
      return true
    }
    (XorInt32, Some({ expr: Some(Const({ value: LitI32(0) })), .. }), _)
    | (XorInt64, Some({ expr: Some(Const({ value: LitI64(0L) })), .. }), _) => {
      graph.replace_all_uses(users, node.id, node.values[1], work)
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
      graph.replace_all_uses(users, node.id, node.values[0], work)
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
      graph.replace_all_uses(users, node.id, zero.id, work)
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
      graph.replace_all_uses(users, node.id, zero.id, work)
      return true
    }
    // x - x => 0, x ^ x => 0
    (SubInt32, _, _) | (XorInt32, _, _) if node.values[0] == node.values[1] => {
      let zero = graph.make_const(DataFlowLiteral::i32(0))
      graph.replace_all_uses(users, node.id, zero, work)
      return true
    }
    (SubInt64, _, _) | (XorInt64, _, _) if node.values[0] == node.values[1] => {
      let zero = graph.make_const(DataFlowLiteral::i64(0L))
      graph.replace_all_uses(users, node.id, zero, work)
      return true
    }
    (SubFloat32, _, _) if node.values[0] == node.values[1] => {
      let zero = graph.make_const(DataFlowLiteral::f32(0.0))
      graph.replace_all_uses(users, node.id, zero, work)
      return true
    }
    (SubFloat64, _, _) if node.values[0] == node.values[1] => {
      let zero = graph.make_const(DataFlowLiteral::f64(0.0))
      graph.replace_all_uses(users, node.id, zero, work)
      return true
    }
    // x & x => x, x | x => x
    (AndInt32, _, _) | (AndInt64, _, _) | (OrInt32, _, _) | (OrInt64, _, _) if node.values[0] ==
      node.values[1] => {
      graph.replace_all_uses(users, node.id, node.values[0], work)
      return true
    }
    // x == x => 1
    (EqInt32, _, _) | (EqInt64, _, _) if node.values[0] == node.values[1] => {
      let one = graph.make_const(DataFlowLiteral::i32(1))
      graph.replace_all_uses(users, node.id, one, work)
      return true
    }
    // x != x => 0
    (NeInt32, _, _) | (NeInt64, _, _) if node.values[0] == node.values[1] => {
      let zero = graph.make_const(DataFlowLiteral::i32(0))
      graph.replace_all_uses(users, node.id, zero, work)
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
      graph.replace_all_uses(users, node.id, one, work)
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
      graph.replace_all_uses(users, node.id, zero, work)
      return true
    }
    // x / x => 1 (when x is known non-zero constant)
    (DivSInt32, _, _) | (DivUInt32, _, _) if node.values[0] == node.values[1] =>
      match get_const_value(graph, node.values[0]) {
        Some(LitI32(x)) if x != 0 => {
          let one = graph.make_const(DataFlowLiteral::i32(1))
          graph.replace_all_uses(users, node.id, one, work)
          return true
        }
        _ => ()
      }
    (DivSInt64, _, _) | (DivUInt64, _, _) if node.values[0] == node.values[1] =>
      match get_const_value(graph, node.values[0]) {
        Some(LitI64(x)) if x != 0L => {
          let one = graph.make_const(DataFlowLiteral::i64(1L))
          graph.replace_all_uses(users, node.id, one, work)
          return true
        }
        _ => ()
      }
    _ => ()
  }
  false
}

// Truncation/extension chain simplification
///|
fn try_simplify_conversion_chain(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  un : UnaryExpr,
  work : Set[NodeId],
) -> Bool {
  match un.op {
    // wrap(extend_s(x)) => x when x is i32
    WrapInt64 =>
      match graph.node_store.get(node.values[0]) {
        Some({ expr: Some(Unary(inner)), values: inner_vals, .. }) if inner.op ==
          DataFlowUnaryOp::extend_s_int32() &&
          inner_vals.length() > 0 => {
          graph.replace_all_uses(users, node.id, inner_vals[0], work)
          return true
        }
        Some({ expr: Some(Unary(inner)), values: inner_vals, .. }) if inner.op ==
          DataFlowUnaryOp::extend_u_int32() &&
          inner_vals.length() > 0 => {
          graph.replace_all_uses(users, node.id, inner_vals[0], work)
          return true
        }
        _ => ()
      }
    // demote(promote(x)) => x
    DemoteFloat64 =>
      match graph.node_store.get(node.values[0]) {
        Some({ expr: Some(Unary(inner)), values: inner_vals, .. }) if inner.op ==
          DataFlowUnaryOp::promote_float32() &&
          inner_vals.length() > 0 => {
          graph.replace_all_uses(users, node.id, inner_vals[0], work)
          return true
        }
        _ => ()
      }
    // extend_s(wrap(x)) where x is known to fit in i32 signed range
    ExtendSInt32 =>
      match graph.node_store.get(node.values[0]) {
        Some({ expr: Some(Unary(inner)), values: inner_vals, .. }) if inner.op ==
          DataFlowUnaryOp::wrap_int64() &&
          inner_vals.length() > 0 =>
          match get_const_value(graph, inner_vals[0]) {
            Some(LitI64(v)) if v >= -2147483648L && v <= 2147483647L => {
              graph.replace_all_uses(users, node.id, inner_vals[0], work)
              return true
            }
            _ => ()
          }
        _ => ()
      }
    // extend_u(wrap(x)) where x is known to fit in u32 range
    ExtendUInt32 =>
      match graph.node_store.get(node.values[0]) {
        Some({ expr: Some(Unary(inner)), values: inner_vals, .. }) if inner.op ==
          DataFlowUnaryOp::wrap_int64() &&
          inner_vals.length() > 0 =>
          match get_const_value(graph, inner_vals[0]) {
            Some(LitI64(v)) if v >= 0L && v <= 4294967295L => {
              graph.replace_all_uses(users, node.id, inner_vals[0], work)
              return true
            }
            _ => ()
          }
        _ => ()
      }
    _ => ()
  }
  false
}

///|
fn try_simplify_select(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  work : Set[NodeId],
) -> Bool {
  // Select node has 3 values: [condition, true_val, false_val]
  if node.values.length() != 3 {
    return false
  }
  let cond_id = node.values[0]
  let true_id = node.values[1]
  let false_id = node.values[2]

  // select(1, a, b) => a
  match get_const_value(graph, cond_id) {
    Some(LitI32(c)) if c != 0 => {
      graph.replace_all_uses(users, node.id, true_id, work)
      return true
    }
    Some(LitI32(0)) => {
      // select(0, a, b) => b
      graph.replace_all_uses(users, node.id, false_id, work)
      return true
    }
    _ => ()
  }

  // select(c, a, a) => a
  if true_id == false_id {
    graph.replace_all_uses(users, node.id, true_id, work)
    return true
  }
  false
}

///|
fn try_fold_phi(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  work : Set[NodeId],
) -> Bool {
  // Phi node: values[0] is block, values[1..] are the actual phi values
  if node.values.length() <= 1 {
    return false
  }

  // Check if all phi inputs (excluding block at index 0) are identical
  let first_val = node.values[1]
  for i = 2; i < node.values.length(); i = i + 1 {
    if node.values[i] != first_val {
      return false
    }
  }

  // All inputs are identical, replace phi with that value
  graph.replace_all_uses(users, node.id, first_val, work)
  true
}


///|
fn try_eliminate_redundant_load(
  graph : Graph,
  mssa : MemorySSA,
  users : NodeUsers,
  node : Node,
  load : LoadExpr,
  work : Set[NodeId],
) -> Bool {
  let mem_state = match mssa.get_defining_access(node.id) {
    Some(s) => s
    None => return false
  }
  
  let our_access = match get_access_info(graph, node) {
    Some(a) => a
    None => return false
  }
  
  // Walk back through memory state looking for a store to the same location
  match graph.node_store.get(mem_state) {
    Some(def_node) if def_node.is_memory_def() => {
      // Check if this is a store to the same location
      match def_node.expr {
        Some(Store(store)) => {
          let store_access = match get_access_info(graph, def_node) {
            Some(a) => a
            None => return false
          }
          match check_alias(graph, our_access, store_access) {
            MustAlias => {
              // The load reads what was just stored
              // Replace load with the stored value
              let stored_value = def_node.values[1]  // store's value operand
              graph.replace_all_uses(users, node.id, stored_value, work)
              return true
            }
            _ => ()
          }
        }
        _ => ()
      }
    }
    _ => ()
  }
  
  // Look for a previous load from the same location with same memory state
  // This requires walking users of the memory state
  false
}

///|
fn try_eliminate_dead_store(
  graph : Graph,
  mssa : MemorySSA,
  users : NodeUsers,
  node : Node,
  store : StoreExpr,
  work : Set[NodeId],
) -> Bool {
  let our_access = match get_access_info(graph, node) {
    Some(a) => a
    None => return false
  }
  
  // Check if there's a subsequent store that overwrites this one
  // without any intervening read
  for user_id in users.get_users(node.id) {
    match graph.node_store.get(user_id) {
      Some(user_node) => {
        match user_node.expr {
          Some(Store(_)) => {
            let user_access = match get_access_info(graph, user_node) {
              Some(a) => a
              None => continue
            }
            match check_alias(graph, our_access, user_access) {
              MustAlias => {
                if no_intervening_loads(graph, mssa, node.id, user_id, our_access) {
                  // Actually remove the dead store
                  graph.node_store.remove(node.id)
                  users.remove_all_uses_of(node.id)
                  // Add users of our inputs to worklist (they may become dead)
                  for v in node.values {
                    work.add(v)
                  }
                  return true
                }
              }
              _ => ()
            }
          }
          Some(Load(_)) => {
            // There's a load that might read this store
            let user_access = match get_access_info(graph, user_node) {
              Some(a) => a
              None => continue
            }
            match check_alias(graph, our_access, user_access) {
              NoAlias => continue  // Load doesn't read our store
              _ => return false    // Store might be read
            }
          }
          _ => ()
        }
      }
      None => ()
    }
  }
  false
}

///|
fn no_intervening_loads(
  graph : Graph,
  mssa : MemorySSA,
  from : NodeId,
  to : NodeId,
  access : (NodeId, Int, Int),
) -> Bool {
  let from_mem = match mssa.get_defining_access(from) {
    Some(id) => id
    None => return false
  }

  let to_mem = match mssa.get_defining_access(to) {
    Some(id) => id
    None => return false
  }

  let work : Array[NodeId] = [from_mem]
  let visited : Set[NodeId] = Set::new()

  while work.length() > 0 {
    let mem_id = work.pop().unwrap()

    if visited.contains(mem_id) {
      continue
    }
    visited.add(mem_id)

    for user in graph.node_store.get(mem_id).unwrap().values {
      match graph.node_store.get(user) {
        Some(node) => {
          if user == to_mem {
            continue
          }

          match node.expr {
            Some(Load(_)) => {
              let load_access = match get_access_info(graph, node) {
                Some(a) => a
                None => return false
              }

              match check_alias(graph, access, load_access) {
                NoAlias => ()
                _ => {
                  // If load is NOT dominated by `to`, then store is observable
                  if not(graph.dominates(to, node.id)) {
                    return false
                  }
                }
              }
            }
            Some(Store(_)) => {
              let store_access = match get_access_info(graph, node) {
                Some(a) => a
                None => return false
              }

              match check_alias(graph, access, store_access) {
                MustAlias => {
                  if graph.dominates(node.id, to) {
                    continue
                  }
                }
                _ => ()
              }
            }
            _ => ()
          }

          work.push(user)
        }
        None => ()
      }
    }
  }

  true
}
///|
/// Run Global Value Numbering on the graph

///|
/// Run phi-aware GVN with fixed-point iteration for cycles
fn run_gvn(graph : Graph) -> Unit {
  let gvn = GVN::new()
  let users = NodeUsers::build(graph)
  
  // Collect all phi nodes for iterative processing
  let phi_nodes : Array[NodeId] = []
  for node in graph.node_store.nodes {
    if node.is_phi() {
      phi_nodes.push(node.id)
    }
  }
  
  // First pass: process all nodes optimistically
  for node in graph.node_store.nodes {
    gvn.process_node_optimistic(graph, node)
  }
  
  // Fixed-point iteration for phi nodes
  let max_iterations = 10
  for iter = 0; iter < max_iterations; iter = iter + 1 {
    gvn.set_changed(false)
    gvn.set_iteration(iter)
    
    // Clear and rebuild expression map for this iteration
    gvn.expr_to_leader.clear()
    
    // Reprocess all nodes with current value numbers
    for node in graph.node_store.nodes {
      gvn.reprocess_node(graph, node)
    }
    
    if not(gvn.changed) {
      break
    }
  }
  
  // Collect replacements
  let replacements : Array[(NodeId, NodeId)] = []
  for node in graph.node_store.nodes {
    let vn = gvn.get_value_number(node.id)
    if vn != node.id {
      replacements.push((node.id, vn))
    }
  }
  
  // Apply replacements
  let work : @set.Set[NodeId] = @set.Set::new()
  for replacement in replacements {
    let (from, to) = replacement
    graph.replace_all_uses(users, from, to, work)
  }
  
  // Run simplification on affected nodes
  while not(work.is_empty()) {
    let node_id = set_pop_any(work)
    match graph.node_store.get(node_id) {
      Some(node) => {
        let _ = simplify_node(graph, users, node, work)
      }
      None => ()
    }
  }
}

///|
/// Run phi-web aware GVN
pub fn run_phi_web_gvn(graph : Graph) -> Unit {
  let web_gvn = PhiWebGVN::new()
  let users = NodeUsers::build(graph)
  
  // First run basic GVN for non-phi nodes
  for node in graph.node_store.nodes {
    if not(node.is_phi()) {
      web_gvn.gvn.process_node_optimistic(graph, node)
    }
  }
  
  // Compute phi congruence classes
  web_gvn.compute_congruence(graph)
  
  // Collect replacements based on congruence classes
  let replacements : Array[(NodeId, NodeId)] = []
  
  // For each phi, replace with its class representative if different
  for node in graph.node_store.nodes {
    if node.is_phi() {
      let rep = web_gvn.congruence.find(node.id)
      if rep != node.id {
        replacements.push((node.id, rep))
      }
    } else {
      let vn = web_gvn.gvn.get_value_number(node.id)
      if vn != node.id {
        replacements.push((node.id, vn))
      }
    }
  }
  
  // Apply replacements
  let work : @set.Set[NodeId] = @set.Set::new()
  for replacement in replacements {
    let (from, to) = replacement
    graph.replace_all_uses(users, from, to, work)
  }
  
  // Cleanup
  while not(work.is_empty()) {
    let node_id = set_pop_any(work)
    match graph.node_store.get(node_id) {
      Some(node) => {
        let _ = simplify_node(graph, users, node, work)
      }
      None => ()
    }
  }
}
///|
/// Run dominator-based GVN
pub fn run_dominator_gvn(graph : Graph) -> Unit {
  let dgvn = DominatorGVN::new()
  let users = NodeUsers::build(graph)
  let replacements : Array[(NodeId, NodeId)] = []

  // Process all nodes - for a more complete implementation,
  // we'd walk the dominator tree, but this simplified version
  // processes nodes in order
  for node in graph.node_store.nodes {
    match node.expr {
      Some(If(if_expr)) =>
        dgvn.process_if(graph, if_expr, users, replacements)
      Some(Block(_)) =>
        dgvn.process_block(graph, node, users, replacements)
      _ =>
        match dgvn.process_node(graph, node) {
          Some(leader) => replacements.push((node.id, leader))
          None => ()
        }
    }
  }

  // Apply replacements
  let work : Set[NodeId] = Set::new()
  for replacement in replacements {
    let (from, to) = replacement
    graph.replace_all_uses(users, from, to, work)
  }

  // Cleanup
  while not(work.is_empty()) {
    let node_id = set_pop_any(work)
    match graph.node_store.get(node_id) {
      Some(node) => {
        let _ = simplify_node(graph, users, node, work)
      }
      None => ()
    }
  }
}

///|
fn simplify_node(
  graph : Graph,
  users : NodeUsers,
  node : Node,
  work : Set[NodeId],
) -> Bool {
  match node.node_type {
    Phi => return try_fold_phi(graph, users, node, work)
    Expr =>
      match node.expr {
        Some(Nop) => return false // Nothing to simplify
        Some(Unreachable) => return false // Nothing to simplify
        Some(Unary(un)) => {
          // Try constant folding
          match get_all_constant_values(graph, node) {
            Some(vals) if vals.length() == 1 =>
              match eval_unary(un.op, vals[0]) {
                Some(result) => {
                  let const_node = graph.make_const(result)
                  graph.replace_all_uses(users, node.id, const_node, work)
                  return true
                }
                None => ()
              }
            _ => ()
          }
          // Try conversion chain simplification
          if try_simplify_conversion_chain(graph, users, node, un, work) {
            return true
          }
        }
        Some(Binary(bin)) => {
          // Try constant folding
          match get_all_constant_values(graph, node) {
            Some(vals) if vals.length() == 2 =>
              match eval_binary(bin.op, vals[0], vals[1]) {
                Some(result) => {
                  let const_node = graph.make_const(result)
                  graph.replace_all_uses(users, node.id, const_node, work)
                  return true
                }
                None => ()
              }
            _ => ()
          }
          // Try algebraic simplifications
          if try_simplify_binary(graph, users, node, bin, work) {
            return true
          }
        }
        Some(Select(_)) =>
          if try_simplify_select(graph, users, node, work) {
            return true
          }
        Some(Drop(drop_expr)) =>
          if try_simplify_drop(graph, users, node, drop_expr, work) {
            return true
          }
        Some(Load(load)) => {
          if try_simplify_load(graph, users, node, load, work) {
            return true
          }
          // Add memory optimization when MSSA is available
          match graph.mssa {
            Some(m) =>
              if try_eliminate_redundant_load(graph, m, users, node, load, work) {
                return true
              }
            None => ()
          }
        }
        Some(Store(store)) => {
          if try_simplify_store(graph, users, node, store, work) {
            return true
          }
          match graph.mssa {
            Some(m) =>
              if try_eliminate_dead_store(graph, m, users, node, store, work) {
                return true
              }
            None => ()
          }
        }
        Some(Call(call)) =>
          if try_simplify_call(graph, users, node, call, work) {
            return true
          }
        Some(Return(ret)) =>
          if try_simplify_return(graph, users, node, ret, work) {
            return true
          }
        Some(MemoryGrow(mem_grow)) =>
          if try_simplify_memory_grow(graph, users, node, mem_grow, work) {
            return true
          }
        Some(MemorySize(mem_size)) =>
          if try_simplify_memory_size(graph, users, node, mem_size, work) {
            return true
          }
        Some(LocalGet(_)) => return false // Handled by graph building
        Some(LocalSet(_)) => return false // Handled by graph building
        Some(Const(_)) => return false // Already a constant
        Some(Block(_)) => return false // Control flow
        Some(If(_)) => return false // Control flow
        Some(Loop(_)) => return false // Control flow
        Some(Break(_)) => return false // Control flow
        Some(Switch(_)) => return false // Control flow
        Some(Generic(_)) => return false // Opaque
        None => ()
      }
    _ => ()
  }
  false
}


///|
priv enum AliasResult {
  MustAlias     // Definitely the same location
  MayAlias      // Could be the same location
  NoAlias       // Definitely different locations
}

///|
fn get_access_info(
  _graph : Graph, 
  node : Node
) -> (NodeId, Int, Int)? {
  // Returns (base_ptr, offset, size) for a memory access
  match node.expr {
    Some(Load(load)) => {
      let size = match load.op {
        Load8SI32 | Load8UI32 | Load8SI64 | Load8UI64 => 1
        Load16SI32 | Load16UI32 | Load16SI64 | Load16UI64 => 2
        LoadI32 | Load32SI64 | Load32UI64 | LoadF32 => 4
        LoadI64 | LoadF64 => 8
      }
      Some((node.values[0], load.offset, size))
    }
    Some(Store(store)) => {
      let size = match store.op {
        Store8I32 | Store8I64 => 1
        Store16I32 | Store16I64 => 2
        StoreI32 | Store32I64 | StoreF32 => 4
        StoreI64 | StoreF64 => 8
      }
      Some((node.values[0], store.offset, size))
    }
    _ => None
  }
}

///|
fn check_alias(
  graph : Graph,
  access1 : (NodeId, Int, Int),
  access2 : (NodeId, Int, Int)
) -> AliasResult {
  let (ptr1, offset1, size1) = access1
  let (ptr2, offset2, size2) = access2
  
  // If base pointers are the same node
  if ptr1 == ptr2 {
    // Check if offset ranges overlap
    let end1 = offset1 + size1
    let end2 = offset2 + size2
    if offset1 >= end2 || offset2 >= end1 {
      return NoAlias  // Non-overlapping ranges
    }
    if offset1 == offset2 && size1 == size2 {
      return MustAlias
    }
    return MayAlias  // Overlapping but not identical
  }
  
  // Check if both are constant pointers
  match (get_const_value(graph, ptr1), get_const_value(graph, ptr2)) {
    (Some(LitI32(p1)), Some(LitI32(p2))) => {
      let addr1 = p1 + offset1
      let addr2 = p2 + offset2
      let end1 = addr1 + size1
      let end2 = addr2 + size2
      if addr1 >= end2 || addr2 >= end1 {
        return NoAlias
      }
      if addr1 == addr2 && size1 == size2 {
        return MustAlias
      }
      return MayAlias
    }
    _ => MayAlias  // Conservative: unknown pointers may alias
  }
}

///|
fn optimize(graph : Graph) -> Unit {
  let users = NodeUsers::build(graph)
  let work : Set[NodeId] = Set::new()

  for node in graph.node_store.nodes {
    work.add(node.id)
  }

  while not(work.is_empty()) {
    let node_id = set_pop_any(work)
    match graph.node_store.get(node_id) {
      Some(node) => {
        let _ = simplify_node(graph, users, node, work)
      }
      None => ()
    }
  }
}

///|
fn try_simplify_drop(
  graph : Graph,
  _users : NodeUsers,
  node : Node,
  _drop_expr : DropExpr,
  _work : Set[NodeId],
) -> Bool {
  // drop(const) => remove (the drop itself becomes dead)
  // drop(pure_expr) => remove
  let value_id = node.values[0]
  match graph.node_store.get(value_id) {
    Some(value_node) if value_node.is_const() => {
      // The drop of a constant has no effect - mark for removal
      // Replace with a nop or just let DCE handle it
      return false // Let DCE clean this up
    }
    Some(value_node) if not(value_node.has_side_effects()) => {
      // Dropping a pure expression - let DCE handle it
      return false
    }
    _ => ()
  }
  false
}

///|
fn try_simplify_load(
  _graph : Graph,
  _users : NodeUsers,
  _node : Node,
  _load : LoadExpr,
  _work : Set[NodeId],
) -> Bool {
  // Load optimizations are limited without more context
  // Could add: redundant load elimination if we track memory state
  false
}

///|
fn try_simplify_store(
  _graph : Graph,
  _users : NodeUsers,
  _node : Node,
  _store : StoreExpr,
  _work : Set[NodeId],
) -> Bool {
  // Store optimizations:
  // - Dead store elimination would require tracking subsequent stores
  // - store(ptr, load(ptr)) with no intervening writes => remove both
  false
}

///|
fn try_simplify_call(
  _graph : Graph,
  _users : NodeUsers,
  _node : Node,
  _call : CallExpr,
  _work : Set[NodeId],
) -> Bool {
  // Call optimizations are limited without interprocedural analysis
  // Could potentially:
  // - Inline small functions
  // - Recognize known pure functions and constant-fold
  false
}

///|
fn try_simplify_return(
  _graph : Graph,
  _users : NodeUsers,
  _node : Node,
  _ret : ReturnExpr,
  _work : Set[NodeId],
) -> Bool {
  // Return optimizations are very limited
  // Could potentially simplify return(select(c, a, b)) in some cases
  false
}

///|
fn try_simplify_memory_grow(
  graph : Graph,
  _users : NodeUsers,
  node : Node,
  _mem_grow : MemoryGrowExpr,
  _work : Set[NodeId],
) -> Bool {
  // memory.grow(0) returns current size but doesn't grow
  // Could potentially optimize, but has side effects (returns -1 on failure)
  match get_const_value(graph, node.values[0]) {
    Some(LitI32(0)) => {
      // memory.grow(0) is equivalent to memory.size but returns i32
      // Can't easily simplify without changing to memory.size
      ()
    }
    _ => ()
  }
  false
}

///|
fn try_simplify_memory_size(
  _graph : Graph,
  _users : NodeUsers,
  _node : Node,
  _mem_size : MemorySizeExpr,
  _work : Set[NodeId],
) -> Bool {
  // memory.size has no simplification without tracking memory state
  false
}

///|
fn eliminate_dead_code(graph : Graph) -> Unit {
  let users = NodeUsers::build(graph)
  let live : Set[NodeId] = Set::new()
  let worklist : Array[NodeId] = []

  // Mark roots as live (nodes with side effects or results)
  for node in graph.node_store.nodes {
    if node.is_root() || node.has_side_effects() {
      live.add(node.id)
      worklist.push(node.id)
    }
  }

  // Propagate liveness backwards
  while worklist.length() > 0 {
    let node_id = worklist.pop().unwrap()
    match graph.node_store.get(node_id) {
      Some(node) =>
        for v in node.values {
          if not(live.contains(v)) {
            live.add(v)
            worklist.push(v)
          }
        }
      None => ()
    }
  }

  // Remove dead nodes
  let dead : Array[NodeId] = []
  for node in graph.node_store.nodes {
    if not(live.contains(node.id)) {
      dead.push(node.id)
    }
  }
  for id in dead {
    graph.node_store.remove(id)
  }
}

///|
pub fn run_eliminate_redundant_computations(graph : Graph) -> Unit {
  // Run multiple passes until no changes
  for _pass = 0; _pass < 10; _pass = _pass + 1 {
    let initial_count = graph.node_store.nodes.length()
    
    // Run GVN first to eliminate redundant computations
    run_gvn(graph)
    
    // Then run local optimizations
    optimize(graph)
    
    // Finally eliminate dead code
    eliminate_dead_code(graph)
    
    let final_count = graph.node_store.nodes.length()
    if initial_count == final_count {
      break
    }
  }
}
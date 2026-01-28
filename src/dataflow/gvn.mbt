///|
/// Represents a canonical expression key for value numbering.
/// Two expressions with the same key compute the same value.
enum GVNKey {
  ConstKey(Literal)
  UnaryKey(UnaryOp, NodeId) // (op, value-numbered operand)
  BinaryKey(BinaryOp, NodeId, NodeId) // (op, vn(left), vn(right))
  SelectKey(NodeId, NodeId, NodeId) // (cond, true, false)
  // Memory operations are not value-numbered (they depend on memory state)
  // Calls are not value-numbered (may have side effects)
  // Phi key: (block, sorted value-numbered operands)
  PhiKey(NodeId, Array[NodeId])
  // Zext key for zero-extension nodes
  ZextKey(NodeId)
}

///|
impl Eq for GVNKey with equal(self, other) {
  match (self, other) {
    (ConstKey(a), ConstKey(b)) => a == b
    (UnaryKey(op1, v1), UnaryKey(op2, v2)) => op1 == op2 && v1 == v2
    (BinaryKey(op1, l1, r1), BinaryKey(op2, l2, r2)) =>
      op1 == op2 && l1 == l2 && r1 == r2
    (SelectKey(c1, t1, f1), SelectKey(c2, t2, f2)) =>
      c1 == c2 && t1 == t2 && f1 == f2
    (PhiKey(b1, ops1), PhiKey(b2, ops2)) => {
      if b1 != b2 {
        return false
      }
      if ops1.length() != ops2.length() {
        return false
      }
      for i in 0..<ops1.length() {
        if ops1[i] != ops2[i] {
          return false
        }
      }
      true
    }
    (ZextKey(v1), ZextKey(v2)) => v1 == v2
    _ => false
  }
}

///|
impl Hash for GVNKey with hash_combine(self, hasher) {
  match self {
    ConstKey(lit) => {
      hasher.combine(0)
      lit.hash_combine(hasher)
    }
    UnaryKey(op, v) => {
      hasher.combine(1)
      op.hash_combine(hasher)
      v.hash_combine(hasher)
    }
    BinaryKey(op, l, r) => {
      hasher.combine(2)
      op.hash_combine(hasher)
      l.hash_combine(hasher)
      r.hash_combine(hasher)
    }
    SelectKey(c, t, f) => {
      hasher.combine(3)
      c.hash_combine(hasher)
      t.hash_combine(hasher)
      f.hash_combine(hasher)
    }
    PhiKey(block, ops) => {
      hasher.combine(4)
      block.hash_combine(hasher)
      for op in ops {
        op.hash_combine(hasher)
      }
    }
    ZextKey(v) => {
      hasher.combine(5)
      v.hash_combine(hasher)
    }
  }
}

///|
/// Hash implementation for UnaryOp (required for GVNKey hashing)
impl Hash for UnaryOp with hash_combine(self, hasher) {
  // Use the discriminant/tag of the enum
  let tag : Int = match self {
    ClzInt32 => 0
    ClzInt64 => 1
    CtzInt32 => 2
    CtzInt64 => 3
    PopcntInt32 => 4
    PopcntInt64 => 5
    EqZInt32 => 6
    EqZInt64 => 7
    ExtendSInt32 => 8
    ExtendUInt32 => 9
    WrapInt64 => 10
    NegFloat32 => 11
    NegFloat64 => 12
    AbsFloat32 => 13
    AbsFloat64 => 14
    SqrtFloat32 => 15
    CeilFloat32 => 16
    FloorFloat32 => 17
    TruncFloat32 => 18
    NearestFloat32 => 19
    SqrtFloat64 => 20
    CeilFloat64 => 21
    FloorFloat64 => 22
    TruncFloat64 => 23
    NearestFloat64 => 24
    TruncSFloat32ToInt32 => 25
    TruncUFloat32ToInt32 => 26
    TruncSFloat64ToInt32 => 27
    TruncUFloat64ToInt32 => 28
    TruncSFloat32ToInt64 => 29
    TruncUFloat32ToInt64 => 30
    TruncSFloat64ToInt64 => 31
    TruncUFloat64ToInt64 => 32
    ConvertSInt32ToFloat32 => 33
    ConvertUInt32ToFloat32 => 34
    ConvertSInt64ToFloat32 => 35
    ConvertUInt64ToFloat32 => 36
    ConvertSInt32ToFloat64 => 37
    ConvertUInt32ToFloat64 => 38
    ConvertSInt64ToFloat64 => 39
    ConvertUInt64ToFloat64 => 40
    PromoteFloat32 => 41
    DemoteFloat64 => 42
    ReinterpretFloat32 => 43
    ReinterpretFloat64 => 44
    ReinterpretInt32 => 45
    ReinterpretInt64 => 46
  }
  hasher.combine(tag)
}

///|
/// Hash implementation for BinaryOp
impl Hash for BinaryOp with hash_combine(self, hasher) {
  let tag : Int = match self {
    AddInt32 => 0
    AddInt64 => 1
    SubInt32 => 2
    SubInt64 => 3
    MulInt32 => 4
    MulInt64 => 5
    DivSInt32 => 6
    DivSInt64 => 7
    DivUInt32 => 8
    DivUInt64 => 9
    RemSInt32 => 10
    RemSInt64 => 11
    RemUInt32 => 12
    RemUInt64 => 13
    AndInt32 => 14
    AndInt64 => 15
    OrInt32 => 16
    OrInt64 => 17
    XorInt32 => 18
    XorInt64 => 19
    ShlInt32 => 20
    ShlInt64 => 21
    ShrUInt32 => 22
    ShrUInt64 => 23
    ShrSInt32 => 24
    ShrSInt64 => 25
    RotLInt32 => 26
    RotLInt64 => 27
    RotRInt32 => 28
    RotRInt64 => 29
    EqInt32 => 30
    EqInt64 => 31
    NeInt32 => 32
    NeInt64 => 33
    LtSInt32 => 34
    LtSInt64 => 35
    LtUInt32 => 36
    LtUInt64 => 37
    LeSInt32 => 38
    LeSInt64 => 39
    LeUInt32 => 40
    LeUInt64 => 41
    GtSInt32 => 42
    GtSInt64 => 43
    GtUInt32 => 44
    GtUInt64 => 45
    GeSInt32 => 46
    GeSInt64 => 47
    GeUInt32 => 48
    GeUInt64 => 49
    AddFloat32 => 50
    AddFloat64 => 51
    SubFloat32 => 52
    SubFloat64 => 53
    MulFloat32 => 54
    MulFloat64 => 55
    DivFloat32 => 56
    DivFloat64 => 57
    MinFloat32 => 58
    MaxFloat32 => 59
    CopysignFloat32 => 60
    EqFloat32 => 61
    NeFloat32 => 62
    LtFloat32 => 63
    LeFloat32 => 64
    GtFloat32 => 65
    GeFloat32 => 66
    MinFloat64 => 67
    MaxFloat64 => 68
    CopysignFloat64 => 69
    EqFloat64 => 70
    NeFloat64 => 71
    LtFloat64 => 72
    LeFloat64 => 73
    GtFloat64 => 74
    GeFloat64 => 75
  }
  hasher.combine(tag)
}

///|
/// Check if a binary operation is commutative
fn is_commutative(op : BinaryOp) -> Bool {
  match op {
    AddInt32 | AddInt64 | AddFloat32 | AddFloat64 => true
    MulInt32 | MulInt64 | MulFloat32 | MulFloat64 => true
    AndInt32 | AndInt64 => true
    OrInt32 | OrInt64 => true
    XorInt32 | XorInt64 => true
    EqInt32 | EqInt64 | EqFloat32 | EqFloat64 => true
    NeInt32 | NeInt64 | NeFloat32 | NeFloat64 => true
    MinFloat32 | MinFloat64 | MaxFloat32 | MaxFloat64 => true
    _ => false
  }
}

///|
/// Global Value Numbering state
pub struct GVN {
  /// Maps each node to its value number
  value_number : Map[NodeId, NodeId]
  /// Maps expression keys to their leader
  expr_to_leader : Map[GVNKey, NodeId]
  /// Tracks which nodes are currently being processed (for cycle detection)
  in_progress : Set[NodeId]
  /// Iteration count for fixed-point computation
  mut iteration : Int
  /// Whether any value number changed in current iteration
  mut changed : Bool
}

///|
pub fn GVN::new() -> GVN {
  {
    value_number: Map::new(),
    expr_to_leader: Map::new(),
    in_progress: Set::new(),
    iteration: 0,
    changed: false,
  }
}

///|
pub fn GVN::set_iteration(self : GVN, iteration : Int) -> Unit {
  self.iteration = iteration
}

///|
pub fn GVN::set_changed(self : GVN, changed : Bool) -> Unit {
  self.changed = changed
}

///|
/// Get the value number (canonical representative) for a node
pub fn GVN::get_value_number(self : GVN, node_id : NodeId) -> NodeId {
  match self.value_number.get(node_id) {
    Some(vn) if vn != node_id => {
      let final_vn = self.get_value_number(vn)
      self.value_number.set(node_id, final_vn)
      final_vn
    }
    Some(vn) => vn
    None => node_id
  }
}

///|
/// Set the value number for a node
fn GVN::set_value_number(self : GVN, node_id : NodeId, leader : NodeId) -> Unit {
  let old = self.value_number.get(node_id)
  match old {
    Some(old_leader) if old_leader != leader => {
      self.value_number.set(node_id, leader)
      self.changed = true
    }
    None => {
      self.value_number.set(node_id, leader)
      self.changed = true
    }
    _ => ()
  }
}

///|
fn GVN::make_phi_key(self : GVN, node : Node) -> GVNKey? {
  if node.values.length() < 1 {
    return None
  }
  let block = node.values[0]
  let operands : Array[NodeId] = []

  // Get value numbers for all phi operands (skip block at index 0)
  for i = 1; i < node.values.length(); i = i + 1 {
    let vn = self.get_value_number(node.values[i])
    operands.push(vn)
  }
  Some(PhiKey(block, operands))
}

///|
/// Create a canonical key for an expression, using value-numbered operands
fn GVN::make_key(self : GVN, _graph : Graph, node : Node) -> GVNKey? {
  match node.node_type {
    Phi => self.make_phi_key(node)
    Zext => {
      if node.values.length() < 1 {
        return None
      }
      let operand_vn = self.get_value_number(node.values[0])
      Some(ZextKey(operand_vn))
    }
    Expr =>
      match node.expr {
        Some(Const(c)) => Some(ConstKey(c.value))
        Some(Unary(un)) => {
          if node.values.length() < 1 {
            return None
          }
          let operand_vn = self.get_value_number(node.values[0])
          Some(UnaryKey(un.op, operand_vn))
        }
        Some(Binary(bin)) => {
          if node.values.length() < 2 {
            return None
          }
          let left_vn = self.get_value_number(node.values[0])
          let right_vn = self.get_value_number(node.values[1])
          if is_commutative(bin.op) && right_vn.0 < left_vn.0 {
            Some(BinaryKey(bin.op, right_vn, left_vn))
          } else {
            Some(BinaryKey(bin.op, left_vn, right_vn))
          }
        }
        Some(Select(_)) => {
          if node.values.length() < 3 {
            return None
          }
          let cond_vn = self.get_value_number(node.values[0])
          let true_vn = self.get_value_number(node.values[1])
          let false_vn = self.get_value_number(node.values[2])
          Some(SelectKey(cond_vn, true_vn, false_vn))
        }
        _ => None
      }
    _ => None
  }
}

///|
/// Check if all phi operands (excluding block) are the same value
fn GVN::is_trivial_phi(self : GVN, node : Node) -> NodeId? {
  if node.values.length() <= 1 {
    return None
  }

  // Get value number of first operand
  let first_vn = self.get_value_number(node.values[1])

  // Check if all other operands have the same value number
  for i = 2; i < node.values.length(); i = i + 1 {
    let vn = self.get_value_number(node.values[i])
    if vn != first_vn {
      return None
    }
  }

  // All operands are equivalent, phi can be replaced with this value
  Some(first_vn)
}

///|
/// Check if a phi has itself as an operand (self-referential)
pub fn GVN::has_self_reference(self : GVN, node : Node) -> Bool {
  let node_vn = self.get_value_number(node.id)
  for i = 1; i < node.values.length(); i = i + 1 {
    let vn = self.get_value_number(node.values[i])
    if vn == node_vn {
      return true
    }
  }
  false
}

///|
/// Check if phi only has self-references and one other value
fn GVN::get_phi_single_non_self_value(self : GVN, node : Node) -> NodeId? {
  let node_vn = self.get_value_number(node.id)
  let mut non_self_value : NodeId? = None
  for i = 1; i < node.values.length(); i = i + 1 {
    let vn = self.get_value_number(node.values[i])
    if vn != node_vn {
      match non_self_value {
        None => non_self_value = Some(vn)
        Some(prev) if prev != vn => return None // Multiple different non-self values
        _ => ()
      }
    }
  }
  non_self_value
}

///|
/// Process a single node (first pass - optimistic)
pub fn GVN::process_node_optimistic(
  self : GVN,
  graph : Graph,
  node : Node,
) -> Unit {
  // Handle cycle detection
  if self.in_progress.contains(node.id) {
    // In a cycle, optimistically assume it equals itself for now
    return
  }
  self.in_progress.add(node.id)

  // Process operands first
  for v in node.values {
    if not(self.value_number.contains(v)) {
      match graph.node_store.get(v) {
        Some(operand_node) => self.process_node_optimistic(graph, operand_node)
        None => ()
      }
    }
  }
  self.in_progress.remove(node.id)

  // Handle phi nodes specially
  if node.is_phi() {
    // First check for trivial phi (all same inputs)
    match self.is_trivial_phi(node) {
      Some(single_value) => {
        self.set_value_number(node.id, single_value)
        return
      }
      None => ()
    }

    // Check for phi with only self-references and one other value
    // phi(x, phi, phi) = x
    match self.get_phi_single_non_self_value(node) {
      Some(single_value) => {
        self.set_value_number(node.id, single_value)
        return
      }
      None => ()
    }
  }

  // Try to find or create a key
  match self.make_key(graph, node) {
    Some(key) =>
      match self.expr_to_leader.get(key) {
        Some(leader) => self.set_value_number(node.id, leader)
        None => {
          self.expr_to_leader.set(key, node.id)
          self.set_value_number(node.id, node.id)
        }
      }
    None => self.set_value_number(node.id, node.id)
  }
}

///|
/// Re-process a node during fixed-point iteration
pub fn GVN::reprocess_node(self : GVN, graph : Graph, node : Node) -> Unit {
  // For phi nodes, check if the key changed
  if node.is_phi() {
    // Check trivial phi again with updated value numbers
    match self.is_trivial_phi(node) {
      Some(single_value) => {
        self.set_value_number(node.id, single_value)
        return
      }
      None => ()
    }
    match self.get_phi_single_non_self_value(node) {
      Some(single_value) => {
        self.set_value_number(node.id, single_value)
        return
      }
      None => ()
    }
  }
  match self.make_key(graph, node) {
    Some(key) =>
      match self.expr_to_leader.get(key) {
        Some(leader) => self.set_value_number(node.id, leader)
        None =>
          // Key might have changed, update mapping
          self.expr_to_leader.set(key, self.get_value_number(node.id))
      }
    None => ()
  }
}

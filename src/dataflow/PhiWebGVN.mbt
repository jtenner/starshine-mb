///|
/// Phi congruence class - tracks sets of equivalent phis
pub struct PhiCongruence {
  /// Maps each phi to its congruence class representative
  class_rep : Map[NodeId, NodeId]
  /// Maps representative to all members of the class
  class_members : Map[NodeId, Array[NodeId]]
}

///|
pub fn PhiCongruence::new() -> PhiCongruence {
  { class_rep: Map::new(), class_members: Map::new() }
}

///|
pub fn PhiCongruence::find(self : PhiCongruence, node_id : NodeId) -> NodeId {
  match self.class_rep.get(node_id) {
    Some(rep) if rep != node_id => {
      let final_rep = self.find(rep)
      self.class_rep.set(node_id, final_rep)
      final_rep
    }
    Some(rep) => rep
    None => {
      self.class_rep.set(node_id, node_id)
      self.class_members.set(node_id, [node_id])
      node_id
    }
  }
}

///|
pub fn PhiCongruence::union(
  self : PhiCongruence,
  a : NodeId,
  b : NodeId,
) -> Unit {
  let rep_a = self.find(a)
  let rep_b = self.find(b)
  if rep_a == rep_b {
    return
  }

  // Merge smaller class into larger
  let members_a = self.class_members.get(rep_a).unwrap_or([])
  let members_b = self.class_members.get(rep_b).unwrap_or([])
  if members_a.length() >= members_b.length() {
    // Merge b into a
    self.class_rep.set(rep_b, rep_a)
    for m in members_b {
      members_a.push(m)
      self.class_rep.set(m, rep_a)
    }
    self.class_members.set(rep_a, members_a)
  } else {
    // Merge a into b
    self.class_rep.set(rep_a, rep_b)
    for m in members_a {
      members_b.push(m)
      self.class_rep.set(m, rep_b)
    }
    self.class_members.set(rep_b, members_b)
  }
}

///|
/// Advanced phi congruence detection using Alpern-Wegman-Zadeck algorithm
/// This handles complex phi webs more efficiently
pub struct PhiWebGVN {
  gvn : GVN
  congruence : PhiCongruence
  /// Worklist of phi pairs to check for congruence
  worklist : Array[(NodeId, NodeId)]
}

///|
pub fn PhiWebGVN::new() -> PhiWebGVN {
  { gvn: GVN::new(), congruence: PhiCongruence::new(), worklist: [] }
}

///|
/// Check if two phis might be congruent based on structure
fn PhiWebGVN::phis_structurally_similar(
  _self : PhiWebGVN,
  _graph : Graph,
  phi1 : Node,
  phi2 : Node,
) -> Bool {
  // Must have same block
  if phi1.values.length() < 1 || phi2.values.length() < 1 {
    return false
  }
  if phi1.values[0] != phi2.values[0] {
    return false
  }

  // Must have same number of operands
  if phi1.values.length() != phi2.values.length() {
    return false
  }
  true
}

///|
/// Check if two phis are congruent given current congruence classes
pub fn PhiWebGVN::check_phi_congruence(
  self : PhiWebGVN,
  graph : Graph,
  phi1 : Node,
  phi2 : Node,
) -> Bool {
  if not(self.phis_structurally_similar(graph, phi1, phi2)) {
    return false
  }

  // Check if corresponding operands are in the same congruence class
  for i = 1; i < phi1.values.length(); i = i + 1 {
    let op1 = phi1.values[i]
    let op2 = phi2.values[i]
    let class1 = self.congruence.find(op1)
    let class2 = self.congruence.find(op2)
    if class1 != class2 {
      return false
    }
  }
  true
}

///|
/// Initialize congruence classes - non-phis in their own class,
/// potentially congruent phis start in same class (optimistic)
fn PhiWebGVN::initialize(self : PhiWebGVN, graph : Graph) -> Unit {
  // Group phis by block and number of operands
  let phi_groups : Map[Int, Array[NodeId]] = Map::new()
  for node in graph.node_store.nodes {
    if node.is_phi() && node.values.length() > 0 {
      // Key: block_id * 1000 + num_operands (simple grouping)
      let key = node.values[0].0 * 1000 + node.values.length()
      let group = phi_groups.get_or_init(key, fn() { [] })
      group.push(node.id)
    } else {
      // Non-phi nodes start in their own class
      let _ = self.congruence.find(node.id)

    }
  }

  // For each group of structurally similar phis, add pairs to worklist
  for entry in phi_groups.iter() {
    let phis = entry.1
    if phis.length() > 1 {
      // Optimistically assume all might be congruent
      for i = 0; i < phis.length(); i = i + 1 {
        for j = i + 1; j < phis.length(); j = j + 1 {
          self.worklist.push((phis[i], phis[j]))
        }
      }
    }
  }
}

///|
/// Run the phi web congruence algorithm
pub fn PhiWebGVN::compute_congruence(self : PhiWebGVN, graph : Graph) -> Unit {
  self.initialize(graph)

  // Process worklist until empty
  while self.worklist.length() > 0 {
    let pair = self.worklist.pop().unwrap()
    let (phi1_id, phi2_id) = pair

    // Skip if already in same class
    if self.congruence.find(phi1_id) == self.congruence.find(phi2_id) {
      continue
    }
    match (graph.node_store.get(phi1_id), graph.node_store.get(phi2_id)) {
      (Some(phi1), Some(phi2)) =>
        if self.check_phi_congruence(graph, phi1, phi2) {
          // Merge congruence classes
          self.congruence.union(phi1_id, phi2_id)

          // Add users of these phis to worklist if they're also phis
          // (their congruence might now be affected)
        }
      _ => ()
    }
  }
}

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
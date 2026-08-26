///|
/// A bounded, declarative description of one Preview 1 marshalling node.
pub(all) enum WasiMarshalNode {
  WasiI32
  WasiInputBytes(Int)
  WasiOutputBytes(Int)
  WasiPointer(Array[WasiMarshalNode])
  WasiList(WasiMarshalNode, Int)
} derive(Eq, Debug)

///|
pub(all) struct WasiPreview1Schema {
  module_name : String
  field : String
  parameters : Array[WasiMarshalNode]
  maximum_depth : Int
  maximum_nodes : Int
} derive(Eq, Debug)

///|
priv struct WasiScratchLayout {
  iovec_address : Int
  result_address : Int
  scratch_address : Int
  scratch_capacity : Int
}

///|
fn wasi_preview1_scratch_layout() -> WasiScratchLayout {
  {
    iovec_address: 0,
    result_address: 8,
    scratch_address: 16,
    scratch_capacity: 65520,
  }
}

///|
pub fn wasi_preview1_fd_write_schema() -> WasiPreview1Schema {
  {
    module_name: "wasi_snapshot_preview1",
    field: "fd_write",
    parameters: [
      WasiI32,
      WasiList(WasiPointer([WasiInputBytes(65520), WasiI32]), 1),
      WasiI32,
      WasiPointer([WasiI32]),
    ],
    maximum_depth: 4,
    maximum_nodes: 16,
  }
}

///|
pub fn wasi_preview1_fd_read_schema() -> WasiPreview1Schema {
  {
    module_name: "wasi_snapshot_preview1",
    field: "fd_read",
    parameters: [
      WasiI32,
      WasiList(WasiPointer([WasiOutputBytes(65520), WasiI32]), 1),
      WasiI32,
      WasiPointer([WasiI32]),
    ],
    maximum_depth: 4,
    maximum_nodes: 16,
  }
}

///|
pub fn validate_wasi_preview1_schema(
  schema : WasiPreview1Schema,
) -> Result[Unit, String] {
  if schema.maximum_depth < 1 || schema.maximum_depth > 16 {
    return Err("WASI marshalling depth must be in 1..16")
  }
  if schema.maximum_nodes < 1 || schema.maximum_nodes > 1024 {
    return Err("WASI marshalling node bound must be in 1..1024")
  }
  let nodes : Array[(WasiMarshalNode, Int)] = []
  for parameter in schema.parameters {
    nodes.push((parameter, 1))
  }
  let mut visited = 0
  while nodes.length() > 0 {
    let (node, depth) = nodes.pop().unwrap()
    visited += 1
    if visited > schema.maximum_nodes {
      return Err("WASI marshalling schema exceeds its node bound")
    }
    if depth > schema.maximum_depth {
      return Err("WASI marshalling schema exceeds its depth bound")
    }
    match node {
      WasiI32 => ()
      WasiInputBytes(limit) | WasiOutputBytes(limit) =>
        if limit < 0 || limit > wasi_preview1_scratch_layout().scratch_capacity {
          return Err("WASI byte range exceeds scratch capacity")
        }
      WasiPointer(fields) =>
        for field in fields {
          nodes.push((field, depth + 1))
        }
      WasiList(element, maximum_count) => {
        if maximum_count < 0 || maximum_count > 1024 {
          return Err("WASI list count is outside its bound")
        }
        nodes.push((element, depth + 1))
      }
    }
  }
  Ok(())
}

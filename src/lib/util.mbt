
///|
pub fn expand_locals(decls : Array[Locals]) -> Result[Array[ValType], String] {
  let out : Array[ValType] = []
  for d in decls {
    let Locals(n, vt) = d
    let count = n.reinterpret_as_int()
    if count < 0 {
      return Err("locals: negative count")
    }
    for _ in 0..<count {
      out.push(vt)
    }
  }
  Ok(out)
}

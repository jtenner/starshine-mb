///|
pub struct SquareMatrix[T] {
  storage : Map[UInt64, T]
  n : UInt
}

///|
pub fn[T] SquareMatrix::new(size? : UInt = 0) -> Self[T] {
  SquareMatrix::{
    storage: Map::new(capacity=(size * size).reinterpret_as_int()),
    n: size,
  }
}

///|
pub fn[T] SquareMatrix::get_or(
  self : SquareMatrix[T],
  or : T,
  x : UInt,
  y : UInt,
) -> Result[T, String] {
  let n = self.n
  if x >= n || y >= n {
    return Err("Index out of bounds")
  }
  let index = x.to_uint64() * n.to_uint64() + y.to_uint64()
  if self.storage.get(index) is Some(t) {
    Ok(t)
  } else {
    Ok(or)
  }
}

///|
pub fn[T : Default] SquareMatrix::get_or_default(
  self : SquareMatrix[T],
  x : UInt,
  y : UInt,
) -> Result[T, String] {
  SquareMatrix::get_or(self, T::default(), x, y)
}

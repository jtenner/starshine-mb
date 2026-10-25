///|
test "hot verify all rejects an invalid drop with a missing operand" {
  let func = HotFunc::new()
  let drop = hot_build_drop(func, HOT_NONE_NODE)
  hot_root_append(func, drop)
  // Builders permit staging sentinels; final verification must reject this
  // incomplete ordinary operand before lowering consumes it as a node ID.
  match hot_verify_all(func) {
    Err(_) => ()
    Ok(_) => fail("expected Err for Drop(HOT_NONE_NODE), got Ok")
  }
}

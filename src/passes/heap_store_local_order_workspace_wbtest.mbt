///|
test "heap-store local-order workspace resets only logical state" {
  let workspace = hso_new_local_order_workspace(10000)
  hso_local_order_workspace_begin(workspace)
  hso_local_order_workspace_note(workspace, 9999, 41)
  hso_local_order_workspace_note(workspace, 7, 12)
  hso_local_order_workspace_note(workspace, 7, 18)
  @debug.assert_eq(hso_local_order_workspace_get(workspace, 9999), 41)
  @debug.assert_eq(hso_local_order_workspace_get(workspace, 7), 18)
  @debug.assert_eq(hso_local_order_workspace_get(workspace, 8), -1)

  hso_local_order_workspace_begin(workspace)
  @debug.assert_eq(hso_local_order_workspace_get(workspace, 9999), -1)
  @debug.assert_eq(hso_local_order_workspace_get(workspace, 7), -1)
  hso_local_order_workspace_note(workspace, 8, 27)
  @debug.assert_eq(hso_local_order_workspace_get(workspace, 8), 27)
}

///|
test "bench heap-store local-order sparse generations" (it : @bench.T) {
  let workspace = hso_new_local_order_workspace(65536)
  it.bench(fn() {
    for generation = 0; generation < 512; generation = generation + 1 {
      hso_local_order_workspace_begin(workspace)
      hso_local_order_workspace_note(workspace, generation & 31, generation)
      it.keep(hso_local_order_workspace_get(workspace, generation & 31))
    }
  })
}

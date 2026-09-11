///|
test "expanded CFG keeps a source local live across a carried block" {
  let input = @wast.wast_to_binary_module(
    (
      #|(module
      #| (import "env" "inc" (func (param i32) (result i32)))
      #| (import "env" "id" (func (param i32) (result i32)))
      #| (func (result i32) (local i32 i32 i32 i32)
      #|  i32.const 10 local.set 0
      #|  block (result i32)
      #|   local.get 0 call 0 local.tee 1 drop
      #|   loop nop end
      #|   local.get 1 br 0
      #|  end
      #|  local.get 0 call 1 local.set 2
      #|  local.tee 3 local.get 2 i32.add))
    ),
  ).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(2U))
  let cfg = cfg_build(func, expand_operand_control=true)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let live = liveness_build(cfg, use_def)
  let mut write = -1
  for id = 0; id < hot_node_count(func); id = id + 1 {
    if hot_node_is_live(func, id) {
      let node = hot_node_get(func, id)
      if node.op is HotOp::LocalTee && node.imm0 == 1 {
        write = id
      }
    }
  }
  assert_true(write >= 0)
  let block = cfg_block_for_node(cfg, write).unwrap()
  assert_true(
    local_live_out(live, block, 0),
    msg="the later identity call must still read the original source local",
  )
}

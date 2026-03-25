///|
fn ir_test_join_lines(lines : Array[String]) -> String {
  let out = StringBuilder::new()
  for i = 0; i < lines.length(); i = i + 1 {
    if i > 0 {
      out.write_string("\n")
    }
    out.write_string(lines[i])
  }
  out.to_string()
}

///|
fn ir_test_fixture_wat() -> String {
  "(module (func (param i32) (local i32) local.get 0 if i32.const 7 local.set 1 else nop end local.get 1 drop))"
}

///|
test "ir test helpers produce deterministic cfg dom liveness and ssa dumps" {
  let fixture = ir_test_build_hot_from_wat(ir_test_fixture_wat())

  assert_eq(
    ir_test_dump_cfg(fixture.hot_func),
    ir_test_join_lines([
      "entry=0 exit=1 exceptional=-", "block=0 synthetic=true holder=-1 span=-1..-1 nodes=[] preds=[] succs=[fallthrough:2]",
      "block=1 synthetic=true holder=-1 span=-1..-1 nodes=[] preds=[fallthrough:3] succs=[]",
      "block=2 synthetic=false holder=-1 span=0..1 nodes=[1] preds=[fallthrough:0] succs=[fallthrough:4, fallthrough:5]",
      "block=3 synthetic=false holder=-1 span=1..2 nodes=[8] preds=[fallthrough:4, fallthrough:5] succs=[fallthrough:1]",
      "block=4 synthetic=false holder=4 span=0..1 nodes=[3] preds=[fallthrough:2] succs=[fallthrough:3]",
      "block=5 synthetic=false holder=6 span=0..1 nodes=[5] preds=[fallthrough:2] succs=[fallthrough:3]",
    ]),
  )
  assert_eq(
    ir_test_dump_dom(fixture.hot_func),
    ir_test_join_lines([
      "entry=0", "block=0 idom=None children=[2] frontier=[]", "block=1 idom=Some(3) children=[] frontier=[]",
      "block=2 idom=Some(0) children=[5, 4, 3] frontier=[]", "block=3 idom=Some(2) children=[1] frontier=[]",
      "block=4 idom=Some(2) children=[] frontier=[3]", "block=5 idom=Some(2) children=[] frontier=[3]",
    ]),
  )
  assert_eq(
    ir_test_dump_liveness(fixture.hot_func),
    ir_test_join_lines([
      "include_exceptional_edges=false", "block=0 in=[0, 1] out=[0, 1]", "block=1 in=[] out=[]",
      "block=2 in=[0, 1] out=[1]", "block=3 in=[1] out=[]", "block=4 in=[] out=[1]",
      "block=5 in=[1] out=[1]",
    ]),
  )
  assert_eq(
    ir_test_dump_ssa(fixture.hot_func),
    ir_test_join_lines([
      "entry_defs=[0, 1]", "value=0 origin=param(0) uses=[get(0)]", "value=1 origin=init(1) uses=[phi(0<-5)]",
      "value=2 origin=phi(0) uses=[get(7)]", "value=3 origin=set(3) uses=[phi(0<-4)]",
      "block=0 phis=[]", "block=1 phis=[]", "block=2 phis=[]", "block=3 phis=[0]",
      "phi=0 block=3 local=1 inputs=[4->3, 5->1]", "block=4 phis=[]", "block=5 phis=[]",
      "node=0 get=0", "node=3 def=3", "node=7 get=2",
    ]),
  )
}

///|
test "ir test helpers verify and lower a mutated hot fixture" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (result i32) nop i32.const 5))",
  )
  let removed = hot_region_remove(fixture.hot_func, HotRegionRef::root(), 0, 1)
  for node_id in removed {
    hot_delete_node(fixture.hot_func, node_id)
  }

  let lowered = ir_test_assert_verify_and_lower(fixture)
  let pretty = lowered.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("nop"))
  assert_true(pretty.contains("I32(5)"))
}

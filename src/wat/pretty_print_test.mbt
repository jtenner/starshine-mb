///|
using @lib {
  inspect_debug,
  inspect_pretty_print,
  type PrettyPrintContext,
  type TabsOrSpaces,
}

///|
test "wast module snapshots for show debug and pretty print" {
  let mod = match
    wat_to_module("(module (type (func (param i32) (result i32))))") {
    Ok(m) => m
    Err(e) => fail("unexpected parse error: \{e}")
  }

  inspect(mod, content="(module\n  (type (func (param i32) (result i32)))\n)\n")
  inspect_debug(
    mod,
    content="{\n  id: None,\n  fields: [TypeField({ id: None, func_type: { params: [I32], results: [I32] } })],\n}",
  )
  inspect_pretty_print(
    mod,
    content="(module\n  (type (func (param i32) (result i32)))\n)\n",
  )
}

///|
test "wast pretty print respects tabs and width" {
  let mod = match
    wat_to_module("(module $m (type $t0 (func (param i32) (result i32))))") {
    Ok(m) => m
    Err(e) => fail("unexpected parse error: \{e}")
  }

  let tabs = PrettyPrintContext::new(
    max_line_width=120U,
    tabs_or_spaces=TabsOrSpaces::tabs(),
    tab_width=1U,
  )
  inspect_pretty_print(
    mod,
    ctx=tabs,
    content="(module $m\n\t(type $t0 (func (param i32) (result i32)))\n)\n",
  )
}

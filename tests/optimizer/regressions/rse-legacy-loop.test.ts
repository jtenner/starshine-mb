import { stateRegression, type StateCase } from "./state-execution";
const cases: StateCase[] = [];
for (const [name, eh] of Object.entries({
  body: "try i32.const 1 local.set 0 catch_all end",
  catch: "try throw $e catch $e i32.const 1 local.set 0 end",
  catch_all: "try throw $e catch_all i32.const 1 local.set 0 end",
  backedge: "try i32.const 1 local.set 0 catch_all end local.get 1 i32.const 1 i32.add local.tee 1 i32.const 2 i32.lt_u br_if 0",
  delegate: "block try i32.const 1 local.set 0 delegate 0 end",
})) cases.push({name: `legacy EH ${name}`, pass: "redundant-set-elimination", expected: 0,
  wat: `(module (tag $e) (func (export "run") (result i32) (local i32 i32) (loop ${eh}) i32.const 0 local.set 0 local.get 0))`});

for (const c of cases) stateRegression(c);

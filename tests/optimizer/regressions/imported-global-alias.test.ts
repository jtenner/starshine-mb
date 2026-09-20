import { stateRegression, type StateCase } from "./state-execution";
const cases: StateCase[] = [];
const variants = ["simplify-locals", "simplify-locals-notee", "simplify-locals-no-tee", "simplify-locals-nonesting", "simplify-locals-no-nesting", "simplify-locals-nostructure", "simplify-locals-no-structure", "simplify-locals-notee-nostructure"];
for (const pass of variants) for (const storage of ["aliased", "distinct", "defined", "mixed"]) {
  const a = storage === "defined" ? `(global (mut i32) (i32.const 1))` : `(import "m" "a" (global (mut i32)))`;
  const b = storage === "defined" || storage === "mixed" ? `(global (mut i32) (i32.const 1))` : `(import "m" "b" (global (mut i32)))`;
  cases.push({name: `global storage ${storage}`, pass, expected: 1, alias: storage === "aliased",
    wat: `(module ${a} ${b} (func (export "run") (result i32) (local i32) global.get 0 local.set 0 i32.const 7 global.set 1 local.get 0))`});
}
for (const pass of ["heap-store-optimization", "optimize-instructions"]) cases.push({
  name: "imported global alias during value motion", pass, expected: pass === "heap-store-optimization" ? 1 : 0, alias: true,
  wat: pass === "heap-store-optimization"
    ? `(module (type $s (struct (field (mut i32)) (field (mut i32))))
       (import "m" "a" (global (mut i32))) (import "m" "b" (global (mut i32)))
       (func (export "run") (result i32) (local (ref null $s))
         global.get 0 i32.const 2 struct.new $s local.set 0
         i32.const 7 global.set 1
         local.get 0 i32.const 9 struct.set $s 1
         local.get 0 struct.get $s 0))`
    : `(module (import "m" "a" (global (mut i32))) (import "m" "b" (global (mut i32)))
       (func (export "run") (result i32)
         (i32.eq (block (result i32) (global.get 0) (global.set 1 (i32.const 7))) (global.get 0))))`,
});

for (const c of cases) stateRegression(c);

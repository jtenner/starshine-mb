import { stateRegression, type StateCase } from "./state-execution";
const cases: StateCase[] = [];
for (const nested of [false, true]) for (const transitive of [false, true]) {
  const expr = `global.get 0 i32.const 10 i32.add ${transitive ? "i32.const 2 i32.mul" : ""}`;
  const tail = `i32.const 5 global.set 0 ${expr}`;
  cases.push({name: `global CSE nested=${nested} transitive=${transitive}`, pass: "local-cse", expected: transitive ? 30 : 15,
    wat: `(module (global (mut i32) (i32.const 1)) (func (export "run") (result i32) ${expr} drop ${nested ? `(block (result i32) ${tail})` : tail}))`});
}

for (const c of cases) stateRegression(c);

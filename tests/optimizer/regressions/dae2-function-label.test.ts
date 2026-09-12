import { regression } from "./execution";
for (const fixture of ["br-void", "br-value", "br-if-taken", "br-if-fallthrough", "table-entry", "table-default", "table-ordinary"]) {
  regression(`dae2-function-${fixture}`, ["dae2", "dae2-optimizing"], fixture === "br-void" ? {} : {result: 42});
}

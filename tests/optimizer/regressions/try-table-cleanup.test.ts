import { regression } from "./execution";
for (const form of ["catch", "catch_ref", "catch_all", "catch_all_ref"]) {
  for (const depth of ["immediate", "outer"]) {
    regression(`try-table-${form}-${depth}`, ["once-reduction", "duplicate-function-elimination", "global-struct-inference"], {trap: "unreachable"});
  }
}

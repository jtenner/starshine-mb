import { regression } from "./execution";
regression("ssa-enclosing-exit", ["ssa-nomerge"], {result: 3});
regression("ssa-simple-enclosing-exit", ["ssa-nomerge"], {result: 7});

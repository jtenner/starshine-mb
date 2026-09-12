import { regression } from "./execution";
regression("ssa-else-read", ["ssa-nomerge"], {result: 0});
regression("ssa-branch-aliases", ["ssa-nomerge"], {result: 0});

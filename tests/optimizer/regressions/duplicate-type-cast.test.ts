import { regression } from "./execution";

regression("duplicate-type-cast", ["optimize-instructions"], {result: 7});
regression("distinct-group-ref-test", ["optimize-instructions"], {result: 0});

import { regression } from "./execution";
regression("heap-nested-struct", ["heap2local"], {result: 21});
regression("heap-nested-array", ["heap2local"], {result: 21});

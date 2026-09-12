import { regression } from "./execution";
regression("precompute-signed-zero-join", ["precompute-propagate"], {result: -2147483648});
regression("precompute-f64-zero-join", ["precompute-propagate"], {result: 10});
regression("precompute-zero-loop", ["precompute-propagate"], {result: 1});

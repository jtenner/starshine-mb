import { regression } from "./execution";
regression("simplify-carried-tail", ["simplify-locals"], {result: 7});
regression("simplify-carried-one-arm", ["simplify-locals"], {result: 79});
regression("simplify-carried-local", ["simplify-locals"], {result: 79});

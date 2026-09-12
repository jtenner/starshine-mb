import { regression } from "./execution";
regression("vacuum-carried-result", ["vacuum"], {result: 7});
regression("simplify-carried-tail", ["simplify-locals"], {result: 7}, ["vacuum"]);
regression("carried-tuple-result", ["vacuum"], {result: 73});

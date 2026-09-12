import { regression } from "./execution";
regression("simplify-nan-termination", ["simplify-locals"], {result: 0});
regression("simplify-f32-nan-termination", ["simplify-locals"], {result: 0});

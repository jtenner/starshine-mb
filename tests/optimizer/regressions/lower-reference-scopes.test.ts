import { regression } from "./execution";

regression("coalesce-unreachable-reference-init", ["coalesce-locals", "coalesce-locals-cfg"], {trap: "unreachable"});

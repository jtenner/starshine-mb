import crypto from "node:crypto";

export type MetamorphicInterfaceRelation = "exact-interface" | "encoding-only" | "additive-unobserved-interface" | "export-alias-extension" | "validation-only";
export type MetamorphicObservationProjection = { exports: "exact" | "base"; baseExportNames?: string[]; imports: "exact" | "base-plus-unused"; ignoredImports?: string[] };
export type OptimizerMetamorphicRelation = { schema: "starshine.optimizer-metamorphic-relation.v1"; transformId: string; relationKind: "equivalent" | "validation"; interfaceRelation: MetamorphicInterfaceRelation; observationProjection: MetamorphicObservationProjection; proof: "construction" | "experimental"; safeForOriginalTwinExecution: boolean; reapplicableDuringReduction: boolean };

export function metamorphicRelationGroupId(seed: string, profile: string, transformId: string, generatorVersion: string): string {
  const text = JSON.stringify({ seed, profile, transformId, generatorVersion });
  return `metamorphic:${crypto.createHash("sha256").update(text).digest("hex")}`;
}

export function buildMetamorphicPair<Module>(options: { seed: string; profile: string; generatorVersion: string; baseHash: string; base: Module; transformed: Module; relation: OptimizerMetamorphicRelation }) {
  const groupId = metamorphicRelationGroupId(options.seed, options.profile, options.relation.transformId, options.generatorVersion);
  return { schema: "starshine.optimizer-metamorphic-pair.v1" as const, groupId, seed: options.seed, profile: options.profile, baseHash: options.baseHash, relation: options.relation, variants: [{ role: "base" as const, module: options.base }, { role: "transformed" as const, module: options.transformed }] };
}

export function semanticPairingAllowed(relation: Pick<OptimizerMetamorphicRelation, "safeForOriginalTwinExecution" | "interfaceRelation">): boolean {
  return relation.safeForOriginalTwinExecution && relation.interfaceRelation !== "validation-only";
}

export function projectMetamorphicObservation(observation: { exports: Record<string, unknown>; imports: Array<{ module: string; field: string }> }, projection: MetamorphicObservationProjection) {
  const exports = projection.exports === "exact" ? observation.exports : Object.fromEntries((projection.baseExportNames ?? []).filter((name) => name in observation.exports).map((name) => [name, observation.exports[name]]));
  const ignored = new Set(projection.ignoredImports ?? []);
  const imports = projection.imports === "exact" ? observation.imports : observation.imports.filter((entry) => !ignored.has(`${entry.module}.${entry.field}`));
  return { exports, imports };
}

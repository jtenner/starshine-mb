import { describe, expect, test } from "bun:test";
import { buildMetamorphicPair, metamorphicRelationGroupId, projectMetamorphicObservation, semanticPairingAllowed } from "./optimizer-metamorphic";

describe("metamorphic relations", () => {
  test("uses deterministic relation-group IDs and emits base plus twin", () => {
    const relation = { schema: "starshine.optimizer-metamorphic-relation.v1" as const, transformId: "add-unused-import", relationKind: "equivalent" as const, interfaceRelation: "additive-unobserved-interface" as const, observationProjection: { exports: "base", imports: "base-plus-unused" as const }, proof: "construction" as const, safeForOriginalTwinExecution: true, reapplicableDuringReduction: true };
    const a = buildMetamorphicPair({ seed: "0x5eed", profile: "p", generatorVersion: "v1", baseHash: "h", base: "A", transformed: "B", relation });
    const b = buildMetamorphicPair({ seed: "0x5eed", profile: "p", generatorVersion: "v1", baseHash: "h", base: "A", transformed: "B", relation });
    expect(a).toEqual(b);
    expect(a.variants.map((v) => v.role)).toEqual(["base", "transformed"]);
    expect(a.groupId).toBe(metamorphicRelationGroupId("0x5eed", "p", "add-unused-import", "v1"));
  });

  test("projects exact, additive import, and export-alias interfaces", () => {
    const observation = { exports: { run: 1, alias: 1 }, imports: [{ module: "m", field: "used" }, { module: "m", field: "unused" }] };
    expect(projectMetamorphicObservation(observation, { exports: "exact", imports: "exact" })).toEqual(observation);
    expect(projectMetamorphicObservation(observation, { exports: "base", baseExportNames: ["run"], imports: "base-plus-unused", ignoredImports: ["m.unused"] })).toEqual({ exports: { run: 1 }, imports: [{ module: "m", field: "used" }] });
    expect(projectMetamorphicObservation(observation, { exports: "base", baseExportNames: ["run"], imports: "exact" })).toEqual({ exports: { run: 1 }, imports: observation.imports });
  });

  test("excludes validation-only transforms from semantic pairing", () => {
    expect(semanticPairingAllowed({ safeForOriginalTwinExecution: false, interfaceRelation: "validation-only" })).toBe(false);
  });
});

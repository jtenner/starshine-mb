export type SemanticRelation = "equal" | "different" | "blocked";

export type PropertyHarness<Module> = {
  apply(module: Module, passes: string[]): Promise<Module>;
  validate(module: Module): Promise<boolean>;
  semanticCompare(original: Module, candidate: Module): Promise<SemanticRelation>;
  structuralHash(module: Module): Promise<string>;
  encodedSize(module: Module): Promise<number>;
  persist(name: string, module: Module): Promise<unknown>;
};

export type PropertyArtifact = { name: string; artifact: unknown };

export type OptimizerPropertyResult = {
  schema: "starshine.optimizer-property-result.v1";
  propertyKind: string;
  passFlags: string[];
  status: "pass" | "fail" | "blocked" | "generator-failure";
  classification: string;
  generatedArtifacts: PropertyArtifact[];
  validationResults: Array<{ generation?: number; artifact: string; valid: boolean }>;
  semanticComparisons: Array<{ left: string; right: string; relation: SemanticRelation }>;
  structuralDiagnostics: unknown;
  firstFailure: { generation?: number; stage: string; detail: string } | null;
  replayData: Record<string, unknown>;
  reducerData: Record<string, unknown>;
};

function baseResult(kind: string, passes: string[]): OptimizerPropertyResult {
  return {
    schema: "starshine.optimizer-property-result.v1",
    propertyKind: kind,
    passFlags: passes,
    status: "pass",
    classification: "pass",
    generatedArtifacts: [],
    validationResults: [],
    semanticComparisons: [],
    structuralDiagnostics: null,
    firstFailure: null,
    replayData: { property: kind, passes },
    reducerData: { independentlyReducible: true },
  };
}

async function persist<Module>(result: OptimizerPropertyResult, harness: PropertyHarness<Module>, name: string, module: Module): Promise<void> {
  result.generatedArtifacts.push({ name, artifact: await harness.persist(name, module) });
}

export async function runSemanticIdempotenceProperty<Module>(
  input: Module,
  passes: string[],
  harness: PropertyHarness<Module>,
): Promise<OptimizerPropertyResult & { classification: "structural-fixed-point" | "semantic-equality-with-structural-drift" | "first-application-semantic-mismatch" | "second-application-semantic-mismatch" | "second-application-validation-failure" | "blocked" }> {
  const result = baseResult("semantic-idempotence", passes) as ReturnType<typeof baseResult> & { classification: any };
  await persist(result, harness, "M0", input);
  const first = await harness.apply(input, passes);
  await persist(result, harness, "M1", first);
  const firstValid = await harness.validate(first);
  result.validationResults.push({ generation: 1, artifact: "M1", valid: firstValid });
  if (!firstValid) {
    result.status = "fail";
    result.classification = "first-application-semantic-mismatch";
    result.firstFailure = { generation: 1, stage: "validation", detail: "first optimizer output is invalid" };
    return result;
  }
  const second = await harness.apply(first, passes);
  await persist(result, harness, "M2", second);
  const secondValid = await harness.validate(second);
  result.validationResults.push({ generation: 2, artifact: "M2", valid: secondValid });
  if (!secondValid) {
    result.status = "fail";
    result.classification = "second-application-validation-failure";
    result.firstFailure = { generation: 2, stage: "validation", detail: "second optimizer output is invalid" };
    return result;
  }
  const comparisons: Array<[string, string, Module, Module]> = [
    ["M0", "M1", input, first],
    ["M0", "M2", input, second],
    ["M1", "M2", first, second],
  ];
  for (const [leftName, rightName, left, right] of comparisons) {
    const relation = await harness.semanticCompare(left, right);
    result.semanticComparisons.push({ left: leftName, right: rightName, relation });
    if (relation === "blocked") {
      result.status = "blocked";
      result.classification = "blocked";
      result.firstFailure = { stage: "semantic-comparison", detail: `${leftName} versus ${rightName} blocked` };
      return result;
    }
    if (relation === "different") {
      result.status = "fail";
      result.classification = leftName === "M0" && rightName === "M1"
        ? "first-application-semantic-mismatch"
        : "second-application-semantic-mismatch";
      result.firstFailure = { generation: 2, stage: "semantic-comparison", detail: `${leftName} differs from ${rightName}` };
      return result;
    }
  }
  const firstHash = await harness.structuralHash(first);
  const secondHash = await harness.structuralHash(second);
  result.structuralDiagnostics = { firstHash, secondHash };
  result.classification = firstHash === secondHash ? "structural-fixed-point" : "semantic-equality-with-structural-drift";
  return result;
}

export type ConvergenceGeneration = {
  generation: number;
  hash: string;
  size: number;
  valid: boolean;
  semantic: SemanticRelation;
};

export type ConvergencePropertyResult = OptimizerPropertyResult & {
  classification: "fixed-point" | "structural-cycle" | "persistent-growth" | "nonconvergence" | "late-validation-failure" | "late-semantic-divergence" | "blocked";
  generations: ConvergenceGeneration[];
  fixedPointGeneration: number | null;
  cycle: { startGeneration: number; endGeneration: number; hashes: string[] } | null;
};

export async function runConvergenceProperty<Module>(
  input: Module,
  passes: string[],
  harness: PropertyHarness<Module>,
  options: { maxGenerations?: number } = {},
): Promise<ConvergencePropertyResult> {
  const maxGenerations = Math.max(1, options.maxGenerations ?? 8);
  const result = Object.assign(baseResult("convergence", passes), {
    classification: "nonconvergence" as ConvergencePropertyResult["classification"],
    generations: [] as ConvergenceGeneration[],
    fixedPointGeneration: null as number | null,
    cycle: null as ConvergencePropertyResult["cycle"],
  });
  let current = input;
  const modules: Module[] = [input];
  const seen = new Map<string, number>();
  const initialHash = await harness.structuralHash(input);
  const initialSize = await harness.encodedSize(input);
  result.generations.push({ generation: 0, hash: initialHash, size: initialSize, valid: true, semantic: "equal" });
  seen.set(initialHash, 0);
  await persist(result, harness, "M0", input);
  for (let generation = 1; generation <= maxGenerations; generation += 1) {
    current = await harness.apply(current, passes);
    modules.push(current);
    await persist(result, harness, `M${generation}`, current);
    const valid = await harness.validate(current);
    result.validationResults.push({ generation, artifact: `M${generation}`, valid });
    const hash = await harness.structuralHash(current);
    const size = await harness.encodedSize(current);
    if (!valid) {
      result.generations.push({ generation, hash, size, valid: false, semantic: "blocked" });
      result.status = "fail";
      result.classification = "late-validation-failure";
      result.firstFailure = { generation, stage: "validation", detail: "optimizer generation is invalid" };
      return result;
    }
    const semantic = await harness.semanticCompare(input, current);
    result.semanticComparisons.push({ left: "M0", right: `M${generation}`, relation: semantic });
    result.generations.push({ generation, hash, size, valid: true, semantic });
    if (semantic === "blocked") {
      result.status = "blocked";
      result.classification = "blocked";
      result.firstFailure = { generation, stage: "semantic-comparison", detail: "generation comparison blocked" };
      return result;
    }
    if (semantic === "different") {
      result.status = "fail";
      result.classification = "late-semantic-divergence";
      result.firstFailure = { generation, stage: "semantic-comparison", detail: "generation differs from original" };
      return result;
    }
    const previousHash = result.generations[generation - 1].hash;
    if (hash === previousHash) {
      result.status = "pass";
      result.classification = "fixed-point";
      result.fixedPointGeneration = generation;
      result.structuralDiagnostics = { fixedPointHash: hash };
      return result;
    }
    const earlier = seen.get(hash);
    if (earlier !== undefined) {
      result.status = "fail";
      result.classification = "structural-cycle";
      result.cycle = {
        startGeneration: earlier,
        endGeneration: generation,
        hashes: result.generations.slice(earlier, generation + 1).map((entry) => entry.hash),
      };
      result.firstFailure = { generation, stage: "convergence", detail: `canonical structure returned to generation ${earlier}` };
      return result;
    }
    seen.set(hash, generation);
  }
  result.status = "fail";
  const sizes = result.generations.map((entry) => entry.size);
  const persistentGrowth = sizes.every((size, index) => index === 0 || size > sizes[index - 1]);
  result.classification = persistentGrowth ? "persistent-growth" : "nonconvergence";
  result.firstFailure = { generation: maxGenerations, stage: "convergence", detail: `no fixed point by generation ${maxGenerations}` };
  result.structuralDiagnostics = { sizes, hashes: result.generations.map((entry) => entry.hash) };
  return result;
}

export async function runCommutatorProperty<Module>(
  input: Module,
  leftPass: string,
  rightPass: string,
  harness: PropertyHarness<Module>,
): Promise<OptimizerPropertyResult & { classification: string }> {
  const result = baseResult("commutator", [leftPass, rightPass]);
  const left = await harness.apply(input, [leftPass]);
  const right = await harness.apply(input, [rightPass]);
  const leftThenRight = await harness.apply(right, [leftPass]);
  const rightThenLeft = await harness.apply(left, [rightPass]);
  const artifacts: Array<[string, Module]> = [["M", input], ["MP", left], ["MQ", right], ["P(Q(M))", leftThenRight], ["Q(P(M))", rightThenLeft]];
  for (const [name, module] of artifacts) {
    await persist(result, harness, name, module);
    if (name !== "M") result.validationResults.push({ artifact: name, valid: await harness.validate(module) });
  }
  if (result.validationResults.some((entry) => !entry.valid)) {
    result.status = "fail";
    result.classification = "validation-failure";
    result.firstFailure = { stage: "validation", detail: "commutator candidate is invalid" };
    return result;
  }
  const leftRelation = await harness.semanticCompare(input, left);
  const rightRelation = await harness.semanticCompare(input, right);
  const leftOrderRelation = await harness.semanticCompare(input, leftThenRight);
  const rightOrderRelation = await harness.semanticCompare(input, rightThenLeft);
  const orderRelation = await harness.semanticCompare(leftThenRight, rightThenLeft);
  result.semanticComparisons.push(
    { left: "M", right: "MP", relation: leftRelation },
    { left: "M", right: "MQ", relation: rightRelation },
    { left: "M", right: "P(Q(M))", relation: leftOrderRelation },
    { left: "M", right: "Q(P(M))", relation: rightOrderRelation },
    { left: "P(Q(M))", right: "Q(P(M))", relation: orderRelation },
  );
  if ([leftRelation, rightRelation, leftOrderRelation, rightOrderRelation, orderRelation].includes("blocked")) {
    result.status = "blocked";
    result.classification = "blocked";
  } else if (leftRelation === "different") {
    result.status = "fail";
    result.classification = "left-pass-fails-alone";
  } else if (rightRelation === "different") {
    result.status = "fail";
    result.classification = "right-pass-fails-alone";
  } else if (leftOrderRelation === "different" && rightOrderRelation === "equal") {
    result.status = "fail";
    result.classification = "only-left-then-right-fails";
  } else if (rightOrderRelation === "different" && leftOrderRelation === "equal") {
    result.status = "fail";
    result.classification = "only-right-then-left-fails";
  } else if (leftOrderRelation === "different" && rightOrderRelation === "different") {
    result.status = "fail";
    result.classification = orderRelation === "equal" ? "both-orders-same-semantic-failure" : "both-orders-fail-differently";
  } else {
    const leftHash = await harness.structuralHash(leftThenRight);
    const rightHash = await harness.structuralHash(rightThenLeft);
    result.classification = leftHash === rightHash ? "semantic-orders-structurally-equal" : "semantic-orders-structurally-different";
    result.structuralDiagnostics = { leftHash, rightHash };
  }
  if (result.status === "fail") result.firstFailure = { stage: "semantic-comparison", detail: result.classification };
  return result;
}

export async function runMetamorphicEquivalenceProperty<Module>(
  base: Module,
  twin: Module,
  passes: string[],
  harness: PropertyHarness<Module>,
  options: { relationId: string; compareRelation(left: Module, right: Module): Promise<SemanticRelation> },
): Promise<OptimizerPropertyResult & { classification: string }> {
  const result = baseResult("metamorphic-equivalence", passes);
  result.replayData.relationId = options.relationId;
  const baseValid = await harness.validate(base);
  const twinValid = await harness.validate(twin);
  result.validationResults.push({ artifact: "base", valid: baseValid }, { artifact: "twin", valid: twinValid });
  if (!baseValid || !twinValid) {
    result.status = "generator-failure";
    result.classification = "input-validation-failure";
    return result;
  }
  const inputRelation = await options.compareRelation(base, twin);
  result.semanticComparisons.push({ left: "base", right: "twin", relation: inputRelation });
  if (inputRelation !== "equal") {
    result.status = inputRelation === "blocked" ? "blocked" : "generator-failure";
    result.classification = inputRelation === "blocked" ? "input-relation-blocked" : "input-relation-contract-failure";
    return result;
  }
  const optimizedBase = await harness.apply(base, passes);
  const optimizedTwin = await harness.apply(twin, passes);
  await persist(result, harness, "base", base);
  await persist(result, harness, "twin", twin);
  await persist(result, harness, "optimized-base", optimizedBase);
  await persist(result, harness, "optimized-twin", optimizedTwin);
  const baseRelation = await harness.semanticCompare(base, optimizedBase);
  const twinRelation = await harness.semanticCompare(twin, optimizedTwin);
  result.semanticComparisons.push(
    { left: "base", right: "optimized-base", relation: baseRelation },
    { left: "twin", right: "optimized-twin", relation: twinRelation },
  );
  if (baseRelation !== "equal") {
    result.status = baseRelation === "blocked" ? "blocked" : "fail";
    result.classification = baseRelation === "blocked" ? "base-optimization-blocked" : "base-optimization-failure";
    return result;
  }
  if (twinRelation !== "equal") {
    result.status = twinRelation === "blocked" ? "blocked" : "fail";
    result.classification = twinRelation === "blocked" ? "twin-optimization-blocked" : "twin-optimization-failure";
    return result;
  }
  const optimizedRelation = await options.compareRelation(optimizedBase, optimizedTwin);
  result.semanticComparisons.push({ left: "optimized-base", right: "optimized-twin", relation: optimizedRelation });
  if (optimizedRelation !== "equal") {
    result.status = optimizedRelation === "blocked" ? "blocked" : "fail";
    result.classification = optimizedRelation === "blocked" ? "optimized-relation-blocked" : "optimized-twins-diverge";
    return result;
  }
  result.classification = "metamorphic-equivalence";
  return result;
}

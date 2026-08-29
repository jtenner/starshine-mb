export type LocalizationSemanticRelation = "equal" | "different" | "blocked";

export type LocalizationRunner<Module> = {
  runPrefix(prefixLength: number): Promise<Module>;
  validate(module: Module): Promise<boolean>;
  semanticCompare(original: Module, module: Module): Promise<LocalizationSemanticRelation>;
  hash(module: Module): Promise<string>;
  size(module: Module): Promise<number>;
  runStandalone(predecessor: Module, pass: string, context: { boundaryIndex: number }): Promise<Module>;
  semanticCompareStandalone(original: Module, standalone: Module): Promise<LocalizationSemanticRelation>;
  persist(name: string, module: Module): Promise<unknown>;
  isIndivisibleComposite?(boundaryIndex: number): boolean;
};

export type PrefixLocalizationEntry = {
  prefixLength: number;
  pass: string | null;
  hash: string;
  byteSize: number;
  valid: boolean;
  semantic: LocalizationSemanticRelation;
  artifact: unknown | null;
};

export type PassLocalizationReport = {
  schema: "starshine.optimizer-pass-localization.v1";
  passSequenceSource: "requested-flags" | "moon-expanded-queue";
  classification:
    | "no-divergence"
    | "decode-encode-baseline-divergence"
    | "first-divergent-top-level-pass-boundary"
    | "candidate-invalid-before-boundary"
    | "internal-composite-boundary-not-divisible"
    | "blocked";
  passSequence: string[];
  prefixes: PrefixLocalizationEntry[];
  firstDivergentBoundary: { index: number; pass: string } | null;
  laterRecoveries: number[];
  standaloneReproduction: "not-run" | "reproduced" | "context-dependent" | "blocked";
  predecessorArtifact: unknown | null;
  boundaryArtifact: unknown | null;
  standaloneArtifact: unknown | null;
};

export async function localizeFirstSemanticDivergence<Module>(
  original: Module,
  passSequence: string[],
  runner: LocalizationRunner<Module>,
  passSequenceSource: PassLocalizationReport["passSequenceSource"] = "requested-flags",
): Promise<PassLocalizationReport> {
  const report: PassLocalizationReport = {
    schema: "starshine.optimizer-pass-localization.v1",
    passSequenceSource,
    classification: "no-divergence",
    passSequence: passSequence.slice(),
    prefixes: [],
    firstDivergentBoundary: null,
    laterRecoveries: [],
    standaloneReproduction: "not-run",
    predecessorArtifact: null,
    boundaryArtifact: null,
    standaloneArtifact: null,
  };
  const modules: Module[] = [];
  let sawDivergence = false;
  for (let prefixLength = 0; prefixLength <= passSequence.length; prefixLength += 1) {
    const module = await runner.runPrefix(prefixLength);
    modules.push(module);
    const valid = await runner.validate(module);
    const hash = await runner.hash(module);
    const byteSize = await runner.size(module);
    let semantic: LocalizationSemanticRelation = "blocked";
    if (valid) semantic = await runner.semanticCompare(original, module);
    const artifact = !valid || semantic !== "equal" ? await runner.persist(`prefix-${prefixLength}`, module) : null;
    report.prefixes.push({
      prefixLength,
      pass: prefixLength === 0 ? null : passSequence[prefixLength - 1],
      hash,
      byteSize,
      valid,
      semantic,
      artifact,
    });
    if (prefixLength === 0 && semantic === "different") {
      report.classification = "decode-encode-baseline-divergence";
      sawDivergence = true;
      continue;
    }
    if (!valid && report.firstDivergentBoundary === null) {
      report.classification = "candidate-invalid-before-boundary";
      return report;
    }
    if (semantic === "blocked" && valid && report.firstDivergentBoundary === null) {
      report.classification = "blocked";
      return report;
    }
    if (semantic === "different") {
      sawDivergence = true;
      if (report.firstDivergentBoundary === null && prefixLength > 0) {
        report.firstDivergentBoundary = { index: prefixLength, pass: passSequence[prefixLength - 1] };
        report.classification = runner.isIndivisibleComposite?.(prefixLength)
          ? "internal-composite-boundary-not-divisible"
          : "first-divergent-top-level-pass-boundary";
      }
    } else if (semantic === "equal" && sawDivergence && prefixLength > 0) {
      report.laterRecoveries.push(prefixLength);
    }
  }
  if (report.classification === "decode-encode-baseline-divergence" || report.firstDivergentBoundary === null) return report;
  const boundaryIndex = report.firstDivergentBoundary.index;
  const predecessor = modules[boundaryIndex - 1];
  const boundary = modules[boundaryIndex];
  const predecessorValid = await runner.validate(predecessor);
  if (!predecessorValid) {
    report.classification = "candidate-invalid-before-boundary";
    return report;
  }
  report.predecessorArtifact = await runner.persist("predecessor", predecessor);
  report.boundaryArtifact = await runner.persist("boundary-output", boundary);
  const standalone = await runner.runStandalone(predecessor, report.firstDivergentBoundary.pass, { boundaryIndex });
  report.standaloneArtifact = await runner.persist("standalone-output", standalone);
  const standaloneValid = await runner.validate(standalone);
  if (!standaloneValid) {
    report.standaloneReproduction = "blocked";
    return report;
  }
  const relation = await runner.semanticCompareStandalone(original, standalone);
  report.standaloneReproduction = relation === "different"
    ? "reproduced"
    : relation === "equal"
      ? "context-dependent"
      : "blocked";
  return report;
}

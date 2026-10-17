import type { OpaqueHandle, StarshineResult } from "../shared.js";
import type { EncodeError as binary_EncodeError } from "../../binary.js";
import type { ValType as lib_ValType } from "../../lib.js";

export type BinaryCanonicalityClassification = OpaqueHandle<"cmd.BinaryCanonicalityClassification">;
export type BinaryCanonicalityInputClass = OpaqueHandle<"cmd.BinaryCanonicalityInputClass">;
export type BinaryCanonicalitySummary = OpaqueHandle<"cmd.BinaryCanonicalitySummary">;
export type BinaryDifferentialAdapterResult = OpaqueHandle<"cmd.BinaryDifferentialAdapterResult">;
export type BinaryDifferentialClassification = OpaqueHandle<"cmd.BinaryDifferentialClassification">;
export type BinaryDifferentialSmokeAdapter = OpaqueHandle<"cmd.BinaryDifferentialSmokeAdapter">;
export type BinaryDifferentialSmokeReport = OpaqueHandle<"cmd.BinaryDifferentialSmokeReport">;
export type BinaryValidationOutcome = OpaqueHandle<"cmd.BinaryValidationOutcome">;
export type CmdEncodeError = OpaqueHandle<"cmd.CmdEncodeError">;
export type CmdError = OpaqueHandle<"cmd.CmdError">;
export type CmdFuzzHarnessProfileConfig = OpaqueHandle<"cmd.CmdFuzzHarnessProfileConfig">;
export type CmdFuzzStats = OpaqueHandle<"cmd.CmdFuzzStats">;
export type CmdIO = OpaqueHandle<"cmd.CmdIO">;
export type CmdOptimizerReportMode = OpaqueHandle<"cmd.CmdOptimizerReportMode">;
export type CmdPipelineDumpFormat = OpaqueHandle<"cmd.CmdPipelineDumpFormat">;
export type CmdPipelinePrintSelector = OpaqueHandle<"cmd.CmdPipelinePrintSelector">;
export type CmdPipelineStep = OpaqueHandle<"cmd.CmdPipelineStep">;
export type CmdRunSummary = OpaqueHandle<"cmd.CmdRunSummary">;
export type DifferentialAdapters = OpaqueHandle<"cmd.DifferentialAdapters">;
export type DifferentialValidationReport = OpaqueHandle<"cmd.DifferentialValidationReport">;
export type ExportInvocationClassification = OpaqueHandle<"cmd.ExportInvocationClassification">;
export type ExportInvocationComparisonReport = OpaqueHandle<"cmd.ExportInvocationComparisonReport">;
export type ExportInvocationFailurePolicy = OpaqueHandle<"cmd.ExportInvocationFailurePolicy">;
export type ExportInvocationMatrixOutcome = OpaqueHandle<"cmd.ExportInvocationMatrixOutcome">;
export type ExportInvocationMatrixSummary = OpaqueHandle<"cmd.ExportInvocationMatrixSummary">;
export type ExportInvocationResult = OpaqueHandle<"cmd.ExportInvocationResult">;
export type FuzzCorpusDedupDecision = OpaqueHandle<"cmd.FuzzCorpusDedupDecision">;
export type FuzzCorpusDedupHashEntry = OpaqueHandle<"cmd.FuzzCorpusDedupHashEntry">;
export type FuzzCorpusDedupIndex = OpaqueHandle<"cmd.FuzzCorpusDedupIndex">;
export type FuzzCorpusDedupSourceEntry = OpaqueHandle<"cmd.FuzzCorpusDedupSourceEntry">;
export type FuzzCorpusSource = OpaqueHandle<"cmd.FuzzCorpusSource">;
export type FuzzFailurePersistIO = OpaqueHandle<"cmd.FuzzFailurePersistIO">;
export type FuzzFailureReport = OpaqueHandle<"cmd.FuzzFailureReport">;
export type FuzzReductionReport = OpaqueHandle<"cmd.FuzzReductionReport">;
export type FuzzReductionStep = OpaqueHandle<"cmd.FuzzReductionStep">;
export type InliningOptions = OpaqueHandle<"cmd.InliningOptions">;
export type OptimizeOptions = OpaqueHandle<"cmd.OptimizeOptions">;
export type OptimizeTracingLevel = OpaqueHandle<"cmd.OptimizeTracingLevel">;
export type OptimizeValidationPolicy = OpaqueHandle<"cmd.OptimizeValidationPolicy">;
export type ReadmeApiVerifyBlock = OpaqueHandle<"cmd.ReadmeApiVerifyBlock">;
export type TextAggregateAdapterResult = OpaqueHandle<"cmd.TextAggregateAdapterResult">;
export type TextAggregateClassification = OpaqueHandle<"cmd.TextAggregateClassification">;
export type TextDifferentialArtifactPaths = OpaqueHandle<"cmd.TextDifferentialArtifactPaths">;
export type TextParsePrintLowerReport = OpaqueHandle<"cmd.TextParsePrintLowerReport">;

export function binaryDifferentialClassificationLabel(arg0: BinaryDifferentialClassification): string;
export function binaryDifferentialFailedValidationResult(arg0: string, arg1: Uint8Array, arg2: string): BinaryDifferentialAdapterResult;
export function chooseSimpleExportInvocationArgs(arg0: Array<lib_ValType>): StarshineResult<Array<string>, string>;
export function classifyBinaryCanonicalityDifferential(arg0: BinaryCanonicalityInputClass, arg1: boolean, arg2: (boolean) | null, arg3: (boolean) | null): BinaryCanonicalityClassification;
export function classifyBinaryDifferentialResults(arg0: Array<BinaryDifferentialAdapterResult>): BinaryDifferentialClassification;
export function classifyExportInvocationMatrix(arg0: ExportInvocationMatrixSummary): ExportInvocationMatrixOutcome;
export function classifyExportInvocationResults(arg0: ExportInvocationResult, arg1: ExportInvocationResult): ExportInvocationClassification;
export function classifyNWayTextAggregate(arg0: Array<TextAggregateAdapterResult>): TextAggregateClassification;
export function cmdFuzzHarnessProfileConfig(arg0: string): StarshineResult<CmdFuzzHarnessProfileConfig, string>;
export function cmdFuzzHarnessProfileConfigWithSeed(arg0: string, arg1: bigint): StarshineResult<CmdFuzzHarnessProfileConfig, string>;
export function cmdFuzzRandomPassSequence(arg0: string, arg1: bigint): Array<string>;
export function cmdHelpText(): string;
export function cmdVersionText(): string;
export function compareExportInvocationResults(arg0: string, arg1: Array<string>, arg2: ExportInvocationResult, arg3: ExportInvocationResult): ExportInvocationComparisonReport;
export function differentialValidateWasm(arg0: Uint8Array, adapters?: DifferentialAdapters): StarshineResult<DifferentialValidationReport, string>;
export function exportInvocationMatrixShouldFail(arg0: ExportInvocationMatrixSummary, arg1: ExportInvocationFailurePolicy): boolean;
export function exportInvocationSemanticMismatchReports(arg0: Array<ExportInvocationComparisonReport>): Array<ExportInvocationComparisonReport>;
export function exportInvocationSummaryHasSemanticMismatch(arg0: ExportInvocationMatrixSummary): boolean;
export function formatBinaryDifferentialSmokeReportJson(arg0: BinaryDifferentialSmokeReport): string;
export function minimizeFuzzPasses(...args: never[]): never;
export function nativeDifferentialToolsAvailable(): [boolean, boolean];
export function persistFuzzFailureReport(arg0: FuzzFailureReport, arg1: FuzzFailurePersistIO, corpusDir?: string): StarshineResult<[string, (string) | null], string>;
export function persistTextDifferentialArtifacts(arg0: string, arg1: TextParsePrintLowerReport, arg2: Array<TextAggregateAdapterResult>, arg3: TextAggregateClassification, arg4: FuzzFailurePersistIO, reproDir?: string, seed?: bigint, attempt?: number): StarshineResult<TextDifferentialArtifactPaths, string>;
export function reduceFuzzBytesBySliceDeletion(...args: never[]): never;
export function reduceFuzzModuleFieldsByDeletion(...args: never[]): never;
export function reduceFuzzSequenceByDeletion(...args: never[]): never;
export function reduceFuzzTextTokensByDeletion(...args: never[]): never;
export function runBinaryDifferentialSmoke(arg0: Array<Uint8Array>, externalAdapters?: Array<BinaryDifferentialSmokeAdapter>): BinaryDifferentialSmokeReport;
export function runBinaryenBinaryValidationAdapter(arg0: Uint8Array): BinaryDifferentialAdapterResult;
export function runCmd(arg0: Array<string>): StarshineResult<CmdRunSummary, CmdError>;
export function runCmdExitCode(arg0: Array<string>): number;
export function runCmdExitCodeWithAdapter(arg0: Array<string>, arg1: CmdIO, configJson?: (string) | null): number;
export function runCmdFuzzHarness(...args: never[]): never;
export function runCmdFuzzHarnessProfile(arg0: string, arg1: bigint): StarshineResult<CmdFuzzStats, string>;
export function runCmdWithAdapter(arg0: Array<string>, arg1: CmdIO, configJson?: (string) | null): StarshineResult<CmdRunSummary, CmdError>;
export function runLocalTextParsePrintLowerMatrix(arg0: string, filename?: string): TextParsePrintLowerReport;
export function runWabtBinaryValidationAdapter(arg0: Uint8Array): BinaryDifferentialAdapterResult;
export function runWasmToolsBinaryValidationAdapter(arg0: Uint8Array): BinaryDifferentialAdapterResult;
export function summarizeBinaryCanonicalityClassifications(arg0: Array<BinaryCanonicalityClassification>): BinaryCanonicalitySummary;
export function summarizeExportInvocationMatrix(arg0: Array<ExportInvocationComparisonReport>): ExportInvocationMatrixSummary;
export function textAggregateClassificationLabel(arg0: TextAggregateClassification): string;
export function textAggregateLocalResult(arg0: TextParsePrintLowerReport, validatesOk?: (boolean) | null): TextAggregateAdapterResult;
export function verifyReadmeApiSignatures(arg0: string, arg1: Array<[string, string]>): StarshineResult<void, string>;
export function verifyReadmeApiSignaturesWithRequiredBlocks(arg0: string, arg1: Array<[string, string]>, arg2: Array<string>): StarshineResult<void, string>;

export const BinaryCanonicalityClassification: {
  acceptedNoncanonical(): BinaryCanonicalityClassification;
  canonicalAccepted(): BinaryCanonicalityClassification;
  decoderBugDisagreement(): BinaryCanonicalityClassification;
  externalPolicyDisagreement(): BinaryCanonicalityClassification;
  malformedRejected(): BinaryCanonicalityClassification;
};

export const BinaryCanonicalityInputClass: {
  acceptedNoncanonical(): BinaryCanonicalityInputClass;
  canonical(): BinaryCanonicalityInputClass;
  malformed(): BinaryCanonicalityInputClass;
};

export const BinaryCanonicalitySummary: {
};

export const BinaryDifferentialAdapterResult: {
  adapterUnavailable(arg0: string, arg1: string): BinaryDifferentialAdapterResult;
  invalidDecode(arg0: string, arg1: string): BinaryDifferentialAdapterResult;
  invalidValidate(arg0: string, arg1: string): BinaryDifferentialAdapterResult;
  toolFailure(arg0: string, arg1: string): BinaryDifferentialAdapterResult;
  unsupportedFeature(arg0: string, arg1: string): BinaryDifferentialAdapterResult;
  valid(arg0: string): BinaryDifferentialAdapterResult;
};

export const BinaryDifferentialClassification: {
  adapterUnavailable(): BinaryDifferentialClassification;
  agreeInvalid(): BinaryDifferentialClassification;
  agreeValid(): BinaryDifferentialClassification;
  decoderStageDisagreement(): BinaryDifferentialClassification;
  proposalGap(): BinaryDifferentialClassification;
  toolFailure(): BinaryDifferentialClassification;
  unsupportedFeature(): BinaryDifferentialClassification;
  validatorStageDisagreement(): BinaryDifferentialClassification;
};

export const BinaryDifferentialSmokeAdapter: {
  "new"(...args: never[]): never;
};

export const BinaryDifferentialSmokeReport: {
};

export const BinaryValidationOutcome: {
};

export const CmdEncodeError: {
  adapter(arg0: string): CmdEncodeError;
  encode(arg0: binary_EncodeError): CmdEncodeError;
  show(value: CmdEncodeError): string;
};

export const CmdError: {
  ambiguousOutputFile(arg0: string): CmdError;
  unknownPassFlag(arg0: string): CmdError;
  show(value: CmdError): string;
};

export const CmdFuzzHarnessProfileConfig: {
};

export const CmdFuzzStats: {
  "new"(attempts?: number, generatedValid?: number, generatedInvalid?: number, pipelineValidated?: number, optimized?: number, roundtripped?: number, differentialChecked?: number, optimizeIdempotenceChecked?: number, encodeDecodeIdempotenceChecked?: number, optimizerDeterminismChecked?: number, generatorProfile?: string, passProfile?: string): CmdFuzzStats;
  show(value: CmdFuzzStats): string;
};

export const CmdIO: {
  "new"(...args: never[]): never;
};

export const CmdOptimizerReportMode: {
};

export const CmdPipelineDumpFormat: {
};

export const CmdPipelinePrintSelector: {
};

export const CmdPipelineStep: {
};

export const CmdRunSummary: {
  "new"(inputFiles?: Array<string>, outputFiles?: Array<string>, resolvedPasses?: Array<string>, optimizeLevel?: number, shrinkLevel?: number, trapsNeverHappen?: boolean, ignoreImplicitTraps?: boolean, monomorphizeMinBenefit?: number, closedWorld?: boolean, lowMemoryUnused?: boolean, lowMemoryBound?: bigint): CmdRunSummary;
  show(value: CmdRunSummary): string;
};

export const DifferentialAdapters: {
  "new"(...args: never[]): never;
};

export const DifferentialValidationReport: {
  show(value: DifferentialValidationReport): string;
};

export const ExportInvocationClassification: {
  equalResult(): ExportInvocationClassification;
  equalTrap(): ExportInvocationClassification;
  nondeterministicImport(): ExportInvocationClassification;
  semanticMismatch(arg0: string): ExportInvocationClassification;
  unsupportedRuntime(): ExportInvocationClassification;
};

export const ExportInvocationComparisonReport: {
};

export const ExportInvocationFailurePolicy: {
  failOnSemanticMismatch(): ExportInvocationFailurePolicy;
  informational(): ExportInvocationFailurePolicy;
};

export const ExportInvocationMatrixOutcome: {
  allEqual(): ExportInvocationMatrixOutcome;
  blocked(): ExportInvocationMatrixOutcome;
  empty(): ExportInvocationMatrixOutcome;
  semanticMismatch(): ExportInvocationMatrixOutcome;
};

export const ExportInvocationMatrixSummary: {
};

export const ExportInvocationResult: {
  nondeterministicImport(arg0: string): ExportInvocationResult;
  trap(arg0: string): ExportInvocationResult;
  unsupportedRuntime(arg0: string): ExportInvocationResult;
  value(arg0: string): ExportInvocationResult;
};

export const FuzzCorpusDedupDecision: {
};

export const FuzzCorpusDedupHashEntry: {
};

export const FuzzCorpusDedupIndex: {
  "new"(): FuzzCorpusDedupIndex;
  record(arg0: FuzzCorpusDedupIndex, arg1: Uint8Array, arg2: FuzzCorpusSource): FuzzCorpusDedupDecision;
  toText(arg0: FuzzCorpusDedupIndex): string;
};

export const FuzzCorpusDedupSourceEntry: {
};

export const FuzzCorpusSource: {
  "new"(arg0: bigint, arg1: number, arg2: string, arg3: string, arg4: string): FuzzCorpusSource;
};

export const FuzzFailurePersistIO: {
  "new"(...args: never[]): never;
};

export const FuzzFailureReport: {
  "new"(arg0: bigint, arg1: number, arg2: number, arg3: string, arg4: string, optimizePasses?: Array<string>, minimizedPasses?: Array<string>, generatorProfile?: string, passProfile?: string, generatorConfigLabel?: string, generatedAttempts?: number, featureFacts?: string, wasm?: (Uint8Array) | null, reducedWasm?: (Uint8Array) | null, reductionOriginalSize?: (number) | null, reductionFinalSize?: (number) | null, reductionPredicateEvaluations?: (number) | null, reductionSteps?: Array<FuzzReductionStep>): FuzzFailureReport;
  show(value: FuzzFailureReport): string;
};

export const FuzzReductionReport: {
};

export const FuzzReductionStep: {
};

export const InliningOptions: {
  "new"(alwaysInlineMaxSize?: number, oneCallerInlineMaxSize?: number, flexibleInlineMaxSize?: number, maxCombinedBinarySize?: number, allowFunctionsWithLoops?: boolean, partialInliningIfs?: number): InliningOptions;
  show(value: InliningOptions): string;
};

export const OptimizeOptions: {
  "new"(optimizeLevel?: number, shrinkLevel?: number, inlining?: InliningOptions, monomorphizeMinBenefit?: number, closedWorld?: boolean, zeroFilledMemory?: boolean, fastMath?: boolean, lowMemoryUnused?: boolean, lowMemoryBound?: bigint, trapsNeverHappen?: boolean, ignoreImplicitTraps?: boolean, compilerFactPolicy?: OpaqueHandle<"@passes.CompilerFactUsePolicy">, validationPolicy?: OptimizeValidationPolicy, stackFunctionPasses?: boolean): OptimizeOptions;
  show(value: OptimizeOptions): string;
};

export const OptimizeTracingLevel: {
  helper(): OptimizeTracingLevel;
  pass(): OptimizeTracingLevel;
  phase(): OptimizeTracingLevel;
  show(value: OptimizeTracingLevel): string;
};

export const OptimizeValidationPolicy: {
  afterSegment(): OptimizeValidationPolicy;
  finalModuleOnly(): OptimizeValidationPolicy;
  show(value: OptimizeValidationPolicy): string;
};

export const ReadmeApiVerifyBlock: {
  show(value: ReadmeApiVerifyBlock): string;
};

export const TextAggregateAdapterResult: {
  externalAccepted(arg0: string, validatesOk?: (boolean) | null): TextAggregateAdapterResult;
  externalParseError(arg0: string, arg1: string): TextAggregateAdapterResult;
  externalUnavailable(arg0: string, arg1: string): TextAggregateAdapterResult;
  externalUnsupportedSyntax(arg0: string, arg1: string): TextAggregateAdapterResult;
};

export const TextAggregateClassification: {
  accepted(): TextAggregateClassification;
  adapterUnavailable(): TextAggregateClassification;
  lowerDisagreement(): TextAggregateClassification;
  parseDisagreement(): TextAggregateClassification;
  printDisagreement(): TextAggregateClassification;
  semanticValidationDisagreement(): TextAggregateClassification;
  unsupportedSyntax(): TextAggregateClassification;
};

export const TextDifferentialArtifactPaths: {
};

export const TextParsePrintLowerReport: {
};

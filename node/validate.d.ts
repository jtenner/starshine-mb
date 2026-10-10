import type { OpaqueHandle, StarshineResult } from "./internal/shared.js";
import type { BlockType as lib_BlockType, Catch as lib_Catch, CodeSec as lib_CodeSec, CompType as lib_CompType, Data as lib_Data, DataCntSec as lib_DataCntSec, DataIdx as lib_DataIdx, DataSec as lib_DataSec, Elem as lib_Elem, ElemIdx as lib_ElemIdx, ElemSec as lib_ElemSec, ExportSec as lib_ExportSec, Expr as lib_Expr, FieldType as lib_FieldType, Func as lib_Func, FuncIdx as lib_FuncIdx, FuncSec as lib_FuncSec, FuncType as lib_FuncType, GlobalIdx as lib_GlobalIdx, GlobalSec as lib_GlobalSec, GlobalType as lib_GlobalType, HeapType as lib_HeapType, ImportSec as lib_ImportSec, LabelIdx as lib_LabelIdx, LocalIdx as lib_LocalIdx, Locals as lib_Locals, MemIdx as lib_MemIdx, MemSec as lib_MemSec, MemType as lib_MemType, Module as lib_Module, RecType as lib_RecType, RefType as lib_RefType, StartSec as lib_StartSec, SubType as lib_SubType, TableIdx as lib_TableIdx, TableSec as lib_TableSec, TableType as lib_TableType, TagIdx as lib_TagIdx, TagSec as lib_TagSec, TagType as lib_TagType, TypeIdx as lib_TypeIdx, TypeSec as lib_TypeSec, ValType as lib_ValType } from "./lib.js";

export type Env = OpaqueHandle<"validate.Env">;
export type GenInvalidAstGenerated = OpaqueHandle<"validate.GenInvalidAstGenerated">;
export type GenInvalidAstParams = OpaqueHandle<"validate.GenInvalidAstParams">;
export type GenInvalidNamedSeedProfile = OpaqueHandle<"validate.GenInvalidNamedSeedProfile">;
export type GenInvalidSeedMode = OpaqueHandle<"validate.GenInvalidSeedMode">;
export type GenValidBudgetStop = OpaqueHandle<"validate.GenValidBudgetStop">;
export type GenValidConfig = OpaqueHandle<"validate.GenValidConfig">;
export type GenValidConstExprAllowedOps = OpaqueHandle<"validate.GenValidConstExprAllowedOps">;
export type GenValidConstExprObservedOps = OpaqueHandle<"validate.GenValidConstExprObservedOps">;
export type GenValidConstExprOpFamily = OpaqueHandle<"validate.GenValidConstExprOpFamily">;
export type GenValidConstExprUse = OpaqueHandle<"validate.GenValidConstExprUse">;
export type GenValidContext = OpaqueHandle<"validate.GenValidContext">;
export type GenValidExactOpcodeCounts = OpaqueHandle<"validate.GenValidExactOpcodeCounts">;
export type GenValidFailure = OpaqueHandle<"validate.GenValidFailure">;
export type GenValidFeatureFacts = OpaqueHandle<"validate.GenValidFeatureFacts">;
export type GenValidFeatureStats = OpaqueHandle<"validate.GenValidFeatureStats">;
export type GenValidFeatureToggles = OpaqueHandle<"validate.GenValidFeatureToggles">;
export type GenValidGenerated = OpaqueHandle<"validate.GenValidGenerated">;
export type GenValidMode = OpaqueHandle<"validate.GenValidMode">;
export type GenValidModuleGenerated = OpaqueHandle<"validate.GenValidModuleGenerated">;
export type GenValidProfile = OpaqueHandle<"validate.GenValidProfile">;
export type GenValidProfileMember = OpaqueHandle<"validate.GenValidProfileMember">;
export type GenValidProposalFeature = OpaqueHandle<"validate.GenValidProposalFeature">;
export type GenValidProposalFeatureGateRow = OpaqueHandle<"validate.GenValidProposalFeatureGateRow">;
export type GenValidRandomStreamLabel = OpaqueHandle<"validate.GenValidRandomStreamLabel">;
export type GenValidSectionBias = OpaqueHandle<"validate.GenValidSectionBias">;
export type GenValidSsaFuncFacts = OpaqueHandle<"validate.GenValidSsaFuncFacts">;
export type LabelStack = OpaqueHandle<"validate.LabelStack">;
export type LegacyCatchScope = OpaqueHandle<"validate.LegacyCatchScope">;
export type ProposalFeature = OpaqueHandle<"validate.ProposalFeature">;
export type TcEscape = OpaqueHandle<"validate.TcEscape">;
export type TcResult = OpaqueHandle<"validate.TcResult">;
export type TcState = OpaqueHandle<"validate.TcState">;
export type ValidateInvalidAstFuzzStats = OpaqueHandle<"validate.ValidateInvalidAstFuzzStats">;
export type ValidateInvalidAstMutation = OpaqueHandle<"validate.ValidateInvalidAstMutation">;
export type ValidateInvalidAstRunConfig = OpaqueHandle<"validate.ValidateInvalidAstRunConfig">;
export type ValidateInvalidAstSeedPrerequisite = OpaqueHandle<"validate.ValidateInvalidAstSeedPrerequisite">;
export type ValidateInvalidAstStrategyId = OpaqueHandle<"validate.ValidateInvalidAstStrategyId">;
export type ValidateInvalidAstStrategySpec = OpaqueHandle<"validate.ValidateInvalidAstStrategySpec">;
export type ValidateInvalidAstStrategyStats = OpaqueHandle<"validate.ValidateInvalidAstStrategyStats">;
export type ValidateValidFeatureFloor = OpaqueHandle<"validate.ValidateValidFeatureFloor">;
export type ValidateValidFeatureFloorFailure = OpaqueHandle<"validate.ValidateValidFeatureFloorFailure">;
export type ValidateValidFeatureKey = OpaqueHandle<"validate.ValidateValidFeatureKey">;
export type ValidateValidFeatureLedgerEntry = OpaqueHandle<"validate.ValidateValidFeatureLedgerEntry">;
export type ValidateValidFeatureLedgerStatus = OpaqueHandle<"validate.ValidateValidFeatureLedgerStatus">;
export type ValidateValidFuzzStats = OpaqueHandle<"validate.ValidateValidFuzzStats">;
export type ValidateValidRunConfig = OpaqueHandle<"validate.ValidateValidRunConfig">;
export type ValidationDiagnostic = OpaqueHandle<"validate.ValidationDiagnostic">;
export type ValidationError = OpaqueHandle<"validate.ValidationError">;
export type ValidationIssue = OpaqueHandle<"validate.ValidationIssue">;
export type ValidationIssueFamily = OpaqueHandle<"validate.ValidationIssueFamily">;

export function applyValidateInvalidAstStrategy(arg0: ValidateInvalidAstStrategyId, arg1: lib_Module): StarshineResult<ValidateInvalidAstMutation, string>;
export function buildValidateInvalidAstMinimalRepro(arg0: ValidateInvalidAstStrategyId): StarshineResult<lib_Module, string>;
export function buildValidateInvalidAstMinimalReproByStableId(arg0: string): StarshineResult<lib_Module, string>;
export function checkValidateValidFeatureFloors(arg0: GenValidFeatureStats, arg1: Array<ValidateValidFeatureFloor>): Array<ValidateValidFeatureFloorFailure>;
export function controlledProposalFeatures(): Array<ProposalFeature>;
export function defaultGenValidConfig(): GenValidConfig;
export function descriptorCompatible(arg0: lib_RefType, arg1: lib_RefType, arg2: Env): boolean;
export function diff(arg0: lib_RefType, arg1: lib_RefType): StarshineResult<lib_RefType, string>;
export function emptyEnv(): Env;
export function genInvalidAstGenerate(arg0: OpaqueHandle<"@splitmix.RandomState">, arg1: GenInvalidAstParams): StarshineResult<GenInvalidAstGenerated, string>;
export function genInvalidAstGenerateFromSeed(arg0: bigint, arg1: GenInvalidAstParams): StarshineResult<GenInvalidAstGenerated, string>;
export function genInvalidAstParamsProfileName(arg0: GenInvalidAstParams): string;
export function genInvalidAstSeedConfig(arg0: GenInvalidAstParams): GenValidConfig;
export function genInvalidAstSeedModule(arg0: OpaqueHandle<"@splitmix.RandomState">, arg1: GenInvalidAstParams): StarshineResult<lib_Module, string>;
export function genInvalidAstStrategySeedPrerequisites(arg0: ValidateInvalidAstStrategyId): Array<ValidateInvalidAstSeedPrerequisite>;
export function genInvalidCoverageSeedGeneratorConfig(): GenValidConfig;
export function genInvalidNamedSeedProfileName(arg0: GenInvalidNamedSeedProfile): string;
export function genInvalidRequireDefinedFuncGenValidConfig(arg0: GenValidConfig): GenValidConfig;
export function genInvalidRequireMemoryDataGenValidConfig(arg0: GenValidConfig): GenValidConfig;
export function genInvalidSeedModeName(arg0: GenInvalidSeedMode): string;
export function genInvalidSmallGenValidConfig(arg0: GenValidConfig): GenValidConfig;
export function genValidCaseSeed(arg0: bigint, arg1: number): bigint;
export function genValidCodeFoldingProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidConfigLabel(arg0: GenValidConfig): string;
export function genValidConstExprAllowedOpMatrix(): Array<GenValidConstExprAllowedOps>;
export function genValidConstExprObservedOpMatrix(arg0: lib_Module): Array<GenValidConstExprObservedOps>;
export function genValidCoverageTemplateSignature(arg0: lib_Module): string;
export function genValidDaeOptimizingProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidDeadArgumentEliminationProfileConfig(arg0: GenValidProfile): GenValidConfig;
export function genValidDeriveStreamSeed(arg0: bigint, arg1: GenValidRandomStreamLabel): bigint;
export function genValidDirectizeProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidDuplicateImportEliminationProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidEngineStateCrossInstanceSupportModule(arg0: bigint): lib_Module;
export function genValidEngineStateFailureFamily(arg0: GenValidProfile, arg1: bigint): string;
export function genValidEngineStateIndirectTrapFamily(arg0: bigint): string;
export function genValidEngineStateInstantiationFailureFamily(arg0: bigint): string;
export function genValidEngineStateInvalidModuleFamily(arg0: bigint): string;
export function genValidEngineStateLinkGraphSupportModules(arg0: bigint): Array<lib_Module>;
export function genValidEngineStateMetamorphicComparisonModule(arg0: bigint): lib_Module;
export function genValidEngineStateOutcome(arg0: GenValidProfile): string;
export function genValidEngineStateProfile(): GenValidProfile;
export function genValidEngineStateStaticInstructionCount(arg0: lib_Module): number;
export function genValidEngineStateTrapCommitFamily(arg0: bigint): string;
export function genValidEngineStateTrapFamily(arg0: bigint): string;
export function genValidEngineTieringProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidFeatureFacts(arg0: lib_Module, arg1: GenValidMode): GenValidFeatureFacts;
export function genValidFlattenProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidHeapStoreOptimizationProfileCaseLabel(arg0: GenValidProfile): (string) | null;
export function genValidInliningOptimizingProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidMemoryPackingProfileCaseLabel(arg0: GenValidProfile): (string) | null;
export function genValidMergeBlocksProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidMergeLocalsProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidMergeSsaFuncFacts(arg0: GenValidSsaFuncFacts, arg1: GenValidSsaFuncFacts): GenValidSsaFuncFacts;
export function genValidModule(arg0: OpaqueHandle<"@splitmix.RandomState">): lib_Module;
export function genValidModuleFromSeed(arg0: bigint, arg1: GenValidConfig): StarshineResult<GenValidModuleGenerated, GenValidFailure>;
export function genValidModuleResult(arg0: OpaqueHandle<"@splitmix.RandomState">, arg1: GenValidConfig): StarshineResult<GenValidGenerated, GenValidFailure>;
export function genValidModuleResultFromSeed(arg0: bigint, arg1: GenValidConfig): StarshineResult<GenValidGenerated, GenValidFailure>;
export function genValidModuleWithConfig(arg0: OpaqueHandle<"@splitmix.RandomState">, arg1: GenValidConfig): lib_Module;
export function genValidMsfProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidNumtype(...args: never[]): never;
export function genValidOiTriggerProfileCaseForSeed(arg0: bigint): number;
export function genValidOiTriggerProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidProfileByName(arg0: string): StarshineResult<GenValidProfile, string>;
export function genValidProfileIsComposite(arg0: GenValidProfile): boolean;
export function genValidProfileLeafForCase(arg0: GenValidProfile, arg1: bigint, arg2: number): GenValidProfile;
export function genValidProfileMembers(arg0: GenValidProfile): Array<GenValidProfileMember>;
export function genValidProfileName(arg0: GenValidProfile): string;
export function genValidProfileNames(): Array<string>;
export function genValidProfiles(): Array<GenValidProfile>;
export function genValidProposalFeatureEnabled(arg0: GenValidFeatureToggles, arg1: GenValidProposalFeature): boolean;
export function genValidProposalFeatureGateMatrix(): Array<GenValidProposalFeatureGateRow>;
export function genValidProposalFeatureLabel(arg0: GenValidProposalFeature): string;
export function genValidProposalFeatures(): Array<GenValidProposalFeature>;
export function genValidRandomStreamLabelName(arg0: GenValidRandomStreamLabel): string;
export function genValidRandomStreamLabels(): Array<GenValidRandomStreamLabel>;
export function genValidReorderGlobalsProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidRumeProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidScanFuncSsaFacts(arg0: number, arg1: lib_Locals, arg2: lib_Expr): GenValidSsaFuncFacts;
export function genValidSsaFullProfileCaseLabel(arg0: GenValidProfile): (string) | null;
export function genValidStreamRandomState(arg0: bigint, arg1: GenValidRandomStreamLabel): OpaqueHandle<"@splitmix.RandomState">;
export function genValidTfunc(...args: never[]): never;
export function genValidTupleOptimizationTriggerProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidUndersampledPassProfileCaseLabel(arg0: GenValidProfile, arg1: bigint): (string) | null;
export function genValidValtype(...args: never[]): never;
export function genValidValtypeWithExtraRefs(...args: never[]): never;
export function makeState(arg0: Env, arg1: Array<lib_ValType>): TcState;
export function makeStateOwned(arg0: Env, arg1: Array<lib_ValType>): TcState;
export function moduleProposalFeatures(arg0: lib_Module): Array<ProposalFeature>;
export function proposalFeatureByName(arg0: string): (ProposalFeature) | null;
export function proposalFeatureName(arg0: ProposalFeature): string;
export function runValidateInvalidAstFuzz(arg0: string, arg1: bigint): StarshineResult<ValidateInvalidAstFuzzStats, string>;
export function runValidateValidFuzz(arg0: string, arg1: bigint): StarshineResult<ValidateValidFuzzStats, string>;
export function tcEscapeNone(): TcEscape;
export function tcEscapeTerminal(): TcEscape;
export function tcStateClone(arg0: TcState): TcState;
export function tcStateFinishBlock(arg0: TcState, arg1: TcState, arg2: TcState, arg3: Array<lib_ValType>): StarshineResult<TcState, string>;
export function tcStateFinishIf(arg0: TcState, arg1: TcState, arg2: TcState, arg3: TcState, arg4: Array<lib_ValType>): StarshineResult<TcState, string>;
export function tcStateFinishLoop(arg0: TcState, arg1: TcState, arg2: TcState, arg3: Array<lib_ValType>): StarshineResult<TcState, string>;
export function tcStateFinishTryTable(arg0: TcState, arg1: TcState, arg2: TcState, arg3: Array<lib_ValType>, arg4: Array<lib_Catch>): StarshineResult<TcState, string>;
export function tcStateForkBody(arg0: TcState, arg1: Env, arg2: Array<lib_ValType>): TcState;
export function tcStateMergeNonfallthroughIfExits(arg0: TcEscape, arg1: TcEscape): TcEscape;
export function tcStateNew(arg0: Env, arg1: Array<lib_ValType>, arg2: boolean, arg3: TcEscape): TcState;
export function tcStateNormalizeUntypedBlockExit(arg0: TcState, arg1: Array<lib_ValType>): StarshineResult<[boolean, TcEscape], string>;
export function tcStateNormalizeUntypedIfBranchExit(arg0: TcState, arg1: Array<lib_ValType>): StarshineResult<[boolean, TcEscape], string>;
export function tcStatePopExpect(arg0: TcState, arg1: lib_ValType): StarshineResult<TcState, string>;
export function tcStatePopTypes(arg0: TcState, arg1: Array<lib_ValType>): StarshineResult<TcState, string>;
export function tcStatePushTypes(arg0: TcState, arg1: Array<lib_ValType>): TcState;
export function tcStateTypecheckCatchClause(arg0: TcState, arg1: lib_Catch): StarshineResult<void, string>;
export function tcStateValidateEndStack(arg0: TcState, arg1: Array<lib_ValType>): StarshineResult<void, string>;
export function tcStateWithOwnedStack(arg0: TcState, arg1: Array<lib_ValType>): TcState;
export function tcStateWithStack(arg0: TcState, arg1: Array<lib_ValType>): TcState;
export function typecheckExprForProbe(arg0: lib_Expr, arg1: TcState): StarshineResult<TcState, string>;
export function validateCodesec(arg0: (lib_CodeSec) | null, arg1: (lib_FuncSec) | null, arg2: Env): StarshineResult<void, string>;
export function validateDatacnt(arg0: (lib_DataCntSec) | null, arg1: (lib_DataSec) | null): StarshineResult<void, string>;
export function validateDatasec(arg0: (lib_DataSec) | null, arg1: Env): StarshineResult<Env, string>;
export function validateDefinedFuncAgainstModule(arg0: lib_Module, arg1: lib_FuncIdx, arg2: lib_Func): StarshineResult<void, string>;
export function validateDefinedFuncsAgainstModule(arg0: lib_Module, arg1: Array<[lib_FuncIdx, lib_Func]>): StarshineResult<Array<[lib_FuncIdx, string]>, ValidationError>;
export function validateElemsec(arg0: (lib_ElemSec) | null, arg1: Env): StarshineResult<Env, string>;
export function validateExportsec(arg0: (lib_ExportSec) | null, arg1: Env): StarshineResult<void, string>;
export function validateFuncBodyAgainstFunctype(arg0: Env, arg1: lib_FuncType, arg2: lib_Func): StarshineResult<void, string>;
export function validateFuncsec(arg0: (lib_FuncSec) | null, arg1: Env): StarshineResult<Env, string>;
export function validateGlobalsec(arg0: (lib_GlobalSec) | null, arg1: Env): StarshineResult<Env, string>;
export function validateImportsec(arg0: (lib_ImportSec) | null, arg1: Env): StarshineResult<Env, string>;
export function validateInvalidAstAttemptSeedForProfile(arg0: bigint, arg1: string, arg2: string): bigint;
export function validateInvalidAstRegistry(): Array<ValidateInvalidAstStrategySpec>;
export function validateInvalidAstRunConfig(arg0: string): StarshineResult<ValidateInvalidAstRunConfig, string>;
export function validateInvalidAstStrategyByStableId(arg0: string): (ValidateInvalidAstStrategySpec) | null;
export function validateInvalidAstStrategySpecById(arg0: ValidateInvalidAstStrategyId): (ValidateInvalidAstStrategySpec) | null;
export function validateMemsec(arg0: (lib_MemSec) | null, arg1: Env): StarshineResult<Env, string>;
export function validateModule(arg0: lib_Module, disabledFeatures?: Array<ProposalFeature>): StarshineResult<void, ValidationError>;
export function validateModuleWithTrace(...args: never[]): never;
export function validateStartsec(arg0: (lib_StartSec) | null, arg1: Env): StarshineResult<void, string>;
export function validateTablesec(arg0: (lib_TableSec) | null, arg1: Env): StarshineResult<Env, string>;
export function validateTagsec(arg0: (lib_TagSec) | null, arg1: Env): StarshineResult<Env, string>;
export function validateTypesec(arg0: (lib_TypeSec) | null, arg1: Env): StarshineResult<Env, string>;
export function validateValidFeatureActualCount(arg0: GenValidFeatureStats, arg1: ValidateValidFeatureKey): number;
export function validateValidFeatureActualCountByLabel(arg0: GenValidFeatureStats, arg1: string): StarshineResult<number, string>;
export function validateValidFeatureFloor(arg0: ValidateValidFeatureKey, arg1: number): ValidateValidFeatureFloor;
export function validateValidFeatureFloorByLabel(arg0: string, arg1: number): StarshineResult<ValidateValidFeatureFloor, string>;
export function validateValidFeatureLedger(arg0: GenValidFeatureStats, arg1: Array<ValidateValidFeatureFloor>): Array<ValidateValidFeatureLedgerEntry>;
export function validateValidRunConfig(arg0: string): StarshineResult<ValidateValidRunConfig, string>;
export function validationErrorDiagnostic(arg0: ValidationError): ValidationDiagnostic;
export function validationErrorFuncIdx(arg0: ValidationError): (lib_FuncIdx) | null;
export function validationErrorMessage(arg0: ValidationError): string;
export function validationIssueFamily(arg0: ValidationIssue): ValidationIssueFamily;
export function validationIssueMessage(arg0: ValidationIssue): string;

export const Env: {
  appendRectypeTypes(arg0: Env, arg1: lib_RecType): Env;
  descriptorResultType(arg0: Env, arg1: lib_TypeIdx, arg2: (lib_RefType) | null): StarshineResult<lib_ValType, string>;
  expandBlocktype(arg0: Env, arg1: lib_BlockType): StarshineResult<[Array<lib_ValType>, Array<lib_ValType>], string>;
  getCatchLabelTypes(arg0: Env, arg1: lib_LabelIdx): (Array<lib_ValType>) | null;
  getElem(arg0: Env, arg1: lib_ElemIdx): (lib_Elem) | null;
  getFunctypeByFuncidx(arg0: Env, arg1: lib_FuncIdx): (lib_FuncType) | null;
  getFunctypeidxByFuncidx(arg0: Env, arg1: lib_FuncIdx): (lib_TypeIdx) | null;
  getGlobalType(arg0: Env, arg1: lib_GlobalIdx): (lib_GlobalType) | null;
  getLabel(arg0: Env, arg1: lib_LabelIdx): (Array<lib_ValType>) | null;
  getLabelTypes(arg0: Env, arg1: lib_LabelIdx): (Array<lib_ValType>) | null;
  getLocalType(arg0: Env, arg1: lib_LocalIdx): (lib_ValType) | null;
  getMemtype(arg0: Env, arg1: lib_MemIdx): (lib_MemType) | null;
  getTableType(arg0: Env, arg1: lib_TableIdx): (lib_TableType) | null;
  getTag(arg0: Env, arg1: lib_TagIdx): (lib_TagType) | null;
  hasData(arg0: Env, arg1: lib_DataIdx): boolean;
  hasFunc(arg0: Env, arg1: lib_FuncIdx): boolean;
  legacyRethrowCatchOrdinal(arg0: Env, arg1: number): (number) | null;
  "new"(): Env;
  pushData(arg0: Env, arg1: lib_Data): Env;
  pushElem(arg0: Env, arg1: lib_Elem): Env;
  pushFunc(arg0: Env, arg1: lib_FuncType): Env;
  pushFuncWithTypeidx(arg0: Env, arg1: lib_FuncType, arg2: (lib_TypeIdx) | null): Env;
  pushGlobal(arg0: Env, arg1: lib_GlobalType): Env;
  pushMem(arg0: Env, arg1: lib_MemType): Env;
  pushTable(arg0: Env, arg1: lib_TableType): Env;
  pushTag(arg0: Env, arg1: lib_TagType): Env;
  resolveArrayField(arg0: Env, arg1: lib_TypeIdx): StarshineResult<lib_FieldType, string>;
  resolveComptype(arg0: Env, arg1: lib_TypeIdx): (lib_CompType) | null;
  resolveContFunctype(arg0: Env, arg1: lib_TypeIdx): (lib_FuncType) | null;
  resolveDescriptorTargetRefType(arg0: Env, arg1: boolean, arg2: lib_HeapType): StarshineResult<lib_RefType, string>;
  resolveFunctype(arg0: Env, arg1: lib_TypeIdx): (lib_FuncType) | null;
  resolveHeaptypeSubtype(arg0: Env, arg1: lib_HeapType): (lib_SubType) | null;
  resolveStructDescriptorType(arg0: Env, arg1: lib_TypeIdx): StarshineResult<(lib_TypeIdx) | null, string>;
  resolveStructFields(arg0: Env, arg1: lib_TypeIdx): StarshineResult<Array<lib_FieldType>, string>;
  resolveStructSubtype(arg0: Env, arg1: lib_TypeIdx): StarshineResult<lib_SubType, string>;
  resolveSubtype(arg0: Env, arg1: lib_TypeIdx): (lib_SubType) | null;
  resolveTagFunctype(arg0: Env, arg1: lib_TagIdx): (lib_FuncType) | null;
  resolveTypeidxSubtype(arg0: Env, arg1: lib_TypeIdx): (lib_SubType) | null;
  withDatas(arg0: Env, arg1: Array<lib_Data>): Env;
  withElems(arg0: Env, arg1: Array<lib_Elem>): Env;
  withExactReferenceInference(arg0: Env, arg1: boolean): Env;
  withFuncs(arg0: Env, arg1: Array<lib_FuncType>): Env;
  withFuncsAndTypeIdxs(arg0: Env, arg1: Array<lib_FuncType>, arg2: Array<(lib_TypeIdx) | null>): Env;
  withGlobals(arg0: Env, arg1: Array<lib_GlobalType>): Env;
  withLabel(arg0: Env, arg1: Array<lib_ValType>): Env;
  withLabels(arg0: Env, arg1: Array<Array<lib_ValType>>): Env;
  withLegacyCatchDepth(arg0: Env, arg1: number): Env;
  withLocals(arg0: Env, arg1: lib_Locals): Env;
  withMems(arg0: Env, arg1: Array<lib_MemType>): Env;
  withModule(arg0: Env, arg1: lib_Module): Env;
  withRectype(arg0: Env, arg1: lib_RecType): Env;
  withReturnType(arg0: Env, arg1: (Array<lib_ValType>) | null): Env;
  withTables(arg0: Env, arg1: Array<lib_TableType>): Env;
  withTags(arg0: Env, arg1: Array<lib_TagType>): Env;
  withTypes(arg0: Env, arg1: Array<lib_SubType>): Env;
  show(value: Env): string;
};

export const GenInvalidAstGenerated: {
};

export const GenInvalidAstParams: {
  coverageForcedSeed(arg0: ValidateInvalidAstStrategyId, generatorConfig?: GenValidConfig, requireStrategyPrereqs?: boolean): GenInvalidAstParams;
  minimalSeed(arg0: ValidateInvalidAstStrategyId, generatorConfig?: GenValidConfig, requireStrategyPrereqs?: boolean): GenInvalidAstParams;
  naturalSeed(arg0: ValidateInvalidAstStrategyId, generatorConfig?: GenValidConfig, requireStrategyPrereqs?: boolean): GenInvalidAstParams;
  "new"(arg0: ValidateInvalidAstStrategyId, seedMode?: GenInvalidSeedMode, generatorConfig?: GenValidConfig, requireStrategyPrereqs?: boolean): GenInvalidAstParams;
  reproSeed(arg0: ValidateInvalidAstStrategyId, generatorConfig?: GenValidConfig, requireStrategyPrereqs?: boolean): GenInvalidAstParams;
  richSeed(arg0: ValidateInvalidAstStrategyId, generatorConfig?: GenValidConfig, requireStrategyPrereqs?: boolean): GenInvalidAstParams;
  smallCoverageForcedSeed(arg0: ValidateInvalidAstStrategyId, generatorConfig?: GenValidConfig, requireStrategyPrereqs?: boolean): GenInvalidAstParams;
  smallNaturalSeed(arg0: ValidateInvalidAstStrategyId, generatorConfig?: GenValidConfig, requireStrategyPrereqs?: boolean): GenInvalidAstParams;
};

export const GenInvalidNamedSeedProfile: {
};

export const GenInvalidSeedMode: {
};

export const GenValidBudgetStop: {
};

export const GenValidConfig: {
  binaryenOracleCoverageForcedDefault(): GenValidConfig;
  coverageForcedDefault(): GenValidConfig;
  forProfile(arg0: GenValidProfile): GenValidConfig;
  naturalDefault(): GenValidConfig;
  portableCoverageForcedDefault(): GenValidConfig;
  profile(arg0: string): StarshineResult<GenValidConfig, string>;
  watTextRoundtripDefault(): GenValidConfig;
  show(value: GenValidConfig): string;
};

export const GenValidConstExprAllowedOps: {
};

export const GenValidConstExprObservedOps: {
};

export const GenValidConstExprOpFamily: {
};

export const GenValidConstExprUse: {
};

export const GenValidContext: {
};

export const GenValidExactOpcodeCounts: {
  add(arg0: GenValidExactOpcodeCounts, arg1: GenValidExactOpcodeCounts): GenValidExactOpcodeCounts;
  empty(): GenValidExactOpcodeCounts;
  show(value: GenValidExactOpcodeCounts): string;
};

export const GenValidFailure: {
};

export const GenValidFeatureFacts: {
};

export const GenValidFeatureStats: {
  empty(arg0: GenValidMode): GenValidFeatureStats;
  record(arg0: GenValidFeatureStats, arg1: GenValidFeatureFacts): GenValidFeatureStats;
  show(value: GenValidFeatureStats): string;
};

export const GenValidFeatureToggles: {
  coverageForcedDefault(): GenValidFeatureToggles;
  naturalDefault(): GenValidFeatureToggles;
  show(value: GenValidFeatureToggles): string;
};

export const GenValidGenerated: {
};

export const GenValidMode: {
  show(value: GenValidMode): string;
};

export const GenValidModuleGenerated: {
};

export const GenValidProfile: {
};

export const GenValidProfileMember: {
  "new"(arg0: GenValidProfile, arg1: number): GenValidProfileMember;
};

export const GenValidProposalFeature: {
};

export const GenValidProposalFeatureGateRow: {
};

export const GenValidRandomStreamLabel: {
};

export const GenValidSectionBias: {
  coverageForcedDefault(): GenValidSectionBias;
  naturalDefault(): GenValidSectionBias;
  show(value: GenValidSectionBias): string;
};

export const GenValidSsaFuncFacts: {
  empty(): GenValidSsaFuncFacts;
};

export const LabelStack: {
  copy(arg0: LabelStack): LabelStack;
  fromLabels(arg0: Array<Array<lib_ValType>>): LabelStack;
  get(arg0: LabelStack, arg1: number): (Array<lib_ValType>) | null;
  length(arg0: LabelStack): number;
  "new"(): LabelStack;
  push(arg0: LabelStack, arg1: Array<lib_ValType>): void;
  show(value: LabelStack): string;
};

export const LegacyCatchScope: {
};

export const ProposalFeature: {
};

export const TcEscape: {
  show(value: TcEscape): string;
};

export const TcResult: {
};

export const TcState: {
  show(value: TcState): string;
};

export const ValidateInvalidAstFuzzStats: {
};

export const ValidateInvalidAstMutation: {
};

export const ValidateInvalidAstRunConfig: {
};

export const ValidateInvalidAstSeedPrerequisite: {
};

export const ValidateInvalidAstStrategyId: {
};

export const ValidateInvalidAstStrategySpec: {
};

export const ValidateInvalidAstStrategyStats: {
};

export const ValidateValidFeatureFloor: {
  show(value: ValidateValidFeatureFloor): string;
};

export const ValidateValidFeatureFloorFailure: {
  show(value: ValidateValidFeatureFloorFailure): string;
};

export const ValidateValidFeatureKey: {
  show(value: ValidateValidFeatureKey): string;
};

export const ValidateValidFeatureLedgerEntry: {
};

export const ValidateValidFeatureLedgerStatus: {
  show(value: ValidateValidFeatureLedgerStatus): string;
};

export const ValidateValidFuzzStats: {
  show(value: ValidateValidFuzzStats): string;
};

export const ValidateValidRunConfig: {
};

export const ValidationDiagnostic: {
  "new"(arg0: ValidationIssue, funcIdx?: (lib_FuncIdx) | null): ValidationDiagnostic;
  show(value: ValidationDiagnostic): string;
};

export const ValidationError: {
  show(value: ValidationError): string;
};

export const ValidationIssue: {
  show(value: ValidationIssue): string;
};

export const ValidationIssueFamily: {
};

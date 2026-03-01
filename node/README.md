# Starshine Node Package

This package publishes Starshine as an ESM-first Node package backed by two generated WebAssembly artifacts:

- `./internal/starshine.wasm-gc.wasm` for the package-level JavaScript API.
- `./internal/starshine.wasm-wasi.wasm` for the optimized WASI CLI artifact shipped alongside the npm package.

## Requirements

- Node.js 25 or newer with WebAssembly GC and JS string builtins available.
- MoonBit on `PATH`, or `MOON_BIN` pointing at the Moon executable.

## Build

```bash
npm --prefix node run build
```

This regenerates the adapter sources, rebuilds the `wasm-gc` package adapter, rebuilds the optimized WASI CLI artifact, and copies both outputs into `node/internal/`.

## Use

```js
import { binary, wast } from '@jtenner/starshine';

const parsed = wast.wastToBinaryModule('(module)');
if (!parsed.ok) throw new Error(parsed.display ?? 'failed to parse');

const encoded = binary.encodeModule(parsed.value);
if (!encoded.ok) throw new Error(encoded.display ?? 'failed to encode');

console.log(encoded.value instanceof Uint8Array);
```

```bash
npx @jtenner/starshine --help
```

## Examples

Run any shipped example from the package root:

```bash
node examples/01-barrel-roundtrip.mjs
```

All examples are executed by the package test suite.

- `examples/01-barrel-roundtrip.mjs`: Parse text, encode to wasm bytes, decode again, and validate through the root barrel export.
- `examples/02-binary-decode-detail.mjs`: Use the binary adapter to decode a wasm payload and inspect the trailing offset detail.
- `examples/03-binary-size-helpers.mjs`: Call the signed and unsigned LEB128 size helpers from the binary package.
- `examples/04-cli-parse-help.mjs`: Parse CLI flags, show the parse result, and resolve pass and trap-mode settings.
- `examples/05-cli-schema-and-paths.mjs`: Inspect the CLI config schema and use the path, glob, and format inference helpers.
- `examples/06-cmd-help-and-version.mjs`: Read the packaged CLI help text and version banner from the cmd bridge.
- `examples/07-cmd-run-with-adapter.mjs`: Run the CLI with a custom in-memory CmdIO adapter and capture the help text.
- `examples/08-cmd-run-filesystem.mjs`: Run the CLI against a temporary .wat file using the default host-backed filesystem integration.
- `examples/09-cmd-differential-validation.mjs`: Validate a wasm binary with the internal validator and custom external adapter hooks.
- `examples/10-cmd-persist-fuzz-report.mjs`: Persist a fuzz failure report through the JS persistence hooks without touching the real filesystem.
- `examples/11-passes-optimize-module.mjs`: Build an ordered manual optimization pipeline and append explicit pass constructors.
- `examples/12-wast-module-roundtrip.mjs`: Parse a WAST module AST and print it back to canonical WAST text.
- `examples/13-wast-script-roundtrip.mjs`: Parse a WAST script and print the normalized script text.
- `examples/14-wast-spec-suite.mjs`: Run the in-memory WAST spec harness and print the summary report.

## Modules

- `binary`: binary.js exposes the public JS adapter for jtenner/starshine/binary.
- `cli`: cli.js exposes the public JS adapter for jtenner/starshine/cli.
- `cmd`: cmd.js exposes the public JS adapter for jtenner/starshine/cmd.
- `ir`: ir.js exposes the public JS adapter for jtenner/starshine/ir.
- `lib`: lib.js exposes the public JS adapter for jtenner/starshine/lib.
- `passes`: passes.js exposes the public JS adapter for jtenner/starshine/passes.
- `transformer`: transformer.js exposes the public JS adapter for jtenner/starshine/transformer.
- `validate`: validate.js exposes the public JS adapter for jtenner/starshine/validate.
- `wast`: wast.js exposes the public JS adapter for jtenner/starshine/wast.
- `wat`: wat.js exposes the public JS adapter for jtenner/starshine/wat.

## Public API

### binary

Import directly with `import * as binary from '@jtenner/starshine/binary';` or from the root barrel.

- `decodeModule(arg0: Uint8Array): StarshineResult<Module, DecodeError>`
  Decode module.
- `decodeModuleWithDetail(arg0: Uint8Array, arg1: number): StarshineResult<[Module, number], ModuleDecodeErrorDetail>`
  Decode module with detail.
- `encodeModule(arg0: Module): StarshineResult<Uint8Array, EncodeError>`
  Encode module.
- `sizeSigned(arg0: bigint, arg1: number): StarshineResult<number, BinaryEncodeError>`
  Call sizeSigned.
- `sizeUnsigned(arg0: bigint, arg1: number): StarshineResult<number, BinaryEncodeError>`
  Call sizeUnsigned.

Type namespace `BinaryDecodeError`
- `BinaryDecodeError.show(value: BinaryDecodeError): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `BinaryEncodeError`
- `BinaryEncodeError.show(value: BinaryEncodeError): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `DecodeError`
- `DecodeError.show(value: DecodeError): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `EncodeError`
- `EncodeError.show(value: EncodeError): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ModuleDecodeErrorDetail`
- `ModuleDecodeErrorDetail.show(value: ModuleDecodeErrorDetail): string`
  Format the value with its MoonBit `Show` implementation.

### cli

Import directly with `import * as cli from '@jtenner/starshine/cli';` or from the root barrel.

Constants:
- `defaultConfigPath: String`

- `cliConfigSchemaJson(): string`
  Call cliConfigSchemaJson.
- `expandGlobs(arg0: Array<string>, arg1: Array<string>): Array<string>`
  Call expandGlobs.
- `expandGlobsWithAdapter(...args: never[]): never`
  Higher-order function parameters are not available through the wasm-gc adapter.
- `globMatch(arg0: string, arg1: string): boolean`
  Call globMatch.
- `inferInputFormat(arg0: string): CliInputFormat | null`
  Infer input format.
- `normalizeCliPath(arg0: string): string`
  Normalize cli path.
- `parseCliArgs(arg0: Array<string>, starshineInput?: string | null): StarshineResult<CliParseResult, CliParseError>`
  Parse cli args.
- `parseStarshineInputEnv(arg0: string | null): Array<string>`
  Parse starshine input env.
- `resolvePassFlags(arg0: CliParseResult): Array<string>`
  Resolve pass flags.
- `resolveTrapsNeverHappen(arg0: CliParseResult, defaultArg?: boolean): boolean`
  Resolve traps never happen.

Type namespace `CliInputFormat`
- `CliInputFormat.wasm(): CliInputFormat`
  Call CliInputFormat.wasm.
- `CliInputFormat.wast(): CliInputFormat`
  Call CliInputFormat.wast.
- `CliInputFormat.wat(): CliInputFormat`
  Call CliInputFormat.wat.
- `CliInputFormat.show(value: CliInputFormat): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `CliOptimizationFlag`
- `CliOptimizationFlag.olevel(arg0: number, arg1: boolean): CliOptimizationFlag`
  Call CliOptimizationFlag.olevel.
- `CliOptimizationFlag.optimize(): CliOptimizationFlag`
  Call CliOptimizationFlag.optimize.
- `CliOptimizationFlag.shrink(): CliOptimizationFlag`
  Call CliOptimizationFlag.shrink.
- `CliOptimizationFlag.show(value: CliOptimizationFlag): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `CliOutputTarget`
- `CliOutputTarget.dir(arg0: string): CliOutputTarget`
  Call CliOutputTarget.dir.
- `CliOutputTarget.file(arg0: string): CliOutputTarget`
  Call CliOutputTarget.file.
- `CliOutputTarget.stdout(): CliOutputTarget`
  Call CliOutputTarget.stdout.
- `CliOutputTarget.show(value: CliOutputTarget): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `CliParseError`
- `CliParseError.invalidInputFormat(arg0: string): CliParseError`
  Call CliParseError.invalidInputFormat.
- `CliParseError.invalidLongFlag(arg0: string): CliParseError`
  Call CliParseError.invalidLongFlag.
- `CliParseError.invalidOptimizationFlag(arg0: string): CliParseError`
  Call CliParseError.invalidOptimizationFlag.
- `CliParseError.invalidTrapMode(arg0: string): CliParseError`
  Call CliParseError.invalidTrapMode.
- `CliParseError.missingFlagValue(arg0: string): CliParseError`
  Call CliParseError.missingFlagValue.
- `CliParseError.stdinNeedsFormat(): CliParseError`
  Call CliParseError.stdinNeedsFormat.
- `CliParseError.unexpectedFlagValue(arg0: string): CliParseError`
  Call CliParseError.unexpectedFlagValue.
- `CliParseError.unknownShortFlag(arg0: number): CliParseError`
  Call CliParseError.unknownShortFlag.
- `CliParseError.show(value: CliParseError): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `CliParseResult`
- `CliParseResult.new(configPath?: string | null, inputGlobs?: Array<string>, helpRequested?: boolean, versionRequested?: boolean, readStdin?: boolean, inputFormat?: CliInputFormat | null, outputTargets?: Array<CliOutputTarget>, passFlags?: Array<string>, optimizeFlags?: Array<CliOptimizationFlag>, trapMode?: TrapMode | null, monomorphizeMinBenefit?: number | null, lowMemoryUnused?: boolean | null, lowMemoryBound?: bigint | null): CliParseResult`
  Create a CliParseResult value.
- `CliParseResult.show(value: CliParseResult): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TrapMode`
- `TrapMode.allow(): TrapMode`
  Call TrapMode.allow.
- `TrapMode.never(): TrapMode`
  Call TrapMode.never.
- `TrapMode.show(value: TrapMode): string`
  Format the value with its MoonBit `Show` implementation.

### cmd

Import directly with `import * as cmd from '@jtenner/starshine/cmd';` or from the root barrel.

This module uses a hand-authored Node bridge for callback-backed APIs, filesystem/process integration, and native differential validation tools.

- `cmdHelpText(): string`
  Return the CLI help text.
- `cmdVersionText(): string`
  Return the CLI version banner.
- `differentialValidateWasm(bytes: Uint8Array, adapters?: DifferentialAdapters): StarshineResult<DifferentialValidationReport, string>`
  Validate a wasm binary with the internal validator and optional external tool adapters.
- `minimizeFuzzPasses(passes: Array<string>, reproduces: (passes: Array<string>) => boolean): Array<string>`
  Minimize a reproducing pass list by repeatedly invoking the provided predicate.
- `nativeDifferentialToolsAvailable(): [boolean, boolean]`
  Report whether `wasm-tools validate` and `wasm-validate` are available on the host PATH.
- `persistFuzzFailureReport(report: FuzzFailureReport, io: FuzzFailurePersistIO, corpusDir?: string): StarshineResult<[string, string | null], string>`
  Write a fuzz failure report and optional wasm payload into a corpus directory.
- `runCmd(args: Array<string>): StarshineResult<CmdRunSummary, CmdError>`
  Run the Starshine CLI with the default host-backed I/O adapter.
- `runCmdExitCode(args: Array<string>): number`
  Run the CLI and return only the exit code.
- `runCmdExitCodeWithAdapter(args: Array<string>, io: CmdIO, configJson?: string | null): number`
  Run the CLI with a custom adapter and return only the exit code.
- `runCmdWithAdapter(args: Array<string>, io: CmdIO, configJson?: string | null): StarshineResult<CmdRunSummary, CmdError>`
  Run the CLI with an explicit host adapter for filesystem, encoding, stdout, and stderr operations.
- `runWasmSmithFuzzHarness(validTarget: number, seed?: bigint, optimizePasses?: Array<ModulePass>, optimizePassNames?: Array<string> | null, differentialAdapters?: DifferentialAdapters | null, differentialEvery?: number, onFailure?: ((report: FuzzFailureReport) => StarshineResult<void, string>) | null): StarshineResult<WasmSmithFuzzStats, string>`
  Run the wasm-smith fuzz harness with optional pass scheduling, differential validation, and failure persistence hooks.
- `verifyReadmeApiSignatures(text: string, signatures: Array<[string, string]>): StarshineResult<void, string>`
  Verify that README text contains every required API signature marker.
- `verifyReadmeApiSignaturesWithRequiredBlocks(text: string, signatures: Array<[string, string]>, requiredBlocks: Array<string>): StarshineResult<void, string>`
  Verify README signatures and enforce additional required marker blocks.

Type namespace `CmdEncodeError`
- `CmdEncodeError.adapter(message: string): CmdEncodeError`
  Create an adapter-backed encoding error.
- `CmdEncodeError.encode(value: EncodeError): CmdEncodeError`
  Wrap a binary encoder error.
- `CmdEncodeError.show(value: CmdEncodeError): string`
  Format the value with its JS display string.

Type namespace `CmdError`
- `CmdError.ambiguousOutputFile(path: string): CmdError`
  Create an ambiguous output target error.
- `CmdError.unknownPassFlag(flag: string): CmdError`
  Create an unknown pass flag error.
- `CmdError.show(value: CmdError): string`
  Format the value with its JS display string.

Type namespace `CmdIO`
- `CmdIO.new(getEnv?: (name: string) => string | null, fileExists?: (path: string) => boolean, readFile?: (path: string) => StarshineResult<Uint8Array, string>, encodeModule?: (mod: Module) => StarshineResult<Uint8Array, CmdEncodeError>, writeFile?: (path: string, bytes: Uint8Array) => StarshineResult<void, string>, writeStdout?: (bytes: Uint8Array) => StarshineResult<void, string>, writeStderr?: (bytes: Uint8Array) => StarshineResult<void, string>, listCandidates?: () => Array<string>, lowerTextModule?: (path: string, format: CliInputFormat, bytes: Uint8Array) => StarshineResult<Uint8Array, string>): CmdIO`
  Create a custom CLI host adapter.

Type namespace `CmdRunSummary`
- `CmdRunSummary.new(inputFiles?: Array<string>, outputFiles?: Array<string>, resolvedPasses?: Array<string>, optimizeLevel?: number, shrinkLevel?: number, trapsNeverHappen?: boolean, monomorphizeMinBenefit?: number, lowMemoryUnused?: boolean, lowMemoryBound?: bigint): CmdRunSummary`
  Create a command run summary value.
- `CmdRunSummary.show(value: CmdRunSummary): string`
  Format the value with its JS display string.

Type namespace `DifferentialAdapters`
- `DifferentialAdapters.new(wasmToolsValidate?: (bytes: Uint8Array) => StarshineResult<boolean, string>, binaryenValidate?: (bytes: Uint8Array) => StarshineResult<boolean, string>): DifferentialAdapters`
  Create adapters for external validation tools.

Type namespace `DifferentialValidationReport`
- `DifferentialValidationReport.show(value: DifferentialValidationReport): string`
  Format the value with its JS display string.

Type namespace `FuzzFailurePersistIO`
- `FuzzFailurePersistIO.new(ensureDir?: (path: string) => StarshineResult<void, string>, writeFile?: (path: string, bytes: Uint8Array) => StarshineResult<void, string>): FuzzFailurePersistIO`
  Create persistence hooks for minimized fuzz failures.

Type namespace `FuzzFailureReport`
- `FuzzFailureReport.new(seed: bigint, attempt: number, generatedValid: number, stage: string, message: string, optimizePasses?: Array<string>, minimizedPasses?: Array<string>, wasm?: Uint8Array | null): FuzzFailureReport`
  Create a fuzz failure report value.
- `FuzzFailureReport.show(value: FuzzFailureReport): string`
  Format the value with its JS display string.

Type namespace `ReadmeApiVerifyBlock`
- `ReadmeApiVerifyBlock.show(value: ReadmeApiVerifyBlock): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `WasmSmithFuzzStats`
- `WasmSmithFuzzStats.new(attempts?: number, generatedValid?: number, generatedInvalid?: number, pipelineValidated?: number, optimized?: number, roundtripped?: number, differentialChecked?: number): WasmSmithFuzzStats`
  Create a fuzz harness statistics value.
- `WasmSmithFuzzStats.show(value: WasmSmithFuzzStats): string`
  Format the value with its JS display string.

### ir

Import directly with `import * as ir from '@jtenner/starshine/ir';` or from the root barrel.

- `compatIsF32Nan(arg0: number): boolean`
  Call compatIsF32Nan.
- `compatIsF64Nan(arg0: number): boolean`
  Call compatIsF64Nan.
- `compatIsF64NonFinite(arg0: number): boolean`
  Call compatIsF64NonFinite.
- `compatTruncF64ToI64S(arg0: number): bigint | null`
  Convert values with compatTruncF64ToI64S.
- `compatTruncF64ToI64U(arg0: number): bigint | null`
  Convert values with compatTruncF64ToI64U.
- `inferSsaTypes(arg0: SSACFG, arg1: TypeContext): SSATypeInfo`
  Infer ssa types.
- `runGvn(arg0: SSACFG, arg1: OpaqueHandle<"Map[BlockId, BlockId]">): SSACFG`
  Run gvn.

Type namespace `BasicBlock`
- `BasicBlock.show(value: BasicBlock): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `BlockId`
- `BlockId.inner(arg0: BlockId): number`
  Return the wrapped inner value from BlockId.
- `BlockId.show(value: BlockId): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `CFG`
- `CFG.block(arg0: CFG, arg1: BlockId): BasicBlock | null`
  Call CFG.block.
- `CFG.build(arg0: TExpr): CFG`
  Call CFG.build.
- `CFG.dominanceFrontier(arg0: CFG): OpaqueHandle<"Map[BlockId, @set.Set[BlockId]]">`
  Call CFG.dominanceFrontier.
- `CFG.dominates(arg0: CFG, arg1: BlockId, arg2: BlockId): boolean`
  Call CFG.dominates.
- `CFG.dominators(arg0: CFG): OpaqueHandle<"Map[BlockId, BlockId]">`
  Call CFG.dominators.
- `CFG.entry(arg0: CFG): BlockId`
  Call CFG.entry.
- `CFG.predecessors(arg0: CFG, arg1: BlockId): Array<BlockId>`
  Call CFG.predecessors.
- `CFG.strictDominates(arg0: CFG, arg1: BlockId, arg2: BlockId): boolean`
  Call CFG.strictDominates.
- `CFG.successors(arg0: CFG, arg1: BlockId): Array<BlockId>`
  Call CFG.successors.
- `CFG.toSsa(arg0: CFG, arg1: OpaqueHandle<"Map[BlockId, BlockId]">, arg2: OpaqueHandle<"Map[BlockId, @set.Set[BlockId]]">, arg3: number): SSACFG`
  Call CFG.toSsa.
- `CFG.validate(arg0: CFG): StarshineResult<void, string>`
  Call CFG.validate.
- `CFG.show(value: CFG): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `IRContext`
- `IRContext.applyGvn(arg0: IRContext): void`
  Call IRContext.applyGvn.
- `IRContext.applySsaOptimize(arg0: IRContext): void`
  Call IRContext.applySsaOptimize.
- `IRContext.cfgDirty(arg0: IRContext): void`
  Call IRContext.cfgDirty.
- `IRContext.getCfg(arg0: IRContext): CFG`
  Read data with IRContext.getCfg.
- `IRContext.getGvn(arg0: IRContext): SSACFG`
  Read data with IRContext.getGvn.
- `IRContext.getLiveness(arg0: IRContext): LivenessInfo`
  Read data with IRContext.getLiveness.
- `IRContext.getLocalGraph(arg0: IRContext): LocalGraph`
  Read data with IRContext.getLocalGraph.
- `IRContext.getMod(arg0: IRContext): Module | null`
  Read data with IRContext.getMod.
- `IRContext.getSsa(arg0: IRContext): SSACFG`
  Read data with IRContext.getSsa.
- `IRContext.getTypeCtx(arg0: IRContext): StarshineResult<TypeContext, string>`
  Read data with IRContext.getTypeCtx.
- `IRContext.getTypes(arg0: IRContext): SSATypeInfo | null`
  Read data with IRContext.getTypes.
- `IRContext.getUsedef(arg0: IRContext): UseDefInfo`
  Read data with IRContext.getUsedef.
- `IRContext.gvnDirty(arg0: IRContext): void`
  Call IRContext.gvnDirty.
- `IRContext.livenessDirty(arg0: IRContext): void`
  Call IRContext.livenessDirty.
- `IRContext.localGraphDirty(arg0: IRContext): void`
  Call IRContext.localGraphDirty.
- `IRContext.lowerToCfg(arg0: IRContext): CFG`
  Convert values with IRContext.lowerToCfg.
- `IRContext.new(): IRContext`
  Create a IRContext value.
- `IRContext.optimizeBodyWithSsa(arg0: IRContext): TExpr | null`
  Call IRContext.optimizeBodyWithSsa.
- `IRContext.optimizeBodyWithSsaTrace(...args: never[]): never`
  Higher-order function parameters are not available through the wasm-gc adapter.
- `IRContext.setBody(arg0: IRContext, arg1: TExpr): void`
  Call IRContext.setBody.
- `IRContext.setLocals(arg0: IRContext, arg1: Array<ValType>): void`
  Call IRContext.setLocals.
- `IRContext.setMod(arg0: IRContext, arg1: Module): void`
  Call IRContext.setMod.
- `IRContext.ssaDirty(arg0: IRContext): void`
  Call IRContext.ssaDirty.
- `IRContext.typesDirty(arg0: IRContext): void`
  Call IRContext.typesDirty.
- `IRContext.usedefDirty(arg0: IRContext): void`
  Call IRContext.usedefDirty.
- `IRContext.validate(arg0: IRContext): StarshineResult<void, string>`
  Call IRContext.validate.

Type namespace `LivenessInfo`
- `LivenessInfo.getLiveIn(arg0: LivenessInfo, arg1: BlockId): OpaqueHandle<"@set.Set[SSAValue]">`
  Read data with LivenessInfo.getLiveIn.
- `LivenessInfo.getLiveOut(arg0: LivenessInfo, arg1: BlockId): OpaqueHandle<"@set.Set[SSAValue]">`
  Read data with LivenessInfo.getLiveOut.
- `LivenessInfo.isLiveIn(arg0: LivenessInfo, arg1: BlockId, arg2: SSAValue): boolean`
  Call LivenessInfo.isLiveIn.
- `LivenessInfo.isLiveOut(arg0: LivenessInfo, arg1: BlockId, arg2: SSAValue): boolean`
  Call LivenessInfo.isLiveOut.

Type namespace `LocalGraph`
- `LocalGraph.getSets(arg0: LocalGraph, arg1: number): OpaqueHandle<"@set.Set[LocalSet]">`
  Read data with LocalGraph.getSets.
- `LocalGraph.new(arg0: Array<TInstr>): LocalGraph`
  Create a LocalGraph value.

Type namespace `PhiNode`
- `PhiNode.show(value: PhiNode): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `SSABlock`
- `SSABlock.show(value: SSABlock): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `SSACFG`
- `SSACFG.buildUseDef(arg0: SSACFG): UseDefInfo`
  Call SSACFG.buildUseDef.
- `SSACFG.computeLiveness(arg0: SSACFG): LivenessInfo`
  Call SSACFG.computeLiveness.
- `SSACFG.optimize(arg0: SSACFG): SSACFG`
  Call SSACFG.optimize.
- `SSACFG.splitCriticalEdges(arg0: SSACFG): SSACFG`
  Call SSACFG.splitCriticalEdges.
- `SSACFG.toCfg(arg0: SSACFG, arg1: number): CFG`
  Call SSACFG.toCfg.
- `SSACFG.show(value: SSACFG): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `SSAInstr`
- `SSAInstr.show(value: SSAInstr): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `SSALiteral`
- `SSALiteral.show(value: SSALiteral): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `SSAOp`
- `SSAOp.show(value: SSAOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `SSATerminator`
- `SSATerminator.show(value: SSATerminator): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `SSATypeInfo`
- `SSATypeInfo.get(arg0: SSATypeInfo, arg1: SSAValue): ValType | null`
  Call SSATypeInfo.get.

Type namespace `SSAValue`
- `SSAValue.inner(arg0: SSAValue): number`
  Return the wrapped inner value from SSAValue.
- `SSAValue.show(value: SSAValue): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `SplatOp`
- `SplatOp.show(value: SplatOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Terminator`
- `Terminator.show(value: Terminator): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TypeContext`
- `TypeContext.empty(): TypeContext`
  Call TypeContext.empty.
- `TypeContext.fromModule(arg0: Module, arg1: Array<ValType>): TypeContext`
  Call TypeContext.fromModule.

Type namespace `UseDefInfo`
- `UseDefInfo.getDef(arg0: UseDefInfo, arg1: SSAValue): [BlockId, SSADef] | null`
  Read data with UseDefInfo.getDef.
- `UseDefInfo.getUses(arg0: UseDefInfo, arg1: SSAValue): Array<SSAUse>`
  Read data with UseDefInfo.getUses.
- `UseDefInfo.isDead(arg0: UseDefInfo, arg1: SSAValue): boolean`
  Call UseDefInfo.isDead.

### lib

Import directly with `import * as lib from '@jtenner/starshine/lib';` or from the root barrel.

- `applyPrettyContext(arg0: string, arg1: PrettyPrintContext): string`
  Call applyPrettyContext.
- `arrayCompType(arg0: FieldType): CompType`
  Call arrayCompType.
- `arrayOfArbitrary(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `compTypeSubType(arg0: CompType): SubType`
  Call compTypeSubType.
- `equals(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `expandLocals(arg0: Array<Locals>): StarshineResult<Array<ValType>, string>`
  Call expandLocals.
- `funcCompType(arg0: Array<ValType>, arg1: Array<ValType>): CompType`
  Call funcCompType.
- `funcExternIdx(arg0: FuncIdx): ExternIdx`
  Call funcExternIdx.
- `funcExternType(arg0: TypeIdx): ExternType`
  Call funcExternType.
- `funcIdx(arg0: number): FuncIdx`
  Call funcIdx.
- `getStructField(arg0: Array<FieldType>, arg1: U32): StarshineResult<FieldType, string>`
  Read data with getStructField.
- `globalExternIdx(arg0: GlobalIdx): ExternIdx`
  Call globalExternIdx.
- `globalExternType(arg0: GlobalType): ExternType`
  Call globalExternType.
- `globalIdx(arg0: number): GlobalIdx`
  Call globalIdx.
- `globalType(arg0: ValType, arg1: boolean): GlobalType`
  Call globalType.
- `groupRecType(arg0: Array<SubType>): RecType`
  Call groupRecType.
- `hasDefault(arg0: ValType): boolean`
  Check default.
- `inspectDebug(...args: never[]): never`
  Exports with `raise` effects are not available through the wasm-gc adapter.
- `inspectPrettyPrint(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `memExternIdx(arg0: MemIdx): ExternIdx`
  Call memExternIdx.
- `memExternType(arg0: MemType): ExternType`
  Call memExternType.
- `memType(arg0: Limits): MemType`
  Call memType.
- `minAddr(arg0: Limits, arg1: Limits): Limits`
  Call minAddr.
- `minAddrValtype(arg0: Limits, arg1: Limits): ValType`
  Call minAddrValtype.
- `recIdx(arg0: number): TypeIdx`
  Call recIdx.
- `singleRecType(arg0: SubType): RecType`
  Call singleRecType.
- `structCompType(arg0: Array<FieldType>): CompType`
  Call structCompType.
- `subType(arg0: boolean, arg1: Array<TypeIdx>, arg2: CompType): SubType`
  Call subType.
- `tableExternIdx(arg0: TableIdx): ExternIdx`
  Call tableExternIdx.
- `tableExternType(arg0: TableType): ExternType`
  Call tableExternType.
- `tableIdx(arg0: number): TableIdx`
  Call tableIdx.
- `tagExternIdx(arg0: TagIdx): ExternIdx`
  Call tagExternIdx.
- `tagExternType(arg0: TagType): ExternType`
  Call tagExternType.
- `tagType(arg0: TypeIdx): TagType`
  Call tagType.
- `tlocalsToLocals(arg0: Array<ValType>): Array<Locals>`
  Convert values with tlocalsToLocals.

Type namespace `AbsHeapType`
- `AbsHeapType.any(): AbsHeapType`
  Call AbsHeapType.any.
- `AbsHeapType.array(): AbsHeapType`
  Call AbsHeapType.array.
- `AbsHeapType.eq(): AbsHeapType`
  Call AbsHeapType.eq.
- `AbsHeapType.exn(): AbsHeapType`
  Call AbsHeapType.exn.
- `AbsHeapType.extern(): AbsHeapType`
  Call AbsHeapType.extern.
- `AbsHeapType.func(): AbsHeapType`
  Call AbsHeapType.func.
- `AbsHeapType.i31(): AbsHeapType`
  Call AbsHeapType.i31.
- `AbsHeapType.noExn(): AbsHeapType`
  Call AbsHeapType.noExn.
- `AbsHeapType.noExtern(): AbsHeapType`
  Call AbsHeapType.noExtern.
- `AbsHeapType.noFunc(): AbsHeapType`
  Call AbsHeapType.noFunc.
- `AbsHeapType.none(): AbsHeapType`
  Call AbsHeapType.none.
- `AbsHeapType.struct(): AbsHeapType`
  Call AbsHeapType.struct.
- `AbsHeapType.show(value: AbsHeapType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `AtomicCmpxchgOp`
- `AtomicCmpxchgOp.i32(): AtomicCmpxchgOp`
  Call AtomicCmpxchgOp.i32.
- `AtomicCmpxchgOp.i3216U(): AtomicCmpxchgOp`
  Call AtomicCmpxchgOp.i3216U.
- `AtomicCmpxchgOp.i328U(): AtomicCmpxchgOp`
  Call AtomicCmpxchgOp.i328U.
- `AtomicCmpxchgOp.i64(): AtomicCmpxchgOp`
  Call AtomicCmpxchgOp.i64.
- `AtomicCmpxchgOp.i6416U(): AtomicCmpxchgOp`
  Call AtomicCmpxchgOp.i6416U.
- `AtomicCmpxchgOp.i6432U(): AtomicCmpxchgOp`
  Call AtomicCmpxchgOp.i6432U.
- `AtomicCmpxchgOp.i648U(): AtomicCmpxchgOp`
  Call AtomicCmpxchgOp.i648U.
- `AtomicCmpxchgOp.show(value: AtomicCmpxchgOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `AtomicRmwOp`
- `AtomicRmwOp.i3216AddU(): AtomicRmwOp`
  Call AtomicRmwOp.i3216AddU.
- `AtomicRmwOp.i3216AndU(): AtomicRmwOp`
  Call AtomicRmwOp.i3216AndU.
- `AtomicRmwOp.i3216OrU(): AtomicRmwOp`
  Call AtomicRmwOp.i3216OrU.
- `AtomicRmwOp.i3216SubU(): AtomicRmwOp`
  Call AtomicRmwOp.i3216SubU.
- `AtomicRmwOp.i3216XchgU(): AtomicRmwOp`
  Call AtomicRmwOp.i3216XchgU.
- `AtomicRmwOp.i3216XorU(): AtomicRmwOp`
  Call AtomicRmwOp.i3216XorU.
- `AtomicRmwOp.i328AddU(): AtomicRmwOp`
  Call AtomicRmwOp.i328AddU.
- `AtomicRmwOp.i328AndU(): AtomicRmwOp`
  Call AtomicRmwOp.i328AndU.
- `AtomicRmwOp.i328OrU(): AtomicRmwOp`
  Call AtomicRmwOp.i328OrU.
- `AtomicRmwOp.i328SubU(): AtomicRmwOp`
  Call AtomicRmwOp.i328SubU.
- `AtomicRmwOp.i328XchgU(): AtomicRmwOp`
  Call AtomicRmwOp.i328XchgU.
- `AtomicRmwOp.i328XorU(): AtomicRmwOp`
  Call AtomicRmwOp.i328XorU.
- `AtomicRmwOp.i32Add(): AtomicRmwOp`
  Call AtomicRmwOp.i32Add.
- `AtomicRmwOp.i32And(): AtomicRmwOp`
  Call AtomicRmwOp.i32And.
- `AtomicRmwOp.i32Or(): AtomicRmwOp`
  Call AtomicRmwOp.i32Or.
- `AtomicRmwOp.i32Sub(): AtomicRmwOp`
  Call AtomicRmwOp.i32Sub.
- `AtomicRmwOp.i32Xchg(): AtomicRmwOp`
  Call AtomicRmwOp.i32Xchg.
- `AtomicRmwOp.i32Xor(): AtomicRmwOp`
  Call AtomicRmwOp.i32Xor.
- `AtomicRmwOp.i6416AddU(): AtomicRmwOp`
  Call AtomicRmwOp.i6416AddU.
- `AtomicRmwOp.i6416AndU(): AtomicRmwOp`
  Call AtomicRmwOp.i6416AndU.
- `AtomicRmwOp.i6416OrU(): AtomicRmwOp`
  Call AtomicRmwOp.i6416OrU.
- `AtomicRmwOp.i6416SubU(): AtomicRmwOp`
  Call AtomicRmwOp.i6416SubU.
- `AtomicRmwOp.i6416XchgU(): AtomicRmwOp`
  Call AtomicRmwOp.i6416XchgU.
- `AtomicRmwOp.i6416XorU(): AtomicRmwOp`
  Call AtomicRmwOp.i6416XorU.
- `AtomicRmwOp.i6432AddU(): AtomicRmwOp`
  Call AtomicRmwOp.i6432AddU.
- `AtomicRmwOp.i6432AndU(): AtomicRmwOp`
  Call AtomicRmwOp.i6432AndU.
- `AtomicRmwOp.i6432OrU(): AtomicRmwOp`
  Call AtomicRmwOp.i6432OrU.
- `AtomicRmwOp.i6432SubU(): AtomicRmwOp`
  Call AtomicRmwOp.i6432SubU.
- `AtomicRmwOp.i6432XchgU(): AtomicRmwOp`
  Call AtomicRmwOp.i6432XchgU.
- `AtomicRmwOp.i6432XorU(): AtomicRmwOp`
  Call AtomicRmwOp.i6432XorU.
- `AtomicRmwOp.i648AddU(): AtomicRmwOp`
  Call AtomicRmwOp.i648AddU.
- `AtomicRmwOp.i648AndU(): AtomicRmwOp`
  Call AtomicRmwOp.i648AndU.
- `AtomicRmwOp.i648OrU(): AtomicRmwOp`
  Call AtomicRmwOp.i648OrU.
- `AtomicRmwOp.i648SubU(): AtomicRmwOp`
  Call AtomicRmwOp.i648SubU.
- `AtomicRmwOp.i648XchgU(): AtomicRmwOp`
  Call AtomicRmwOp.i648XchgU.
- `AtomicRmwOp.i648XorU(): AtomicRmwOp`
  Call AtomicRmwOp.i648XorU.
- `AtomicRmwOp.i64Add(): AtomicRmwOp`
  Call AtomicRmwOp.i64Add.
- `AtomicRmwOp.i64And(): AtomicRmwOp`
  Call AtomicRmwOp.i64And.
- `AtomicRmwOp.i64Or(): AtomicRmwOp`
  Call AtomicRmwOp.i64Or.
- `AtomicRmwOp.i64Sub(): AtomicRmwOp`
  Call AtomicRmwOp.i64Sub.
- `AtomicRmwOp.i64Xchg(): AtomicRmwOp`
  Call AtomicRmwOp.i64Xchg.
- `AtomicRmwOp.i64Xor(): AtomicRmwOp`
  Call AtomicRmwOp.i64Xor.
- `AtomicRmwOp.show(value: AtomicRmwOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `BinaryOp`
- `BinaryOp.f32Add(): BinaryOp`
  Call BinaryOp.f32Add.
- `BinaryOp.f32Copysign(): BinaryOp`
  Call BinaryOp.f32Copysign.
- `BinaryOp.f32Div(): BinaryOp`
  Call BinaryOp.f32Div.
- `BinaryOp.f32Eq(): BinaryOp`
  Call BinaryOp.f32Eq.
- `BinaryOp.f32Ge(): BinaryOp`
  Call BinaryOp.f32Ge.
- `BinaryOp.f32Gt(): BinaryOp`
  Call BinaryOp.f32Gt.
- `BinaryOp.f32Le(): BinaryOp`
  Call BinaryOp.f32Le.
- `BinaryOp.f32Lt(): BinaryOp`
  Call BinaryOp.f32Lt.
- `BinaryOp.f32Max(): BinaryOp`
  Call BinaryOp.f32Max.
- `BinaryOp.f32Min(): BinaryOp`
  Call BinaryOp.f32Min.
- `BinaryOp.f32Mul(): BinaryOp`
  Call BinaryOp.f32Mul.
- `BinaryOp.f32Ne(): BinaryOp`
  Call BinaryOp.f32Ne.
- `BinaryOp.f32Sub(): BinaryOp`
  Call BinaryOp.f32Sub.
- `BinaryOp.f32x4Add(): BinaryOp`
  Call BinaryOp.f32x4Add.
- `BinaryOp.f32x4Div(): BinaryOp`
  Call BinaryOp.f32x4Div.
- `BinaryOp.f32x4Eq(): BinaryOp`
  Call BinaryOp.f32x4Eq.
- `BinaryOp.f32x4Ge(): BinaryOp`
  Call BinaryOp.f32x4Ge.
- `BinaryOp.f32x4Gt(): BinaryOp`
  Call BinaryOp.f32x4Gt.
- `BinaryOp.f32x4Le(): BinaryOp`
  Call BinaryOp.f32x4Le.
- `BinaryOp.f32x4Lt(): BinaryOp`
  Call BinaryOp.f32x4Lt.
- `BinaryOp.f32x4Max(): BinaryOp`
  Call BinaryOp.f32x4Max.
- `BinaryOp.f32x4Min(): BinaryOp`
  Call BinaryOp.f32x4Min.
- `BinaryOp.f32x4Mul(): BinaryOp`
  Call BinaryOp.f32x4Mul.
- `BinaryOp.f32x4Ne(): BinaryOp`
  Call BinaryOp.f32x4Ne.
- `BinaryOp.f32x4Pmax(): BinaryOp`
  Call BinaryOp.f32x4Pmax.
- `BinaryOp.f32x4Pmin(): BinaryOp`
  Call BinaryOp.f32x4Pmin.
- `BinaryOp.f32x4RelaxedMax(): BinaryOp`
  Call BinaryOp.f32x4RelaxedMax.
- `BinaryOp.f32x4RelaxedMin(): BinaryOp`
  Call BinaryOp.f32x4RelaxedMin.
- `BinaryOp.f32x4Sub(): BinaryOp`
  Call BinaryOp.f32x4Sub.
- `BinaryOp.f64Add(): BinaryOp`
  Call BinaryOp.f64Add.
- `BinaryOp.f64Copysign(): BinaryOp`
  Call BinaryOp.f64Copysign.
- `BinaryOp.f64Div(): BinaryOp`
  Call BinaryOp.f64Div.
- `BinaryOp.f64Eq(): BinaryOp`
  Call BinaryOp.f64Eq.
- `BinaryOp.f64Ge(): BinaryOp`
  Call BinaryOp.f64Ge.
- `BinaryOp.f64Gt(): BinaryOp`
  Call BinaryOp.f64Gt.
- `BinaryOp.f64Le(): BinaryOp`
  Call BinaryOp.f64Le.
- `BinaryOp.f64Lt(): BinaryOp`
  Call BinaryOp.f64Lt.
- `BinaryOp.f64Max(): BinaryOp`
  Call BinaryOp.f64Max.
- `BinaryOp.f64Min(): BinaryOp`
  Call BinaryOp.f64Min.
- `BinaryOp.f64Mul(): BinaryOp`
  Call BinaryOp.f64Mul.
- `BinaryOp.f64Ne(): BinaryOp`
  Call BinaryOp.f64Ne.
- `BinaryOp.f64Sub(): BinaryOp`
  Call BinaryOp.f64Sub.
- `BinaryOp.f64x2Add(): BinaryOp`
  Call BinaryOp.f64x2Add.
- `BinaryOp.f64x2Div(): BinaryOp`
  Call BinaryOp.f64x2Div.
- `BinaryOp.f64x2Eq(): BinaryOp`
  Call BinaryOp.f64x2Eq.
- `BinaryOp.f64x2Ge(): BinaryOp`
  Call BinaryOp.f64x2Ge.
- `BinaryOp.f64x2Gt(): BinaryOp`
  Call BinaryOp.f64x2Gt.
- `BinaryOp.f64x2Le(): BinaryOp`
  Call BinaryOp.f64x2Le.
- `BinaryOp.f64x2Lt(): BinaryOp`
  Call BinaryOp.f64x2Lt.
- `BinaryOp.f64x2Max(): BinaryOp`
  Call BinaryOp.f64x2Max.
- `BinaryOp.f64x2Min(): BinaryOp`
  Call BinaryOp.f64x2Min.
- `BinaryOp.f64x2Mul(): BinaryOp`
  Call BinaryOp.f64x2Mul.
- `BinaryOp.f64x2Ne(): BinaryOp`
  Call BinaryOp.f64x2Ne.
- `BinaryOp.f64x2Pmax(): BinaryOp`
  Call BinaryOp.f64x2Pmax.
- `BinaryOp.f64x2Pmin(): BinaryOp`
  Call BinaryOp.f64x2Pmin.
- `BinaryOp.f64x2RelaxedMax(): BinaryOp`
  Call BinaryOp.f64x2RelaxedMax.
- `BinaryOp.f64x2RelaxedMin(): BinaryOp`
  Call BinaryOp.f64x2RelaxedMin.
- `BinaryOp.f64x2Sub(): BinaryOp`
  Call BinaryOp.f64x2Sub.
- `BinaryOp.i16x8Add(): BinaryOp`
  Call BinaryOp.i16x8Add.
- `BinaryOp.i16x8AddSatS(): BinaryOp`
  Call BinaryOp.i16x8AddSatS.
- `BinaryOp.i16x8AddSatU(): BinaryOp`
  Call BinaryOp.i16x8AddSatU.
- `BinaryOp.i16x8AvgrU(): BinaryOp`
  Call BinaryOp.i16x8AvgrU.
- `BinaryOp.i16x8Eq(): BinaryOp`
  Call BinaryOp.i16x8Eq.
- `BinaryOp.i16x8ExtmulHighI8x16s(): BinaryOp`
  Call BinaryOp.i16x8ExtmulHighI8x16s.
- `BinaryOp.i16x8ExtmulHighI8x16u(): BinaryOp`
  Call BinaryOp.i16x8ExtmulHighI8x16u.
- `BinaryOp.i16x8ExtmulLowI8x16s(): BinaryOp`
  Call BinaryOp.i16x8ExtmulLowI8x16s.
- `BinaryOp.i16x8ExtmulLowI8x16u(): BinaryOp`
  Call BinaryOp.i16x8ExtmulLowI8x16u.
- `BinaryOp.i16x8GeS(): BinaryOp`
  Call BinaryOp.i16x8GeS.
- `BinaryOp.i16x8GeU(): BinaryOp`
  Call BinaryOp.i16x8GeU.
- `BinaryOp.i16x8GtS(): BinaryOp`
  Call BinaryOp.i16x8GtS.
- `BinaryOp.i16x8GtU(): BinaryOp`
  Call BinaryOp.i16x8GtU.
- `BinaryOp.i16x8LeS(): BinaryOp`
  Call BinaryOp.i16x8LeS.
- `BinaryOp.i16x8LeU(): BinaryOp`
  Call BinaryOp.i16x8LeU.
- `BinaryOp.i16x8LtS(): BinaryOp`
  Call BinaryOp.i16x8LtS.
- `BinaryOp.i16x8LtU(): BinaryOp`
  Call BinaryOp.i16x8LtU.
- `BinaryOp.i16x8MaxS(): BinaryOp`
  Call BinaryOp.i16x8MaxS.
- `BinaryOp.i16x8MaxU(): BinaryOp`
  Call BinaryOp.i16x8MaxU.
- `BinaryOp.i16x8MinS(): BinaryOp`
  Call BinaryOp.i16x8MinS.
- `BinaryOp.i16x8MinU(): BinaryOp`
  Call BinaryOp.i16x8MinU.
- `BinaryOp.i16x8Mul(): BinaryOp`
  Call BinaryOp.i16x8Mul.
- `BinaryOp.i16x8NarrowI32x4s(): BinaryOp`
  Call BinaryOp.i16x8NarrowI32x4s.
- `BinaryOp.i16x8NarrowI32x4u(): BinaryOp`
  Call BinaryOp.i16x8NarrowI32x4u.
- `BinaryOp.i16x8Ne(): BinaryOp`
  Call BinaryOp.i16x8Ne.
- `BinaryOp.i16x8RelaxedDotI8x16i7x16s(): BinaryOp`
  Call BinaryOp.i16x8RelaxedDotI8x16i7x16s.
- `BinaryOp.i16x8RelaxedQ15mulrS(): BinaryOp`
  Call BinaryOp.i16x8RelaxedQ15mulrS.
- `BinaryOp.i16x8Sub(): BinaryOp`
  Call BinaryOp.i16x8Sub.
- `BinaryOp.i16x8SubSatS(): BinaryOp`
  Call BinaryOp.i16x8SubSatS.
- `BinaryOp.i16x8SubSatU(): BinaryOp`
  Call BinaryOp.i16x8SubSatU.
- `BinaryOp.i16x8q15mulrSatS(): BinaryOp`
  Call BinaryOp.i16x8q15mulrSatS.
- `BinaryOp.i32Add(): BinaryOp`
  Call BinaryOp.i32Add.
- `BinaryOp.i32And(): BinaryOp`
  Call BinaryOp.i32And.
- `BinaryOp.i32DivS(): BinaryOp`
  Call BinaryOp.i32DivS.
- `BinaryOp.i32DivU(): BinaryOp`
  Call BinaryOp.i32DivU.
- `BinaryOp.i32Eq(): BinaryOp`
  Call BinaryOp.i32Eq.
- `BinaryOp.i32GeS(): BinaryOp`
  Call BinaryOp.i32GeS.
- `BinaryOp.i32GeU(): BinaryOp`
  Call BinaryOp.i32GeU.
- `BinaryOp.i32GtS(): BinaryOp`
  Call BinaryOp.i32GtS.
- `BinaryOp.i32GtU(): BinaryOp`
  Call BinaryOp.i32GtU.
- `BinaryOp.i32LeS(): BinaryOp`
  Call BinaryOp.i32LeS.
- `BinaryOp.i32LeU(): BinaryOp`
  Call BinaryOp.i32LeU.
- `BinaryOp.i32LtS(): BinaryOp`
  Call BinaryOp.i32LtS.
- `BinaryOp.i32LtU(): BinaryOp`
  Call BinaryOp.i32LtU.
- `BinaryOp.i32Mul(): BinaryOp`
  Call BinaryOp.i32Mul.
- `BinaryOp.i32Ne(): BinaryOp`
  Call BinaryOp.i32Ne.
- `BinaryOp.i32Or(): BinaryOp`
  Call BinaryOp.i32Or.
- `BinaryOp.i32RemS(): BinaryOp`
  Call BinaryOp.i32RemS.
- `BinaryOp.i32RemU(): BinaryOp`
  Call BinaryOp.i32RemU.
- `BinaryOp.i32Rotl(): BinaryOp`
  Call BinaryOp.i32Rotl.
- `BinaryOp.i32Rotr(): BinaryOp`
  Call BinaryOp.i32Rotr.
- `BinaryOp.i32Shl(): BinaryOp`
  Call BinaryOp.i32Shl.
- `BinaryOp.i32ShrS(): BinaryOp`
  Call BinaryOp.i32ShrS.
- `BinaryOp.i32ShrU(): BinaryOp`
  Call BinaryOp.i32ShrU.
- `BinaryOp.i32Sub(): BinaryOp`
  Call BinaryOp.i32Sub.
- `BinaryOp.i32Xor(): BinaryOp`
  Call BinaryOp.i32Xor.
- `BinaryOp.i32x4Add(): BinaryOp`
  Call BinaryOp.i32x4Add.
- `BinaryOp.i32x4DotI16x8s(): BinaryOp`
  Call BinaryOp.i32x4DotI16x8s.
- `BinaryOp.i32x4Eq(): BinaryOp`
  Call BinaryOp.i32x4Eq.
- `BinaryOp.i32x4ExtmulHighI16x8s(): BinaryOp`
  Call BinaryOp.i32x4ExtmulHighI16x8s.
- `BinaryOp.i32x4ExtmulHighI16x8u(): BinaryOp`
  Call BinaryOp.i32x4ExtmulHighI16x8u.
- `BinaryOp.i32x4ExtmulLowI16x8s(): BinaryOp`
  Call BinaryOp.i32x4ExtmulLowI16x8s.
- `BinaryOp.i32x4ExtmulLowI16x8u(): BinaryOp`
  Call BinaryOp.i32x4ExtmulLowI16x8u.
- `BinaryOp.i32x4GeS(): BinaryOp`
  Call BinaryOp.i32x4GeS.
- `BinaryOp.i32x4GeU(): BinaryOp`
  Call BinaryOp.i32x4GeU.
- `BinaryOp.i32x4GtS(): BinaryOp`
  Call BinaryOp.i32x4GtS.
- `BinaryOp.i32x4GtU(): BinaryOp`
  Call BinaryOp.i32x4GtU.
- `BinaryOp.i32x4LeS(): BinaryOp`
  Call BinaryOp.i32x4LeS.
- `BinaryOp.i32x4LeU(): BinaryOp`
  Call BinaryOp.i32x4LeU.
- `BinaryOp.i32x4LtS(): BinaryOp`
  Call BinaryOp.i32x4LtS.
- `BinaryOp.i32x4LtU(): BinaryOp`
  Call BinaryOp.i32x4LtU.
- `BinaryOp.i32x4MaxS(): BinaryOp`
  Call BinaryOp.i32x4MaxS.
- `BinaryOp.i32x4MaxU(): BinaryOp`
  Call BinaryOp.i32x4MaxU.
- `BinaryOp.i32x4MinS(): BinaryOp`
  Call BinaryOp.i32x4MinS.
- `BinaryOp.i32x4MinU(): BinaryOp`
  Call BinaryOp.i32x4MinU.
- `BinaryOp.i32x4Mul(): BinaryOp`
  Call BinaryOp.i32x4Mul.
- `BinaryOp.i32x4Ne(): BinaryOp`
  Call BinaryOp.i32x4Ne.
- `BinaryOp.i32x4Sub(): BinaryOp`
  Call BinaryOp.i32x4Sub.
- `BinaryOp.i64Add(): BinaryOp`
  Call BinaryOp.i64Add.
- `BinaryOp.i64And(): BinaryOp`
  Call BinaryOp.i64And.
- `BinaryOp.i64DivS(): BinaryOp`
  Call BinaryOp.i64DivS.
- `BinaryOp.i64DivU(): BinaryOp`
  Call BinaryOp.i64DivU.
- `BinaryOp.i64Eq(): BinaryOp`
  Call BinaryOp.i64Eq.
- `BinaryOp.i64GeS(): BinaryOp`
  Call BinaryOp.i64GeS.
- `BinaryOp.i64GeU(): BinaryOp`
  Call BinaryOp.i64GeU.
- `BinaryOp.i64GtS(): BinaryOp`
  Call BinaryOp.i64GtS.
- `BinaryOp.i64GtU(): BinaryOp`
  Call BinaryOp.i64GtU.
- `BinaryOp.i64LeS(): BinaryOp`
  Call BinaryOp.i64LeS.
- `BinaryOp.i64LeU(): BinaryOp`
  Call BinaryOp.i64LeU.
- `BinaryOp.i64LtS(): BinaryOp`
  Call BinaryOp.i64LtS.
- `BinaryOp.i64LtU(): BinaryOp`
  Call BinaryOp.i64LtU.
- `BinaryOp.i64Mul(): BinaryOp`
  Call BinaryOp.i64Mul.
- `BinaryOp.i64Ne(): BinaryOp`
  Call BinaryOp.i64Ne.
- `BinaryOp.i64Or(): BinaryOp`
  Call BinaryOp.i64Or.
- `BinaryOp.i64RemS(): BinaryOp`
  Call BinaryOp.i64RemS.
- `BinaryOp.i64RemU(): BinaryOp`
  Call BinaryOp.i64RemU.
- `BinaryOp.i64Rotl(): BinaryOp`
  Call BinaryOp.i64Rotl.
- `BinaryOp.i64Rotr(): BinaryOp`
  Call BinaryOp.i64Rotr.
- `BinaryOp.i64Shl(): BinaryOp`
  Call BinaryOp.i64Shl.
- `BinaryOp.i64ShrS(): BinaryOp`
  Call BinaryOp.i64ShrS.
- `BinaryOp.i64ShrU(): BinaryOp`
  Call BinaryOp.i64ShrU.
- `BinaryOp.i64Sub(): BinaryOp`
  Call BinaryOp.i64Sub.
- `BinaryOp.i64Xor(): BinaryOp`
  Call BinaryOp.i64Xor.
- `BinaryOp.i64x2Add(): BinaryOp`
  Call BinaryOp.i64x2Add.
- `BinaryOp.i64x2Eq(): BinaryOp`
  Call BinaryOp.i64x2Eq.
- `BinaryOp.i64x2ExtmulHighI32x4s(): BinaryOp`
  Call BinaryOp.i64x2ExtmulHighI32x4s.
- `BinaryOp.i64x2ExtmulHighI32x4u(): BinaryOp`
  Call BinaryOp.i64x2ExtmulHighI32x4u.
- `BinaryOp.i64x2ExtmulLowI32x4s(): BinaryOp`
  Call BinaryOp.i64x2ExtmulLowI32x4s.
- `BinaryOp.i64x2ExtmulLowI32x4u(): BinaryOp`
  Call BinaryOp.i64x2ExtmulLowI32x4u.
- `BinaryOp.i64x2GeS(): BinaryOp`
  Call BinaryOp.i64x2GeS.
- `BinaryOp.i64x2GtS(): BinaryOp`
  Call BinaryOp.i64x2GtS.
- `BinaryOp.i64x2LeS(): BinaryOp`
  Call BinaryOp.i64x2LeS.
- `BinaryOp.i64x2LtS(): BinaryOp`
  Call BinaryOp.i64x2LtS.
- `BinaryOp.i64x2Mul(): BinaryOp`
  Call BinaryOp.i64x2Mul.
- `BinaryOp.i64x2Ne(): BinaryOp`
  Call BinaryOp.i64x2Ne.
- `BinaryOp.i64x2Sub(): BinaryOp`
  Call BinaryOp.i64x2Sub.
- `BinaryOp.i8x16Add(): BinaryOp`
  Call BinaryOp.i8x16Add.
- `BinaryOp.i8x16AddSatS(): BinaryOp`
  Call BinaryOp.i8x16AddSatS.
- `BinaryOp.i8x16AddSatU(): BinaryOp`
  Call BinaryOp.i8x16AddSatU.
- `BinaryOp.i8x16AvgrU(): BinaryOp`
  Call BinaryOp.i8x16AvgrU.
- `BinaryOp.i8x16Eq(): BinaryOp`
  Call BinaryOp.i8x16Eq.
- `BinaryOp.i8x16GeS(): BinaryOp`
  Call BinaryOp.i8x16GeS.
- `BinaryOp.i8x16GeU(): BinaryOp`
  Call BinaryOp.i8x16GeU.
- `BinaryOp.i8x16GtS(): BinaryOp`
  Call BinaryOp.i8x16GtS.
- `BinaryOp.i8x16GtU(): BinaryOp`
  Call BinaryOp.i8x16GtU.
- `BinaryOp.i8x16LeS(): BinaryOp`
  Call BinaryOp.i8x16LeS.
- `BinaryOp.i8x16LeU(): BinaryOp`
  Call BinaryOp.i8x16LeU.
- `BinaryOp.i8x16LtS(): BinaryOp`
  Call BinaryOp.i8x16LtS.
- `BinaryOp.i8x16LtU(): BinaryOp`
  Call BinaryOp.i8x16LtU.
- `BinaryOp.i8x16MaxS(): BinaryOp`
  Call BinaryOp.i8x16MaxS.
- `BinaryOp.i8x16MaxU(): BinaryOp`
  Call BinaryOp.i8x16MaxU.
- `BinaryOp.i8x16MinS(): BinaryOp`
  Call BinaryOp.i8x16MinS.
- `BinaryOp.i8x16MinU(): BinaryOp`
  Call BinaryOp.i8x16MinU.
- `BinaryOp.i8x16NarrowI16x8s(): BinaryOp`
  Call BinaryOp.i8x16NarrowI16x8s.
- `BinaryOp.i8x16NarrowI16x8u(): BinaryOp`
  Call BinaryOp.i8x16NarrowI16x8u.
- `BinaryOp.i8x16Ne(): BinaryOp`
  Call BinaryOp.i8x16Ne.
- `BinaryOp.i8x16Sub(): BinaryOp`
  Call BinaryOp.i8x16Sub.
- `BinaryOp.i8x16SubSatS(): BinaryOp`
  Call BinaryOp.i8x16SubSatS.
- `BinaryOp.i8x16SubSatU(): BinaryOp`
  Call BinaryOp.i8x16SubSatU.
- `BinaryOp.v128And(): BinaryOp`
  Call BinaryOp.v128And.
- `BinaryOp.v128Andnot(): BinaryOp`
  Call BinaryOp.v128Andnot.
- `BinaryOp.v128Or(): BinaryOp`
  Call BinaryOp.v128Or.
- `BinaryOp.v128Xor(): BinaryOp`
  Call BinaryOp.v128Xor.
- `BinaryOp.show(value: BinaryOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `BlockType`
- `BlockType.typeIdx(arg0: TypeIdx): BlockType`
  Call BlockType.typeIdx.
- `BlockType.valType(arg0: ValType): BlockType`
  Call BlockType.valType.
- `BlockType.void(): BlockType`
  Call BlockType.void.
- `BlockType.show(value: BlockType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `CastOp`
- `CastOp.new(arg0: boolean, arg1: boolean): CastOp`
  Create a CastOp value.
- `CastOp.sourceNullable(arg0: CastOp): boolean`
  Call CastOp.sourceNullable.
- `CastOp.targetNullable(arg0: CastOp): boolean`
  Call CastOp.targetNullable.
- `CastOp.show(value: CastOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Catch`
- `Catch.all(arg0: LabelIdx): Catch`
  Call Catch.all.
- `Catch.allRef(arg0: LabelIdx): Catch`
  Call Catch.allRef.
- `Catch.new(arg0: TagIdx, arg1: LabelIdx): Catch`
  Create a Catch value.
- `Catch.ref(arg0: TagIdx, arg1: LabelIdx): Catch`
  Call Catch.ref.
- `Catch.show(value: Catch): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `CodeSec`
- `CodeSec.inner(arg0: CodeSec): Array<Func>`
  Return the wrapped inner value from CodeSec.
- `CodeSec.new(arg0: Array<Func>): CodeSec`
  Create a CodeSec value.
- `CodeSec.show(value: CodeSec): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `CompType`
- `CompType.array(arg0: FieldType): CompType`
  Call CompType.array.
- `CompType.func(arg0: Array<ValType>, arg1: Array<ValType>): CompType`
  Call CompType.func.
- `CompType.struct(arg0: Array<FieldType>): CompType`
  Call CompType.struct.
- `CompType.show(value: CompType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `CustomSec`
- `CustomSec.new(arg0: Name, arg1: Uint8Array): CustomSec`
  Create a CustomSec value.
- `CustomSec.show(value: CustomSec): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Data`
- `Data.new(arg0: DataMode, arg1: Uint8Array): Data`
  Create a Data value.
- `Data.show(value: Data): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `DataCntSec`
- `DataCntSec.inner(arg0: DataCntSec): U32`
  Return the wrapped inner value from DataCntSec.
- `DataCntSec.new(arg0: U32): DataCntSec`
  Create a DataCntSec value.
- `DataCntSec.show(value: DataCntSec): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `DataIdx`
- `DataIdx.inner(arg0: DataIdx): number`
  Return the wrapped inner value from DataIdx.
- `DataIdx.new(arg0: number): DataIdx`
  Create a DataIdx value.
- `DataIdx.show(value: DataIdx): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `DataMode`
- `DataMode.active(arg0: MemIdx, arg1: Expr): DataMode`
  Call DataMode.active.
- `DataMode.passive(): DataMode`
  Call DataMode.passive.
- `DataMode.show(value: DataMode): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `DataSec`
- `DataSec.inner(arg0: DataSec): Array<Data>`
  Return the wrapped inner value from DataSec.
- `DataSec.new(arg0: Array<Data>): DataSec`
  Create a DataSec value.
- `DataSec.show(value: DataSec): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `DefType`
- `DefType.new(arg0: RecType, arg1: number): DefType`
  Create a DefType value.
- `DefType.project(arg0: DefType): SubType | null`
  Call DefType.project.
- `DefType.show(value: DefType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Elem`
- `Elem.new(arg0: ElemMode, arg1: ElemKind): Elem`
  Create a Elem value.
- `Elem.reftype(arg0: Elem): RefType`
  Call Elem.reftype.
- `Elem.show(value: Elem): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ElemIdx`
- `ElemIdx.inner(arg0: ElemIdx): number`
  Return the wrapped inner value from ElemIdx.
- `ElemIdx.new(arg0: number): ElemIdx`
  Create a ElemIdx value.
- `ElemIdx.show(value: ElemIdx): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ElemKind`
- `ElemKind.funcExprs(arg0: Array<Expr>): ElemKind`
  Call ElemKind.funcExprs.
- `ElemKind.funcs(arg0: Array<FuncIdx>): ElemKind`
  Call ElemKind.funcs.
- `ElemKind.typedExprs(arg0: RefType, arg1: Array<Expr>): ElemKind`
  Call ElemKind.typedExprs.
- `ElemKind.show(value: ElemKind): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ElemMode`
- `ElemMode.active(arg0: TableIdx, arg1: Expr): ElemMode`
  Call ElemMode.active.
- `ElemMode.declarative(): ElemMode`
  Call ElemMode.declarative.
- `ElemMode.passive(): ElemMode`
  Call ElemMode.passive.
- `ElemMode.show(value: ElemMode): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ElemSec`
- `ElemSec.inner(arg0: ElemSec): Array<Elem>`
  Return the wrapped inner value from ElemSec.
- `ElemSec.new(arg0: Array<Elem>): ElemSec`
  Create a ElemSec value.
- `ElemSec.show(value: ElemSec): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Export`
- `Export.new(arg0: Name, arg1: ExternIdx): Export`
  Create a Export value.
- `Export.show(value: Export): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ExportSec`
- `ExportSec.inner(arg0: ExportSec): Array<Export>`
  Return the wrapped inner value from ExportSec.
- `ExportSec.new(arg0: Array<Export>): ExportSec`
  Create a ExportSec value.
- `ExportSec.show(value: ExportSec): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Expr`
- `Expr.inner(arg0: Expr): Array<Instruction>`
  Return the wrapped inner value from Expr.
- `Expr.new(arg0: Array<Instruction>): Expr`
  Create a Expr value.
- `Expr.show(value: Expr): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ExternIdx`
- `ExternIdx.func(arg0: FuncIdx): ExternIdx`
  Call ExternIdx.func.
- `ExternIdx.global(arg0: GlobalIdx): ExternIdx`
  Call ExternIdx.global.
- `ExternIdx.mem(arg0: MemIdx): ExternIdx`
  Call ExternIdx.mem.
- `ExternIdx.table(arg0: TableIdx): ExternIdx`
  Call ExternIdx.table.
- `ExternIdx.tag(arg0: TagIdx): ExternIdx`
  Call ExternIdx.tag.
- `ExternIdx.show(value: ExternIdx): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ExternType`
- `ExternType.func(arg0: TypeIdx): ExternType`
  Call ExternType.func.
- `ExternType.global(arg0: GlobalType): ExternType`
  Call ExternType.global.
- `ExternType.mem(arg0: MemType): ExternType`
  Call ExternType.mem.
- `ExternType.table(arg0: TableType): ExternType`
  Call ExternType.table.
- `ExternType.tag(arg0: TagType): ExternType`
  Call ExternType.tag.
- `ExternType.show(value: ExternType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ExtractLaneOp`
- `ExtractLaneOp.f32x4ExtractLane(): ExtractLaneOp`
  Call ExtractLaneOp.f32x4ExtractLane.
- `ExtractLaneOp.f64x2ExtractLane(): ExtractLaneOp`
  Call ExtractLaneOp.f64x2ExtractLane.
- `ExtractLaneOp.i16x8ExtractLaneS(): ExtractLaneOp`
  Call ExtractLaneOp.i16x8ExtractLaneS.
- `ExtractLaneOp.i16x8ExtractLaneU(): ExtractLaneOp`
  Call ExtractLaneOp.i16x8ExtractLaneU.
- `ExtractLaneOp.i32x4ExtractLane(): ExtractLaneOp`
  Call ExtractLaneOp.i32x4ExtractLane.
- `ExtractLaneOp.i64x2ExtractLane(): ExtractLaneOp`
  Call ExtractLaneOp.i64x2ExtractLane.
- `ExtractLaneOp.i8x16ExtractLaneS(): ExtractLaneOp`
  Call ExtractLaneOp.i8x16ExtractLaneS.
- `ExtractLaneOp.i8x16ExtractLaneU(): ExtractLaneOp`
  Call ExtractLaneOp.i8x16ExtractLaneU.
- `ExtractLaneOp.show(value: ExtractLaneOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `F32`
- `F32.inner(arg0: F32): number`
  Return the wrapped inner value from F32.
- `F32.show(value: F32): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `F64`
- `F64.inner(arg0: F64): number`
  Return the wrapped inner value from F64.
- `F64.show(value: F64): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `FieldType`
- `FieldType.getStorageType(arg0: FieldType): StorageType`
  Read data with FieldType.getStorageType.
- `FieldType.isMutable(arg0: FieldType): boolean`
  Call FieldType.isMutable.
- `FieldType.new(arg0: StorageType, arg1: Mut): FieldType`
  Create a FieldType value.
- `FieldType.unpack(arg0: FieldType): ValType`
  Call FieldType.unpack.
- `FieldType.show(value: FieldType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Func`
- `Func.new(arg0: Array<Locals>, arg1: Expr): Func`
  Create a Func value.
- `Func.tFunc(arg0: Array<ValType>, arg1: TExpr): Func`
  Call Func.tFunc.
- `Func.show(value: Func): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `FuncIdx`
- `FuncIdx.inner(arg0: FuncIdx): number`
  Return the wrapped inner value from FuncIdx.
- `FuncIdx.new(arg0: number): FuncIdx`
  Create a FuncIdx value.
- `FuncIdx.show(value: FuncIdx): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `FuncSec`
- `FuncSec.inner(arg0: FuncSec): Array<TypeIdx>`
  Return the wrapped inner value from FuncSec.
- `FuncSec.new(arg0: Array<TypeIdx>): FuncSec`
  Create a FuncSec value.
- `FuncSec.show(value: FuncSec): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `FuncType`
- `FuncType.new(arg0: Array<ValType>, arg1: Array<ValType>): FuncType`
  Create a FuncType value.
- `FuncType.show(value: FuncType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Global`
- `Global.new(arg0: GlobalType, arg1: Expr): Global`
  Create a Global value.
- `Global.show(value: Global): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `GlobalIdx`
- `GlobalIdx.inner(arg0: GlobalIdx): number`
  Return the wrapped inner value from GlobalIdx.
- `GlobalIdx.new(arg0: number): GlobalIdx`
  Create a GlobalIdx value.
- `GlobalIdx.show(value: GlobalIdx): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `GlobalSec`
- `GlobalSec.inner(arg0: GlobalSec): Array<Global>`
  Return the wrapped inner value from GlobalSec.
- `GlobalSec.new(arg0: Array<Global>): GlobalSec`
  Create a GlobalSec value.
- `GlobalSec.show(value: GlobalSec): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `GlobalType`
- `GlobalType.new(arg0: ValType, arg1: boolean): GlobalType`
  Create a GlobalType value.
- `GlobalType.show(value: GlobalType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `HeapType`
- `HeapType.abs(arg0: AbsHeapType): HeapType`
  Call HeapType.abs.
- `HeapType.bottom(): HeapType`
  Call HeapType.bottom.
- `HeapType.defType(arg0: DefType): HeapType`
  Call HeapType.defType.
- `HeapType.isArray(arg0: HeapType): boolean`
  Call HeapType.isArray.
- `HeapType.isGcAggregate(arg0: HeapType): boolean`
  Call HeapType.isGcAggregate.
- `HeapType.isStruct(arg0: HeapType): boolean`
  Call HeapType.isStruct.
- `HeapType.new(arg0: TypeIdx): HeapType`
  Create a HeapType value.
- `HeapType.show(value: HeapType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `I32`
- `I32.inner(arg0: I32): number`
  Return the wrapped inner value from I32.
- `I32.show(value: I32): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `I64`
- `I64.inner(arg0: I64): bigint`
  Return the wrapped inner value from I64.
- `I64.show(value: I64): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Import`
- `Import.new(arg0: Name, arg1: Name, arg2: ExternType): Import`
  Create a Import value.
- `Import.show(value: Import): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ImportSec`
- `ImportSec.inner(arg0: ImportSec): Array<Import>`
  Return the wrapped inner value from ImportSec.
- `ImportSec.new(arg0: Array<Import>): ImportSec`
  Create a ImportSec value.
- `ImportSec.show(value: ImportSec): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Instruction`
- `Instruction.anyConvertExtern(): Instruction`
  Call Instruction.anyConvertExtern.
- `Instruction.arrayCopy(arg0: TypeIdx, arg1: TypeIdx): Instruction`
  Call Instruction.arrayCopy.
- `Instruction.arrayFill(arg0: TypeIdx): Instruction`
  Call Instruction.arrayFill.
- `Instruction.arrayGet(arg0: TypeIdx): Instruction`
  Call Instruction.arrayGet.
- `Instruction.arrayGetS(arg0: TypeIdx): Instruction`
  Call Instruction.arrayGetS.
- `Instruction.arrayGetU(arg0: TypeIdx): Instruction`
  Call Instruction.arrayGetU.
- `Instruction.arrayInitData(arg0: TypeIdx, arg1: DataIdx): Instruction`
  Call Instruction.arrayInitData.
- `Instruction.arrayInitElem(arg0: TypeIdx, arg1: ElemIdx): Instruction`
  Call Instruction.arrayInitElem.
- `Instruction.arrayLen(): Instruction`
  Call Instruction.arrayLen.
- `Instruction.arrayNew(arg0: TypeIdx): Instruction`
  Call Instruction.arrayNew.
- `Instruction.arrayNewData(arg0: TypeIdx, arg1: DataIdx): Instruction`
  Call Instruction.arrayNewData.
- `Instruction.arrayNewDefault(arg0: TypeIdx): Instruction`
  Call Instruction.arrayNewDefault.
- `Instruction.arrayNewElem(arg0: TypeIdx, arg1: ElemIdx): Instruction`
  Call Instruction.arrayNewElem.
- `Instruction.arrayNewFixed(arg0: TypeIdx, arg1: U32): Instruction`
  Call Instruction.arrayNewFixed.
- `Instruction.arraySet(arg0: TypeIdx): Instruction`
  Call Instruction.arraySet.
- `Instruction.atomicCmpxchg(arg0: AtomicCmpxchgOp, arg1: MemArg): Instruction`
  Call Instruction.atomicCmpxchg.
- `Instruction.atomicFence(): Instruction`
  Call Instruction.atomicFence.
- `Instruction.atomicRmw(arg0: AtomicRmwOp, arg1: MemArg): Instruction`
  Call Instruction.atomicRmw.
- `Instruction.block(arg0: BlockType, arg1: Expr): Instruction`
  Call Instruction.block.
- `Instruction.br(arg0: LabelIdx): Instruction`
  Call Instruction.br.
- `Instruction.brIf(arg0: LabelIdx): Instruction`
  Call Instruction.brIf.
- `Instruction.brOnCast(arg0: LabelIdx, arg1: boolean, arg2: HeapType, arg3: boolean, arg4: HeapType): Instruction`
  Call Instruction.brOnCast.
- `Instruction.brOnCastFail(arg0: LabelIdx, arg1: boolean, arg2: HeapType, arg3: boolean, arg4: HeapType): Instruction`
  Call Instruction.brOnCastFail.
- `Instruction.brOnNonNull(arg0: LabelIdx): Instruction`
  Call Instruction.brOnNonNull.
- `Instruction.brOnNull(arg0: LabelIdx): Instruction`
  Call Instruction.brOnNull.
- `Instruction.brTable(arg0: Array<LabelIdx>, arg1: LabelIdx): Instruction`
  Call Instruction.brTable.
- `Instruction.call(arg0: FuncIdx): Instruction`
  Call Instruction.call.
- `Instruction.callIndirect(arg0: TypeIdx, arg1: TableIdx): Instruction`
  Call Instruction.callIndirect.
- `Instruction.callRef(arg0: TypeIdx): Instruction`
  Call Instruction.callRef.
- `Instruction.dataDrop(arg0: DataIdx): Instruction`
  Call Instruction.dataDrop.
- `Instruction.drop(): Instruction`
  Call Instruction.drop.
- `Instruction.elemDrop(arg0: ElemIdx): Instruction`
  Call Instruction.elemDrop.
- `Instruction.externConvertAny(): Instruction`
  Call Instruction.externConvertAny.
- `Instruction.f32Abs(): Instruction`
  Call Instruction.f32Abs.
- `Instruction.f32Add(): Instruction`
  Call Instruction.f32Add.
- `Instruction.f32Ceil(): Instruction`
  Call Instruction.f32Ceil.
- `Instruction.f32Const(arg0: F32): Instruction`
  Call Instruction.f32Const.
- `Instruction.f32ConvertI32s(): Instruction`
  Call Instruction.f32ConvertI32s.
- `Instruction.f32ConvertI32u(): Instruction`
  Call Instruction.f32ConvertI32u.
- `Instruction.f32ConvertI64s(): Instruction`
  Call Instruction.f32ConvertI64s.
- `Instruction.f32ConvertI64u(): Instruction`
  Call Instruction.f32ConvertI64u.
- `Instruction.f32Copysign(): Instruction`
  Call Instruction.f32Copysign.
- `Instruction.f32DemoteF64(): Instruction`
  Call Instruction.f32DemoteF64.
- `Instruction.f32Div(): Instruction`
  Call Instruction.f32Div.
- `Instruction.f32Eq(): Instruction`
  Call Instruction.f32Eq.
- `Instruction.f32Floor(): Instruction`
  Call Instruction.f32Floor.
- `Instruction.f32Ge(): Instruction`
  Call Instruction.f32Ge.
- `Instruction.f32Gt(): Instruction`
  Call Instruction.f32Gt.
- `Instruction.f32Le(): Instruction`
  Call Instruction.f32Le.
- `Instruction.f32Load(arg0: MemArg): Instruction`
  Call Instruction.f32Load.
- `Instruction.f32Lt(): Instruction`
  Call Instruction.f32Lt.
- `Instruction.f32Max(): Instruction`
  Call Instruction.f32Max.
- `Instruction.f32Min(): Instruction`
  Call Instruction.f32Min.
- `Instruction.f32Mul(): Instruction`
  Call Instruction.f32Mul.
- `Instruction.f32Ne(): Instruction`
  Call Instruction.f32Ne.
- `Instruction.f32Nearest(): Instruction`
  Call Instruction.f32Nearest.
- `Instruction.f32Neg(): Instruction`
  Call Instruction.f32Neg.
- `Instruction.f32ReinterpretI32(): Instruction`
  Call Instruction.f32ReinterpretI32.
- `Instruction.f32Sqrt(): Instruction`
  Call Instruction.f32Sqrt.
- `Instruction.f32Store(arg0: MemArg): Instruction`
  Call Instruction.f32Store.
- `Instruction.f32Sub(): Instruction`
  Call Instruction.f32Sub.
- `Instruction.f32Trunc(): Instruction`
  Call Instruction.f32Trunc.
- `Instruction.f32x4Abs(): Instruction`
  Call Instruction.f32x4Abs.
- `Instruction.f32x4Add(): Instruction`
  Call Instruction.f32x4Add.
- `Instruction.f32x4Ceil(): Instruction`
  Call Instruction.f32x4Ceil.
- `Instruction.f32x4ConvertI32x4s(): Instruction`
  Call Instruction.f32x4ConvertI32x4s.
- `Instruction.f32x4ConvertI32x4u(): Instruction`
  Call Instruction.f32x4ConvertI32x4u.
- `Instruction.f32x4DemoteF64x2Zero(): Instruction`
  Call Instruction.f32x4DemoteF64x2Zero.
- `Instruction.f32x4Div(): Instruction`
  Call Instruction.f32x4Div.
- `Instruction.f32x4Eq(): Instruction`
  Call Instruction.f32x4Eq.
- `Instruction.f32x4ExtractLane(arg0: LaneIdx): Instruction`
  Call Instruction.f32x4ExtractLane.
- `Instruction.f32x4Floor(): Instruction`
  Call Instruction.f32x4Floor.
- `Instruction.f32x4Ge(): Instruction`
  Call Instruction.f32x4Ge.
- `Instruction.f32x4Gt(): Instruction`
  Call Instruction.f32x4Gt.
- `Instruction.f32x4Le(): Instruction`
  Call Instruction.f32x4Le.
- `Instruction.f32x4Lt(): Instruction`
  Call Instruction.f32x4Lt.
- `Instruction.f32x4Max(): Instruction`
  Call Instruction.f32x4Max.
- `Instruction.f32x4Min(): Instruction`
  Call Instruction.f32x4Min.
- `Instruction.f32x4Mul(): Instruction`
  Call Instruction.f32x4Mul.
- `Instruction.f32x4Ne(): Instruction`
  Call Instruction.f32x4Ne.
- `Instruction.f32x4Nearest(): Instruction`
  Call Instruction.f32x4Nearest.
- `Instruction.f32x4Neg(): Instruction`
  Call Instruction.f32x4Neg.
- `Instruction.f32x4Pmax(): Instruction`
  Call Instruction.f32x4Pmax.
- `Instruction.f32x4Pmin(): Instruction`
  Call Instruction.f32x4Pmin.
- `Instruction.f32x4RelaxedMadd(): Instruction`
  Call Instruction.f32x4RelaxedMadd.
- `Instruction.f32x4RelaxedMax(): Instruction`
  Call Instruction.f32x4RelaxedMax.
- `Instruction.f32x4RelaxedMin(): Instruction`
  Call Instruction.f32x4RelaxedMin.
- `Instruction.f32x4RelaxedNmadd(): Instruction`
  Call Instruction.f32x4RelaxedNmadd.
- `Instruction.f32x4ReplaceLane(arg0: LaneIdx): Instruction`
  Call Instruction.f32x4ReplaceLane.
- `Instruction.f32x4Splat(): Instruction`
  Call Instruction.f32x4Splat.
- `Instruction.f32x4Sqrt(): Instruction`
  Call Instruction.f32x4Sqrt.
- `Instruction.f32x4Sub(): Instruction`
  Call Instruction.f32x4Sub.
- `Instruction.f32x4Trunc(): Instruction`
  Call Instruction.f32x4Trunc.
- `Instruction.f64Abs(): Instruction`
  Call Instruction.f64Abs.
- `Instruction.f64Add(): Instruction`
  Call Instruction.f64Add.
- `Instruction.f64Ceil(): Instruction`
  Call Instruction.f64Ceil.
- `Instruction.f64Const(arg0: F64): Instruction`
  Call Instruction.f64Const.
- `Instruction.f64ConvertI32s(): Instruction`
  Call Instruction.f64ConvertI32s.
- `Instruction.f64ConvertI32u(): Instruction`
  Call Instruction.f64ConvertI32u.
- `Instruction.f64ConvertI64s(): Instruction`
  Call Instruction.f64ConvertI64s.
- `Instruction.f64ConvertI64u(): Instruction`
  Call Instruction.f64ConvertI64u.
- `Instruction.f64Copysign(): Instruction`
  Call Instruction.f64Copysign.
- `Instruction.f64Div(): Instruction`
  Call Instruction.f64Div.
- `Instruction.f64Eq(): Instruction`
  Call Instruction.f64Eq.
- `Instruction.f64Floor(): Instruction`
  Call Instruction.f64Floor.
- `Instruction.f64Ge(): Instruction`
  Call Instruction.f64Ge.
- `Instruction.f64Gt(): Instruction`
  Call Instruction.f64Gt.
- `Instruction.f64Le(): Instruction`
  Call Instruction.f64Le.
- `Instruction.f64Load(arg0: MemArg): Instruction`
  Call Instruction.f64Load.
- `Instruction.f64Lt(): Instruction`
  Call Instruction.f64Lt.
- `Instruction.f64Max(): Instruction`
  Call Instruction.f64Max.
- `Instruction.f64Min(): Instruction`
  Call Instruction.f64Min.
- `Instruction.f64Mul(): Instruction`
  Call Instruction.f64Mul.
- `Instruction.f64Ne(): Instruction`
  Call Instruction.f64Ne.
- `Instruction.f64Nearest(): Instruction`
  Call Instruction.f64Nearest.
- `Instruction.f64Neg(): Instruction`
  Call Instruction.f64Neg.
- `Instruction.f64PromoteF32(): Instruction`
  Call Instruction.f64PromoteF32.
- `Instruction.f64ReinterpretI64(): Instruction`
  Call Instruction.f64ReinterpretI64.
- `Instruction.f64Sqrt(): Instruction`
  Call Instruction.f64Sqrt.
- `Instruction.f64Store(arg0: MemArg): Instruction`
  Call Instruction.f64Store.
- `Instruction.f64Sub(): Instruction`
  Call Instruction.f64Sub.
- `Instruction.f64Trunc(): Instruction`
  Call Instruction.f64Trunc.
- `Instruction.f64x2Abs(): Instruction`
  Call Instruction.f64x2Abs.
- `Instruction.f64x2Add(): Instruction`
  Call Instruction.f64x2Add.
- `Instruction.f64x2Ceil(): Instruction`
  Call Instruction.f64x2Ceil.
- `Instruction.f64x2ConvertLowI32x4s(): Instruction`
  Call Instruction.f64x2ConvertLowI32x4s.
- `Instruction.f64x2ConvertLowI32x4u(): Instruction`
  Call Instruction.f64x2ConvertLowI32x4u.
- `Instruction.f64x2Div(): Instruction`
  Call Instruction.f64x2Div.
- `Instruction.f64x2Eq(): Instruction`
  Call Instruction.f64x2Eq.
- `Instruction.f64x2ExtractLane(arg0: LaneIdx): Instruction`
  Call Instruction.f64x2ExtractLane.
- `Instruction.f64x2Floor(): Instruction`
  Call Instruction.f64x2Floor.
- `Instruction.f64x2Ge(): Instruction`
  Call Instruction.f64x2Ge.
- `Instruction.f64x2Gt(): Instruction`
  Call Instruction.f64x2Gt.
- `Instruction.f64x2Le(): Instruction`
  Call Instruction.f64x2Le.
- `Instruction.f64x2Lt(): Instruction`
  Call Instruction.f64x2Lt.
- `Instruction.f64x2Max(): Instruction`
  Call Instruction.f64x2Max.
- `Instruction.f64x2Min(): Instruction`
  Call Instruction.f64x2Min.
- `Instruction.f64x2Mul(): Instruction`
  Call Instruction.f64x2Mul.
- `Instruction.f64x2Ne(): Instruction`
  Call Instruction.f64x2Ne.
- `Instruction.f64x2Nearest(): Instruction`
  Call Instruction.f64x2Nearest.
- `Instruction.f64x2Neg(): Instruction`
  Call Instruction.f64x2Neg.
- `Instruction.f64x2Pmax(): Instruction`
  Call Instruction.f64x2Pmax.
- `Instruction.f64x2Pmin(): Instruction`
  Call Instruction.f64x2Pmin.
- `Instruction.f64x2PromoteLowF32x4(): Instruction`
  Call Instruction.f64x2PromoteLowF32x4.
- `Instruction.f64x2RelaxedMadd(): Instruction`
  Call Instruction.f64x2RelaxedMadd.
- `Instruction.f64x2RelaxedMax(): Instruction`
  Call Instruction.f64x2RelaxedMax.
- `Instruction.f64x2RelaxedMin(): Instruction`
  Call Instruction.f64x2RelaxedMin.
- `Instruction.f64x2RelaxedNmadd(): Instruction`
  Call Instruction.f64x2RelaxedNmadd.
- `Instruction.f64x2ReplaceLane(arg0: LaneIdx): Instruction`
  Call Instruction.f64x2ReplaceLane.
- `Instruction.f64x2Splat(): Instruction`
  Call Instruction.f64x2Splat.
- `Instruction.f64x2Sqrt(): Instruction`
  Call Instruction.f64x2Sqrt.
- `Instruction.f64x2Sub(): Instruction`
  Call Instruction.f64x2Sub.
- `Instruction.f64x2Trunc(): Instruction`
  Call Instruction.f64x2Trunc.
- `Instruction.globalGet(arg0: GlobalIdx): Instruction`
  Call Instruction.globalGet.
- `Instruction.globalSet(arg0: GlobalIdx): Instruction`
  Call Instruction.globalSet.
- `Instruction.i16x8Abs(): Instruction`
  Call Instruction.i16x8Abs.
- `Instruction.i16x8Add(): Instruction`
  Call Instruction.i16x8Add.
- `Instruction.i16x8AddSatS(): Instruction`
  Call Instruction.i16x8AddSatS.
- `Instruction.i16x8AddSatU(): Instruction`
  Call Instruction.i16x8AddSatU.
- `Instruction.i16x8AllTrue(): Instruction`
  Call Instruction.i16x8AllTrue.
- `Instruction.i16x8AvgrU(): Instruction`
  Call Instruction.i16x8AvgrU.
- `Instruction.i16x8Bitmask(): Instruction`
  Call Instruction.i16x8Bitmask.
- `Instruction.i16x8Eq(): Instruction`
  Call Instruction.i16x8Eq.
- `Instruction.i16x8ExtaddPairwiseI8x16s(): Instruction`
  Call Instruction.i16x8ExtaddPairwiseI8x16s.
- `Instruction.i16x8ExtaddPairwiseI8x16u(): Instruction`
  Call Instruction.i16x8ExtaddPairwiseI8x16u.
- `Instruction.i16x8ExtendHighI8x16s(): Instruction`
  Call Instruction.i16x8ExtendHighI8x16s.
- `Instruction.i16x8ExtendHighI8x16u(): Instruction`
  Call Instruction.i16x8ExtendHighI8x16u.
- `Instruction.i16x8ExtendLowI8x16s(): Instruction`
  Call Instruction.i16x8ExtendLowI8x16s.
- `Instruction.i16x8ExtendLowI8x16u(): Instruction`
  Call Instruction.i16x8ExtendLowI8x16u.
- `Instruction.i16x8ExtmulHighI8x16s(): Instruction`
  Call Instruction.i16x8ExtmulHighI8x16s.
- `Instruction.i16x8ExtmulHighI8x16u(): Instruction`
  Call Instruction.i16x8ExtmulHighI8x16u.
- `Instruction.i16x8ExtmulLowI8x16s(): Instruction`
  Call Instruction.i16x8ExtmulLowI8x16s.
- `Instruction.i16x8ExtmulLowI8x16u(): Instruction`
  Call Instruction.i16x8ExtmulLowI8x16u.
- `Instruction.i16x8ExtractLaneS(arg0: LaneIdx): Instruction`
  Call Instruction.i16x8ExtractLaneS.
- `Instruction.i16x8ExtractLaneU(arg0: LaneIdx): Instruction`
  Call Instruction.i16x8ExtractLaneU.
- `Instruction.i16x8GeS(): Instruction`
  Call Instruction.i16x8GeS.
- `Instruction.i16x8GeU(): Instruction`
  Call Instruction.i16x8GeU.
- `Instruction.i16x8GtS(): Instruction`
  Call Instruction.i16x8GtS.
- `Instruction.i16x8GtU(): Instruction`
  Call Instruction.i16x8GtU.
- `Instruction.i16x8LeS(): Instruction`
  Call Instruction.i16x8LeS.
- `Instruction.i16x8LeU(): Instruction`
  Call Instruction.i16x8LeU.
- `Instruction.i16x8LtS(): Instruction`
  Call Instruction.i16x8LtS.
- `Instruction.i16x8LtU(): Instruction`
  Call Instruction.i16x8LtU.
- `Instruction.i16x8MaxS(): Instruction`
  Call Instruction.i16x8MaxS.
- `Instruction.i16x8MaxU(): Instruction`
  Call Instruction.i16x8MaxU.
- `Instruction.i16x8MinS(): Instruction`
  Call Instruction.i16x8MinS.
- `Instruction.i16x8MinU(): Instruction`
  Call Instruction.i16x8MinU.
- `Instruction.i16x8Mul(): Instruction`
  Call Instruction.i16x8Mul.
- `Instruction.i16x8NarrowI32x4s(): Instruction`
  Call Instruction.i16x8NarrowI32x4s.
- `Instruction.i16x8NarrowI32x4u(): Instruction`
  Call Instruction.i16x8NarrowI32x4u.
- `Instruction.i16x8Ne(): Instruction`
  Call Instruction.i16x8Ne.
- `Instruction.i16x8Neg(): Instruction`
  Call Instruction.i16x8Neg.
- `Instruction.i16x8RelaxedDotI8x16i7x16s(): Instruction`
  Call Instruction.i16x8RelaxedDotI8x16i7x16s.
- `Instruction.i16x8RelaxedLaneselect(): Instruction`
  Call Instruction.i16x8RelaxedLaneselect.
- `Instruction.i16x8RelaxedQ15mulrS(): Instruction`
  Call Instruction.i16x8RelaxedQ15mulrS.
- `Instruction.i16x8ReplaceLane(arg0: LaneIdx): Instruction`
  Call Instruction.i16x8ReplaceLane.
- `Instruction.i16x8Shl(): Instruction`
  Call Instruction.i16x8Shl.
- `Instruction.i16x8ShrS(): Instruction`
  Call Instruction.i16x8ShrS.
- `Instruction.i16x8ShrU(): Instruction`
  Call Instruction.i16x8ShrU.
- `Instruction.i16x8Splat(): Instruction`
  Call Instruction.i16x8Splat.
- `Instruction.i16x8Sub(): Instruction`
  Call Instruction.i16x8Sub.
- `Instruction.i16x8SubSatS(): Instruction`
  Call Instruction.i16x8SubSatS.
- `Instruction.i16x8SubSatU(): Instruction`
  Call Instruction.i16x8SubSatU.
- `Instruction.i16x8q15mulrSatS(): Instruction`
  Call Instruction.i16x8q15mulrSatS.
- `Instruction.i31GetS(): Instruction`
  Call Instruction.i31GetS.
- `Instruction.i31GetU(): Instruction`
  Call Instruction.i31GetU.
- `Instruction.i32Add(): Instruction`
  Call Instruction.i32Add.
- `Instruction.i32And(): Instruction`
  Call Instruction.i32And.
- `Instruction.i32AtomicLoad(arg0: MemArg): Instruction`
  Call Instruction.i32AtomicLoad.
- `Instruction.i32AtomicLoad16U(arg0: MemArg): Instruction`
  Call Instruction.i32AtomicLoad16U.
- `Instruction.i32AtomicLoad8U(arg0: MemArg): Instruction`
  Call Instruction.i32AtomicLoad8U.
- `Instruction.i32AtomicStore(arg0: MemArg): Instruction`
  Call Instruction.i32AtomicStore.
- `Instruction.i32AtomicStore16(arg0: MemArg): Instruction`
  Call Instruction.i32AtomicStore16.
- `Instruction.i32AtomicStore8(arg0: MemArg): Instruction`
  Call Instruction.i32AtomicStore8.
- `Instruction.i32Clz(): Instruction`
  Call Instruction.i32Clz.
- `Instruction.i32Const(arg0: I32): Instruction`
  Call Instruction.i32Const.
- `Instruction.i32Ctz(): Instruction`
  Call Instruction.i32Ctz.
- `Instruction.i32DivS(): Instruction`
  Call Instruction.i32DivS.
- `Instruction.i32DivU(): Instruction`
  Call Instruction.i32DivU.
- `Instruction.i32Eq(): Instruction`
  Call Instruction.i32Eq.
- `Instruction.i32Eqz(): Instruction`
  Call Instruction.i32Eqz.
- `Instruction.i32Extend16s(): Instruction`
  Call Instruction.i32Extend16s.
- `Instruction.i32Extend8s(): Instruction`
  Call Instruction.i32Extend8s.
- `Instruction.i32GeS(): Instruction`
  Call Instruction.i32GeS.
- `Instruction.i32GeU(): Instruction`
  Call Instruction.i32GeU.
- `Instruction.i32GtS(): Instruction`
  Call Instruction.i32GtS.
- `Instruction.i32GtU(): Instruction`
  Call Instruction.i32GtU.
- `Instruction.i32LeS(): Instruction`
  Call Instruction.i32LeS.
- `Instruction.i32LeU(): Instruction`
  Call Instruction.i32LeU.
- `Instruction.i32Load(arg0: MemArg): Instruction`
  Call Instruction.i32Load.
- `Instruction.i32Load16s(arg0: MemArg): Instruction`
  Call Instruction.i32Load16s.
- `Instruction.i32Load16u(arg0: MemArg): Instruction`
  Call Instruction.i32Load16u.
- `Instruction.i32Load8s(arg0: MemArg): Instruction`
  Call Instruction.i32Load8s.
- `Instruction.i32Load8u(arg0: MemArg): Instruction`
  Call Instruction.i32Load8u.
- `Instruction.i32LtS(): Instruction`
  Call Instruction.i32LtS.
- `Instruction.i32LtU(): Instruction`
  Call Instruction.i32LtU.
- `Instruction.i32Mul(): Instruction`
  Call Instruction.i32Mul.
- `Instruction.i32Ne(): Instruction`
  Call Instruction.i32Ne.
- `Instruction.i32Or(): Instruction`
  Call Instruction.i32Or.
- `Instruction.i32Popcnt(): Instruction`
  Call Instruction.i32Popcnt.
- `Instruction.i32ReinterpretF32(): Instruction`
  Call Instruction.i32ReinterpretF32.
- `Instruction.i32RemS(): Instruction`
  Call Instruction.i32RemS.
- `Instruction.i32RemU(): Instruction`
  Call Instruction.i32RemU.
- `Instruction.i32Rotl(): Instruction`
  Call Instruction.i32Rotl.
- `Instruction.i32Rotr(): Instruction`
  Call Instruction.i32Rotr.
- `Instruction.i32Shl(): Instruction`
  Call Instruction.i32Shl.
- `Instruction.i32ShrS(): Instruction`
  Call Instruction.i32ShrS.
- `Instruction.i32ShrU(): Instruction`
  Call Instruction.i32ShrU.
- `Instruction.i32Store(arg0: MemArg): Instruction`
  Call Instruction.i32Store.
- `Instruction.i32Store16(arg0: MemArg): Instruction`
  Call Instruction.i32Store16.
- `Instruction.i32Store8(arg0: MemArg): Instruction`
  Call Instruction.i32Store8.
- `Instruction.i32Sub(): Instruction`
  Call Instruction.i32Sub.
- `Instruction.i32TruncF32s(): Instruction`
  Call Instruction.i32TruncF32s.
- `Instruction.i32TruncF32u(): Instruction`
  Call Instruction.i32TruncF32u.
- `Instruction.i32TruncF64s(): Instruction`
  Call Instruction.i32TruncF64s.
- `Instruction.i32TruncF64u(): Instruction`
  Call Instruction.i32TruncF64u.
- `Instruction.i32TruncSatF32s(): Instruction`
  Call Instruction.i32TruncSatF32s.
- `Instruction.i32TruncSatF32u(): Instruction`
  Call Instruction.i32TruncSatF32u.
- `Instruction.i32TruncSatF64s(): Instruction`
  Call Instruction.i32TruncSatF64s.
- `Instruction.i32TruncSatF64u(): Instruction`
  Call Instruction.i32TruncSatF64u.
- `Instruction.i32WrapI64(): Instruction`
  Call Instruction.i32WrapI64.
- `Instruction.i32Xor(): Instruction`
  Call Instruction.i32Xor.
- `Instruction.i32x4Abs(): Instruction`
  Call Instruction.i32x4Abs.
- `Instruction.i32x4Add(): Instruction`
  Call Instruction.i32x4Add.
- `Instruction.i32x4AllTrue(): Instruction`
  Call Instruction.i32x4AllTrue.
- `Instruction.i32x4Bitmask(): Instruction`
  Call Instruction.i32x4Bitmask.
- `Instruction.i32x4DotI16x8s(): Instruction`
  Call Instruction.i32x4DotI16x8s.
- `Instruction.i32x4Eq(): Instruction`
  Call Instruction.i32x4Eq.
- `Instruction.i32x4ExtaddPairwiseI16x8s(): Instruction`
  Call Instruction.i32x4ExtaddPairwiseI16x8s.
- `Instruction.i32x4ExtaddPairwiseI16x8u(): Instruction`
  Call Instruction.i32x4ExtaddPairwiseI16x8u.
- `Instruction.i32x4ExtendHighI16x8s(): Instruction`
  Call Instruction.i32x4ExtendHighI16x8s.
- `Instruction.i32x4ExtendHighI16x8u(): Instruction`
  Call Instruction.i32x4ExtendHighI16x8u.
- `Instruction.i32x4ExtendLowI16x8s(): Instruction`
  Call Instruction.i32x4ExtendLowI16x8s.
- `Instruction.i32x4ExtendLowI16x8u(): Instruction`
  Call Instruction.i32x4ExtendLowI16x8u.
- `Instruction.i32x4ExtmulHighI16x8s(): Instruction`
  Call Instruction.i32x4ExtmulHighI16x8s.
- `Instruction.i32x4ExtmulHighI16x8u(): Instruction`
  Call Instruction.i32x4ExtmulHighI16x8u.
- `Instruction.i32x4ExtmulLowI16x8s(): Instruction`
  Call Instruction.i32x4ExtmulLowI16x8s.
- `Instruction.i32x4ExtmulLowI16x8u(): Instruction`
  Call Instruction.i32x4ExtmulLowI16x8u.
- `Instruction.i32x4ExtractLane(arg0: LaneIdx): Instruction`
  Call Instruction.i32x4ExtractLane.
- `Instruction.i32x4GeS(): Instruction`
  Call Instruction.i32x4GeS.
- `Instruction.i32x4GeU(): Instruction`
  Call Instruction.i32x4GeU.
- `Instruction.i32x4GtS(): Instruction`
  Call Instruction.i32x4GtS.
- `Instruction.i32x4GtU(): Instruction`
  Call Instruction.i32x4GtU.
- `Instruction.i32x4LeS(): Instruction`
  Call Instruction.i32x4LeS.
- `Instruction.i32x4LeU(): Instruction`
  Call Instruction.i32x4LeU.
- `Instruction.i32x4LtS(): Instruction`
  Call Instruction.i32x4LtS.
- `Instruction.i32x4LtU(): Instruction`
  Call Instruction.i32x4LtU.
- `Instruction.i32x4MaxS(): Instruction`
  Call Instruction.i32x4MaxS.
- `Instruction.i32x4MaxU(): Instruction`
  Call Instruction.i32x4MaxU.
- `Instruction.i32x4MinS(): Instruction`
  Call Instruction.i32x4MinS.
- `Instruction.i32x4MinU(): Instruction`
  Call Instruction.i32x4MinU.
- `Instruction.i32x4Mul(): Instruction`
  Call Instruction.i32x4Mul.
- `Instruction.i32x4Ne(): Instruction`
  Call Instruction.i32x4Ne.
- `Instruction.i32x4Neg(): Instruction`
  Call Instruction.i32x4Neg.
- `Instruction.i32x4RelaxedDotI8x16i7x16AddS(): Instruction`
  Call Instruction.i32x4RelaxedDotI8x16i7x16AddS.
- `Instruction.i32x4RelaxedLaneselect(): Instruction`
  Call Instruction.i32x4RelaxedLaneselect.
- `Instruction.i32x4RelaxedTruncF32x4s(): Instruction`
  Call Instruction.i32x4RelaxedTruncF32x4s.
- `Instruction.i32x4RelaxedTruncF32x4u(): Instruction`
  Call Instruction.i32x4RelaxedTruncF32x4u.
- `Instruction.i32x4RelaxedTruncZeroF64x2s(): Instruction`
  Call Instruction.i32x4RelaxedTruncZeroF64x2s.
- `Instruction.i32x4RelaxedTruncZeroF64x2u(): Instruction`
  Call Instruction.i32x4RelaxedTruncZeroF64x2u.
- `Instruction.i32x4ReplaceLane(arg0: LaneIdx): Instruction`
  Call Instruction.i32x4ReplaceLane.
- `Instruction.i32x4Shl(): Instruction`
  Call Instruction.i32x4Shl.
- `Instruction.i32x4ShrS(): Instruction`
  Call Instruction.i32x4ShrS.
- `Instruction.i32x4ShrU(): Instruction`
  Call Instruction.i32x4ShrU.
- `Instruction.i32x4Splat(): Instruction`
  Call Instruction.i32x4Splat.
- `Instruction.i32x4Sub(): Instruction`
  Call Instruction.i32x4Sub.
- `Instruction.i32x4TruncSatF32x4s(): Instruction`
  Call Instruction.i32x4TruncSatF32x4s.
- `Instruction.i32x4TruncSatF32x4u(): Instruction`
  Call Instruction.i32x4TruncSatF32x4u.
- `Instruction.i32x4TruncSatF64x2sZero(): Instruction`
  Call Instruction.i32x4TruncSatF64x2sZero.
- `Instruction.i32x4TruncSatF64x2uZero(): Instruction`
  Call Instruction.i32x4TruncSatF64x2uZero.
- `Instruction.i64Add(): Instruction`
  Call Instruction.i64Add.
- `Instruction.i64And(): Instruction`
  Call Instruction.i64And.
- `Instruction.i64AtomicLoad(arg0: MemArg): Instruction`
  Call Instruction.i64AtomicLoad.
- `Instruction.i64AtomicLoad16U(arg0: MemArg): Instruction`
  Call Instruction.i64AtomicLoad16U.
- `Instruction.i64AtomicLoad32U(arg0: MemArg): Instruction`
  Call Instruction.i64AtomicLoad32U.
- `Instruction.i64AtomicLoad8U(arg0: MemArg): Instruction`
  Call Instruction.i64AtomicLoad8U.
- `Instruction.i64AtomicStore(arg0: MemArg): Instruction`
  Call Instruction.i64AtomicStore.
- `Instruction.i64AtomicStore16(arg0: MemArg): Instruction`
  Call Instruction.i64AtomicStore16.
- `Instruction.i64AtomicStore32(arg0: MemArg): Instruction`
  Call Instruction.i64AtomicStore32.
- `Instruction.i64AtomicStore8(arg0: MemArg): Instruction`
  Call Instruction.i64AtomicStore8.
- `Instruction.i64Clz(): Instruction`
  Call Instruction.i64Clz.
- `Instruction.i64Const(arg0: I64): Instruction`
  Call Instruction.i64Const.
- `Instruction.i64Ctz(): Instruction`
  Call Instruction.i64Ctz.
- `Instruction.i64DivS(): Instruction`
  Call Instruction.i64DivS.
- `Instruction.i64DivU(): Instruction`
  Call Instruction.i64DivU.
- `Instruction.i64Eq(): Instruction`
  Call Instruction.i64Eq.
- `Instruction.i64Eqz(): Instruction`
  Call Instruction.i64Eqz.
- `Instruction.i64Extend16s(): Instruction`
  Call Instruction.i64Extend16s.
- `Instruction.i64Extend32s(): Instruction`
  Call Instruction.i64Extend32s.
- `Instruction.i64Extend8s(): Instruction`
  Call Instruction.i64Extend8s.
- `Instruction.i64ExtendI32s(): Instruction`
  Call Instruction.i64ExtendI32s.
- `Instruction.i64ExtendI32u(): Instruction`
  Call Instruction.i64ExtendI32u.
- `Instruction.i64GeS(): Instruction`
  Call Instruction.i64GeS.
- `Instruction.i64GeU(): Instruction`
  Call Instruction.i64GeU.
- `Instruction.i64GtS(): Instruction`
  Call Instruction.i64GtS.
- `Instruction.i64GtU(): Instruction`
  Call Instruction.i64GtU.
- `Instruction.i64LeS(): Instruction`
  Call Instruction.i64LeS.
- `Instruction.i64LeU(): Instruction`
  Call Instruction.i64LeU.
- `Instruction.i64Load(arg0: MemArg): Instruction`
  Call Instruction.i64Load.
- `Instruction.i64Load16s(arg0: MemArg): Instruction`
  Call Instruction.i64Load16s.
- `Instruction.i64Load16u(arg0: MemArg): Instruction`
  Call Instruction.i64Load16u.
- `Instruction.i64Load32s(arg0: MemArg): Instruction`
  Call Instruction.i64Load32s.
- `Instruction.i64Load32u(arg0: MemArg): Instruction`
  Call Instruction.i64Load32u.
- `Instruction.i64Load8s(arg0: MemArg): Instruction`
  Call Instruction.i64Load8s.
- `Instruction.i64Load8u(arg0: MemArg): Instruction`
  Call Instruction.i64Load8u.
- `Instruction.i64LtS(): Instruction`
  Call Instruction.i64LtS.
- `Instruction.i64LtU(): Instruction`
  Call Instruction.i64LtU.
- `Instruction.i64Mul(): Instruction`
  Call Instruction.i64Mul.
- `Instruction.i64Ne(): Instruction`
  Call Instruction.i64Ne.
- `Instruction.i64Or(): Instruction`
  Call Instruction.i64Or.
- `Instruction.i64Popcnt(): Instruction`
  Call Instruction.i64Popcnt.
- `Instruction.i64ReinterpretF64(): Instruction`
  Call Instruction.i64ReinterpretF64.
- `Instruction.i64RemS(): Instruction`
  Call Instruction.i64RemS.
- `Instruction.i64RemU(): Instruction`
  Call Instruction.i64RemU.
- `Instruction.i64Rotl(): Instruction`
  Call Instruction.i64Rotl.
- `Instruction.i64Rotr(): Instruction`
  Call Instruction.i64Rotr.
- `Instruction.i64Shl(): Instruction`
  Call Instruction.i64Shl.
- `Instruction.i64ShrS(): Instruction`
  Call Instruction.i64ShrS.
- `Instruction.i64ShrU(): Instruction`
  Call Instruction.i64ShrU.
- `Instruction.i64Store(arg0: MemArg): Instruction`
  Call Instruction.i64Store.
- `Instruction.i64Store16(arg0: MemArg): Instruction`
  Call Instruction.i64Store16.
- `Instruction.i64Store32(arg0: MemArg): Instruction`
  Call Instruction.i64Store32.
- `Instruction.i64Store8(arg0: MemArg): Instruction`
  Call Instruction.i64Store8.
- `Instruction.i64Sub(): Instruction`
  Call Instruction.i64Sub.
- `Instruction.i64TruncF32s(): Instruction`
  Call Instruction.i64TruncF32s.
- `Instruction.i64TruncF32u(): Instruction`
  Call Instruction.i64TruncF32u.
- `Instruction.i64TruncF64s(): Instruction`
  Call Instruction.i64TruncF64s.
- `Instruction.i64TruncF64u(): Instruction`
  Call Instruction.i64TruncF64u.
- `Instruction.i64TruncSatF32s(): Instruction`
  Call Instruction.i64TruncSatF32s.
- `Instruction.i64TruncSatF32u(): Instruction`
  Call Instruction.i64TruncSatF32u.
- `Instruction.i64TruncSatF64s(): Instruction`
  Call Instruction.i64TruncSatF64s.
- `Instruction.i64TruncSatF64u(): Instruction`
  Call Instruction.i64TruncSatF64u.
- `Instruction.i64Xor(): Instruction`
  Call Instruction.i64Xor.
- `Instruction.i64x2Abs(): Instruction`
  Call Instruction.i64x2Abs.
- `Instruction.i64x2Add(): Instruction`
  Call Instruction.i64x2Add.
- `Instruction.i64x2AllTrue(): Instruction`
  Call Instruction.i64x2AllTrue.
- `Instruction.i64x2Bitmask(): Instruction`
  Call Instruction.i64x2Bitmask.
- `Instruction.i64x2Eq(): Instruction`
  Call Instruction.i64x2Eq.
- `Instruction.i64x2ExtendHighI32x4s(): Instruction`
  Call Instruction.i64x2ExtendHighI32x4s.
- `Instruction.i64x2ExtendHighI32x4u(): Instruction`
  Call Instruction.i64x2ExtendHighI32x4u.
- `Instruction.i64x2ExtendLowI32x4s(): Instruction`
  Call Instruction.i64x2ExtendLowI32x4s.
- `Instruction.i64x2ExtendLowI32x4u(): Instruction`
  Call Instruction.i64x2ExtendLowI32x4u.
- `Instruction.i64x2ExtmulHighI32x4s(): Instruction`
  Call Instruction.i64x2ExtmulHighI32x4s.
- `Instruction.i64x2ExtmulHighI32x4u(): Instruction`
  Call Instruction.i64x2ExtmulHighI32x4u.
- `Instruction.i64x2ExtmulLowI32x4s(): Instruction`
  Call Instruction.i64x2ExtmulLowI32x4s.
- `Instruction.i64x2ExtmulLowI32x4u(): Instruction`
  Call Instruction.i64x2ExtmulLowI32x4u.
- `Instruction.i64x2ExtractLane(arg0: LaneIdx): Instruction`
  Call Instruction.i64x2ExtractLane.
- `Instruction.i64x2GeS(): Instruction`
  Call Instruction.i64x2GeS.
- `Instruction.i64x2GtS(): Instruction`
  Call Instruction.i64x2GtS.
- `Instruction.i64x2LeS(): Instruction`
  Call Instruction.i64x2LeS.
- `Instruction.i64x2LtS(): Instruction`
  Call Instruction.i64x2LtS.
- `Instruction.i64x2Mul(): Instruction`
  Call Instruction.i64x2Mul.
- `Instruction.i64x2Ne(): Instruction`
  Call Instruction.i64x2Ne.
- `Instruction.i64x2Neg(): Instruction`
  Call Instruction.i64x2Neg.
- `Instruction.i64x2RelaxedLaneselect(): Instruction`
  Call Instruction.i64x2RelaxedLaneselect.
- `Instruction.i64x2ReplaceLane(arg0: LaneIdx): Instruction`
  Call Instruction.i64x2ReplaceLane.
- `Instruction.i64x2Shl(): Instruction`
  Call Instruction.i64x2Shl.
- `Instruction.i64x2ShrS(): Instruction`
  Call Instruction.i64x2ShrS.
- `Instruction.i64x2ShrU(): Instruction`
  Call Instruction.i64x2ShrU.
- `Instruction.i64x2Splat(): Instruction`
  Call Instruction.i64x2Splat.
- `Instruction.i64x2Sub(): Instruction`
  Call Instruction.i64x2Sub.
- `Instruction.i8x16Abs(): Instruction`
  Call Instruction.i8x16Abs.
- `Instruction.i8x16Add(): Instruction`
  Call Instruction.i8x16Add.
- `Instruction.i8x16AddSatS(): Instruction`
  Call Instruction.i8x16AddSatS.
- `Instruction.i8x16AddSatU(): Instruction`
  Call Instruction.i8x16AddSatU.
- `Instruction.i8x16AllTrue(): Instruction`
  Call Instruction.i8x16AllTrue.
- `Instruction.i8x16AvgrU(): Instruction`
  Call Instruction.i8x16AvgrU.
- `Instruction.i8x16Bitmask(): Instruction`
  Call Instruction.i8x16Bitmask.
- `Instruction.i8x16Eq(): Instruction`
  Call Instruction.i8x16Eq.
- `Instruction.i8x16ExtractLaneS(arg0: LaneIdx): Instruction`
  Call Instruction.i8x16ExtractLaneS.
- `Instruction.i8x16ExtractLaneU(arg0: LaneIdx): Instruction`
  Call Instruction.i8x16ExtractLaneU.
- `Instruction.i8x16GeS(): Instruction`
  Call Instruction.i8x16GeS.
- `Instruction.i8x16GeU(): Instruction`
  Call Instruction.i8x16GeU.
- `Instruction.i8x16GtS(): Instruction`
  Call Instruction.i8x16GtS.
- `Instruction.i8x16GtU(): Instruction`
  Call Instruction.i8x16GtU.
- `Instruction.i8x16LeS(): Instruction`
  Call Instruction.i8x16LeS.
- `Instruction.i8x16LeU(): Instruction`
  Call Instruction.i8x16LeU.
- `Instruction.i8x16LtS(): Instruction`
  Call Instruction.i8x16LtS.
- `Instruction.i8x16LtU(): Instruction`
  Call Instruction.i8x16LtU.
- `Instruction.i8x16MaxS(): Instruction`
  Call Instruction.i8x16MaxS.
- `Instruction.i8x16MaxU(): Instruction`
  Call Instruction.i8x16MaxU.
- `Instruction.i8x16MinS(): Instruction`
  Call Instruction.i8x16MinS.
- `Instruction.i8x16MinU(): Instruction`
  Call Instruction.i8x16MinU.
- `Instruction.i8x16NarrowI16x8s(): Instruction`
  Call Instruction.i8x16NarrowI16x8s.
- `Instruction.i8x16NarrowI16x8u(): Instruction`
  Call Instruction.i8x16NarrowI16x8u.
- `Instruction.i8x16Ne(): Instruction`
  Call Instruction.i8x16Ne.
- `Instruction.i8x16Neg(): Instruction`
  Call Instruction.i8x16Neg.
- `Instruction.i8x16Popcnt(): Instruction`
  Call Instruction.i8x16Popcnt.
- `Instruction.i8x16RelaxedLaneselect(): Instruction`
  Call Instruction.i8x16RelaxedLaneselect.
- `Instruction.i8x16RelaxedSwizzle(): Instruction`
  Call Instruction.i8x16RelaxedSwizzle.
- `Instruction.i8x16ReplaceLane(arg0: LaneIdx): Instruction`
  Call Instruction.i8x16ReplaceLane.
- `Instruction.i8x16Shl(): Instruction`
  Call Instruction.i8x16Shl.
- `Instruction.i8x16ShrS(): Instruction`
  Call Instruction.i8x16ShrS.
- `Instruction.i8x16ShrU(): Instruction`
  Call Instruction.i8x16ShrU.
- `Instruction.i8x16Shuffle(arg0: LaneIdx, arg1: LaneIdx, arg2: LaneIdx, arg3: LaneIdx, arg4: LaneIdx, arg5: LaneIdx, arg6: LaneIdx, arg7: LaneIdx, arg8: LaneIdx, arg9: LaneIdx, arg10: LaneIdx, arg11: LaneIdx, arg12: LaneIdx, arg13: LaneIdx, arg14: LaneIdx, arg15: LaneIdx): Instruction`
  Call Instruction.i8x16Shuffle.
- `Instruction.i8x16Splat(): Instruction`
  Call Instruction.i8x16Splat.
- `Instruction.i8x16Sub(): Instruction`
  Call Instruction.i8x16Sub.
- `Instruction.i8x16SubSatS(): Instruction`
  Call Instruction.i8x16SubSatS.
- `Instruction.i8x16SubSatU(): Instruction`
  Call Instruction.i8x16SubSatU.
- `Instruction.i8x16Swizzle(): Instruction`
  Call Instruction.i8x16Swizzle.
- `Instruction.if(arg0: BlockType, arg1: Array<Instruction>, arg2: Array<Instruction> | null): Instruction`
  Call Instruction.if.
- `Instruction.localGet(arg0: LocalIdx): Instruction`
  Call Instruction.localGet.
- `Instruction.localSet(arg0: LocalIdx): Instruction`
  Call Instruction.localSet.
- `Instruction.localTee(arg0: LocalIdx): Instruction`
  Call Instruction.localTee.
- `Instruction.loop(arg0: BlockType, arg1: Expr): Instruction`
  Call Instruction.loop.
- `Instruction.memoryAtomicNotify(arg0: MemArg): Instruction`
  Call Instruction.memoryAtomicNotify.
- `Instruction.memoryAtomicWait32(arg0: MemArg): Instruction`
  Call Instruction.memoryAtomicWait32.
- `Instruction.memoryAtomicWait64(arg0: MemArg): Instruction`
  Call Instruction.memoryAtomicWait64.
- `Instruction.memoryCopy(arg0: MemIdx, arg1: MemIdx): Instruction`
  Call Instruction.memoryCopy.
- `Instruction.memoryFill(arg0: MemIdx): Instruction`
  Call Instruction.memoryFill.
- `Instruction.memoryGrow(arg0: MemIdx): Instruction`
  Call Instruction.memoryGrow.
- `Instruction.memoryInit(arg0: DataIdx, arg1: MemIdx): Instruction`
  Call Instruction.memoryInit.
- `Instruction.memorySize(arg0: MemIdx): Instruction`
  Call Instruction.memorySize.
- `Instruction.nop(): Instruction`
  Call Instruction.nop.
- `Instruction.refAsNonNull(): Instruction`
  Call Instruction.refAsNonNull.
- `Instruction.refCast(arg0: boolean, arg1: HeapType): Instruction`
  Call Instruction.refCast.
- `Instruction.refCastDescEq(arg0: boolean, arg1: HeapType): Instruction`
  Call Instruction.refCastDescEq.
- `Instruction.refEq(): Instruction`
  Call Instruction.refEq.
- `Instruction.refFunc(arg0: FuncIdx): Instruction`
  Call Instruction.refFunc.
- `Instruction.refGetDesc(): Instruction`
  Call Instruction.refGetDesc.
- `Instruction.refI31(): Instruction`
  Call Instruction.refI31.
- `Instruction.refIsNull(): Instruction`
  Call Instruction.refIsNull.
- `Instruction.refNull(arg0: HeapType): Instruction`
  Call Instruction.refNull.
- `Instruction.refTest(arg0: boolean, arg1: HeapType): Instruction`
  Call Instruction.refTest.
- `Instruction.refTestDesc(arg0: boolean, arg1: HeapType): Instruction`
  Call Instruction.refTestDesc.
- `Instruction.return(): Instruction`
  Call Instruction.return.
- `Instruction.returnCall(arg0: FuncIdx): Instruction`
  Call Instruction.returnCall.
- `Instruction.returnCallIndirect(arg0: TypeIdx, arg1: TableIdx): Instruction`
  Call Instruction.returnCallIndirect.
- `Instruction.returnCallRef(arg0: TypeIdx): Instruction`
  Call Instruction.returnCallRef.
- `Instruction.select(types?: Array<ValType> | null): Instruction`
  Call Instruction.select.
- `Instruction.structGet(arg0: TypeIdx, arg1: U32): Instruction`
  Call Instruction.structGet.
- `Instruction.structGetS(arg0: TypeIdx, arg1: U32): Instruction`
  Call Instruction.structGetS.
- `Instruction.structGetU(arg0: TypeIdx, arg1: U32): Instruction`
  Call Instruction.structGetU.
- `Instruction.structNew(arg0: TypeIdx): Instruction`
  Call Instruction.structNew.
- `Instruction.structNewDefault(arg0: TypeIdx): Instruction`
  Call Instruction.structNewDefault.
- `Instruction.structSet(arg0: TypeIdx, arg1: U32): Instruction`
  Call Instruction.structSet.
- `Instruction.tableCopy(arg0: TableIdx, arg1: TableIdx): Instruction`
  Call Instruction.tableCopy.
- `Instruction.tableFill(arg0: TableIdx): Instruction`
  Call Instruction.tableFill.
- `Instruction.tableGet(arg0: TableIdx): Instruction`
  Call Instruction.tableGet.
- `Instruction.tableGrow(arg0: TableIdx): Instruction`
  Call Instruction.tableGrow.
- `Instruction.tableInit(arg0: ElemIdx, arg1: TableIdx): Instruction`
  Call Instruction.tableInit.
- `Instruction.tableSet(arg0: TableIdx): Instruction`
  Call Instruction.tableSet.
- `Instruction.tableSize(arg0: TableIdx): Instruction`
  Call Instruction.tableSize.
- `Instruction.throw(arg0: TagIdx): Instruction`
  Call Instruction.throw.
- `Instruction.throwRef(): Instruction`
  Call Instruction.throwRef.
- `Instruction.tryTable(arg0: BlockType, arg1: Array<Catch>, arg2: Expr): Instruction`
  Call Instruction.tryTable.
- `Instruction.unreachable(): Instruction`
  Call Instruction.unreachable.
- `Instruction.v128And(): Instruction`
  Call Instruction.v128And.
- `Instruction.v128Andnot(): Instruction`
  Call Instruction.v128Andnot.
- `Instruction.v128AnyTrue(): Instruction`
  Call Instruction.v128AnyTrue.
- `Instruction.v128Bitselect(): Instruction`
  Call Instruction.v128Bitselect.
- `Instruction.v128Const(arg0: number, arg1: number, arg2: number, arg3: number, arg4: number, arg5: number, arg6: number, arg7: number, arg8: number, arg9: number, arg10: number, arg11: number, arg12: number, arg13: number, arg14: number, arg15: number): Instruction`
  Call Instruction.v128Const.
- `Instruction.v128Load(arg0: MemArg): Instruction`
  Call Instruction.v128Load.
- `Instruction.v128Load16Lane(arg0: MemArg, arg1: LaneIdx): Instruction`
  Call Instruction.v128Load16Lane.
- `Instruction.v128Load16Splat(arg0: MemArg): Instruction`
  Call Instruction.v128Load16Splat.
- `Instruction.v128Load16x4s(arg0: MemArg): Instruction`
  Call Instruction.v128Load16x4s.
- `Instruction.v128Load16x4u(arg0: MemArg): Instruction`
  Call Instruction.v128Load16x4u.
- `Instruction.v128Load32Lane(arg0: MemArg, arg1: LaneIdx): Instruction`
  Call Instruction.v128Load32Lane.
- `Instruction.v128Load32Splat(arg0: MemArg): Instruction`
  Call Instruction.v128Load32Splat.
- `Instruction.v128Load32Zero(arg0: MemArg): Instruction`
  Call Instruction.v128Load32Zero.
- `Instruction.v128Load32x2s(arg0: MemArg): Instruction`
  Call Instruction.v128Load32x2s.
- `Instruction.v128Load32x2u(arg0: MemArg): Instruction`
  Call Instruction.v128Load32x2u.
- `Instruction.v128Load64Lane(arg0: MemArg, arg1: LaneIdx): Instruction`
  Call Instruction.v128Load64Lane.
- `Instruction.v128Load64Splat(arg0: MemArg): Instruction`
  Call Instruction.v128Load64Splat.
- `Instruction.v128Load64Zero(arg0: MemArg): Instruction`
  Call Instruction.v128Load64Zero.
- `Instruction.v128Load8Lane(arg0: MemArg, arg1: LaneIdx): Instruction`
  Call Instruction.v128Load8Lane.
- `Instruction.v128Load8Splat(arg0: MemArg): Instruction`
  Call Instruction.v128Load8Splat.
- `Instruction.v128Load8x8s(arg0: MemArg): Instruction`
  Call Instruction.v128Load8x8s.
- `Instruction.v128Load8x8u(arg0: MemArg): Instruction`
  Call Instruction.v128Load8x8u.
- `Instruction.v128Not(): Instruction`
  Call Instruction.v128Not.
- `Instruction.v128Or(): Instruction`
  Call Instruction.v128Or.
- `Instruction.v128Store(arg0: MemArg): Instruction`
  Call Instruction.v128Store.
- `Instruction.v128Store16Lane(arg0: MemArg, arg1: LaneIdx): Instruction`
  Call Instruction.v128Store16Lane.
- `Instruction.v128Store32Lane(arg0: MemArg, arg1: LaneIdx): Instruction`
  Call Instruction.v128Store32Lane.
- `Instruction.v128Store64Lane(arg0: MemArg, arg1: LaneIdx): Instruction`
  Call Instruction.v128Store64Lane.
- `Instruction.v128Store8Lane(arg0: MemArg, arg1: LaneIdx): Instruction`
  Call Instruction.v128Store8Lane.
- `Instruction.v128Xor(): Instruction`
  Call Instruction.v128Xor.
- `Instruction.show(value: Instruction): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `LabelIdx`
- `LabelIdx.inner(arg0: LabelIdx): number`
  Return the wrapped inner value from LabelIdx.
- `LabelIdx.new(arg0: number): LabelIdx`
  Create a LabelIdx value.
- `LabelIdx.show(value: LabelIdx): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `LaneIdx`
- `LaneIdx.inner(arg0: LaneIdx): number`
  Return the wrapped inner value from LaneIdx.
- `LaneIdx.new(arg0: number): LaneIdx`
  Create a LaneIdx value.
- `LaneIdx.show(value: LaneIdx): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Limits`
- `Limits.addrValtype(arg0: Limits): ValType`
  Call Limits.addrValtype.
- `Limits.i32(arg0: number, arg1: number | null): Limits`
  Call Limits.i32.
- `Limits.i64(arg0: bigint, arg1: bigint | null): Limits`
  Call Limits.i64.
- `Limits.memAddrBits(arg0: Limits): number`
  Call Limits.memAddrBits.
- `Limits.show(value: Limits): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `LoadOp`
- `LoadOp.f32Load(): LoadOp`
  Call LoadOp.f32Load.
- `LoadOp.f64Load(): LoadOp`
  Call LoadOp.f64Load.
- `LoadOp.i32AtomicLoad(): LoadOp`
  Call LoadOp.i32AtomicLoad.
- `LoadOp.i32AtomicLoad16U(): LoadOp`
  Call LoadOp.i32AtomicLoad16U.
- `LoadOp.i32AtomicLoad8U(): LoadOp`
  Call LoadOp.i32AtomicLoad8U.
- `LoadOp.i32Load(): LoadOp`
  Call LoadOp.i32Load.
- `LoadOp.i32Load16s(): LoadOp`
  Call LoadOp.i32Load16s.
- `LoadOp.i32Load16u(): LoadOp`
  Call LoadOp.i32Load16u.
- `LoadOp.i32Load8s(): LoadOp`
  Call LoadOp.i32Load8s.
- `LoadOp.i32Load8u(): LoadOp`
  Call LoadOp.i32Load8u.
- `LoadOp.i64AtomicLoad(): LoadOp`
  Call LoadOp.i64AtomicLoad.
- `LoadOp.i64AtomicLoad16U(): LoadOp`
  Call LoadOp.i64AtomicLoad16U.
- `LoadOp.i64AtomicLoad32U(): LoadOp`
  Call LoadOp.i64AtomicLoad32U.
- `LoadOp.i64AtomicLoad8U(): LoadOp`
  Call LoadOp.i64AtomicLoad8U.
- `LoadOp.i64Load(): LoadOp`
  Call LoadOp.i64Load.
- `LoadOp.i64Load16s(): LoadOp`
  Call LoadOp.i64Load16s.
- `LoadOp.i64Load16u(): LoadOp`
  Call LoadOp.i64Load16u.
- `LoadOp.i64Load32s(): LoadOp`
  Call LoadOp.i64Load32s.
- `LoadOp.i64Load32u(): LoadOp`
  Call LoadOp.i64Load32u.
- `LoadOp.i64Load8s(): LoadOp`
  Call LoadOp.i64Load8s.
- `LoadOp.i64Load8u(): LoadOp`
  Call LoadOp.i64Load8u.
- `LoadOp.v128Load(): LoadOp`
  Call LoadOp.v128Load.
- `LoadOp.v128Load16Splat(): LoadOp`
  Call LoadOp.v128Load16Splat.
- `LoadOp.v128Load16x4s(): LoadOp`
  Call LoadOp.v128Load16x4s.
- `LoadOp.v128Load16x4u(): LoadOp`
  Call LoadOp.v128Load16x4u.
- `LoadOp.v128Load32Splat(): LoadOp`
  Call LoadOp.v128Load32Splat.
- `LoadOp.v128Load32Zero(): LoadOp`
  Call LoadOp.v128Load32Zero.
- `LoadOp.v128Load32x2s(): LoadOp`
  Call LoadOp.v128Load32x2s.
- `LoadOp.v128Load32x2u(): LoadOp`
  Call LoadOp.v128Load32x2u.
- `LoadOp.v128Load64Splat(): LoadOp`
  Call LoadOp.v128Load64Splat.
- `LoadOp.v128Load64Zero(): LoadOp`
  Call LoadOp.v128Load64Zero.
- `LoadOp.v128Load8Splat(): LoadOp`
  Call LoadOp.v128Load8Splat.
- `LoadOp.v128Load8x8s(): LoadOp`
  Call LoadOp.v128Load8x8s.
- `LoadOp.v128Load8x8u(): LoadOp`
  Call LoadOp.v128Load8x8u.
- `LoadOp.show(value: LoadOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `LocalIdx`
- `LocalIdx.inner(arg0: LocalIdx): number`
  Return the wrapped inner value from LocalIdx.
- `LocalIdx.new(arg0: number): LocalIdx`
  Create a LocalIdx value.
- `LocalIdx.show(value: LocalIdx): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Locals`
- `Locals.new(arg0: number, arg1: ValType): Locals`
  Create a Locals value.
- `Locals.show(value: Locals): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `MemArg`
- `MemArg.new(arg0: U32, arg1: MemIdx | null, arg2: U64): MemArg`
  Create a MemArg value.
- `MemArg.show(value: MemArg): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `MemIdx`
- `MemIdx.inner(arg0: MemIdx): number`
  Return the wrapped inner value from MemIdx.
- `MemIdx.new(arg0: number): MemIdx`
  Create a MemIdx value.
- `MemIdx.show(value: MemIdx): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `MemSec`
- `MemSec.inner(arg0: MemSec): Array<MemType>`
  Return the wrapped inner value from MemSec.
- `MemSec.new(arg0: Array<MemType>): MemSec`
  Create a MemSec value.
- `MemSec.show(value: MemSec): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `MemType`
- `MemType.inner(arg0: MemType): Limits`
  Return the wrapped inner value from MemType.
- `MemType.new(arg0: Limits): MemType`
  Create a MemType value.
- `MemType.show(value: MemType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Module`
- `Module.new(customSecs?: Array<CustomSec>, typeSec?: TypeSec | null, importSec?: ImportSec | null, funcSec?: FuncSec | null, tableSec?: TableSec | null, memSec?: MemSec | null, tagSec?: TagSec | null, globalSec?: GlobalSec | null, exportSec?: ExportSec | null, startSec?: StartSec | null, elemSec?: ElemSec | null, dataCntSec?: DataCntSec | null, codeSec?: CodeSec | null, dataSec?: DataSec | null): Module`
  Create a Module value.
- `Module.withCodeSec(arg0: Module, arg1: CodeSec): Module`
  Return an updated value from Module.withCodeSec.
- `Module.withCustomSecs(arg0: Module, arg1: Array<CustomSec>): Module`
  Return an updated value from Module.withCustomSecs.
- `Module.withDataCntSec(arg0: Module, arg1: DataCntSec): Module`
  Return an updated value from Module.withDataCntSec.
- `Module.withDataSec(arg0: Module, arg1: DataSec): Module`
  Return an updated value from Module.withDataSec.
- `Module.withElemSec(arg0: Module, arg1: ElemSec): Module`
  Return an updated value from Module.withElemSec.
- `Module.withExportSec(arg0: Module, arg1: ExportSec): Module`
  Return an updated value from Module.withExportSec.
- `Module.withFuncSec(arg0: Module, arg1: FuncSec): Module`
  Return an updated value from Module.withFuncSec.
- `Module.withGlobalSec(arg0: Module, arg1: GlobalSec): Module`
  Return an updated value from Module.withGlobalSec.
- `Module.withImportSec(arg0: Module, arg1: ImportSec): Module`
  Return an updated value from Module.withImportSec.
- `Module.withMemSec(arg0: Module, arg1: MemSec): Module`
  Return an updated value from Module.withMemSec.
- `Module.withStartSec(arg0: Module, arg1: StartSec): Module`
  Return an updated value from Module.withStartSec.
- `Module.withTableSec(arg0: Module, arg1: TableSec): Module`
  Return an updated value from Module.withTableSec.
- `Module.withTagSec(arg0: Module, arg1: TagSec): Module`
  Return an updated value from Module.withTagSec.
- `Module.withTypeSec(arg0: Module, arg1: TypeSec): Module`
  Return an updated value from Module.withTypeSec.
- `Module.show(value: Module): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Mut`
- `Mut.const(): Mut`
  Call Mut.const.
- `Mut.var(): Mut`
  Call Mut.var.
- `Mut.show(value: Mut): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Name`
- `Name.inner(arg0: Name): OpaqueHandle<"StringView">`
  Return the wrapped inner value from Name.
- `Name.new(arg0: OpaqueHandle<"StringView">): Name`
  Create a Name value.
- `Name.show(value: Name): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `NumType`
- `NumType.f32(): NumType`
  Call NumType.f32.
- `NumType.f64(): NumType`
  Call NumType.f64.
- `NumType.i32(): NumType`
  Call NumType.i32.
- `NumType.i64(): NumType`
  Call NumType.i64.
- `NumType.show(value: NumType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `PackType`
- `PackType.i16(): PackType`
  Call PackType.i16.
- `PackType.i8(): PackType`
  Call PackType.i8.
- `PackType.show(value: PackType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `PrettyPrintContext`
- `PrettyPrintContext.indent(arg0: PrettyPrintContext, arg1: number): string`
  Call PrettyPrintContext.indent.
- `PrettyPrintContext.indentUnit(arg0: PrettyPrintContext): string`
  Call PrettyPrintContext.indentUnit.
- `PrettyPrintContext.new(maxLineWidth?: number, tabsOrSpaces?: TabsOrSpaces, tabWidth?: number, continuationIndent?: number, sourceIndentWidth?: number): PrettyPrintContext`
  Create a PrettyPrintContext value.
- `PrettyPrintContext.show(value: PrettyPrintContext): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `RecType`
- `RecType.getSubtype(arg0: RecType, arg1: number): SubType | null`
  Read data with RecType.getSubtype.
- `RecType.group(arg0: Array<SubType>): RecType`
  Call RecType.group.
- `RecType.new(arg0: SubType): RecType`
  Create a RecType value.
- `RecType.show(value: RecType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `RefType`
- `RefType.abs(arg0: AbsHeapType): RefType`
  Call RefType.abs.
- `RefType.getHeapType(arg0: RefType): HeapType`
  Read data with RefType.getHeapType.
- `RefType.isDefaultable(arg0: RefType): boolean`
  Call RefType.isDefaultable.
- `RefType.isNonNullable(arg0: RefType): boolean`
  Call RefType.isNonNullable.
- `RefType.isNullable(arg0: RefType): boolean`
  Call RefType.isNullable.
- `RefType.makeNullable(arg0: RefType): RefType`
  Call RefType.makeNullable.
- `RefType.new(arg0: boolean, arg1: HeapType): RefType`
  Create a RefType value.
- `RefType.show(value: RefType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ReplaceLaneOp`
- `ReplaceLaneOp.f32x4ReplaceLane(): ReplaceLaneOp`
  Call ReplaceLaneOp.f32x4ReplaceLane.
- `ReplaceLaneOp.f64x2ReplaceLane(): ReplaceLaneOp`
  Call ReplaceLaneOp.f64x2ReplaceLane.
- `ReplaceLaneOp.i16x8ReplaceLane(): ReplaceLaneOp`
  Call ReplaceLaneOp.i16x8ReplaceLane.
- `ReplaceLaneOp.i32x4ReplaceLane(): ReplaceLaneOp`
  Call ReplaceLaneOp.i32x4ReplaceLane.
- `ReplaceLaneOp.i64x2ReplaceLane(): ReplaceLaneOp`
  Call ReplaceLaneOp.i64x2ReplaceLane.
- `ReplaceLaneOp.i8x16ReplaceLane(): ReplaceLaneOp`
  Call ReplaceLaneOp.i8x16ReplaceLane.
- `ReplaceLaneOp.show(value: ReplaceLaneOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `S33`
- `S33.inner(arg0: S33): number`
  Return the wrapped inner value from S33.
- `S33.show(value: S33): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `StartSec`
- `StartSec.inner(arg0: StartSec): FuncIdx`
  Return the wrapped inner value from StartSec.
- `StartSec.new(arg0: FuncIdx): StartSec`
  Create a StartSec value.
- `StartSec.show(value: StartSec): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `StorageType`
- `StorageType.isPacked(arg0: StorageType): boolean`
  Call StorageType.isPacked.
- `StorageType.packType(arg0: PackType): StorageType`
  Call StorageType.packType.
- `StorageType.unpack(arg0: StorageType): ValType`
  Call StorageType.unpack.
- `StorageType.valType(arg0: ValType): StorageType`
  Call StorageType.valType.
- `StorageType.show(value: StorageType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `StoreOp`
- `StoreOp.f32Store(): StoreOp`
  Call StoreOp.f32Store.
- `StoreOp.f64Store(): StoreOp`
  Call StoreOp.f64Store.
- `StoreOp.i32AtomicStore(): StoreOp`
  Call StoreOp.i32AtomicStore.
- `StoreOp.i32AtomicStore16(): StoreOp`
  Call StoreOp.i32AtomicStore16.
- `StoreOp.i32AtomicStore8(): StoreOp`
  Call StoreOp.i32AtomicStore8.
- `StoreOp.i32Store(): StoreOp`
  Call StoreOp.i32Store.
- `StoreOp.i32Store16(): StoreOp`
  Call StoreOp.i32Store16.
- `StoreOp.i32Store8(): StoreOp`
  Call StoreOp.i32Store8.
- `StoreOp.i64AtomicStore(): StoreOp`
  Call StoreOp.i64AtomicStore.
- `StoreOp.i64AtomicStore16(): StoreOp`
  Call StoreOp.i64AtomicStore16.
- `StoreOp.i64AtomicStore32(): StoreOp`
  Call StoreOp.i64AtomicStore32.
- `StoreOp.i64AtomicStore8(): StoreOp`
  Call StoreOp.i64AtomicStore8.
- `StoreOp.i64Store(): StoreOp`
  Call StoreOp.i64Store.
- `StoreOp.i64Store16(): StoreOp`
  Call StoreOp.i64Store16.
- `StoreOp.i64Store32(): StoreOp`
  Call StoreOp.i64Store32.
- `StoreOp.i64Store8(): StoreOp`
  Call StoreOp.i64Store8.
- `StoreOp.v128Store(): StoreOp`
  Call StoreOp.v128Store.
- `StoreOp.show(value: StoreOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `SubType`
- `SubType.compType(arg0: CompType): SubType`
  Call SubType.compType.
- `SubType.getComptype(arg0: SubType): CompType`
  Read data with SubType.getComptype.
- `SubType.new(arg0: boolean, arg1: Array<TypeIdx>, arg2: CompType): SubType`
  Create a SubType value.
- `SubType.superTypes(arg0: SubType): Array<TypeIdx>`
  Call SubType.superTypes.
- `SubType.show(value: SubType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TExpr`
- `TExpr.inner(arg0: TExpr): Array<TInstr>`
  Return the wrapped inner value from TExpr.
- `TExpr.new(arg0: Array<TInstr>): TExpr`
  Create a TExpr value.
- `TExpr.toExpr(arg0: TExpr): Expr`
  Call TExpr.toExpr.
- `TExpr.show(value: TExpr): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TInstr`
- `TInstr.anyConvertExtern(arg0: TInstr): TInstr`
  Call TInstr.anyConvertExtern.
- `TInstr.arrayCopy(arg0: TypeIdx, arg1: TypeIdx, arg2: TInstr, arg3: TInstr, arg4: TInstr, arg5: TInstr, arg6: TInstr): TInstr`
  Call TInstr.arrayCopy.
- `TInstr.arrayFill(arg0: TypeIdx, arg1: TInstr, arg2: TInstr, arg3: TInstr, arg4: TInstr): TInstr`
  Call TInstr.arrayFill.
- `TInstr.arrayGet(arg0: TypeIdx, arg1: TInstr, arg2: TInstr): TInstr`
  Call TInstr.arrayGet.
- `TInstr.arrayGetS(arg0: TypeIdx, arg1: TInstr, arg2: TInstr): TInstr`
  Call TInstr.arrayGetS.
- `TInstr.arrayGetU(arg0: TypeIdx, arg1: TInstr, arg2: TInstr): TInstr`
  Call TInstr.arrayGetU.
- `TInstr.arrayInitData(arg0: TypeIdx, arg1: DataIdx, arg2: TInstr, arg3: TInstr, arg4: TInstr, arg5: TInstr): TInstr`
  Call TInstr.arrayInitData.
- `TInstr.arrayInitElem(arg0: TypeIdx, arg1: ElemIdx, arg2: TInstr, arg3: TInstr, arg4: TInstr, arg5: TInstr): TInstr`
  Call TInstr.arrayInitElem.
- `TInstr.arrayLen(arg0: TInstr): TInstr`
  Call TInstr.arrayLen.
- `TInstr.arrayNew(arg0: TypeIdx, arg1: TInstr, arg2: TInstr): TInstr`
  Call TInstr.arrayNew.
- `TInstr.arrayNewData(arg0: TypeIdx, arg1: DataIdx, arg2: TInstr, arg3: TInstr): TInstr`
  Call TInstr.arrayNewData.
- `TInstr.arrayNewDefault(arg0: TypeIdx, arg1: TInstr): TInstr`
  Call TInstr.arrayNewDefault.
- `TInstr.arrayNewElem(arg0: TypeIdx, arg1: ElemIdx, arg2: TInstr, arg3: TInstr): TInstr`
  Call TInstr.arrayNewElem.
- `TInstr.arrayNewFixed(arg0: TypeIdx, arg1: Array<TInstr>): TInstr`
  Call TInstr.arrayNewFixed.
- `TInstr.arraySet(arg0: TypeIdx, arg1: TInstr, arg2: TInstr, arg3: TInstr): TInstr`
  Call TInstr.arraySet.
- `TInstr.atomicCmpxchg(arg0: AtomicCmpxchgOp, arg1: MemArg, arg2: TInstr, arg3: TInstr, arg4: TInstr): TInstr`
  Call TInstr.atomicCmpxchg.
- `TInstr.atomicFence(): TInstr`
  Call TInstr.atomicFence.
- `TInstr.atomicRmw(arg0: AtomicRmwOp, arg1: MemArg, arg2: TInstr, arg3: TInstr): TInstr`
  Call TInstr.atomicRmw.
- `TInstr.binary(arg0: BinaryOp, arg1: TInstr, arg2: TInstr): TInstr`
  Call TInstr.binary.
- `TInstr.block(arg0: BlockType, arg1: TExpr): TInstr`
  Call TInstr.block.
- `TInstr.br(arg0: LabelIdx, arg1: Array<TInstr>): TInstr`
  Call TInstr.br.
- `TInstr.brIf(arg0: LabelIdx, arg1: TInstr, arg2: Array<TInstr>): TInstr`
  Call TInstr.brIf.
- `TInstr.brOnCast(arg0: LabelIdx, arg1: boolean, arg2: HeapType, arg3: boolean, arg4: HeapType, arg5: TInstr, arg6: Array<TInstr>): TInstr`
  Call TInstr.brOnCast.
- `TInstr.brOnCastFail(arg0: LabelIdx, arg1: boolean, arg2: HeapType, arg3: boolean, arg4: HeapType, arg5: TInstr, arg6: Array<TInstr>): TInstr`
  Call TInstr.brOnCastFail.
- `TInstr.brOnNonNull(arg0: LabelIdx, arg1: TInstr, arg2: Array<TInstr>): TInstr`
  Call TInstr.brOnNonNull.
- `TInstr.brOnNull(arg0: LabelIdx, arg1: TInstr, arg2: Array<TInstr>): TInstr`
  Call TInstr.brOnNull.
- `TInstr.brTable(arg0: Array<LabelIdx>, arg1: LabelIdx, arg2: TInstr, arg3: Array<TInstr>): TInstr`
  Call TInstr.brTable.
- `TInstr.call(arg0: FuncIdx, arg1: Array<TInstr>): TInstr`
  Call TInstr.call.
- `TInstr.callIndirect(arg0: TypeIdx, arg1: TableIdx, arg2: Array<TInstr>, arg3: TInstr): TInstr`
  Call TInstr.callIndirect.
- `TInstr.callRef(arg0: TypeIdx, arg1: Array<TInstr>, arg2: TInstr): TInstr`
  Call TInstr.callRef.
- `TInstr.dataDrop(arg0: DataIdx): TInstr`
  Call TInstr.dataDrop.
- `TInstr.drop(arg0: TInstr): TInstr`
  Call TInstr.drop.
- `TInstr.elemDrop(arg0: ElemIdx): TInstr`
  Call TInstr.elemDrop.
- `TInstr.externConvertAny(arg0: TInstr): TInstr`
  Call TInstr.externConvertAny.
- `TInstr.extractLane(arg0: ExtractLaneOp, arg1: LaneIdx, arg2: TInstr): TInstr`
  Call TInstr.extractLane.
- `TInstr.f32Const(arg0: F32): TInstr`
  Call TInstr.f32Const.
- `TInstr.f32x4Splat(arg0: TInstr): TInstr`
  Call TInstr.f32x4Splat.
- `TInstr.f64Const(arg0: F64): TInstr`
  Call TInstr.f64Const.
- `TInstr.f64x2Splat(arg0: TInstr): TInstr`
  Call TInstr.f64x2Splat.
- `TInstr.globalGet(arg0: GlobalIdx): TInstr`
  Call TInstr.globalGet.
- `TInstr.globalSet(arg0: GlobalIdx, arg1: TInstr): TInstr`
  Call TInstr.globalSet.
- `TInstr.i16x8Splat(arg0: TInstr): TInstr`
  Call TInstr.i16x8Splat.
- `TInstr.i31GetS(arg0: TInstr): TInstr`
  Call TInstr.i31GetS.
- `TInstr.i31GetU(arg0: TInstr): TInstr`
  Call TInstr.i31GetU.
- `TInstr.i32Const(arg0: I32): TInstr`
  Call TInstr.i32Const.
- `TInstr.i32x4Splat(arg0: TInstr): TInstr`
  Call TInstr.i32x4Splat.
- `TInstr.i64Const(arg0: I64): TInstr`
  Call TInstr.i64Const.
- `TInstr.i64x2Splat(arg0: TInstr): TInstr`
  Call TInstr.i64x2Splat.
- `TInstr.i8x16RelaxedSwizzle(arg0: TInstr, arg1: TInstr): TInstr`
  Call TInstr.i8x16RelaxedSwizzle.
- `TInstr.i8x16Shuffle(arg0: LaneIdx, arg1: LaneIdx, arg2: LaneIdx, arg3: LaneIdx, arg4: LaneIdx, arg5: LaneIdx, arg6: LaneIdx, arg7: LaneIdx, arg8: LaneIdx, arg9: LaneIdx, arg10: LaneIdx, arg11: LaneIdx, arg12: LaneIdx, arg13: LaneIdx, arg14: LaneIdx, arg15: LaneIdx, arg16: TInstr, arg17: TInstr): TInstr`
  Call TInstr.i8x16Shuffle.
- `TInstr.i8x16Splat(arg0: TInstr): TInstr`
  Call TInstr.i8x16Splat.
- `TInstr.i8x16Swizzle(arg0: TInstr, arg1: TInstr): TInstr`
  Call TInstr.i8x16Swizzle.
- `TInstr.if(arg0: BlockType, arg1: TInstr, arg2: TExpr, arg3: TExpr | null): TInstr`
  Call TInstr.if.
- `TInstr.load(arg0: LoadOp, arg1: MemArg, arg2: TInstr): TInstr`
  Call TInstr.load.
- `TInstr.localGet(arg0: LocalIdx): TInstr`
  Call TInstr.localGet.
- `TInstr.localSet(arg0: LocalIdx, arg1: TInstr): TInstr`
  Call TInstr.localSet.
- `TInstr.localTee(arg0: LocalIdx, arg1: TInstr): TInstr`
  Call TInstr.localTee.
- `TInstr.loop(arg0: BlockType, arg1: TExpr): TInstr`
  Call TInstr.loop.
- `TInstr.memoryAtomicNotify(arg0: MemArg, arg1: TInstr, arg2: TInstr): TInstr`
  Call TInstr.memoryAtomicNotify.
- `TInstr.memoryAtomicWait32(arg0: MemArg, arg1: TInstr, arg2: TInstr, arg3: TInstr): TInstr`
  Call TInstr.memoryAtomicWait32.
- `TInstr.memoryAtomicWait64(arg0: MemArg, arg1: TInstr, arg2: TInstr, arg3: TInstr): TInstr`
  Call TInstr.memoryAtomicWait64.
- `TInstr.memoryCopy(arg0: MemIdx, arg1: MemIdx, arg2: TInstr, arg3: TInstr, arg4: TInstr): TInstr`
  Call TInstr.memoryCopy.
- `TInstr.memoryFill(arg0: MemIdx, arg1: TInstr, arg2: TInstr, arg3: TInstr): TInstr`
  Call TInstr.memoryFill.
- `TInstr.memoryGrow(arg0: MemIdx, arg1: TInstr): TInstr`
  Call TInstr.memoryGrow.
- `TInstr.memoryInit(arg0: DataIdx, arg1: MemIdx, arg2: TInstr, arg3: TInstr, arg4: TInstr): TInstr`
  Call TInstr.memoryInit.
- `TInstr.memorySize(arg0: MemIdx): TInstr`
  Call TInstr.memorySize.
- `TInstr.nop(): TInstr`
  Call TInstr.nop.
- `TInstr.refAsNonNull(arg0: TInstr): TInstr`
  Call TInstr.refAsNonNull.
- `TInstr.refCast(arg0: boolean, arg1: HeapType, arg2: TInstr): TInstr`
  Call TInstr.refCast.
- `TInstr.refCastDescEq(arg0: boolean, arg1: HeapType, arg2: TInstr): TInstr`
  Call TInstr.refCastDescEq.
- `TInstr.refEq(arg0: TInstr, arg1: TInstr): TInstr`
  Call TInstr.refEq.
- `TInstr.refFunc(arg0: FuncIdx): TInstr`
  Call TInstr.refFunc.
- `TInstr.refGetDesc(arg0: TInstr): TInstr`
  Call TInstr.refGetDesc.
- `TInstr.refI31(arg0: TInstr): TInstr`
  Call TInstr.refI31.
- `TInstr.refIsNull(arg0: TInstr): TInstr`
  Call TInstr.refIsNull.
- `TInstr.refNull(arg0: HeapType): TInstr`
  Call TInstr.refNull.
- `TInstr.refTest(arg0: boolean, arg1: HeapType, arg2: TInstr): TInstr`
  Call TInstr.refTest.
- `TInstr.refTestDesc(arg0: boolean, arg1: HeapType, arg2: TInstr): TInstr`
  Call TInstr.refTestDesc.
- `TInstr.replaceLane(arg0: ReplaceLaneOp, arg1: LaneIdx, arg2: TInstr, arg3: TInstr): TInstr`
  Call TInstr.replaceLane.
- `TInstr.return(arg0: Array<TInstr>): TInstr`
  Call TInstr.return.
- `TInstr.returnCall(arg0: FuncIdx, arg1: Array<TInstr>): TInstr`
  Call TInstr.returnCall.
- `TInstr.returnCallIndirect(arg0: TypeIdx, arg1: TableIdx, arg2: Array<TInstr>, arg3: TInstr): TInstr`
  Call TInstr.returnCallIndirect.
- `TInstr.returnCallRef(arg0: TypeIdx, arg1: Array<TInstr>, arg2: TInstr): TInstr`
  Call TInstr.returnCallRef.
- `TInstr.select(arg0: Array<ValType> | null, arg1: TInstr, arg2: TInstr, arg3: TInstr): TInstr`
  Call TInstr.select.
- `TInstr.store(arg0: StoreOp, arg1: MemArg, arg2: TInstr, arg3: TInstr): TInstr`
  Call TInstr.store.
- `TInstr.structGet(arg0: TypeIdx, arg1: U32, arg2: TInstr): TInstr`
  Call TInstr.structGet.
- `TInstr.structGetS(arg0: TypeIdx, arg1: U32, arg2: TInstr): TInstr`
  Call TInstr.structGetS.
- `TInstr.structGetU(arg0: TypeIdx, arg1: U32, arg2: TInstr): TInstr`
  Call TInstr.structGetU.
- `TInstr.structNew(arg0: TypeIdx, arg1: Array<TInstr>): TInstr`
  Call TInstr.structNew.
- `TInstr.structNewDefault(arg0: TypeIdx): TInstr`
  Call TInstr.structNewDefault.
- `TInstr.structSet(arg0: TypeIdx, arg1: U32, arg2: TInstr, arg3: TInstr): TInstr`
  Call TInstr.structSet.
- `TInstr.tableCopy(arg0: TableIdx, arg1: TableIdx, arg2: TInstr, arg3: TInstr, arg4: TInstr): TInstr`
  Call TInstr.tableCopy.
- `TInstr.tableFill(arg0: TableIdx, arg1: TInstr, arg2: TInstr, arg3: TInstr): TInstr`
  Call TInstr.tableFill.
- `TInstr.tableGet(arg0: TableIdx, arg1: TInstr): TInstr`
  Call TInstr.tableGet.
- `TInstr.tableGrow(arg0: TableIdx, arg1: TInstr, arg2: TInstr): TInstr`
  Call TInstr.tableGrow.
- `TInstr.tableInit(arg0: ElemIdx, arg1: TableIdx, arg2: TInstr, arg3: TInstr, arg4: TInstr): TInstr`
  Call TInstr.tableInit.
- `TInstr.tableSet(arg0: TableIdx, arg1: TInstr, arg2: TInstr): TInstr`
  Call TInstr.tableSet.
- `TInstr.tableSize(arg0: TableIdx): TInstr`
  Call TInstr.tableSize.
- `TInstr.throw(arg0: TagIdx, arg1: Array<TInstr>): TInstr`
  Call TInstr.throw.
- `TInstr.throwRef(arg0: TInstr): TInstr`
  Call TInstr.throwRef.
- `TInstr.tryTable(arg0: BlockType, arg1: Array<Catch>, arg2: TExpr): TInstr`
  Call TInstr.tryTable.
- `TInstr.unary(arg0: UnaryOp, arg1: TInstr): TInstr`
  Call TInstr.unary.
- `TInstr.unreachable(): TInstr`
  Call TInstr.unreachable.
- `TInstr.v128Const(arg0: number, arg1: number, arg2: number, arg3: number, arg4: number, arg5: number, arg6: number, arg7: number, arg8: number, arg9: number, arg10: number, arg11: number, arg12: number, arg13: number, arg14: number, arg15: number): TInstr`
  Call TInstr.v128Const.
- `TInstr.v128LoadLane(arg0: V128LoadLaneOp, arg1: MemArg, arg2: LaneIdx, arg3: TInstr, arg4: TInstr): TInstr`
  Call TInstr.v128LoadLane.
- `TInstr.v128Shift(arg0: V128ShiftOp, arg1: TInstr, arg2: TInstr): TInstr`
  Call TInstr.v128Shift.
- `TInstr.v128StoreLane(arg0: V128StoreLaneOp, arg1: MemArg, arg2: LaneIdx, arg3: TInstr, arg4: TInstr): TInstr`
  Call TInstr.v128StoreLane.
- `TInstr.v128Ternary(arg0: V128TernaryOp, arg1: TInstr, arg2: TInstr, arg3: TInstr): TInstr`
  Call TInstr.v128Ternary.
- `TInstr.show(value: TInstr): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TInstrKind`
- `TInstrKind.show(value: TInstrKind): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Table`
- `Table.new(arg0: TableType, arg1: Expr | null): Table`
  Create a Table value.
- `Table.show(value: Table): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TableIdx`
- `TableIdx.inner(arg0: TableIdx): number`
  Return the wrapped inner value from TableIdx.
- `TableIdx.new(arg0: number): TableIdx`
  Create a TableIdx value.
- `TableIdx.show(value: TableIdx): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TableSec`
- `TableSec.inner(arg0: TableSec): Array<Table>`
  Return the wrapped inner value from TableSec.
- `TableSec.new(arg0: Array<Table>): TableSec`
  Create a TableSec value.
- `TableSec.show(value: TableSec): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TableType`
- `TableType.new(arg0: RefType, arg1: Limits): TableType`
  Create a TableType value.
- `TableType.show(value: TableType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TabsOrSpaces`
- `TabsOrSpaces.spaces(): TabsOrSpaces`
  Call TabsOrSpaces.spaces.
- `TabsOrSpaces.tabs(): TabsOrSpaces`
  Call TabsOrSpaces.tabs.
- `TabsOrSpaces.show(value: TabsOrSpaces): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TagIdx`
- `TagIdx.inner(arg0: TagIdx): number`
  Return the wrapped inner value from TagIdx.
- `TagIdx.new(arg0: number): TagIdx`
  Create a TagIdx value.
- `TagIdx.show(value: TagIdx): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TagSec`
- `TagSec.inner(arg0: TagSec): Array<TagType>`
  Return the wrapped inner value from TagSec.
- `TagSec.new(arg0: Array<TagType>): TagSec`
  Create a TagSec value.
- `TagSec.show(value: TagSec): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TagType`
- `TagType.inner(arg0: TagType): TypeIdx`
  Return the wrapped inner value from TagType.
- `TagType.new(arg0: TypeIdx): TagType`
  Create a TagType value.
- `TagType.show(value: TagType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TypeIdx`
- `TypeIdx.new(arg0: number): TypeIdx`
  Create a TypeIdx value.
- `TypeIdx.rec(arg0: number): TypeIdx`
  Call TypeIdx.rec.
- `TypeIdx.show(value: TypeIdx): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TypeSec`
- `TypeSec.inner(arg0: TypeSec): Array<RecType>`
  Return the wrapped inner value from TypeSec.
- `TypeSec.new(arg0: Array<RecType>): TypeSec`
  Create a TypeSec value.
- `TypeSec.show(value: TypeSec): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `U32`
- `U32.inner(arg0: U32): number`
  Return the wrapped inner value from U32.
- `U32.show(value: U32): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `U64`
- `U64.inner(arg0: U64): bigint`
  Return the wrapped inner value from U64.
- `U64.show(value: U64): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `UnaryOp`
- `UnaryOp.f32Abs(): UnaryOp`
  Call UnaryOp.f32Abs.
- `UnaryOp.f32Ceil(): UnaryOp`
  Call UnaryOp.f32Ceil.
- `UnaryOp.f32ConvertI32s(): UnaryOp`
  Call UnaryOp.f32ConvertI32s.
- `UnaryOp.f32ConvertI32u(): UnaryOp`
  Call UnaryOp.f32ConvertI32u.
- `UnaryOp.f32ConvertI64s(): UnaryOp`
  Call UnaryOp.f32ConvertI64s.
- `UnaryOp.f32ConvertI64u(): UnaryOp`
  Call UnaryOp.f32ConvertI64u.
- `UnaryOp.f32DemoteF64(): UnaryOp`
  Call UnaryOp.f32DemoteF64.
- `UnaryOp.f32Floor(): UnaryOp`
  Call UnaryOp.f32Floor.
- `UnaryOp.f32Nearest(): UnaryOp`
  Call UnaryOp.f32Nearest.
- `UnaryOp.f32Neg(): UnaryOp`
  Call UnaryOp.f32Neg.
- `UnaryOp.f32ReinterpretI32(): UnaryOp`
  Call UnaryOp.f32ReinterpretI32.
- `UnaryOp.f32Sqrt(): UnaryOp`
  Call UnaryOp.f32Sqrt.
- `UnaryOp.f32Trunc(): UnaryOp`
  Call UnaryOp.f32Trunc.
- `UnaryOp.f32x4Abs(): UnaryOp`
  Call UnaryOp.f32x4Abs.
- `UnaryOp.f32x4Ceil(): UnaryOp`
  Call UnaryOp.f32x4Ceil.
- `UnaryOp.f32x4ConvertI32x4s(): UnaryOp`
  Call UnaryOp.f32x4ConvertI32x4s.
- `UnaryOp.f32x4ConvertI32x4u(): UnaryOp`
  Call UnaryOp.f32x4ConvertI32x4u.
- `UnaryOp.f32x4DemoteF64x2Zero(): UnaryOp`
  Call UnaryOp.f32x4DemoteF64x2Zero.
- `UnaryOp.f32x4Floor(): UnaryOp`
  Call UnaryOp.f32x4Floor.
- `UnaryOp.f32x4Nearest(): UnaryOp`
  Call UnaryOp.f32x4Nearest.
- `UnaryOp.f32x4Neg(): UnaryOp`
  Call UnaryOp.f32x4Neg.
- `UnaryOp.f32x4Sqrt(): UnaryOp`
  Call UnaryOp.f32x4Sqrt.
- `UnaryOp.f32x4Trunc(): UnaryOp`
  Call UnaryOp.f32x4Trunc.
- `UnaryOp.f64Abs(): UnaryOp`
  Call UnaryOp.f64Abs.
- `UnaryOp.f64Ceil(): UnaryOp`
  Call UnaryOp.f64Ceil.
- `UnaryOp.f64ConvertI32s(): UnaryOp`
  Call UnaryOp.f64ConvertI32s.
- `UnaryOp.f64ConvertI32u(): UnaryOp`
  Call UnaryOp.f64ConvertI32u.
- `UnaryOp.f64ConvertI64s(): UnaryOp`
  Call UnaryOp.f64ConvertI64s.
- `UnaryOp.f64ConvertI64u(): UnaryOp`
  Call UnaryOp.f64ConvertI64u.
- `UnaryOp.f64Floor(): UnaryOp`
  Call UnaryOp.f64Floor.
- `UnaryOp.f64Nearest(): UnaryOp`
  Call UnaryOp.f64Nearest.
- `UnaryOp.f64Neg(): UnaryOp`
  Call UnaryOp.f64Neg.
- `UnaryOp.f64PromoteF32(): UnaryOp`
  Call UnaryOp.f64PromoteF32.
- `UnaryOp.f64ReinterpretI64(): UnaryOp`
  Call UnaryOp.f64ReinterpretI64.
- `UnaryOp.f64Sqrt(): UnaryOp`
  Call UnaryOp.f64Sqrt.
- `UnaryOp.f64Trunc(): UnaryOp`
  Call UnaryOp.f64Trunc.
- `UnaryOp.f64x2Abs(): UnaryOp`
  Call UnaryOp.f64x2Abs.
- `UnaryOp.f64x2Ceil(): UnaryOp`
  Call UnaryOp.f64x2Ceil.
- `UnaryOp.f64x2ConvertLowI32x4s(): UnaryOp`
  Call UnaryOp.f64x2ConvertLowI32x4s.
- `UnaryOp.f64x2ConvertLowI32x4u(): UnaryOp`
  Call UnaryOp.f64x2ConvertLowI32x4u.
- `UnaryOp.f64x2Floor(): UnaryOp`
  Call UnaryOp.f64x2Floor.
- `UnaryOp.f64x2Nearest(): UnaryOp`
  Call UnaryOp.f64x2Nearest.
- `UnaryOp.f64x2Neg(): UnaryOp`
  Call UnaryOp.f64x2Neg.
- `UnaryOp.f64x2PromoteLowF32x4(): UnaryOp`
  Call UnaryOp.f64x2PromoteLowF32x4.
- `UnaryOp.f64x2Sqrt(): UnaryOp`
  Call UnaryOp.f64x2Sqrt.
- `UnaryOp.f64x2Trunc(): UnaryOp`
  Call UnaryOp.f64x2Trunc.
- `UnaryOp.i16x8Abs(): UnaryOp`
  Call UnaryOp.i16x8Abs.
- `UnaryOp.i16x8AllTrue(): UnaryOp`
  Call UnaryOp.i16x8AllTrue.
- `UnaryOp.i16x8Bitmask(): UnaryOp`
  Call UnaryOp.i16x8Bitmask.
- `UnaryOp.i16x8ExtaddPairwiseI8x16s(): UnaryOp`
  Call UnaryOp.i16x8ExtaddPairwiseI8x16s.
- `UnaryOp.i16x8ExtaddPairwiseI8x16u(): UnaryOp`
  Call UnaryOp.i16x8ExtaddPairwiseI8x16u.
- `UnaryOp.i16x8ExtendHighI8x16s(): UnaryOp`
  Call UnaryOp.i16x8ExtendHighI8x16s.
- `UnaryOp.i16x8ExtendHighI8x16u(): UnaryOp`
  Call UnaryOp.i16x8ExtendHighI8x16u.
- `UnaryOp.i16x8ExtendLowI8x16s(): UnaryOp`
  Call UnaryOp.i16x8ExtendLowI8x16s.
- `UnaryOp.i16x8ExtendLowI8x16u(): UnaryOp`
  Call UnaryOp.i16x8ExtendLowI8x16u.
- `UnaryOp.i16x8Neg(): UnaryOp`
  Call UnaryOp.i16x8Neg.
- `UnaryOp.i32Clz(): UnaryOp`
  Call UnaryOp.i32Clz.
- `UnaryOp.i32Ctz(): UnaryOp`
  Call UnaryOp.i32Ctz.
- `UnaryOp.i32Eqz(): UnaryOp`
  Call UnaryOp.i32Eqz.
- `UnaryOp.i32Extend16s(): UnaryOp`
  Call UnaryOp.i32Extend16s.
- `UnaryOp.i32Extend8s(): UnaryOp`
  Call UnaryOp.i32Extend8s.
- `UnaryOp.i32Popcnt(): UnaryOp`
  Call UnaryOp.i32Popcnt.
- `UnaryOp.i32ReinterpretF32(): UnaryOp`
  Call UnaryOp.i32ReinterpretF32.
- `UnaryOp.i32TruncF32s(): UnaryOp`
  Call UnaryOp.i32TruncF32s.
- `UnaryOp.i32TruncF32u(): UnaryOp`
  Call UnaryOp.i32TruncF32u.
- `UnaryOp.i32TruncF64s(): UnaryOp`
  Call UnaryOp.i32TruncF64s.
- `UnaryOp.i32TruncF64u(): UnaryOp`
  Call UnaryOp.i32TruncF64u.
- `UnaryOp.i32TruncSatF32s(): UnaryOp`
  Call UnaryOp.i32TruncSatF32s.
- `UnaryOp.i32TruncSatF32u(): UnaryOp`
  Call UnaryOp.i32TruncSatF32u.
- `UnaryOp.i32TruncSatF64s(): UnaryOp`
  Call UnaryOp.i32TruncSatF64s.
- `UnaryOp.i32TruncSatF64u(): UnaryOp`
  Call UnaryOp.i32TruncSatF64u.
- `UnaryOp.i32WrapI64(): UnaryOp`
  Call UnaryOp.i32WrapI64.
- `UnaryOp.i32x4Abs(): UnaryOp`
  Call UnaryOp.i32x4Abs.
- `UnaryOp.i32x4AllTrue(): UnaryOp`
  Call UnaryOp.i32x4AllTrue.
- `UnaryOp.i32x4Bitmask(): UnaryOp`
  Call UnaryOp.i32x4Bitmask.
- `UnaryOp.i32x4ExtaddPairwiseI16x8s(): UnaryOp`
  Call UnaryOp.i32x4ExtaddPairwiseI16x8s.
- `UnaryOp.i32x4ExtaddPairwiseI16x8u(): UnaryOp`
  Call UnaryOp.i32x4ExtaddPairwiseI16x8u.
- `UnaryOp.i32x4ExtendHighI16x8s(): UnaryOp`
  Call UnaryOp.i32x4ExtendHighI16x8s.
- `UnaryOp.i32x4ExtendHighI16x8u(): UnaryOp`
  Call UnaryOp.i32x4ExtendHighI16x8u.
- `UnaryOp.i32x4ExtendLowI16x8s(): UnaryOp`
  Call UnaryOp.i32x4ExtendLowI16x8s.
- `UnaryOp.i32x4ExtendLowI16x8u(): UnaryOp`
  Call UnaryOp.i32x4ExtendLowI16x8u.
- `UnaryOp.i32x4Neg(): UnaryOp`
  Call UnaryOp.i32x4Neg.
- `UnaryOp.i32x4RelaxedTruncF32x4s(): UnaryOp`
  Call UnaryOp.i32x4RelaxedTruncF32x4s.
- `UnaryOp.i32x4RelaxedTruncF32x4u(): UnaryOp`
  Call UnaryOp.i32x4RelaxedTruncF32x4u.
- `UnaryOp.i32x4RelaxedTruncZeroF64x2s(): UnaryOp`
  Call UnaryOp.i32x4RelaxedTruncZeroF64x2s.
- `UnaryOp.i32x4RelaxedTruncZeroF64x2u(): UnaryOp`
  Call UnaryOp.i32x4RelaxedTruncZeroF64x2u.
- `UnaryOp.i32x4TruncSatF32x4s(): UnaryOp`
  Call UnaryOp.i32x4TruncSatF32x4s.
- `UnaryOp.i32x4TruncSatF32x4u(): UnaryOp`
  Call UnaryOp.i32x4TruncSatF32x4u.
- `UnaryOp.i32x4TruncSatF64x2sZero(): UnaryOp`
  Call UnaryOp.i32x4TruncSatF64x2sZero.
- `UnaryOp.i32x4TruncSatF64x2uZero(): UnaryOp`
  Call UnaryOp.i32x4TruncSatF64x2uZero.
- `UnaryOp.i64Clz(): UnaryOp`
  Call UnaryOp.i64Clz.
- `UnaryOp.i64Ctz(): UnaryOp`
  Call UnaryOp.i64Ctz.
- `UnaryOp.i64Eqz(): UnaryOp`
  Call UnaryOp.i64Eqz.
- `UnaryOp.i64Extend16s(): UnaryOp`
  Call UnaryOp.i64Extend16s.
- `UnaryOp.i64Extend32s(): UnaryOp`
  Call UnaryOp.i64Extend32s.
- `UnaryOp.i64Extend8s(): UnaryOp`
  Call UnaryOp.i64Extend8s.
- `UnaryOp.i64ExtendI32s(): UnaryOp`
  Call UnaryOp.i64ExtendI32s.
- `UnaryOp.i64ExtendI32u(): UnaryOp`
  Call UnaryOp.i64ExtendI32u.
- `UnaryOp.i64Popcnt(): UnaryOp`
  Call UnaryOp.i64Popcnt.
- `UnaryOp.i64ReinterpretF64(): UnaryOp`
  Call UnaryOp.i64ReinterpretF64.
- `UnaryOp.i64TruncF32s(): UnaryOp`
  Call UnaryOp.i64TruncF32s.
- `UnaryOp.i64TruncF32u(): UnaryOp`
  Call UnaryOp.i64TruncF32u.
- `UnaryOp.i64TruncF64s(): UnaryOp`
  Call UnaryOp.i64TruncF64s.
- `UnaryOp.i64TruncF64u(): UnaryOp`
  Call UnaryOp.i64TruncF64u.
- `UnaryOp.i64TruncSatF32s(): UnaryOp`
  Call UnaryOp.i64TruncSatF32s.
- `UnaryOp.i64TruncSatF32u(): UnaryOp`
  Call UnaryOp.i64TruncSatF32u.
- `UnaryOp.i64TruncSatF64s(): UnaryOp`
  Call UnaryOp.i64TruncSatF64s.
- `UnaryOp.i64TruncSatF64u(): UnaryOp`
  Call UnaryOp.i64TruncSatF64u.
- `UnaryOp.i64x2Abs(): UnaryOp`
  Call UnaryOp.i64x2Abs.
- `UnaryOp.i64x2AllTrue(): UnaryOp`
  Call UnaryOp.i64x2AllTrue.
- `UnaryOp.i64x2Bitmask(): UnaryOp`
  Call UnaryOp.i64x2Bitmask.
- `UnaryOp.i64x2ExtendHighI32x4s(): UnaryOp`
  Call UnaryOp.i64x2ExtendHighI32x4s.
- `UnaryOp.i64x2ExtendHighI32x4u(): UnaryOp`
  Call UnaryOp.i64x2ExtendHighI32x4u.
- `UnaryOp.i64x2ExtendLowI32x4s(): UnaryOp`
  Call UnaryOp.i64x2ExtendLowI32x4s.
- `UnaryOp.i64x2ExtendLowI32x4u(): UnaryOp`
  Call UnaryOp.i64x2ExtendLowI32x4u.
- `UnaryOp.i64x2Neg(): UnaryOp`
  Call UnaryOp.i64x2Neg.
- `UnaryOp.i8x16Abs(): UnaryOp`
  Call UnaryOp.i8x16Abs.
- `UnaryOp.i8x16AllTrue(): UnaryOp`
  Call UnaryOp.i8x16AllTrue.
- `UnaryOp.i8x16Bitmask(): UnaryOp`
  Call UnaryOp.i8x16Bitmask.
- `UnaryOp.i8x16Neg(): UnaryOp`
  Call UnaryOp.i8x16Neg.
- `UnaryOp.i8x16Popcnt(): UnaryOp`
  Call UnaryOp.i8x16Popcnt.
- `UnaryOp.v128AnyTrue(): UnaryOp`
  Call UnaryOp.v128AnyTrue.
- `UnaryOp.v128Not(): UnaryOp`
  Call UnaryOp.v128Not.
- `UnaryOp.show(value: UnaryOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `V128LoadLaneOp`
- `V128LoadLaneOp.v128Load16Lane(): V128LoadLaneOp`
  Call V128LoadLaneOp.v128Load16Lane.
- `V128LoadLaneOp.v128Load32Lane(): V128LoadLaneOp`
  Call V128LoadLaneOp.v128Load32Lane.
- `V128LoadLaneOp.v128Load64Lane(): V128LoadLaneOp`
  Call V128LoadLaneOp.v128Load64Lane.
- `V128LoadLaneOp.v128Load8Lane(): V128LoadLaneOp`
  Call V128LoadLaneOp.v128Load8Lane.
- `V128LoadLaneOp.show(value: V128LoadLaneOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `V128ShiftOp`
- `V128ShiftOp.i16x8Shl(): V128ShiftOp`
  Call V128ShiftOp.i16x8Shl.
- `V128ShiftOp.i16x8ShrS(): V128ShiftOp`
  Call V128ShiftOp.i16x8ShrS.
- `V128ShiftOp.i16x8ShrU(): V128ShiftOp`
  Call V128ShiftOp.i16x8ShrU.
- `V128ShiftOp.i32x4Shl(): V128ShiftOp`
  Call V128ShiftOp.i32x4Shl.
- `V128ShiftOp.i32x4ShrS(): V128ShiftOp`
  Call V128ShiftOp.i32x4ShrS.
- `V128ShiftOp.i32x4ShrU(): V128ShiftOp`
  Call V128ShiftOp.i32x4ShrU.
- `V128ShiftOp.i64x2Shl(): V128ShiftOp`
  Call V128ShiftOp.i64x2Shl.
- `V128ShiftOp.i64x2ShrS(): V128ShiftOp`
  Call V128ShiftOp.i64x2ShrS.
- `V128ShiftOp.i64x2ShrU(): V128ShiftOp`
  Call V128ShiftOp.i64x2ShrU.
- `V128ShiftOp.i8x16Shl(): V128ShiftOp`
  Call V128ShiftOp.i8x16Shl.
- `V128ShiftOp.i8x16ShrS(): V128ShiftOp`
  Call V128ShiftOp.i8x16ShrS.
- `V128ShiftOp.i8x16ShrU(): V128ShiftOp`
  Call V128ShiftOp.i8x16ShrU.
- `V128ShiftOp.show(value: V128ShiftOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `V128StoreLaneOp`
- `V128StoreLaneOp.v128Store16Lane(): V128StoreLaneOp`
  Call V128StoreLaneOp.v128Store16Lane.
- `V128StoreLaneOp.v128Store32Lane(): V128StoreLaneOp`
  Call V128StoreLaneOp.v128Store32Lane.
- `V128StoreLaneOp.v128Store64Lane(): V128StoreLaneOp`
  Call V128StoreLaneOp.v128Store64Lane.
- `V128StoreLaneOp.v128Store8Lane(): V128StoreLaneOp`
  Call V128StoreLaneOp.v128Store8Lane.
- `V128StoreLaneOp.show(value: V128StoreLaneOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `V128TernaryOp`
- `V128TernaryOp.f32x4RelaxedMadd(): V128TernaryOp`
  Call V128TernaryOp.f32x4RelaxedMadd.
- `V128TernaryOp.f32x4RelaxedNmadd(): V128TernaryOp`
  Call V128TernaryOp.f32x4RelaxedNmadd.
- `V128TernaryOp.f64x2RelaxedMadd(): V128TernaryOp`
  Call V128TernaryOp.f64x2RelaxedMadd.
- `V128TernaryOp.f64x2RelaxedNmadd(): V128TernaryOp`
  Call V128TernaryOp.f64x2RelaxedNmadd.
- `V128TernaryOp.i16x8RelaxedLaneselect(): V128TernaryOp`
  Call V128TernaryOp.i16x8RelaxedLaneselect.
- `V128TernaryOp.i32x4RelaxedDotI8x16i7x16AddS(): V128TernaryOp`
  Call V128TernaryOp.i32x4RelaxedDotI8x16i7x16AddS.
- `V128TernaryOp.i32x4RelaxedLaneselect(): V128TernaryOp`
  Call V128TernaryOp.i32x4RelaxedLaneselect.
- `V128TernaryOp.i64x2RelaxedLaneselect(): V128TernaryOp`
  Call V128TernaryOp.i64x2RelaxedLaneselect.
- `V128TernaryOp.i8x16RelaxedLaneselect(): V128TernaryOp`
  Call V128TernaryOp.i8x16RelaxedLaneselect.
- `V128TernaryOp.v128Bitselect(): V128TernaryOp`
  Call V128TernaryOp.v128Bitselect.
- `V128TernaryOp.show(value: V128TernaryOp): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ValType`
- `ValType.anyref(): ValType`
  Call ValType.anyref.
- `ValType.bottom(): ValType`
  Call ValType.bottom.
- `ValType.eqrefNull(): ValType`
  Call ValType.eqrefNull.
- `ValType.externref(): ValType`
  Call ValType.externref.
- `ValType.f32(): ValType`
  Call ValType.f32.
- `ValType.f64(): ValType`
  Call ValType.f64.
- `ValType.funcref(): ValType`
  Call ValType.funcref.
- `ValType.i31ref(): ValType`
  Call ValType.i31ref.
- `ValType.i31refNullable(): ValType`
  Call ValType.i31refNullable.
- `ValType.i32(): ValType`
  Call ValType.i32.
- `ValType.i64(): ValType`
  Call ValType.i64.
- `ValType.isRefType(arg0: ValType): boolean`
  Call ValType.isRefType.
- `ValType.numType(arg0: NumType): ValType`
  Call ValType.numType.
- `ValType.refArrayNonnull(arg0: TypeIdx): ValType`
  Call ValType.refArrayNonnull.
- `ValType.refArrayNullable(arg0: TypeIdx): ValType`
  Call ValType.refArrayNullable.
- `ValType.refNull(arg0: HeapType): ValType`
  Call ValType.refNull.
- `ValType.refNullArrayOf(arg0: TypeIdx): ValType`
  Call ValType.refNullArrayOf.
- `ValType.refNullExn(): ValType`
  Call ValType.refNullExn.
- `ValType.refType(arg0: RefType): ValType`
  Call ValType.refType.
- `ValType.v128(): ValType`
  Call ValType.v128.
- `ValType.show(value: ValType): string`
  Format the value with its MoonBit `Show` implementation.

### passes

Import directly with `import * as passes from '@jtenner/starshine/passes';` or from the root barrel.

Manual pipelines can be built by ordering `ModulePass` values in a plain JS array, then passing that array to `optimizeModule(...)` or `optimizeModuleWithOptions(...)`.

```js
const pipeline = passes.defaultFunctionOptimizationPasses(mod, options);
pipeline.push(passes.deadArgumentElimination());
pipeline.push(passes.vacuum());
```

- `modulePass(name: string): ModulePass`
  Resolve one of the canonical explicit pass names into a `ModulePass` value.
- `optimizeModuleWithOptionsTrace(arg0: Module, arg1: Array<ModulePass>, arg2: OptimizeOptions, trace?: (msg: string) => void, tracePassDetails?: boolean, traceModuleStats?: boolean): StarshineResult<Module, string>`
  Call `optimizeModuleWithOptionsTrace`, replaying trace lines through the provided JS callback.
- `deadArgumentElimination(): ModulePass`
  Create `ModulePass::DeadArgumentElimination` for manual ordered pipelines.
- `vacuum(): ModulePass`
  Create `ModulePass::Vacuum` for manual cleanup placement.
- `directize(always?: boolean): ModulePass`
  Create `ModulePass::Directize`, defaulting `always` to `false`.

- `defaultFunctionOptimizationPasses(arg0: Module, arg1: OptimizeOptions): Array<ModulePass>`
  Call defaultFunctionOptimizationPasses.
- `defaultGlobalOptimizationPostPasses(arg0: Module, arg1: OptimizeOptions): Array<ModulePass>`
  Call defaultGlobalOptimizationPostPasses.
- `defaultGlobalOptimizationPrePasses(arg0: Module, arg1: OptimizeOptions, closedWorld?: boolean): Array<ModulePass>`
  Call defaultGlobalOptimizationPrePasses.
- `optimizeModule(arg0: Module, arg1: Array<ModulePass>): StarshineResult<Module, string>`
  Call optimizeModule.
- `optimizeModuleWithOptions(arg0: Module, arg1: Array<ModulePass>, arg2: OptimizeOptions): StarshineResult<Module, string>`
  Call optimizeModuleWithOptions.

Type namespace `AbstractTypeRefiningPassProps`
- `AbstractTypeRefiningPassProps.show(value: AbstractTypeRefiningPassProps): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `AsyncifyPassProps`
- `AsyncifyPassProps.show(value: AsyncifyPassProps): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `BlockLiveness`
- `BlockLiveness.show(value: BlockLiveness): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `CallSite`
- `CallSite.show(value: CallSite): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `EquivalentClass`
- `EquivalentClass.show(value: EquivalentClass): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `InliningOptions`
- `InliningOptions.new(alwaysInlineMaxSize?: number, oneCallerInlineMaxSize?: number, flexibleInlineMaxSize?: number, maxCombinedBinarySize?: number, allowFunctionsWithLoops?: boolean, partialInliningIfs?: number): InliningOptions`
  Create a InliningOptions value.

Type namespace `Literal`
- `Literal.show(value: Literal): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `LiteralKind`
- `LiteralKind.show(value: LiteralKind): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `MSFCallSite`
- `MSFCallSite.show(value: MSFCallSite): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `MSFDefinedFunc`
- `MSFDefinedFunc.show(value: MSFDefinedFunc): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `MSFHashState`
- `MSFHashState.show(value: MSFHashState): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `MSFParamKind`
- `MSFParamKind.show(value: MSFParamKind): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `MSFSiteValue`
- `MSFSiteValue.show(value: MSFSiteValue): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `MemoryPackingPassProps`
- `MemoryPackingPassProps.show(value: MemoryPackingPassProps): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ModulePass`
- `ModulePass.show(value: ModulePass): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `OptimizeOptions`
- `OptimizeOptions.new(optimizeLevel?: number, shrinkLevel?: number, inlining?: InliningOptions, monomorphizeMinBenefit?: number, lowMemoryUnused?: boolean, lowMemoryBound?: bigint, trapsNeverHappen?: boolean): OptimizeOptions`
  Create a OptimizeOptions value.

Type namespace `ParamInfo`
- `ParamInfo.show(value: ParamInfo): string`
  Format the value with its MoonBit `Show` implementation.

### transformer

Import directly with `import * as transformer from '@jtenner/starshine/transformer';` or from the root barrel.

- `change(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `error(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `unchanged(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.

Type namespace `ModuleTransformer`
- `ModuleTransformer.new(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onBinaryopEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onBlocktypeEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onCodesecEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onComptypeEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onDatacntsecEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onDataidxEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onDatasecEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onElemidxEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onElemkindEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onElemsecEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onExportEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onExportsecEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onExprEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onExternidxEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onExterntypeEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onExtractlaneopEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onFieldtypeEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onFuncEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onFuncidxEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onFuncsecEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onGlobalEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onGlobalidxEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onGlobalsecEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onGlobaltypeEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onHeaptypeEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onImportsecEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onInstructionEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onLabelidxEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onLaneidxEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onLimitsEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onLoadopEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onLocalidxEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onLocalsEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onMemargEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onMemidxEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onMemsecEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onMemtypeEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onModuleEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onNameEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onNumtypeEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onRectypeEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onReftypeEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onReplacelaneopEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onStartsecEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onStoragetypeEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onStoreopEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onSubtypeEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onTableEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onTableidxEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onTablesecEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onTagidxEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onTagsecEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onTagtypeEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onTexprEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onTinstructionEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onTypeidxEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onTypesecEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onUnaryopEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onV128loadlaneopEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onV128shiftopEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onV128storelaneopEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onV128ternaryopEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.onValtypeEvt(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkArray(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkBinaryop(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkBlocktype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkBlocktypeDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkCatch(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkCodesec(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkCodesecDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkComptype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkComptypeDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkCustomsec(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkCustomsecs(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkData(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkDatacntsec(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkDataidx(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkDatamode(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkDatasec(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkDatasecDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkElem(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkElemidx(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkElemkind(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkElemkindDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkElemmode(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkElemsec(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkElemsecDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkExport(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkExportDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkExportsec(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkExportsecDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkExpr(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkExprDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkExternidx(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkExternidxDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkExterntype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkExtractlaneop(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkFieldtype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkFieldtypeDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkFunc(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkFuncDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkFuncidx(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkFuncsec(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkFuncsecDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkGlobal(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkGlobalDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkGlobalidx(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkGlobalsec(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkGlobalsecDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkGlobaltype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkGlobaltypeDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkHeaptype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkHeaptypeDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkImport(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkImportsec(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkImportsecDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkInstruction(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkInstructionDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkLabelidx(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkLaneidx(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkLimits(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkLoadop(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkLocalidx(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkLocals(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkLocalsDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkMemarg(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkMemidx(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkMemsec(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkMemsecDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkMemtype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkMemtypeDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkModule(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkModuleDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkName(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkNumtype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkRectype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkRectypeDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkReftype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkReftypeDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkReplacelaneop(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkSingleLocal(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkStartsec(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkStartsecDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkStoragetype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkStoragetypeDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkStoreop(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkSubtype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkSubtypeDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTable(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTableDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTableidx(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTablesec(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTablesecDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTabletype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTagidx(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTagsec(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTagsecDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTagtype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTagtypeDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTexpr(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTexprDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTinstruction(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTinstructionDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTypeidx(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTypesec(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkTypesecDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkUnaryop(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkV128loadlaneop(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkV128shiftop(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkV128storelaneop(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkV128ternaryop(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkValtype(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.
- `ModuleTransformer.walkValtypeDefault(...args: never[]): never`
  Generic exports are not available through the wasm-gc adapter.

### validate

Import directly with `import * as validate from '@jtenner/starshine/validate';` or from the root barrel.

- `descriptorCompatible(arg0: RefType, arg1: RefType, arg2: Env): boolean`
  Call descriptorCompatible.
- `diff(arg0: RefType, arg1: RefType): StarshineResult<RefType, string>`
  Call diff.
- `emptyEnv(): Env`
  Call emptyEnv.
- `genSideEffectTinstr(arg0: GenValidContext, arg1: number, labelDepth?: number): TInstr`
  Call genSideEffectTinstr.
- `genTinstrOfType(arg0: GenValidContext, arg1: ValType): TInstr`
  Call genTinstrOfType.
- `genValidModule(arg0: OpaqueHandle<"@splitmix.RandomState">): Module`
  Call genValidModule.
- `genValidNumtype(arg0: GenValidContext): NumType`
  Call genValidNumtype.
- `genValidResultType(arg0: GenValidContext, arg1: Array<ValType>, arg2: TypeGenerationStrategy): Array<ValType>`
  Call genValidResultType.
- `genValidTfunc(arg0: GenValidContext, arg1: Array<ValType>, arg2: Array<ValType>): Func`
  Call genValidTfunc.
- `genValidValtype(arg0: GenValidContext): ValType`
  Call genValidValtype.
- `toTexpr(arg0: Expr, arg1: Env): StarshineResult<TExpr, string>`
  Call toTexpr.
- `validateCodesec(arg0: CodeSec | null, arg1: FuncSec | null, arg2: Env): StarshineResult<void, string>`
  Validate codesec.
- `validateDatacnt(arg0: DataCntSec | null, arg1: DataSec | null): StarshineResult<void, string>`
  Validate datacnt.
- `validateDatasec(arg0: DataSec | null, arg1: Env): StarshineResult<Env, string>`
  Validate datasec.
- `validateElemsec(arg0: ElemSec | null, arg1: Env): StarshineResult<Env, string>`
  Validate elemsec.
- `validateExportsec(arg0: ExportSec | null, arg1: Env): StarshineResult<void, string>`
  Validate exportsec.
- `validateFuncsec(arg0: FuncSec | null, arg1: Env): StarshineResult<Env, string>`
  Validate funcsec.
- `validateGlobalsec(arg0: GlobalSec | null, arg1: Env): StarshineResult<Env, string>`
  Validate globalsec.
- `validateImportsec(arg0: ImportSec | null, arg1: Env): StarshineResult<Env, string>`
  Validate importsec.
- `validateMemsec(arg0: MemSec | null, arg1: Env): StarshineResult<Env, string>`
  Validate memsec.
- `validateModule(arg0: Module): StarshineResult<void, ValidationError>`
  Validate module.
- `validateStartsec(arg0: StartSec | null, arg1: Env): StarshineResult<void, string>`
  Validate startsec.
- `validateTablesec(arg0: TableSec | null, arg1: Env): StarshineResult<Env, string>`
  Validate tablesec.
- `validateTagsec(arg0: TagSec | null, arg1: Env): StarshineResult<Env, string>`
  Validate tagsec.
- `validateTypesec(arg0: TypeSec | null, arg1: Env): StarshineResult<Env, string>`
  Validate typesec.

Type namespace `Env`
- `Env.appendRectypeTypes(arg0: Env, arg1: RecType): Env`
  Call Env.appendRectypeTypes.
- `Env.descriptorResultType(arg0: Env): ValType`
  Call Env.descriptorResultType.
- `Env.expandBlocktype(arg0: Env, arg1: BlockType): StarshineResult<[Array<ValType>, Array<ValType>], string>`
  Call Env.expandBlocktype.
- `Env.getCatchLabelTypes(arg0: Env, arg1: LabelIdx): Array<ValType> | null`
  Read data with Env.getCatchLabelTypes.
- `Env.getElem(arg0: Env, arg1: ElemIdx): Elem | null`
  Read data with Env.getElem.
- `Env.getFunctypeByFuncidx(arg0: Env, arg1: FuncIdx): FuncType | null`
  Read data with Env.getFunctypeByFuncidx.
- `Env.getFunctypeidxByFuncidx(arg0: Env, arg1: FuncIdx): TypeIdx | null`
  Read data with Env.getFunctypeidxByFuncidx.
- `Env.getGlobalType(arg0: Env, arg1: GlobalIdx): GlobalType | null`
  Read data with Env.getGlobalType.
- `Env.getLabel(arg0: Env, arg1: LabelIdx): Array<ValType> | null`
  Read data with Env.getLabel.
- `Env.getLabelTypes(arg0: Env, arg1: LabelIdx): Array<ValType> | null`
  Read data with Env.getLabelTypes.
- `Env.getLocalType(arg0: Env, arg1: LocalIdx): ValType | null`
  Read data with Env.getLocalType.
- `Env.getMemtype(arg0: Env, arg1: MemIdx): MemType | null`
  Read data with Env.getMemtype.
- `Env.getTableType(arg0: Env, arg1: TableIdx): TableType | null`
  Read data with Env.getTableType.
- `Env.getTag(arg0: Env, arg1: TagIdx): TagType | null`
  Read data with Env.getTag.
- `Env.hasData(arg0: Env, arg1: DataIdx): boolean`
  Check Env::has data.
- `Env.hasFunc(arg0: Env, arg1: FuncIdx): boolean`
  Check Env::has func.
- `Env.new(): Env`
  Create a Env value.
- `Env.pushData(arg0: Env, arg1: Data): Env`
  Call Env.pushData.
- `Env.pushElem(arg0: Env, arg1: Elem): Env`
  Call Env.pushElem.
- `Env.pushFunc(arg0: Env, arg1: FuncType): Env`
  Call Env.pushFunc.
- `Env.pushFuncWithTypeidx(arg0: Env, arg1: FuncType, arg2: TypeIdx | null): Env`
  Call Env.pushFuncWithTypeidx.
- `Env.pushGlobal(arg0: Env, arg1: GlobalType): Env`
  Call Env.pushGlobal.
- `Env.pushMem(arg0: Env, arg1: MemType): Env`
  Call Env.pushMem.
- `Env.pushTable(arg0: Env, arg1: TableType): Env`
  Call Env.pushTable.
- `Env.pushTag(arg0: Env, arg1: TagType): Env`
  Call Env.pushTag.
- `Env.resolveArrayField(arg0: Env, arg1: TypeIdx): StarshineResult<FieldType, string>`
  Resolve Env::resolve array field.
- `Env.resolveComptype(arg0: Env, arg1: TypeIdx): CompType | null`
  Resolve Env::resolve comptype.
- `Env.resolveDescriptorTargetRefType(arg0: Env, arg1: boolean, arg2: HeapType): StarshineResult<RefType, string>`
  Resolve Env::resolve descriptor target ref type.
- `Env.resolveFunctype(arg0: Env, arg1: TypeIdx): FuncType | null`
  Resolve Env::resolve functype.
- `Env.resolveHeaptypeSubtype(arg0: Env, arg1: HeapType): SubType | null`
  Resolve Env::resolve heaptype subtype.
- `Env.resolveStructFields(arg0: Env, arg1: TypeIdx): StarshineResult<Array<FieldType>, string>`
  Resolve Env::resolve struct fields.
- `Env.resolveSubtype(arg0: Env, arg1: TypeIdx): SubType | null`
  Resolve Env::resolve subtype.
- `Env.resolveTagFunctype(arg0: Env, arg1: TagIdx): FuncType | null`
  Resolve Env::resolve tag functype.
- `Env.resolveTypeidxSubtype(arg0: Env, arg1: TypeIdx): SubType | null`
  Resolve Env::resolve typeidx subtype.
- `Env.withElems(arg0: Env, arg1: Array<Elem>): Env`
  Return an updated value from Env.withElems.
- `Env.withFuncs(arg0: Env, arg1: Array<FuncType>): Env`
  Return an updated value from Env.withFuncs.
- `Env.withGlobals(arg0: Env, arg1: Array<GlobalType>): Env`
  Return an updated value from Env.withGlobals.
- `Env.withLabel(arg0: Env, arg1: Array<ValType>): Env`
  Return an updated value from Env.withLabel.
- `Env.withLabels(arg0: Env, arg1: Array<Array<ValType>>): Env`
  Return an updated value from Env.withLabels.
- `Env.withLocals(arg0: Env, arg1: Array<ValType>): Env`
  Return an updated value from Env.withLocals.
- `Env.withMems(arg0: Env, arg1: Array<MemType>): Env`
  Return an updated value from Env.withMems.
- `Env.withModule(arg0: Env, arg1: Module): Env`
  Return an updated value from Env.withModule.
- `Env.withRectype(arg0: Env, arg1: RecType): Env`
  Return an updated value from Env.withRectype.
- `Env.withReturnType(arg0: Env, arg1: Array<ValType> | null): Env`
  Return an updated value from Env.withReturnType.
- `Env.withTables(arg0: Env, arg1: Array<TableType>): Env`
  Return an updated value from Env.withTables.
- `Env.withTags(arg0: Env, arg1: Array<TagType>): Env`
  Return an updated value from Env.withTags.
- `Env.withTypes(arg0: Env, arg1: Array<SubType>): Env`
  Return an updated value from Env.withTypes.
- `Env.show(value: Env): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TcState`
- `TcState.show(value: TcState): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ValidationError`
- `ValidationError.show(value: ValidationError): string`
  Format the value with its MoonBit `Show` implementation.

### wast

Import directly with `import * as wast from '@jtenner/starshine/wast';` or from the root barrel.

- `lookupKeyword(arg0: string): TokenType | null`
  Look up keyword.
- `moduleToWast(arg0: Module): StarshineResult<string, string>`
  Convert values with moduleToWast.
- `moduleToWastWithContext(arg0: Module, arg1: PrettyPrintContext): StarshineResult<string, string>`
  Convert values with moduleToWastWithContext.
- `runWastSpecFile(arg0: string, arg1: string): WastSpecFileReport`
  Run wast spec file.
- `runWastSpecSuite(arg0: Array<[string, string]>): WastSpecRunSummary`
  Run wast spec suite.
- `scriptToWast(arg0: WastScript): StarshineResult<string, string>`
  Convert values with scriptToWast.
- `scriptToWastWithContext(arg0: WastScript, arg1: PrettyPrintContext): StarshineResult<string, string>`
  Convert values with scriptToWastWithContext.
- `wastAstToBinaryModule(arg0: Module): StarshineResult<Module, string>`
  Convert values with wastAstToBinaryModule.
- `wastTextBinaryRoundtrip(arg0: string, filename?: string): StarshineResult<[string, Module], string>`
  Call wastTextBinaryRoundtrip.
- `wastToBinaryModule(arg0: string, filename?: string): StarshineResult<Module, string>`
  Convert values with wastToBinaryModule.
- `wastToModule(arg0: string, filename?: string): StarshineResult<Module, string>`
  Convert values with wastToModule.
- `wastToScript(arg0: string, filename?: string): StarshineResult<WastScript, string>`
  Convert values with wastToScript.

Type namespace `BlockType`
- `BlockType.show(value: BlockType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `CatchClause`
- `CatchClause.show(value: CatchClause): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `DataSegment`
- `DataSegment.show(value: DataSegment): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ElemInitExpr`
- `ElemInitExpr.show(value: ElemInitExpr): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ElemSegment`
- `ElemSegment.show(value: ElemSegment): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ErrorLevel`
- `ErrorLevel.show(value: ErrorLevel): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Export`
- `Export.show(value: Export): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ExportDesc`
- `ExportDesc.show(value: ExportDesc): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Func`
- `Func.show(value: Func): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `FuncType`
- `FuncType.show(value: FuncType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Global`
- `Global.show(value: Global): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `GlobalType`
- `GlobalType.show(value: GlobalType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `HeapTypeRef`
- `HeapTypeRef.show(value: HeapTypeRef): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Import`
- `Import.show(value: Import): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ImportDesc`
- `ImportDesc.show(value: ImportDesc): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Index`
- `Index.show(value: Index): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `InlineExport`
- `InlineExport.show(value: InlineExport): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Instruction`
- `Instruction.show(value: Instruction): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `KeywordTable`
- `KeywordTable.lookup(arg0: KeywordTable, arg1: string): TokenType | null`
  Call KeywordTable.lookup.

Type namespace `LegacyCatchClause`
- `LegacyCatchClause.show(value: LegacyCatchClause): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `LexerError`
- `LexerError.show(value: LexerError): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Limits`
- `Limits.show(value: Limits): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Literal`
- `Literal.show(value: Literal): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `LiteralType`
- `LiteralType.show(value: LiteralType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Local`
- `Local.show(value: Local): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Location`
- `Location.show(value: Location): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `MemArg`
- `MemArg.show(value: MemArg): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Memory`
- `Memory.show(value: Memory): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `MemoryType`
- `MemoryType.inner(arg0: MemoryType): Limits`
  Return the wrapped inner value from MemoryType.
- `MemoryType.show(value: MemoryType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Module`
- `Module.show(value: Module): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ModuleField`
- `ModuleField.show(value: ModuleField): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Opcode`
- `Opcode.show(value: Opcode): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ParseError`
- `ParseError.show(value: ParseError): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ParserError`
- `ParserError.show(value: ParserError): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ShuffleLanes`
- `ShuffleLanes.show(value: ShuffleLanes): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `SimdShape`
- `SimdShape.show(value: SimdShape): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Start`
- `Start.show(value: Start): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Table`
- `Table.show(value: Table): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TableType`
- `TableType.show(value: TableType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Tag`
- `Tag.show(value: Tag): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `Token`
- `Token.show(value: Token): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TokenType`
- `TokenType.show(value: TokenType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TokenValue`
- `TokenValue.show(value: TokenValue): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TypeDef`
- `TypeDef.show(value: TypeDef): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `TypeUse`
- `TypeUse.show(value: TypeUse): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `V128Const`
- `V128Const.show(value: V128Const): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `ValueType`
- `ValueType.show(value: ValueType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `WastAction`
- `WastAction.show(value: WastAction): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `WastActionType`
- `WastActionType.show(value: WastActionType): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `WastCommand`
- `WastCommand.show(value: WastCommand): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `WastLexer`
- `WastLexer.getErrors(arg0: WastLexer): Array<LexerError>`
  Read data with WastLexer.getErrors.
- `WastLexer.getToken(arg0: WastLexer): Token`
  Read data with WastLexer.getToken.
- `WastLexer.hasErrors(arg0: WastLexer): boolean`
  Check WastLexer::has errors.
- `WastLexer.new(arg0: Uint8Array, arg1: string): WastLexer`
  Create a WastLexer value.

Type namespace `WastModuleDef`
- `WastModuleDef.show(value: WastModuleDef): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `WastParser`
- `WastParser.getErrors(arg0: WastParser): Array<ParseError>`
  Read data with WastParser.getErrors.
- `WastParser.hasErrors(arg0: WastParser): boolean`
  Check WastParser::has errors.
- `WastParser.new(arg0: WastLexer): WastParser`
  Create a WastParser value.
- `WastParser.parseModule(...args: never[]): never`
  Exports with `raise` effects are not available through the wasm-gc adapter.
- `WastParser.parseScript(...args: never[]): never`
  Exports with `raise` effects are not available through the wasm-gc adapter.

Type namespace `WastResult`
- `WastResult.show(value: WastResult): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `WastScript`
- `WastScript.show(value: WastScript): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `WastSpecFileReport`
- `WastSpecFileReport.show(value: WastSpecFileReport): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `WastSpecFileStatus`
- `WastSpecFileStatus.show(value: WastSpecFileStatus): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `WastSpecRunSummary`
- `WastSpecRunSummary.show(value: WastSpecRunSummary): string`
  Format the value with its MoonBit `Show` implementation.

Type namespace `WastValue`
- `WastValue.show(value: WastValue): string`
  Format the value with its MoonBit `Show` implementation.

### wat

Import directly with `import * as wat from '@jtenner/starshine/wat';` or from the root barrel.

- `lookupKeyword(arg0: string): TokenType | null`
  Look up keyword.
- `moduleToWat(arg0: Module): StarshineResult<string, string>`
  Convert values with moduleToWat.
- `moduleToWatWithContext(arg0: Module, arg1: PrettyPrintContext): StarshineResult<string, string>`
  Convert values with moduleToWatWithContext.
- `scriptToWat(arg0: WastScript): StarshineResult<string, string>`
  Convert values with scriptToWat.
- `scriptToWatWithContext(arg0: WastScript, arg1: PrettyPrintContext): StarshineResult<string, string>`
  Convert values with scriptToWatWithContext.
- `watToModule(arg0: string, filename?: string): StarshineResult<Module, string>`
  Convert values with watToModule.
- `watToScript(arg0: string, filename?: string): StarshineResult<WastScript, string>`
  Convert values with watToScript.

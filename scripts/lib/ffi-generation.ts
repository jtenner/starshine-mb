export { rewriteWasmExportNames } from "./wasm-export-renaming";

const BUILTIN_TYPES = new Set([
  "Array",
  "ArrayView",
  "Bool",
  "Byte",
  "Bytes",
  "Char",
  "Double",
  "FixedArray",
  "Float",
  "Int",
  "Int16",
  "Int64",
  "Int8",
  "Iter",
  "Json",
  "Map",
  "Option",
  "Result",
  "String",
  "UInt",
  "UInt16",
  "UInt64",
  "UInt8",
  "Unit",
]);

export interface FfiInterfaceInput {
  alias: string;
  packagePath: string;
  interfaceText: string;
}

const PRELUDE_TRAIT_PACKAGES = new Map([
  ["Eq", "moonbitlang/core/builtin"],
  ["Hash", "moonbitlang/core/builtin"],
  ["Show", "moonbitlang/core/builtin"],
]);

export function standardTraitInterfaces(): FfiInterfaceInput[] {
  return [
    {
      alias: "builtin",
      packagePath: "moonbitlang/core/builtin",
      interfaceText: `
package "moonbitlang/core/builtin"
pub type Logger
pub type Hasher
pub trait Show {
  fn output(Self, &Logger) -> Unit
  fn to_string(Self) -> String
}
pub trait Eq {
  fn equal(Self, Self) -> Bool
  fn not_equal(Self, Self) -> Bool
}
pub trait Hash {
  fn hash(Self) -> Int
  fn hash_combine(Self, Hasher) -> Unit
}
`,
    },
    {
      alias: "quickcheck",
      packagePath: "moonbitlang/core/quickcheck",
      interfaceText: `
package "moonbitlang/core/quickcheck"
import {
  "moonbitlang/core/quickcheck/splitmix",
}
pub trait Arbitrary {
  fn arbitrary(Int, @splitmix.RandomState) -> Self
}
`,
    },
  ];
}

export interface UnsupportedFfiSymbol {
  packagePath: string;
  symbol: string;
  reason: string;
}

export interface GeneratedFfiPackage {
  source: string;
  packageManifest: string;
  linkExports: string[];
  exportNames: Record<string, string>;
  unsupported: UnsupportedFfiSymbol[];
  exportedCount: number;
}

interface ParsedParameter {
  declaration: string;
  localName: string;
  callArgument: string;
}

interface ParsedImport {
  alias: string;
  packagePath: string;
}

interface ParsedFunction {
  packageAlias: string;
  packagePath: string;
  owner: string | null;
  name: string;
  generic: boolean;
  paramsText: string;
  returnText: string;
  suffixText: string;
  localTypes: Set<string>;
  selfType?: string;
  typeBindings?: Map<string, string>;
  sourceFunctionNameOverride?: string;
  requestedExportNameOverride?: string;
  targetExpressionOverride?: string;
  implementationAlias?: string;
}

interface ParsedTrait {
  packageAlias: string;
  packagePath: string;
  name: string;
  localTypes: Set<string>;
  methods: ParsedFunction[];
}

interface ParsedImpl {
  packageAlias: string;
  packagePath: string;
  localTypes: Set<string>;
  traitPackagePath: string | null;
  traitName: string;
  genericParameters: Map<string, string | null>;
  implementerPattern: string;
}

interface TypeShape {
  name: string;
  args: TypeShape[];
  optionDepth: number;
}

function splitTopLevel(text: string, delimiter = ","): string[] {
  const parts: string[] = [];
  let start = 0;
  let depth = 0;
  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    if (char === "(" || char === "[" || char === "{") depth += 1;
    else if (char === ")" || char === "]" || char === "}") depth -= 1;
    else if (char === delimiter && depth === 0) {
      parts.push(text.slice(start, index).trim());
      start = index + 1;
    }
  }
  const tail = text.slice(start).trim();
  if (tail.length > 0) parts.push(tail);
  return parts;
}

function findMatchingParen(text: string, openIndex: number): number {
  let depth = 0;
  for (let index = openIndex; index < text.length; index += 1) {
    if (text[index] === "(") depth += 1;
    else if (text[index] === ")") {
      depth -= 1;
      if (depth === 0) return index;
    }
  }
  throw new Error(`unbalanced function signature: ${text}`);
}

function interfaceImports(interfaceText: string): ParsedImport[] {
  const imports: ParsedImport[] = [];
  const block = interfaceText.match(/\nimport \{([\s\S]*?)\n\}/)?.[1] ?? "";
  for (const line of block.split("\n")) {
    const match = line.match(/^\s*"([^"]+)"(?:\s+@([A-Za-z0-9_-]+))?,?$/);
    if (!match) continue;
    imports.push({
      packagePath: match[1],
      alias: match[2] ?? match[1].split("/").at(-1)!,
    });
  }
  return imports;
}

function declaredTypes(interfaceText: string): Set<string> {
  const result = new Set<string>();
  for (const line of interfaceText.split("\n")) {
    const match = line.match(/^pub(?:\([^)]*\))?\s+(?:struct|enum|type|trait|suberror|error)\s+([A-Z][A-Za-z0-9_]*)\b/);
    if (match) result.add(match[1]);
  }
  return result;
}

function qualifyType(
  text: string,
  alias: string,
  localTypes: Set<string>,
  owner: string | null,
  selfType?: string,
  typeBindings?: Map<string, string>,
): string {
  let output = text;
  for (const [parameter, concrete] of typeBindings ?? []) {
    output = output.replace(
      new RegExp(`(?<![@A-Za-z0-9_.])${parameter}(?![A-Za-z0-9_])`, "g"),
      concrete,
    );
  }
  output = output.replace(
    /\bSelf\b/g,
    selfType ?? (owner ? `@${alias}.${owner}` : "Self"),
  );
  for (const typeName of localTypes) {
    if (BUILTIN_TYPES.has(typeName)) continue;
    output = output.replace(
      new RegExp(`(?<![@A-Za-z0-9_.])${typeName}(?![A-Za-z0-9_])`, "g"),
      `@${alias}.${typeName}`,
    );
  }
  return output;
}

function parseFunctions(input: FfiInterfaceInput): ParsedFunction[] {
  const localTypes = declaredTypes(input.interfaceText);
  const functions: ParsedFunction[] = [];
  for (const line of input.interfaceText.split("\n")) {
    if (!line.startsWith("pub fn")) continue;
    const openIndex = line.indexOf("(");
    if (openIndex < 0) continue;
    const closeIndex = findMatchingParen(line, openIndex);
    const head = line.slice("pub fn".length, openIndex).trim();
    const generic = head.startsWith("[");
    const symbolHead = generic ? head.slice((head.indexOf("]") + 1)).trim() : head;
    const symbolMatch = symbolHead.match(/^(?:(\w+)::)?([A-Za-z_][A-Za-z0-9_]*)$/);
    if (!symbolMatch) continue;
    const tail = line.slice(closeIndex + 1).trim();
    const returnMatch = tail.match(/^->\s+(.+?)(\s+raise\s+.+)?$/);
    const returnText = returnMatch ? returnMatch[1].trim() : "Unit";
    const suffixText = returnMatch?.[2]?.trim() ?? "";
    functions.push({
      packageAlias: input.alias,
      packagePath: input.packagePath,
      owner: symbolMatch[1] ?? null,
      name: symbolMatch[2],
      generic,
      paramsText: line.slice(openIndex + 1, closeIndex),
      returnText,
      suffixText,
      localTypes,
    });
  }
  return functions;
}

function parseTraits(input: FfiInterfaceInput): ParsedTrait[] {
  const traits: ParsedTrait[] = [];
  const localTypes = declaredTypes(input.interfaceText);
  let current: ParsedTrait | null = null;
  for (const line of input.interfaceText.split("\n")) {
    const traitMatch = line.match(
      /^pub(?:\([^)]*\))?\s+trait\s+([A-Za-z_][A-Za-z0-9_]*)/,
    );
    if (traitMatch) {
      current = {
        packageAlias: input.alias,
        packagePath: input.packagePath,
        name: traitMatch[1],
        localTypes,
        methods: [],
      };
      traits.push(current);
      continue;
    }
    if (current && line === "}") {
      current = null;
      continue;
    }
    if (!current) continue;
    const methodStart = line.match(/^\s+fn(?:\[[^\]]+\])?\s+([A-Za-z_][A-Za-z0-9_]*)\(/);
    if (!methodStart) continue;
    const openIndex = line.indexOf("(");
    const closeIndex = findMatchingParen(line, openIndex);
    const tail = line.slice(closeIndex + 1).trim();
    const returnMatch = tail.match(/^->\s+(.+?)(\s+raise\s+.+)?$/);
    current.methods.push({
      packageAlias: input.alias,
      packagePath: input.packagePath,
      owner: null,
      name: methodStart[1],
      generic: /^\s+fn\[/.test(line),
      paramsText: line.slice(openIndex + 1, closeIndex),
      returnText: returnMatch ? returnMatch[1].trim() : "Unit",
      suffixText: returnMatch?.[2]?.trim() ?? "",
      localTypes,
    });
  }
  return traits;
}

function resolveTraitReference(
  input: FfiInterfaceInput,
  traitReference: string,
): { packagePath: string | null; name: string } {
  const qualified = traitReference.match(/^@([A-Za-z0-9_-]+)\.([A-Za-z_][A-Za-z0-9_]*)$/);
  if (!qualified) {
    const localTrait = new RegExp(
      `^pub(?:\\([^)]*\\))?\\s+trait\\s+${traitReference}\\b`,
      "m",
    ).test(input.interfaceText);
    return {
      packagePath: localTrait
        ? input.packagePath
        : (PRELUDE_TRAIT_PACKAGES.get(traitReference) ?? input.packagePath),
      name: traitReference,
    };
  }
  const imported = interfaceImports(input.interfaceText).find(
    (entry) => entry.alias === qualified[1],
  );
  return { packagePath: imported?.packagePath ?? null, name: qualified[2] };
}

function parseImpls(input: FfiInterfaceInput): ParsedImpl[] {
  const impls: ParsedImpl[] = [];
  const localTypes = declaredTypes(input.interfaceText);
  for (const line of input.interfaceText.split("\n")) {
    const match = line.match(/^pub impl(?:\[([^\]]+)\])?\s+([^\s]+)\s+for\s+(.+)$/);
    if (!match) continue;
    const trait = resolveTraitReference(input, match[2]);
    const genericParameters = new Map<string, string | null>();
    for (const parameter of splitTopLevel(match[1] ?? "")) {
      const separator = parameter.indexOf(":");
      if (separator < 0) genericParameters.set(parameter.trim(), null);
      else {
        genericParameters.set(
          parameter.slice(0, separator).trim(),
          parameter.slice(separator + 1).trim(),
        );
      }
    }
    impls.push({
      packageAlias: input.alias,
      packagePath: input.packagePath,
      localTypes,
      traitPackagePath: trait.packagePath,
      traitName: trait.name,
      genericParameters,
      implementerPattern: qualifyType(match[3].trim(), input.alias, localTypes, null),
    });
  }
  return impls;
}

function parseTypeShape(text: string): TypeShape | null {
  let source = text.trim();
  let optionDepth = 0;
  while (source.endsWith("?")) {
    optionDepth += 1;
    source = source.slice(0, -1).trim();
  }
  const nameMatch = source.match(/^(@[A-Za-z0-9_-]+\.)?[A-Za-z_][A-Za-z0-9_]*/);
  if (!nameMatch) return null;
  const name = nameMatch[0];
  let rest = source.slice(name.length).trim();
  const args: TypeShape[] = [];
  if (rest.startsWith("[")) {
    let depth = 0;
    let close = -1;
    for (let index = 0; index < rest.length; index += 1) {
      if (rest[index] === "[") depth += 1;
      else if (rest[index] === "]") {
        depth -= 1;
        if (depth === 0) {
          close = index;
          break;
        }
      }
    }
    if (close < 0 || rest.slice(close + 1).trim().length > 0) return null;
    for (const argument of splitTopLevel(rest.slice(1, close))) {
      const parsed = parseTypeShape(argument);
      if (!parsed) return null;
      args.push(parsed);
    }
    rest = "";
  }
  if (rest.length > 0) return null;
  return { name, args, optionDepth };
}

function renderTypeShape(shape: TypeShape): string {
  const args = shape.args.length > 0
    ? `[${shape.args.map(renderTypeShape).join(", ")}]`
    : "";
  return `${shape.name}${args}${"?".repeat(shape.optionDepth)}`;
}

function collectTypeShape(shape: TypeShape, output: Set<string>): void {
  output.add(renderTypeShape(shape));
  for (const argument of shape.args) collectTypeShape(argument, output);
}

function collectPublicTypeUniverse(inputs: FfiInterfaceInput[]): Set<string> {
  const universe = new Set<string>();
  for (const input of inputs) {
    const localTypes = declaredTypes(input.interfaceText);
    const texts = parseFunctions(input).flatMap((fn) => [fn.paramsText, fn.returnText, fn.suffixText]);
    for (const text of texts) {
      for (let start = 0; start < text.length; start += 1) {
        const prefix = text.slice(start);
        const token = prefix.match(/^(@[A-Za-z0-9_-]+\.)?[A-Z][A-Za-z0-9_]*/);
        if (!token) continue;
        let end = start + token[0].length;
        if (text[end] === "[") {
          let depth = 0;
          for (; end < text.length; end += 1) {
            if (text[end] === "[") depth += 1;
            else if (text[end] === "]") {
              depth -= 1;
              if (depth === 0) {
                end += 1;
                break;
              }
            }
          }
        }
        while (text[end] === "?") end += 1;
        const candidate = qualifyType(text.slice(start, end), input.alias, localTypes, null);
        const shape = parseTypeShape(candidate);
        if (shape) collectTypeShape(shape, universe);
        start = end - 1;
      }
    }
  }
  return universe;
}

function matchTypePattern(
  pattern: TypeShape,
  candidate: TypeShape,
  parameters: Set<string>,
  bindings: Map<string, string>,
): boolean {
  if (pattern.optionDepth !== candidate.optionDepth) return false;
  if (parameters.has(pattern.name) && pattern.args.length === 0) {
    const boundShape = { ...candidate, optionDepth: 0 };
    const value = renderTypeShape(boundShape);
    const existing = bindings.get(pattern.name);
    if (existing && existing !== value) return false;
    bindings.set(pattern.name, value);
    return true;
  }
  if (pattern.name !== candidate.name || pattern.args.length !== candidate.args.length) {
    return false;
  }
  return pattern.args.every((argument, index) =>
    matchTypePattern(argument, candidate.args[index], parameters, bindings)
  );
}

function traitKey(packagePath: string | null, traitName: string): string {
  return `${packagePath ?? "?"}::${traitName}`;
}

function constraintTraitKey(impl: ParsedImpl, reference: string): string {
  const qualified = reference.match(/^@([A-Za-z0-9_-]+)\.([A-Za-z_][A-Za-z0-9_]*)$/);
  if (!qualified) return traitKey(impl.packagePath, reference);
  return traitKey(null, reference);
}

function implementerDisplay(type: string): string {
  const shape = parseTypeShape(type);
  if (!shape) return type.replace(/@[A-Za-z0-9_-]+\./g, "");
  const render = (value: TypeShape): string => {
    const name = value.name.replace(/^@[A-Za-z0-9_-]+\./, "");
    const args = value.args.length > 0 ? `[${value.args.map(render).join(",")}]` : "";
    return `${name}${args}${"?".repeat(value.optionDepth)}`;
  };
  return render(shape);
}

function implementerAlias(type: string): string | null {
  return type.match(/^@([A-Za-z0-9_-]+)\./)?.[1] ?? null;
}

function implementerSourceDisplay(type: string): string {
  return implementerDisplay(type)
    .replace(/\?/g, "_option")
    .replace(/\[/g, "_")
    .replace(/\]/g, "")
    .replace(/,/g, "_");
}

function implementationTypeAccessible(impl: ParsedImpl, type: string): boolean {
  const shape = parseTypeShape(type);
  if (!shape) return false;
  const visit = (current: TypeShape): boolean => {
    if (
      !current.name.startsWith("@") &&
      !BUILTIN_TYPES.has(current.name) &&
      !impl.localTypes.has(current.name)
    ) {
      return false;
    }
    return current.args.every(visit);
  };
  return visit(shape);
}

function traitWrappers(
  inputs: FfiInterfaceInput[],
  unsupported: UnsupportedFfiSymbol[],
): ParsedFunction[] {
  const traits = inputs.flatMap(parseTraits);
  const traitsByKey = new Map(
    traits.map((trait) => [traitKey(trait.packagePath, trait.name), trait]),
  );
  const impls = inputs.flatMap(parseImpls);
  const universe = collectPublicTypeUniverse(inputs);
  for (const impl of impls) {
    if (impl.genericParameters.size === 0) universe.add(impl.implementerPattern);
  }

  const concreteImpls: Array<{ impl: ParsedImpl; type: string; bindings: Map<string, string> }> = [];
  const implemented = new Set<string>();
  for (const impl of impls) {
    if (impl.genericParameters.size > 0 || !impl.traitPackagePath) continue;
    concreteImpls.push({ impl, type: impl.implementerPattern, bindings: new Map() });
    implemented.add(`${traitKey(impl.traitPackagePath, impl.traitName)}::${impl.implementerPattern}`);
  }

  let changed = true;
  while (changed) {
    changed = false;
    for (const impl of impls) {
      if (impl.genericParameters.size === 0 || !impl.traitPackagePath) continue;
      const pattern = parseTypeShape(impl.implementerPattern);
      if (!pattern) continue;
      for (const candidateText of universe) {
        const candidate = parseTypeShape(candidateText);
        if (!candidate) continue;
        const bindings = new Map<string, string>();
        if (!matchTypePattern(pattern, candidate, new Set(impl.genericParameters.keys()), bindings)) {
          continue;
        }
        let constraintsSatisfied = true;
        for (const [parameter, constraint] of impl.genericParameters) {
          if (!constraint) continue;
          const bound = bindings.get(parameter);
          if (!bound || !implemented.has(`${constraintTraitKey(impl, constraint)}::${bound}`)) {
            constraintsSatisfied = false;
            break;
          }
        }
        const key = `${traitKey(impl.traitPackagePath, impl.traitName)}::${candidateText}`;
        if (!constraintsSatisfied || implemented.has(key)) continue;
        implemented.add(key);
        concreteImpls.push({ impl, type: candidateText, bindings });
        changed = true;
      }
    }
  }

  const wrappers: ParsedFunction[] = [];
  for (const concrete of concreteImpls) {
    if (!implementationTypeAccessible(concrete.impl, concrete.type)) {
      unsupported.push({
        packagePath: concrete.impl.packagePath,
        symbol: `${concrete.impl.traitName}::${implementerDisplay(concrete.type)}`,
        reason: "public trait implementation uses a non-public implementing type",
      });
      continue;
    }
    const trait = traitsByKey.get(
      traitKey(concrete.impl.traitPackagePath, concrete.impl.traitName),
    );
    if (!trait) continue;
    const display = implementerDisplay(concrete.type);
    const implAlias = implementerAlias(concrete.type) ?? concrete.impl.packageAlias;
    const sourceDisplay = implementerSourceDisplay(concrete.type);
    const sourceType = implAlias === trait.packageAlias
      ? sourceDisplay
      : `${implAlias}_${sourceDisplay}`;
    for (const method of trait.methods) {
      if (method.generic) continue;
      wrappers.push({
        ...method,
        selfType: concrete.type,
        typeBindings: concrete.bindings,
        implementationAlias: implAlias,
        sourceFunctionNameOverride: safeIdentifier(
          `ffi_${trait.packageAlias}_${trait.name}_${sourceType}_${method.name}`,
        ),
        requestedExportNameOverride: `${trait.name}::${display}::${method.name}`,
        targetExpressionOverride: `@${trait.packageAlias}.${trait.name}::${method.name}`,
      });
    }
  }
  return wrappers;
}

function parseParameters(fn: ParsedFunction): ParsedParameter[] {
  return splitTopLevel(fn.paramsText).map((raw, index) => {
    const colon = raw.indexOf(":");
    if (colon >= 0) {
      const label = raw.slice(0, colon).trim();
      const type = raw.slice(colon + 1).trim();
      const baseName = label.replace(/[?~]$/, "");
      const qualifiedType = qualifyType(
        type,
        fn.packageAlias,
        fn.localTypes,
        fn.owner,
        fn.selfType,
        fn.typeBindings,
      );
      const declaration = label.endsWith("?")
        ? `${baseName} : (${qualifiedType})?`
        : `${baseName} : ${qualifiedType}`;
      const callArgument = label.endsWith("~")
        ? `${baseName}~`
        : label.endsWith("?")
          ? `${baseName}?`
          : `${baseName}=${baseName}`;
      return { declaration, localName: baseName, callArgument };
    }
    const localName = raw === "Self" && index === 0 ? "receiver" : `value${index}`;
    return {
      declaration: `${localName} : ${qualifyType(
        raw,
        fn.packageAlias,
        fn.localTypes,
        fn.owner,
        fn.selfType,
        fn.typeBindings,
      )}`,
      localName,
      callArgument: localName,
    };
  });
}

function safeIdentifier(text: string): string {
  return text.replace(/[^A-Za-z0-9_]/g, "_");
}

function requestedExportName(fn: ParsedFunction): string {
  return fn.requestedExportNameOverride ??
    (fn.owner ? `${fn.owner}::${fn.name}` : `${fn.packageAlias}::${fn.name}`);
}

function sourceFunctionName(fn: ParsedFunction): string {
  return fn.sourceFunctionNameOverride ?? safeIdentifier(
    `ffi_${fn.packageAlias}_${fn.owner ? `${fn.owner}_` : ""}${fn.name}`,
  );
}

function targetExpression(fn: ParsedFunction): string {
  if (fn.targetExpressionOverride) return fn.targetExpressionOverride;
  return fn.owner
    ? `@${fn.packageAlias}.${fn.owner}::${fn.name}`
    : `@${fn.packageAlias}.${fn.name}`;
}

function renderWrapper(fn: ParsedFunction): string {
  const params = parseParameters(fn);
  const returnType = qualifyType(
    fn.returnText,
    fn.packageAlias,
    fn.localTypes,
    fn.owner,
    fn.selfType,
    fn.typeBindings,
  );
  const suffix = fn.suffixText.length > 0
    ? ` ${qualifyType(
        fn.suffixText,
        fn.packageAlias,
        fn.localTypes,
        fn.owner,
        fn.selfType,
        fn.typeBindings,
      )}`
    : "";
  const call = `${targetExpression(fn)}(${params.map((param) => param.callArgument).join(", ")})`;
  return [
    "///|",
    "#doc(hidden)",
    `#export_name("${sourceFunctionName(fn)}")`,
    `pub fn ${sourceFunctionName(fn)}(${params.map((param) => param.declaration).join(", ")}) -> ${returnType}${suffix} {`,
    `  ${call}`,
    "}",
  ].join("\n");
}

function renderPackageManifest(
  inputs: FfiInterfaceInput[],
  usedAliases: Set<string>,
): string {
  const importsByAlias = new Map<string, string>();
  for (const input of inputs) {
    importsByAlias.set(input.alias, input.packagePath);
    for (const imported of interfaceImports(input.interfaceText)) {
      const existing = importsByAlias.get(imported.alias);
      if (existing && existing !== imported.packagePath) {
        throw new Error(`FFI import alias collision: @${imported.alias} is both ${existing} and ${imported.packagePath}`);
      }
      importsByAlias.set(imported.alias, imported.packagePath);
    }
  }
  const imports = [...importsByAlias]
    .filter(([alias]) => usedAliases.has(alias))
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([alias, packagePath]) => `  \"${packagePath}\" @${alias},`)
    .join("\n");
  return `import {\n${imports}\n}\n\npkgtype(kind: \"foreign_library\")\n\noptions(\n  link: {\n    \"wasm-gc\": {\n      \"export-memory-name\": \"memory\",\n    },\n  },\n)\n`;
}

export function generateFfiPackage(inputs: FfiInterfaceInput[]): GeneratedFfiPackage {
  const functions = inputs.flatMap(parseFunctions);
  const unsupported: UnsupportedFfiSymbol[] = [];
  const concrete: ParsedFunction[] = [];
  for (const fn of functions) {
    const signature = `${fn.paramsText} ${fn.returnText} ${fn.suffixText}`;
    const leakedTypes = [...signature.matchAll(/(?<![@.])\b([A-Z][A-Za-z0-9_]*)\b/g)]
      .map((match) => match[1])
      .filter((name) => !BUILTIN_TYPES.has(name) && name !== "Self" && !fn.localTypes.has(name));
    if (fn.generic) {
      unsupported.push({
        packagePath: fn.packagePath,
        symbol: fn.owner ? `${fn.owner}::${fn.name}` : fn.name,
        reason: "generic functions require concrete type instantiations before they can be Wasm exports",
      });
    } else if (leakedTypes.length > 0) {
      unsupported.push({
        packagePath: fn.packagePath,
        symbol: fn.owner ? `${fn.owner}::${fn.name}` : fn.name,
        reason: `public signature references non-public type(s): ${[...new Set(leakedTypes)].join(", ")}`,
      });
    } else {
      concrete.push(fn);
    }
  }

  for (const fn of traitWrappers(inputs, unsupported)) {
    const signature = `${fn.paramsText} ${fn.returnText} ${fn.suffixText}`;
    const leakedTypes = [...signature.matchAll(/(?<![@.])\b([A-Z][A-Za-z0-9_]*)\b/g)]
      .map((match) => match[1])
      .filter((name) =>
        !BUILTIN_TYPES.has(name) &&
        name !== "Self" &&
        !fn.localTypes.has(name) &&
        !fn.typeBindings?.has(name)
      );
    if (leakedTypes.length === 0) concrete.push(fn);
    else {
      unsupported.push({
        packagePath: fn.packagePath,
        symbol: requestedExportName(fn),
        reason: `instantiated trait signature references non-public type(s): ${[...new Set(leakedTypes)].join(", ")}`,
      });
    }
  }

  const requestedCounts = new Map<string, number>();
  for (const fn of concrete) {
    const name = requestedExportName(fn);
    requestedCounts.set(name, (requestedCounts.get(name) ?? 0) + 1);
  }
  const linkExports = concrete.map((fn) => {
    const requested = requestedExportName(fn);
    let exported = requested;
    if ((requestedCounts.get(requested) ?? 0) > 1) {
      if (fn.requestedExportNameOverride && fn.implementationAlias) {
        const parts = requested.split("::");
        exported = `${parts[0]}::${fn.implementationAlias}::${parts.slice(1).join("::")}`;
      } else if (fn.owner) {
        exported = `${fn.packageAlias}::${requested}`;
      }
    }
    return `${sourceFunctionName(fn)}:${exported}`;
  });
  const source = `// Generated by \`bun ffi generate\`. DO NOT EDIT!\n\n${concrete.map(renderWrapper).join("\n\n")}\n`;
  const usedAliases = new Set(
    [...source.matchAll(/@([A-Za-z0-9_-]+)\./g)].map((match) => match[1]),
  );
  const exportNames = Object.fromEntries(
    linkExports.map((entry) => {
      const separator = entry.indexOf(":");
      return [entry.slice(0, separator), entry.slice(separator + 1)];
    }),
  );
  return {
    source,
    packageManifest: renderPackageManifest(inputs, usedAliases),
    linkExports,
    exportNames,
    unsupported,
    exportedCount: concrete.length,
  };
}

export interface GeneratedCoreIrBindings {
  wit: string;
  implementation: string;
  resourceCount: number;
  constructorCount: number;
}

interface CoreIrMethod {
  owner: string;
  name: string;
  params: CoreIrParam[];
}

interface CoreIrParam {
  name: string;
  type: CoreIrType;
  optionalLabel: boolean;
}

type CoreIrType =
  | { kind: "named"; name: string }
  | { kind: "array"; element: CoreIrType }
  | { kind: "option"; value: CoreIrType };

const PRIMITIVE_WIT = new Map<string, string>([
  ["Bool", "bool"],
  ["Byte", "u8"],
  ["Int", "s32"],
  ["UInt", "u32"],
  ["Int64", "s64"],
  ["UInt64", "u64"],
  ["Float", "f32"],
  ["Double", "f64"],
  ["String", "string"],
  ["Bytes", "list<u8>"],
]);

const MOONBIT_RESERVED = new Set([
  "and", "as", "break", "catch", "const", "continue", "derive", "else", "enum", "extern",
  "fn", "for", "guard", "if", "impl", "in", "interface", "is", "let", "loop", "match",
  "mut", "priv", "pub", "raise", "ref", "resume", "return", "struct", "test", "throw", "trait",
  "try", "type", "typealias", "unreachable", "using", "var", "void", "while", "with", "yield",
]);

const WIT_RESERVED = new Set([
  "as", "bool", "borrow", "char", "constructor", "enum", "export", "f32", "f64",
  "flags", "float32", "float64", "from", "func", "future", "import", "include", "interface",
  "list", "option", "own", "package", "record", "resource", "result", "s16", "s32", "s64",
  "s8", "static", "stream", "string", "tuple", "type", "u16", "u32", "u64", "u8", "use",
  "variant", "with", "world",
]);

function splitTopLevel(input: string): string[] {
  if (input.trim() === "") return [];
  const parts: string[] = [];
  let start = 0;
  let depth = 0;
  for (let index = 0; index < input.length; index += 1) {
    const char = input[index];
    if (char === "[" || char === "(") depth += 1;
    if (char === "]" || char === ")") depth -= 1;
    if (char === "," && depth === 0) {
      parts.push(input.slice(start, index).trim());
      start = index + 1;
    }
  }
  parts.push(input.slice(start).trim());
  return parts;
}

function parseCoreIrType(source: string): CoreIrType {
  const input = source.trim();
  if (input.startsWith("(") || input.includes("->")) {
    throw new Error(`unsupported Core IR constructor parameter: ${source}`);
  }
  if (input.endsWith("?")) {
    return { kind: "option", value: parseCoreIrType(input.slice(0, -1)) };
  }
  if (input.startsWith("Array[") && input.endsWith("]")) {
    return { kind: "array", element: parseCoreIrType(input.slice(6, -1)) };
  }
  if (!/^[A-Za-z][A-Za-z0-9_]*$/.test(input)) {
    throw new Error(`unsupported Core IR constructor parameter: ${source}`);
  }
  return { kind: "named", name: input };
}

function replaceSelfType(type: CoreIrType, owner: string): CoreIrType {
  if (type.kind === "named") {
    return type.name === "Self" ? { kind: "named", name: owner } : type;
  }
  if (type.kind === "array") {
    return { kind: "array", element: replaceSelfType(type.element, owner) };
  }
  return { kind: "option", value: replaceSelfType(type.value, owner) };
}

function parseParam(source: string, index: number): CoreIrParam {
  const labeled = source.match(/^([A-Za-z][A-Za-z0-9_]*)\?\s*:\s*(.+)$/);
  if (labeled) {
    return {
      name: labeled[1],
      type: parseCoreIrType(labeled[2]),
      optionalLabel: true,
    };
  }
  return { name: `p${index}`, type: parseCoreIrType(source), optionalLabel: false };
}

function kebabCase(name: string): string {
  return name
    .replace(/([A-Z]+)([A-Z][a-z])/g, "$1-$2")
    .replace(/([a-z0-9])([A-Z])/g, "$1-$2")
    .replace(/_/g, "-")
    .replace(/-+$/g, "")
    .toLowerCase();
}

function snakeCase(name: string): string {
  return kebabCase(name).replace(/-/g, "_");
}

function resourceWitName(name: string): string {
  const candidate = kebabCase(name);
  return WIT_RESERVED.has(candidate) ? `${candidate}-ir` : candidate;
}

function resourceMoonName(name: string): string {
  return resourceWitName(name)
    .split("-")
    .map((part) => part.length > 0 ? `${part[0].toUpperCase()}${part.slice(1)}` : "")
    .join("");
}

function methodWitName(name: string, used: Set<string>): string {
  const reservedResourceMethods: Record<string, string> = {
    new: "create",
    drop: "drop-op",
    rep: "rep-value",
    dtor: "destroy-value",
  };
  let candidate = reservedResourceMethods[name] ?? kebabCase(name);
  if (WIT_RESERVED.has(candidate)) candidate = `${candidate}-value`;
  let suffix = 2;
  const base = candidate;
  while (used.has(candidate)) {
    candidate = `${base}-${suffix}`;
    suffix += 1;
  }
  used.add(candidate);
  return candidate;
}

function namedTypes(type: CoreIrType, resourceNames: Set<string>, output: Set<string>): void {
  if (type.kind === "named") {
    if (resourceNames.has(type.name)) output.add(type.name);
    return;
  }
  namedTypes(type.kind === "array" ? type.element : type.value, resourceNames, output);
}

function witType(type: CoreIrType, resourceNames: Set<string>): string {
  if (type.kind === "array") return `list<${witType(type.element, resourceNames)}>`;
  if (type.kind === "option") return `option<${witType(type.value, resourceNames)}>`;
  const primitive = PRIMITIVE_WIT.get(type.name);
  if (primitive) return primitive;
  if (type.name === "Self" || resourceNames.has(type.name)) {
    const resource = type.name === "Self" ? "self" : resourceWitName(type.name);
    return `borrow<${resource}>`;
  }
  throw new Error(`unsupported Core IR constructor parameter: ${type.name}`);
}

function moonType(type: CoreIrType, resourceNames: Set<string>): string {
  if (type.kind === "array") {
    if (type.element.kind === "named" && type.element.name === "Byte") return "FixedArray[Byte]";
    return `Array[${moonType(type.element, resourceNames)}]`;
  }
  if (type.kind === "option") return `${moonType(type.value, resourceNames)}?`;
  if (type.name === "Bytes") return "FixedArray[Byte]";
  if (type.name === "Self") return "Self";
  if (resourceNames.has(type.name)) return resourceMoonName(type.name);
  if (PRIMITIVE_WIT.has(type.name)) return type.name;
  throw new Error(`unsupported Core IR constructor parameter: ${type.name}`);
}

function conversion(type: CoreIrType, expression: string, resourceNames: Set<string>): string {
  if (type.kind === "array") {
    if (type.element.kind === "named" && type.element.name === "Byte") {
      return `core_ir_byte_array(${expression})`;
    }
    if (type.element.kind === "named" && type.element.name === "Bytes") {
      return `core_ir_bytes_array(${expression})`;
    }
    if (type.element.kind === "named" && resourceNames.has(type.element.name)) {
      return `core_ir_${snakeCase(type.element.name)}_array(${expression})`;
    }
    return expression;
  }
  if (type.kind === "option") {
    if (type.value.kind === "named" && resourceNames.has(type.value.name)) {
      return `core_ir_${snakeCase(type.value.name)}_option(${expression})`;
    }
    if (type.value.kind === "named" && type.value.name === "Bytes") {
      return `core_ir_bytes_option(${expression})`;
    }
    if (type.value.kind === "named" && PRIMITIVE_WIT.has(type.value.name)) {
      return expression;
    }
    return `match ${expression} {\n    Some(value) => Some(${conversion(type.value, "value", resourceNames)})\n    None => None\n  }`;
  }
  if (type.name === "Bytes") return `core_ir_bytes(${expression})`;
  if (type.name === "Self") return expression;
  if (resourceNames.has(type.name)) return `core_ir_${snakeCase(type.name)}_get(${expression})`;
  return expression;
}

function parseMethods(mbti: string): { typeNames: Set<string>; methods: Map<string, CoreIrMethod[]> } {
  const typeNames = new Set(
    [...mbti.matchAll(/^pub(?:\(all\))? (?:enum|struct|type) ([A-Za-z0-9_]+)/gm)].map(
      (match) => match[1],
    ),
  );
  const methods = new Map<string, CoreIrMethod[]>();
  for (const line of mbti.split("\n")) {
    const match = line.match(/^pub fn ([A-Za-z0-9_]+)::([A-Za-z0-9_]+)\((.*)\) -> Self$/);
    if (!match) continue;
    const [, owner, name, rawParams] = match;
    if (!typeNames.has(owner)) continue;
    if (owner === "Name" && name === "new" && rawParams === "StringView") continue;
    const params = splitTopLevel(rawParams)
      .map(parseParam)
      .map((param) => ({ ...param, type: replaceSelfType(param.type, owner) }));
    const entries = methods.get(owner) ?? [];
    entries.push({ owner, name, params });
    methods.set(owner, entries);
  }
  return { typeNames, methods };
}

function reachableResources(
  typeNames: Set<string>,
  methods: Map<string, CoreIrMethod[]>,
): Set<string> {
  const reached = new Set<string>();
  const pending = ["Module"];
  while (pending.length > 0) {
    const current = pending.shift()!;
    if (reached.has(current)) continue;
    if (!typeNames.has(current)) throw new Error(`missing Core IR type: ${current}`);
    reached.add(current);
    for (const method of methods.get(current) ?? []) {
      for (const param of method.params) {
        const dependencies = new Set<string>();
        namedTypes(param.type, typeNames, dependencies);
        for (const dependency of dependencies) {
          if (!reached.has(dependency)) pending.push(dependency);
        }
      }
    }
  }
  return reached;
}

function renderWit(resources: string[], methods: Map<string, CoreIrMethod[]>): string {
  const resourceNames = new Set(resources);
  const lines = [
    "// Generated from src/lib/pkg.generated.mbti. DO NOT EDIT.",
    "interface core-ir {",
    "  record diagnostic {",
    "    stage: string,",
    "    message: string,",
    "  }",
    "",
  ];
  for (const owner of resources) {
    const used = new Set<string>();
    lines.push(`  resource ${resourceWitName(owner)} {`);
    for (const method of methods.get(owner) ?? []) {
      const name = methodWitName(method.name, used);
      const params = method.params.map((param) => {
        const type = param.type.kind === "named" && param.type.name === "Self"
          ? `borrow<${resourceWitName(owner)}>`
          : witType(param.type, resourceNames);
        return `${kebabCase(param.name)}: ${type}`;
      });
      lines.push(
        `    ${name}: static func(${params.join(", ")}) -> ${resourceWitName(owner)};`,
      );
    }
    lines.push("  }", "");
  }
  lines.push(
    "  empty-module: func() -> module;",
    "  decode-module: func(wasm: list<u8>) -> result<module, diagnostic>;",
    "  parse-module: func(wat: string) -> result<module, diagnostic>;",
    "  encode-module: func(value: borrow<module>) -> result<list<u8>, diagnostic>;",
    "  validate-module: func(value: borrow<module>) -> result<_, diagnostic>;",
    "}",
    "",
  );
  return lines.join("\n");
}

function renderStorage(owner: string): string {
  const snake = snakeCase(owner);
  const wrapper = resourceMoonName(owner);
  return `///|\nlet core_ir_${snake}_values : Array[@lib.${owner}?] = []\n\n///|\nlet core_ir_${snake}_free_reps : Array[Int] = []\n\n///|\nfn core_ir_${snake}_store(value : @lib.${owner}) -> ${wrapper} {\n  let rep = match core_ir_${snake}_free_reps.pop() {\n    Some(rep) => {\n      core_ir_${snake}_values[rep] = Some(value)\n      rep\n    }\n    None => {\n      let rep = core_ir_${snake}_values.length()\n      core_ir_${snake}_values.push(Some(value))\n      rep\n    }\n  }\n  ${wrapper}::new(rep)\n}\n\n///|\nfn core_ir_${snake}_get(value : ${wrapper}) -> @lib.${owner} {\n  let ${wrapper}(rep) = value\n  if rep < 0 || rep >= core_ir_${snake}_values.length() {\n    abort(\"invalid core-ir ${resourceWitName(owner)} handle\")\n  }\n  match core_ir_${snake}_values[rep] {\n    Some(value) => value\n    None => abort(\"dropped core-ir ${resourceWitName(owner)} handle\")\n  }\n}\n\n///|\nfn core_ir_${snake}_option(value : ${wrapper}?) -> @lib.${owner}? {\n  match value {\n    Some(value) => Some(core_ir_${snake}_get(value))\n    None => None\n  }\n}\n\n///|\nfn core_ir_${snake}_array(values : Array[${wrapper}]) -> Array[@lib.${owner}] {\n  values.map(fn(value) { core_ir_${snake}_get(value) })\n}\n\n///|\npub fn ${wrapper}::dtor(self : ${wrapper}) -> Unit {\n  let ${wrapper}(rep) = self\n  if rep >= 0 && rep < core_ir_${snake}_values.length() {\n    core_ir_${snake}_values[rep] = None\n    core_ir_${snake}_free_reps.push(rep)\n  }\n}\n`;
}

function moonMethodName(_originalName: string, witName: string): string {
  const candidate = snakeCase(witName);
  return MOONBIT_RESERVED.has(candidate) ? `${candidate}_` : candidate;
}

function renderMethod(
  method: CoreIrMethod,
  witName: string,
  resourceNames: Set<string>,
): string {
  const signature = method.params
    .map((param) => {
      const type = param.type.kind === "named" && param.type.name === "Self"
        ? resourceMoonName(method.owner)
        : moonType(param.type, resourceNames);
      return `${param.name} : ${type}`;
    })
    .join(",\n  ");
  const positional: string[] = [];
  const labeled: string[] = [];
  for (const param of method.params) {
    const converted = param.type.kind === "named" && param.type.name === "Self"
      ? `core_ir_${snakeCase(method.owner)}_get(${param.name})`
      : conversion(param.type, param.name, resourceNames);
    if (param.optionalLabel) labeled.push(`${param.name}=${converted}`);
    else positional.push(converted);
  }
  const args = [...positional, ...labeled].join(", ");
  const call = `@lib.${method.owner}::${method.name}(${args})`;
  const wrapper = resourceMoonName(method.owner);
  const parameters = signature === "" ? "" : `\n  ${signature}\n`;
  return `///|\npub fn ${wrapper}::${moonMethodName(method.name, witName)}(${parameters}) -> ${wrapper} {\n  core_ir_${snakeCase(method.owner)}_store(${call})\n}\n`;
}

function renderImplementation(resources: string[], methods: Map<string, CoreIrMethod[]>): string {
  const resourceNames = new Set(resources);
  const sections = ["// Generated from src/lib/pkg.generated.mbti. DO NOT EDIT.\n"];
  sections.push(`///|\nfn core_ir_bytes(value : FixedArray[Byte]) -> Bytes {\n  Bytes::from_iter(value.iter())\n}\n\n///|\nfn core_ir_bytes_option(value : FixedArray[Byte]?) -> Bytes? {\n  match value {\n    Some(value) => Some(core_ir_bytes(value))\n    None => None\n  }\n}\n\n///|\nfn core_ir_bytes_array(values : Array[FixedArray[Byte]]) -> Array[Bytes] {\n  values.map(fn(value) { core_ir_bytes(value) })\n}\n\n///|\nfn core_ir_byte_array(value : FixedArray[Byte]) -> Array[Byte] {\n  let result : Array[Byte] = []\n  for byte in value {\n    result.push(byte)\n  }\n  result\n}\n`);
  for (const owner of resources) sections.push(renderStorage(owner));
  for (const owner of resources) {
    const used = new Set<string>();
    for (const method of methods.get(owner) ?? []) {
      sections.push(renderMethod(method, methodWitName(method.name, used), resourceNames));
    }
  }
  sections.push(`///|\npub fn empty_module() -> Module {\n  core_ir_module_store(@lib.Module::new())\n}\n\n///|\npub fn decode_module(wasm : FixedArray[Byte]) -> Result[Module, Diagnostic] {\n  match @binary.decode_module(core_ir_bytes(wasm)) {\n    Ok(value) => Ok(core_ir_module_store(value))\n    Err(err) => Err({ stage: \"decode\", message: \"\\{err}\" })\n  }\n}\n\n///|\npub fn parse_module(wat : String) -> Result[Module, Diagnostic] {\n  match @wast.wast_to_binary_module(wat, filename=\"component-core-ir.wat\") {\n    Ok(value) => Ok(core_ir_module_store(value))\n    Err(err) => Err({ stage: \"parse\", message: err })\n  }\n}\n\n///|\npub fn encode_module(value : Module) -> Result[FixedArray[Byte], Diagnostic] {\n  match @binary.encode_module(core_ir_module_get(value)) {\n    Ok(bytes) => Ok(bytes.to_fixedarray())\n    Err(err) => Err({ stage: \"encode\", message: \"\\{err}\" })\n  }\n}\n\n///|\npub fn validate_module(value : Module) -> Result[Unit, Diagnostic] {\n  match @validate.validate_module(core_ir_module_get(value)) {\n    Ok(_) => Ok(())\n    Err(err) => Err({ stage: \"validate\", message: \"\\{err}\" })\n  }\n}\n`);
  return `${sections.join("\n")}\n`;
}

export function generateCoreIrBindings(mbti: string): GeneratedCoreIrBindings {
  const parsed = parseMethods(mbti);
  const reachable = reachableResources(parsed.typeNames, parsed.methods);
  const resources = [...reachable].sort((left, right) => left.localeCompare(right));
  for (const resource of resources) {
    if ((parsed.methods.get(resource) ?? []).length === 0) {
      throw new Error(`Core IR resource has no public constructor: ${resource}`);
    }
    for (const method of parsed.methods.get(resource) ?? []) {
      for (const param of method.params) {
        witType(
          param.type.kind === "named" && param.type.name === "Self"
            ? { kind: "named", name: resource }
            : param.type,
          reachable,
        );
      }
    }
  }
  return {
    wit: renderWit(resources, parsed.methods),
    implementation: renderImplementation(resources, parsed.methods),
    resourceCount: resources.length,
    constructorCount: resources.reduce(
      (count, resource) => count + (parsed.methods.get(resource) ?? []).length,
      0,
    ),
  };
}

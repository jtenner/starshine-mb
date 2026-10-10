#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { repoRootFromScript } from './self-optimized-artifacts.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = repoRootFromScript(import.meta.url);

import { generateFfiPackage, standardTraitInterfaces } from './ffi-generation.ts';
import { collectFfiInterfaces, formatGeneratedMoonBit } from './ffi-task.ts';

const TARGET_PACKAGES = ['binary', 'cli', 'cmd', 'lib', 'validate', 'wast', 'wat'].map(id => ({ id, moonPackage: `jtenner/starshine/${id}`, alias: `@${id}` }));
const TARGET_PACKAGE_IDS = new Set(TARGET_PACKAGES.map(pkg => pkg.id));
const PACKAGE_BY_ALIAS = new Map(TARGET_PACKAGES.map(pkg => [pkg.alias, pkg.id]));
PACKAGE_BY_ALIAS.set('@ffi_bridge', 'ffi_bridge');
const JS_SHARED_IMPORT = './internal/shared.js';
const RUNTIME_IMPORT = './internal/runtime.js';
let checking = false;
let ffiSchema = [];
const compatibilityOrder = JSON.parse(readText('ffi/src/npm/compatibility-parameter-order.json'));
const PRIMITIVE_KIND_BY_NAME = new Map([
  ['Bool', 'bool'],
  ['Byte', 'byte'],
  ['Char', 'char'],
  ['Double', 'number'],
  ['Float', 'number'],
  ['Int', 'number'],
  ['Int16', 'number'],
  ['Int64', 'bigint'],
  ['Int8', 'number'],
  ['String', 'string'],
  ['UInt', 'number'],
  ['UInt16', 'number'],
  ['UInt64', 'bigint'],
  ['UInt8', 'number'],
  ['Unit', 'unit'],
]);

const EXTERNAL_ALIAS_IMPORTS = new Map([
  ['@set', 'moonbitlang/core/set'],
  ['@splitmix', 'moonbitlang/core/quickcheck/splitmix'],
]);

const RESERVED_JS_IDENTIFIERS = new Set([
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'debugger',
  'default',
  'delete',
  'do',
  'else',
  'enum',
  'export',
  'extends',
  'false',
  'finally',
  'for',
  'function',
  'if',
  'import',
  'in',
  'instanceof',
  'new',
  'null',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'typeof',
  'var',
  'void',
  'while',
  'with',
  'yield',
]);

function readText(relativePath) {
  return fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');
}

function writeText(relativePath, text) {
  const absolutePath = path.join(repoRoot, relativePath);
  fs.mkdirSync(path.dirname(absolutePath), { recursive: true });
  const normalized = `${text.replace(/\r\n/g, '\n')}\n`;
  if (fs.existsSync(absolutePath)) {
    const current = fs.readFileSync(absolutePath, 'utf8');
    if (current === normalized) {
      return;
    }
  }
  if (checking) {
    if (!fs.existsSync(absolutePath) || fs.readFileSync(absolutePath, 'utf8') !== normalized) throw new Error(`Stale generated artifact: ${relativePath}`);
  } else fs.writeFileSync(absolutePath, normalized);
}

function splitTopLevel(input, delimiter) {
  const parts = [];
  let current = '';
  let squareDepth = 0;
  let parenDepth = 0;
  for (let index = 0; index < input.length; index += 1) {
    const char = input[index];
    const next = input[index + 1];
    if (char === '[') {
      squareDepth += 1;
      current += char;
      continue;
    }
    if (char === ']') {
      squareDepth -= 1;
      current += char;
      continue;
    }
    if (char === '(') {
      parenDepth += 1;
      current += char;
      continue;
    }
    if (char === ')') {
      parenDepth -= 1;
      current += char;
      continue;
    }
    if (squareDepth === 0 && parenDepth === 0 && input.startsWith(delimiter, index)) {
      parts.push(current.trim());
      current = '';
      index += delimiter.length - 1;
      continue;
    }
    if (char === '-' && next === '>' && squareDepth === 0 && parenDepth === 0 && delimiter === '->') {
      parts.push(current.trim());
      current = '';
      index += 1;
      continue;
    }
    current += char;
  }
  parts.push(current.trim());
  return parts.filter((part) => part.length > 0);
}

function findMatchingBracket(input, startIndex, openChar, closeChar) {
  let depth = 0;
  for (let index = startIndex; index < input.length; index += 1) {
    const char = input[index];
    if (char === openChar) {
      depth += 1;
    } else if (char === closeChar) {
      depth -= 1;
      if (depth === 0) {
        return index;
      }
    }
  }
  throw new Error(`Unbalanced ${openChar}${closeChar} pair in "${input}"`);
}

function findTopLevelArrow(input) {
  let squareDepth = 0;
  let parenDepth = 0;
  for (let index = 0; index < input.length - 1; index += 1) {
    const char = input[index];
    const next = input[index + 1];
    if (char === '[') {
      squareDepth += 1;
      continue;
    }
    if (char === ']') {
      squareDepth -= 1;
      continue;
    }
    if (char === '(') {
      parenDepth += 1;
      continue;
    }
    if (char === ')') {
      parenDepth -= 1;
      continue;
    }
    if (char === '-' && next === '>' && squareDepth === 0 && parenDepth === 0) {
      return index;
    }
  }
  return -1;
}

export function parseTypeDescriptor(rawType, packageMeta, ownerTypeName = null) {
  const raw = rawType.trim();
  if (raw.length === 0) {
    throw new Error('Expected a non-empty type');
  }
  const topLevelArrow = findTopLevelArrow(raw);
  if (topLevelArrow >= 0) {
    return {
      kind: 'function', raw,
      params: splitTopLevel(raw.slice(0, topLevelArrow).trim().replace(/^\(/, '').replace(/\)$/, ''), ',').map(item => parseTypeDescriptor(item, packageMeta, ownerTypeName)),
      result: parseTypeDescriptor(raw.slice(topLevelArrow + 2), packageMeta, ownerTypeName),
    };
  }
  if (raw.endsWith('?')) {
    return {
      kind: 'option',
      raw,
      item: parseTypeDescriptor(raw.slice(0, -1), packageMeta, ownerTypeName),
    };
  }
  if (raw === 'Bytes') {
    return { kind: 'bytes', raw };
  }
  if (PRIMITIVE_KIND_BY_NAME.has(raw)) {
    return {
      kind: 'primitive',
      raw,
      primitive: PRIMITIVE_KIND_BY_NAME.get(raw),
    };
  }
  if (raw === 'Self') {
    return namedDescriptor(ownerTypeName ?? 'Self', raw, packageMeta);
  }
  if (raw.startsWith('(') && raw.endsWith(')')) {
    const inner = raw.slice(1, -1).trim();
    if (inner.length === 0) {
      return { kind: 'tuple', raw, items: [] };
    }
    if (splitTopLevel(inner, ',').length === 1) return parseTypeDescriptor(inner, packageMeta, ownerTypeName);
    return {
      kind: 'tuple',
      raw,
      items: splitTopLevel(inner, ',').map((part) => parseTypeDescriptor(part, packageMeta, ownerTypeName)),
    };
  }
  const bracketIndex = raw.indexOf('[');
  if (bracketIndex >= 0 && raw.endsWith(']')) {
    const head = raw.slice(0, bracketIndex).trim();
    const inner = raw.slice(bracketIndex + 1, -1);
    const innerParts = splitTopLevel(inner, ',');
    if (head === 'Array' && innerParts.length === 1) {
      return {
        kind: 'array',
        raw,
        item: parseTypeDescriptor(innerParts[0], packageMeta, ownerTypeName),
      };
    }
    if (head === 'Result' && innerParts.length === 2) {
      return {
        kind: 'result',
        raw,
        ok: parseTypeDescriptor(innerParts[0], packageMeta, ownerTypeName),
        err: parseTypeDescriptor(innerParts[1], packageMeta, ownerTypeName),
      };
    }
    if (['Iter', 'Map', 'ArrayView'].includes(head) || /^@[A-Za-z_]+\.[A-Z][A-Za-z_]+$/.test(head)) return { kind: 'genericOpaque', raw, head, items: innerParts.map(part => parseTypeDescriptor(part, packageMeta, ownerTypeName)) };
    throw new Error(`Unsupported generic JS mapping: ${raw}`);
  }
  return namedDescriptor(raw, raw, packageMeta);
}

function namedDescriptor(name, raw, packageMeta) {
  if (name.startsWith('@')) {
    const aliasEnd = name.indexOf('.');
    if (aliasEnd > 0) {
      const alias = name.slice(0, aliasEnd);
      const typeName = name.slice(aliasEnd + 1);
      const targetPackageId = PACKAGE_BY_ALIAS.get(alias);
      if (targetPackageId) {
      return {
        kind: 'named',
        raw,
        packageId: targetPackageId,
        typeName,
      };
      }
    }
    if (!EXTERNAL_ALIAS_IMPORTS.has(name.slice(0, aliasEnd))) throw new Error(`Unknown external JS type: ${raw}`);
    return { kind: 'externalNamed', raw };
  }
  if (PRIMITIVE_KIND_BY_NAME.has(name)) {
    return {
      kind: 'primitive',
      raw,
      primitive: PRIMITIVE_KIND_BY_NAME.get(name),
    };
  }
  if (name === 'Bytes') {
    return { kind: 'bytes', raw };
  }
  if (packageMeta?.types?.has(name)) {
    return {
      kind: 'named',
      raw,
      packageId: packageMeta.id,
      typeName: name,
    };
  }
  throw new Error(`Unresolved JS type mapping: ${raw}`);
}

function descriptorKey(descriptor) {
  switch (descriptor.kind) {
    case 'primitive':
      return `primitive:${descriptor.primitive}`;
    case 'bytes':
      return 'bytes';
    case 'array':
      return `array:${descriptorKey(descriptor.item)}`;
    case 'option':
      return `option:${descriptorKey(descriptor.item)}`;
    case 'result':
      return `result:${descriptorKey(descriptor.ok)}:${descriptorKey(descriptor.err)}`;
    case 'tuple':
      return `tuple:${descriptor.items.map(descriptorKey).join(':')}`;
    case 'named':
      return `named:${descriptor.packageId}.${descriptor.typeName}`;
    case 'externalNamed':
      return `external:${descriptor.raw}`;
    case 'genericOpaque':
      return `generic:${descriptor.head}:${descriptor.items.map(descriptorKey).join(':')}`;
    case 'opaque':
      return `opaque:${descriptor.brand}`;
    case 'function':
      return `function:${descriptor.raw}`;
    default:
      throw new Error(`Unhandled descriptor kind: ${descriptor.kind}`);
  }
}

function parsePackageMeta(packageInfo) {
  const lines = readText(`src/${packageInfo.id}/pkg.generated.mbti`).split('\n');
  const types = new Map();
  const showTypes = new Set();

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index].trim();
    if (line.startsWith('pub impl Show for ')) {
      showTypes.add(line.slice('pub impl Show for '.length).trim());
      continue;
    }
    if (line.startsWith('pub enum ') || line.startsWith('pub(all) enum ')) {
      const match = /^(?:pub|pub\(all\)) enum ([A-Za-z0-9_]+)/.exec(line);
      if (match) {
        types.set(match[1], { name: match[1], kind: 'enum' });
      }
      continue;
    }
    if (line.startsWith('pub suberror ') || line.startsWith('pub(all) suberror ')) {
      const match = /^(?:pub|pub\(all\)) suberror ([A-Za-z0-9_]+)/.exec(line);
      if (match) {
        types.set(match[1], { name: match[1], kind: 'suberror' });
      }
      continue;
    }
    if (line.startsWith('pub struct ') || line.startsWith('pub(all) struct ')) {
      const match = /^(?:pub|pub\(all\)) struct ([A-Za-z0-9_]+)/.exec(line);
      if (match) {
        types.set(match[1], { name: match[1], kind: 'struct' });
      }
      continue;
    }
    if (line.startsWith('type ')) {
      const match = /^type ([A-Za-z0-9_]+)/.exec(line);
      if (match) {
        types.set(match[1], { name: match[1], kind: 'abstract' });
      }
      continue;
    }
    if (line.startsWith('pub type ')) {
      const match = /^pub type ([A-Za-z0-9_]+)/.exec(line);
      if (match) {
        types.set(match[1], { name: match[1], kind: 'alias' });
      }
      continue;
    }
  }

  for (const typeName of showTypes) {
    if (types.has(typeName)) {
      types.get(typeName).show = true;
    }
  }

  const packageMeta = {
    ...packageInfo,
    types,
    showTypes,
  };
  const values = [];
  const methodsByType = new Map();
  const constants = [];
  let previousMeaningfulLine = '';

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index].trim();
    if (line.length === 0) {
      continue;
    }
    if (line.startsWith('pub const ')) {
      const match = /^pub const ([A-Za-z0-9_]+)\s*:\s*(.+?)\s*=\s*(.+)$/.exec(line);
      if (!match) {
        throw new Error(`Unable to parse constant line "${line}"`);
      }
      constants.push({
        name: match[1],
        typeRaw: match[2].trim(),
        valueLiteral: match[3].trim(),
      });
      previousMeaningfulLine = line;
      continue;
    }
    if (line.startsWith('pub fn ') || line.startsWith('pub fn[')) {
      const match = line.match(/^pub fn(?:\[[^\]]+\])?\s+([^ (]+)\(/);
      const [possibleOwner, possibleName] = match[1].split('::');
      const owner = possibleName ? possibleOwner : null;
      const name = possibleName ?? possibleOwner;
      const ffi = ffiSchema.find(item => item.packageAlias === packageInfo.id && item.owner === owner && item.name === name && item.sourceName === `ffi_${packageInfo.id}_${owner ? owner + '_' : ''}${name}`);
      let entry;
      if (!ffi || ffi.effect || ffi.params.some(param => param.type.includes('->') || param.type.includes('&') || param.labelOnly)) {
        entry = { unsupportedReason: !ffi ? 'The FFI excludes this generic or inaccessible signature.' : ffi.effect ? 'MoonBit raise effects require an explicit JavaScript error adapter.' : ffi.params.some(param => param.type.includes('->')) ? 'Higher-order MoonBit callbacks require an explicit JavaScript adapter.' : 'Trait-object or callsite-only labels require an explicit JavaScript adapter.', packageId: packageInfo.id, ownerTypeName: owner, fullName: match[1], exportName: name, generic: true, hasRaise: Boolean(ffi?.effect), params: [], returnTypeRaw: 'Unit', returnDescriptor: { kind: 'primitive', primitive: 'unit', raw: 'Unit' } };
      } else {
        entry = { packageId: packageInfo.id, ownerTypeName: owner, fullName: match[1], exportName: name, generic: false, hasRaise: false, ffi,
          params: ffi.params.map((param, index) => ({ index, raw: param.type, name: param.name, generatedName: `arg${index}`, optionalLabel: param.optional, labelOnly: param.labelOnly, typeRaw: param.type, descriptor: parseTypeDescriptor(param.type, packageMeta, owner) })),
          returnTypeRaw: ffi.returnType, returnDescriptor: parseTypeDescriptor(ffi.returnType, packageMeta, owner) };
      }
      const ordering = compatibilityOrder[`${entry.packageId}.${entry.fullName}`];
      if (ordering && !entry.generic) {
        if (ordering.some(name => !entry.params.some(param => param.name === name))) throw new Error(`Compatibility parameter disappeared: ${entry.fullName}`);
        entry.params.sort((left, right) => (ordering.indexOf(left.name) < 0 ? ordering.length + left.index : ordering.indexOf(left.name)) - (ordering.indexOf(right.name) < 0 ? ordering.length + right.index : ordering.indexOf(right.name)));
      }
      entry.deprecated = previousMeaningfulLine === '#deprecated';
      if (entry.ownerTypeName) {
        if (!methodsByType.has(entry.ownerTypeName)) {
          methodsByType.set(entry.ownerTypeName, []);
        }
        methodsByType.get(entry.ownerTypeName).push(entry);
      } else {
        values.push(entry);
      }
      previousMeaningfulLine = line;
      continue;
    }
    previousMeaningfulLine = line;
  }

  return {
    ...packageMeta,
    types,
    showTypes,
    values,
    methodsByType,
    constants,
  };
}

function entryQualifiedName(entry) {
  return entry.ownerTypeName ? `${entry.ownerTypeName}::${entry.exportName}` : entry.exportName;
}

function splitIdentifierWords(name) {
  return name
    .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
    .split(/[_-]+/)
    .filter(Boolean);
}

function toLowerCamelCase(name) {
  const words = splitIdentifierWords(name);
  if (words.length === 0) {
    return name;
  }
  return words[0].toLowerCase()
    + words.slice(1).map((word) => word[0].toUpperCase() + word.slice(1).toLowerCase()).join('');
}

function constantJsName(constant) {
  return toLowerCamelCase(constant.name);
}

function entryJsName(entry) {
  return toLowerCamelCase(entry.exportName);
}

function entryJsQualifiedName(entry) {
  return entry.ownerTypeName ? `${entry.ownerTypeName}.${entryJsName(entry)}` : entryJsName(entry);
}

function entryUnsupportedReason(entry) {
  if (entry.unsupportedReason) return entry.unsupportedReason;
  if (entry.generic) {
    return 'Generic exports are not available through the wasm-gc adapter.';
  }
  if (entry.hasRaise) {
    return 'Exports with `raise` effects are not available through the wasm-gc adapter.';
  }
  if (entry.params.some((param) => param.labelOnly)) {
    return 'Callsite-only labeled parameters are not available through the wasm-gc adapter.';
  }
  if (entry.params.some((param) => param.raw.includes('&'))) {
    return 'Trait-object parameters are not available through the wasm-gc adapter.';
  }
  if (entry.params.some((param) => containsFunctionType(param.descriptor))) {
    return 'Higher-order function parameters are not available through the wasm-gc adapter.';
  }
  if (containsFunctionType(entry.returnDescriptor)) {
    return 'Higher-order function return values are not available through the wasm-gc adapter.';
  }
  return null;
}

function containsFunctionType(descriptor) {
  switch (descriptor.kind) {
    case 'function':
      return true;
    case 'array':
    case 'option':
      return containsFunctionType(descriptor.item);
    case 'result':
      return containsFunctionType(descriptor.ok) || containsFunctionType(descriptor.err);
    case 'tuple':
      return descriptor.items.some(containsFunctionType);
    case 'genericOpaque':
      return descriptor.items.some(containsFunctionType);
    default:
      return false;
  }
}

function collectCompositeDescriptors(descriptor, state) {
  switch (descriptor.kind) {
    case 'bytes':
      state.bytes = true;
      return;
    case 'array': {
      const key = descriptorKey(descriptor);
      if (!state.arrays.has(key)) {
        state.arrays.set(key, descriptor);
      }
      collectCompositeDescriptors(descriptor.item, state);
      return;
    }
    case 'option': {
      const key = descriptorKey(descriptor);
      if (!state.options.has(key)) {
        state.options.set(key, descriptor);
      }
      collectCompositeDescriptors(descriptor.item, state);
      return;
    }
    case 'result': {
      const key = descriptorKey(descriptor);
      if (!state.results.has(key)) {
        state.results.set(key, descriptor);
      }
      collectCompositeDescriptors(descriptor.ok, state);
      collectCompositeDescriptors(descriptor.err, state);
      return;
    }
    case 'tuple': {
      const key = descriptorKey(descriptor);
      if (!state.tuples.has(key)) {
        state.tuples.set(key, descriptor);
      }
      for (const item of descriptor.items) {
        collectCompositeDescriptors(item, state);
      }
      return;
    }
    default:
      return;
  }
}

function buildInteropCatalog(packageMetas) {
  const state = {
    bytes: false,
    arrays: new Map(),
    options: new Map(),
    results: new Map(),
    tuples: new Map(),
  };
  for (const pkg of packageMetas) {
    for (const entry of [...pkg.values, ...[...pkg.methodsByType.values()].flat()]) {
      if (entryUnsupportedReason(entry)) {
        continue;
      }
      for (const param of entry.params) {
        collectCompositeDescriptors(param.optionalLabel ? optionalDescriptor(param) : param.descriptor, state);
      }
      collectCompositeDescriptors(entry.returnDescriptor, state);
    }
  }
  if (state.bytes) {
    const byteArrayDescriptor = {
      kind: 'array',
      raw: 'Array[Byte]',
      item: {
        kind: 'primitive',
        raw: 'Byte',
        primitive: 'byte',
      },
    };
    state.arrays.set(descriptorKey(byteArrayDescriptor), byteArrayDescriptor);
  }
  return state;
}

function createHelperNames(catalog) {
  const bytesHelper = catalog.bytes
    ? {
      fromArray: '__js_bytes_from_array',
      length: '__js_bytes_length',
      get: '__js_bytes_get',
    }
    : null;
  const arrays = new Map();
  const options = new Map();
  const results = new Map();
  const tuples = new Map();

  let nextArrayId = 0;
  for (const key of catalog.arrays.keys()) {
    nextArrayId += 1;
    arrays.set(key, {
      new: `__js_array_${nextArrayId}_new`,
      push: `__js_array_${nextArrayId}_push`,
      length: `__js_array_${nextArrayId}_length`,
      get: `__js_array_${nextArrayId}_get`,
    });
  }

  let nextOptionId = 0;
  for (const key of catalog.options.keys()) {
    nextOptionId += 1;
    options.set(key, {
      none: `__js_option_${nextOptionId}_none`,
      some: `__js_option_${nextOptionId}_some`,
      isSome: `__js_option_${nextOptionId}_is_some`,
      unwrap: `__js_option_${nextOptionId}_unwrap`,
    });
  }

  let nextResultId = 0;
  for (const key of catalog.results.keys()) {
    nextResultId += 1;
    results.set(key, {
      isOk: `__js_result_${nextResultId}_is_ok`,
      unwrapOk: `__js_result_${nextResultId}_unwrap_ok`,
      unwrapErr: `__js_result_${nextResultId}_unwrap_err`,
    });
  }

  let nextTupleId = 0;
  for (const [key, descriptor] of catalog.tuples.entries()) {
    nextTupleId += 1;
    tuples.set(key, {
      make: `__js_tuple_${nextTupleId}_new`,
      getters: descriptor.items.map((_, index) => `__js_tuple_${nextTupleId}_get_${index}`),
    });
  }

  return {
    bytes: bytesHelper,
    arrays,
    options,
    results,
    tuples,
  };
}

function makeMoonType(descriptor) {
  switch (descriptor.kind) {
    case 'primitive':
      return descriptor.raw;
    case 'bytes':
      return 'Bytes';
    case 'array':
      return `Array[${makeMoonType(descriptor.item)}]`;
    case 'option':
      return `${makeMoonType(descriptor.item)}?`;
    case 'result':
      return `Result[${makeMoonType(descriptor.ok)}, ${makeMoonType(descriptor.err)}]`;
    case 'tuple':
      return `(${descriptor.items.map(makeMoonType).join(', ')})`;
    case 'named':
      if (descriptor.packageId === null) {
        return descriptor.raw;
      }
      if (descriptor.raw.startsWith('@')) {
        return descriptor.raw;
      }
      return descriptor.packageId ? `@${descriptor.packageId}.${descriptor.typeName}` : descriptor.raw;
    case 'externalNamed':
      return descriptor.raw;
    case 'genericOpaque':
      return `${descriptor.head}[${descriptor.items.map(makeMoonType).join(', ')}]`;
    case 'opaque':
      return descriptor.raw;
    default:
      throw new Error(`Unsupported MoonBit descriptor kind: ${descriptor.kind}`);
  }
}

function generateMoonInterop(packageMetas, catalog, helperNames) {
  const exports = [];
  const lines = [];

  if (helperNames.bytes) {
    exports.push(...Object.values(helperNames.bytes));
    lines.push('pub fn __js_bytes_from_array(value : Array[Byte]) -> Bytes {');
    lines.push('  Bytes::from_array(value)');
    lines.push('}');
    lines.push('');
    lines.push('pub fn __js_bytes_length(value : Bytes) -> Int {');
    lines.push('  value.length()');
    lines.push('}');
    lines.push('');
    lines.push('pub fn __js_bytes_get(value : Bytes, index : Int) -> Byte {');
    lines.push('  value[index]');
    lines.push('}');
    lines.push('');
  }

  for (const [key, descriptor] of catalog.arrays.entries()) {
    const helper = helperNames.arrays.get(key);
    exports.push(helper.new, helper.push, helper.length, helper.get);
    const itemType = makeMoonType(descriptor.item);
    lines.push(`pub fn ${helper.new}() -> Array[${itemType}] {`);
    lines.push('  Array::new()');
    lines.push('}');
    lines.push('');
    lines.push(`pub fn ${helper.push}(value : Array[${itemType}], item : ${itemType}) -> Unit {`);
    lines.push('  value.push(item)');
    lines.push('}');
    lines.push('');
    lines.push(`pub fn ${helper.length}(value : Array[${itemType}]) -> Int {`);
    lines.push('  value.length()');
    lines.push('}');
    lines.push('');
    lines.push(`pub fn ${helper.get}(value : Array[${itemType}], index : Int) -> ${itemType} {`);
    lines.push('  value[index]');
    lines.push('}');
    lines.push('');
  }

  for (const [key, descriptor] of catalog.options.entries()) {
    const helper = helperNames.options.get(key);
    exports.push(helper.none, helper.some, helper.isSome, helper.unwrap);
    const itemType = makeMoonType(descriptor.item);
    lines.push(`pub fn ${helper.none}() -> ${itemType}? {`);
    lines.push('  None');
    lines.push('}');
    lines.push('');
    lines.push(`pub fn ${helper.some}(value : ${itemType}) -> ${itemType}? {`);
    lines.push('  Some(value)');
    lines.push('}');
    lines.push('');
    lines.push(`pub fn ${helper.isSome}(value : ${itemType}?) -> Bool {`);
    lines.push('  match value {');
    lines.push('    Some(_) => true');
    lines.push('    None => false');
    lines.push('  }');
    lines.push('}');
    lines.push('');
    lines.push(`pub fn ${helper.unwrap}(value : ${itemType}?) -> ${itemType} {`);
    lines.push('  match value {');
    lines.push('    Some(inner) => inner');
    lines.push('    None => abort("Attempted to unwrap None inside the Node adapter.")');
    lines.push('  }');
    lines.push('}');
    lines.push('');
  }

  for (const [key, descriptor] of catalog.results.entries()) {
    const helper = helperNames.results.get(key);
    exports.push(helper.isOk, helper.unwrapOk, helper.unwrapErr);
    const okType = makeMoonType(descriptor.ok);
    const errType = makeMoonType(descriptor.err);
    lines.push(`pub fn ${helper.isOk}(value : Result[${okType}, ${errType}]) -> Bool {`);
    lines.push('  match value {');
    lines.push('    Ok(_) => true');
    lines.push('    Err(_) => false');
    lines.push('  }');
    lines.push('}');
    lines.push('');
    lines.push(`pub fn ${helper.unwrapOk}(value : Result[${okType}, ${errType}]) -> ${okType} {`);
    lines.push('  match value {');
    lines.push('    Ok(inner) => inner');
    lines.push('    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")');
    lines.push('  }');
    lines.push('}');
    lines.push('');
    lines.push(`pub fn ${helper.unwrapErr}(value : Result[${okType}, ${errType}]) -> ${errType} {`);
    lines.push('  match value {');
    lines.push('    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")');
    lines.push('    Err(inner) => inner');
    lines.push('  }');
    lines.push('}');
    lines.push('');
  }

  for (const [key, descriptor] of catalog.tuples.entries()) {
    const helper = helperNames.tuples.get(key);
    const itemTypes = descriptor.items.map(makeMoonType);
    exports.push(helper.make, ...helper.getters);
    lines.push(`pub fn ${helper.make}(${itemTypes.map((type, index) => `arg${index} : ${type}`).join(', ')}) -> (${itemTypes.join(', ')}) {`);
    lines.push(`  (${descriptor.items.map((_, index) => `arg${index}`).join(', ')})`);
    lines.push('}');
    lines.push('');
    for (let index = 0; index < itemTypes.length; index += 1) {
      const bindingNames = itemTypes.map((_, itemIndex) => (itemIndex === index ? `item${itemIndex}` : '_'));
      lines.push(`pub fn ${helper.getters[index]}(value : (${itemTypes.join(', ')})) -> ${itemTypes[index]} {`);
      lines.push(`  let (${bindingNames.join(', ')}) = value`);
      lines.push(`  item${index}`);
      lines.push('}');
      lines.push('');
    }
  }

  for (const pkg of packageMetas) {
    for (const type of pkg.types.values()) {
      if (!type.show) {
        continue;
      }
      const exportName = `__js_show_${pkg.id}_${type.name}`;
      exports.push(exportName);
      lines.push(`pub fn ${exportName}(value : @${pkg.id}.${type.name}) -> String {`);
      lines.push(type.debugShow ? '  @debug.Debug::to_repr(value).to_string()' : '  value.to_string()');
      lines.push('}');
      lines.push('');
    }
  }

  for (const pkg of packageMetas) {
    for (const entry of [...pkg.values, ...[...pkg.methodsByType.values()].flat()]) {
      const unsupportedReason = entryUnsupportedReason(entry);
      entry.unsupportedReason = unsupportedReason;
      if (unsupportedReason) {
        continue;
      }
      const totalCount = entry.params.length;
      entry.arityExports = [];
      for (let arity = totalCount; arity <= totalCount; arity += 1) {
        const exportName = arity === totalCount
          ? moonWrapperExportName(entry)
          : `${moonWrapperExportName(entry)}__arity_${arity}`;
        const usedParams = entry.params.slice(0, arity);
        const signature = usedParams
          .map((param, index) => `${param.generatedName} : ${makeMoonType(param.optionalLabel ? optionalDescriptor(param) : param.descriptor)}`)
          .join(', ');
        exports.push(exportName);
        entry.arityExports.push({ arity, exportName });
        lines.push(`pub fn ${exportName}(${signature}) -> ${makeMoonType(entry.returnDescriptor)} {`);
        lines.push(`  ${buildMoonCall(entry, arity)}`);
        lines.push('}');
        lines.push('');
      }
    }
  }



  return {
    exports,
    source: lines.join('\n'),
  };
}

function moonWrapperExportName(entry) {
  if (entry.ownerTypeName) {
    return `${entry.packageId}__${entry.ownerTypeName}__${entry.exportName}`;
  }
  return `${entry.packageId}__${entry.exportName}`;
}

function buildMoonCall(entry, arity) {
  if (!entry.ffi) throw new Error(`Missing FFI signature: ${entry.packageId}.${entry.fullName}`);
  const args = entry.ffi.params.map(param => entry.params.find(item => item.name === param.name).generatedName);
  return `${entry.ffi.sourceName}(${args.join(', ')})`;
}

function lowerRuntimeDescriptor(descriptor, helperNames, packageMetas) {
  switch (descriptor.kind) {
    case 'primitive':
      return `{ kind: ${JSON.stringify(descriptor.primitive)}, moonType: ${JSON.stringify(descriptor.raw)} }`;
    case 'bytes':
      return `{ kind: "bytes", helper: ${JSON.stringify({
        ...helperNames.bytes,
        byteArray: helperNames.arrays.get('array:primitive:byte'),
      })} }`;
    case 'array': {
      const helper = helperNames.arrays.get(descriptorKey(descriptor));
      return `{ kind: "array", helper: ${JSON.stringify(helper)}, item: ${lowerRuntimeDescriptor(descriptor.item, helperNames, packageMetas)} }`;
    }
    case 'option': {
      const helper = helperNames.options.get(descriptorKey(descriptor));
      return `{ kind: "option", helper: ${JSON.stringify(helper)}, item: ${lowerRuntimeDescriptor(descriptor.item, helperNames, packageMetas)} }`;
    }
    case 'result': {
      const helper = helperNames.results.get(descriptorKey(descriptor));
      return `{ kind: "result", helper: ${JSON.stringify(helper)}, ok: ${lowerRuntimeDescriptor(descriptor.ok, helperNames, packageMetas)}, err: ${lowerRuntimeDescriptor(descriptor.err, helperNames, packageMetas)} }`;
    }
    case 'tuple': {
      const helper = helperNames.tuples.get(descriptorKey(descriptor));
      return `{ kind: "tuple", helper: ${JSON.stringify(helper)}, items: [${descriptor.items.map((item) => lowerRuntimeDescriptor(item, helperNames, packageMetas)).join(', ')}] }`;
    }
    case 'named': {
      const type = packageMetas.get(descriptor.packageId).types.get(descriptor.typeName);
      const showExport = type?.show ? `__js_show_${descriptor.packageId}_${descriptor.typeName}` : null;
      return `{ kind: "named", brand: ${JSON.stringify(`${descriptor.packageId}.${descriptor.typeName}`)}, showExport: ${JSON.stringify(showExport)} }`;
    }
    case 'externalNamed':
      return `{ kind: "opaque", brand: ${JSON.stringify(descriptor.raw)} }`;
    case 'genericOpaque':
      return `{ kind: "opaque", brand: ${JSON.stringify(descriptor.raw)} }`;
    case 'opaque':
      return `{ kind: "opaque", brand: ${JSON.stringify(descriptor.brand)} }`;
    case 'function':
      return `{ kind: "function", brand: ${JSON.stringify(descriptor.raw)} }`;
    default:
      throw new Error(`Unhandled runtime descriptor kind ${descriptor.kind}`);
  }
}

function renderTsType(descriptor, currentPackageId, imports) {
  switch (descriptor.kind) {
    case 'primitive':
      if (descriptor.primitive === 'bool') {
        return 'boolean';
      }
      if (descriptor.primitive === 'string') {
        return 'string';
      }
      if (descriptor.primitive === 'bigint') {
        return 'bigint';
      }
      if (descriptor.primitive === 'unit') {
        return 'void';
      }
      return 'number';
    case 'bytes':
      return 'Uint8Array';
    case 'array':
      return `Array<${renderTsType(descriptor.item, currentPackageId, imports)}>`;
    case 'option':
      return `(${renderTsType(descriptor.item, currentPackageId, imports)}) | null`;
    case 'result':
      imports.shared = true;
      return `StarshineResult<${renderTsType(descriptor.ok, currentPackageId, imports)}, ${renderTsType(descriptor.err, currentPackageId, imports)}>`;
    case 'tuple':
      return `[${descriptor.items.map((item) => renderTsType(item, currentPackageId, imports)).join(', ')}]`;
    case 'named':
      if (descriptor.packageId !== currentPackageId) {
        if (TARGET_PACKAGE_IDS.has(descriptor.packageId)) {
          if (!imports.byModule.has(descriptor.packageId)) {
            imports.byModule.set(descriptor.packageId, new Set());
          }
          imports.byModule.get(descriptor.packageId).add(descriptor.typeName);
        }
      }
      return descriptor.packageId === currentPackageId ? descriptor.typeName : `${descriptor.packageId}_${descriptor.typeName}`;
    case 'externalNamed':
      imports.shared = true;
      return `OpaqueHandle<${JSON.stringify(descriptor.raw)}>`;
    case 'genericOpaque':
      imports.shared = true;
      return `OpaqueHandle<${JSON.stringify(descriptor.raw)}>`;
    case 'opaque':
      imports.shared = true;
      return `OpaqueHandle<${JSON.stringify(descriptor.brand)}>`;
    case 'function':
      return `(${descriptor.params.map((param, index) => `arg${index}: ${renderTsType(param, currentPackageId, imports)}`).join(', ')}) => ${renderTsType(descriptor.result, currentPackageId, imports)}`;
    default:
      throw new Error(`Unhandled TypeScript descriptor kind ${descriptor.kind}`);
  }
}

function tsParamName(param) {
  return safeJsIdentifier(toLowerCamelCase(param.name === param.generatedName ? param.generatedName : param.name));
}

function safeJsIdentifier(name) {
  if (/^[A-Za-z_$][A-Za-z0-9_$]*$/.test(name) && !RESERVED_JS_IDENTIFIERS.has(name)) {
    return name;
  }
  const normalized = name.replace(/[^A-Za-z0-9_$]/g, '_').replace(/^[^A-Za-z_$]+/, 'arg_');
  const camelName = toLowerCamelCase(normalized);
  if (/^[A-Za-z_$][A-Za-z0-9_$]*$/.test(camelName) && !RESERVED_JS_IDENTIFIERS.has(camelName)) {
    return camelName;
  }
  return `${camelName}Arg`;
}

function renderTsSignature(entry, currentPackageId, imports, unsupported = false) {
  if (unsupported) {
    return '(...args: never[]): never';
  }
  const params = entry.params.map((param) => {
    const optional = param.optionalLabel ? '?' : '';
    return `${tsParamName(param)}${optional}: ${param.descriptor.raw === 'Char' ? 'number | string' : renderTsType(param.descriptor, currentPackageId, imports)}`;
  });
  return `(${params.join(', ')}): ${renderTsType(entry.returnDescriptor, currentPackageId, imports)}`;
}

function generatePackageJs(pkg, helperNames, packageMetas, runtimeImport = RUNTIME_IMPORT) {
  const lines = [];
  lines.push(`import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from ${JSON.stringify(runtimeImport)};`);
  lines.push('');
  lines.push('const wasm = await getWasmGcExports();');
  lines.push('');

  for (const constant of pkg.constants) {
    lines.push(`export const ${constantJsName(constant)} = ${constant.valueLiteral};`);
  }
  if (pkg.constants.length > 0) {
    lines.push('');
  }

  const methodsByType = new Map(pkg.methodsByType);
  const packageMetasById = new Map(TARGET_PACKAGES.map((info) => [info.id, packageMetas.find((meta) => meta.id === info.id)]));

  for (const entry of pkg.values) {
    lines.push(...generateJsFunction(entry, helperNames, packageMetasById));
    lines.push('');
  }

  for (const typeName of [...pkg.types.keys()].sort()) {
    const typeMethods = [...(methodsByType.get(typeName) ?? [])];
    const type = pkg.types.get(typeName);
    const showExport = type?.show ? `__js_show_${pkg.id}_${typeName}` : null;
    lines.push(`export const ${typeName} = Object.freeze({`);
    for (const method of typeMethods) {
      const jsLines = generateJsObjectMethod(method, helperNames, packageMetasById);
      for (const line of jsLines) {
        lines.push(`  ${line}`);
      }
    }
    if (showExport && !typeMethods.some(method => entryJsName(method) === 'show')) {
      lines.push(`  show(value) {`);
      lines.push(`    return wasm[${JSON.stringify(showExport)}](lowerValue({ kind: "named", brand: ${JSON.stringify(`${pkg.id}.${typeName}`)} }, value, wasm));`);
      lines.push('  },');
    }
    lines.push('});');
    lines.push('');
  }

  return lines.join('\n').trimEnd();
}

function generateJsFunction(entry, helperNames, packageMetasById) {
  const unsupportedReason = entry.unsupportedReason ?? entryUnsupportedReason(entry);
  const wrapperName = entryJsName(entry);
  const publicQualifiedName = `${entry.packageId}.${entryJsQualifiedName(entry)}`;
  if (unsupportedReason) {
    return [
      `export const ${wrapperName} = unsupportedExport(${JSON.stringify(publicQualifiedName)}, ${JSON.stringify(unsupportedReason)});`,
    ];
  }
  const fullExportName = moonWrapperExportName(entry);
  const runtimeReturnDescriptor = lowerRuntimeDescriptor(entry.returnDescriptor, helperNames, packageMetasById);
  if (entry.arityExports.length === 1) {
    const paramList = entry.params.map((param) => tsParamName(param)).join(', ');
    const callArgs = entry.params.map((param) => `lowerValue(${parameterRuntimeDescriptor(param, helperNames, packageMetasById)}, ${tsParamName(param)}, wasm)`);
    return [
      `export function ${wrapperName}(${paramList}) {`,
      `  return liftValue(${runtimeReturnDescriptor}, wasm[${JSON.stringify(fullExportName)}](${callArgs.join(', ')}), wasm);`,
      '}',
    ];
  }
  const paramsList = entry.params.map((param) => tsParamName(param)).join(', ');
  const lines = [];
  lines.push(`export function ${wrapperName}(${paramsList}) {`);
  lines.push('  const provided = countProvidedArgs(arguments);');
  lines.push('  switch (provided) {');
  for (const arityExport of entry.arityExports) {
    const usedParams = entry.params.slice(0, arityExport.arity);
    const loweredArgs = usedParams
      .map((param) => `lowerValue(${parameterRuntimeDescriptor(param, helperNames, packageMetasById)}, ${tsParamName(param)}, wasm)`)
      .join(', ');
    lines.push(`    case ${arityExport.arity}:`);
    lines.push(`      return liftValue(${runtimeReturnDescriptor}, wasm[${JSON.stringify(arityExport.exportName)}](${loweredArgs}), wasm);`);
  }
  lines.push('    default:');
  lines.push(`      throw new TypeError(${JSON.stringify(`Invalid argument count for ${publicQualifiedName}.`)});`);
  lines.push('  }');
  lines.push('}');
  return lines;
}

function generateJsObjectMethod(entry, helperNames, packageMetasById) {
  const unsupportedReason = entry.unsupportedReason ?? entryUnsupportedReason(entry);
  const methodName = entryJsName(entry);
  const publicQualifiedName = `${entry.packageId}.${entryJsQualifiedName(entry)}`;
  if (unsupportedReason) {
    return [
      `${methodName}: unsupportedExport(${JSON.stringify(publicQualifiedName)}, ${JSON.stringify(unsupportedReason)}),`,
    ];
  }
  const fullExportName = moonWrapperExportName(entry);
  const runtimeReturnDescriptor = lowerRuntimeDescriptor(entry.returnDescriptor, helperNames, packageMetasById);
  const paramsList = entry.params.map((param) => tsParamName(param)).join(', ');
  if (entry.arityExports.length === 1) {
    const loweredArgs = entry.params
      .map((param) => `lowerValue(${parameterRuntimeDescriptor(param, helperNames, packageMetasById)}, ${tsParamName(param)}, wasm)`)
      .join(', ');
    return [
      `${methodName}(${paramsList}) {`,
      `  return liftValue(${runtimeReturnDescriptor}, wasm[${JSON.stringify(fullExportName)}](${loweredArgs}), wasm);`,
      '},',
    ];
  }
  const lines = [];
  lines.push(`${methodName}(${paramsList}) {`);
  lines.push('  const provided = countProvidedArgs(arguments);');
  lines.push('  switch (provided) {');
  for (const arityExport of entry.arityExports) {
    const usedParams = entry.params.slice(0, arityExport.arity);
    const loweredArgs = usedParams
      .map((param) => `lowerValue(${parameterRuntimeDescriptor(param, helperNames, packageMetasById)}, ${tsParamName(param)}, wasm)`)
      .join(', ');
    lines.push(`    case ${arityExport.arity}:`);
    lines.push(`      return liftValue(${runtimeReturnDescriptor}, wasm[${JSON.stringify(arityExport.exportName)}](${loweredArgs}), wasm);`);
  }
  lines.push('    default:');
  lines.push(`      throw new TypeError(${JSON.stringify(`Invalid argument count for ${publicQualifiedName}.`)});`);
  lines.push('  }');
  lines.push('},');
  return lines;
}

function generatePackageDts(pkg, options = {}) {
  const sharedImport = options.sharedImport ?? JS_SHARED_IMPORT;
  const moduleImportPrefix = options.moduleImportPrefix ?? '.';
  const imports = {
    shared: false,
    byModule: new Map(),
  };
  const body = [];
  const localTypeNames = [...pkg.types.keys()].sort();

  for (const constant of pkg.constants) {
    body.push(`export const ${constantJsName(constant)}: ${renderTsType(parseTypeDescriptor(constant.typeRaw, pkg), pkg.id, imports)};`);
  }
  if (pkg.constants.length > 0) {
    body.push('');
  }

  for (const typeName of localTypeNames) {
    body.push(`export type ${typeName} = OpaqueHandle<${JSON.stringify(`${pkg.id}.${typeName}`)}>;`);
  }
  if (localTypeNames.length > 0) {
    body.push('');
  }

  for (const entry of pkg.values) {
    const unsupported = Boolean(entry.unsupportedReason ?? entryUnsupportedReason(entry));
    body.push(`export function ${entryJsName(entry)}${renderTsSignature(entry, pkg.id, imports, unsupported)};`);
  }
  if (pkg.values.length > 0) {
    body.push('');
  }

  for (const typeName of localTypeNames) {
    const type = pkg.types.get(typeName);
    const methods = pkg.methodsByType.get(typeName) ?? [];
    body.push(`export const ${typeName}: {`);
    for (const method of methods) {
      const unsupported = Boolean(method.unsupportedReason ?? entryUnsupportedReason(method));
      body.push(`  ${entryJsName(method) === "new" ? '"new"' : entryJsName(method)}${renderTsSignature(method, pkg.id, imports, unsupported)};`);
    }
    if (type?.show && !methods.some(method => entryJsName(method) === 'show')) {
      body.push(`  show(value: ${typeName}): string;`);
    }
    body.push('};');
    body.push('');
  }

  const importLines = [];
  if (imports.shared || localTypeNames.length > 0) {
    importLines.push(`import type { OpaqueHandle, StarshineResult } from ${JSON.stringify(sharedImport)};`);
  }
  for (const [moduleId, names] of [...imports.byModule.entries()].sort(([left], [right]) => left.localeCompare(right))) {
    if (moduleId === pkg.id || names.size === 0) {
      continue;
    }
    const sortedNames = [...names].sort().map(name => `${name} as ${moduleId}_${name}`).join(', ');
    importLines.push(`import type { ${sortedNames} } from ${JSON.stringify(`${moduleImportPrefix}/${moduleId}.js`)};`);
  }
  if (importLines.length > 0) {
    importLines.push('');
  }

  return [...importLines, ...body].join('\n').trimEnd();
}


export function generateNodePackage({ check = false } = {}) {
  checking = check;
  const generated = generateFfiPackage([...collectFfiInterfaces(repoRoot), ...standardTraitInterfaces()]);
  ffiSchema = generated.schema;
  for (const item of collectFfiInterfaces(repoRoot)) EXTERNAL_ALIAS_IMPORTS.set(`@${item.alias}`, item.packagePath);
  const storedSchema = JSON.parse(readText('ffi/src/ffi/export-schema.generated.json'));
  if (JSON.stringify(storedSchema) !== JSON.stringify(ffiSchema)) throw new Error('FFI schema drift: run bun ffi generate');
  const packageMetas = TARGET_PACKAGES.filter(pkg => !['passes', 'ir'].includes(pkg.id)).map(parsePackageMeta);
  // The optimizer facade is a concrete FFI bridge, with no callbacks or optimizer-internal types.
  const bridge = parsePackageMeta({ id: 'ffi_bridge', moonPackage: 'jtenner/starshine/ffi_bridge', alias: '@ffi_bridge' });
  bridge.values = bridge.values.filter(entry => entry.exportName === 'optimize_module');
  bridge.types = new Map(); bridge.methodsByType = new Map(); bridge.constants = [];
  packageMetas.push(bridge);
  const summaryType = packageMetas.find(pkg => pkg.id === 'wast').types.get('WastSpecRunSummary');
  summaryType.show = true; summaryType.debugShow = true;
  const catalog = buildInteropCatalog(packageMetas);
  const helpers = createHelperNames(catalog);
  const interop = generateMoonInterop(packageMetas, catalog, helpers);
  const selectedNames = new Set(packageMetas.flatMap(pkg => [...pkg.values, ...[...pkg.methodsByType.values()].flat()].filter(entry => !entryUnsupportedReason(entry)).map(entry => entry.ffi.sourceName)));
  const selectedForwarders = generated.source.split('\n\n').filter(block => [...selectedNames].some(name => block.includes(`pub fn ${name}(`))).join('\n\n').replace(/^#export_name\([^\n]+\)\n/gm, '');
  const adapterSource = '// Generated from the FFI export schema. DO NOT EDIT.\n' + selectedForwarders + '\n' + interop.source;
  const custom = readText('ffi/src/npm/custom.mbt');
  const customExports = [...custom.matchAll(/pub fn ([A-Za-z0-9_]+)\(/g)].map(match => match[1]);
  const aliases = new Set([...adapterSource.matchAll(/@([A-Za-z0-9_-]+)\./g)].map(match => match[1]));
  // Forwarders remain in the same compilation unit, so the FFI is the signature and call authority.
  const imports = [...collectFfiInterfaces(repoRoot), ...standardTraitInterfaces()].filter(item => aliases.has(item.alias)).map(item => `  "${item.packagePath}" @${item.alias},`);
  imports.push('  "moonbitlang/core/quickcheck/splitmix" @splitmix,');
  if (!aliases.has('cmd')) imports.push('  "jtenner/starshine/cmd" @cmd,');
  imports.push('  "moonbitlang/core/debug" @debug,');
  const allExports = [...interop.exports, ...customExports];
  const adapterManifest = `import {\n${imports.join('\n')}\n}\n\npkgtype(kind: "foreign_library")\n\noptions(\n  link: { "wasm-gc": {\n    "exports": [\n${allExports.map(name => `      "${name}",`).join("\n")}\n    ],\n    "use-js-builtin-string": true,\n    "imported-string-constants": "_",\n  } },\n)\n`;
  const formatted = formatGeneratedMoonBit(repoRoot, adapterSource, adapterManifest);
  writeText('ffi/src/npm/generated.mbt', formatted.source.trimEnd());
  writeText('ffi/src/npm/moon.pkg', formatted.manifest.trimEnd());
  for (const pkg of packageMetas) {
    const name = pkg.id === 'ffi_bridge' ? 'passes' : pkg.id;
    if (pkg.id === 'cmd') {
      writeText('node/internal/generated/cmd.generated.js', generatePackageJs(pkg, helpers, packageMetas, '../runtime.js'));
      writeText('node/internal/generated/cmd.generated.d.ts', generatePackageDts(pkg, { sharedImport: '../shared.js', moduleImportPrefix: '../..' }));
    } else {
      writeText(`node/${name}.js`, generatePackageJs(pkg, helpers, packageMetas));
      writeText(`node/${name}.d.ts`, generatePackageDts(pkg));
    }
  }
  generateCmdFacadeDeclarations(packageMetas.find(pkg => pkg.id === 'cmd'));
  writeText('node/internal/required-exports.json', JSON.stringify(allExports, null, 2));
  writeText('node/internal/unsupported-exports.json', JSON.stringify(packageMetas.flatMap(pkg => [...pkg.values, ...[...pkg.methodsByType.values()].flat()].filter(entry => entryUnsupportedReason(entry)).map(entry => ({ symbol: `${pkg.id}.${entry.fullName}`, reason: entryUnsupportedReason(entry) }))), null, 2));
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) generateNodePackage({ check: process.argv.includes('--check') });

function optionalDescriptor(param) { return { kind: 'option', raw: `(${param.typeRaw})?`, item: param.descriptor }; }
function parameterRuntimeDescriptor(param, helpers, metas) {
  const descriptor = lowerRuntimeDescriptor(param.optionalLabel ? optionalDescriptor(param) : param.descriptor, helpers, metas);
  return param.optionalLabel ? descriptor.replace('kind: "option"', 'kind: "optional"') : descriptor;
}

function generateCmdFacadeDeclarations(pkg) {
  const policy = JSON.parse(readText('ffi/src/npm/cmd-public-api.json'));
  const imports = { shared: true, byModule: new Map([['lib', new Set(['Module'])], ['binary', new Set(['EncodeError'])], ['cli', new Set(['CliInputFormat'])]]) };
  function signature(ffi) {
    if (!ffi) throw new Error('Public cmd export missing from FFI schema');
    const names = policy.parameterProjections[ffi.owner ? `${ffi.owner}::${ffi.name}` : ffi.name];
    const params = names ? names.map(name => { const param = ffi.params.find(item => item.name === name); if (!param) throw new Error(`cmd API parameter drift: ${name}`); return param; }) : ffi.params;
    const entry = { params: params.map((param, index) => ({ name: param.name, generatedName: `arg${index}`, optionalLabel: param.optional, descriptor: parseTypeDescriptor(param.type, pkg, ffi.owner) })), returnDescriptor: parseTypeDescriptor(ffi.returnType, pkg, ffi.owner) };
    return renderTsSignature(entry, 'cmd', imports, false);
  }
  const body = [];
  for (const name of policy.functions) {
    const ffi = ffiSchema.find(item => item.packageAlias === 'cmd' && !item.owner && toLowerCamelCase(item.name) === name);
    body.push(`export function ${name}${signature(ffi)};`);
  }
  for (const name of policy.factories) {
    body.push(`export const ${name}: {`);
    const methods = ffiSchema.filter(item => item.packageAlias === 'cmd' && item.owner === name);
    for (const method of methods) body.push(`  ${method.name === "new" ? '"new"' : toLowerCamelCase(method.name)}${signature(method)};`);
    if (pkg.types.get(name)?.show && !methods.some(method => method.name === 'show')) body.push(`  show(value: ${name}): string;`);
    body.push('};');
  }
  body.push('export const WasmSmithFuzzStats: typeof CmdFuzzStats;');
  body.push('export const runWasmSmithFuzzHarness: typeof runCmdFuzzHarness;');
  body.push('export const runWasmSmithFuzzHarnessProfile: typeof runCmdFuzzHarnessProfile;');
  const header = ['// Generated from the FFI schema and explicit JavaScript facade projections. DO NOT EDIT.', `import type { OpaqueHandle, StarshineResult } from './internal/shared.js';`];
  for (const [moduleId, names] of imports.byModule) header.push(`import type { ${[...names].sort().map(name => `${name} as ${moduleId}_${name}`).join(', ')} } from './${moduleId}.js';`);
  writeText('node/cmd.d.ts', [...header, readText('ffi/src/npm/cmd-model.d.ts'), ...body].join('\n'));
}

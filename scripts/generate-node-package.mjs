#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..');

const TARGET_PACKAGES = [
  { id: 'binary', moonPackage: 'jtenner/starshine/binary', alias: '@binary' },
  { id: 'cli', moonPackage: 'jtenner/starshine/cli', alias: '@cli' },
  { id: 'cmd', moonPackage: 'jtenner/starshine/cmd', alias: '@cmd' },
  { id: 'ir', moonPackage: 'jtenner/starshine/ir', alias: '@ir' },
  { id: 'lib', moonPackage: 'jtenner/starshine/lib', alias: '@lib' },
  { id: 'passes', moonPackage: 'jtenner/starshine/passes', alias: '@passes' },
  { id: 'transformer', moonPackage: 'jtenner/starshine/transformer', alias: '@transformer' },
  { id: 'validate', moonPackage: 'jtenner/starshine/validate', alias: '@validate' },
  { id: 'wast', moonPackage: 'jtenner/starshine/wast', alias: '@wast' },
  { id: 'wat', moonPackage: 'jtenner/starshine/wat', alias: '@wat' },
];

const TARGET_PACKAGE_IDS = new Set(TARGET_PACKAGES.map((pkg) => pkg.id));
const PACKAGE_BY_ALIAS = new Map(TARGET_PACKAGES.map((pkg) => [pkg.alias, pkg.id]));
const PACKAGE_BY_ID = new Map(TARGET_PACKAGES.map((pkg) => [pkg.id, pkg]));

const JS_SHARED_IMPORT = './internal/shared.js';
const RUNTIME_IMPORT = './internal/runtime.js';
const HAND_AUTHORED_PACKAGE_OVERRIDES = new Set(['cmd', 'passes']);
const CUSTOM_MOON_EXPORTS = [
  '__node_cli_parse_result_has_config_path',
  '__node_cli_parse_result_get_config_path',
  '__node_cli_parse_result_input_globs_length',
  '__node_cli_parse_result_input_globs_get',
  '__node_cli_parse_result_help_requested',
  '__node_cli_parse_result_version_requested',
  '__node_cli_parse_result_read_stdin',
  '__node_cli_parse_result_has_input_format',
  '__node_cli_parse_result_get_input_format',
  '__node_cli_parse_result_output_targets_length',
  '__node_cli_parse_result_output_targets_get',
  '__node_cli_parse_result_pass_flags_length',
  '__node_cli_parse_result_pass_flags_get',
  '__node_cli_parse_result_optimize_flags_length',
  '__node_cli_parse_result_optimize_flags_get',
  '__node_cli_parse_result_has_trap_mode',
  '__node_cli_parse_result_get_trap_mode',
  '__node_cli_parse_result_has_monomorphize_min_benefit',
  '__node_cli_parse_result_get_monomorphize_min_benefit',
  '__node_cli_parse_result_has_low_memory_unused',
  '__node_cli_parse_result_get_low_memory_unused',
  '__node_cli_parse_result_has_low_memory_bound',
  '__node_cli_parse_result_get_low_memory_bound',
  '__node_cli_input_format_name',
  '__node_cli_output_target_kind',
  '__node_cli_output_target_path',
  '__node_cli_optimization_flag_kind',
  '__node_cli_optimization_flag_level',
  '__node_cli_optimization_flag_size_bias',
  '__node_cli_trap_mode_name',
  '__node_cmd_can_expand_passes_for_cli',
  '__node_cmd_expand_passes_for_cli_error',
  '__node_cmd_expand_passes_for_cli_length',
  '__node_cmd_expand_passes_for_cli_get',
  '__node_passes_can_resolve_module_pass',
  '__node_passes_resolve_module_pass_error',
  '__node_passes_resolve_module_pass',
  '__node_passes_directize',
  '__node_wast_spec_run_summary_total_files',
  '__node_wast_spec_run_summary_passed_files',
  '__node_wast_spec_run_summary_skipped_files',
  '__node_wast_spec_run_summary_failed_files',
  '__node_wast_spec_run_summary_files_length',
  '__node_wast_spec_run_summary_files_get',
  '__node_wast_spec_file_report_path',
  '__node_wast_spec_file_report_status',
  '__node_wast_spec_file_status_kind',
  '__node_wast_spec_file_status_message',
  '__node_splitmix_new',
];

const PUBLISHED_EXAMPLES = [
  {
    file: 'examples/01-barrel-roundtrip.mjs',
    description: 'Parse text, encode to wasm bytes, decode again, and validate through the root barrel export.',
  },
  {
    file: 'examples/02-binary-decode-detail.mjs',
    description: 'Use the binary adapter to decode a wasm payload and inspect the trailing offset detail.',
  },
  {
    file: 'examples/03-binary-size-helpers.mjs',
    description: 'Call the signed and unsigned LEB128 size helpers from the binary package.',
  },
  {
    file: 'examples/04-cli-parse-help.mjs',
    description: 'Parse CLI flags, show the parse result, and resolve pass and trap-mode settings.',
  },
  {
    file: 'examples/05-cli-schema-and-paths.mjs',
    description: 'Inspect the CLI config schema and use the path, glob, and format inference helpers.',
  },
  {
    file: 'examples/06-cmd-help-and-version.mjs',
    description: 'Read the packaged CLI help text and version banner from the cmd bridge.',
  },
  {
    file: 'examples/07-cmd-run-with-adapter.mjs',
    description: 'Run the CLI with a custom in-memory CmdIO adapter and capture the help text.',
  },
  {
    file: 'examples/08-cmd-run-filesystem.mjs',
    description: 'Run the CLI against a temporary .wat file using the default host-backed filesystem integration.',
  },
  {
    file: 'examples/09-cmd-differential-validation.mjs',
    description: 'Validate a wasm binary with the internal validator and custom external adapter hooks.',
  },
  {
    file: 'examples/10-cmd-persist-fuzz-report.mjs',
    description: 'Persist a fuzz failure report through the JS persistence hooks without touching the real filesystem.',
  },
  {
    file: 'examples/11-passes-optimize-module.mjs',
    description: 'Build an ordered manual optimization pipeline and append explicit pass constructors.',
  },
  {
    file: 'examples/12-wast-module-roundtrip.mjs',
    description: 'Parse a WAST module AST and print it back to canonical WAST text.',
  },
  {
    file: 'examples/13-wast-script-roundtrip.mjs',
    description: 'Parse a WAST script and print the normalized script text.',
  },
  {
    file: 'examples/14-wast-spec-suite.mjs',
    description: 'Run the in-memory WAST spec harness and print the summary report.',
  },
];

const NO_ARG_MODULE_PASS_FLAGS = [
  'alignment-lowering',
  'avoid-reinterprets',
  'coalesce-locals',
  'code-folding',
  'code-pushing',
  'const-hoisting',
  'constant-field-propagation',
  'dataflow-optimization',
  'dead-code-elimination',
  'dead-argument-elimination',
  'dead-argument-elimination-optimizing',
  'signature-pruning',
  'signature-refining',
  'duplicate-import-elimination',
  'global-refining',
  'global-struct-inference',
  'global-struct-inference-desc-cast',
  'global-type-optimization',
  'simplify-globals',
  'simplify-globals-optimizing',
  'global-effects',
  'propagate-globals-globally',
  'type-refining',
  'type-generalizing',
  'type-finalizing',
  'type-un-finalizing',
  'unsubtyping',
  'heap2local',
  'heap-store-optimization',
  'inlining',
  'inlining-optimizing',
  'inline-main',
  'local-cse',
  'local-subtyping',
  'loop-invariant-code-motion',
  'merge-locals',
  'merge-similar-functions',
  'merge-blocks',
  'flatten',
  're-reloop',
  'tuple-optimization',
  'once-reduction',
  'minimize-rec-groups',
  'type-merging',
  'monomorphize',
  'monomorphize-always',
  'optimize-added-constants',
  'optimize-added-constants-propagate',
  'optimize-instructions',
  'precompute',
  'precompute-propagate',
  'redundant-set-elimination',
  'pick-load-signs',
  'gufa',
  'gufa-optimizing',
  'gufa-cast-all',
  'i64-to-i32-lowering',
  'duplicate-function-elimination',
  'optimize-casts',
  'de-nan',
  'remove-unused-brs',
  'remove-unused-names',
  'simplify-locals',
  'simplify-locals-no-tee',
  'simplify-locals-no-structure',
  'simplify-locals-no-tee-no-structure',
  'simplify-locals-no-nesting',
  'untee',
  'vacuum',
  'reorder-locals',
  'reorder-types',
  'reorder-globals',
  'reorder-globals-always',
  'reorder-functions',
  'reorder-functions-by-name',
  'remove-unused-types',
  'remove-unused',
  'remove-unused-module-elements',
  'remove-unused-non-function-elements',
];

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
  fs.writeFileSync(absolutePath, normalized);
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

function parseTypeDescriptor(rawType, packageMeta, ownerTypeName = null) {
  const raw = rawType.trim();
  if (raw.length === 0) {
    throw new Error('Expected a non-empty type');
  }
  const topLevelArrow = findTopLevelArrow(raw);
  if (topLevelArrow >= 0) {
    return {
      kind: 'function',
      raw,
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
    return {
      kind: 'genericOpaque',
      raw,
      head,
      items: innerParts.map((part) => parseTypeDescriptor(part, packageMeta, ownerTypeName)),
    };
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
    return {
      kind: 'externalNamed',
      raw,
    };
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
  return {
    kind: 'externalNamed',
    raw,
  };
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

function parseParameter(rawParameter, parameterIndex, packageMeta, ownerTypeName) {
  const raw = rawParameter.trim();
  const generatedName = `arg${parameterIndex}`;
  if (raw.length === 0) {
    return null;
  }
  const colonParts = splitTopLevel(raw, ':');
  if (colonParts.length === 1) {
    const typeRaw = colonParts[0];
    return {
      index: parameterIndex,
      raw,
      name: generatedName,
      generatedName,
      optionalLabel: false,
      labelOnly: false,
      typeRaw,
      descriptor: parseTypeDescriptor(typeRaw, packageMeta, ownerTypeName),
    };
  }
  if (colonParts.length !== 2) {
    throw new Error(`Unable to parse parameter "${raw}"`);
  }
  const left = colonParts[0].trim();
  const typeRaw = colonParts[1].trim();
  const optionalLabel = left.endsWith('?');
  const labelOnly = left.endsWith('~');
  const name = left.replace(/[?~]$/, '').trim() || generatedName;
  return {
    index: parameterIndex,
    raw,
    name,
    generatedName,
    optionalLabel,
    labelOnly,
    typeRaw,
    descriptor: parseTypeDescriptor(typeRaw, packageMeta, ownerTypeName),
  };
}

function parseFunctionLine(line, packageMeta) {
  let content;
  let generic = false;
  if (line.startsWith('pub fn[')) {
    generic = true;
    content = line.slice('pub fn'.length).trimStart();
    const genericEnd = findMatchingBracket(content, 0, '[', ']');
    content = content.slice(genericEnd + 1).trimStart();
  } else {
    content = line.slice('pub fn '.length);
  }
  const nameEnd = content.indexOf('(');
  const fullName = content.slice(0, nameEnd).trim();
  const paramsEnd = findMatchingBracket(content, nameEnd, '(', ')');
  const paramsRaw = content.slice(nameEnd + 1, paramsEnd).trim();
  const returnAndMaybeRaise = content.slice(paramsEnd + 1).trim();
  if (!returnAndMaybeRaise.startsWith('->')) {
    throw new Error(`Unable to parse return type from "${line}"`);
  }
  const returnPieces = returnAndMaybeRaise.slice(2).trim().split(/\s+raise\s+/);
  const returnTypeRaw = returnPieces[0].trim();
  const hasRaise = returnPieces.length > 1;
  const ownerSplit = fullName.split('::');
  const ownerTypeName = ownerSplit.length === 2 ? ownerSplit[0] : null;
  const exportName = ownerSplit.length === 2 ? ownerSplit[1] : ownerSplit[0];
  const params = paramsRaw.length === 0
    ? []
    : splitTopLevel(paramsRaw, ',')
      .map((param, index) => parseParameter(param, index, packageMeta, ownerTypeName))
      .filter(Boolean);
  return {
    packageId: packageMeta.id,
    ownerTypeName,
    fullName,
    exportName,
    generic,
    hasRaise,
    params,
    returnTypeRaw,
    returnDescriptor: parseTypeDescriptor(returnTypeRaw, packageMeta, ownerTypeName),
  };
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

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index].trim();
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
      continue;
    }
    if (line.startsWith('pub fn ') || line.startsWith('pub fn[')) {
      const entry = parseFunctionLine(line, packageMeta);
      if (entry.ownerTypeName) {
        if (!methodsByType.has(entry.ownerTypeName)) {
          methodsByType.set(entry.ownerTypeName, []);
        }
        methodsByType.get(entry.ownerTypeName).push(entry);
      } else {
        values.push(entry);
      }
    }
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
        collectCompositeDescriptors(param.descriptor, state);
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
      lines.push('  value.to_string()');
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
      const requiredCount = entry.params.filter((param) => !param.optionalLabel).length;
      const totalCount = entry.params.length;
      entry.arityExports = [];
      for (let arity = requiredCount; arity <= totalCount; arity += 1) {
        const exportName = arity === totalCount
          ? moonWrapperExportName(entry)
          : `${moonWrapperExportName(entry)}__arity_${arity}`;
        const usedParams = entry.params.slice(0, arity);
        const signature = usedParams
          .map((param, index) => `${param.generatedName} : ${makeMoonType(param.descriptor)}`)
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

  lines.push('fn main {');
  lines.push('  ()');
  lines.push('}');

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
  const callTarget = entry.ownerTypeName
    ? `@${entry.packageId}.${entry.ownerTypeName}::${entry.exportName}`
    : `@${entry.packageId}.${entry.exportName}`;
  const params = entry.params.slice(0, arity);
  const callArgs = params.map((param) => {
    if (param.optionalLabel) {
      return `${param.name}=${param.generatedName}`;
    }
    return param.generatedName;
  });
  return `${callTarget}(${callArgs.join(', ')})`;
}

function lowerRuntimeDescriptor(descriptor, helperNames, packageMetas) {
  switch (descriptor.kind) {
    case 'primitive':
      return `{ kind: ${JSON.stringify(descriptor.primitive)} }`;
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
      return `${renderTsType(descriptor.item, currentPackageId, imports)} | null`;
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
      return descriptor.typeName;
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
      return '(...args: never[]) => never';
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
    return `${tsParamName(param)}${optional}: ${renderTsType(param.descriptor, currentPackageId, imports)}`;
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
    if (showExport) {
      lines.push(`  show(value) {`);
      lines.push(`    return wasm[${JSON.stringify(showExport)}](value);`);
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
    const callArgs = entry.params.map((param) => `lowerValue(${lowerRuntimeDescriptor(param.descriptor, helperNames, packageMetasById)}, ${tsParamName(param)}, wasm)`);
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
      .map((param) => `lowerValue(${lowerRuntimeDescriptor(param.descriptor, helperNames, packageMetasById)}, ${tsParamName(param)}, wasm)`)
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
      .map((param) => `lowerValue(${lowerRuntimeDescriptor(param.descriptor, helperNames, packageMetasById)}, ${tsParamName(param)}, wasm)`)
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
      .map((param) => `lowerValue(${lowerRuntimeDescriptor(param.descriptor, helperNames, packageMetasById)}, ${tsParamName(param)}, wasm)`)
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
      body.push(`  ${entryJsName(method)}${renderTsSignature(method, pkg.id, imports, unsupported)};`);
    }
    if (type?.show) {
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
    const sortedNames = [...names].sort().join(', ');
    importLines.push(`import type { ${sortedNames} } from ${JSON.stringify(`${moduleImportPrefix}/${moduleId}.js`)};`);
  }
  if (importLines.length > 0) {
    importLines.push('');
  }

  return [...importLines, ...body].join('\n').trimEnd();
}

function packageSummary(pkg) {
  return `${pkg.id}.js exposes the public JS adapter for ${pkg.moonPackage}.`;
}

function describeEntry(entry) {
  const rawQualifiedName = entryQualifiedName(entry);
  const jsQualifiedName = entryJsQualifiedName(entry);
  if (entry.unsupportedReason) {
    return entry.unsupportedReason;
  }
  if (entry.ownerTypeName && entry.exportName === 'new') {
    return `Create a ${entry.ownerTypeName} value.`;
  }
  if (entry.exportName === 'inner') {
    return `Return the wrapped inner value from ${entry.ownerTypeName}.`;
  }
  if (entry.exportName.startsWith('decode_')) {
    return `Decode ${rawQualifiedName.replace(/^decode_/, '').replace(/_/g, ' ')}.`;
  }
  if (entry.exportName.startsWith('encode_')) {
    return `Encode ${rawQualifiedName.replace(/^encode_/, '').replace(/_/g, ' ')}.`;
  }
  if (entry.exportName.startsWith('validate_')) {
    return `Validate ${rawQualifiedName.replace(/^validate_/, '').replace(/_/g, ' ')}.`;
  }
  if (entry.exportName.startsWith('parse_')) {
    return `Parse ${rawQualifiedName.replace(/^parse_/, '').replace(/_/g, ' ')}.`;
  }
  if (entry.exportName.startsWith('lookup_')) {
    return `Look up ${rawQualifiedName.replace(/^lookup_/, '').replace(/_/g, ' ')}.`;
  }
  if (entry.exportName.startsWith('module_to_') || entry.exportName.includes('_to_')) {
    return `Convert values with ${jsQualifiedName}.`;
  }
  if (entry.exportName.startsWith('run_')) {
    return `Run ${rawQualifiedName.replace(/^run_/, '').replace(/_/g, ' ')}.`;
  }
  if (entry.exportName.startsWith('resolve_')) {
    return `Resolve ${rawQualifiedName.replace(/^resolve_/, '').replace(/_/g, ' ')}.`;
  }
  if (entry.exportName.startsWith('infer_')) {
    return `Infer ${rawQualifiedName.replace(/^infer_/, '').replace(/_/g, ' ')}.`;
  }
  if (entry.exportName.startsWith('normalize_')) {
    return `Normalize ${rawQualifiedName.replace(/^normalize_/, '').replace(/_/g, ' ')}.`;
  }
  if (entry.exportName.startsWith('with_')) {
    return `Return an updated value from ${jsQualifiedName}.`;
  }
  if (entry.exportName.startsWith('get_')) {
    return `Read data with ${jsQualifiedName}.`;
  }
  if (entry.exportName.startsWith('has_')) {
    return `Check ${rawQualifiedName.replace(/^has_/, '').replace(/_/g, ' ')}.`;
  }
  return `Call ${jsQualifiedName}.`;
}

function pushReadmeEntry(lines, signature, description) {
  lines.push(`- \`${signature}\``);
  lines.push(`  ${description}`);
}

function renderCmdReadmeSection(lines) {
  lines.push('### cmd');
  lines.push('');
  lines.push("Import directly with `import * as cmd from '@jtenner/starshine/cmd';` or from the root barrel.");
  lines.push('');
  lines.push('This module uses a hand-authored Node bridge for callback-backed APIs, filesystem/process integration, and native differential validation tools.');
  lines.push('');

  pushReadmeEntry(lines, 'cmdHelpText(): string', 'Return the CLI help text.');
  pushReadmeEntry(lines, 'cmdVersionText(): string', 'Return the CLI version banner.');
  pushReadmeEntry(
    lines,
    'differentialValidateWasm(bytes: Uint8Array, adapters?: DifferentialAdapters): StarshineResult<DifferentialValidationReport, string>',
    'Validate a wasm binary with the internal validator and optional external tool adapters.',
  );
  pushReadmeEntry(
    lines,
    'minimizeFuzzPasses(passes: Array<string>, reproduces: (passes: Array<string>) => boolean): Array<string>',
    'Minimize a reproducing pass list by repeatedly invoking the provided predicate.',
  );
  pushReadmeEntry(
    lines,
    'nativeDifferentialToolsAvailable(): [boolean, boolean]',
    'Report whether `wasm-tools validate` and `wasm-validate` are available on the host PATH.',
  );
  pushReadmeEntry(
    lines,
    'persistFuzzFailureReport(report: FuzzFailureReport, io: FuzzFailurePersistIO, corpusDir?: string): StarshineResult<[string, string | null], string>',
    'Write a fuzz failure report and optional wasm payload into a corpus directory.',
  );
  pushReadmeEntry(
    lines,
    'runCmd(args: Array<string>): StarshineResult<CmdRunSummary, CmdError>',
    'Run the Starshine CLI with the default host-backed I/O adapter.',
  );
  pushReadmeEntry(lines, 'runCmdExitCode(args: Array<string>): number', 'Run the CLI and return only the exit code.');
  pushReadmeEntry(
    lines,
    'runCmdExitCodeWithAdapter(args: Array<string>, io: CmdIO, configJson?: string | null): number',
    'Run the CLI with a custom adapter and return only the exit code.',
  );
  pushReadmeEntry(
    lines,
    'runCmdWithAdapter(args: Array<string>, io: CmdIO, configJson?: string | null): StarshineResult<CmdRunSummary, CmdError>',
    'Run the CLI with an explicit host adapter for filesystem, encoding, stdout, and stderr operations.',
  );
  pushReadmeEntry(
    lines,
    'runWasmSmithFuzzHarness(validTarget: number, seed?: bigint, optimizePasses?: Array<ModulePass>, optimizePassNames?: Array<string> | null, differentialAdapters?: DifferentialAdapters | null, differentialEvery?: number, onFailure?: ((report: FuzzFailureReport) => StarshineResult<void, string>) | null): StarshineResult<WasmSmithFuzzStats, string>',
    'Run the wasm-smith fuzz harness with optional pass scheduling, differential validation, and failure persistence hooks.',
  );
  pushReadmeEntry(
    lines,
    'verifyReadmeApiSignatures(text: string, signatures: Array<[string, string]>): StarshineResult<void, string>',
    'Verify that README text contains every required API signature marker.',
  );
  pushReadmeEntry(
    lines,
    'verifyReadmeApiSignaturesWithRequiredBlocks(text: string, signatures: Array<[string, string]>, requiredBlocks: Array<string>): StarshineResult<void, string>',
    'Verify README signatures and enforce additional required marker blocks.',
  );
  lines.push('');

  lines.push('Type namespace `CmdEncodeError`');
  pushReadmeEntry(lines, 'CmdEncodeError.adapter(message: string): CmdEncodeError', 'Create an adapter-backed encoding error.');
  pushReadmeEntry(lines, 'CmdEncodeError.encode(value: EncodeError): CmdEncodeError', 'Wrap a binary encoder error.');
  pushReadmeEntry(lines, 'CmdEncodeError.show(value: CmdEncodeError): string', 'Format the value with its JS display string.');
  lines.push('');

  lines.push('Type namespace `CmdError`');
  pushReadmeEntry(lines, 'CmdError.ambiguousOutputFile(path: string): CmdError', 'Create an ambiguous output target error.');
  pushReadmeEntry(lines, 'CmdError.unknownPassFlag(flag: string): CmdError', 'Create an unknown pass flag error.');
  pushReadmeEntry(lines, 'CmdError.show(value: CmdError): string', 'Format the value with its JS display string.');
  lines.push('');

  lines.push('Type namespace `CmdIO`');
  pushReadmeEntry(
    lines,
    'CmdIO.new(getEnv?: (name: string) => string | null, fileExists?: (path: string) => boolean, readFile?: (path: string) => StarshineResult<Uint8Array, string>, encodeModule?: (mod: Module) => StarshineResult<Uint8Array, CmdEncodeError>, writeFile?: (path: string, bytes: Uint8Array) => StarshineResult<void, string>, writeStdout?: (bytes: Uint8Array) => StarshineResult<void, string>, writeStderr?: (bytes: Uint8Array) => StarshineResult<void, string>, listCandidates?: () => Array<string>, lowerTextModule?: (path: string, format: CliInputFormat, bytes: Uint8Array) => StarshineResult<Uint8Array, string>): CmdIO',
    'Create a custom CLI host adapter.',
  );
  lines.push('');

  lines.push('Type namespace `CmdRunSummary`');
  pushReadmeEntry(
    lines,
    'CmdRunSummary.new(inputFiles?: Array<string>, outputFiles?: Array<string>, resolvedPasses?: Array<string>, optimizeLevel?: number, shrinkLevel?: number, trapsNeverHappen?: boolean, monomorphizeMinBenefit?: number, lowMemoryUnused?: boolean, lowMemoryBound?: bigint): CmdRunSummary',
    'Create a command run summary value.',
  );
  pushReadmeEntry(lines, 'CmdRunSummary.show(value: CmdRunSummary): string', 'Format the value with its JS display string.');
  lines.push('');

  lines.push('Type namespace `DifferentialAdapters`');
  pushReadmeEntry(
    lines,
    'DifferentialAdapters.new(wasmToolsValidate?: (bytes: Uint8Array) => StarshineResult<boolean, string>, binaryenValidate?: (bytes: Uint8Array) => StarshineResult<boolean, string>): DifferentialAdapters',
    'Create adapters for external validation tools.',
  );
  lines.push('');

  lines.push('Type namespace `DifferentialValidationReport`');
  pushReadmeEntry(lines, 'DifferentialValidationReport.show(value: DifferentialValidationReport): string', 'Format the value with its JS display string.');
  lines.push('');

  lines.push('Type namespace `FuzzFailurePersistIO`');
  pushReadmeEntry(
    lines,
    'FuzzFailurePersistIO.new(ensureDir?: (path: string) => StarshineResult<void, string>, writeFile?: (path: string, bytes: Uint8Array) => StarshineResult<void, string>): FuzzFailurePersistIO',
    'Create persistence hooks for minimized fuzz failures.',
  );
  lines.push('');

  lines.push('Type namespace `FuzzFailureReport`');
  pushReadmeEntry(
    lines,
    'FuzzFailureReport.new(seed: bigint, attempt: number, generatedValid: number, stage: string, message: string, optimizePasses?: Array<string>, minimizedPasses?: Array<string>, wasm?: Uint8Array | null): FuzzFailureReport',
    'Create a fuzz failure report value.',
  );
  pushReadmeEntry(lines, 'FuzzFailureReport.show(value: FuzzFailureReport): string', 'Format the value with its JS display string.');
  lines.push('');

  lines.push('Type namespace `ReadmeApiVerifyBlock`');
  pushReadmeEntry(lines, 'ReadmeApiVerifyBlock.show(value: ReadmeApiVerifyBlock): string', 'Format the value with its MoonBit `Show` implementation.');
  lines.push('');

  lines.push('Type namespace `WasmSmithFuzzStats`');
  pushReadmeEntry(
    lines,
    'WasmSmithFuzzStats.new(attempts?: number, generatedValid?: number, generatedInvalid?: number, pipelineValidated?: number, optimized?: number, roundtripped?: number, differentialChecked?: number): WasmSmithFuzzStats',
    'Create a fuzz harness statistics value.',
  );
  pushReadmeEntry(lines, 'WasmSmithFuzzStats.show(value: WasmSmithFuzzStats): string', 'Format the value with its JS display string.');
  lines.push('');
}

function passFlagToJsName(flag) {
  return toLowerCamelCase(flag);
}

function renderPassesOverlayJs() {
  const lines = [];
  lines.push("import { getWasmGcExports } from './internal/runtime.js';");
  lines.push('');
  lines.push("export * from './internal/generated/passes.generated.js';");
  lines.push('');
  lines.push('const wasm = await getWasmGcExports();');
  lines.push('');
  lines.push('function resolveModulePass(name) {');
  lines.push('  if (!wasm.__node_passes_can_resolve_module_pass(name)) {');
  lines.push('    throw new RangeError(wasm.__node_passes_resolve_module_pass_error(name));');
  lines.push('  }');
  lines.push('  return wasm.__node_passes_resolve_module_pass(name);');
  lines.push('}');
  lines.push('');
  lines.push('export function modulePass(name) {');
  lines.push('  return resolveModulePass(name);');
  lines.push('}');
  lines.push('');
  for (const flag of NO_ARG_MODULE_PASS_FLAGS) {
    lines.push(`export function ${passFlagToJsName(flag)}() {`);
    lines.push(`  return resolveModulePass(${JSON.stringify(flag)});`);
    lines.push('}');
    lines.push('');
  }
  lines.push('export function directize(always = false) {');
  lines.push('  return wasm.__node_passes_directize(Boolean(always));');
  lines.push('}');
  return lines.join('\n').trimEnd();
}

function renderPassesOverlayDts() {
  const lines = [];
  lines.push("export * from './internal/generated/passes.generated.js';");
  lines.push("import type { ModulePass } from './internal/generated/passes.generated.js';");
  lines.push('');
  lines.push('export function modulePass(name: string): ModulePass;');
  for (const flag of NO_ARG_MODULE_PASS_FLAGS) {
    lines.push(`export function ${passFlagToJsName(flag)}(): ModulePass;`);
  }
  lines.push('export function directize(always?: boolean): ModulePass;');
  return lines.join('\n').trimEnd();
}

function renderPassesReadmeSection(lines, pkg) {
  lines.push('### passes');
  lines.push('');
  lines.push("Import directly with `import * as passes from '@jtenner/starshine/passes';` or from the root barrel.");
  lines.push('');
  lines.push('Manual pipelines can be built by ordering `ModulePass` values in a plain JS array, then passing that array to `optimizeModule(...)` or `optimizeModuleWithOptions(...)`.');
  lines.push('');
  lines.push('```js');
  lines.push("const pipeline = passes.defaultFunctionOptimizationPasses(mod, options);");
  lines.push('pipeline.push(passes.deadArgumentElimination());');
  lines.push('pipeline.push(passes.vacuum());');
  lines.push('```');
  lines.push('');
  pushReadmeEntry(lines, 'modulePass(name: string): ModulePass', 'Resolve one of the canonical explicit pass names into a `ModulePass` value.');
  pushReadmeEntry(lines, 'deadArgumentElimination(): ModulePass', 'Create `ModulePass::DeadArgumentElimination` for manual ordered pipelines.');
  pushReadmeEntry(lines, 'vacuum(): ModulePass', 'Create `ModulePass::Vacuum` for manual cleanup placement.');
  pushReadmeEntry(lines, 'directize(always?: boolean): ModulePass', 'Create `ModulePass::Directize`, defaulting `always` to `false`.');
  lines.push('');
  for (const entry of pkg.values) {
    const tsImports = { shared: false, byModule: new Map() };
    const signature = renderTsSignature(entry, pkg.id, tsImports, Boolean(entry.unsupportedReason ?? entryUnsupportedReason(entry)));
    lines.push(`- \`${entryJsName(entry)}${signature}\``);
    lines.push(`  ${describeEntry(entry)}`);
  }
  if (pkg.values.length > 0) {
    lines.push('');
  }
  for (const typeName of [...pkg.types.keys()].sort()) {
    const type = pkg.types.get(typeName);
    const methods = pkg.methodsByType.get(typeName) ?? [];
    if (methods.length === 0 && !type?.show) {
      continue;
    }
    lines.push(`Type namespace \`${typeName}\``);
    for (const method of methods) {
      const tsImports = { shared: false, byModule: new Map() };
      const signature = renderTsSignature(method, pkg.id, tsImports, Boolean(method.unsupportedReason ?? entryUnsupportedReason(method)));
      lines.push(`- \`${typeName}.${entryJsName(method)}${signature}\``);
      lines.push(`  ${describeEntry(method)}`);
    }
    if (type?.show) {
      lines.push(`- \`${typeName}.show(value: ${typeName}): string\``);
      lines.push('  Format the value with its MoonBit `Show` implementation.');
    }
    lines.push('');
  }
}

function renderReadme(packageMetas) {
  const lines = [];
  lines.push('# Starshine Node Package');
  lines.push('');
  lines.push('This package publishes Starshine as an ESM-first Node package backed by two generated WebAssembly artifacts:');
  lines.push('');
  lines.push('- `./internal/starshine.wasm-gc.wasm` for the package-level JavaScript API.');
  lines.push('- `./internal/starshine.wasm-wasi.wasm` for the optimized WASI CLI artifact shipped alongside the npm package.');
  lines.push('');
  lines.push('## Requirements');
  lines.push('');
  lines.push('- Node.js 25 or newer with WebAssembly GC and JS string builtins available.');
  lines.push('- MoonBit on `PATH`, or `MOON_BIN` pointing at the Moon executable.');
  lines.push('');
  lines.push('## Build');
  lines.push('');
  lines.push('```bash');
  lines.push('npm --prefix node run build');
  lines.push('```');
  lines.push('');
  lines.push('This regenerates the adapter sources, rebuilds the `wasm-gc` package adapter, rebuilds the optimized WASI CLI artifact, and copies both outputs into `node/internal/`.');
  lines.push('');
  lines.push('## Use');
  lines.push('');
  lines.push('```js');
  lines.push("import { binary, wast } from '@jtenner/starshine';");
  lines.push('');
  lines.push("const parsed = wast.wastToBinaryModule('(module)');");
  lines.push("if (!parsed.ok) throw new Error(parsed.display ?? 'failed to parse');");
  lines.push('');
  lines.push('const encoded = binary.encodeModule(parsed.value);');
  lines.push("if (!encoded.ok) throw new Error(encoded.display ?? 'failed to encode');");
  lines.push('');
  lines.push('console.log(encoded.value instanceof Uint8Array);');
  lines.push('```');
  lines.push('');
  lines.push('```bash');
  lines.push('npx @jtenner/starshine --help');
  lines.push('```');
  lines.push('');
  lines.push('## Examples');
  lines.push('');
  lines.push('Run any shipped example from the package root:');
  lines.push('');
  lines.push('```bash');
  lines.push('node examples/01-barrel-roundtrip.mjs');
  lines.push('```');
  lines.push('');
  lines.push('All examples are executed by the package test suite.');
  lines.push('');
  for (const example of PUBLISHED_EXAMPLES) {
    lines.push(`- \`${example.file}\`: ${example.description}`);
  }
  lines.push('');
  lines.push('## Modules');
  lines.push('');
  for (const pkg of packageMetas) {
    lines.push(`- \`${pkg.id}\`: ${packageSummary(pkg)}`);
  }
  lines.push('');
  lines.push('## Public API');
  lines.push('');
  for (const pkg of packageMetas) {
    if (HAND_AUTHORED_PACKAGE_OVERRIDES.has(pkg.id) && pkg.id === 'cmd') {
      renderCmdReadmeSection(lines);
      continue;
    }
    if (HAND_AUTHORED_PACKAGE_OVERRIDES.has(pkg.id) && pkg.id === 'passes') {
      renderPassesReadmeSection(lines, pkg);
      continue;
    }
    lines.push(`### ${pkg.id}`);
    lines.push('');
    lines.push(`Import directly with \`import * as ${pkg.id} from '@jtenner/starshine/${pkg.id}';\` or from the root barrel.`);
    lines.push('');
    if (pkg.constants.length > 0) {
      lines.push('Constants:');
      for (const constant of pkg.constants) {
        lines.push(`- \`${constantJsName(constant)}: ${constant.typeRaw}\``);
      }
      lines.push('');
    }
    for (const entry of pkg.values) {
      const tsImports = { shared: false, byModule: new Map() };
      const signature = renderTsSignature(entry, pkg.id, tsImports, Boolean(entry.unsupportedReason ?? entryUnsupportedReason(entry)));
      lines.push(`- \`${entryJsName(entry)}${signature}\``);
      lines.push(`  ${describeEntry(entry)}`);
    }
    if (pkg.values.length > 0) {
      lines.push('');
    }
    for (const typeName of [...pkg.types.keys()].sort()) {
      const type = pkg.types.get(typeName);
      const methods = pkg.methodsByType.get(typeName) ?? [];
      if (methods.length === 0 && !type?.show) {
        continue;
      }
      lines.push(`Type namespace \`${typeName}\``);
      for (const method of methods) {
        const tsImports = { shared: false, byModule: new Map() };
        const signature = renderTsSignature(method, pkg.id, tsImports, Boolean(method.unsupportedReason ?? entryUnsupportedReason(method)));
        lines.push(`- \`${typeName}.${entryJsName(method)}${signature}\``);
        lines.push(`  ${describeEntry(method)}`);
      }
      if (type?.show) {
        lines.push(`- \`${typeName}.show(value: ${typeName}): string\``);
        lines.push('  Format the value with its MoonBit `Show` implementation.');
      }
      lines.push('');
    }
  }
  return lines.join('\n').trimEnd();
}

function generateNodePackageFiles(packageMetas, helperNames) {
  const packageMetasById = new Map(packageMetas.map((pkg) => [pkg.id, pkg]));
  for (const pkg of packageMetas) {
    if (HAND_AUTHORED_PACKAGE_OVERRIDES.has(pkg.id)) {
      writeText(
        `node/internal/generated/${pkg.id}.generated.js`,
        generatePackageJs(pkg, helperNames, packageMetas, '../runtime.js'),
      );
      writeText(
        `node/internal/generated/${pkg.id}.generated.d.ts`,
        generatePackageDts(pkg, {
          sharedImport: '../shared.js',
          moduleImportPrefix: '../..',
        }),
      );
      continue;
    }
    writeText(`node/${pkg.id}.js`, generatePackageJs(pkg, helperNames, packageMetas));
    writeText(`node/${pkg.id}.d.ts`, generatePackageDts(pkg));
  }

  writeText('node/passes.js', renderPassesOverlayJs());
  writeText('node/passes.d.ts', renderPassesOverlayDts());

  writeText('node/index.js', TARGET_PACKAGES.map((pkg) => `export * as ${pkg.id} from './${pkg.id}.js';`).join('\n'));

  writeText(
    'node/index.d.ts',
    [
      `export type { OpaqueHandle, StarshineResult } from ${JSON.stringify(JS_SHARED_IMPORT)};`,
      ...TARGET_PACKAGES.map((pkg) => `export * as ${pkg.id} from './${pkg.id}.js';`),
    ].join('\n'),
  );

  const exportsField = Object.fromEntries([
    ['.', { types: './index.d.ts', import: './index.js' }],
    ...TARGET_PACKAGES.map((pkg) => [`./${pkg.id}`, { types: `./${pkg.id}.d.ts`, import: `./${pkg.id}.js` }]),
  ]);

  writeText(
    'node/package.json',
    JSON.stringify(
      {
        name: '@jtenner/starshine',
        version: '0.1.0',
        description: 'Node.js package for the Starshine WebAssembly toolkit',
        type: 'module',
        main: './index.js',
        types: './index.d.ts',
        exports: exportsField,
        bin: {
          starshine: './bin/starshine.js',
        },
        files: [
          '*.js',
          '*.d.ts',
          'bin',
          'examples',
          'internal',
          'README.md',
          'package.json',
        ],
        engines: {
          node: '>=25',
        },
        scripts: {
          generate: 'node ../scripts/generate-node-package.mjs',
          build: 'node ../scripts/build-node-package.mjs',
          test: 'npm run build && node --test test/*.test.mjs',
          clean: 'rm -f internal/starshine.wasm-gc.wasm internal/starshine.wasm-wasi.wasm',
          prepack: 'npm run build',
        },
      },
      null,
      2,
    ),
  );

  writeText('node/README.md', renderReadme(packageMetas));
  writeText('node/.npmignore', '# package contents are controlled by package.json#files\n');
  writeText('node/internal/.npmignore', '# keep wasm artifacts publishable even though they are gitignored locally\n');
  writeText('node/internal/.gitignore', 'starshine.wasm-gc.wasm\nstarshine.wasm-wasi.wasm');
}

function generateMoonPackageFiles(packageMetas, moonInterop) {
  const externalImports = collectExternalImports(packageMetas);
  const usedTargetPackages = TARGET_PACKAGES.filter((pkg) => (
    moonInterop.source.includes(`${pkg.alias}.`) || moonInterop.source.includes(`${pkg.alias}::`)
  ));
  const importLines = [
    ...usedTargetPackages.map((pkg) => `  ${JSON.stringify(pkg.moonPackage)} ${pkg.alias},`),
    ...externalImports.map(([alias, packagePath]) => `  ${JSON.stringify(packagePath)} ${alias},`),
  ];
  writeText(
    'src/node_api/moon.pkg',
    [
      'import {',
      ...importLines,
      '}',
      '',
      'options(',
      '  "is-main": true,',
      '  link: {',
      '    "wasm-gc": {',
      '      "exports": [',
      ...moonInterop.exports.map((name) => `        ${JSON.stringify(name)},`),
      ...CUSTOM_MOON_EXPORTS.map((name) => `        ${JSON.stringify(name)},`),
      '      ],',
      '      "use-js-builtin-string": true,',
      '      "imported-string-constants": "_",',
      '    },',
      '  },',
      ')',
    ].join('\n'),
  );
  writeText('src/node_api/imports.mbt', '///|');
  writeText('src/node_api/generated.mbt', moonInterop.source);
}

function collectExternalImports(packageMetas) {
  const imports = new Map();
  function collectFromDescriptor(descriptor) {
    switch (descriptor.kind) {
      case 'externalNamed': {
        if (descriptor.raw.startsWith('@')) {
          const alias = descriptor.raw.slice(0, descriptor.raw.indexOf('.'));
          if (EXTERNAL_ALIAS_IMPORTS.has(alias)) {
            imports.set(alias, EXTERNAL_ALIAS_IMPORTS.get(alias));
          }
        }
        return;
      }
      case 'genericOpaque':
        if (descriptor.head.startsWith('@')) {
          const alias = descriptor.head.slice(0, descriptor.head.indexOf('.'));
          if (EXTERNAL_ALIAS_IMPORTS.has(alias)) {
            imports.set(alias, EXTERNAL_ALIAS_IMPORTS.get(alias));
          }
        }
        for (const item of descriptor.items) {
          collectFromDescriptor(item);
        }
        return;
      case 'array':
      case 'option':
        collectFromDescriptor(descriptor.item);
        return;
      case 'result':
        collectFromDescriptor(descriptor.ok);
        collectFromDescriptor(descriptor.err);
        return;
      case 'tuple':
        for (const item of descriptor.items) {
          collectFromDescriptor(item);
        }
        return;
      default:
        return;
    }
  }

  for (const pkg of packageMetas) {
    for (const entry of [...pkg.values, ...[...pkg.methodsByType.values()].flat()]) {
      if (entry.unsupportedReason ?? entryUnsupportedReason(entry)) {
        continue;
      }
      for (const param of entry.params) {
        collectFromDescriptor(param.descriptor);
      }
      collectFromDescriptor(entry.returnDescriptor);
    }
  }

  return [...imports.entries()].sort(([left], [right]) => left.localeCompare(right));
}

function main() {
  const packageMetas = TARGET_PACKAGES.map(parsePackageMeta);
  const catalog = buildInteropCatalog(packageMetas);
  const helperNames = createHelperNames(catalog);
  const moonInterop = generateMoonInterop(packageMetas, catalog, helperNames);
  generateMoonPackageFiles(packageMetas, moonInterop);
  generateNodePackageFiles(packageMetas, helperNames);
}

main();

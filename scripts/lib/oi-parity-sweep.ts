import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

export type OiParityStatus =
  | "covered"
  | "mismatch"
  | "intentional-boundary"
  | "blocked-surface"
  | "unsafe-gap"
  | "starshine-win-candidate";

export type OiParitySweepRow = {
  id: string;
  family: string;
  title: string;
  upstreamOwner: string;
  litSources?: string[];
  featureRequirements?: string[];
  binaryenOracleMode: string;
  starshineStatus: OiParityStatus;
  priority: string;
  blockerBoundaryReason: string;
  lastCheckedEvidence: string[];
  genValidProfiles?: string[];
  metamorphicTransforms?: string[];
  sweep?: {
    enabled?: boolean;
    count?: number;
    seed?: string;
    profile?: string;
    normalizers?: string[];
    blockedUntilProfileExists?: boolean;
  };
};

export type OiParityMatrix = {
  schemaVersion: number;
  kind: string;
  pass: string;
  binaryenVersion: string;
  rows: OiParitySweepRow[];
};

export type OiParitySweepOptions = {
  matrixPath: string;
  families: string[];
  ids: string[];
  statuses: string[];
  priorities: string[];
  outDir: string;
  count: number | null;
  seed: string | null;
  starshineBin: string | null;
  jobs: string | null;
  execute: boolean;
  json: boolean;
  list: boolean;
  summarizeExisting: boolean;
  includeDisabled: boolean;
  includeProfileStubs: boolean;
  defaultGenValid: boolean;
  bunBin: string;
  extraCompareArgs: string[];
};

export type OiParityPlannedRow = {
  id: string;
  family: string;
  status: OiParityStatus;
  priority: string;
  title: string;
  skipped: boolean;
  skipReason: string | null;
  command: string[];
  outDir: string;
};

export type OiParityCaseLabelStatusSummary = {
  label: string;
  total: number;
  statuses: Record<string, number>;
};

export type OiParityResultSummary = {
  comparedCount: number | null;
  normalizedMatchCount: number | null;
  cleanupNormalizedMatchCount: number | null;
  mismatchCount: number | null;
  validationFailureCount: number | null;
  generatorFailureCount: number | null;
  propertyFailureCount: number | null;
  commandFailureCount: number | null;
  genValidProfile: string | null;
  genValidSelectedProfileCounts: Record<string, number>;
  genValidProfileCaseCounts: Record<string, number>;
  failureDirCount: number | null;
  caseLabelStatuses: OiParityCaseLabelStatusSummary[];
};

export type OiParityExecutedRow = OiParityPlannedRow & {
  exitCode: number | null;
  signal: NodeJS.Signals | null;
  resultJsonPath: string;
  casesJsonlPath: string;
  result: unknown | null;
  resultSummary: OiParityResultSummary | null;
};

export type OiParitySweepReport = {
  matrixPath: string;
  pass: string;
  binaryenVersion: string;
  execute: boolean;
  selectedRows: number;
  plannedRows: OiParityPlannedRow[];
  executedRows: OiParityExecutedRow[];
  grouped: Record<string, { total: number; skipped: number; statuses: Record<string, number> }>;
};

function fail(message: string): never {
  throw new Error(message);
}

function defaultMatrixPath(): string {
  return path.join("docs", "wiki", "binaryen", "passes", "optimize-instructions", "parity-matrix.json");
}

function splitCsv(value: string): string[] {
  return value.split(",").map((part) => part.trim()).filter(Boolean);
}

export function parseOiParitySweepArgs(argv: string[]): OiParitySweepOptions {
  const options: OiParitySweepOptions = {
    matrixPath: defaultMatrixPath(),
    families: [],
    ids: [],
    statuses: [],
    priorities: [],
    outDir: path.join(".tmp", "oi-parity-sweep"),
    count: null,
    seed: null,
    starshineBin: null,
    jobs: null,
    execute: false,
    json: false,
    list: false,
    summarizeExisting: false,
    includeDisabled: false,
    includeProfileStubs: false,
    defaultGenValid: false,
    bunBin: "bun",
    extraCompareArgs: [],
  };

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    if (token === "--") {
      options.extraCompareArgs.push(...argv.slice(i + 1));
      break;
    }
    if (token.startsWith("--matrix=")) {
      options.matrixPath = token.substring("--matrix=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--family=")) {
      options.families.push(...splitCsv(token.substring("--family=".length)));
      i += 1;
      continue;
    }
    if (token.startsWith("--id=")) {
      options.ids.push(...splitCsv(token.substring("--id=".length)));
      i += 1;
      continue;
    }
    if (token.startsWith("--status=")) {
      options.statuses.push(...splitCsv(token.substring("--status=".length)));
      i += 1;
      continue;
    }
    if (token.startsWith("--priority=")) {
      options.priorities.push(...splitCsv(token.substring("--priority=".length)));
      i += 1;
      continue;
    }
    if (token.startsWith("--out-dir=")) {
      options.outDir = token.substring("--out-dir=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--count=")) {
      options.count = Number.parseInt(token.substring("--count=".length), 10);
      i += 1;
      continue;
    }
    if (token.startsWith("--seed=")) {
      options.seed = token.substring("--seed=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--starshine-bin=")) {
      options.starshineBin = token.substring("--starshine-bin=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--jobs=")) {
      options.jobs = token.substring("--jobs=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--bun=")) {
      options.bunBin = token.substring("--bun=".length);
      i += 1;
      continue;
    }

    switch (token) {
      case "--matrix":
        options.matrixPath = argv[i + 1] ?? fail("missing value for --matrix");
        i += 2;
        break;
      case "--family":
        options.families.push(...splitCsv(argv[i + 1] ?? fail("missing value for --family")));
        i += 2;
        break;
      case "--id":
        options.ids.push(...splitCsv(argv[i + 1] ?? fail("missing value for --id")));
        i += 2;
        break;
      case "--status":
        options.statuses.push(...splitCsv(argv[i + 1] ?? fail("missing value for --status")));
        i += 2;
        break;
      case "--priority":
        options.priorities.push(...splitCsv(argv[i + 1] ?? fail("missing value for --priority")));
        i += 2;
        break;
      case "--out-dir":
        options.outDir = argv[i + 1] ?? fail("missing value for --out-dir");
        i += 2;
        break;
      case "--count":
        options.count = Number.parseInt(argv[i + 1] ?? fail("missing value for --count"), 10);
        i += 2;
        break;
      case "--seed":
        options.seed = argv[i + 1] ?? fail("missing value for --seed");
        i += 2;
        break;
      case "--starshine-bin":
        options.starshineBin = argv[i + 1] ?? fail("missing value for --starshine-bin");
        i += 2;
        break;
      case "--jobs":
        options.jobs = argv[i + 1] ?? fail("missing value for --jobs");
        i += 2;
        break;
      case "--bun":
        options.bunBin = argv[i + 1] ?? fail("missing value for --bun");
        i += 2;
        break;
      case "--execute":
        options.execute = true;
        i += 1;
        break;
      case "--json":
        options.json = true;
        i += 1;
        break;
      case "--list":
        options.list = true;
        i += 1;
        break;
      case "--summarize-existing":
        options.summarizeExisting = true;
        i += 1;
        break;
      case "--include-disabled":
        options.includeDisabled = true;
        i += 1;
        break;
      case "--include-profile-stubs":
        options.includeProfileStubs = true;
        i += 1;
        break;
      case "--default-gen-valid":
        options.defaultGenValid = true;
        i += 1;
        break;
      case "--help":
      case "-h":
        printOiParitySweepHelp();
        process.exit(0);
      default:
        fail(`unknown option: ${token}`);
    }
  }

  if (options.count !== null && (!Number.isFinite(options.count) || options.count < 1)) {
    fail("--count must be a positive integer");
  }
  return options;
}

export function readOiParityMatrix(matrixPath: string): OiParityMatrix {
  const parsed = JSON.parse(fs.readFileSync(matrixPath, "utf8")) as OiParityMatrix;
  if (parsed.kind !== "starshine.optimize-instructions.parity-matrix") {
    fail(`unexpected OI parity matrix kind in ${matrixPath}`);
  }
  if (parsed.pass !== "optimize-instructions") {
    fail(`unexpected pass in ${matrixPath}: ${parsed.pass}`);
  }
  if (!Array.isArray(parsed.rows)) {
    fail(`missing rows array in ${matrixPath}`);
  }
  return parsed;
}

function selected(value: string, filters: string[]): boolean {
  return filters.length === 0 || filters.includes(value);
}

export function selectOiParityRows(matrix: OiParityMatrix, options: OiParitySweepOptions): OiParitySweepRow[] {
  return matrix.rows.filter((row) => {
    return selected(row.family, options.families) &&
      selected(row.id, options.ids) &&
      selected(row.starshineStatus, options.statuses) &&
      selected(row.priority, options.priorities);
  });
}

function rowOutDir(rootOutDir: string, row: OiParitySweepRow): string {
  return path.join(rootOutDir, row.family.toLowerCase(), row.id);
}

const implementedOiMetamorphicTransforms = new Set<string>([
  "oi-local-carried",
  "oi-local-tee-wrapped",
  "oi-commuted-operands",
  "oi-if-select-shell",
  "oi-effectful-sibling",
  "oi-trapping-sibling",
  "oi-call-ref-target-wrapper",
  "oi-tuple-selected-lane",
  "oi-memory-size-boundary",
  "oi-live-zero-memory-boundary",
  "oi-live-nonzero-memory-copy-boundary",
  "oi-live-nonzero-memory-mid-copy-boundary",
  "oi-live-nonzero-memory-end-copy-boundary",
  "oi-live-nonzero-memory-dynamic-copy-boundary",
  "oi-live-nonzero-memory-varied-copy-boundary",
  "oi-live-nonzero-memory-second-copy-boundary",
  "oi-live-nonzero-memory-cross-copy-boundary",
  "oi-live-nonzero-memory-atomic-boundary",
  "oi-live-nonzero-memory-atomic-rmw-boundary",
  "oi-live-nonzero-memory-fill-restore-boundary",
  "oi-live-nonzero-memory-mid-fill-restore-boundary",
  "oi-live-nonzero-memory-end-fill-restore-boundary",
]);

function isForwardableMetamorphicTransform(transform: string): boolean {
  return !transform.startsWith("oi-") || implementedOiMetamorphicTransforms.has(transform);
}

export function planOiParitySweep(matrix: OiParityMatrix, options: OiParitySweepOptions): OiParityPlannedRow[] {
  return selectOiParityRows(matrix, options).map((row) => {
    const sweep = row.sweep ?? {};
    const outDir = rowOutDir(options.outDir, row);
    const profile = options.defaultGenValid ? null : sweep.profile ?? row.genValidProfiles?.[0] ?? null;
    const count = options.count ?? sweep.count ?? 100;
    const seed = options.seed ?? sweep.seed ?? "0x5eed";
    const skipped = (!options.includeDisabled && sweep.enabled === false) ||
      (!options.defaultGenValid && !options.includeProfileStubs && sweep.blockedUntilProfileExists === true);
    const skipReason = !options.includeDisabled && sweep.enabled === false
      ? "matrix row sweep.enabled is false"
      : !options.defaultGenValid && !options.includeProfileStubs && sweep.blockedUntilProfileExists === true
        ? "matrix row references a GenValid profile stub; pass --include-profile-stubs after implementing or intentionally smoke-testing the stub"
        : null;

    const command = [
      options.bunBin,
      "scripts/pass-fuzz-compare.ts",
      "--count",
      count.toString(),
      "--seed",
      seed,
      "--pass",
      "optimize-instructions",
      "--out-dir",
      outDir,
    ];
    if (profile !== null) {
      command.push("--gen-valid-profile", profile);
    }
    for (const transform of row.metamorphicTransforms ?? []) {
      if (!isForwardableMetamorphicTransform(transform)) {
        continue;
      }
      command.push("--gen-valid-metamorphic-transform", transform);
    }
    for (const normalizer of sweep.normalizers ?? []) {
      command.push("--normalize", normalizer);
    }
    if (options.starshineBin !== null) {
      command.push("--starshine-bin", options.starshineBin);
      command.push("--jobs", options.jobs ?? "auto");
    } else if (options.jobs !== null) {
      command.push("--jobs", options.jobs);
    }
    command.push(...options.extraCompareArgs);

    return {
      id: row.id,
      family: row.family,
      status: row.starshineStatus,
      priority: row.priority,
      title: row.title,
      skipped,
      skipReason,
      command,
      outDir,
    };
  });
}

function groupPlans(plans: OiParityPlannedRow[]): OiParitySweepReport["grouped"] {
  const grouped: OiParitySweepReport["grouped"] = {};
  for (const plan of plans) {
    const group = grouped[plan.family] ?? { total: 0, skipped: 0, statuses: {} };
    group.total += 1;
    if (plan.skipped) {
      group.skipped += 1;
    }
    group.statuses[plan.status] = (group.statuses[plan.status] ?? 0) + 1;
    grouped[plan.family] = group;
  }
  return grouped;
}

function readResultJson(resultJsonPath: string): unknown | null {
  if (!fs.existsSync(resultJsonPath)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(resultJsonPath, "utf8"));
}

function asRecord(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

function numberField(record: Record<string, unknown>, key: string): number | null {
  const value = record[key];
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function stringField(record: Record<string, unknown>, key: string): string | null {
  const value = record[key];
  return typeof value === "string" ? value : null;
}

function numberMapField(record: Record<string, unknown>, key: string): Record<string, number> {
  const value = asRecord(record[key]);
  const result: Record<string, number> = {};
  for (const [entryKey, entryValue] of Object.entries(value)) {
    if (typeof entryValue === "number" && Number.isFinite(entryValue)) {
      result[entryKey] = entryValue;
    }
  }
  return result;
}

function countArrayField(record: Record<string, unknown>, key: string): number | null {
  const value = record[key];
  return Array.isArray(value) ? value.length : null;
}

function readCaseLabelStatuses(casesJsonlPath: string): OiParityCaseLabelStatusSummary[] {
  if (!fs.existsSync(casesJsonlPath)) {
    return [];
  }
  const grouped = new Map<string, OiParityCaseLabelStatusSummary>();
  const text = fs.readFileSync(casesJsonlPath, "utf8");
  for (const line of text.split(/\r?\n/)) {
    if (line.trim() === "") {
      continue;
    }
    const parsed = asRecord(JSON.parse(line));
    const profileCaseLabel = stringField(parsed, "genValidProfileCaseLabel");
    const transformId = stringField(parsed, "transformId");
    const label = profileCaseLabel ?? (transformId === null ? "<unlabeled>" : `transform:${transformId}`);
    const status = stringField(parsed, "status") ?? "<unknown>";
    const summary = grouped.get(label) ?? { label, total: 0, statuses: {} };
    summary.total += 1;
    summary.statuses[status] = (summary.statuses[status] ?? 0) + 1;
    grouped.set(label, summary);
  }
  return Array.from(grouped.values());
}

function summarizeOiParityResult(result: unknown | null, casesJsonlPath: string): OiParityResultSummary | null {
  if (result === null) {
    return null;
  }
  const record = asRecord(result);
  return {
    comparedCount: numberField(record, "comparedCount"),
    normalizedMatchCount: numberField(record, "normalizedMatchCount"),
    cleanupNormalizedMatchCount: numberField(record, "cleanupNormalizedMatchCount"),
    mismatchCount: numberField(record, "mismatchCount"),
    validationFailureCount: numberField(record, "validationFailureCount"),
    generatorFailureCount: numberField(record, "generatorFailureCount"),
    propertyFailureCount: numberField(record, "propertyFailureCount"),
    commandFailureCount: numberField(record, "commandFailureCount"),
    genValidProfile: stringField(record, "genValidProfile"),
    genValidSelectedProfileCounts: numberMapField(record, "genValidSelectedProfileCounts"),
    genValidProfileCaseCounts: numberMapField(record, "genValidProfileCaseCounts"),
    failureDirCount: countArrayField(record, "failureDirs"),
    caseLabelStatuses: readCaseLabelStatuses(casesJsonlPath),
  };
}

export function runOiParitySweep(options: OiParitySweepOptions): OiParitySweepReport {
  const matrix = readOiParityMatrix(options.matrixPath);
  const plannedRows = planOiParitySweep(matrix, options);
  const executedRows: OiParityExecutedRow[] = [];

  if (options.execute) {
    for (const plan of plannedRows) {
      if (plan.skipped) {
        continue;
      }
      fs.mkdirSync(plan.outDir, { recursive: true });
      const [bin, ...args] = plan.command;
      const result = spawnSync(bin, args, { stdio: "inherit" });
      const resultJsonPath = path.join(plan.outDir, "result.json");
      const casesJsonlPath = path.join(plan.outDir, "cases.jsonl");
      const resultJson = readResultJson(resultJsonPath);
      executedRows.push({
        ...plan,
        exitCode: result.status,
        signal: result.signal,
        resultJsonPath,
        casesJsonlPath,
        result: resultJson,
        resultSummary: summarizeOiParityResult(resultJson, casesJsonlPath),
      });
      if (result.status !== 0) {
        break;
      }
    }
  } else if (options.summarizeExisting) {
    for (const plan of plannedRows) {
      if (plan.skipped) {
        continue;
      }
      const resultJsonPath = path.join(plan.outDir, "result.json");
      const casesJsonlPath = path.join(plan.outDir, "cases.jsonl");
      const resultJson = readResultJson(resultJsonPath);
      executedRows.push({
        ...plan,
        exitCode: null,
        signal: null,
        resultJsonPath,
        casesJsonlPath,
        result: resultJson,
        resultSummary: summarizeOiParityResult(resultJson, casesJsonlPath),
      });
    }
  }

  return {
    matrixPath: options.matrixPath,
    pass: matrix.pass,
    binaryenVersion: matrix.binaryenVersion,
    execute: options.execute,
    selectedRows: plannedRows.length,
    plannedRows,
    executedRows,
    grouped: groupPlans(plannedRows),
  };
}

function formatCommand(command: string[]): string {
  return command.map((part) => part.includes(" ") ? JSON.stringify(part) : part).join(" ");
}

function formatNumberMap(map: Record<string, number>): string {
  const entries = Object.entries(map);
  if (entries.length === 0) {
    return "<none>";
  }
  return entries.map(([key, value]) => `${key}=${value}`).join(", ");
}

function formatResultSummary(summary: OiParityResultSummary): string[] {
  const lines = [
    `  compared=${summary.comparedCount ?? "?"} normalized=${summary.normalizedMatchCount ?? "?"} cleanup=${summary.cleanupNormalizedMatchCount ?? "?"} mismatches=${summary.mismatchCount ?? "?"} validation=${summary.validationFailureCount ?? "?"} generator=${summary.generatorFailureCount ?? "?"} property=${summary.propertyFailureCount ?? "?"} command=${summary.commandFailureCount ?? "?"} profile=${summary.genValidProfile ?? "<none>"}`,
    `  selected profiles: ${formatNumberMap(summary.genValidSelectedProfileCounts)}`,
    `  profile cases: ${formatNumberMap(summary.genValidProfileCaseCounts)}`,
  ];
  if (summary.caseLabelStatuses.length > 0) {
    lines.push(`  case labels: ${summary.caseLabelStatuses.map((entry) => `${entry.label} total=${entry.total} statuses=${JSON.stringify(entry.statuses)}`).join("; ")}`);
  }
  if (summary.failureDirCount !== null) {
    lines.push(`  failure dirs: ${summary.failureDirCount}`);
  }
  return lines;
}

export function formatOiParitySweepReport(report: OiParitySweepReport): string {
  const lines = [
    `OI parity sweep (${report.pass}, ${report.binaryenVersion})`,
    `matrix: ${report.matrixPath}`,
    `selected rows: ${report.selectedRows}`,
    "",
    "Grouped rows:",
  ];
  for (const [family, group] of Object.entries(report.grouped).sort()) {
    lines.push(`- ${family}: ${group.total} row(s), ${group.skipped} skipped, statuses=${JSON.stringify(group.statuses)}`);
  }
  lines.push("", "Commands:");
  for (const plan of report.plannedRows) {
    lines.push(`- ${plan.id} [${plan.family}/${plan.status}/${plan.priority}]${plan.skipped ? ` SKIP: ${plan.skipReason}` : ""}`);
    lines.push(`  ${formatCommand(plan.command)}`);
  }
  if (report.executedRows.length > 0) {
    lines.push("", "Executed:");
    for (const row of report.executedRows) {
      lines.push(`- ${row.id}: exit=${row.exitCode}${row.signal === null ? "" : ` signal=${row.signal}`} result=${row.resultJsonPath}`);
    }
    lines.push("", "Result summaries:");
    for (const row of report.executedRows) {
      lines.push(`- ${row.id} [${row.family}]`);
      if (row.resultSummary === null) {
        lines.push(`  missing result.json at ${row.resultJsonPath}`);
      } else {
        lines.push(...formatResultSummary(row.resultSummary));
      }
    }
  }
  return `${lines.join("\n")}\n`;
}

export function printOiParitySweepHelp(): void {
  process.stdout.write([
    "usage: bun scripts/oi-parity-sweep.ts [options] [-- extra compare-pass args]",
    "",
    "Plans or executes grouped optimize-instructions compare-pass sweeps from the parity matrix.",
    "Default mode is dry-run. Use --execute to invoke bun scripts/pass-fuzz-compare.ts.",
    "Rows that reference profile stubs are skipped unless --include-profile-stubs or --default-gen-valid is passed.",
    "Implemented oi-* metamorphic transforms are forwarded; design-only oi-* ids stay filtered.",
    "",
    "options:",
    "  --matrix <path>              Matrix JSON path",
    "  --family <OI-D[,OI-G]>       Filter families; may repeat",
    "  --id <row-id[,row-id]>       Filter matrix row ids; may repeat",
    "  --status <status>            Filter Starshine status; may repeat",
    "  --priority <P0[,P1]>         Filter priorities; may repeat",
    "  --out-dir <dir>              Root output dir (default .tmp/oi-parity-sweep)",
    "  --count <n>                  Override per-row count",
    "  --seed <seed>                Override per-row seed",
    "  --starshine-bin <path>       Forward prebuilt CLI and default --jobs auto",
    "  --jobs <n|auto>              Forward compare-pass jobs",
    "  --include-disabled           Include rows with sweep.enabled=false",
    "  --include-profile-stubs      Include rows whose profile is still documented as a stub",
    "  --default-gen-valid          Omit row profiles and run the default GenValid generator instead",
    "  --execute                    Run compare-pass commands instead of only printing",
    "  --summarize-existing         Read result.json/cases.jsonl under planned out dirs without running compare-pass",
    "  --json                       Print JSON report",
    "  --bun <path>                 Bun executable to use in planned commands",
  ].join("\n") + "\n");
}

export function mainOiParitySweep(argv: string[]): void {
  const options = parseOiParitySweepArgs(argv);
  const report = runOiParitySweep(options);
  if (options.json) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } else {
    process.stdout.write(formatOiParitySweepReport(report));
  }
}

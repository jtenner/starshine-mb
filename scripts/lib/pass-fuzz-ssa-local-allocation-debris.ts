function parenDelta(line: string): number {
  let delta = 0;
  for (const char of line) {
    if (char === "(") delta += 1;
    if (char === ")") delta -= 1;
  }
  return delta;
}

function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function rewriteLocalInExpr(expr: string, from: string, to: string): string {
  const fromRe = escapeRegExp(from);
  return expr
    .replace(new RegExp(`\\(local\\s+${fromRe}\\b`, "g"), `(local ${to}`)
    .replace(new RegExp(`\\(param\\s+${fromRe}\\b`, "g"), `(param ${to}`)
    .replace(new RegExp(`\\blocal\\.(get|set|tee)\\s+${fromRe}\\b`, "g"), `local.$1 ${to}`);
}

function extractTopLevelExpressions(funcText: string): { header: string; localDecls: string[]; bodyExprs: string[]; footer: string } {
  const lines = funcText.split("\n");
  const headerLines: string[] = [];
  const localDecls: string[] = [];
  const bodyLines: string[] = [];
  let index = 0;
  while (index < lines.length && !lines[index].trimStart().startsWith("(func")) {
    index += 1;
  }
  if (index >= lines.length) {
    return { header: funcText, localDecls: [], bodyExprs: [], footer: "" };
  }
  headerLines.push(lines[index]);
  index += 1;
  let funcBodyBalance = parenDelta(headerLines[0]);
  while (index < lines.length && funcBodyBalance > 0) {
    const line = lines[index];
    if (/^\s*\(local\s+(\$[A-Za-z0-9_.$-]+)\s+[A-Za-z0-9_.]+\)\s*$/.test(line)) {
      localDecls.push(line);
      index += 1;
      continue;
    }
    bodyLines.push(line);
    funcBodyBalance += parenDelta(line);
    index += 1;
  }
  const footer = index < lines.length ? lines.slice(index).join("\n") : "";
  const bodyExprs: string[] = [];
  let bodyIndex = 0;
  while (bodyIndex < bodyLines.length) {
    const line = bodyLines[bodyIndex];
    if (line.trim() === "") {
      bodyIndex += 1;
      continue;
    }
    const exprLines = [line];
    let balance = parenDelta(line);
    while (balance > 0 && bodyIndex + 1 < bodyLines.length) {
      bodyIndex += 1;
      exprLines.push(bodyLines[bodyIndex]);
      balance += parenDelta(bodyLines[bodyIndex]);
    }
    bodyExprs.push(exprLines.join("\n"));
    bodyIndex += 1;
  }
  return {
    header: headerLines.join("\n"),
    localDecls,
    bodyExprs,
    footer,
  };
}

function parseParamNames(funcText: string): Set<string> {
  const names = new Set<string>();
  for (const match of funcText.matchAll(/\(param\s+(\$[A-Za-z0-9_.$-]+)\s+[A-Za-z0-9_.]+/g)) {
    names.add(match[1]);
  }
  return names;
}

function matchLocalSetTarget(expr: string): string | null {
  const match = expr.match(/^\s*\(local\.set\s+(\$[A-Za-z0-9_.$-]+)\b/);
  return match ? match[1] : null;
}

function matchDropLocalTeeTarget(expr: string): string | null {
  const match = expr.match(/^\s*\(drop\s*\n\s*\(local\.tee\s+(\$[A-Za-z0-9_.$-]+)\b/s);
  return match ? match[1] : null;
}

function isDropLocalGet(expr: string, localName: string): boolean {
  const pattern = new RegExp(
    `^\\s*\\(drop\\s*\\n\\s*\\(local\\.get\\s+${escapeRegExp(localName)}\\)\\s*\\n\\s*\\)\\s*$`,
  );
  return pattern.test(expr);
}

function isControlFlowExpr(expr: string): boolean {
  return /^\s*\((?:if|block|loop|try|try_table|br|br_if|br_table|return|unreachable)\b/.test(expr);
}

function extractIfConditionLocal(expr: string): string | null {
  const match = expr.match(/^\s*\(if\s*\n\s*\(local\.get\s+(\$[A-Za-z0-9_.$-]+)\)\s*\n/s);
  return match ? match[1] : null;
}

function rewriteIfConditionLocal(expr: string, from: string, to: string): string {
  const fromRe = escapeRegExp(from);
  return expr.replace(
    new RegExp(`^(\\s*\\(if\\s*\\n\\s*\\(local\\.get\\s+)${fromRe}(\\)\\s*\\n)`, "s"),
    `$1${to}$2`,
  );
}

type IslandCounter = { next: number };

function nextIslandName(counter: IslandCounter): string {
  const name = `$ssaisland${counter.next}`;
  counter.next += 1;
  return name;
}

function tryParseStraightLineIsland(exprs: string[], start: number, paramNames: Set<string>): { local: string; length: number } | null {
  const setLocal = matchLocalSetTarget(exprs[start] ?? "");
  if (setLocal !== null && !paramNames.has(setLocal)) {
    let length = 1;
    while (start + length < exprs.length && isDropLocalGet(exprs[start + length], setLocal)) {
      length += 1;
    }
    if (length >= 2) {
      return { local: setLocal, length };
    }
    return null;
  }
  const teeLocal = matchDropLocalTeeTarget(exprs[start] ?? "");
  if (teeLocal !== null && !paramNames.has(teeLocal)) {
    let length = 1;
    while (start + length < exprs.length && isDropLocalGet(exprs[start + length], teeLocal)) {
      length += 1;
    }
    return { local: teeLocal, length };
  }
  return null;
}

function normalizeStraightLineChunk(exprs: string[], paramNames: Set<string>, counter: IslandCounter): string[] {
  const output: string[] = [];
  let index = 0;
  while (index < exprs.length) {
    const island = tryParseStraightLineIsland(exprs, index, paramNames);
    if (island) {
      const canonical = nextIslandName(counter);
      for (let offset = 0; offset < island.length; offset += 1) {
        output.push(rewriteLocalInExpr(exprs[index + offset], island.local, canonical));
      }
      index += island.length;
      continue;
    }
    output.push(exprs[index]);
    index += 1;
  }
  return output;
}

function tryPreIfConditionCarrier(
  setExpr: string,
  ifExpr: string,
  paramNames: Set<string>,
): string | null {
  const carrier = matchLocalSetTarget(setExpr);
  if (carrier === null || paramNames.has(carrier)) return null;
  if (!ifExpr.trimStart().startsWith("(if")) return null;
  const conditionLocal = extractIfConditionLocal(ifExpr);
  if (conditionLocal !== carrier) return null;
  return carrier;
}

function normalizeTopLevelBody(exprs: string[], paramNames: Set<string>, counter: IslandCounter): string[] {
  const output: string[] = [];
  let index = 0;
  while (index < exprs.length) {
    if (isControlFlowExpr(exprs[index])) {
      const ifExpr = exprs[index];
      if (output.length > 0) {
        const carrier = tryPreIfConditionCarrier(output[output.length - 1], ifExpr, paramNames);
        if (carrier !== null) {
          const canonical = nextIslandName(counter);
          output[output.length - 1] = rewriteLocalInExpr(output[output.length - 1], carrier, canonical);
          output.push(rewriteIfConditionLocal(ifExpr, carrier, canonical));
          index += 1;
          continue;
        }
      }
      output.push(ifExpr);
      index += 1;
      continue;
    }
    const chunk: string[] = [];
    while (index < exprs.length && !isControlFlowExpr(exprs[index])) {
      chunk.push(exprs[index]);
      index += 1;
    }
    output.push(...normalizeStraightLineChunk(chunk, paramNames, counter));
  }
  return output;
}

function normalizeSsaLocalAllocationInFunction(funcText: string): string {
  if (/\blocal\.(?:get|set|tee)\s+\d+\b/.test(funcText)) return funcText;
  const paramNames = parseParamNames(funcText);
  const { header, localDecls, bodyExprs, footer } = extractTopLevelExpressions(funcText);
  const counter: IslandCounter = { next: 0 };
  const normalizedBody = normalizeTopLevelBody(bodyExprs, paramNames, counter);
  const parts = [header, ...localDecls, ...normalizedBody];
  if (footer) parts.push(footer);
  return parts.join("\n");
}

export function normalizeSsaLocalAllocationDebris(wat: string): string {
  const lines = wat.split("\n");
  const output: string[] = [];
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (!line.trimStart().startsWith("(func")) {
      output.push(line);
      continue;
    }
    const funcLines = [line];
    let balance = parenDelta(line);
    while (balance > 0 && index + 1 < lines.length) {
      index += 1;
      funcLines.push(lines[index]);
      balance += parenDelta(lines[index]);
    }
    output.push(...normalizeSsaLocalAllocationInFunction(funcLines.join("\n")).split("\n"));
  }
  return output.join("\n");
}

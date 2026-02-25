const fs = require('node:fs');
const path = require('node:path');

const distDir = path.join(__dirname, 'dist');

const debugWasmPath = path.join(distDir, 'starshine.debug.wasm');
const releaseWasmPath = path.join(distDir, 'starshine.release.wasm');
const selfOptimizedWasmPath = path.join(distDir, 'starshine.self-optimized.wasm');
const compareReportPath = path.join(distDir, 'compare.report.json');

function readCompareReport() {
  return JSON.parse(fs.readFileSync(compareReportPath, 'utf8'));
}

module.exports = {
  distDir,
  debugWasmPath,
  releaseWasmPath,
  selfOptimizedWasmPath,
  compareReportPath,
  readCompareReport,
};

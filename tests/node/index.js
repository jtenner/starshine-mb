const fs = require('node:fs');
const path = require('node:path');

const distDir = path.join(__dirname, 'dist');

const debugWasmPath = path.join(distDir, 'starshine-debug-wasi.wasm');
const optimizedWasmPath = path.join(distDir, 'starshine-optimized-wasi.wasm');
const selfOptimizedWasmPath = path.join(distDir, 'starshine-self-optimized-wasi.wasm');
const compareReportPath = path.join(distDir, 'compare.report.json');

function readCompareReport() {
  return JSON.parse(fs.readFileSync(compareReportPath, 'utf8'));
}

module.exports = {
  distDir,
  debugWasmPath,
  optimizedWasmPath,
  selfOptimizedWasmPath,
  compareReportPath,
  readCompareReport,
};

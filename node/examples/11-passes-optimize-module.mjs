import * as binary from '../binary.js';
import * as passes from '../passes.js';
import * as wast from '../wast.js';
import { SAMPLE_OPTIMIZE_MODULE_TEXT, expectOk } from './_shared.mjs';

const mod = expectOk(
  wast.wastToBinaryModule(SAMPLE_OPTIMIZE_MODULE_TEXT),
  'wast.wastToBinaryModule',
);
const options = passes.OptimizeOptions.new();
const pipeline = passes.defaultFunctionOptimizationPasses(mod, options);
pipeline.push(passes.deadArgumentElimination());
pipeline.push(passes.vacuum());
const optimized = expectOk(
  passes.optimizeModuleWithOptions(mod, pipeline, options),
  'passes.optimizeModuleWithOptions',
);
const bytes = expectOk(binary.encodeModule(optimized), 'binary.encodeModule');

console.log(
  `passes example ok: ordered pipeline length ${pipeline.length}, tail passes deadArgumentElimination -> vacuum, encoded size ${bytes.length} bytes`,
);

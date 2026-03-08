import * as wast from '../wast.js';

const summary = wast.runWastSpecSuite([
  ['inline-spec.wast', '(module (func (export "run")))'],
]);

console.log(wast.WastSpecRunSummary.show(summary));

import { expect, test } from 'bun:test';

test('npm self-optimization requires the declared six-pass O4s queue', async () => {
  const { assertNpmSelfOptimizationQueue } = await import('./npm-preset.mjs');
  const report = { optimizeLevel: 4, shrinkLevel: 1, expandedPasses: [
    'duplicate-function-elimination', 'constraint-analysis', 'vacuum',
    'reorder-locals', 'merge-similar-functions', 'strip-debug',
  ] };
  expect(() => assertNpmSelfOptimizationQueue(report)).not.toThrow();
  expect(() => assertNpmSelfOptimizationQueue({ ...report, optimizeLevel: 1 })).toThrow();
  expect(() => assertNpmSelfOptimizationQueue({ ...report, shrinkLevel: 4 })).toThrow();
  expect(() => assertNpmSelfOptimizationQueue({ ...report, expandedPasses: report.expandedPasses.filter(name => name !== 'merge-similar-functions') })).toThrow();
  expect(() => assertNpmSelfOptimizationQueue({ ...report, expandedPasses: [...report.expandedPasses].reverse() })).toThrow();
  expect(() => assertNpmSelfOptimizationQueue({ ...report, expandedPasses: [...report.expandedPasses, 'vacuum'] })).toThrow();
});

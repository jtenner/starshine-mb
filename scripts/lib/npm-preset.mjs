import assert from 'node:assert/strict';

// Changing the build scheduler requires fresh artifact and consumer qualification.
export function assertNpmSelfOptimizationQueue(report) {
  assert.equal(report.optimizeLevel, 4);
  assert.equal(report.shrinkLevel, 1);
  assert.deepEqual(report.expandedPasses, [
    'duplicate-function-elimination', 'constraint-analysis', 'vacuum',
    'reorder-locals', 'merge-similar-functions', 'strip-debug',
  ], 'O4s pass selection changed; qualify the new scheduler explicitly');
}

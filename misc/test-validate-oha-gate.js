'use strict';

const assert = require('assert');

const {validateComparison} = require('./validate-oha-gate');

function samples(overrides = {}) {
  return ['/empty.gif', '/64k.bin', '/churn'].map(workload => ({
    workload, rawPairs: 6, retainedPairs: 5, errors: 0,
    requestsPerSecondDeltaPercent: workload === '/churn' ? 3 : 0,
    ...overrides
  }));
}

validateComparison(samples());
for (const overrides of [
  {rawPairs: 5}, {retainedPairs: 2}, {errors: 1},
  {requestsPerSecondDeltaPercent: 1.9},
  {requestsPerSecondDeltaPercent: NaN},
  {requestsPerSecondDeltaPercent: undefined}
]) {
  assert.throws(() => validateComparison(samples(overrides)));
}
const regressed = samples();
regressed[0].requestsPerSecondDeltaPercent = -2.1;
assert.throws(() => validateComparison(regressed));
assert.throws(() => validateComparison(samples().slice(1)));
assert.throws(() => validateComparison([]));

process.stdout.write('oha performance gate tests passed\n');

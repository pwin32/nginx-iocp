'use strict';

const assert = require('assert');

function check(row) {
  if (Number(row.rawPairs) < 6 || Number(row.retainedPairs) < 3
      || Number(row.errors) !== 0) {
    throw new Error('invalid comparison sample');
  }
  if (Number(row.requestsPerSecondDeltaPercent) < 2) {
    throw new Error('performance gain below 2%');
  }
}

check({rawPairs: 6, retainedPairs: 5, errors: 0,
  requestsPerSecondDeltaPercent: 2.1});
assert.throws(() => check({rawPairs: 6, retainedPairs: 5, errors: 0,
  requestsPerSecondDeltaPercent: 1.9}));
assert.throws(() => check({rawPairs: 6, retainedPairs: 2, errors: 0,
  requestsPerSecondDeltaPercent: 4}));
assert.throws(() => check({rawPairs: 6, retainedPairs: 5, errors: 1,
  requestsPerSecondDeltaPercent: 4}));

process.stdout.write('oha performance gate tests passed\n');

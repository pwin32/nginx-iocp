'use strict';

const fs = require('fs');

function validateComparison(rows) {
  const expected = new Set(['/empty.gif', '/64k.bin', '/churn']);
  for (const row of rows) {
    if (!expected.delete(row.workload)
        || !Number.isInteger(row.rawPairs) || row.rawPairs < 6
        || !Number.isInteger(row.retainedPairs) || row.retainedPairs < 3
        || row.retainedPairs > row.rawPairs || row.errors !== 0
        || !Number.isFinite(row.requestsPerSecondDeltaPercent)) {
      throw new Error(`invalid comparison sample: ${JSON.stringify(row)}`);
    }
    const threshold = row.workload === '/churn' ? 2 : -2;
    if (row.requestsPerSecondDeltaPercent < threshold) {
      throw new Error(
        `${row.workload}: ${row.requestsPerSecondDeltaPercent}% `
        + `is below the ${threshold}% gate`
      );
    }
  }
  if (expected.size) { throw new Error('comparison is missing workloads'); }
}

if (require.main === module) {
  const files = process.argv.slice(2);
  if (files.length !== 2) {
    throw new Error('usage: validate-oha-gate.js forward.jsonl reverse.jsonl');
  }
  for (const file of files) {
    validateComparison(fs.readFileSync(file, 'utf8').trim().split(/\r?\n/)
      .filter(Boolean).map(line => JSON.parse(line)));
  }
  process.stdout.write('performance gate passed in both run orders\n');
}

module.exports = {validateComparison};

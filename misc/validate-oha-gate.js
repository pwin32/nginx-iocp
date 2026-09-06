'use strict';

const fs = require('fs');

const file = process.argv[2];
if (!file) {
  throw new Error('usage: validate-oha-gate.js comparison.jsonl');
}

const rows = fs.readFileSync(file, 'utf8').trim().split(/\r?\n/)
  .filter(Boolean).map(line => JSON.parse(line));

if (!rows.length) {
  throw new Error('comparison output is empty');
}

for (const row of rows) {
  if (Number(row.rawPairs) < 6 || Number(row.retainedPairs) < 3
      || Number(row.errors) !== 0) {
    throw new Error(`invalid comparison sample: ${JSON.stringify(row)}`);
  }

  if (Number(row.requestsPerSecondDeltaPercent) < 2) {
    throw new Error(
      `performance gain below 2% for ${row.workload}: `
      + `${row.requestsPerSecondDeltaPercent}%`
    );
  }
}

process.stdout.write(`performance gate passed for ${rows.length} workloads\n`);

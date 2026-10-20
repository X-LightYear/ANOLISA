/**
 * @license
 * Copyright 2026 Alibaba Cloud
 * SPDX-License-Identifier: Apache-2.0
 */

import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(
  new URL('../scripts/package-npm.js', import.meta.url),
);
const result = spawnSync(process.execPath, [script, '--target'], {
  encoding: 'utf8',
});

assert.equal(result.status, 1, result.stdout);
assert.match(
  result.stderr,
  /Error: --target requires a target selector/,
);
console.log('ok - missing package targets are rejected before building');

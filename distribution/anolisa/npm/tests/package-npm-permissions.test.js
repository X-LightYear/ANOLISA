/**
 * @license
 * Copyright 2026 Alibaba Cloud
 * SPDX-License-Identifier: Apache-2.0
 */

import assert from 'node:assert/strict';
import {
  mkdtempSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ensureExecutable } from '../scripts/package-npm.js';

if (process.platform === 'win32') {
  console.log('ok - executable mode test skipped on Windows');
} else {
  const root = mkdtempSync(join(tmpdir(), 'anolisa-npm-permissions-'));
  try {
    const binary = join(root, 'anolisa');
    writeFileSync(binary, '#!/bin/sh\nexit 0\n');
    ensureExecutable(binary);

    assert.equal(readFileSync(binary, 'utf8'), '#!/bin/sh\nexit 0\n');
    assert.equal(statSync(binary).mode & 0o111, 0o111);
    console.log('ok - packaged binaries receive executable permissions');
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

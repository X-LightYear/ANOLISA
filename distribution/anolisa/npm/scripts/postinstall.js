#!/usr/bin/env node

/**
 * @license
 * Copyright 2026 Alibaba Cloud
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * postinstall script for @anolisa/cli
 *
 * Resolves the platform-specific binary package and creates a launcher
 * script at bin/anolisa that delegates to the native binary.
 *
 * Platform packages follow the naming convention:
 *   @anolisa/cli-{os}-{arch}
 *
 * Each platform package ships a single native binary at:
 *   bin/anolisa
 */

import {
  existsSync,
  mkdirSync,
  statSync,
  symlinkSync,
  unlinkSync,
  chmodSync,
} from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { platform, arch } from 'node:os';
import { platformPackageName } from './platforms.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const require = createRequire(import.meta.url);
const packageRoot = join(__dirname, '..');
const binDir = join(packageRoot, 'bin');
const linkPath = join(binDir, 'anolisa');

function removeLauncher() {
  // Unlink the entry itself: existsSync follows dangling symlinks.
  try {
    unlinkSync(linkPath);
  } catch (error) {
    if (error.code !== 'ENOENT') {
      throw error;
    }
  }
}

function resolvePackageBinary() {
  const pkgName = platformPackageName(platform(), arch());

  // Resolve platform package using createRequire (compatible with Node 16+)
  let pkgDir;
  try {
    const resolved = require.resolve(`${pkgName}/package.json`);
    pkgDir = dirname(resolved);
  } catch {
    // Fallback: walk up to find node_modules
    let current = packageRoot;
    while (current !== dirname(current)) {
      const candidate = join(current, 'node_modules', ...pkgName.split('/'));
      if (existsSync(candidate)) {
        pkgDir = candidate;
        break;
      }
      current = dirname(current);
    }
  }

  if (!pkgDir || !existsSync(pkgDir)) {
    throw new Error(
      `Platform package ${pkgName} not found; optional dependencies may have been skipped`,
    );
  }

  const nativeBinary = join(pkgDir, 'bin', 'anolisa');
  let nativeBinaryStat;
  try {
    nativeBinaryStat = statSync(nativeBinary);
  } catch {
    // Missing paths, unreadable parent directories and symlink loops land here.
  }
  if (!nativeBinaryStat) {
    throw new Error(`Binary not found in ${pkgName} at ${nativeBinary}`);
  }
  if (!nativeBinaryStat.isFile()) {
    throw new Error(
      `Binary is not a regular file in ${pkgName} at ${nativeBinary}`,
    );
  }

  return nativeBinary;
}

function main() {
  let nativeBinary;
  try {
    nativeBinary = resolvePackageBinary();
  } catch (error) {
    removeLauncher();
    throw error;
  }

  // Ensure bin/ directory exists
  if (!existsSync(binDir)) {
    mkdirSync(binDir, { recursive: true });
  }

  removeLauncher();

  // Keep the launcher valid when the complete installation tree is relocated.
  symlinkSync(relative(binDir, nativeBinary), linkPath);
  chmodSync(linkPath, 0o755);

  console.log(`@anolisa/cli: Linked native binary for ${platform()}-${arch()}`);
}

try {
  main();
} catch (error) {
  console.error(`@anolisa/cli: ${error.message}`);
  process.exit(1);
}

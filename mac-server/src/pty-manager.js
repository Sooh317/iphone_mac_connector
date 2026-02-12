import fs from 'fs';
import os from 'os';
import path from 'path';
import pty from 'node-pty';
import { spawn } from 'child_process';

const REQUIRED_PATH_ENTRIES = [
  '/opt/homebrew/bin',
  '/usr/local/bin',
  '/usr/bin',
  '/bin',
  '/usr/sbin',
  '/sbin'
];
const MIN_TERMINAL_COLS = 30;
const MIN_TERMINAL_ROWS = 10;

function assertSupportedNodeRuntime() {
  const nodeMajor = Number.parseInt(process.versions.node.split('.')[0], 10);

  if (!Number.isNaN(nodeMajor) && nodeMajor < 24) {
    return;
  }

  if (process.env.ALLOW_NON_PTY_FALLBACK === 'true') {
    console.warn(
      `Unsupported Node.js runtime ${process.version}; continuing in ALLOW_NON_PTY_FALLBACK mode.`
    );
    return;
  }

  throw new Error(
    `Unsupported Node.js runtime ${process.version}. ` +
    'Use Node.js 18/20/22 LTS for stable node-pty PTY spawning.'
  );
}

function isExecutable(filePath) {
  if (typeof filePath !== 'string' || filePath.trim() === '') {
    return false;
  }

  try {
    fs.accessSync(filePath, fs.constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function sanitizeEnv(env = {}) {
  const cleaned = {};

  for (const [key, value] of Object.entries(env)) {
    if (value === undefined || value === null) {
      continue;
    }
    cleaned[key] = String(value);
  }

  return cleaned;
}

function mergePath(pathValue) {
  const existing = (pathValue || '')
    .split(':')
    .filter(Boolean);

  for (const requiredPath of REQUIRED_PATH_ENTRIES) {
    if (!existing.includes(requiredPath)) {
      existing.push(requiredPath);
    }
  }

  return existing.join(':');
}

function resolveShell(shell, env) {
  const requestedShell = typeof shell === 'string' && shell.trim() !== ''
    ? shell.trim()
    : '/bin/zsh';
  const expandedShell = requestedShell.startsWith('~/')
    ? path.join(env.HOME || os.homedir(), requestedShell.slice(2))
    : requestedShell;

  if (expandedShell.includes('/')) {
    if (!isExecutable(expandedShell)) {
      throw new Error(`Configured shell is not executable: ${expandedShell}`);
    }
    return expandedShell;
  }

  for (const pathEntry of env.PATH.split(':').filter(Boolean)) {
    const candidate = path.join(pathEntry, expandedShell);
    if (isExecutable(candidate)) {
      return candidate;
    }
  }

  throw new Error(`Configured shell "${expandedShell}" was not found in PATH: ${env.PATH}`);
}

function resolveCwd(cwd, env) {
  const candidates = [cwd, env.HOME, os.homedir(), process.cwd(), '/']
    .filter((value) => typeof value === 'string' && value.trim() !== '');

  for (const candidate of candidates) {
    try {
      if (fs.statSync(candidate).isDirectory()) {
        return candidate;
      }
    } catch {
      // Ignore invalid directory and try the next candidate.
    }
  }

  return '/';
}

function preparePtyOptions(shell, options = {}) {
  const mergedEnv = sanitizeEnv({
    ...process.env,
    ...(options.env || {})
  });

  mergedEnv.HOME = mergedEnv.HOME || os.homedir();
  mergedEnv.PATH = mergePath(mergedEnv.PATH);
  mergedEnv.LANG = mergedEnv.LANG || 'en_US.UTF-8';
  mergedEnv.LC_ALL = mergedEnv.LC_ALL || mergedEnv.LANG;
  mergedEnv.TERM = mergedEnv.TERM || 'xterm-256color';
  // Prevent Apple shell-session restore noise in non-Terminal.app PTY sessions.
  mergedEnv.SHELL_SESSIONS_DISABLE = mergedEnv.SHELL_SESSIONS_DISABLE || '1';
  // Avoid zsh prompt end-of-line marker ("%") when previous output had no trailing newline.
  mergedEnv.PROMPT_EOL_MARK = mergedEnv.PROMPT_EOL_MARK ?? '';

  const resolvedShell = resolveShell(shell, mergedEnv);
  mergedEnv.SHELL = resolvedShell;

  const ptyOptions = {
    name: 'xterm-256color',
    cols: 80,
    rows: 24,
    ...options,
    cwd: resolveCwd(options.cwd, mergedEnv),
    env: mergedEnv
  };

  return { resolvedShell, ptyOptions };
}

function createFallbackProcess(shell, options) {
  const fallbackShell = isExecutable('/bin/bash') ? '/bin/bash' : '/bin/sh';
  const resolvedShell = isExecutable(shell) ? shell : fallbackShell;

  const child = spawn(resolvedShell, ['-il'], {
    cwd: options.cwd,
    env: options.env,
    stdio: ['pipe', 'pipe', 'pipe']
  });

  return {
    pid: child.pid,
    onData(callback) {
      child.stdout.on('data', (chunk) => callback(chunk.toString()));
      child.stderr.on('data', (chunk) => callback(chunk.toString()));
    },
    onExit(callback) {
      child.on('exit', (exitCode, signal) => callback({ exitCode, signal }));
    },
    write(data) {
      if (child.stdin.writable) {
        child.stdin.write(data);
      }
    },
    resize() {
      // No-op in fallback mode (no PTY available)
    },
    kill() {
      child.kill('SIGKILL');
    }
  };
}

/**
 * Create a new PTY process
 * @param {string} shell - Shell executable path
 * @param {object} options - Additional options (optional)
 * @returns {object} PTY process instance
 */
export function createPty(shell, options = {}) {
  assertSupportedNodeRuntime();
  const { resolvedShell, ptyOptions } = preparePtyOptions(shell, options);

  try {
    return pty.spawn(resolvedShell, [], ptyOptions);
  } catch (error) {
    const details = `node-pty spawn failed (${error.message}) shell=${resolvedShell} cwd=${ptyOptions.cwd} PATH=${ptyOptions.env.PATH}`;
    if (process.env.ALLOW_NON_PTY_FALLBACK === 'true') {
      console.warn(`${details}; falling back to child_process mode.`);
      return createFallbackProcess(resolvedShell, ptyOptions);
    }

    const wrappedError = new Error(details);
    wrappedError.code = 'PTY_SPAWN_FAILED';
    throw wrappedError;
  }
}

/**
 * Attach PTY process to WebSocket
 * @param {object} ptyProcess - PTY process instance
 * @param {object} ws - WebSocket connection
 * @param {function} sendMessage - Callback to send messages via WebSocket
 */
export function attachPtyToWebSocket(ptyProcess, ws, sendMessage) {
  ptyProcess.onData((data) => {
    sendMessage({ type: 'output', data });
  });

  ptyProcess.onExit(({ exitCode, signal }) => {
    const errorMessage = `Process exited with code ${exitCode}${signal ? ` (signal: ${signal})` : ''}`;
    sendMessage({ type: 'error', message: errorMessage });
    ws.close();
  });
}

/**
 * Handle input data to PTY
 * @param {object} ptyProcess - PTY process instance
 * @param {string} data - Input data to write
 */
export function handleInput(ptyProcess, data) {
  if (ptyProcess && data) {
    ptyProcess.write(data);
  }
}

/**
 * Handle PTY resize
 * @param {object} ptyProcess - PTY process instance
 * @param {number} cols - Number of columns
 * @param {number} rows - Number of rows
 */
export function handleResize(ptyProcess, cols, rows) {
  if (
    ptyProcess &&
    typeof cols === 'number' &&
    typeof rows === 'number' &&
    cols >= MIN_TERMINAL_COLS &&
    rows >= MIN_TERMINAL_ROWS
  ) {
    ptyProcess.resize(cols, rows);
  }
}

/**
 * Safely kill PTY process
 * @param {object} ptyProcess - PTY process instance
 */
export function killPty(ptyProcess) {
  if (ptyProcess) {
    try {
      ptyProcess.kill();
    } catch (error) {
      console.error('Error killing PTY process:', error.message);
    }
  }
}

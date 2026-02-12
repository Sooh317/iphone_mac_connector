import test from 'node:test';
import assert from 'node:assert';
import WebSocket from 'ws';
import fs from 'fs';
import path from 'path';
import os from 'os';
import crypto from 'crypto';
import { spawn } from 'child_process';

// Test configuration
const TEST_PORT = 8766; // Use different port for testing
const TEST_HOST = '127.0.0.1';
const TEST_TOKEN_FILE = path.join(os.tmpdir(), `test-token-${Date.now()}`);
const TEST_TOKEN = crypto.randomBytes(32).toString('hex');

test('WebSocket Connection', async (t) => {
  let serverProcess = null;

  t.before(async () => {
    // Create test token file with 0600 permissions
    fs.writeFileSync(TEST_TOKEN_FILE, TEST_TOKEN, { mode: 0o600 });

    // Create test config with 0600 permissions
    const testConfig = {
      host: TEST_HOST,
      port: TEST_PORT,
      shell: '/bin/zsh',
      tokenFile: TEST_TOKEN_FILE
    };
    const configPath = path.join(process.cwd(), 'config.json');
    const configBackup = fs.existsSync(configPath) ? fs.readFileSync(configPath, 'utf8') : null;
    fs.writeFileSync(configPath, JSON.stringify(testConfig, null, 2), { mode: 0o600 });

    // Start test server with ALLOW_INSECURE_BIND for 127.0.0.1 binding
    serverProcess = spawn('node', ['src/server.js'], {
      env: { ...process.env, NODE_ENV: 'test', ALLOW_INSECURE_BIND: 'true' },
      cwd: process.cwd()
    });

    // Wait for server to start
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Restore original config
    if (configBackup) {
      fs.writeFileSync(configPath, configBackup, 'utf8');
    } else {
      fs.unlinkSync(configPath);
    }
  });

  t.after(() => {
    // Clean up
    if (serverProcess) {
      serverProcess.kill('SIGTERM');
    }
    if (fs.existsSync(TEST_TOKEN_FILE)) {
      fs.unlinkSync(TEST_TOKEN_FILE);
    }
  });

  await t.test('should reject connection without authentication', async () => {
    await assert.rejects(async () => {
      await new Promise((resolve, reject) => {
        const ws = new WebSocket(`ws://${TEST_HOST}:${TEST_PORT}/terminal`);
        ws.on('open', resolve);
        ws.on('error', reject);
        ws.on('unexpected-response', (req, res) => {
          if (res.statusCode === 401) {
            reject(new Error('Authentication failed'));
          }
        });
        setTimeout(() => reject(new Error('Connection timeout')), 3000);
      });
    });
  });

  await t.test('should reject connection with invalid token', async () => {
    await assert.rejects(async () => {
      await new Promise((resolve, reject) => {
        const ws = new WebSocket(`ws://${TEST_HOST}:${TEST_PORT}/terminal`, {
          headers: { Authorization: 'Bearer invalid-token' }
        });
        ws.on('open', resolve);
        ws.on('error', reject);
        ws.on('unexpected-response', (req, res) => {
          if (res.statusCode === 401) {
            reject(new Error('Authentication failed'));
          }
        });
        setTimeout(() => reject(new Error('Connection timeout')), 3000);
      });
    });
  });

  await t.test('should accept connection with valid token', async () => {
    const ws = await new Promise((resolve, reject) => {
      const socket = new WebSocket(`ws://${TEST_HOST}:${TEST_PORT}/terminal`, {
        headers: { Authorization: `Bearer ${TEST_TOKEN}` }
      });
      socket.on('open', () => resolve(socket));
      socket.on('error', reject);
      socket.on('unexpected-response', (req, res) => {
        reject(new Error(`Unexpected response: ${res.statusCode}`));
      });
      setTimeout(() => reject(new Error('Connection timeout')), 3000);
    });

    assert.ok(ws);
    assert.strictEqual(ws.readyState, WebSocket.OPEN);

    // Clean up
    ws.close();
    await new Promise(resolve => {
      ws.on('close', resolve);
      setTimeout(resolve, 1000);
    });
  });

  await t.test('should handle disconnection gracefully', async () => {
    const ws = await new Promise((resolve, reject) => {
      const socket = new WebSocket(`ws://${TEST_HOST}:${TEST_PORT}/terminal`, {
        headers: { Authorization: `Bearer ${TEST_TOKEN}` }
      });
      socket.on('open', () => resolve(socket));
      socket.on('error', reject);
      setTimeout(() => reject(new Error('Connection timeout')), 3000);
    });

    const closePromise = new Promise((resolve) => {
      ws.on('close', (code, reason) => {
        resolve({ code, reason: reason.toString() });
      });
    });

    ws.close(1000, 'Test complete');
    const { code } = await closePromise;

    assert.strictEqual(code, 1000);
  });

  await t.test('should enforce maximum connection limit', async () => {
    // Connect first client
    const ws1 = await new Promise((resolve, reject) => {
      const socket = new WebSocket(`ws://${TEST_HOST}:${TEST_PORT}/terminal`, {
        headers: { Authorization: `Bearer ${TEST_TOKEN}` }
      });
      socket.on('open', () => resolve(socket));
      socket.on('error', reject);
      setTimeout(() => reject(new Error('Connection timeout')), 3000);
    });

    // Try to connect second client (should be rejected)
    const closePromise = new Promise((resolve) => {
      const ws2 = new WebSocket(`ws://${TEST_HOST}:${TEST_PORT}/terminal`, {
        headers: { Authorization: `Bearer ${TEST_TOKEN}` }
      });
      ws2.on('close', (code, reason) => {
        resolve({ code, reason: reason.toString() });
      });
      ws2.on('unexpected-response', (req, res) => {
        // Server might reject before upgrade
        resolve({ code: res.statusCode });
      });
      setTimeout(() => resolve({ code: 0 }), 3000);
    });

    const { code } = await closePromise;
    assert.ok(code === 1008 || code === 401, `Expected connection limit rejection, got code ${code}`);

    // Clean up
    ws1.close();
    await new Promise(resolve => {
      ws1.on('close', resolve);
      setTimeout(resolve, 1000);
    });
  });
});

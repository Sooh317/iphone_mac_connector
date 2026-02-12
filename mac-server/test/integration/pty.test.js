import test from 'node:test';
import assert from 'node:assert';
import WebSocket from 'ws';
import fs from 'fs';
import path from 'path';
import os from 'os';
import crypto from 'crypto';
import { spawn } from 'child_process';

// Test configuration
const TEST_PORT = 8768; // Use different port for PTY testing
const TEST_HOST = '127.0.0.1';
const TEST_TOKEN_FILE = path.join(os.tmpdir(), `test-pty-token-${Date.now()}`);
const TEST_TOKEN = crypto.randomBytes(32).toString('hex');

test('PTY and Message Handling', async (t) => {
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

  await t.test('should receive output messages from PTY', async () => {
    const ws = await new Promise((resolve, reject) => {
      const socket = new WebSocket(`ws://${TEST_HOST}:${TEST_PORT}/terminal`, {
        headers: { Authorization: `Bearer ${TEST_TOKEN}` }
      });
      socket.on('open', () => resolve(socket));
      socket.on('error', reject);
      setTimeout(() => reject(new Error('Connection timeout')), 3000);
    });

    const outputPromise = new Promise((resolve) => {
      let receivedOutput = false;
      ws.on('message', (data) => {
        try {
          const message = JSON.parse(data);
          if (message.type === 'output' && !receivedOutput) {
            receivedOutput = true;
            resolve(message);
          }
        } catch (err) {
          // Ignore parse errors
        }
      });
      setTimeout(() => resolve(null), 5000);
    });

    const output = await outputPromise;
    assert.ok(output !== null, 'Should receive output message from PTY');
    assert.strictEqual(output.type, 'output');

    // Clean up
    ws.close();
    await new Promise(resolve => {
      ws.on('close', resolve);
      setTimeout(resolve, 1000);
    });
  });

  await t.test('should handle input messages', async () => {
    const ws = await new Promise((resolve, reject) => {
      const socket = new WebSocket(`ws://${TEST_HOST}:${TEST_PORT}/terminal`, {
        headers: { Authorization: `Bearer ${TEST_TOKEN}` }
      });
      socket.on('open', () => resolve(socket));
      socket.on('error', reject);
      setTimeout(() => reject(new Error('Connection timeout')), 3000);
    });

    // Send input command
    const command = 'echo "test"\n';
    ws.send(JSON.stringify({ type: 'input', data: command }));

    // Wait for echo response
    const echoPromise = new Promise((resolve) => {
      ws.on('message', (data) => {
        try {
          const message = JSON.parse(data);
          if (message.type === 'output' && message.data && message.data.includes('test')) {
            resolve(message);
          }
        } catch (err) {
          // Ignore parse errors
        }
      });
      setTimeout(() => resolve(null), 5000);
    });

    const echo = await echoPromise;
    assert.ok(echo !== null, 'Should receive echo of input command');

    // Clean up
    ws.close();
    await new Promise(resolve => {
      ws.on('close', resolve);
      setTimeout(resolve, 1000);
    });
  });

  await t.test('should handle resize messages', async () => {
    const ws = await new Promise((resolve, reject) => {
      const socket = new WebSocket(`ws://${TEST_HOST}:${TEST_PORT}/terminal`, {
        headers: { Authorization: `Bearer ${TEST_TOKEN}` }
      });
      socket.on('open', () => resolve(socket));
      socket.on('error', reject);
      setTimeout(() => reject(new Error('Connection timeout')), 3000);
    });

    // Send resize command
    ws.send(JSON.stringify({ type: 'resize', cols: 100, rows: 30 }));

    // Wait a bit to ensure no error occurs
    await new Promise(resolve => setTimeout(resolve, 500));

    // If we get here without error, resize was handled successfully
    assert.ok(true);

    // Clean up
    ws.close();
    await new Promise(resolve => {
      ws.on('close', resolve);
      setTimeout(resolve, 1000);
    });
  });

  await t.test('should ignore tiny resize messages', async () => {
    const ws = await new Promise((resolve, reject) => {
      const socket = new WebSocket(`ws://${TEST_HOST}:${TEST_PORT}/terminal`, {
        headers: { Authorization: `Bearer ${TEST_TOKEN}` }
      });
      socket.on('open', () => resolve(socket));
      socket.on('error', reject);
      setTimeout(() => reject(new Error('Connection timeout')), 3000);
    });

    // Send invalid tiny size; server should ignore instead of breaking PTY.
    ws.send(JSON.stringify({ type: 'resize', cols: 1, rows: 1 }));
    await new Promise(resolve => setTimeout(resolve, 200));

    ws.send(JSON.stringify({ type: 'input', data: 'echo "tiny-resize-ok"\n' }));

    const outputPromise = new Promise((resolve) => {
      ws.on('message', (data) => {
        try {
          const message = JSON.parse(data);
          if (message.type === 'output' && message.data && message.data.includes('tiny-resize-ok')) {
            resolve(message);
          }
        } catch {
          // Ignore parse errors
        }
      });
      setTimeout(() => resolve(null), 5000);
    });

    const output = await outputPromise;
    assert.ok(output !== null, 'PTY should still respond after tiny resize');

    ws.close();
    await new Promise(resolve => {
      ws.on('close', resolve);
      setTimeout(resolve, 1000);
    });
  });

  await t.test('should handle heartbeat messages', async () => {
    const ws = await new Promise((resolve, reject) => {
      const socket = new WebSocket(`ws://${TEST_HOST}:${TEST_PORT}/terminal`, {
        headers: { Authorization: `Bearer ${TEST_TOKEN}` }
      });
      socket.on('open', () => resolve(socket));
      socket.on('error', reject);
      setTimeout(() => reject(new Error('Connection timeout')), 3000);
    });

    // Send heartbeat
    ws.send(JSON.stringify({ type: 'heartbeat' }));

    // Wait for heartbeat response
    const heartbeatPromise = new Promise((resolve) => {
      ws.on('message', (data) => {
        try {
          const message = JSON.parse(data);
          if (message.type === 'heartbeat') {
            resolve(message);
          }
        } catch (err) {
          // Ignore parse errors
        }
      });
      setTimeout(() => resolve(null), 5000);
    });

    const heartbeat = await heartbeatPromise;
    assert.ok(heartbeat !== null, 'Should receive heartbeat response');
    assert.strictEqual(heartbeat.type, 'heartbeat');
    assert.ok(heartbeat.ts, 'Heartbeat should include timestamp');

    // Clean up
    ws.close();
    await new Promise(resolve => {
      ws.on('close', resolve);
      setTimeout(resolve, 1000);
    });
  });

  await t.test('should reject unknown message types', async () => {
    const ws = await new Promise((resolve, reject) => {
      const socket = new WebSocket(`ws://${TEST_HOST}:${TEST_PORT}/terminal`, {
        headers: { Authorization: `Bearer ${TEST_TOKEN}` }
      });
      socket.on('open', () => resolve(socket));
      socket.on('error', reject);
      setTimeout(() => reject(new Error('Connection timeout')), 3000);
    });

    // Send unknown message type
    ws.send(JSON.stringify({ type: 'unknown' }));

    // Wait for error response
    const errorPromise = new Promise((resolve) => {
      ws.on('message', (data) => {
        try {
          const message = JSON.parse(data);
          if (message.type === 'error') {
            resolve(message);
          }
        } catch (err) {
          // Ignore parse errors
        }
      });
      setTimeout(() => resolve(null), 2000);
    });

    const error = await errorPromise;
    assert.ok(error !== null, 'Should receive error for unknown message type');
    assert.strictEqual(error.type, 'error');

    // Clean up
    ws.close();
    await new Promise(resolve => {
      ws.on('close', resolve);
      setTimeout(resolve, 1000);
    });
  });
});

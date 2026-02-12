#!/usr/bin/env node

import http from 'http';
import { WebSocketServer } from 'ws';
import config from './config.js';
import { authenticateRequest } from './auth.js';
import { createPty, attachPtyToWebSocket, handleInput, handleResize, killPty } from './pty-manager.js';
import * as logger from './logger.js';

// Track active connections
let activeConnections = 0;
const MAX_CONNECTIONS = 1;

// Track active sessions for graceful shutdown
const activeSessions = new Set();

/**
 * Send JSON message over WebSocket
 */
function sendMessage(ws, message) {
  if (ws.readyState === 1) { // WebSocket.OPEN
    ws.send(JSON.stringify(message));
  }
}

/**
 * Handle WebSocket connection
 */
function handleConnection(ws, request) {
  const clientIp = request.socket.remoteAddress;

  // Check connection limit
  if (activeConnections >= MAX_CONNECTIONS) {
    logger.warn(`Connection rejected from ${clientIp}: maximum connections reached`);
    ws.close(1008, 'Maximum connections reached');
    return;
  }

  activeConnections++;
  logger.logConnection(clientIp, true);

  // Create PTY process
  let ptyProcess;
  try {
    ptyProcess = createPty(config.shell);
  } catch (error) {
    logger.error(`Failed to create PTY: ${error.message}`);
    sendMessage(ws, { type: 'error', message: 'Failed to create terminal session' });
    ws.close();
    activeConnections--;
    return;
  }

  // Track session for graceful shutdown with disconnect reason
  let disconnectReason = 'client closed connection';
  const session = { ws, ptyProcess };
  activeSessions.add(session);

  // Attach PTY to WebSocket
  attachPtyToWebSocket(ptyProcess, ws, (msg) => sendMessage(ws, msg));

  // --- Heartbeat management ---
  let lastHeartbeatReceived = Date.now();

  // Server-initiated heartbeat: send every 30 seconds
  const heartbeatInterval = setInterval(() => {
    sendMessage(ws, { type: 'heartbeat', ts: Math.floor(Date.now() / 1000) });
  }, 30000);

  // Timeout check: disconnect if no heartbeat received for 90 seconds
  const timeoutCheck = setInterval(() => {
    const elapsed = Date.now() - lastHeartbeatReceived;
    if (elapsed > 90000) {
      logger.warn(`Heartbeat timeout for ${clientIp} (${elapsed}ms)`);
      disconnectReason = 'heartbeat timeout';
      clearInterval(heartbeatInterval);
      clearInterval(timeoutCheck);
      ws.close(1001, 'Heartbeat timeout');
    }
  }, 15000); // Check every 15 seconds

  // Handle incoming messages
  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data);

      switch (message.type) {
        case 'input':
          if (message.data) {
            handleInput(ptyProcess, message.data);
          }
          break;

        case 'resize':
          if (message.cols && message.rows) {
            handleResize(ptyProcess, message.cols, message.rows);
          }
          break;

        case 'heartbeat':
          // Update last received timestamp
          lastHeartbeatReceived = Date.now();
          // Respond with heartbeat (including ts in seconds)
          sendMessage(ws, { type: 'heartbeat', ts: Math.floor(Date.now() / 1000) });
          break;

        default:
          logger.warn(`Unknown message type: ${message.type}`);
          sendMessage(ws, { type: 'error', message: `Unknown message type: ${message.type}` });
      }
    } catch (error) {
      logger.error(`Error handling message: ${error.message}`);
      sendMessage(ws, { type: 'error', message: 'Failed to process message' });
    }
  });

  // Handle WebSocket errors
  ws.on('error', (error) => {
    logger.error(`WebSocket error from ${clientIp}: ${error.message}`);
  });

  // Handle disconnection
  ws.on('close', (code, reason) => {
    clearInterval(heartbeatInterval);
    clearInterval(timeoutCheck);
    activeConnections--;
    activeSessions.delete(session);

    // Use close code and reason to determine disconnect cause
    let finalReason = disconnectReason;
    if (code === 1000) {
      finalReason = 'normal closure';
    } else if (code === 1001 && reason.toString() === 'Heartbeat timeout') {
      finalReason = 'heartbeat timeout';
    } else if (code === 1001 && reason.toString() === 'Server shutdown') {
      finalReason = 'server shutdown';
    } else if (code === 1006) {
      finalReason = 'abnormal closure (connection lost)';
    } else if (code !== 1001) {
      // For other codes, include the code in the reason
      finalReason = `${disconnectReason} (code: ${code})`;
    }

    logger.logDisconnection(clientIp, finalReason);
    killPty(ptyProcess);
  });
}

/**
 * Graceful shutdown handler
 */
function shutdown(signal, server) {
  logger.info(`Shutdown signal received: ${signal}`);

  // Close all active sessions
  for (const session of activeSessions) {
    const { ws, ptyProcess } = session;
    try {
      // Mark this as server shutdown before closing
      ws.close(1001, 'Server shutdown');
    } catch (error) {
      logger.error(`Error closing WebSocket: ${error.message}`);
    }

    try {
      killPty(ptyProcess);
    } catch (error) {
      logger.error(`Error killing PTY: ${error.message}`);
    }
  }

  activeSessions.clear();

  // Close HTTP server
  server.close(() => {
    logger.logServerStop();
    process.exit(0);
  });

  // Force exit after 10 seconds if graceful shutdown fails
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
}

/**
 * Create and start the server
 */
function startServer() {
  // Create HTTP server
  const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('Terminal Gateway Server\n');
  });

  // Create WebSocket server with noServer mode
  const wss = new WebSocketServer({ noServer: true });

  // Handle upgrade requests
  server.on('upgrade', (request, socket, head) => {
    const clientIp = socket.remoteAddress;

    // Authenticate request
    if (!authenticateRequest(request.headers)) {
      logger.logConnection(clientIp, false);
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
      return;
    }

    // Handle upgrade to WebSocket
    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit('connection', ws, request);
    });
  });

  // Handle WebSocket connections
  wss.on('connection', handleConnection);

  // Start listening
  server.listen(config.port, config.host, () => {
    logger.logServerStart(config.host, config.port);
    console.log('');
    console.log('Configuration:');
    console.log(`  Host: ${config.host}`);
    console.log(`  Port: ${config.port}`);
    console.log(`  Shell: ${config.shell}`);
    console.log(`  Max Connections: ${MAX_CONNECTIONS}`);
    console.log('');
  });

  // Handle shutdown gracefully
  process.on('SIGINT', () => shutdown('SIGINT', server));
  process.on('SIGTERM', () => shutdown('SIGTERM', server));

  // Handle uncaught exceptions
  process.on('uncaughtException', (error) => {
    logger.error(`Uncaught exception: ${error.message}`);
    logger.error(error.stack || '');
    shutdown('uncaughtException', server);
  });

  // Handle unhandled promise rejections
  process.on('unhandledRejection', (reason, promise) => {
    logger.error(`Unhandled rejection at: ${promise}, reason: ${reason}`);
    shutdown('unhandledRejection', server);
  });

  return server;
}

// Start the server
startServer();

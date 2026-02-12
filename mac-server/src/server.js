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

/**
 * Send JSON message over WebSocket
 */
function sendMessage(ws, message) {
  if (ws.readyState === 1) { // WebSocket.OPEN
    ws.send(JSON.stringify(message));
  }
}

/**
 * Handle incoming WebSocket messages
 */
function handleMessage(ws, ptyProcess, data) {
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
        // Respond to heartbeat with heartbeat
        sendMessage(ws, { type: 'heartbeat' });
        break;

      default:
        logger.warn(`Unknown message type: ${message.type}`);
        sendMessage(ws, { type: 'error', message: `Unknown message type: ${message.type}` });
    }
  } catch (error) {
    logger.error(`Error handling message: ${error.message}`);
    sendMessage(ws, { type: 'error', message: 'Failed to process message' });
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

  // Attach PTY to WebSocket
  attachPtyToWebSocket(ptyProcess, ws, (msg) => sendMessage(ws, msg));

  // Handle incoming messages
  ws.on('message', (data) => {
    handleMessage(ws, ptyProcess, data);
  });

  // Handle WebSocket errors
  ws.on('error', (error) => {
    logger.error(`WebSocket error from ${clientIp}: ${error.message}`);
  });

  // Handle disconnection
  ws.on('close', () => {
    activeConnections--;
    logger.logDisconnection(clientIp, 'client closed connection');
    killPty(ptyProcess);
  });
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
  process.on('SIGINT', () => {
    logger.logServerStop();
    process.exit(0);
  });

  process.on('SIGTERM', () => {
    logger.logServerStop();
    process.exit(0);
  });
}

// Start the server
startServer();

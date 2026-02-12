import { handleInput, handleResize } from './pty-manager.js';

/**
 * Parse incoming message
 * @param {string} raw - Raw message string
 * @returns {object|null} Parsed message object or null on failure
 */
export function parseMessage(raw) {
  try {
    return JSON.parse(raw);
  } catch (error) {
    console.error('Failed to parse message:', error.message);
    return null;
  }
}

/**
 * Create output message
 * @param {string} data - Output data
 * @returns {string} JSON string message
 */
export function createOutputMessage(data) {
  return JSON.stringify({ type: 'output', data });
}

/**
 * Create error message
 * @param {string} message - Error message
 * @returns {string} JSON string message
 */
export function createErrorMessage(message) {
  return JSON.stringify({ type: 'error', message });
}

/**
 * Create heartbeat message
 * @returns {string} JSON string message
 */
export function createHeartbeatMessage() {
  return JSON.stringify({ type: 'heartbeat', ts: Date.now() });
}

/**
 * Handle incoming message
 * @param {object} msg - Parsed message object
 * @param {object} ptyProcess - PTY process instance
 * @param {object} ws - WebSocket connection
 * @returns {string|null} Error message if type is unknown, null otherwise
 */
export function handleMessage(msg, ptyProcess, ws) {
  if (!msg || !msg.type) {
    return createErrorMessage('Invalid message format');
  }

  switch (msg.type) {
    case 'input':
      if (msg.data) {
        handleInput(ptyProcess, msg.data);
      }
      return null;

    case 'resize':
      if (typeof msg.cols === 'number' && typeof msg.rows === 'number') {
        handleResize(ptyProcess, msg.cols, msg.rows);
      }
      return null;

    case 'heartbeat':
      ws.send(createHeartbeatMessage());
      return null;

    default:
      return createErrorMessage(`Unknown message type: ${msg.type}`);
  }
}

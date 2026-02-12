import pty from 'node-pty';

/**
 * Create a new PTY process
 * @param {string} shell - Shell executable path
 * @param {object} options - Additional options (optional)
 * @returns {object} PTY process instance
 */
export function createPty(shell, options = {}) {
  const defaultOptions = {
    name: 'xterm-color',
    cols: 80,
    rows: 24,
    cwd: process.env.HOME,
    env: process.env
  };

  const ptyOptions = { ...defaultOptions, ...options };

  const ptyProcess = pty.spawn(shell, [], ptyOptions);

  return ptyProcess;
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
  if (ptyProcess && typeof cols === 'number' && typeof rows === 'number') {
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

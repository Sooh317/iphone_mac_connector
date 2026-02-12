import fs from 'fs';
import path from 'path';
import os from 'os';

// Log directory and file paths
const LOG_DIR = path.join(os.homedir(), '.terminal-gateway');
const LOG_FILE = path.join(LOG_DIR, 'audit.log');

// Log levels
const LEVELS = {
  INFO: 'INFO',
  WARN: 'WARN',
  ERROR: 'ERROR'
};

// Initialize log directory
function initLogDir() {
  if (!fs.existsSync(LOG_DIR)) {
    fs.mkdirSync(LOG_DIR, { recursive: true });
  }
}

// Core logging function
function log(level, message) {
  initLogDir();

  const timestamp = new Date().toISOString();
  const logEntry = `[${timestamp}] [${level}] ${message}\n`;

  // Write to stdout
  process.stdout.write(logEntry);

  // Append to log file
  fs.appendFileSync(LOG_FILE, logEntry, 'utf8');
}

// Exported logging functions
export function info(message) {
  log(LEVELS.INFO, message);
}

export function warn(message) {
  log(LEVELS.WARN, message);
}

export function error(message) {
  log(LEVELS.ERROR, message);
}

export function logConnection(ip, success) {
  const status = success ? 'successful' : 'failed';
  info(`Connection ${status} from ${ip}`);
}

export function logDisconnection(ip, reason) {
  info(`Client ${ip} disconnected: ${reason}`);
}

export function logServerStart(host, port) {
  info(`Server started on ${host}:${port}`);
}

export function logServerStop() {
  info('Server stopped');
}

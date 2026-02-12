import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Default configuration
const DEFAULT_CONFIG = {
  host: '0.0.0.0',
  port: 8765,
  shell: '/bin/zsh',
  tokenFile: '~/.terminal-gateway-token'
};

/**
 * Expand ~ to home directory
 */
function expandTilde(filepath) {
  if (filepath.startsWith('~/')) {
    return path.join(process.env.HOME, filepath.slice(2));
  }
  return filepath;
}

/**
 * Validate configuration
 */
function validateConfig(config) {
  // Validate port
  if (typeof config.port !== 'number' || config.port < 1 || config.port > 65535) {
    throw new Error(`Invalid port: ${config.port}. Must be between 1 and 65535.`);
  }

  // Validate host
  if (typeof config.host !== 'string' || config.host.trim() === '') {
    throw new Error('Invalid host: must be a non-empty string.');
  }

  // Validate shell
  if (typeof config.shell !== 'string' || config.shell.trim() === '') {
    throw new Error('Invalid shell: must be a non-empty string.');
  }

  // Validate tokenFile
  if (typeof config.tokenFile !== 'string' || config.tokenFile.trim() === '') {
    throw new Error('Invalid tokenFile: must be a non-empty string.');
  }

  return true;
}

/**
 * Load configuration from config.json
 */
function loadConfig() {
  const configPath = path.join(__dirname, '..', 'config.json');

  let userConfig = {};

  // Try to load config.json if it exists
  if (fs.existsSync(configPath)) {
    try {
      const configContent = fs.readFileSync(configPath, 'utf8');
      userConfig = JSON.parse(configContent);
    } catch (error) {
      throw new Error(`Failed to parse config.json: ${error.message}`);
    }
  }

  // Merge with defaults
  const config = {
    ...DEFAULT_CONFIG,
    ...userConfig
  };

  // Expand tilde in tokenFile path
  config.tokenFile = expandTilde(config.tokenFile);

  // Validate configuration
  validateConfig(config);

  return config;
}

export default loadConfig();

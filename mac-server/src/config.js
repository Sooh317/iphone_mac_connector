import fs from 'fs';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Default configuration
const DEFAULT_CONFIG = {
  host: '127.0.0.1',
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
 * Validate listen host is Tailscale interface or localhost
 */
function validateListenHost(host) {
  // Always allow localhost/loopback
  if (host === '127.0.0.1' || host === 'localhost' || host === '::1') {
    return;
  }

  // Get all network interfaces
  const interfaces = os.networkInterfaces();
  const tailscaleIps = [];

  for (const [ifname, addresses] of Object.entries(interfaces)) {
    if (!addresses) continue;

    for (const addr of addresses) {
      // Tailscale interfaces typically named 'tailscale0' or 'utun*'
      // Tailscale IPs are in the 100.x.x.x range (CGNAT)
      if (ifname === 'tailscale0' || addr.address.startsWith('100.')) {
        tailscaleIps.push(addr.address);
      }
    }
  }

  // Check if host is a Tailscale IP
  if (tailscaleIps.includes(host)) {
    return;
  }

  // Allow 0.0.0.0 with warning (for Docker/container environments)
  if (host === '0.0.0.0' || host === '::') {
    console.warn('WARNING: Listening on all interfaces (0.0.0.0). Ensure Tailscale ACL is properly configured.');
    console.warn('For better security, bind to a specific Tailscale IP or 127.0.0.1');
    return;
  }

  // Reject other addresses
  throw new Error(
    `Invalid listen host: ${host}\n` +
    `Host must be:\n` +
    `  - 127.0.0.1 (localhost)\n` +
    `  - Tailscale interface IP (100.x.x.x)\n` +
    `  - 0.0.0.0 (all interfaces, not recommended)\n` +
    `Available Tailscale IPs: ${tailscaleIps.length > 0 ? tailscaleIps.join(', ') : 'none detected'}`
  );
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

  // Validate listen host security (Tailscale requirement)
  validateListenHost(config.host);

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
    // Verify file permissions (must be 0600 for security)
    const stats = fs.statSync(configPath);
    const mode = stats.mode & 0o777;

    if (mode !== 0o600) {
      throw new Error(
        `Insecure config.json permissions: ${mode.toString(8)} (expected 600)\n` +
        `Please fix with: chmod 600 ${configPath}`
      );
    }

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

  // Environment variable overrides (highest priority)
  if (process.env.GATEWAY_HOST) {
    config.host = process.env.GATEWAY_HOST;
  }
  if (process.env.GATEWAY_PORT) {
    config.port = parseInt(process.env.GATEWAY_PORT, 10);
  }
  if (process.env.GATEWAY_SHELL) {
    config.shell = process.env.GATEWAY_SHELL;
  }
  if (process.env.GATEWAY_TOKEN_FILE) {
    config.tokenFile = process.env.GATEWAY_TOKEN_FILE;
  }

  // Validate configuration
  validateConfig(config);

  return config;
}

export default loadConfig();

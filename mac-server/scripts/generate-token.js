#!/usr/bin/env node

import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

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
 * Load config to get tokenFile path
 */
function getTokenFilePath() {
  const configPath = path.join(__dirname, '..', 'config.json');

  let tokenFile = '~/.terminal-gateway-token'; // default

  if (fs.existsSync(configPath)) {
    try {
      const configContent = fs.readFileSync(configPath, 'utf8');
      const config = JSON.parse(configContent);
      if (config.tokenFile) {
        tokenFile = config.tokenFile;
      }
    } catch (error) {
      console.error('Warning: Failed to read config.json, using default token file path');
    }
  }

  return expandTilde(tokenFile);
}

/**
 * Generate a cryptographically secure random token
 */
function generateToken() {
  // Generate 32 bytes (256 bits) of random data
  const buffer = crypto.randomBytes(32);
  // Convert to hex string (64 characters)
  return buffer.toString('hex');
}

/**
 * Main function
 */
function main() {
  try {
    // Check for --show-token flag
    const showToken = process.argv.includes('--show-token');

    const tokenFilePath = getTokenFilePath();
    const token = generateToken();

    // Ensure directory exists
    const tokenDir = path.dirname(tokenFilePath);
    if (!fs.existsSync(tokenDir)) {
      fs.mkdirSync(tokenDir, { recursive: true });
    }

    // Write token to file with 0600 permissions (read/write for owner only)
    fs.writeFileSync(tokenFilePath, token, { mode: 0o600 });
    // Explicitly set permissions to ensure 0600 even on existing files
    fs.chmodSync(tokenFilePath, 0o600);

    console.log('');
    console.log('Token generated successfully!');
    console.log('');
    console.log('Token file:', tokenFilePath);
    console.log('');

    // Only show token if explicitly requested with --show-token flag
    if (showToken) {
      console.log('Your authentication token:');
      console.log('');
      console.log(`  ${token}`);
      console.log('');
      console.log('Use this token in the Authorization header:');
      console.log(`  Authorization: Bearer ${token}`);
      console.log('');
      console.log('WARNING: This token provides full access. Keep it secure and never commit it to version control.');
      console.log('');
    } else {
      console.log('Token has been saved securely to the file above.');
      console.log('');
      console.log('For security, the token is not displayed by default.');
      console.log('To view it once, run:');
      console.log(`  node scripts/generate-token.js --show-token`);
      console.log('');
      console.log('Or read directly from file (ensure secure environment):');
      console.log(`  cat ${tokenFilePath}`);
      console.log('');
    }

  } catch (error) {
    console.error('Error generating token:', error.message);
    process.exit(1);
  }
}

main();

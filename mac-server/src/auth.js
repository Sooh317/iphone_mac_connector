import fs from 'fs';
import crypto from 'crypto';
import config from './config.js';

let cachedToken = null;

/**
 * Load authentication token from file
 */
function loadToken() {
  if (cachedToken) {
    return cachedToken;
  }

  const tokenFile = config.tokenFile;

  if (!fs.existsSync(tokenFile)) {
    throw new Error(
      `Token file not found: ${tokenFile}\n` +
      'Please run: npm run generate-token'
    );
  }

  // Verify token file permissions (must be 600)
  const stat = fs.statSync(tokenFile);
  const mode = stat.mode & 0o777;
  if (mode !== 0o600) {
    throw new Error(
      `Insecure token file mode: ${mode.toString(8)} (expected 600)\n` +
      `Please run: chmod 600 ${tokenFile}`
    );
  }

  try {
    cachedToken = fs.readFileSync(tokenFile, 'utf8').trim();

    if (!cachedToken) {
      throw new Error('Token file is empty');
    }

    // Validate token length (must be at least 32 bytes)
    const tokenLength = Buffer.byteLength(cachedToken, 'utf8');
    if (tokenLength < 32) {
      throw new Error(
        `Token is too short: ${tokenLength} bytes (minimum 32 bytes required)\n` +
        'Please regenerate token with: npm run generate-token'
      );
    }

    return cachedToken;
  } catch (error) {
    throw new Error(`Failed to read token file: ${error.message}`);
  }
}

/**
 * Verify authentication token using timing-safe comparison
 *
 * @param {string} providedToken - Token from Authorization header
 * @returns {boolean} - True if token is valid
 */
export function verifyToken(providedToken) {
  if (!providedToken) {
    return false;
  }

  try {
    const validToken = loadToken();

    // Both tokens must be the same length for timing-safe comparison
    if (providedToken.length !== validToken.length) {
      return false;
    }

    // Convert strings to buffers for crypto.timingSafeEqual
    const providedBuffer = Buffer.from(providedToken, 'utf8');
    const validBuffer = Buffer.from(validToken, 'utf8');

    // Use timing-safe comparison to prevent timing attacks
    return crypto.timingSafeEqual(providedBuffer, validBuffer);
  } catch (error) {
    console.error('Token verification error:', error.message);
    return false;
  }
}

/**
 * Extract Bearer token from Authorization header
 *
 * @param {string} authHeader - Authorization header value
 * @returns {string|null} - Token or null if not found
 */
export function extractBearerToken(authHeader) {
  if (!authHeader || typeof authHeader !== 'string') {
    return null;
  }

  const parts = authHeader.split(' ');

  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return null;
  }

  return parts[1];
}

/**
 * Authenticate WebSocket upgrade request
 *
 * @param {Object} headers - HTTP headers from upgrade request
 * @returns {boolean} - True if authenticated
 */
export function authenticateRequest(headers) {
  const authHeader = headers['authorization'];
  const token = extractBearerToken(authHeader);

  if (!token) {
    return false;
  }

  return verifyToken(token);
}

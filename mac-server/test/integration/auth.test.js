import test from 'node:test';
import assert from 'node:assert';
import { extractBearerToken } from '../../src/auth.js';

/**
 * Unit tests for extractBearerToken (pure function)
 *
 * Note: verifyToken and authenticateRequest tests have been moved to
 * integration tests (connection.test.js) as they depend on config loading
 * and token file setup which is difficult to mock in unit tests.
 */
test('Authentication - extractBearerToken', async (t) => {
  await t.test('should extract valid Bearer token', () => {
    const header = 'Bearer test-token-12345';
    const token = extractBearerToken(header);
    assert.strictEqual(token, 'test-token-12345');
  });

  await t.test('should return null for invalid header format', () => {
    const token = extractBearerToken('InvalidFormat test-token');
    assert.strictEqual(token, null);
  });

  await t.test('should return null for missing header', () => {
    const token = extractBearerToken(null);
    assert.strictEqual(token, null);
  });

  await t.test('should return null for empty Bearer token', () => {
    const token = extractBearerToken('Bearer ');
    assert.strictEqual(token, null);
  });
});

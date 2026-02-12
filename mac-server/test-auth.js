#!/usr/bin/env node

/**
 * Simple test script to verify authentication
 * This demonstrates the auth flow without starting the full server
 */

import { authenticateRequest, extractBearerToken, verifyToken } from './src/auth.js';

console.log('Testing authentication module...\n');

// Test 1: Extract Bearer token
console.log('Test 1: Extract Bearer token');
const validHeader = 'Bearer test-token-12345';
const token = extractBearerToken(validHeader);
console.log(`  Input: "${validHeader}"`);
console.log(`  Extracted token: "${token}"`);
console.log(`  Result: ${token === 'test-token-12345' ? 'PASS' : 'FAIL'}\n`);

// Test 2: Invalid header format
console.log('Test 2: Invalid header format');
const invalidHeader = 'Basic user:pass';
const noToken = extractBearerToken(invalidHeader);
console.log(`  Input: "${invalidHeader}"`);
console.log(`  Extracted token: ${noToken}`);
console.log(`  Result: ${noToken === null ? 'PASS' : 'FAIL'}\n`);

// Test 3: Verify real token (will fail if token not generated)
console.log('Test 3: Verify authentication');
try {
  const headers = {
    'authorization': 'Bearer invalid-token'
  };
  const isAuth = authenticateRequest(headers);
  console.log(`  With invalid token: ${isAuth ? 'AUTHENTICATED' : 'REJECTED'}`);
  console.log(`  Result: ${!isAuth ? 'PASS' : 'FAIL'}\n`);
} catch (error) {
  console.log(`  Error: ${error.message}`);
  console.log('  (Run "npm run generate-token" to create a token)\n');
}

console.log('Authentication tests complete!');

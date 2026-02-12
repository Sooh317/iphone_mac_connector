#!/usr/bin/env node

import crypto from 'crypto';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { execFileSync } from 'child_process';
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

  if (process.env.GATEWAY_TOKEN_FILE && process.env.GATEWAY_TOKEN_FILE.trim() !== '') {
    tokenFile = process.env.GATEWAY_TOKEN_FILE;
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
 * Generate QR image on macOS using Swift/CoreImage.
 */
function generateTokenQRCode(payload) {
  const swiftScriptPath = path.join(os.tmpdir(), `terminal-gateway-qr-${Date.now()}.swift`);
  const qrFilePath = path.join(os.tmpdir(), `terminal-gateway-token-qr-${Date.now()}.png`);
  const moduleCachePath = path.join(os.tmpdir(), 'terminal-gateway-swift-module-cache');

  const swiftCode = `
import Foundation
import CoreImage
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 3 else {
  fputs("Missing arguments\\n", stderr)
  exit(1)
}

let payload = args[1]
let outputPath = args[2]
guard let payloadData = payload.data(using: .utf8) else {
  fputs("Failed to encode payload\\n", stderr)
  exit(1)
}

guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
  fputs("Failed to create CIQRCodeGenerator filter\\n", stderr)
  exit(1)
}
filter.setValue(payloadData, forKey: "inputMessage")
filter.setValue("M", forKey: "inputCorrectionLevel")

guard let outputImage = filter.outputImage else {
  fputs("Failed to create QR image\\n", stderr)
  exit(1)
}

let scale: CGFloat = 16
let qrImage = outputImage
  .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
  .cropped(to: outputImage.extent.applying(CGAffineTransform(scaleX: scale, y: scale)).integral)
let qrExtent = qrImage.extent.integral

let qrWidth = Int(qrExtent.width)
let qrHeight = Int(qrExtent.height)
let bytesPerPixel = 4
let qrBytesPerRow = qrWidth * bytesPerPixel
var qrBitmap = [UInt8](repeating: 0, count: qrHeight * qrBytesPerRow)

let context = CIContext(options: nil)
let colorSpace = CGColorSpaceCreateDeviceRGB()
context.render(
  qrImage,
  toBitmap: &qrBitmap,
  rowBytes: qrBytesPerRow,
  bounds: qrExtent,
  format: .RGBA8,
  colorSpace: colorSpace
)

// Binarize pixels to avoid anti-aliasing artifacts that break camera decoding.
for index in stride(from: 0, to: qrBitmap.count, by: 4) {
  let luminance = qrBitmap[index]
  let value: UInt8 = luminance < 128 ? 0 : 255
  qrBitmap[index] = value
  qrBitmap[index + 1] = value
  qrBitmap[index + 2] = value
  qrBitmap[index + 3] = 255
}

// Add quiet zone (white border) around QR for reliable camera scanning.
let quietZone = Int(scale * 4)
let width = qrWidth + (quietZone * 2)
let height = qrHeight + (quietZone * 2)
let bytesPerRow = width * bytesPerPixel
var bitmap = [UInt8](repeating: 255, count: height * bytesPerRow)

for y in 0..<qrHeight {
  let srcStart = y * qrBytesPerRow
  let srcEnd = srcStart + qrBytesPerRow
  let dstStart = ((y + quietZone) * bytesPerRow) + (quietZone * bytesPerPixel)
  bitmap[dstStart..<(dstStart + qrBytesPerRow)] = qrBitmap[srcStart..<srcEnd]
}

let data = Data(bitmap)
guard let provider = CGDataProvider(data: data as CFData),
      let cgImage = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      ) else {
  fputs("Failed to create CGImage\\n", stderr)
  exit(1)
}

let outputURL = URL(fileURLWithPath: outputPath) as CFURL
guard let destination = CGImageDestinationCreateWithURL(
  outputURL,
  UTType.png.identifier as CFString,
  1,
  nil
) else {
  fputs("Failed to create image destination\\n", stderr)
  exit(1)
}

CGImageDestinationAddImage(destination, cgImage, nil)
guard CGImageDestinationFinalize(destination) else {
  fputs("Failed to write PNG\\n", stderr)
  exit(1)
}
`;

  fs.writeFileSync(swiftScriptPath, swiftCode, { mode: 0o600 });
  if (!fs.existsSync(moduleCachePath)) {
    fs.mkdirSync(moduleCachePath, { recursive: true });
  }

  try {
    execFileSync('swift', ['-module-cache-path', moduleCachePath, swiftScriptPath, payload, qrFilePath], {
      stdio: 'pipe',
      env: {
        ...process.env,
        SWIFT_MODULECACHE_PATH: moduleCachePath
      }
    });
    return qrFilePath;
  } finally {
    if (fs.existsSync(swiftScriptPath)) {
      fs.unlinkSync(swiftScriptPath);
    }
  }
}

function openQRCodeImage(qrFilePath) {
  execFileSync('open', [qrFilePath], { stdio: 'ignore' });
}

function copyTokenToClipboard(token) {
  execFileSync('pbcopy', [], {
    input: `${token}\n`,
    encoding: 'utf8',
    stdio: 'pipe'
  });
}

/**
 * Main function
 */
function main() {
  try {
    // Check for --show-token flag
    const showToken = process.argv.includes('--show-token');
    const showQR = process.argv.includes('--qr');
    const copyToClipboard = !process.argv.includes('--no-copy');

    const tokenFilePath = getTokenFilePath();
    const token = generateToken();
    const qrPayload = `iphonemacconnector://import-token?token=${encodeURIComponent(token)}`;

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

    if (copyToClipboard) {
      try {
        copyTokenToClipboard(token);
        console.log('Token copied to clipboard (Universal Clipboard supported).');
        console.log('');
      } catch (error) {
        console.error('Warning: Failed to copy token to clipboard:', error.message);
        console.log('');
      }
    }

    if (showQR) {
      try {
        const qrFilePath = generateTokenQRCode(qrPayload);
        console.log(`QR image file: ${qrFilePath}`);
        console.log('QR payload uses app deeplink and may not be handled by Camera on some iOS versions.');
        console.log('Use clipboard sharing as the primary setup path.');

        try {
          openQRCodeImage(qrFilePath);
          console.log('QR code opened in a viewer window.');
        } catch (openError) {
          console.error('Warning: Failed to auto-open QR code image:', openError.message);
          console.error('Open the file above manually to scan from iPhone.');
        }

        console.log('');
      } catch (error) {
        console.error('Warning: Failed to generate QR code:', error.message);
        console.error('You can still copy token from the token file.');
        console.log('');
      }
    }

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
      console.log('QR code is optional.');
      console.log('To generate QR as well, run:');
      console.log('  node scripts/generate-token.js --qr');
      console.log('');
      console.log('Token is copied to clipboard by default.');
      console.log('To skip clipboard copy, run:');
      console.log('  node scripts/generate-token.js --no-copy');
      console.log('');
      console.log('For security, the token text is not displayed by default.');
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

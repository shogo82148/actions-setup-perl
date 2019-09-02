import io = require('@actions/io');
import path = require('path');
import os = require('os');
import fs = require('fs');

const toolDir = path.join(__dirname, 'runner', 'tools');
const tempDir = path.join(__dirname, 'runner', 'temp');
// const dataDir = path.join(__dirname, 'data');

process.env['RUNNER_TOOL_CACHE'] = toolDir;
process.env['RUNNER_TEMP'] = tempDir;
import * as installer from '../src/installer';

const IS_WINDOWS = process.platform === 'win32';

describe('installer tests', () => {
  beforeAll(async () => {
    await io.rmRF(toolDir);
    await io.rmRF(tempDir);
  }, 100000);

  afterAll(async () => {
    try {
      await io.rmRF(toolDir);
      await io.rmRF(tempDir);
    } catch {
      console.log('Failed to remove test directories');
    }
  }, 100000);

  it('Acquires version of go if no matching version is installed', async () => {
    await installer.getPerl('5.30');
    const goDir = path.join(toolDir, 'go', '5.30', os.arch());

    expect(fs.existsSync(`${goDir}.complete`)).toBe(true);
    if (IS_WINDOWS) {
      expect(fs.existsSync(path.join(goDir, 'bin', 'perl.exe'))).toBe(true);
    } else {
      expect(fs.existsSync(path.join(goDir, 'bin', 'perl'))).toBe(true);
    }
  }, 100000);
});

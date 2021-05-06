// install CPAN modules and caching

import * as core from '@actions/core';
import * as exec from '@actions/exec';
import * as cache from '@actions/cache';
import * as crypto from 'crypto';
import * as fs from 'fs';
import * as stream from 'stream';
import * as util from 'util';
import * as path from 'path';

export interface Options {
  // path to perl installed
  toolPath: string;

  install_modules_with: string | null;
  install_modules_args: string | null;
  install_modules: string | null;
  enable_modules_cache: boolean;
  working_directory: string | null;
}

export async function install(opt: Options): Promise<void> {
  if (!opt.install_modules_with) {
    core.info('nothing to install');
    return;
  }
  let installer: (opt: Options) => Promise<void>;
  switch (opt.install_modules_with) {
    case 'cpanm':
      installer = installWithCpanm;
      break;
    case 'cpm':
      installer = installWithCpm;
      break;
    case 'carton':
      installer = installWithCarton;
      break;
    default:
      core.error(`unknown installer: ${opt.install_modules_with}`);
      return;
  }

  const workingDirectory = path.join(process.cwd(), opt.working_directory || '.');

  const cachePath = path.join(workingDirectory, 'local');
  const paths = [cachePath];

  const baseKey = await cacheKey(opt);
  const cpanfileKey = await hashFiles(
    path.join(workingDirectory, 'cpanfile'),
    path.join(workingDirectory, 'cpanfile.snapshot')
  );
  const installKey = hashString(opt.install_modules || '');
  const key = `${baseKey}-${cpanfileKey}-${installKey}`;
  const restoreKeys = [`${baseKey}-${cpanfileKey}-`, `${baseKey}-`];

  // restore cache
  let cachedKey: string | undefined = undefined;
  if (opt.enable_modules_cache) {
    try {
      cachedKey = await cache.restoreCache(paths, key, restoreKeys);
    } catch (error) {
      if (error.name === cache.ValidationError.name) {
      } else {
        core.info(`[warning] There was an error restoring the cache ${error.message}`);
      }
    }
    if (cachedKey) {
      core.info(`Found cache for key: ${cachedKey}`);
    } else {
      core.info(`cache not found for input keys: ${key}, ${restoreKeys.join(', ')}`);
    }
  }

  // install
  await installer(opt);

  // configure environment values
  core.addPath(path.join(cachePath, 'bin'));
  core.exportVariable('PERL5LIB', path.join(cachePath, 'lib', 'perl5') + path.delimiter + process.env['PERL5LIB']);

  if (opt.enable_modules_cache) {
    // save cache
    if (cachedKey !== key) {
      core.info(`saving cache for ${key}.`);
      try {
        await cache.saveCache(paths, key);
      } catch (error) {
        if (error.name === cache.ValidationError.name) {
          throw error;
        } else if (error.name === cache.ReserveCacheError.name) {
          core.info(error.message);
        } else {
          core.info(`[warning]${error.message}`);
        }
      }
    } else {
      core.info(`cache for ${key} already exists, skip saving.`);
    }
  }

  return;
}

async function cacheKey(opt: Options): Promise<string> {
  let key = 'setup-perl-module-cache-v1-';
  key += await digestOfPerlVersion(opt);
  key += '-' + (opt.install_modules_with || 'unknown');
  return key;
}

// we use `perl -V` to the cache key.
// it contains useful information to use as the cache key,
// e.g. the platform, the version of perl, the compiler option for building perl
async function digestOfPerlVersion(opt: Options): Promise<string> {
  const perl = path.join(opt.toolPath, 'bin', 'perl');
  const hash = crypto.createHash('sha256');
  await exec.exec(perl, ['-V'], {
    listeners: {
      stdout: (data: Buffer) => {
        hash.update(data);
      }
    },
    env: {}
  });
  hash.end();
  return hash.digest('hex');
}

// see https://github.com/actions/runner/blob/master/src/Misc/expressionFunc/hashFiles/src/hashFiles.ts
async function hashFiles(...files: string[]): Promise<string> {
  const result = crypto.createHash('sha256');
  for (const file of files) {
    try {
      const hash = crypto.createHash('sha256');
      const pipeline = util.promisify(stream.pipeline);
      await pipeline(fs.createReadStream(file), hash);
      result.write(hash.digest());
    } catch (err) {
      // skip files that doesn't exist.
      if (err.code !== 'ENOENT') {
        throw err;
      }
    }
  }
  result.end();
  return result.digest('hex');
}

function hashString(s: string): string {
  const hash = crypto.createHash('sha256');
  hash.update(s, 'utf-8');
  hash.end();
  return hash.digest('hex');
}

async function installWithCpanm(opt: Options): Promise<void> {
  const perl = path.join(opt.toolPath, 'bin', 'perl');
  const cpanm = path.join(__dirname, '..', 'bin', 'cpanm');
  const workingDirectory = path.join(process.cwd(), opt.working_directory || '.');
  const execOpt = {
    cwd: workingDirectory
  };
  const args = [cpanm, '--local-lib-contained', 'local', '--notest'];
  if (core.isDebug()) {
    args.push('--verbose');
  }
  if (await exists(path.join(workingDirectory, 'cpanfile'))) {
    await exec.exec(perl, [...args, '--installdeps', '.'], execOpt);
  }
  if (opt.install_modules) {
    const modules = opt.install_modules.split('\n').map(s => s.trim());
    await exec.exec(perl, [...args, ...modules], execOpt);
  }
}

async function installWithCpm(opt: Options): Promise<void> {
  const perl = path.join(opt.toolPath, 'bin', 'perl');
  const cpm = path.join(__dirname, '..', 'bin', 'cpm');
  const workingDirectory = path.join(process.cwd(), opt.working_directory || '.');
  const execOpt = {
    cwd: workingDirectory
  };
  const args = [cpm, 'install', '--show-build-log-on-failure'];
  if (core.isDebug()) {
    args.push('--verbose');
  }
  if (
    (await exists(path.join(workingDirectory, 'cpanfile'))) ||
    (await exists(path.join(workingDirectory, 'cpanfile.snapshot')))
  ) {
    await exec.exec(perl, [...args], execOpt);
  }
  if (opt.install_modules) {
    const modules = opt.install_modules.split('\n').map(s => s.trim());
    await exec.exec(perl, [...args, ...modules], execOpt);
  }
}

async function installWithCarton(opt: Options): Promise<void> {
  const perl = path.join(opt.toolPath, 'bin', 'perl');
  const carton = path.join(__dirname, '..', 'bin', 'carton');
  const workingDirectory = path.join(process.cwd(), opt.working_directory || '.');
  const execOpt = {
    cwd: workingDirectory
  };
  const args = [carton, 'install'];
  if (
    (await exists(path.join(workingDirectory, 'cpanfile'))) ||
    (await exists(path.join(workingDirectory, 'cpanfile.snapshot')))
  ) {
    await exec.exec(perl, [...args], execOpt);
  }
  if (opt.install_modules) {
    const cpanm = path.join(__dirname, '..', 'bin', 'cpanm');
    const modules = opt.install_modules.split('\n').map(s => s.trim());
    const args = [cpanm, '--local-lib-contained', 'local', '--notest'];
    if (core.isDebug()) {
      args.push('--verbose');
    }
    await exec.exec(perl, [...args, ...modules], execOpt);
  }
}

async function exists(path: string): Promise<boolean> {
  return new Promise((resolve, reject) => {
    fs.stat(path, err => {
      if (err) {
        if (err.code === 'ENOENT') {
          resolve(false);
        } else {
          reject(err);
        }
        return;
      }
      resolve(true);
    });
  });
}

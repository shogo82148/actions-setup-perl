// install CPAN modules and caching

import * as core from "@actions/core";
import * as exec from "@actions/exec";
import * as cache from "@actions/cache";
import * as crypto from "crypto";
import * as fs from "fs";
import * as stream from "stream";
import * as util from "util";
import * as path from "path";
import {State, Outputs} from './constants';

export interface Options {
  // the digest of `perl -V`
  perlHash: string;

  // path to perl installed
  toolPath: string;

  install_modules_with: string | null;
  install_modules_args: string | null;
  install_modules: string | null;
  enable_modules_cache: boolean;
  working_directory: string | null;
}

export async function install(opt: Options): Promise<void> {
  let installer: (opt: Options) => Promise<void>;
  switch (opt.install_modules_with || "cpanm") {
    case "cpanm":
      installer = installWithCpanm;
      break;
    case "cpm":
      installer = installWithCpm;
      break;
    case "carton":
      installer = installWithCarton;
      break;
    default:
      core.error(`unknown installer: ${opt.install_modules_with}`);
      return;
  }

  const workingDirectory = path.join(process.cwd(), opt.working_directory || ".");

  const cachePath = path.join(workingDirectory, "local");
  const paths = [cachePath];

  const baseKey = await cacheKey(opt);
  const cpanfileKey = await hashFiles(
    opt,
    path.join(workingDirectory, "cpanfile"),
    path.join(workingDirectory, "cpanfile.snapshot")
  );
  const installKey = hashString(opt.install_modules || "");
  const key = `${baseKey}-${cpanfileKey}-${installKey}`;
  const restoreKeys = [`${baseKey}-${cpanfileKey}-`, `${baseKey}-`];

  // restore cache
  let cachedKey: string | undefined = undefined;
  if (opt.enable_modules_cache) {
    try {
      cachedKey = await cache.restoreCache(paths, key, restoreKeys);
    } catch (error) {
      if (error instanceof Error) {
        if (error.name === cache.ValidationError.name) {
        } else {
          core.info(`[warning] There was an error restoring the cache ${error.message}`);
        }
      } else {
        core.info(`[warning] There was an error restoring the cache ${error}`);
      }
    }
    if (cachedKey) {
      core.info(`Found cache for key: ${cachedKey}`);
      core.setOutput(Outputs.CacheHit, 'true');
    } else {
      core.info(`cache not found for input keys: ${key}, ${restoreKeys.join(", ")}`);
      core.setOutput(Outputs.CacheHit, 'false');
    }
  }

  // install
  await installer(opt);

  // configure environment values
  core.addPath(path.join(cachePath, "bin"));
  const archName = await getArchName(opt);
  const libPath = path.join(cachePath, "lib", "perl5");
  const libArchPath = path.join(cachePath, "lib", "perl5", archName);
  core.exportVariable("PERL5LIB", libPath + path.delimiter + libArchPath + path.delimiter + process.env["PERL5LIB"]);

  if (opt.enable_modules_cache) {
    core.saveState(State.CachePath, cachePath)
    core.saveState(State.CachePrimaryKey, key);
    core.saveState(State.CacheMatchedKey, cachedKey);
  }

  return;
}

async function cacheKey(opt: Options): Promise<string> {
  let key = "setup-perl-module-cache-v1-";
  key += opt.perlHash;
  key += "-" + (opt.install_modules_with || "unknown");
  return key;
}

// see https://github.com/actions/runner/blob/master/src/Misc/expressionFunc/hashFiles/src/hashFiles.ts
async function hashFiles(opt: Options, ...files: string[]): Promise<string> {
  const result = crypto.createHash("sha256");
  result.update(opt.install_modules_args || "");
  for (const file of files) {
    try {
      const hash = crypto.createHash("sha256");
      const pipeline = util.promisify(stream.pipeline);
      await pipeline(fs.createReadStream(file), hash);
      result.write(hash.digest());
    } catch (err) {
      // skip files that doesn't exist.
      if ((err as any)?.code !== "ENOENT") {
        throw err;
      }
    }
  }
  result.end();
  return result.digest("hex");
}

function hashString(s: string): string {
  const hash = crypto.createHash("sha256");
  hash.update(s, "utf-8");
  hash.end();
  return hash.digest("hex");
}

async function installWithCpanm(opt: Options): Promise<void> {
  const perl = path.join(opt.toolPath, "bin", "perl");
  const cpanm = path.join(__dirname, "..", "bin", "cpanm");
  const workingDirectory = path.join(process.cwd(), opt.working_directory || ".");
  const execOpt = {
    cwd: workingDirectory,
  };
  const args = [cpanm, "--local-lib-contained", "local", "--notest"];
  if (core.isDebug()) {
    args.push("--verbose");
  }
  args.push(...splitArgs(opt.install_modules_args));
  if (opt.install_modules_with) {
    if (await exists(path.join(workingDirectory, "cpanfile"))) {
      await exec.exec(perl, [...args, "--installdeps", "."], execOpt);
    }
  }
  const modules = splitModules(opt.install_modules);
  if (modules.length > 0) {
    await exec.exec(perl, [...args, ...modules], execOpt);
  }
}

async function installWithCpm(opt: Options): Promise<void> {
  const perl = path.join(opt.toolPath, "bin", "perl");
  const cpm = path.join(__dirname, "..", "bin", "cpm");
  const workingDirectory = path.join(process.cwd(), opt.working_directory || ".");
  const execOpt = {
    cwd: workingDirectory,
  };
  const args = [cpm, "install", "--show-build-log-on-failure"];
  if (core.isDebug()) {
    args.push("--verbose");
  }
  args.push(...splitArgs(opt.install_modules_args));
  if (
    (await exists(path.join(workingDirectory, "cpanfile"))) ||
    (await exists(path.join(workingDirectory, "cpanfile.snapshot")))
  ) {
    await exec.exec(perl, [...args], execOpt);
  }
  const modules = splitModules(opt.install_modules);
  if (modules.length > 0) {
    await exec.exec(perl, [...args, ...modules], execOpt);
  }
}

async function installWithCarton(opt: Options): Promise<void> {
  const perl = path.join(opt.toolPath, "bin", "perl");
  const carton = path.join(__dirname, "..", "bin", "carton");
  const workingDirectory = path.join(process.cwd(), opt.working_directory || ".");
  const execOpt = {
    cwd: workingDirectory,
  };
  const args = [carton, "install"];
  args.push(...splitArgs(opt.install_modules_args));
  if (
    (await exists(path.join(workingDirectory, "cpanfile"))) ||
    (await exists(path.join(workingDirectory, "cpanfile.snapshot")))
  ) {
    await exec.exec(perl, [...args], execOpt);
  }
  const modules = splitModules(opt.install_modules);
  if (modules.length > 0) {
    const cpanm = path.join(__dirname, "..", "bin", "cpanm");
    const args = [cpanm, "--local-lib-contained", "local", "--notest"];
    if (core.isDebug()) {
      args.push("--verbose");
    }
    await exec.exec(perl, [...args, ...modules], execOpt);
  }
}

// getArchName gets the arch name such as x86_64-linux, darwin-thread-multi-2level, etc.
async function getArchName(opt: Options): Promise<string> {
  const perl = path.join(opt.toolPath, "bin", "perl");
  const out = await exec.getExecOutput(perl, ["-MConfig", "-E", "print $Config{archname}"]);
  return out.stdout;
}

async function exists(path: string): Promise<boolean> {
  return new Promise((resolve, reject) => {
    fs.stat(path, (err) => {
      if (err) {
        if (err.code === "ENOENT") {
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

function splitArgs(args: string | null): string[] {
  if (!args) {
    return [];
  }
  args = args.trim();
  if (args === "") {
    return [];
  }
  return args.split(/\s+/);
}

function splitModules(modules: string | null): string[] {
  if (!modules) {
    return [];
  }
  modules = modules.trim();
  if (modules === "") {
    return [];
  }
  return modules.split(/\s+/);
}

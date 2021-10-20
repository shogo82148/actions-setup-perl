// Ports of @actions/tool-cache
// We use hard-coded paths rather than $RUNNER_TOOL_CACHE
// because the prebuilt perl binaries cannot be moved anyway

import * as os from "os";
import * as fs from "fs";
import * as path from "path";
import * as core from "@actions/core";
import * as io from "@actions/io";
import * as semver from "semver";

// Finds the path to a tool version in the local installed tool cache
export function find(toolName: string, versionSpec: string, arch?: string): string {
  if (!toolName) {
    throw new Error("toolName parameter is required");
  }

  if (!versionSpec) {
    throw new Error("versionSpec parameter is required");
  }

  arch = arch || os.arch();
  versionSpec = semver.clean(versionSpec) || "";
  const cachePath = path.join(_getCacheDirectory(), toolName, versionSpec, arch);

  let toolPath = "";
  core.debug(`checking cache: ${cachePath}`);
  if (fs.existsSync(cachePath) && fs.existsSync(`${cachePath}.complete`)) {
    core.debug(`Found tool in cache ${toolName} ${versionSpec} ${arch}`);
    toolPath = cachePath;
  } else {
    core.debug("not found");
  }
  return toolPath;
}

// Caches a directory and installs it into the tool cacheDir
export async function cacheDir(sourceDir: string, tool: string, version: string, arch?: string): Promise<string> {
  version = semver.clean(version) || version;
  arch = arch || os.arch();
  core.debug(`Caching tool ${tool} ${version} ${arch}`);

  core.debug(`source dir: ${sourceDir}`);
  if (!fs.statSync(sourceDir).isDirectory()) {
    throw new Error("sourceDir is not a directory");
  }

  // Create the tool dir
  const destPath: string = await _createToolPath(tool, version, arch);

  // copy each child item. do not move. move can fail on Windows
  // due to anti-virus software having an open handle on a file.
  for (const itemName of fs.readdirSync(sourceDir)) {
    const s = path.join(sourceDir, itemName);
    await io.cp(s, destPath, { recursive: true });
  }

  // write .complete
  _completeToolPath(tool, version, arch);

  return destPath;
}

async function _createToolPath(tool: string, version: string, arch?: string): Promise<string> {
  const folderPath = path.join(_getCacheDirectory(), tool, semver.clean(version) || version, arch || "");
  core.debug(`destination ${folderPath}`);
  const markerPath = `${folderPath}.complete`;
  await io.rmRF(folderPath);
  await io.rmRF(markerPath);
  await io.mkdirP(folderPath);
  return folderPath;
}

function _completeToolPath(tool: string, version: string, arch?: string): void {
  const folderPath = path.join(_getCacheDirectory(), tool, semver.clean(version) || version, arch || "");
  const markerPath = `${folderPath}.complete`;
  fs.writeFileSync(markerPath, "");
  core.debug("finished caching tool");
}

function _getCacheDirectory(): string {
  if (process.env["ACTIONS_SETUP_PERL_TESTING"]) {
    // for testing
    return process.env["RUNNER_TOOL_CACHE"] || "";
  }
  const platform = os.platform();
  if (platform === "linux") {
    return "/opt/hostedtoolcache";
  } else if (platform === "darwin") {
    return "/Users/runner/hostedtoolcache";
  } else if (platform === "win32") {
    return "C:\\hostedtoolcache\\windows";
  }

  throw new Error(`unknown platform: ${platform}`);
}

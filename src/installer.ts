// Load tempDirectory before it gets wiped by tool-cache
let tempDirectory = process.env['RUNNER_TEMPDIRECTORY'] || '';

import * as core from '@actions/core';
import * as tc from '@actions/tool-cache';
import * as os from 'os';
import * as fs from 'fs';
import * as path from 'path';
import * as semver from 'semver';
import * as yaml from 'js-yaml';

const osPlat = os.platform();
const osArch = os.arch();

if (!tempDirectory) {
  let baseLocation;
  if (process.platform === 'win32') {
    // On windows use the USERPROFILE env variable
    baseLocation = process.env['USERPROFILE'] || 'C:\\';
  } else if (process.platform === 'darwin') {
    baseLocation = '/Users';
  } else {
    baseLocation = '/home';
  }
  tempDirectory = path.join(baseLocation, 'actions', 'temp');
}

interface Workflow {
  jobs: Jobs;
}

interface Jobs {
  build: Job;
}

interface Job {
  strategy: Strategy;
}

interface Strategy {
  matrix: Matrix;
}

interface Matrix {
  perl: string[];
}

async function getAvailableVersions(): Promise<string[]> {
  return new Promise<Workflow>((resolve, reject) => {
    fs.readFile(
      path.join(__dirname, '..', '.github', 'workflows', `${osPlat}.yml`),
      (err, data) => {
        if (err) {
          reject(err);
        }
        const info = yaml.safeLoad(data.toString()) as Workflow;
        resolve(info);
      }
    );
  }).then((info: Workflow) => {
    return info.jobs.build.strategy.matrix.perl;
  });
}

async function determineVersion(version: string): Promise<string> {
  const availableVersions = await getAvailableVersions();

  // stable latest version
  if (version === "latest") {
    return availableVersions[0];
  }

  for (let v of availableVersions) {
    if (semver.satisfies(v, version)) {
      return v;
    }
  }
  throw new Error('unable to get latest version');
}

export async function getPerl(version: string) {
  const selected = await determineVersion(version);

  // check cache
  let toolPath: string;
  toolPath = tc.find('perl', selected);

  if (!toolPath) {
    // download, extract, cache
    toolPath = await acquirePerl(selected);
    core.debug('Perl tool is cached under ' + toolPath);
  }

  toolPath = path.join(toolPath, 'bin');
  //
  // prepend the tools path. instructs the agent to prepend for future tasks
  //
  core.addPath(toolPath);
}

async function acquirePerl(version: string): Promise<string> {
  //
  // Download - a tool installer intimately knows how to get the tool (and construct urls)
  //
  const fileName = getFileName(version);
  const downloadUrl = await getDownloadUrl(fileName);
  let downloadPath: string | null = null;
  try {
    downloadPath = await tc.downloadTool(downloadUrl);
  } catch (error) {
    core.debug(error);

    throw `Failed to download version ${version}: ${error}`;
  }

  //
  // Extract
  //
  let extPath = tempDirectory;
  if (!extPath) {
    throw new Error('Temp directory not set');
  }

  if (osPlat == 'win32') {
    extPath = await tc.extractZip(downloadPath);
  } else {
    extPath = await tc.extractTar(downloadPath);
  }

  return await tc.cacheDir(extPath, 'perl', version);
}

function getFileName(version: string): string {
  return `perl-${version}-${osPlat}-${osArch}.tar.gz`;
}

interface PackageVersion {
  version: string;
}

async function getDownloadUrl(filename: string): Promise<string> {
  return new Promise<PackageVersion>((resolve, reject) => {
    fs.readFile(path.join(__dirname, '..', 'package.json'), (err, data) => {
      if (err) {
        reject(err);
      }
      const info: PackageVersion = JSON.parse(data.toString());
      resolve(info);
    });
  }).then(info => {
    const actionsVersion = info.version;
    return `https://shogo82148-actions-setup-perl.s3.amazonaws.com/v${actionsVersion}/${filename}`;
  });
}

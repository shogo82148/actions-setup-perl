import * as core from '@actions/core';
import * as tc from '@actions/tool-cache';
import * as os from 'os';
import * as fs from 'fs';
import * as path from 'path';
import * as semver from 'semver';

const osPlat = os.platform();
const osArch = os.arch();

async function getAvailableVersions(): Promise<string[]> {
  return new Promise<string[]>((resolve, reject) => {
    fs.readFile(path.join(__dirname, '..', 'versions', `${osPlat}.json`), (err, data) => {
      if (err) {
        reject(err);
      }
      const info = JSON.parse(data.toString()) as string[];
      resolve(info);
    });
  });
}

async function determineVersion(version: string): Promise<string> {
  const availableVersions = await getAvailableVersions();

  // stable latest version
  if (version === 'latest') {
    return availableVersions[0];
  }

  for (let v of availableVersions) {
    if (semver.satisfies(v, version)) {
      return v;
    }
  }
  throw new Error('unable to get latest version');
}

export async function getPerl(version: string, thread: boolean) {
  const selected = await determineVersion(version);

  // check cache
  let toolPath: string;
  toolPath = tc.find('perl', selected);

  if (!toolPath) {
    // download, extract, cache
    toolPath = await acquirePerl(selected, thread);
    core.debug('Perl tool is cached under ' + toolPath);
  }

  const bin = path.join(toolPath, 'bin');
  //
  // prepend the tools path. instructs the agent to prepend for future tasks
  //
  core.addPath(bin);
}

async function acquirePerl(version: string, thread: boolean): Promise<string> {
  //
  // Download - a tool installer intimately knows how to get the tool (and construct urls)
  //
  const fileName = getFileName(version, thread);
  const downloadUrl = await getDownloadUrl(fileName);
  let downloadPath: string | null = null;
  try {
    downloadPath = await tc.downloadTool(downloadUrl);
  } catch (error) {
    core.debug(error);

    throw `Failed to download version ${version}: ${error}`;
  }

  //
  // Extract compressed archive
  //
  const extPath = downloadUrl.endsWith('.zip')
    ? await tc.extractZip(downloadPath)
    : downloadUrl.endsWith('.tar.xz')
    ? await tc.extractTar(downloadPath, '', 'xJ')
    : downloadUrl.endsWith('.tar.bz2')
    ? await tc.extractTar(downloadPath, '', 'xj')
    : await tc.extractTar(downloadPath);
  return await tc.cacheDir(extPath, 'perl', version + (thread ? '-thr' : ''));
}

function getFileName(version: string, thread: boolean): string {
  const suffix = thread ? '-multi-thread' : '';
  const ext = osPlat === 'win32' ? 'zip' : 'tar.xz';
  return `perl-${version}-${osPlat}-${osArch}${suffix}.${ext}`;
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
    return `https://setupperl.blob.core.windows.net/actions-setup-perl/v${actionsVersion}/${filename}`;
  });
}

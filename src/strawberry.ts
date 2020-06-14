// Load tempDirectory before it gets wiped by tool-cache
let tempDirectory = process.env['RUNNER_TEMPDIRECTORY'] || '';

import * as core from '@actions/core';
import * as tc from '@actions/tool-cache';
import * as path from 'path';
import * as semver from 'semver';
import * as installer from './installer';

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

interface PerlVersion {
  version: string;
  path: string;
}

const availableVersions: PerlVersion[] = [
  {
    version: '5.30.0',
    path: 'strawberry-perl-5.30.0.1-64bit-portable.zip'
  }
];

function determineVersion(version: string): PerlVersion {
  for (let v of availableVersions) {
    if (semver.satisfies(v.version, version)) {
      return v;
    }
  }
  throw new Error('unable to get latest version');
}

export async function getPerl(version: string) {
  if (process.platform !== 'win32') {
    core.info('The strawberry distribution is not available on this platform');
    core.info('fallback to the default distribution');
    installer.getPerl(version);
    return;
  }

  // check cache
  const selected = determineVersion(version);
  let toolPath: string;
  toolPath = tc.find('perl', selected.version);

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

async function acquirePerl(version: PerlVersion): Promise<string> {
  //
  // Download - a tool installer intimately knows how to get the tool (and construct urls)
  //

  // download from a mirror for actions-setup-perl
  const downloadUrl = `https://shogo82148-actions-setup-perl.s3.amazonaws.com/strawberry-perl/${version.path}`;
  let downloadPath: string | null = null;
  try {
    downloadPath = await tc.downloadTool(downloadUrl);
  } catch (error) {
    core.debug(error);

    throw `Failed to download version ${version.version}: ${error}`;
  }

  //
  // Extract
  //
  let extPath = tempDirectory;
  if (!extPath) {
    throw new Error('Temp directory not set');
  }

  extPath = await tc.extractZip(downloadPath);
  return await tc.cacheDir(extPath, 'perl', version.version);
}

"use strict";
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (Object.hasOwnProperty.call(mod, k)) result[k] = mod[k];
    result["default"] = mod;
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
// Load tempDirectory before it gets wiped by tool-cache
let tempDirectory = process.env['RUNNER_TEMPDIRECTORY'] || '';
const core = __importStar(require("@actions/core"));
const tc = __importStar(require("@actions/tool-cache"));
const os = __importStar(require("os"));
const path = __importStar(require("path"));
const semver = __importStar(require("semver"));
const actionVersion = 'v0.0.1';
const osPlat = os.platform();
const osArch = os.arch();
if (!tempDirectory) {
    let baseLocation;
    if (process.platform === 'win32') {
        // On windows use the USERPROFILE env variable
        baseLocation = process.env['USERPROFILE'] || 'C:\\';
    }
    else if (process.platform === 'darwin') {
        baseLocation = '/Users';
    }
    else {
        baseLocation = '/home';
    }
    tempDirectory = path.join(baseLocation, 'actions', 'temp');
}
const availableVersions = [
    '5.30.0',
    '5.28.2',
    '5.28.1',
    '5.28.0',
    '5.26.3',
    '5.26.2',
    '5.26.1',
    '5.26.0'
];
function determineVersion(version) {
    for (let v of availableVersions) {
        if (semver.satisfies(v, version)) {
            return v;
        }
    }
    throw new Error('unable to get latest version');
}
async function getPerl(version) {
    const selected = determineVersion(version);
    // check cache
    let toolPath;
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
exports.getPerl = getPerl;
async function acquirePerl(version) {
    //
    // Download - a tool installer intimately knows how to get the tool (and construct urls)
    //
    const fileName = getFileName(version);
    const downloadUrl = getDownloadUrl(fileName);
    let downloadPath = null;
    try {
        downloadPath = await tc.downloadTool(downloadUrl);
    }
    catch (error) {
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
    }
    else {
        extPath = await tc.extractTar(downloadPath);
    }
    return await tc.cacheDir(extPath, 'perl', version);
}
function getFileName(version) {
    return `perl-${version}-${osPlat}-${osArch}.tar.gz`;
}
function getDownloadUrl(filename) {
    return `https://shogo82148-actions-setup-perl.s3.amazonaws.com/${actionVersion}/${filename}`;
}

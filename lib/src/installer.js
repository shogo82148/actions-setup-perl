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
const actionVersion = 'v0.0.1-alpha';
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
async function getPerl(version) {
    await acquirePerl(version);
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
    const toolRoot = path.join(extPath, 'go');
    return await tc.cacheDir(toolRoot, 'perl', version);
}
function getFileName(version) {
    return `perl-${version}-${osPlat}-${osArch}.tar.gz`;
}
function getDownloadUrl(filename) {
    return `https://github.com/shogo82148/actions-setup-perl/releases/download/${actionVersion}/${filename}`;
}

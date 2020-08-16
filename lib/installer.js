"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getPerl = void 0;
// Load tempDirectory before it gets wiped by tool-cache
let tempDirectory = process.env['RUNNER_TEMPDIRECTORY'] || '';
const core = __importStar(require("@actions/core"));
const tc = __importStar(require("@actions/tool-cache"));
const os = __importStar(require("os"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const semver = __importStar(require("semver"));
const yaml = __importStar(require("js-yaml"));
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
async function getAvailableVersions() {
    return new Promise((resolve, reject) => {
        fs.readFile(path.join(__dirname, '..', '.github', 'workflows', `${osPlat}.yml`), (err, data) => {
            if (err) {
                reject(err);
            }
            const info = yaml.safeLoad(data.toString());
            resolve(info);
        });
    }).then((info) => {
        return info.jobs.build.strategy.matrix.perl;
    });
}
async function determineVersion(version) {
    const availableVersions = await getAvailableVersions();
    for (let v of availableVersions) {
        if (semver.satisfies(v, version)) {
            return v;
        }
    }
    throw new Error('unable to get latest version');
}
async function getPerl(version) {
    const selected = await determineVersion(version);
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
    const downloadUrl = await getDownloadUrl(fileName);
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
async function getDownloadUrl(filename) {
    return new Promise((resolve, reject) => {
        fs.readFile(path.join(__dirname, '..', 'package.json'), (err, data) => {
            if (err) {
                reject(err);
            }
            const info = JSON.parse(data.toString());
            resolve(info);
        });
    }).then(info => {
        const actionsVersion = info.version;
        return `https://shogo82148-actions-setup-perl.s3.amazonaws.com/v${actionsVersion}/${filename}`;
    });
}

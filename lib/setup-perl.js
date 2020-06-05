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
    if (mod != null) for (var k in mod) if (Object.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
const core = __importStar(require("@actions/core"));
const installer = __importStar(require("./installer"));
const path = __importStar(require("path"));
async function run() {
    try {
        const version = core.getInput('perl-version');
        if (version) {
            await installer.getPerl(version);
        }
        const matchersPath = path.join(__dirname, '..', '.github');
        console.log(`##[add-matcher]${path.join(matchersPath, 'perl.json')}`);
        // for cpanm and carton
        core.addPath(path.join(__dirname, '..', 'bin'));
    }
    catch (error) {
        core.setFailed(error.message);
    }
}
run();

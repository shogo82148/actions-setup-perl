"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
async function getPerl(version) {
    await acquirePerl(version);
}
exports.getPerl = getPerl;
async function acquirePerl(version) {
    //
    // Download - a tool installer intimately knows how to get the tool (and construct urls)
    //
}

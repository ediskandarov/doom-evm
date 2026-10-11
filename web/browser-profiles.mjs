// SPDX-License-Identifier: GPL-2.0-only
// One deployment manager; profiles select authenticated releases and packing only.
import {BrowserInstaller} from './install-engine.mjs';
import {PROFILES,prepareResources} from './install-resources.mjs';
import {DOOM2_PROFILE,prepareDoom2Resources} from './doom2-profile.mjs';
import {Doom2BrowserInstaller} from './doom2-install.mjs';
export const GAME_PROFILES=Object.freeze([PROFILES[0],PROFILES[1],DOOM2_PROFILE]);
export function createGameInstaller(profile,options={}){
 if(!GAME_PROFILES.includes(profile))throw Error('Unknown game profile');
 return profile===DOOM2_PROFILE?new Doom2BrowserInstaller(options):new BrowserInstaller(options);
}
export function prepareGameResources(bytes,profile){
 if(!GAME_PROFILES.includes(profile))throw Error('Unknown game profile');
 return profile===DOOM2_PROFILE?prepareDoom2Resources(bytes):prepareResources(bytes,profile);
}

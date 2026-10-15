// Publishes the current game as an online update (no reinstall needed on the phones).
// Run from the project folder:  node tools/release.mjs
// It builds the game with a new version number, zips it, uploads the zip as a GitHub release
// of the updates repository, and points the app's latest.json at it. Phones pick it up next time the app opens.
//
// Channels (each app reads its own latest.json, see UPDATE_URL in game/src/config.js):
//   birthday/latest.json  the birthday app (com.jananijanika.gracy): normal updates go here
//   latest.json           the old test app (com.gracy.adventurer): retired with --retire-old
//
// node tools/release.mjs --retire-old   sends every old test copy the "this version has ended" screen
import { execSync } from 'node:child_process';
import { writeFileSync, mkdirSync, existsSync, rmSync } from 'node:fs';

const REPO = 'gowtham11112007/gracy-the-adventurer-updates';
const retire = process.argv.includes('--retire-old');
const channelFile = retire ? 'latest.json' : 'birthday/latest.json';
const run = (cmd, opts = {}) => execSync(cmd, { stdio: 'inherit', ...opts });
const version = `1.0.${Math.floor(Date.now() / 60000)}`;
const tag = `${retire ? 'retired' : 'v'}${version}`;

run('npx vite build', { cwd: 'game', env: { ...process.env, GAME_VERSION: version, GAME_RETIRED: retire ? '1' : '' } });
const zip = `/tmp/gracy-${tag}.zip`;
run(`cd game/dist && rm -f ${zip} && zip -qr ${zip} .`);
run(`gh release create ${tag} ${zip} --repo ${REPO} --title "${tag}" --notes "${retire ? 'Retires the old test app' : `Game update ${version}`}"`);

// latest.json lives in the repository itself, served by raw.githubusercontent.com
const dir = '/tmp/gracy-updates-repo';
if (existsSync(dir)) rmSync(dir, { recursive: true });
run(`gh repo clone ${REPO} ${dir}`);
mkdirSync(`${dir}/birthday`, { recursive: true });
const url = `https://github.com/${REPO}/releases/download/${tag}/gracy-${tag}.zip`;
writeFileSync(`${dir}/${channelFile}`, JSON.stringify({ version, url }, null, 2) + '\n');
run(`git -C ${dir} add -A && git -C ${dir} commit -qm "${retire ? 'Retire old app' : 'Update'} ${version}" && git -C ${dir} push -q`);
console.log(`\nPublished ${tag} to ${channelFile}. Phones will download it next time the game opens with internet.`);
if (retire) execSync('npx vite build', { cwd: 'game', stdio: 'ignore' }); // leave a normal build in game/dist

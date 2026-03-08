import * as cmd from '../cmd.js';

const helpLines = cmd.cmdHelpText().trim().split('\n');

console.log(helpLines.slice(0, 4).join('\n'));
console.log(`version: ${cmd.cmdVersionText()}`);

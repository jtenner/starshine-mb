import * as wast from '../wast.js';
import { expectOk } from './_shared.mjs';

const script = expectOk(
  wast.wastToScript('(module (func (export "run")))', 'inline-script.wast'),
  'wast.wastToScript',
);
const text = expectOk(wast.scriptToWast(script), 'wast.scriptToWast');

console.log(text.trim());

import * as wast from '../wast.js';
import { expectOk } from './_shared.mjs';

const mod = expectOk(
  wast.wastToModule('(module (func (export "run")))', 'inline-module.wast'),
  'wast.wastToModule',
);
const text = expectOk(wast.moduleToWast(mod), 'wast.moduleToWast');

console.log(text.trim());

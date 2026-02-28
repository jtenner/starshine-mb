import * as cli from '../cli.js';
import { printJson } from './_shared.mjs';

const schema = JSON.parse(cli.cliConfigSchemaJson());
const inferredFormat = cli.inferInputFormat('demo.wast');

printJson('cli helpers', {
  schemaKeys: Object.keys(schema),
  normalizedPath: cli.normalizeCliPath('./examples/../demo.wat'),
  inferredFormat: inferredFormat === null ? null : cli.CliInputFormat.show(inferredFormat),
  globMatch: cli.globMatch('examples/*.wat', 'examples/demo.wat'),
});

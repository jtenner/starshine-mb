// Only the isolated deadline regression test invokes this file.
import { runNodeExportInvocationMatrix } from "../pass-fuzz-compare-task.ts";
const reports = await runNodeExportInvocationMatrix(process.argv[2], process.argv[2]);
process.stdout.write(JSON.stringify(reports));

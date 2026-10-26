import subprocess,shlex,pathlib,os,json,hashlib,sys
root=pathlib.Path(sys.argv[1]); package=sys.argv[2]
for arm in ['baseline','candidate']:
 cwd=root/arm
 result=subprocess.run(['moon','bench','--dry-run','--target','native','--release','--warn-list','-a','--package','jtenner/starshine/'+package,'--file',f'daybreak19_{root.name.lower()}_perf_wbtest.mbt','--index','0'],cwd=cwd,capture_output=True,text=True)
 (root/f'link-{arm}-dryrun.stdout').write_text(result.stdout);(root/f'link-{arm}-dryrun.stderr').write_text(result.stderr)
 assert result.returncode==0,result.stderr
 lines=[x for x in result.stdout.splitlines() if x.startswith('/usr/bin/cc -o ') and x.split(' -o ')[1].split(' ')[0].endswith(f'{package}.whitebox_test.exe')]
 assert len(lines)==1,lines
 cmd=[x.replace('$MOON_HOME','/home/dev/.moon') for x in shlex.split(lines[0])]
 dest=root/f'alloc-link-{arm}';dest.mkdir(exist_ok=True)
 import shutil
 original=next(x for x in cmd if '/libruntime-' in x)
 archive=dest/pathlib.Path(original).name;shutil.copyfile(cwd/original,archive)
 shutil.copyfile('/tmp/daybreak19/runtime-count.o',dest/'runtime-runtime.o')
 subprocess.run(['ar','r',str(archive),str(dest/'runtime-runtime.o')],check=True)
 cmd=[str(archive) if x==original else x for x in cmd]
 generated=next(x for x in cmd if x.endswith('.whitebox_test.c'))
 measured_c=dest/'instrumented.c'
 source=(cwd/generated).read_text();needle='#include "moonbit_runtime.h"';assert source.count(needle)==1
 source=source.replace(needle,needle+'\nextern void *db19_counted_alloc(size_t);\n#undef MOONBIT_MALLOC_RAW\n#define MOONBIT_MALLOC_RAW db19_counted_alloc\n')
 measured_c.write_text(source)
 cmd=[str(measured_c) if x==generated else x for x in cmd]

 output=cmd[cmd.index('-o')+1];cmd[cmd.index('-o')+1]=output[:-4]+'.alloc.exe'
 with (root/f'link-{arm}.stdout').open('w') as out,(root/f'link-{arm}.stderr').open('w') as err: result=subprocess.run(cmd,cwd=cwd,stdout=out,stderr=err)
 (root/f'link-{arm}.json').write_text(json.dumps({'command':cmd,'cwd':str(cwd),'exit_code':result.returncode},indent=2)+'\n')
 assert result.returncode==0
 print(arm,cmd[cmd.index('-o')+1],flush=True)

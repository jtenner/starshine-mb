import subprocess,shlex,pathlib,os,json,hashlib,sys,datetime
from concurrent.futures import ThreadPoolExecutor
root=pathlib.Path(sys.argv[1]); package=sys.argv[2];jobs=[]
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
 jobs.append((arm,cmd,cwd,measured_c))

def compile_one(job):
 arm,cmd,cwd,measured_c=job
 record={'command':cmd,'cwd':str(cwd),'state':'running','compiler_parallelism':2,'start':datetime.datetime.now(datetime.timezone.utc).isoformat(),'instrumented_c_sha256':hashlib.sha256(measured_c.read_bytes()).hexdigest(),'counter_object_sha256':hashlib.sha256(pathlib.Path('/tmp/daybreak19/runtime-count.o').read_bytes()).hexdigest()}
 path=root/f'link-{arm}.json';path.write_text(json.dumps(record,indent=2)+'\n')
 with (root/f'link-{arm}.stdout').open('w') as out,(root/f'link-{arm}.stderr').open('w') as err: result=subprocess.run(cmd,cwd=cwd,stdout=out,stderr=err)
 record.update(state='exited',exit_code=result.returncode,end=datetime.datetime.now(datetime.timezone.utc).isoformat());path.write_text(json.dumps(record,indent=2)+'\n')
 return arm,result.returncode,cmd[cmd.index('-o')+1]

# Moon commands and archive/C preparation above are serial. Only two independent
# native compiler invocations run together; await both before any timing starts.
with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(compile_one,jobs))
for arm,code,output in results:print(arm,output,'exit',code,flush=True)
assert all(code==0 for _,code,_ in results),results

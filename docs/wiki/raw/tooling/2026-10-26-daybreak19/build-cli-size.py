from pathlib import Path
import json,subprocess,hashlib,sys,os,datetime
r=Path('/tmp/daybreak19')/sys.argv[1];d={'scope':'Production native release CLI; benchmark source and wbtest imports are excluded from this build','phases':[],'arms':{}}
for arm in ['baseline','candidate']:
 cwd=r/arm;assert not subprocess.check_output(['git','status','--porcelain'],cwd=cwd,text=True);head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=cwd,text=True).strip();cmd=['moon','build','--target','native','--release','--warn-list','-a','src/cmd'];phase={'arm':arm,'command':cmd,'head':head,'start':datetime.datetime.now(datetime.timezone.utc).isoformat()};d['phases'].append(phase);(r/'code-size-build.json').write_text(json.dumps(d,indent=2)+'\n');print('CLI build',arm,'starting',flush=True)
 with (r/(arm+'-cli-build.stdout')).open('w') as out,(r/(arm+'-cli-build.stderr')).open('w') as err:p=subprocess.run(cmd,cwd=cwd,stdout=out,stderr=err,env={**os.environ,'RAYON_NUM_THREADS':'1','TOKIO_WORKER_THREADS':'1'})
 phase.update(exit_code=p.returncode,end=datetime.datetime.now(datetime.timezone.utc).isoformat());(r/'code-size-build.json').write_text(json.dumps(d,indent=2)+'\n');assert p.returncode==0,(arm,p.returncode)
 binary=cwd/'_build/native/release/build/cmd/cmd.exe';assert binary.is_file();size=subprocess.check_output(['size',str(binary)],text=True);values=size.splitlines()[-1].split();d['arms'][arm]={'head':head,'binary':str(binary),'sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'file_bytes':binary.stat().st_size,**dict(zip(['text_bytes','data_bytes','bss_bytes'],map(int,values[:3]))),'size_stdout':size};print('CLI build',arm,'exit zero',flush=True)
for k in ['file_bytes','text_bytes','data_bytes','bss_bytes']:d[k+'_delta']=d['arms']['candidate'][k]-d['arms']['baseline'][k]
d['text_delta_percent']=100*(d['arms']['candidate']['text_bytes']/d['arms']['baseline']['text_bytes']-1);(r/'code-size.json').write_text(json.dumps(d,indent=2)+'\n');print(json.dumps(d,indent=2))

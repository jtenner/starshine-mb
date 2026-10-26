import pathlib,json,subprocess,sys,os,datetime
item=sys.argv[1];stage=sys.argv[2];root=pathlib.Path('/tmp/daybreak19')/item;count=str(len(json.loads((root/'cases.json').read_text())));file=f'daybreak19_{item.lower()}_perf_wbtest.mbt';pkg='jtenner/starshine/daybreak19_measure'
choices={
'build':[(f'build-{a}',['moon','bench','--build-only','--target','native','--release','--warn-list','-a','--package',pkg,'--file',file],root/a) for a in ['baseline','candidate']],
'round1':[('runtime-round1',['python3','/tmp/daybreak19/sample.py',str(root),'daybreak19_measure',count,'paired','round1'],root),('evaluate-round1',['python3','/tmp/daybreak19/round1.py',str(root)],root)],
'finish':[('runtime',['python3','/tmp/daybreak19/sample.py',str(root),'daybreak19_measure',count],root),('build-allocation',['python3','/tmp/daybreak19/link-allocation.py',str(root),'daybreak19_measure'],root),('allocation',['python3','/tmp/daybreak19/sample.py',str(root),'daybreak19_measure',count,'allocation-v2'],root),('aggregate',['python3','/tmp/daybreak19/aggregate.py',str(root)],root)]}
if stage=='round1':
 import shutil
 shutil.copyfile('/tmp/daybreak19/sample.py',root/'sample-used.py')
p=root/'controller.json';record=json.loads(p.read_text()) if p.exists() else {'phases':[]};record.update(controller_pid=os.getpid(),state='running',stage=stage)
for name,cmd,cwd in choices[stage]:
 entry={'phase':name,'command':cmd,'cwd':str(cwd),'state':'running','start':datetime.datetime.now(datetime.timezone.utc).isoformat()};record['phases'].append(entry);p.write_text(json.dumps(record,indent=2)+'\n');print(name,'starting',flush=True)
 with (root/(name+'-phase.stdout')).open('w') as out,(root/(name+'-phase.stderr')).open('w') as err:r=subprocess.run(cmd,cwd=cwd,stdout=out,stderr=err)
 entry.update(state='exited',exit_code=r.returncode,end=datetime.datetime.now(datetime.timezone.utc).isoformat());record['state']='failed' if r.returncode else 'running';p.write_text(json.dumps(record,indent=2)+'\n');print(name,'exit',r.returncode,flush=True)
 if r.returncode:sys.exit(r.returncode)
record['state']='complete' if stage=='finish' else stage+'-complete';p.write_text(json.dumps(record,indent=2)+'\n')

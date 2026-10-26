from pathlib import Path
import os,sys,json,subprocess,hashlib,resource,re,datetime
item=sys.argv[1];arm=sys.argv[2] if len(sys.argv)>2 else 'candidate';root=Path('/tmp/daybreak19')/item;cwd=root/arm;assert cwd.is_dir()
bun=Path('/tmp/dae-gate-investigation/actual-bun.txt').read_text().strip();assert Path(bun).is_file()
oracle=subprocess.check_output(['mise','which','wasm-opt'],text=True).strip();assert Path(oracle).is_file();version=subprocess.check_output([oracle,'--version'],text=True).strip();assert 'version 133 ' in version
oracle_hash=hashlib.sha256(Path(oracle).read_bytes()).hexdigest();assert oracle_hash=='8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b'
assert subprocess.check_output(['git','status','--porcelain'],cwd=cwd,text=True)==''
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=cwd,text=True).strip();(cwd/'.tmp').mkdir(exist_ok=True)
env={**os.environ,'PATH':str(Path(oracle).parent)+':'+str(Path(bun).parent)+':'+os.environ['PATH'],'DAYBREAK19_ORACLE':oracle,'RAYON_NUM_THREADS':'1','TOKIO_WORKER_THREADS':'1'}
soft,hard=resource.getrlimit(resource.RLIMIT_STACK);newsoft=64*1024*1024 if hard==resource.RLIM_INFINITY else min(64*1024*1024,hard);resource.setrlimit(resource.RLIMIT_STACK,(newsoft,hard))
phases=[('native',[bun,'/tmp/daybreak19/native-gate.ts']),('fuzz',[bun,'scripts/fuzz.ts','run','--suite','all','--profile','ci','--target','native','--seed','0x5eed','--output','jsonl','--report-json',str(root/(arm+'-fuzz-report.json'))])]
record={'state':'running','controller_pid':os.getpid(),'arm':arm,'head':head,'cwd':str(cwd),'source_status':'','oracle':oracle,'oracle_version':version,'oracle_sha256':oracle_hash,'stack_limit':resource.getrlimit(resource.RLIMIT_STACK),'environment':{k:env[k] for k in ['PATH','RAYON_NUM_THREADS','TOKIO_WORKER_THREADS']},'phases':[]};dest=root/(arm+'-gates.json')
for name,cmd in phases:
 phase={'name':name,'command':cmd,'state':'running','start':datetime.datetime.now(datetime.timezone.utc).isoformat()};record['phases'].append(phase);dest.write_text(json.dumps(record,indent=2)+'\n');print(name,'starting',flush=True)
 with (root/f'{arm}-{name}.stdout').open('w') as out,(root/f'{arm}-{name}.stderr').open('w') as err:p=subprocess.run(cmd,cwd=cwd,env=env,stdout=out,stderr=err)
 data=(root/f'{arm}-{name}.stdout').read_text(errors='replace')+(root/f'{arm}-{name}.stderr').read_text(errors='replace');phase.update(state='exited',exit_code=p.returncode,end=datetime.datetime.now(datetime.timezone.utc).isoformat())
 if name=='native':
  batches=[dict(zip(['total','passed','failed'],map(int,x))) for x in re.findall(r'Total tests: (\d+), passed: (\d+), failed: (\d+)\.',data)];phase['batches']=batches;phase['total']=sum(x['total'] for x in batches)
  if p.returncode==0:assert len(batches)>=8 and phase['total']>=15522 and all(x['failed']==0 and x['total']==x['passed'] for x in batches),batches
 else:
  report_path=root/(arm+'-fuzz-report.json')
  if report_path.exists():
   report=json.loads(report_path.read_text());phase.update(suites=report.get('run_count'),attempts=report.get('summary',{}).get('total_attempts'),base_seed=report.get('base_seed'))
   if p.returncode==0:assert report['pass'] and report['run_count']==len(report['runs'])==14 and all(x['pass'] for x in report['runs']) and not report['summary']['failure_classes']
  elif p.returncode==0:raise RuntimeError('Fuzz exited zero without its required report')
 dest.write_text(json.dumps(record,indent=2)+'\n');print(name,'exit',p.returncode,flush=True)
 if p.returncode!=0:record['state']='failed';dest.write_text(json.dumps(record,indent=2)+'\n');raise SystemExit(p.returncode)
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=cwd,text=True).strip()==head
assert subprocess.check_output(['git','status','--porcelain'],cwd=cwd,text=True)==''
record['state']='passed';dest.write_text(json.dumps(record,indent=2)+'\n');print('all gates passed',flush=True)

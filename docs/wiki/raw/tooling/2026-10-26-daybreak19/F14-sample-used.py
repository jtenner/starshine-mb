import os,sys,time,json,hashlib,subprocess,re,pathlib,platform,datetime
root=pathlib.Path(sys.argv[1]).resolve(); selection=sys.argv[2]; count=int(sys.argv[3]); indexes=list(range(count))
label=sys.argv[4] if len(sys.argv)>4 else 'paired'
start_max=65 if int(root.name[1:])>=6 else 60
mode=sys.argv[5] if len(sys.argv)>5 else 'full'
assert mode in ['full','round1']
sensor=pathlib.Path('/sys/class/hwmon/hwmon8/temp1_input'); assert sensor.with_name('temp1_label').read_text().strip()=='Tctl'
def temp(): return int(sensor.read_text())/1000
meta={}
for arm in ['baseline','candidate']:
 cwd=root/arm
 binary=cwd/'_build/native/release/bench'/selection/(selection+'.whitebox_test.exe')
 assert binary.is_file(),binary
 assert subprocess.check_output(['git','status','--porcelain'],cwd=cwd,text=True)==''
 meta[arm]={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=cwd,text=True).strip(),'binary':str(binary),'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'binary_bytes':binary.stat().st_size}
if label.startswith('allocation'):
 for arm in ['baseline','candidate']:
  binary=pathlib.Path(meta[arm]['binary']);binary=binary.with_name(binary.stem+'.alloc.exe')
  meta[arm]['allocation_binary']={'path':str(binary),'sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'bytes':binary.stat().st_size}
meta.update(environment={'uname':platform.uname()._asdict(),'cpu_affinity':[2], 'sensor':str(sensor),'sample_start_max_c':start_max,'mode':mode,'discard_peak_above_c':80,'timing_allocator':'normal MoonBit mimalloc','allocation_scope':'separate instrumented raw allocator in generated C and runtime; whole-process counts divided by callback count; headers/fixture/runner overhead included','allocation_counter_runtime_sha256':hashlib.sha256(pathlib.Path('/tmp/daybreak19/runtime-count.c').read_bytes()).hexdigest()})
meta['measurement_tools']={name:hashlib.sha256(pathlib.Path('/tmp/daybreak19',name).read_bytes()).hexdigest() for name in ['sample.py','link-allocation.py','runtime-count.c','rss-run.c','rss-run']}
meta['cases_sha256']=hashlib.sha256((root/'cases.json').read_bytes()).hexdigest()
meta['harness_sha256']=hashlib.sha256((root/'harness.mbt').read_bytes()).hexdigest()
(root/('provenance-'+label+'.json')).write_text(json.dumps(meta,indent=2)+'\n')
# Balanced paired rounds, then two same-build pairs for each arm.
orders=[('pair1','baseline'),('pair1','candidate'),('pair2','candidate'),('pair2','baseline'),('pair3','baseline'),('pair3','candidate'),('AA1','baseline'),('AA2','baseline'),('BB1','candidate'),('BB2','candidate')]
if mode=='round1':orders=[x for x in orders if x[0] in ['pair1','AA1','AA2','BB1','BB2']]
# Allocation samples use the same paired rounds and same-build controls.
log=root/(label+'.jsonl')
completed=set()
if log.exists():
 for line in log.read_text().splitlines():
  r=json.loads(line)
  if r.get('accepted'):completed.add((r['index'],r['round'],r['arm']))
case_specs=json.loads((root/'cases.json').read_text()) if (root/'cases.json').exists() else [{} for _ in indexes]
for index in indexes:
 for round_,arm in orders:
  if (root/'STOP').exists():raise SystemExit('Stopped after completed sample')
  if (index,round_,arm) in completed:continue
  for attempt in range(6):
   while temp()>start_max:
    if (root/'STOP').exists():raise SystemExit('Stopped while cooling; no sample started')
    time.sleep(1)
   if (root/'STOP').exists():raise SystemExit('Stopped before sample launch')
   binary=pathlib.Path(meta[arm]['binary'])
   if label.startswith('allocation'):binary=binary.with_name(binary.stem+'.alloc.exe')
   cmd=['/tmp/daybreak19/rss-run','taskset','-c','2',str(binary),f'daybreak19_{root.name.lower()}_perf_wbtest.mbt:{index}-{index+1}']
   stamp=f'{label}-{index:02}-{round_}-{arm}-{attempt}'
   wall_start=datetime.datetime.now(datetime.timezone.utc).isoformat()
   start=temp()
   while start>start_max:
    if (root/'STOP').exists():raise SystemExit('Stopped at final launch gate; no sample started')
    time.sleep(1);start=temp()
   peak=start
   with (root/(stamp+'.stdout')).open('w') as out,(root/(stamp+'.stderr')).open('w') as err:
    p=subprocess.Popen(cmd,stdout=out,stderr=err,cwd=root/arm,env={**os.environ,'RAYON_NUM_THREADS':'1','TOKIO_WORKER_THREADS':'1'})
    while True:
     pid,status,usage=os.wait4(p.pid,os.WNOHANG)
     if pid:
      p.returncode=os.waitstatus_to_exitcode(status)
      break
     peak=max(peak,temp());time.sleep(.02)
   data=(root/(stamp+'.stdout')).read_text(); stderr=(root/(stamp+'.stderr')).read_text()
   if p.returncode != 0:
    failure=dict(index=index,round=round_,arm=arm,attempt=attempt,command=cmd,exit_code=p.returncode,start_c=start,peak_c=peak,accepted=False,stdout=stamp+'.stdout',stderr=stamp+'.stderr')
    with log.open('a') as stream:stream.write(json.dumps(failure)+'\n')
    raise SystemExit('Sample subprocess failed; see preserved stdout/stderr and exit code')
   result=[json.loads(x) for x in data.splitlines() if x.startswith('{') and '"type":"result"' in x]
   assert len(result)==1,(cmd,data,stderr)
   message=result[0]['message'];assert message.startswith('@BATCH_BENCH '),(cmd,data,stderr)
   summary=json.loads(message[len('@BATCH_BENCH '):])['summaries'][0]
   callbacks=int(re.search(r'DB19_CALLBACKS=(\d+)',data)[1])
   launch_rss=usage.ru_maxrss
   native_rss=re.search(r'DB19_NATIVE_RSS_KIB=(\d+)',stderr)
   assert native_rss, 'Native RSS launcher did not return its completed-child measurement'
   rss=int(native_rss[1])
   small_launcher_rss=int(re.search(r'DB19_SMALL_LAUNCHER_RSS_KIB=(\d+)',stderr)[1])
   alloc=re.search(r'DB19_ALLOC=(\{.*\})',stderr)
   record=dict(index=index,round=round_,arm=arm,attempt=attempt,command=cmd,exit_code=p.returncode,wall_start=wall_start,wall_end=datetime.datetime.now(datetime.timezone.utc).isoformat(),start_c=start,peak_c=peak,accepted=p.returncode==0 and peak<=80,summary=summary,callbacks=callbacks,peak_rss_kib=rss,python_child_kernel_peak_kib=launch_rss,small_launcher_current_rss_kib=small_launcher_rss,peak_rss_scope='target child from small native launcher',stdout=stamp+'.stdout',stderr=stamp+'.stderr')
   if alloc:record['allocation']=json.loads(alloc[1]);record['alloc_calls_per_callback']=record['allocation']['calls']/callbacks;record['alloc_bytes_per_callback']=record['allocation']['bytes']/callbacks
   if label.startswith('allocation') and case_specs[index].get('allocation_sanity_check',index==0):
    minimum=case_specs[index].get('min_allocations_per_callback',256) if (root/'cases.json').exists() else 256
    assert record.get('alloc_calls_per_callback',0)>minimum, 'Counter misses known per-callback allocations'
   with log.open('a') as stream:stream.write(json.dumps(record)+'\n');stream.flush();os.fsync(stream.fileno())
   print(json.dumps(record),flush=True)
   if record['accepted']:break
  else:raise SystemExit('Repeated bad thermal samples; stop and park batch')

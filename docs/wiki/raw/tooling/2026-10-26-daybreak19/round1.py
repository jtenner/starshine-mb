import pathlib,json,statistics,sys,re
root=pathlib.Path(sys.argv[1]);cases=json.loads((root/'cases.json').read_text());raw=[json.loads(x) for x in (root/'paired.jsonl').read_text().splitlines()];rows=[]
for i,case in enumerate(cases):
 samples=[x for x in raw if x['index']==i and x.get('accepted')];row={'index':i,**case};assert all(sum(x['round']==r for x in samples)==n for r,n in [('pair1',2),('AA1',1),('AA2',1),('BB1',1),('BB2',1)])
 for arm in ['baseline','candidate']:
  a=[x for x in samples if x['arm']==arm]
  pair=next(x for x in a if x['round']=='pair1');row[arm+'_us']=pair['summary']['median'];row[arm+'_peak_rss_kib']=pair['peak_rss_kib']
  c=sorted([x for x in a if x['round']!='pair1'],key=lambda x:x['round']);row[arm+'_same_build_delta_percent']=100*(c[1]['summary']['median']/c[0]['summary']['median']-1)
  for x in a:
   output=(root/x['stdout']).read_text();expected=case.get(arm+'_expected_validation_accepted')
   if expected is not None:assert f'DB19_VALIDATION_ACCEPTED={str(expected).lower()}' in output
   error=case.get(arm+'_expected_validation_error_contains')
   if error:assert error in output
   value=case.get(arm+'_expected_first_i32')
   if value is not None:assert int(re.search(r'DB19_FIRST_I32=(-?\d+)',output)[1])==value
 row['us_delta_percent']=100*(row['candidate_us']/row['baseline_us']-1);rows.append(row)
valid=[x for x in rows if x.get('comparable',True)];loss=statistics.median(x['us_delta_percent'] for x in valid);drift=max(abs(x[a+'_same_build_delta_percent']) for x in valid for a in ['baseline','candidate']);stop=all(x['us_delta_percent']>0 for x in valid) and loss>10 and drift<loss/3
result={'rows':rows,'early_stop':stop,'comparable_median_loss_percent':loss,'maximum_absolute_control_drift_percent':drift,'control_small_rule':'maximum absolute drift < one third of median loss','runtime_samples_accepted':sum(x.get('accepted',False) for x in raw),'maximum_sample_start_c':max(x['start_c'] for x in raw),'maximum_sample_peak_c':max(x['peak_c'] for x in raw if x.get('accepted'))}
(root/'round1-summary.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

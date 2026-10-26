import pathlib,json,statistics,sys,re
root=pathlib.Path(sys.argv[1]);label=sys.argv[2] if len(sys.argv)>2 else 'paired';cases=json.loads((root/'cases.json').read_text());raw=[json.loads(x) for x in (root/(label+'.jsonl')).read_text().splitlines()];rows=[]
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
   expected_changes=case.get(arm+'_expected_change_count')
   if expected_changes is not None:assert int(re.search(r'DB19_DIFF_COUNT=(\d+)',output)[1])==expected_changes,(arm,'wrong diff change count')
   paths=case.get(arm+'_expected_paths_preserved')
   if paths is not None:assert f'DB19_PATHS_PRESERVED={str(paths).lower()}' in output,(arm,'path preservation mismatch')
   equal=case.get(arm+'_expected_equal_result')
   if equal is not None:assert f'DB19_EQUAL_RESULT={str(equal).lower()}' in output,(i,arm,'wrong equality result')
   if case.get('expected_inputs_unchanged'):assert 'DB19_INPUTS_UNCHANGED=true' in output,(i,arm,'input mutation')
   names=case.get(arm+'_expected_utf8_names_preserved')
   if names is not None:assert f'DB19_UTF8_NAMES_PRESERVED={str(names).lower()}' in output,(i,arm,'wrong UTF-8 names')
   if 'expected_import_count' in case:assert int(re.search(r'DB19_IMPORT_COUNT=(\d+)',output)[1])==case['expected_import_count'],(i,arm,'wrong import count')
   groups=case.get(arm+'_expected_group_layout_preserved')
   if groups is not None:assert f'DB19_GROUP_LAYOUT_PRESERVED={str(groups).lower()}' in output,(i,arm,'unexpected group layout')
   roundtrip=case.get(arm+'_expected_roundtrip_preserved')
   if roundtrip is not None:assert f'DB19_ROUNDTRIP_PRESERVED={str(roundtrip).lower()}' in output,(i,arm,'unexpected roundtrip')
   value=case.get(arm+'_expected_first_i32')
   if value is not None:assert int(re.search(r'DB19_FIRST_I32=(-?\d+)',output)[1])==value
 row['us_delta_percent']=100*(row['candidate_us']/row['baseline_us']-1);rows.append(row)
valid=[x for x in rows if x.get('comparable',True)];loss=statistics.median(x['us_delta_percent'] for x in valid);drift=max(abs(x[a+'_same_build_delta_percent']) for x in valid for a in ['baseline','candidate']);stop=all(x['us_delta_percent']>0 for x in valid) and loss>10 and drift<loss/3
result={'rows':rows,'early_stop':stop,'comparable_median_loss_percent':loss,'maximum_absolute_control_drift_percent':drift,'control_small_rule':'maximum absolute drift < one third of median loss','runtime_samples_accepted':sum(x.get('accepted',False) for x in raw),'maximum_sample_start_c':max(x['start_c'] for x in raw),'maximum_sample_peak_c':max(x['peak_c'] for x in raw if x.get('accepted'))}
(root/('round1-summary.json' if label=='paired' else label+'-round1-summary.json')).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

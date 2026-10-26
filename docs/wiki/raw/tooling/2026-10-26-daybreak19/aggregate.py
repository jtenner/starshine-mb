import pathlib,json,statistics,re,sys
root=pathlib.Path(sys.argv[1]);cases=json.loads((root/'cases.json').read_text())
raw=[json.loads(x) for x in (root/'paired.jsonl').read_text().splitlines()];allocation=[json.loads(x) for x in (root/'allocation-v2.jsonl').read_text().splitlines()];memory=[json.loads(x) for x in (root/'memory-v2.jsonl').read_text().splitlines()] if (root/'memory-v2.jsonl').exists() else [];rows=[]
for index,case in enumerate(cases):
 samples=[x for x in raw if x['index']==index and x.get('accepted')];counted=[x for x in allocation if x['index']==index and x.get('accepted')];assert len(samples)==len(counted)==10,(index,len(samples),len(counted))
 row={'index':index,**case}
 for arm in ['baseline','candidate']:
  paired=[x for x in samples if x['arm']==arm and x['round'].startswith('pair')]
  row[arm+'_us']=statistics.median(x['summary']['median'] for x in paired);memory_pair=[x for x in memory if x['index']==index and x['arm']==arm and x.get('accepted') and x['round'].startswith('pair')]
  if memory:assert len(memory_pair)==3
  row[arm+'_peak_rss_kib']=statistics.median(x['peak_rss_kib'] for x in (memory_pair if memory else paired))
  row['peak_rss_scope']='target child from separate memory lane and small native launcher' if memory else paired[0].get('peak_rss_scope','Python-child kernel peak includes pre-exec launcher floor')
  ca=[x for x in counted if x['arm']==arm and x['round'].startswith('pair')]
  for metric in ['alloc_calls_per_callback','alloc_bytes_per_callback']:row[arm+'_'+metric]=statistics.median(x[metric] for x in ca)
  controls=[x for x in samples if x['arm']==arm and not x['round'].startswith('pair')];row[arm+'_same_build_delta_percent']=100*(controls[1]['summary']['median']/controls[0]['summary']['median']-1)
  rss_controls=[x for x in (memory if memory else samples) if x['index']==index and x['arm']==arm and x.get('accepted') and not x['round'].startswith('pair')]
  row[arm+'_rss_same_build_delta_percent']=100*(rss_controls[1]['peak_rss_kib']/rss_controls[0]['peak_rss_kib']-1)
  for metric in ['alloc_calls_per_callback','alloc_bytes_per_callback']:
   controls=[x for x in counted if x['arm']==arm and not x['round'].startswith('pair')];row[arm+'_'+metric+'_same_build_delta_percent']=100*(controls[1][metric]/controls[0][metric]-1)
  mutation=set()
  for x in samples:
   if x['arm']!=arm:continue
   m=re.search(r'DB19_MUTATION_ISOLATED=(true|false)',(root/x['stdout']).read_text())
   if m:mutation.add(m[1]=='true')
  if mutation:
   assert len(mutation)==1
   row[arm+'_mutation_isolated']=next(iter(mutation))
   expected=case.get(arm+'_expected_mutation_isolated')
   if expected is not None:assert row[arm+'_mutation_isolated']==expected,(index,arm,row)
 for arm in ['baseline','candidate']:
  observed=set();errors=set()
  for x in samples:
   if x['arm']!=arm:continue
   output=(root/x['stdout']).read_text()
   expected_changes=case.get(arm+'_expected_change_count')
   if expected_changes is not None:assert int(re.search(r'DB19_DIFF_COUNT=(\d+)',output)[1])==expected_changes,(arm,'wrong diff change count')
   paths=case.get(arm+'_expected_paths_preserved')
   if paths is not None:assert f'DB19_PATHS_PRESERVED={str(paths).lower()}' in output,(arm,'path preservation mismatch')
   equal=case.get(arm+'_expected_equal_result')
   if equal is not None:assert f'DB19_EQUAL_RESULT={str(equal).lower()}' in output,(index,arm,'wrong equality result')
   if case.get('expected_inputs_unchanged'):assert 'DB19_INPUTS_UNCHANGED=true' in output,(index,arm,'input mutation')
   names=case.get(arm+'_expected_utf8_names_preserved')
   if names is not None:assert f'DB19_UTF8_NAMES_PRESERVED={str(names).lower()}' in output,(index,arm,'wrong UTF-8 names')
   if 'expected_import_count' in case:assert int(re.search(r'DB19_IMPORT_COUNT=(\d+)',output)[1])==case['expected_import_count'],(index,arm,'wrong import count')
   groups=case.get(arm+'_expected_group_layout_preserved')
   if groups is not None:assert f'DB19_GROUP_LAYOUT_PRESERVED={str(groups).lower()}' in output,(index,arm,'unexpected group layout')
   roundtrip=case.get(arm+'_expected_roundtrip_preserved')
   if roundtrip is not None:assert f'DB19_ROUNDTRIP_PRESERVED={str(roundtrip).lower()}' in output,(index,arm,'unexpected roundtrip')
   expected_value=case.get(arm+'_expected_first_i32')
   if expected_value is not None:
    value=re.search(r'DB19_FIRST_I32=(-?\d+)',output);assert value and int(value[1])==expected_value,(index,arm,'unexpected lowered i32')
   m=re.search(r'DB19_VALIDATION_ACCEPTED=(true|false)',output)
   if m:observed.add(m[1]=='true')
   expected_error=case.get(arm+'_expected_validation_error_contains')
   if expected_error:assert expected_error in output,(index,arm,'unexpected rejection reason')
   error=re.search(r'DB19_VALIDATION_ERROR=(.*)',output)
   if error:errors.add(error[1])
  if observed:
   assert len(observed)==1
   row[arm+'_validation_accepted']=next(iter(observed))
   expected=case.get(arm+'_expected_validation_accepted')
   if expected is not None:assert row[arm+'_validation_accepted']==expected,(index,arm,'unexpected validation result')
   row[arm+'_validation_errors']=sorted(errors)
 for metric in ['us','peak_rss_kib','alloc_calls_per_callback','alloc_bytes_per_callback']:row[metric+'_delta_percent']=100*(row['candidate_'+metric]/row['baseline_'+metric]-1)
 rows.append(row)
accepted=[x for x in raw+allocation+memory if x.get('accepted')]
summary={'rows':rows,'runtime_samples':len(raw),'allocation_samples':len(allocation),'runtime_samples_accepted':sum(x.get('accepted',False) for x in raw),'allocation_samples_accepted':sum(x.get('accepted',False) for x in allocation),'maximum_sample_start_c':max(x['start_c'] for x in raw+allocation+memory),'maximum_sample_peak_c':max(x['peak_c'] for x in accepted),'memory_samples_accepted':sum(x.get('accepted',False) for x in memory),'discarded_samples':len(raw)+len(allocation)+len(memory)-len(accepted),'allocation_scope':'Raw MoonBit allocations in generated C and runtime, including headers. Whole-process counts divided by all callbacks; setup/fixture/benchmark overhead remains. Instrumented speed is excluded. RSS is uninstrumented whole-process kernel peak, not logical live memory.'}
(root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))

from pathlib import Path
import sys,json,re
r=Path(sys.argv[1]);cases=json.loads((r/'cases.json').read_text());xs=[json.loads(x) for x in (r/'paired.jsonl').read_text().splitlines() if json.loads(x).get('accepted')];rows=[]
for i,c in enumerate(cases):
 if 'expected_printed_byte_delta' not in c and not c.get('record_printed_bytes'):continue
 row={'index':i,'case':c.get('case',c.get('name'))}
 for arm in ['baseline','candidate']:
  sizes=set();flags=set()
  for x in xs:
   if x['index']!=i or x['arm']!=arm:continue
   out=(r/x['stdout']).read_text();m=re.search(r'DB19_SHARED_FLAGS_PRESERVED=(true|false)',out)
   if arm+'_expected_shared_flags_preserved' in c:
    assert m,(i,arm,'missing shared observation');flag=m[1]=='true';assert flag==c[arm+'_expected_shared_flags_preserved'],(i,arm,'wrong shared flags');flags.add(flag)
   m=re.search(r'DB19_PRINTED_BYTES=(\d+)',out);assert m;sizes.add(int(m[1]))
  assert len(sizes)==1,(i,arm,sizes);row[arm+'_printed_bytes']=next(iter(sizes))
  if flags:row[arm+'_shared_flags_preserved']=next(iter(flags))
 row['printed_bytes_delta']=row['candidate_printed_bytes']-row['baseline_printed_bytes']
 if 'expected_printed_byte_delta' in c:assert row['printed_bytes_delta']==c['expected_printed_byte_delta'],(i,row,c)
 rows.append(row)
(r/'output-observations.json').write_text(json.dumps({'rows':rows,'scope':'ASCII printer output size after timing. Shared flags are checked only where declared in the per-item cases; other roundtrip and group observations are checked by round1.py and aggregate.py.'},indent=2)+'\n')
if (r/'summary.json').exists():
 s=json.loads((r/'summary.json').read_text())
 for row in rows:s['rows'][row['index']].update(row)
 (r/'summary.json').write_text(json.dumps(s,indent=2)+'\n')
print('Verified output observations:',len(rows),'cases')

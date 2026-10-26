from pathlib import Path
import sys,json,re
r=Path(sys.argv[1]);cases=json.loads((r/'cases.json').read_text());xs=[json.loads(x) for x in (r/'paired.jsonl').read_text().splitlines() if json.loads(x).get('accepted')];rows=[]
for i,c in enumerate(cases):
 if 'baseline_expected_decimal_value' not in c:continue
 row={'index':i,'case':c['case']}
 for arm in ['baseline','candidate']:
  observed={}
  for x in xs:
   if x['index']!=i or x['arm']!=arm:continue
   out=(r/x['stdout']).read_text()
   for key,marker in [('decimal_value','DECIMAL_VALUE'),('low_memory_value','LOW_MEMORY_VALUE')]:
    if arm+'_expected_'+key not in c:continue
    m=re.search('DB19_'+marker+r'=(none|-?\d+)',out);assert m,(i,arm,key);value=None if m[1]=='none' else int(m[1]);assert value==c[arm+'_expected_'+key],(i,arm,key,value);observed[key]=value
   if c['mode']==1:assert f'DB19_CLI_REJECTED={str(c[arm+"_expected_decimal_value"] is None).lower()}' in out
  row.update({arm+'_'+k:v for k,v in observed.items()})
 rows.append(row)
(r/'decimal-observations.json').write_text(json.dumps({'rows':rows,'scope':'Post-timing option values; overflow changes are diagnostic, with CLI rejection and permissive config/environment omission checked separately'},indent=2)+'\n')
if (r/'summary.json').exists():
 s=json.loads((r/'summary.json').read_text())
 for row in rows:s['rows'][row['index']].update(row)
 (r/'summary.json').write_text(json.dumps(s,indent=2)+'\n')
print('Verified decimal and unsigned observations:',len(rows),'cases')

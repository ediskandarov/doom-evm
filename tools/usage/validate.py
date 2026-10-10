"""Focused standard-library validation for our documented schema subset/CSVs."""
import csv
import json
import math
from pathlib import Path
import re
import sys
from reporting import CSV_COLUMNS

FORBIDDEN_KEYS={'message','summary','content','output','input','arguments','objective',
                'aggregated_output','replacement_history','retained_context','command','text'}


def check(value, spec, root, location='$'):
    if '$ref' in spec:
        target=root
        for key in spec['$ref'].split('/')[1:]:target=target[key]
        check(value,target,root,location);return
    for child in spec.get('allOf',[]):check(value,child,root,location)
    if 'const' in spec and value!=spec['const']:raise ValueError(location+' const')
    types=spec.get('type',[]);types=[types] if isinstance(types,str) else types
    predicates={'null':value is None,'number':type(value) in (int,float) and math.isfinite(value),
                'integer':type(value) is int,'string':isinstance(value,str),'boolean':type(value) is bool,
                'object':isinstance(value,dict),'array':isinstance(value,list)}
    if types and not any(predicates.get(t,False) for t in types):raise ValueError(location+' type')
    if type(value) in (int,float) and 'minimum' in spec and value<spec['minimum']:raise ValueError(location+' minimum')
    if isinstance(value,str) and 'pattern' in spec and not re.search(spec['pattern'],value):raise ValueError(location+' pattern')
    if isinstance(value,dict):
        if any(k not in value for k in spec.get('required',[])):raise ValueError(location+' required')
        for key,sub in spec.get('properties',{}).items():
            if key in value:check(value[key],sub,root,location+'.'+key)
    if isinstance(value,list) and 'items' in spec:
        for i,x in enumerate(value):check(x,spec['items'],root,location+'['+str(i)+']')


def privacy(value):
    if isinstance(value,dict):
        if FORBIDDEN_KEYS.intersection(value):raise ValueError('forbidden transcript field')
        for v in value.values():privacy(v)
    elif isinstance(value,list):
        for v in value:privacy(v)


def validate(output):
    output=Path(output);report=json.loads((output/'usage.json').read_text())
    schema=json.loads((Path(__file__).parent/'schemas/usage-v2.schema.json').read_text())
    check(report,schema,schema);privacy(report)
    activity=report['activity']
    for name,key in [('compactions.csv','compactions'),('approvals.csv','approvals'),('executions.csv','executions'),('goals.csv','goals'),('activity-phase-totals.csv','phase_totals')]:
        with (output/name).open(newline='') as stream:
            reader=csv.DictReader(stream);assert reader.fieldnames==CSV_COLUMNS[name]
            rows=list(reader);assert len(rows)==len(activity[key])
            for row,original in zip(rows,activity[key]):
                for field in CSV_COLUMNS[name]:
                    value=original.get(field);assert row[field]==('' if value is None else str(value)), (name,field)
    return len(activity['compactions']),len(activity['executions'])


if __name__=='__main__':
    try:
        n,x=validate(sys.argv[1]);print(f'PASS v2 JSON contract, metadata privacy and CSV reconciliation: {n} compactions/{x} command records')
    except (ValueError,OSError,AssertionError,IndexError,TypeError):
        print('Telemetry export validation failed; inspect schema/metadata contracts, not raw transcripts.',file=sys.stderr);sys.exit(1)

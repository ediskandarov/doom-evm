#!/usr/bin/env python3
"""Record a scoped command and raw output separately from runner reports."""
import datetime
import json
import pathlib
import subprocess
import sys
import time

folder = pathlib.Path(__file__).resolve().parent
name, cwd, *command = sys.argv[1:]
start = datetime.datetime.now(datetime.timezone.utc).isoformat()
clock = time.monotonic()
with (folder / (name + '.log')).open('wb') as output:
    completed = subprocess.run(command, cwd=cwd, stdout=output, stderr=subprocess.STDOUT)
record = {'command': command, 'cwd': cwd, 'startedUtc': start,
          'endedUtc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'elapsedSeconds': time.monotonic() - clock, 'exitCode': completed.returncode,
          'rawOutput': str(folder / (name + '.log'))}
(folder / (name + '-command.json')).write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record))
print((folder / (name + '.log')).read_text()[-6000:])
sys.exit(completed.returncode)

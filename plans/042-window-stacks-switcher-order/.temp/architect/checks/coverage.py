"""Phase D coverage check: every R carried by the design, covered by a test row and delivered by a slice; every T in
exactly one slice. Usage: python3 -I coverage.py <plan.md>"""
import re
import sys

s = open(sys.argv[1]).read()
design = s[s.index('## Design'):s.index('## Testing Decisions')]
testing = s[s.index('## Testing Decisions'):s.index('## Slices')]
slices = s[s.index('## Slices'):]

rows = re.findall(r'^\| (T\d+) \| ([^|]+)\|', testing, re.M)
tids = [r[0] for r in rows]
print("test rows:", len(tids), "dupes:", sorted({t for t in tids if tids.count(t) > 1}))
covered = set()
for _, reqs in rows:
    covered |= set(re.findall(r'R\d+', reqs))

blocks = re.split(r'^### (S\d+)', slices, flags=re.M)
slice_t, slice_r = {}, {}
for i in range(1, len(blocks), 2):
    name, body = blocks[i], blocks[i + 1]
    m = re.search(r'\*\*Test scenarios:\*\*(.*)', body)
    slice_t[name] = re.findall(r'T\d+', m.group(1)) if m else []
    m = re.search(r'\*\*Requirements:\*\*(.*)', body)
    slice_r[name] = set(re.findall(r'R\d+', m.group(1))) if m else set()

allt = [t for v in slice_t.values() for t in v]
key = lambda x: int(x[1:])
print("T in slices:", len(allt))
print("  missing from slices:", sorted(set(tids) - set(allt), key=key))
print("  in more than one slice:", sorted({t for t in allt if allt.count(t) > 1}, key=key))
print("  unknown ids:", sorted(set(allt) - set(tids), key=key))
R = [f"R{i}" for i in range(1, 14)]
print("R without a test row:", [r for r in R if r not in covered])
in_slices = set().union(*slice_r.values())
print("R in no slice:", [r for r in R if r not in in_slices])
print("R never named in the design:", [r for r in R if not re.search(r'\b' + r + r'\b', design)])
for name in slice_t:
    print(name, slice_t[name], sorted(slice_r[name], key=key))

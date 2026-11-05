"""Summarise a tap-click-order log as touch episodes (first contact to empty pad) with the events inside each.
Usage: python3 episodes.py <log> [from_ms]"""
import re
import sys

lines = open(sys.argv[1]).read().splitlines()
since = float(sys.argv[2]) if len(sys.argv) > 2 else 0
episodes = []
current = None
for line in lines:
    m = re.match(r'\s*([\d.]+) ms\s+FRAME mt=[\d.]+ n=(\d+)\s*(.*)', line)
    if m:
        t, n, rest = float(m.group(1)), int(m.group(2)), m.group(3)
        if n > 0 and current is None:
            current = {'start': t, 'ids': set(), 'thumb': False, 'max': 0, 'events': []}
        if current is not None:
            for ident, _, x, y in re.findall(r'#(\d+) s(\d) \(([\d.]+),([\d.]+)\)', rest):
                current['ids'].add(ident)
                if float(x) < 0.12 and float(y) < 0.12:
                    current['thumb'] = True
            current['max'] = max(current['max'], n)
            if n == 0:
                current['end'] = t
                episodes.append(current)
                current = None
        continue
    m = re.match(r'\s*([\d.]+) ms\s+(.*)', line)
    if not m:
        continue
    t, text = float(m.group(1)), m.group(2)
    if 'hid=32' in text or 'type=14' in text or ' UP ' in text:
        continue
    text = re.sub(r'\s*number.*', '', text).strip()
    if current is not None:
        current['events'].append(f'{t - current["start"]:.0f}ms {text}')
    elif episodes:
        episodes[-1]['events'].append(f'+{t - episodes[-1]["end"]:.0f}ms after {text}')

for e in episodes:
    if e['start'] < since:
        continue
    events = []
    for x in e['events']:
        if not events or events[-1].split(' ', 1)[1] != x.split(' ', 1)[1]:
            events.append(x)
    print(f"{e['start']:9.0f} dur={e['end'] - e['start']:4.0f} contacts={len(e['ids'])} max={e['max']} "
          f"thumb={'Y' if e['thumb'] else '-'}  " + ' | '.join(events))

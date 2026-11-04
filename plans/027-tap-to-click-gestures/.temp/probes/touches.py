"""List every contact's landing (state 1-4 first seen), lift (first state >= 5) and hold, plus the events, in time order,
for a time range of a tap-click-order log. Usage: python3 touches.py <log> <from_ms> <to_ms>"""
import re
import sys

lines = open(sys.argv[1]).read().splitlines()
lo, hi = float(sys.argv[2]), float(sys.argv[3])
landed = {}
lifted = set()
out = []
for line in lines:
    m = re.match(r'\s*([\d.]+) ms\s+(.*)', line)
    if not m:
        continue
    t, text = float(m.group(1)), m.group(2)
    if t < lo or t > hi:
        continue
    if text.startswith('FRAME'):
        for ident, state, x, y in re.findall(r'#(\d+) s(\d) \(([\d.]+),([\d.]+)\)', text):
            state = int(state)
            if state <= 4 and ident not in landed:
                landed[ident] = t
                lifted.discard(ident)
                out.append(f'{t:9.1f}  land  #{ident} at ({x},{y})')
            elif state >= 5 and ident in landed and ident not in lifted:
                lifted.add(ident)
                out.append(f'{t:9.1f}  lift  #{ident} held {t - landed.pop(ident):.0f} ms')
        n = int(re.search(r'n=(\d+)', text).group(1))
        if n == 0:
            landed.clear()
            lifted.clear()
            out.append(f'{t:9.1f}  ---- pad empty')
    elif 'hid=32' not in text and 'type=14' not in text:
        out.append(f'{t:9.1f}  >>> {re.sub(r" (number|f39).*", "", text)}')
print('\n'.join(out))

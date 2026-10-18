"""Aggregate an exported Time Profiler table: per-thread totals, top self frames, top inclusive frames.
Usage: python3 -I profile.py <time-profile.xml> [N]"""
import collections
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
top = int(sys.argv[2]) if len(sys.argv) > 2 else 30
root = ET.parse(path).getroot()
ids = {}


def resolve(el):
    ref = el.get("ref")
    if ref is not None:
        return ids[ref]
    if el.get("id") is not None:
        ids[el.get("id")] = el
    for child in el:
        resolve(child)
    return el


threads = collections.Counter()
self_w = collections.Counter()
incl_w = collections.Counter()
total = 0
for row in root.iter("row"):
    weight = thread = bt = None
    for child in row:
        el = resolve(child)
        if child.tag == "weight":
            weight = int(el.text)
        elif child.tag == "thread":
            thread = el.get("fmt")
        elif child.tag in ("backtrace", "tagged-backtrace"):
            bt = el
    if weight is None or bt is None:
        continue
    total += weight
    threads[(thread or "?").split(" 0x")[0]] += weight
    names = []
    for frame in bt.iter("frame"):
        f = ids[frame.get("ref")] if frame.get("ref") else frame
        names.append(f.get("name") or "?")
    if names:
        self_w[names[0]] += weight
    for name in set(names):
        incl_w[name] += weight

ms = lambda w: w / 1e6
print(f"total sampled CPU: {ms(total):.1f} ms")
print("-- by thread")
for t, w in threads.most_common(10):
    print(f"{ms(w):8.1f} ms {100*w/total:5.1f}%  {t}")
print("-- top self")
for n, w in self_w.most_common(top):
    print(f"{ms(w):8.1f} ms {100*w/total:5.1f}%  {n[:150]}")
print("-- top inclusive")
for n, w in incl_w.most_common(top):
    print(f"{ms(w):8.1f} ms {100*w/total:5.1f}%  {n[:150]}")

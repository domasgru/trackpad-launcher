import re
import sys

text = open(sys.argv[1]).read()
testing = text[text.index("## Testing Decisions"):text.index("## Slices")]
slices = text[text.index("## Slices"):]

rows = re.findall(r"^\| (T\d+) \| ([^|]+) \|", testing, re.M)
covered_by_tests = set()
for _, reqs in rows:
    covered_by_tests |= set(re.findall(r"R\d+", reqs))

verified = testing[testing.index("### Verified without a test"):]
covered_by_checks = set()
for reqs in re.findall(r"\*\*C\d+\*\* \(([^)]*)\)", verified):
    covered_by_checks |= set(re.findall(r"R\d+", reqs))

slice_reqs = set()
slice_tests = set()
for m in re.finditer(r"\*\*Requirements:\*\* (.*)", slices):
    slice_reqs |= set(re.findall(r"R\d+", m.group(1)))
for m in re.finditer(r"\*\*Test scenarios:\*\* (.*)", slices):
    slice_tests |= set(re.findall(r"T\d+", m.group(1)))

def order(ids):
    return sorted(ids, key=lambda x: int(x[1:]))

all_reqs = {f"R{i}" for i in range(1, 26)}
table_ids = {r for r, _ in rows}
print("T rows", len(rows), "checks", len(re.findall(r"\*\*C\d+\*\*", verified)),
      "slices", len(re.findall(r"^### S\d+", slices, re.M)))
print("R not in a T row or check:", order(all_reqs - covered_by_tests - covered_by_checks))
print("R not delivered by a slice:", order(all_reqs - slice_reqs))
print("T not in a slice:", order(table_ids - slice_tests))
print("T in a slice but not in the table:", order(slice_tests - table_ids))
print("T ids in order:", [r for r, _ in rows] == [f"T{i}" for i in range(1, len(rows) + 1)])

# Reads what an update run left behind, for Scripts/update-e2e.sh: the server's request log (server.py) and the
# sampler's file (sampler.swift). Each command prints one line of evidence and exits 0 when its check holds, 1 when it
# does not. Times are epoch milliseconds.
#
#   analyze.py requests <log> [--since MS] [--until MS]
#   analyze.py count <log> [--kind K] [--contains TEXT] [--since MS] [--until MS]      K: feed release payload download any
#   analyze.py privacy <log> [--since MS] [--until MS]
#   analyze.py same-headers <log> <since-a> <until-a> <since-b> <until-b>
#   analyze.py samples-ok <samples> [--min N]
#   analyze.py quiet <samples> [--since MS] [--forbid-owner NAME]... [--max-app-windows N]
#                      [--no-new-windows [--allow-owner NAME]...]
#   analyze.py pids <samples> [--since MS] [--max-concurrent N] [--max-distinct N]
#   analyze.py first-version <samples> --app PATH --version V [--since MS]
#   analyze.py window-open <samples>
#   analyze.py first-at <log> --kind K [--since MS]                 prints the time of the first request of that kind
#   analyze.py gone-at <samples> --pid P [--since MS]               prints the first sample time the pid is gone, once seen
#   analyze.py new-pid <samples> --exclude P... [--since MS]        prints "time pid" of the first app process not excluded
#   analyze.py closed-at <samples>                                  prints when the app's windows last all went away
#   analyze.py first-front <samples> --id BUNDLE-ID [--since MS]    prints the time that app is first frontmost
#   analyze.py whole <samples> --app PATH --versions V,V...         every read of the bundle is one of those builds, intact
#   analyze.py absent <samples> --owner NAME...
import argparse
import json
import re
import sys

FEED_PATH = "/domasgru/trackpad-launcher/main/appcast.xml"
RELEASE = re.compile(r"^/domasgru/trackpad-launcher/releases/download/v[^/]+/[^/]+$")
HELPERS = {"Updater", "Autoupdate"}
FORBIDDEN = {"cookie", "if-none-match", "if-modified-since", "if-match", "if-range", "authorization", "referer", "origin"}


def finish(ok, evidence):
    print(evidence)
    sys.exit(0 if ok else 1)


def read_requests(path, since=0, until=None):
    with open(path) as handle:
        text = handle.read()
    found = []
    for block in text.split("\n\n"):
        lines = [line for line in block.split("\n") if line]
        if not lines or not lines[0].startswith("--- "):
            continue
        _, stamp, method, target = lines[0].split(" ", 3)
        when = int(stamp)
        if when < since or (until is not None and when > until):
            continue
        headers = [tuple(line.split(": ", 1)) for line in lines[1:] if ": " in line]
        found.append({"t": when, "method": method, "target": target, "path": target.split("?", 1)[0], "headers": headers})
    return found


def kind_of(request):
    path = request["path"]
    if path == FEED_PATH:
        return "feed"
    if RELEASE.match(path):
        return "release"
    if path.startswith("/assets/"):
        return "payload"
    return "other"


def read_samples(path, since=0):
    samples = []
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                sample = json.loads(line)
            except ValueError:
                continue
            if sample["t"] >= since:
                samples.append(sample)
    return samples


def app_windows(sample):
    pids = set(sample["app"]["pids"])
    return [window for window in sample["windows"] if window[1] in pids and window[3] == 0]


def standing(samples, owners):
    """Windows of these owners already on screen in the first sample: SecurityAgent keeps one up all the time."""
    return {window[2] for window in samples[0]["windows"] if window[0] in owners}


def command_requests(args):
    for request in read_requests(args.log, args.since, args.until):
        print(request["t"], request["method"], request["target"])
    sys.exit(0)


def command_count(args):
    selected = []
    for request in read_requests(args.log, args.since, args.until):
        kind = kind_of(request)
        if args.kind == "download" and kind not in ("release", "payload"):
            continue
        if args.kind not in ("any", "download") and kind != args.kind:
            continue
        if args.contains and args.contains not in request["target"]:
            continue
        selected.append(request)
    print(len(selected))
    sys.exit(0)


def command_privacy(args):
    requests = read_requests(args.log, args.since, args.until)
    feed = [request for request in requests if kind_of(request) == "feed"]
    if not feed:
        finish(False, "no feed request in the window")
    problems = []
    for request in requests:
        names = [name.lower() for name, _ in request["headers"]]
        for name in names:
            if name in FORBIDDEN or name.startswith("x-"):
                problems.append(f"{request['method']} {request['path']} carries {name}")
        if kind_of(request) in ("feed", "release") and "?" in request["target"]:
            problems.append(f"{request['path']} has a query")
    expected = {"user-agent": "TrackpadLauncher", "accept-language": "en", "accept-encoding": "gzip"}
    for request in feed:
        values = {name.lower(): value for name, value in request["headers"]}
        for name, want in expected.items():
            if values.get(name) != want:
                problems.append(f"feed {name} is {values.get(name)!r}, not {want!r}")
    finish(not problems, "; ".join(sorted(set(problems))) or f"{len(requests)} requests, {len(feed)} of the feed, all clean")


def header_sets(path, since, until):
    sets = set()
    for request in read_requests(path, int(since), int(until)):
        if kind_of(request) != "feed":
            continue
        sets.add(tuple(sorted((name.lower(), value) for name, value in request["headers"] if name.lower() != "host")))
    return sets


def command_same_headers(args):
    first = header_sets(args.log, args.since_a, args.until_a)
    second = header_sets(args.log, args.since_b, args.until_b)
    if not first or not second:
        finish(False, f"a side has no feed request ({len(first)} and {len(second)} header sets)")
    finish(first == second, f"{len(first)} and {len(second)} header sets, " + ("equal" if first == second else "different"))


def command_samples_ok(args):
    samples = read_samples(args.samples)
    keys = {"t", "front", "app", "windows", "installed"}
    ok = len(samples) >= args.min and all(keys <= set(sample) for sample in samples)
    finish(ok, f"{len(samples)} samples")


def command_quiet(args):
    samples = read_samples(args.samples)
    if not samples:
        finish(False, "no samples")
    forbidden = set(args.forbid_owner) | HELPERS
    problems = []
    policies = {sample["app"]["policy"] for sample in samples}
    if not policies <= {"accessory", "none"}:
        problems.append(f"activation policy was {sorted(policies)}")
    for sample in samples:
        if sample["t"] < args.since:
            continue
        front = sample["front"]
        if front["pid"] in sample["app"]["pids"]:
            problems.append("the app was frontmost")
        if front["name"] in HELPERS or "sparkle" in front["id"].lower():
            problems.append(f"{front['name'] or front['id']} was frontmost")
    already = standing(samples, forbidden)
    for sample in samples:
        for window in sample["windows"]:
            if window[0] in forbidden and window[2] not in already:
                problems.append(f"a window of {window[0]} appeared")
    if args.no_new_windows:
        later = [sample for sample in samples if sample["t"] >= args.since]
        if later:
            normal = lambda sample: [w for w in sample["windows"] if w[3] == 0 and w[0] not in args.allow_owner]
            known = {window[2] for window in normal(later[0])}
            for sample in later:
                for window in normal(sample):
                    if window[2] not in known:
                        problems.append(f"a new window of {window[0]} appeared")
    seen = {window[2] for sample in samples for window in app_windows(sample)}
    if args.max_app_windows is not None and len(seen) > args.max_app_windows:
        problems.append(f"{len(seen)} app windows appeared, more than {args.max_app_windows}")
    finish(
        not problems,
        "; ".join(sorted(set(problems))) or f"{len(samples)} samples: policy {sorted(policies)}, {len(seen)} app windows",
    )


def command_pids(args):
    samples = read_samples(args.samples, args.since)
    if not samples:
        finish(False, "no samples")
    concurrent = max(len(sample["app"]["pids"]) for sample in samples)
    distinct = len({pid for sample in samples for pid in sample["app"]["pids"]})
    ok = (args.max_concurrent is None or concurrent <= args.max_concurrent) and (
        args.max_distinct is None or distinct <= args.max_distinct
    )
    finish(ok, f"at most {concurrent} app processes at once, {distinct} distinct, over {len(samples)} samples")


def command_first_version(args):
    for sample in read_samples(args.samples, args.since):
        if sample["installed"].get(args.app, {}).get("version") == args.version:
            print(sample["t"])
            sys.exit(0)
    sys.exit(1)


def command_window_open(args):
    samples = read_samples(args.samples)
    open_now = bool(samples) and bool(app_windows(samples[-1]))
    finish(open_now, "an app window is open" if open_now else "no app window is open")


def command_absent(args):
    samples = read_samples(args.samples)
    if not samples:
        finish(False, "no samples")
    already = standing(samples, set(args.owner))
    seen = sorted(
        {w[0] for sample in samples for w in sample["windows"] if w[0] in args.owner and w[2] not in already}
    )
    finish(not seen, f"windows of {', '.join(seen)} appeared" if seen else f"no window of {', '.join(args.owner)} in {len(samples)} samples")


def command_first_at(args):
    for request in read_requests(args.log, args.since):
        if kind_of(request) == args.kind:
            print(request["t"])
            sys.exit(0)
    sys.exit(1)


def command_gone_at(args):
    seen = False
    for sample in read_samples(args.samples, args.since):
        if args.pid in sample["app"]["pids"]:
            seen = True
        elif seen:
            print(sample["t"])
            sys.exit(0)
    sys.exit(1)


def command_new_pid(args):
    for sample in read_samples(args.samples, args.since):
        fresh = [pid for pid in sample["app"]["pids"] if pid not in args.exclude]
        if fresh:
            print(sample["t"], fresh[0])
            sys.exit(0)
    sys.exit(1)


def command_closed_at(args):
    samples = read_samples(args.samples)
    if not samples or app_windows(samples[-1]):
        sys.exit(1)
    earliest = samples[-1]["t"]
    for sample in reversed(samples):
        if app_windows(sample):
            break
        earliest = sample["t"]
    print(earliest)
    sys.exit(0)


def command_first_front(args):
    for sample in read_samples(args.samples, args.since):
        if sample["front"]["id"] == args.id:
            print(sample["t"])
            sys.exit(0)
    sys.exit(1)


def command_whole(args):
    wanted = set(args.versions.split(","))
    samples = read_samples(args.samples)
    if not samples:
        finish(False, "no samples")
    for sample in samples:
        read = sample["installed"].get(args.app, {})
        if read.get("version") not in wanted or not read.get("exec"):
            finish(False, f"a read at {sample['t']} was version {read.get('version')}, executable {read.get('exec')}")
    finish(True, f"{len(samples)} reads, each a whole build of {sorted(wanted)}")


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)

    def add(name, function, source, *flags):
        command = commands.add_parser(name)
        command.add_argument(source)
        command.set_defaults(function=function)
        for flag, kwargs in flags:
            command.add_argument(flag, **kwargs)
        return command

    window = [("--since", {"type": int, "default": 0}), ("--until", {"type": int, "default": None})]
    add("requests", command_requests, "log", *window)
    add("count", command_count, "log", ("--kind", {"default": "any"}), ("--contains", {"default": ""}), *window)
    add("privacy", command_privacy, "log", *window)
    same = add("same-headers", command_same_headers, "log")
    for name in ("since_a", "until_a", "since_b", "until_b"):
        same.add_argument(name)
    add("samples-ok", command_samples_ok, "samples", ("--min", {"type": int, "default": 1}))
    add(
        "quiet", command_quiet, "samples", ("--since", {"type": int, "default": 0}),
        ("--forbid-owner", {"action": "append", "default": []}), ("--max-app-windows", {"type": int, "default": None}),
        ("--no-new-windows", {"action": "store_true"}), ("--allow-owner", {"action": "append", "default": []}),
    )
    add(
        "pids", command_pids, "samples", ("--since", {"type": int, "default": 0}),
        ("--max-concurrent", {"type": int, "default": None}), ("--max-distinct", {"type": int, "default": None}),
    )
    add(
        "first-version", command_first_version, "samples", ("--app", {"required": True}),
        ("--version", {"required": True}), ("--since", {"type": int, "default": 0}),
    )
    add("window-open", command_window_open, "samples")
    add("first-at", command_first_at, "log", ("--kind", {"required": True}), ("--since", {"type": int, "default": 0}))
    add("gone-at", command_gone_at, "samples", ("--pid", {"type": int, "required": True}), ("--since", {"type": int, "default": 0}))
    add(
        "new-pid", command_new_pid, "samples", ("--exclude", {"type": int, "action": "append", "default": []}),
        ("--since", {"type": int, "default": 0}),
    )
    add("closed-at", command_closed_at, "samples")
    add("first-front", command_first_front, "samples", ("--id", {"required": True}), ("--since", {"type": int, "default": 0}))
    add("whole", command_whole, "samples", ("--app", {"required": True}), ("--versions", {"required": True}))
    add("absent", command_absent, "samples", ("--owner", {"action": "append", "required": True}))

    args = parser.parse_args()
    args.function(args)


main()

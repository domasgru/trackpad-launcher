# Edits a feed that release.sh --feed-only rendered, for Scripts/update-e2e.sh. The item's signature covers its archive,
# not the feed, so neither edit re-signs anything. The result goes to standard output.
#
#   feed.py set-minimum <feed> <version> <macOS version>
#       the item of <version> now needs that macOS
#   feed.py derive <feed> <version> <new version> <new build>
#       adds an item copied from <version>'s, as <new version>: its archive address moves under v<new version>, so a
#       row that expects no download of it never needs a real archive
import re
import sys

ITEM = re.compile(r"<item>.*?</item>", re.DOTALL)


def item_of(text, version):
    for match in ITEM.finditer(text):
        if f"<title>{version}</title>" in match.group(0):
            return match
    sys.exit(f"feed.py: no item for {version}")


def set_tag(item, tag, value):
    return re.sub(rf"<{tag}>[^<]*</{tag}>", f"<{tag}>{value}</{tag}>", item)


command, path, version = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as handle:
    text = handle.read()
match = item_of(text, version)

if command == "set-minimum":
    item = set_tag(match.group(0), "sparkle:minimumSystemVersion", sys.argv[4])
    sys.stdout.write(text[: match.start()] + item + text[match.end() :])
elif command == "derive":
    new_version, build = sys.argv[4], sys.argv[5]
    item = match.group(0)
    item = set_tag(item, "title", new_version)
    item = set_tag(item, "sparkle:shortVersionString", new_version)
    item = set_tag(item, "sparkle:version", build)
    item = item.replace(f"/v{version}/", f"/v{new_version}/")
    sys.stdout.write(text.replace("</channel>", item + "\n</channel>", 1))
else:
    sys.exit(f"feed.py: unknown command {command}")

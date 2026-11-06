#!/bin/sh
# What does each GitHub URL an update feed or download could use send back?
# Prints status, redirect target host, Set-Cookie names and cache headers.
show() {
  echo "=== $1"
  curl -sS -m 30 -o /dev/null -D - "$1" | tr -d '\r' | grep -i -E '^(HTTP/|location:|set-cookie:|cache-control:|etag:|content-type:|content-length:)' | sed -E 's/(set-cookie: [^=]+)=.*/\1=<value>/I; s/(location: https:\/\/[^\/?]+).*/\1\/.../I'
}
show https://github.com/domasgru/trackpad-launcher/releases/latest/download/appcast.xml
show https://github.com/domasgru/trackpad-launcher/releases/download/v1.0.14/TrackpadLauncher-1.0.14-macOS-26.0.aar
show https://raw.githubusercontent.com/domasgru/trackpad-launcher/main/README.md
show https://raw.githubusercontent.com/domasgru/trackpad-launcher/refs/heads/main/project.yml
show https://api.github.com/repos/domasgru/trackpad-launcher/releases/latest
show https://domasgru.github.io/trackpad-launcher/appcast.xml
echo "=== follow the release asset to its final host"
curl -sS -m 60 -L -o /dev/null -D - -r 0-0 https://github.com/domasgru/trackpad-launcher/releases/download/v1.0.14/TrackpadLauncher-1.0.14-macOS-26.0.aar | tr -d '\r' | grep -i -E '^(HTTP/|location:|set-cookie:)' | sed -E 's/(set-cookie: [^=]+)=.*/\1=<value>/I; s/(location: https:\/\/[^\/?]+).*/\1\/.../I'
echo "=== release list"
curl -sS -m 30 "https://api.github.com/repos/domasgru/trackpad-launcher/releases?per_page=30" | /usr/bin/python3 -I -c "
import json,sys
d=json.load(sys.stdin)
for r in d[:6]:
    print(r['tag_name'], 'draft' if r['draft'] else '', 'pre' if r['prerelease'] else '', [a['name'] for a in r['assets']])
print('count', len(d))"

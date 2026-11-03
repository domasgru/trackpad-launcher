#!/bin/sh
# Probe: what api.github.com answers for this repo's release list, with and without a User-Agent.
# Claims tested:
#  (a) this repo's release list is publicly readable without a token;
#  (b) GitHub rejects a request that carries no User-Agent header;
#  (c) the unauthenticated rate limit, and the fields a release and an asset carry.
# Leaves nothing behind (the temp file is removed).
REPO=domasgru/trackpad-launcher
OUT=/tmp/tl-probe-releases.json

echo "== (a) this repo's release list, constant UA 'TrackpadLauncher'"
curl -s -o "$OUT" -D - -A "TrackpadLauncher" "https://api.github.com/repos/$REPO/releases" | grep -iE '^HTTP|x-ratelimit-limit'
echo "-- body (first 300 bytes)"; head -c 300 "$OUT"; echo

echo "== (b) this repo, User-Agent header removed"
curl -s -o "$OUT" -w "status %{http_code}\n" -H "User-Agent:" "https://api.github.com/repos/$REPO/releases"
head -c 300 "$OUT"; echo

echo "== (c) a public repo with releases (sparkle-project/Sparkle), constant UA: fields"
curl -s -o "$OUT" -A "TrackpadLauncher" "https://api.github.com/repos/sparkle-project/Sparkle/releases?per_page=2"
/usr/bin/python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); r=d[0]; print("release keys:", sorted(r.keys())); print({k:r[k] for k in ("tag_name","name","draft","prerelease")}); a=r["assets"][0]; print("asset keys:", sorted(a.keys())); print("download url:", a["browser_download_url"])' "$OUT"

echo "== (c2) that public repo, User-Agent header removed"
curl -s -o "$OUT" -w "status %{http_code}\n" -H "User-Agent:" "https://api.github.com/repos/sparkle-project/Sparkle/releases?per_page=1"
head -c 200 "$OUT"; echo

echo "== (d) /releases/latest on the public repo: excludes drafts and pre-releases?"
curl -s -o "$OUT" -A "TrackpadLauncher" "https://api.github.com/repos/sparkle-project/Sparkle/releases/latest"
/usr/bin/python3 -I -c 'import json,sys; r=json.load(open(sys.argv[1])); print({k:r[k] for k in ("tag_name","draft","prerelease")})' "$OUT"

echo "== (e) asset download: redirect chain and final host"
curl -s -o /dev/null -L -A "TrackpadLauncher" -w "final %{url_effective} status %{http_code} redirects %{num_redirects}\n" -r 0-0 "https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz"
rm -f "$OUT"

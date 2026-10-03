#!/bin/sh
# Builds ember-tv-staging.zip: the channel as it is, but pointed at the staging
# environment (staging--embertv.netlify.app and the staging Supabase project),
# titled "Ember TV Staging" and showing a STAGING badge. Sideload it like any
# dev build (see README). Never submit this zip to the Roku store.
set -eu
cd "$(dirname "$0")/.."
out="$PWD/ember-tv-staging.zip"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cp -R manifest source components images fonts "$tmp"/
sed 's/^title=.*/title=Ember TV Staging/' manifest > "$tmp/manifest"
printf '\nember_env=staging\n' >> "$tmp/manifest"

rm -f "$out"
(cd "$tmp" && zip -qr "$out" manifest source components images fonts -x '*.DS_Store')
echo "Built $out"

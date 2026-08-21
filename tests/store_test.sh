#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d /tmp/omaleaf-store-test-XXXXXX)
trap 'rm -rf "$test_dir"' EXIT

store="$project_dir/scripts/omaleaf-store"
export OMALEAF_DATA_DIR="$test_dir/data"

first=$($store create --folder Work | jq -r .id)
[[ $first == Work/*.md ]]

printf '# Release notes\n\n- [ ] Capture screenshots\n- [x] Run tests\n' > "$OMALEAF_DATA_DIR/notes/$first"

$store create-folder Personal >/dev/null
listing=$($store list)
[[ $(jq '.notes | length' <<<"$listing") -eq 1 ]]
[[ $(jq -r '.notes[0].title' <<<"$listing") == "Release notes" ]]
[[ $(jq -r '.notes[0].openTasks' <<<"$listing") -eq 1 ]]
[[ $(jq -r '.folders | contains(["Personal", "Work"])' <<<"$listing") == true ]]

$store pin "$first" >/dev/null
[[ $($store list | jq -r '.notes[0].pinned') == true ]]

moved=$($store move "$first" --folder Personal | jq -r .id)
[[ $moved == Personal/*.md ]]
[[ -f "$OMALEAF_DATA_DIR/notes/$moved" ]]
[[ $($store list | jq -r '.notes[0].pinned') == true ]]

trashed=$($store trash "$moved" | jq -r .id)
[[ -f "$OMALEAF_DATA_DIR/trash/$trashed" ]]
[[ $($store list | jq -r '.notes[0].trashed') == true ]]

restored=$($store restore "$trashed" | jq -r .id)
[[ -f "$OMALEAF_DATA_DIR/notes/$restored" ]]

$store trash "$restored" >/dev/null
$store delete "$restored" >/dev/null
[[ $($store list | jq '.notes | length') -eq 0 ]]

if $store create --folder ../escape >/dev/null 2>&1; then
  echo "unsafe folder unexpectedly accepted" >&2
  exit 1
fi

echo "OmaLeaf store tests passed"

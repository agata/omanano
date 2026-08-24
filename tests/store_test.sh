#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d /tmp/omanano-store-test-XXXXXX)
trap 'rm -rf "$test_dir"' EXIT

store="$project_dir/scripts/omanano-store"
export OMANANO_DATA_DIR="$test_dir/data"

first=$($store create --folder Work | jq -r .id)
[[ $first == Work/*.md ]]

printf '# Release notes\n\n- [ ] Capture screenshots\n- [x] Run tests\n' > "$OMANANO_DATA_DIR/notes/$first"

$store create-folder Personal >/dev/null
listing=$($store list)
[[ $(jq '.notes | length' <<<"$listing") -eq 1 ]]
[[ $(jq -r '.notes[0].title' <<<"$listing") == "Release notes" ]]
[[ $(jq -r '.notes[0].openTasks' <<<"$listing") -eq 1 ]]
[[ $(jq -r '.notes[0] | has("content")' <<<"$listing") == false ]]
[[ $(jq -r '.folders | contains(["Personal", "Work"])' <<<"$listing") == true ]]

loaded=$($store read "$first")
[[ $(jq -r '.tooLarge' <<<"$loaded") == false ]]
[[ $(jq -r '.content' <<<"$loaded") == $'# Release notes\n\n- [ ] Capture screenshots\n- [x] Run tests' ]]

oversized=$($store create | jq -r .id)
truncate -s 1048577 "$OMANANO_DATA_DIR/notes/$oversized"
oversized_listing=$($store list)
[[ $(jq --arg id "$oversized" -r '.notes[] | select(.id == $id) | .tooLarge' <<<"$oversized_listing") == true ]]
[[ ${#oversized_listing} -lt 10000 ]]
oversized_read=$($store read "$oversized")
[[ $(jq -r '.tooLarge' <<<"$oversized_read") == true ]]
[[ $(jq -r 'has("content")' <<<"$oversized_read") == false ]]
$store trash "$oversized" >/dev/null
$store delete "$oversized" >/dev/null

$store pin "$first" >/dev/null
[[ $($store list | jq -r '.notes[0].pinned') == true ]]

moved=$($store move "$first" --folder Personal | jq -r .id)
[[ $moved == Personal/*.md ]]
[[ -f "$OMANANO_DATA_DIR/notes/$moved" ]]
[[ $($store list | jq -r '.notes[0].pinned') == true ]]

trashed=$($store trash "$moved" | jq -r .id)
[[ -f "$OMANANO_DATA_DIR/trash/$trashed" ]]
[[ $($store list | jq -r '.notes[0].trashed') == true ]]

restored=$($store restore "$trashed" | jq -r .id)
[[ -f "$OMANANO_DATA_DIR/notes/$restored" ]]

$store trash "$restored" >/dev/null
$store delete "$restored" >/dev/null
[[ $($store list | jq '.notes | length') -eq 0 ]]

if $store create --folder ../escape >/dev/null 2>&1; then
  echo "unsafe folder unexpectedly accepted" >&2
  exit 1
fi

export OMANANO_DATA_DIR="$test_dir/cap-data"
mkdir -p "$OMANANO_DATA_DIR/notes"
for index in $(seq 1 2001); do
  : > "$OMANANO_DATA_DIR/notes/$index.md"
done
capped_listing=$($store list)
[[ $(jq '.notes | length' <<<"$capped_listing") -eq 2000 ]]
[[ $(jq -r '.notesTruncated' <<<"$capped_listing") == true ]]

echo "OmaNano store tests passed"

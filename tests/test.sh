#!/bin/zsh --no-rcs
# Runs the workflow script against a stand-in Diff Anything app and a stand-in open command,
# which records what it was asked to open. Usage: tests/test.sh
emulate -L zsh
cd "${0:A:h}/.."
script=workflow/diffanything.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A stand-in app bundle of a given version.
make_app() {
  mkdir -p "$work/$1/Contents"
  /usr/bin/plutil -create xml1 "$work/$1/Contents/Info.plist"
  /usr/bin/plutil -insert CFBundleShortVersionString -string "$2" "$work/$1/Contents/Info.plist"
  print -r -- "$work/$1"
}
cat > "$work/open" <<'EOF'
#!/bin/zsh --no-rcs
print -rl -- "$@" > "$OPEN_LOG"
EOF
chmod +x "$work/open"
export DIFF_ANYTHING_OPEN="$work/open" OPEN_LOG="$work/opened" alfred_workflow_cache="$work/cache"
current=$(make_app "Diff Anything.app" 1.7.0)
old=$(make_app "Old Diff Anything.app" 1.5.0)

failures=0
check() { # name, expected output (glob), expected opened lines (newline-separated), command...
  local name=$1 expected=$2 opened=$3; shift 3
  rm -f "$OPEN_LOG"
  local output; output=$("$@" 2>&1)
  local actual_opened=""; [[ -f "$OPEN_LOG" ]] && actual_opened=$(<"$OPEN_LOG")
  if [[ "$output" == ${~expected} && "$actual_opened" == ${~opened} ]]; then
    print "ok   $name"
  else
    print "FAIL $name\n     output: $output\n     opened: $actual_opened"
    (( failures++ ))
  fi
}

mkdir -p "$work/Café menus/Före" "$work/Café menus/Efter"
print "Bread 3.50" > "$work/Café menus/Före/price list.txt"
print "Bread 3.80" > "$work/Café menus/Efter/price list.txt"
left="$work/Café menus/Före/price list.txt" right="$work/Café menus/Efter/price list.txt"

export DIFF_ANYTHING_APP="$current"
check "two files with spaces and non-ASCII names" "" "-a
$current
$left
$right" zsh --no-rcs $script files "$left" "$right"
check "two folders" "" "-a
$current
$work/Café menus/Före
$work/Café menus/Efter" zsh --no-rcs $script files "$work/Café menus/Före" "$work/Café menus/Efter"
check "a file and a folder" "Compare two files or two folders, not one of each." "" \
  zsh --no-rcs $script files "$left" "$work/Café menus/Efter"
check "one item" "Choose exactly two files or exactly two folders; 1 were given." "" \
  zsh --no-rcs $script files "$left"
check "three items" "Choose exactly two*3 were given." "" zsh --no-rcs $script files "$left" "$right" "$left"
check "a missing file" "Cannot read $work/missing.txt*" "" zsh --no-rcs $script files "$left" "$work/missing.txt"
check "a relative path" "Choose items by their full path: price list.txt" "" zsh --no-rcs $script files "price list.txt" "$right"

older_text=$'Line one\nLine two\n' newer_text=$'Line one\nLine 2\n' \
  check "two multiline texts" "" "-a
$current
$work/cache/text-comparisons/pair.*/Earlier copy.txt
$work/cache/text-comparisons/pair.*/Latest copy.txt" zsh --no-rcs $script text
pair=(${(f)"$(<"$OPEN_LOG")"})
if [[ "$(cat "${pair[3]}"; print -n x)" == $'Line one\nLine two\nx' && "$(stat -f %Lp "${pair[3]}")" == 600 && "$(stat -f %Lp "${pair[3]:h}")" == 700 ]]; then
  print "ok   the texts are written exactly, privately"
else
  print "FAIL the texts are written exactly, privately"; (( failures++ ))
fi
older_text="" newer_text="Only one" check "only one copied text" "Only one copied text was found.*" "" zsh --no-rcs $script text
older_text="" newer_text="" check "no copied text" "There is no copied text to compare.*" "" zsh --no-rcs $script text

DIFF_ANYTHING_APP="$work/Nowhere.app" check "the app is missing" "Diff Anything is not installed.*" \
  "macappstore://apps.apple.com/app/id6795463996" zsh --no-rcs $script files "$left" "$right"
DIFF_ANYTHING_APP="$old" check "the app is too old" \
  "This workflow needs Diff Anything 1.7.0 or later; 1.5.0 is installed.*" \
  "macappstore://apps.apple.com/app/id6795463996" zsh --no-rcs $script files "$left" "$right"
check "an unknown command" "Unknown command: nothing" "" zsh --no-rcs $script nothing

if (( failures )); then print "$failures failed"; exit 1; fi
print "All passed"

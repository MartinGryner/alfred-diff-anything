#!/bin/zsh --no-rcs
# Hands two files, two folders, or two texts to the Diff Anything app on the Mac, left then right.
#
#   diffanything.sh files <left> <right>   two files or two folders (Alfred's file action)
#   diffanything.sh finder                 the two items selected in Finder
#   diffanything.sh text                   the texts in $older_text (left) and $newer_text (right)
#
# Prints nothing when the comparison opens, and otherwise one sentence for Alfred's notification.
# The pair goes to the app through macOS (open -a), the way a Finder double-click does: files
# opened this way are ones the sandboxed Mac App Store app may read; paths on its command line
# are not. Nothing is sent over the network.

emulate -L zsh
setopt no_unset

readonly bundle_id="com.martingruner.diffanything"
readonly minimum_version="1.7.0"
readonly store_url="macappstore://apps.apple.com/app/id6795463996"
# Tests point these at a stand-in app and a stand-in open command.
readonly open_command="${DIFF_ANYTHING_OPEN:-/usr/bin/open}"
readonly text_root="${alfred_workflow_cache:-${TMPDIR:-/tmp}/com.martingruner.alfred.diffanything}"

# The version, as numbers to compare, of an app bundle; 0 when it cannot be read.
app_version() {
  /usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$1/Contents/Info.plist" 2>/dev/null || print 0
}

# Whether version $1 is older than version $2, compared number by number.
older_than() {
  local -a a b
  a=(${(s:.:)1}) b=(${(s:.:)2})
  local i
  for i in {1..$(( ${#a} > ${#b} ? ${#a} : ${#b} ))}; do
    (( ${a[i]:-0} < ${b[i]:-0} )) && return 0
    (( ${a[i]:-0} > ${b[i]:-0} )) && return 1
  done
  return 1
}

# The newest installed Diff Anything, or a message that says how to install or update it.
find_app() {
  local -a candidates
  if [[ -n "${DIFF_ANYTHING_APP:-}" ]]; then
    candidates=("$DIFF_ANYTHING_APP")
  else
    candidates=(${(f)"$(/usr/bin/mdfind "kMDItemCFBundleIdentifier == '$bundle_id'" 2>/dev/null)"})
  fi
  local newest="" newest_version="0" candidate version
  for candidate in $candidates; do
    [[ -d "$candidate" ]] || continue
    version=$(app_version "$candidate")
    if [[ -z "$newest" ]] || older_than "$newest_version" "$version"; then
      newest=$candidate newest_version=$version
    fi
  done
  if [[ -z "$newest" ]]; then
    "$open_command" "$store_url" 2>/dev/null
    print "Diff Anything is not installed. Install it from the Mac App Store, which is now open."
    return 1
  fi
  if older_than "$newest_version" "$minimum_version"; then
    "$open_command" "$store_url" 2>/dev/null
    print "This workflow needs Diff Anything $minimum_version or later; $newest_version is installed. Update it from the Mac App Store, which is now open."
    return 1
  fi
  print -r -- "$newest"
}

# Checks that the pair is two readable files or two readable folders.
check_pair() {
  if (( $# != 2 )); then
    print "Choose exactly two files or exactly two folders; $# were given."
    return 1
  fi
  local item
  for item in "$@"; do
    if [[ "$item" != /* ]]; then
      print "Choose items by their full path: $item"
      return 1
    fi
    if [[ ! -r "$item" ]] || [[ ! -f "$item" && ! -d "$item" ]]; then
      print "Cannot read $item. Check that it exists and that you may open it."
      return 1
    fi
  done
  if [[ -d "$1" && ! -d "$2" || ! -d "$1" && -d "$2" ]]; then
    print "Compare two files or two folders, not one of each."
    return 1
  fi
}

open_pair() {
  local app
  app=$(find_app) || { print -r -- "$app"; return 1; }
  if ! "$open_command" -a "$app" "$1" "$2" 2>/dev/null; then
    print "Diff Anything could not be opened. Open it once from Applications, then try again."
    return 1
  fi
}

compare_files() {
  local message
  message=$(check_pair "$@") || { print -r -- "$message"; return 1; }
  open_pair "$1" "$2"
}

# The POSIX paths of the items selected in Finder, one a line.
finder_selection() {
  /usr/bin/osascript -e 'tell application "Finder" to set chosen to selection as alias list' \
    -e 'set out to ""' \
    -e 'repeat with item_ref in chosen' \
    -e 'set out to out & POSIX path of item_ref & linefeed' \
    -e 'end repeat' -e 'return out' 2>/dev/null
}

compare_finder_selection() {
  local -a chosen
  chosen=(${(f)"$(finder_selection)"})
  if (( ${#chosen} == 0 )); then
    print "Select two files or two folders in Finder first."
    return 1
  fi
  # Finder ends a folder's path with a slash; the app takes it either way.
  compare_files "${chosen[@]%/}"
}

# Writes the two texts as private files the app can open, and removes pairs older than a day.
compare_texts() {
  local older="${older_text:-}" newer="${newer_text:-}"
  if [[ -z "$older" && -z "$newer" ]]; then
    print "There is no copied text to compare. Copy two texts, one after the other, then try again."
    return 1
  fi
  if [[ -z "$older" ]]; then
    print "Only one copied text was found. Turn on Clipboard History in Alfred's Features, copy two texts, then try again."
    return 1
  fi
  local base="$text_root/text-comparisons"
  /bin/mkdir -p -m 700 "$base"
  /usr/bin/find "$base" -mindepth 1 -maxdepth 1 -type d -mtime +0 -exec /bin/rm -rf {} + 2>/dev/null
  local directory
  directory=$(/usr/bin/mktemp -d "$base/pair.XXXXXX")
  /bin/chmod 700 "$directory"
  (umask 077; print -rn -- "$older" > "$directory/Earlier copy.txt"; print -rn -- "$newer" > "$directory/Latest copy.txt")
  open_pair "$directory/Earlier copy.txt" "$directory/Latest copy.txt"
}

main() {
  local command="${1:-}"
  (( $# )) && shift
  case "$command" in
    files) compare_files "$@" ;;
    finder) compare_finder_selection ;;
    text) compare_texts ;;
    *) print "Unknown command: $command"; return 2 ;;
  esac
}

main "$@"

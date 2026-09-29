#!/usr/bin/env bash
# Grades answers.txt. Answers are stored as hashes so reading this file won't spoil them.
source "$(dirname "$0")/../lib.sh"
LAB="$REPO_ROOT/labs/00-terminal"
ANSWERS="$LAB/answers.txt"

# Make answers forgiving: ignore case, quotes, "# comments", "./path/" prefixes, etc.
norm() {
  local q="$1" a="$2"
  a="${a%%#*}"
  a="$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]' | sed -E "s/^[[:space:]\"'\`]+//; s/[[:space:]\"'\`]+$//")"
  case "$q" in
    8|11) a="${a##*/}" ;;
    5|6)  a="${a#/}" ;;
    10)   a="${a##*=}"; a="${a// /}" ;;
    12)   a="$(printf '%s' "$a" | sed -E 's/:.*//; s/^0+([0-9])/\1/')" ;;
  esac
  printf '%s' "$a"
}
hash_answer() { printf 'lab00:%s:%s' "$1" "$(norm "$1" "$2")" | shasum -a 256 | cut -c1-16; }

declare -a EXPECTED
EXPECTED[1]=568c0ce6ea661615
EXPECTED[2]=aa61913f36c54edc
EXPECTED[3]=9d0dd2b2b9cd92b0
EXPECTED[4]=b5a5dadcbd9063cd
EXPECTED[5]=bcdf7d4d12a76c0e
EXPECTED[6]=9da8ad1128cb3cc0
EXPECTED[7]=15691725ae29d185
EXPECTED[8]=b59cfaeee6a2d3ff
EXPECTED[9]=28144df27bb88780
EXPECTED[10]=a0376ef2b5a3c7e0
EXPECTED[11]=6428706a6bb98fcb
EXPECTED[12]=49a6836ac04677d5

HINTS=(
  ""
  "wc -l counts lines"
  "grep -c with a pattern that only matches the status column"
  "grep -v inverts, -c counts"
  "awk '{print \$1}' | sort | uniq -c | sort -rn | head"
  "filter 404s first, then the path is column 7"
  "tail -n 1, then awk"
  "find app -name '*.log' | wc -l (is the pattern exact?)"
  "grep -rl lists the files that match"
  "grep -ri '\\[error\\]' app | wc -l"
  "comments (#) don't count"
  "grep -rl for 'token' or 'secret' in config/"
  "awk '{print \$4}' | cut -d: -f2 | sort | uniq -c | sort -rn"
)

title "Lab 00: Terminal detective"
[ -f "$ANSWERS" ] || { echo "No answers.txt found at $ANSWERS"; exit 1; }

for q in $(seq 1 12); do
  line=$(grep -E "^[[:space:]]*$q[:.)][[:space:]]*" "$ANSWERS" | head -n 1)
  answer=$(printf '%s' "$line" | sed -E "s/^[[:space:]]*$q[:.)][[:space:]]*//")
  label="Q$q"; [ "$q" -eq 12 ] && label="Q12 (bonus)"
  if [ -z "$(norm "$q" "$answer")" ]; then
    fail "$label: not answered yet"
  elif [ "$(hash_answer "$q" "$answer")" = "${EXPECTED[$q]}" ]; then
    pass "$label"
  else
    fail "$label (you said: $(norm "$q" "$answer"))" "${HINTS[$q]}"
  fi
done

summary

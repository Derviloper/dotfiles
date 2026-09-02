#!/usr/bin/env bash
set -u

emit() {
  local focused occupied
  focused=$(bspc query -D -d focused --names 2>/dev/null || true)
  occupied=$(bspc query -D -d .occupied --names 2>/dev/null | tr '\n' ' ')

  local out="["
  for i in 1 2 3 4 5 6 7 8 9 10; do
    local state="empty"
    if [[ " $occupied " == *" $i "* ]]; then
      state="occupied"
    fi
    if [[ $i == "$focused" ]]; then
      state="active"
    fi
    out+="{\"num\":\"$i\",\"state\":\"$state\"},"
  done
  out="${out%,}]"
  printf '%s\n' "$out"
}

emit
bspc subscribe report | while read -r _; do
  emit
done

#!/usr/bin/env bash

# simple wrapper for go.runs-on.com finder api

set -euo pipefail

name="$(basename "$0")"

cpu="${1:-}"
mem="${2:-}"
arch="${3:-x86_64}"

if [ -z "$cpu" ] || [ -z "$mem" ]; then
  echo "usage: $name <cpu> <memory> [arch]"
  echo
  echo "examples:"
  echo "  $name 4-8 16-32"
  echo "  $name 4-8 16-32 arm64"
  exit 1
fi

# basic colors
title_color=$'\033[1;34m'  # bold blue
header_color=$'\033[1;36m' # bold cyan
reset_color=$'\033[0m'

# title line
printf '%s%s%s\n' "$title_color" "runs-on.com ec2 finder: cpu=$cpu, memory=$mem, arch=$arch" "$reset_color"
echo

i=0
while IFS= read -r line; do
  if [ "$i" -eq 0 ]; then
    # header row
    printf '%s%s%s\n' "$header_color" "$line" "$reset_color"
  else
    printf '%s\n' "$line"
  fi
  i=$((i + 1))
done < <(
  curl -fsS -G \
    -d "cpu=$cpu" \
    -d "ram=$mem" \
    -d "arch=$arch" \
    "https://go.runs-on.com/api/finder" |
    jq -r '
    # handle both {.top3: [...]} and plain [...] input
    (.top3 // .) as $items
    | def round3: (.*1000 + 0.5 | floor) / 1000;

    # header row
    ["type", "benchmark", "cpu", "memory", "ebs mps", "network", "ondemand", "spot"],

    # data rows
    ($items[] |
      [
        .instanceType,
        (.passmark | tostring),
        (.vcpus | tostring),
        (.memoryGiB | tostring),
        (.ebsBaselineBandwidthMbps | tostring),
        (.networkPerformanceGiBps | tostring),
        (.avgOnDemandPrice | round3 | tostring),
        (.avgSpotPrice | round3 | tostring)
      ]
    )
    | @tsv
  ' | column -t -s $'\t'
)

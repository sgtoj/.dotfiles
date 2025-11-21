#!/usr/bin/env bash

# simple wrapper for runs-on finder api

set -euo pipefail

cpu="${1:-}"
mem="${2:-}"
arch="${3:-x86_64}"

if [ -z "$cpu" ] || [ -z "$mem" ]; then
  echo "usage: $0 <cpu> <memory> [arch]"
  exit 1
fi

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
    ["type","cpu","memory","ebs mps","network","ondemand", "spot"],

    # data rows
    ($items[] |
      [
        .instanceType,
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

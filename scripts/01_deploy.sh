#!/usr/bin/env bash
set -e
ORG=${1:-carenest}
sf project deploy start --source-dir force-app --target-org "$ORG" --wait 30

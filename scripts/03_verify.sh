#!/usr/bin/env bash
set -eo pipefail

ORG=${1:-carenest}

# Windows / Git-Bash compatibility:
# In Git Bash on Windows, /c/Program Files/sf/bin/sf delegates to sf.cmd, which
# causes cmd.exe to split paths with spaces at 'C:\Program'. Prepending the native
# client bin directory so Git Bash invokes the native CLI directly without cmd.exe.
if [ -d "/c/Program Files/sf/client/bin" ]; then
  export PATH="/c/Program Files/sf/client/bin:$PATH"
elif [ -n "$LOCALAPPDATA" ] && [ -d "$LOCALAPPDATA/sf/client/bin" ]; then
  export PATH="$LOCALAPPDATA/sf/client/bin:$PATH"
fi

echo "=================================================="
echo "CareNest Phase 14 Verification"
echo "=================================================="
echo "Target Org: $ORG"

# 1. Verify target org
ORG_DISPLAY=$(sf org display --target-org "$ORG" --json 2>/dev/null || true)
if [ -z "$ORG_DISPLAY" ]; then
  echo "FAIL: Unable to connect to target org: $ORG"
  exit 1
fi

ORG_STATUS=$(printf '%s' "$ORG_DISPLAY" | grep -o '"connectedStatus": *"[^"]*"' | head -n1 | cut -d'"' -f4)
ORG_ALIAS=$(printf '%s' "$ORG_DISPLAY" | grep -o '"alias": *"[^"]*"' | head -n1 | cut -d'"' -f4)
ORG_USERNAME=$(printf '%s' "$ORG_DISPLAY" | grep -o '"username": *"[^"]*"' | head -n1 | cut -d'"' -f4)

if [ "$ORG_STATUS" != "Connected" ]; then
  echo "FAIL: Org $ORG status is not Connected (found: $ORG_STATUS)"
  exit 1
fi
echo "Org Status: Connected (Alias: $ORG_ALIAS, User: $ORG_USERNAME)"
echo ""

# Helper to extract totalSize from JSON
get_count() {
  local query="$1"
  local raw
  raw=$(sf data query --query "$query" --target-org "$ORG" --json 2>/dev/null || true)
  local count=""
  if command -v node >/dev/null 2>&1; then
    count=$(printf '%s' "$raw" | node -e '
      let d="";
      process.stdin.on("data", c => d += c).on("end", () => {
        try {
          const j = JSON.parse(d);
          console.log(j.result ? j.result.totalSize : (j.totalSize !== undefined ? j.totalSize : -1));
        } catch (e) {
          console.log(-1);
        }
      });
    ')
  elif command -v python3 >/dev/null 2>&1 && python3 -c "import sys" >/dev/null 2>&1; then
    count=$(printf '%s' "$raw" | python3 -c "import sys,json;print(json.load(sys.stdin).get('result',{}).get('totalSize',-1))" 2>/dev/null || echo "-1")
  elif command -v python >/dev/null 2>&1 && python -c "import sys" >/dev/null 2>&1; then
    count=$(printf '%s' "$raw" | python -c "import sys,json;print(json.load(sys.stdin).get('result',{}).get('totalSize',-1))" 2>/dev/null || echo "-1")
  else
    count=$(printf '%s' "$raw" | grep -o '"totalSize": *[0-9]*' | head -n1 | grep -o '[0-9]*' || echo "-1")
  fi
  echo "$count"
}

ERRORS=0

check_record_count() {
  local label="$1"
  local query="$2"
  local expected="$3"
  
  local actual
  actual=$(get_count "$query")
  
  if [ "$actual" -eq "$expected" ] 2>/dev/null; then
    echo "  [PASS] $label: $actual (Expected: $expected)"
  else
    echo "  [FAIL] $label: $actual (Expected: $expected)"
    ERRORS=$((ERRORS + 1))
  fi
}

echo "Record Count Checks:"
check_record_count "Doctor__c" "SELECT COUNT() FROM Doctor__c" 12
check_record_count "Contact (Patient_Code__c != null)" "SELECT COUNT() FROM Contact WHERE Patient_Code__c != null" 100
check_record_count "Appointment_Slot__c" "SELECT COUNT() FROM Appointment_Slot__c" 36
check_record_count "Appointment__c" "SELECT COUNT() FROM Appointment__c" 80
check_record_count "Payment__c" "SELECT COUNT() FROM Payment__c" 69
check_record_count "Cancellation__c" "SELECT COUNT() FROM Cancellation__c" 9
check_record_count "Visit_Record__c" "SELECT COUNT() FROM Visit_Record__c" 21

echo ""
echo "Sample Appointment Records (LIMIT 5):"
sf data query --query "SELECT Name, Status__c, Fee_Amount__c, Discount_Percent__c, Total_Amount__c, Amount_Paid__c, Balance_Due__c FROM Appointment__c LIMIT 5" --target-org "$ORG"

echo ""
echo "Cancellation Policies:"
sf data query --query "SELECT DeveloperName, Min_Hours__c, Fee_Percent__c FROM Cancellation_Policy__mdt" --target-org "$ORG"

echo ""
echo "=================================================="
if [ "$ERRORS" -eq 0 ]; then
  echo "VERIFICATION SUMMARY: ALL CHECKS PASSED (7/7)"
  echo "=================================================="
  exit 0
else
  echo "VERIFICATION SUMMARY: $ERRORS CHECK(S) FAILED"
  echo "=================================================="
  exit 1
fi

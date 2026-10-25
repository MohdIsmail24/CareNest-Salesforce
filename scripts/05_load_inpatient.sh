#!/usr/bin/env bash
# usage: scripts/05_load_inpatient.sh [orgAlias]
# Run AFTER scripts/02_load_data.sh (needs Contacts and Doctors). Idempotent (upsert on external IDs).
set -e
ORG=${1:-carenest}; D=data/demo/cli

if [ -f "/c/Program Files/sf/client/bin/node.exe" ] && [ -f "/c/Program Files/sf/client/bin/run.js" ]; then
    NODE_BIN="/c/Program Files/sf/client/bin/node.exe"
    SF_RUN="/c/Program Files/sf/client/bin/run.js"
    sf() {
        "$NODE_BIN" "$SF_RUN" "$@"
    }
fi

echo "Seeding hospital wards..."
sf apex run --file scripts/apex/seed_wards.apex --target-org "$ORG"
sf data upsert bulk --sobject Bed__c                 --file $D/beds.csv                 --external-id Bed_Code__c       --wait 20 --target-org "$ORG"
sf data upsert bulk --sobject Admission__c           --file $D/admissions.csv           --external-id Admission_Code__c --wait 20 --target-org "$ORG"
sf data upsert bulk --sobject Inpatient_Encounter__c --file $D/inpatient_encounters.csv --external-id Encounter_Code__c --wait 20 --target-org "$ORG"
sf data upsert bulk --sobject Patient_Vital__c       --file $D/patient_vitals.csv       --external-id Vital_Code__c     --wait 20 --target-org "$ORG"

count() {
    if [ -n "$NODE_BIN" ]; then
        "$NODE_BIN" "$SF_RUN" data query --query "SELECT COUNT() FROM $1" --target-org "$ORG" --json | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['totalSize'])"
    else
        sf data query --query "SELECT COUNT() FROM $1" --target-org "$ORG" --json | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['totalSize'])"
    fi
}
for o in Bed__c Admission__c Inpatient_Encounter__c Patient_Vital__c; do echo -n "$o: "; count $o; done
sf data query --query "SELECT Name, Patient__r.Name, Bed__r.Name, Bed__r.Ward__c, Status__c, Length_Of_Stay__c, Total_Bed_Charge__c FROM Admission__c WHERE Status__c = 'Admitted'" --target-org "$ORG"
sf data query --query "SELECT Admission__r.Name, Recorded_At__c, Pulse_BPM__c, Systolic_BP__c, SpO2_Percent__c, Alert_Flag__c FROM Patient_Vital__c WHERE Alert_Flag__c = true LIMIT 10" --target-org "$ORG"

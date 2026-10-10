#!/usr/bin/env bash
# usage: scripts/02_load_data.sh [demo|full] [orgAlias]
set -e
SET=${1:-demo}; ORG=${2:-carenest}; D=data/$SET/cli
sf data upsert bulk --sobject Doctor__c           --file $D/doctors.csv           --external-id Registration_No__c --line-ending LF --wait 20 --target-org "$ORG"
sf data upsert bulk --sobject Contact             --file $D/patients_contacts.csv --external-id Patient_Code__c    --line-ending LF --wait 20 --target-org "$ORG"
sf data upsert bulk --sobject Appointment_Slot__c --file $D/appointment_slots.csv --external-id Slot_Code__c       --line-ending LF --wait 20 --target-org "$ORG"
sf data upsert bulk --sobject Appointment__c      --file $D/appointments.csv      --external-id Appointment_Code__c --line-ending LF --wait 20 --target-org "$ORG"
sf data upsert bulk --sobject Payment__c          --file $D/payments.csv          --external-id Gateway_Txn_Id__c  --line-ending LF --wait 20 --target-org "$ORG"
sf apex run --file scripts/apex/seed_cancellations_and_visits.apex --target-org "$ORG"
sf apex run --file scripts/apex/recalc_after_load.apex --target-org "$ORG"

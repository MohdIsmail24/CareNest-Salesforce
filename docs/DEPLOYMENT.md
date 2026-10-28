# CareNest HMS — Setup & Salesforce CLI Deployment Guide

**Project:** CareNest Hospital Management System  
**Tooling:** Salesforce CLI (`sf` v2.151+)  
**Repository Structure:** Salesforce DX Format (`sfdx-project.json`)  
**Target API Version:** `68.0`  

---

## 1. Prerequisites

Before deploying CareNest, ensure your local development environment meets the following requirements:
* **Node.js:** v18.0.0 or higher
* **Salesforce CLI:** `@salesforce/cli` (v2.150+)
* **Git:** v2.30+
* **Salesforce Org:** A Developer Edition or Scratch Org with Lightning Experience enabled.

---

## 2. Authentication

Authorize your target Salesforce organization using the Salesforce CLI web login:

```bash
# Login with browser authorization
sf org login web --set-default --alias carenest

# Verify active connection
sf org display --target-org carenest
```

---

## 3. Metadata Deployment

### 3.1 Pre-Deployment Check-Only Validation Gate
Always validate metadata deployment using test validation before applying permanent changes:

```bash
sf project deploy start \
  --metadata-dir manifest/package.xml \
  --test-level RunSpecifiedTests \
  --tests CareNestAdmissionControllerTest,CareNestPatientSharingTest \
  --dry-run \
  --target-org carenest
```

### 3.2 Permanent Production/Developer Org Deployment
Once validation passes with 100% test completion and 0 errors, execute the permanent deployment:

```bash
sf project deploy start \
  --metadata-dir manifest/package.xml \
  --test-level RunSpecifiedTests \
  --tests CareNestAdmissionControllerTest,CareNestPatientSharingTest \
  --target-org carenest
```

---

## 4. Post-Deployment Configuration

### 4.1 Assign Permission Sets
Assign the core CareNest permission sets to your user:

```bash
# Assign Hospital Administrator Permission Set
sf org assign permset --name CareNest_Administrator --target-org carenest

# Assign Doctor and Nurse Permission Sets (for test users)
sf org assign permset --name CareNest_Doctor --target-org carenest
sf org assign permset --name CareNest_Nurse --target-org carenest
sf org assign permset --name CareNest_Front_Desk --target-org carenest
sf org assign permset --name CareNest_Billing_Cashier --target-org carenest
```

### 4.2 Launch the Application
Open the CareNest Lightning Application directly in your browser:

```bash
sf org open --path /lightning/app/c__CareNest --target-org carenest
```

---

## 5. Verification Checklist

1. **Lightning App Navigation:** Verify all 12 modules render without JavaScript errors.
2. **Patient Directory:** Confirm the master patient index populates.
3. **Bed Capacity Matrix:** Confirm all 42 beds across the 5 wards display their accurate status.
4. **Apex Scheduled Jobs:** Verify scheduled jobs under Setup $\rightarrow$ Scheduled Jobs.
5. **Agentforce AI:** Verify the Einstein assistant widget connects to active invocable actions.

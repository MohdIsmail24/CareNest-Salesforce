/**
 * scripts/generate_internal_dashboard_v2_preview.js
 * Generates standalone preview HTML for CareNest Hospital Admin Command Center, Revenue Analytics & Reports Hub.
 * Serves preview on http://localhost:8093 for Playwright responsive verification and screenshots.
 */
const http = require('http');
const fs = require('fs');
const path = require('path');

const cssPath = path.join(__dirname, '..', 'force-app', 'main', 'default', 'lwc', 'careNestDashboardV2', 'careNestDashboardV2.css');
const imgPath = path.join(__dirname, '..', 'force-app', 'main', 'default', 'staticresources', 'careNestHeroMedicalSuite.resource');
const cssContent = fs.readFileSync(cssPath, 'utf8');

const reportsData = [
    {
        id: '00Og700000BBzBYEA1',
        name: 'Daily Collections & Payment Settlements',
        developerName: 'CareNest_Daily_Collections_Settlements',
        category: 'Financial Analytics',
        categoryKey: 'financial',
        description: 'Daily verified patient fee collections, POS receipts, and settled invoices by payment method.',
        url: '/lightning/r/Report/00Og700000BBzBYEA1/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#0d9488" stroke-width="2"><rect x="2" y="4" width="20" height="16" rx="2"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>',
        badgeClass: 'care-pill-badge-teal',
        isFinancial: true
    },
    {
        id: '00Og700000BBzBZEA1',
        name: 'Department & Specialty Revenue Breakdown',
        developerName: 'CareNest_Department_Specialty_Revenue',
        category: 'Financial Analytics',
        categoryKey: 'financial',
        description: 'Gross recorded collections aggregated by medical department and clinical specialty.',
        url: '/lightning/r/Report/00Og700000BBzBZEA1/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#0d9488" stroke-width="2"><line x1="18" x2="18" y1="20" y2="10"/><line x1="12" x2="12" y1="20" y2="4"/><line x1="6" x2="6" y1="20" y2="14"/></svg>',
        badgeClass: 'care-pill-badge-teal',
        isFinancial: true
    },
    {
        id: '00Og700000BBzBbEAL',
        name: 'Doctor Revenue Contribution Analytics',
        developerName: 'CareNest_Doctor_Revenue_Contribution',
        category: 'Financial Analytics',
        categoryKey: 'financial',
        description: 'Revenue generated per attending physician and consulting specialist across hospital encounters.',
        url: '/lightning/r/Report/00Og700000BBzBbEAL/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#0d9488" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
        badgeClass: 'care-pill-badge-teal',
        isFinancial: true
    },
    {
        id: '00Og700000BBzBeEAL',
        name: 'Post-Service Open Receivables Aging',
        developerName: 'CareNest_Outstanding_Receivables_Aging',
        category: 'Financial Analytics',
        categoryKey: 'financial',
        description: 'Outstanding patient receivables categorized by consultation aging buckets (0-30, 31-60, 60+ days).',
        url: '/lightning/r/Report/00Og700000BBzBeEAL/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#0d9488" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>',
        badgeClass: 'care-pill-badge-teal',
        isFinancial: true
    },
    {
        id: '00Og700000BBzBVEA1',
        name: 'Active Inpatient Census by Ward & Bed',
        developerName: 'CareNest_Active_Admissions_Census',
        category: 'Hospital Operations',
        categoryKey: 'operations',
        description: 'Current inpatient bed occupancy, ward census distribution, and patient stay durations.',
        url: '/lightning/r/Report/00Og700000BBzBVEA1/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#2563eb" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="9" y1="21" x2="9" y2="9"/></svg>',
        badgeClass: 'care-pill-badge-blue',
        isFinancial: false
    },
    {
        id: '00Og700000BBzBWEA1',
        name: 'Outpatient Appointment Volume & Status',
        developerName: 'CareNest_Appointments_Volume_by_Status',
        category: 'Hospital Operations',
        categoryKey: 'operations',
        description: 'Total outpatient appointments categorized by status (Scheduled, Completed, In-Progress).',
        url: '/lightning/r/Report/00Og700000BBzBWEA1/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#2563eb" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>',
        badgeClass: 'care-pill-badge-blue',
        isFinancial: false
    },
    {
        id: '00Og700000BBzBcEAL',
        name: 'Inpatient Bed Occupancy & Capacity',
        developerName: 'CareNest_Inpatient_Bed_Occupancy_Capacity',
        category: 'Hospital Operations',
        categoryKey: 'operations',
        description: 'Real-time operational bed capacity, active bed assignments, and vacancy rates across wards.',
        url: '/lightning/r/Report/00Og700000BBzBcEAL/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#2563eb" stroke-width="2"><path d="M2 4v16M2 8h18a2 2 0 0 1 2 2v10M2 17h20M6 8v9"/></svg>',
        badgeClass: 'care-pill-badge-blue',
        isFinancial: false
    },
    {
        id: '00Og700000BBzBXEA1',
        name: 'Clinical Alerts & Abnormal Vitals Review',
        developerName: 'CareNest_Clinical_Alerts_Vitals_Review',
        category: 'Clinical & Physician',
        categoryKey: 'clinical',
        description: 'Patient vital sign measurements flagging abnormal systolic, diastolic, or heart rate thresholds.',
        url: '/lightning/r/Report/00Og700000BBzBXEA1/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#d97706" stroke-width="2"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
        badgeClass: 'care-pill-badge-amber',
        isFinancial: false
    },
    {
        id: '00Og700000BBzBaEAL',
        name: 'Doctor Consultation Workload & Encounters',
        developerName: 'CareNest_Doctor_Consultation_Workload',
        category: 'Clinical & Physician',
        categoryKey: 'clinical',
        description: 'Active consultation volume and encounter counts per physician for operational load balancing.',
        url: '/lightning/r/Report/00Og700000BBzBaEAL/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#d97706" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
        badgeClass: 'care-pill-badge-amber',
        isFinancial: false
    },
    {
        id: '00Og700000BBzBdEAL',
        name: 'Inpatient Encounters & Rounds by Doctor',
        developerName: 'CareNest_Inpatient_Encounters_by_Doctor',
        category: 'Clinical & Physician',
        categoryKey: 'clinical',
        description: 'Daily inpatient doctor rounds, clinical ward visits, and encounter notes recorded by physicians.',
        url: '/lightning/r/Report/00Og700000BBzBdEAL/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#d97706" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>',
        badgeClass: 'care-pill-badge-amber',
        isFinancial: false
    },
    {
        id: '00Og700000AiDF8EAN',
        name: 'Available-Bed Capacity by Ward',
        developerName: 'Available_Bed_Capacity_by_Ward',
        category: 'Additional Operations',
        categoryKey: 'additional',
        description: 'Real-time available bed count and capacity distribution across wards.',
        url: '/lightning/r/Report/00Og700000AiDF8EAN/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#64748b" stroke-width="2"><line x1="18" x2="18" y1="20" y2="10"/><line x1="12" x2="12" y1="20" y2="4"/><line x1="6" x2="6" y1="20" y2="14"/></svg>',
        badgeClass: 'care-pill-badge-gray',
        isFinancial: false
    },
    {
        id: '00Og700000AiDFAEA3',
        name: 'Current Admissions by Status',
        developerName: 'Current_Admissions_by_Status',
        category: 'Additional Operations',
        categoryKey: 'additional',
        description: 'Live patient admissions grouped by status and clinical severity.',
        url: '/lightning/r/Report/00Og700000AiDFAEA3/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#64748b" stroke-width="2"><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><rect x="8" y="2" width="8" height="4" rx="1" ry="1"/></svg>',
        badgeClass: 'care-pill-badge-gray',
        isFinancial: false
    },
    {
        id: '00Og700000AiDFDEA3',
        name: 'Encounter Activity by Doctor and Date',
        developerName: 'Inpatient_Encounters_by_Doctor_Date',
        category: 'Additional Operations',
        categoryKey: 'additional',
        description: 'Daily doctor ward rounds and clinical encounters over time.',
        url: '/lightning/r/Report/00Og700000AiDFDEA3/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#64748b" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 14 14"/></svg>',
        badgeClass: 'care-pill-badge-gray',
        isFinancial: false
    },
    {
        id: '00Og700000AiDFEEA3',
        name: 'Appointment Volume by Date',
        developerName: 'Appointment_Volume_by_Date',
        category: 'Additional Operations',
        categoryKey: 'additional',
        description: 'Timeline of outpatient appointment bookings, arrivals, and completions.',
        url: '/lightning/r/Report/00Og700000AiDFEEA3/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#64748b" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>',
        badgeClass: 'care-pill-badge-gray',
        isFinancial: false
    },
    {
        id: '00Og700000AiDFFEA3',
        name: 'Appointments by Doctor',
        developerName: 'Appointments_by_Doctor',
        category: 'Additional Operations',
        categoryKey: 'additional',
        description: 'Doctor consultation workload, scheduled sessions, and completion tracking.',
        url: '/lightning/r/Report/00Og700000AiDFFEA3/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#64748b" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
        badgeClass: 'care-pill-badge-gray',
        isFinancial: false
    },
    {
        id: '00Og700000AiDF7EAN',
        name: 'Recorded Patient Vitals by Date',
        developerName: 'Patient_Vitals_by_Date',
        category: 'Additional Operations',
        categoryKey: 'additional',
        description: 'Chronological vital sign observations, blood pressure, temperature, and pulse logs.',
        url: '/lightning/r/Report/00Og700000AiDF7EAN/view',
        icon: '<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#64748b" stroke-width="2"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>',
        badgeClass: 'care-pill-badge-gray',
        isFinancial: false
    }
];

function generateReportCardsHtml(list) {
    return list.map(r => `
        <div class="care-report-hub-card" data-category="${r.categoryKey}" data-name="${r.name.toLowerCase()}" data-desc="${r.description.toLowerCase()}">
            <div class="care-report-hub-card-header">
                <span class="${r.badgeClass}">${r.category}</span>
                <span class="care-report-id-chip" title="Salesforce Report ID">${r.id}</span>
            </div>
            <div class="care-report-hub-card-body">
                <div class="care-report-hub-card-title-row">
                    <div class="care-report-hub-icon-box">
                        ${r.icon}
                    </div>
                    <h3 class="care-report-hub-title">${r.name}</h3>
                </div>
                <p class="care-report-hub-desc">${r.description}</p>
            </div>
            <div class="care-report-hub-card-footer">
                <a href="${r.url}" target="_blank" rel="noopener noreferrer" class="care-btn-open-report">
                    <span>Open in Salesforce</span>
                    <svg class="svg-icon" viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" x2="21" y1="14" y2="3"/></svg>
                </a>
            </div>
        </div>
    `).join('\n');
}

function generateQuickHubCardsHtml(list) {
    return list.map(r => `
        <a href="${r.url}" target="_blank" class="care-report-link-card">
            <div class="care-report-card-icon">
                ${r.icon}
            </div>
            <div class="care-report-card-content">
                <div class="care-report-name">${r.name}</div>
                <div class="care-report-cat">${r.category} • ${r.id}</div>
            </div>
            <svg class="svg-icon care-report-ext-icon" viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="#94a3b8" stroke-width="2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" x2="21" y1="14" y2="3"/></svg>
        </a>
    `).join('\n');
}

const htmlTemplate = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CareNest Hospital Admin Command Center, Revenue Analytics &amp; Reports Hub</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f8fafc; color: #1e293b; line-height: 1.5; -webkit-font-smoothing: antialiased; }
        ${cssContent}
        
        .svg-icon { display: inline-flex; vertical-align: middle; flex-shrink: 0; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
    </style>
</head>
<body>
    <div class="care-internal-app">
        <!-- 0. TOP UTILITY RIBBON -->
        <header class="care-utility-bar">
            <div class="care-utility-container">
                <div class="care-utility-left">
                    <span class="care-live-indicator">
                        <span class="care-pulse-dot"></span>
                        LIVE HOSPITAL COMMAND CENTER
                    </span>
                    <span class="care-utility-divider">|</span>
                    <span class="care-utility-text">CareNest Enterprise Healthcare Platform</span>
                    <span class="care-utility-divider">|</span>
                    <span class="care-utility-hotline">
                        <svg class="svg-icon" viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="#f87171" stroke-width="2"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
                        Emergency Hotline Ext: <strong>911 / 4567</strong>
                    </span>
                </div>
                <div class="care-utility-right">
                    <span class="care-staff-badge">
                        <svg class="svg-icon" viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="7" r="4"/><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/></svg>
                        <span class="care-staff-name">Dr. Mohammad Ismail</span>
                        <span class="care-staff-role">(Hospital Administrator)</span>
                    </span>
                    <span class="care-kpi-chip">
                        <span class="care-kpi-chip-label">Occupancy:</span>
                        <span class="care-kpi-chip-val">57.6%</span>
                    </span>
                    <span class="care-kpi-chip">
                        <span class="care-kpi-chip-label">Inpatients:</span>
                        <span class="care-kpi-chip-val">19</span>
                    </span>
                    <span class="care-kpi-chip">
                        <span class="care-kpi-chip-label">Reports Live:</span>
                        <span class="care-kpi-chip-val" style="color:#0d9488;font-weight:700;">16</span>
                    </span>
                </div>
            </div>
        </header>

        <!-- 1. STICKY BRANDED NAVIGATION HEADER -->
        <nav class="care-brand-nav">
            <div class="care-brand-nav-container">
                <div class="care-logo-group" onclick="switchTab('adminOverview')">
                    <div class="care-logo-mark">
                        <svg class="care-logo-svg" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <rect width="32" height="32" rx="8" fill="#0d9488"/>
                            <path d="M16 8V24M8 16H24" stroke="white" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                    </div>
                    <div class="care-logo-text">
                        <div class="care-logo-title">CareNest</div>
                        <div class="care-logo-tagline">Hospital Admin Command Center</div>
                    </div>
                </div>

                <!-- Navigation Tabs (Pills) -->
                <div class="care-nav-pills-container">
                    <button class="care-nav-scroll-btn care-nav-scroll-left" onclick="scrollNav(-250)" aria-label="Scroll left">
                        <svg class="svg-icon" viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg>
                    </button>
                    <div id="nav-pills-wrapper" class="care-nav-pills-wrapper">
                        <div class="care-nav-pills">
                            <button id="pill-adminOverview" class="care-nav-pill care-nav-pill-active" onclick="switchTab('adminOverview')">
                                <svg class="svg-icon care-pill-icon" viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="9"/><rect x="14" y="3" width="7" height="5"/><rect x="14" y="12" width="7" height="9"/><rect x="3" y="16" width="7" height="5"/></svg>
                                <span>Executive Analytics</span>
                                <span class="care-pill-badge" style="background:#ccfbf1;color:#0f766e;">₹42.5K</span>
                            </button>
                            <button id="pill-reports" class="care-nav-pill" onclick="switchTab('reports')">
                                <svg class="svg-icon care-pill-icon" viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
                                <span>Reports Hub</span>
                                <span class="care-pill-badge" style="background:#0d9488;color:#fff;font-weight:700;">16</span>
                            </button>
                            <button id="pill-overview" class="care-nav-pill" onclick="switchTab('overview')">
                                <svg class="svg-icon care-pill-icon" viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2v20M2 12h20"/></svg>
                                <span>Command Center</span>
                                <span class="care-pill-badge">Live</span>
                            </button>
                            <button class="care-nav-pill"><span class="care-pill-label">Patient Registry</span><span class="care-pill-badge">114</span></button>
                            <button class="care-nav-pill"><span class="care-pill-label">Doctors &amp; Staff</span><span class="care-pill-badge">12</span></button>
                            <button class="care-nav-pill"><span class="care-pill-label">OPD Appointments</span></button>
                            <button class="care-nav-pill"><span class="care-pill-label">Admissions &amp; Beds</span><span class="care-pill-badge">19</span></button>
                            <button class="care-nav-pill"><span class="care-pill-label">Ward Capacity</span><span class="care-pill-badge">14 Avail</span></button>
                            <button class="care-nav-pill"><span class="care-pill-label">Clinical Charts &amp; Vitals</span><span class="care-pill-badge" style="background:#fee2e2;color:#991b1b;">17</span></button>
                            <button class="care-nav-pill"><span class="care-pill-label">Billing &amp; Payments</span></button>
                            <button class="care-nav-pill"><span class="care-pill-label">Agentforce AI</span><span class="care-pill-badge">AI</span></button>
                            <button class="care-nav-pill"><span class="care-pill-label">System Health</span><span class="care-pill-badge">RBAC</span></button>
                        </div>
                    </div>
                    <button class="care-nav-scroll-btn care-nav-scroll-right" onclick="scrollNav(250)" aria-label="Scroll right">
                        <svg class="svg-icon" viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg>
                    </button>
                </div>

                <div class="care-nav-actions">
                    <button class="care-btn-all-modules" onclick="toggleModulesMenu()">
                        <svg class="svg-icon care-btn-icon" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>
                        <span>All Modules</span>
                    </button>
                    <button class="care-btn-register" onclick="switchTab('reports')">
                        <svg class="svg-icon care-btn-icon" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
                        <span>Reports Hub (16)</span>
                    </button>
                    <button class="care-mobile-toggle" onclick="toggleMobileMenu()">
                        <svg class="svg-icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><line x1="4" x2="20" y1="12" y2="12"/><line x1="4" x2="20" y1="6" y2="6"/><line x1="4" x2="20" y1="18" y2="18"/></svg>
                    </button>
                </div>
            </div>

            <!-- Mobile Drawer -->
            <div id="mobile-drawer" class="care-mobile-drawer" style="display:none;">
                <button class="care-mobile-nav-item care-mobile-nav-item-active" onclick="switchTab('adminOverview')">Executive Revenue Analytics</button>
                <button class="care-mobile-nav-item" onclick="switchTab('reports')">Reports Hub (16 Reports)</button>
                <button class="care-mobile-nav-item" onclick="switchTab('overview')">Command Center</button>
                <button class="care-mobile-nav-item">Patient Registry</button>
                <button class="care-mobile-nav-item">Doctors &amp; Staff</button>
                <button class="care-mobile-nav-item">OPD Appointments</button>
                <button class="care-mobile-nav-item">Admissions &amp; Beds</button>
                <button class="care-mobile-nav-item">Ward Capacity</button>
                <button class="care-mobile-nav-item">Clinical Charts &amp; Vitals</button>
                <button class="care-mobile-nav-item">Billing &amp; Payments</button>
                <button class="care-mobile-nav-item">Agentforce AI</button>
                <button class="care-mobile-nav-item">System Health &amp; RBAC</button>
            </div>
        </nav>

        <!-- 2. MAIN CONTENT AREA -->
        <main class="care-main-content">
            <!-- TAB 1: EXECUTIVE REVENUE ANALYTICS & ADMIN OVERVIEW -->
            <div id="tab-adminOverview" class="tab-content active">
                <div class="care-admin-container">
                    <!-- Title Bar -->
                    <div class="care-admin-header-row">
                        <div>
                            <span class="care-pill-badge-teal">CareNest Certified Deployment</span>
                            <h1 class="care-admin-main-title">Hospital Executive &amp; Revenue Command Center</h1>
                            <p class="care-admin-main-desc">High-precision accounting terminology, reconciled clinical alerts, and live operational analytics across CareNest Hospital.</p>
                        </div>
                        <div class="care-admin-header-actions">
                            <button class="care-btn-primary" onclick="switchTab('reports')">
                                <svg class="svg-icon" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
                                <span>Open Full Reports Hub (16)</span>
                            </button>
                            <button class="care-btn-glass" onclick="location.reload()">
                                <svg class="svg-icon" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M23 4v6h-6"/><path d="M1 20v-6h6"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>
                                <span>Live Sync</span>
                            </button>
                        </div>
                    </div>

                    <!-- 1. CORRECTED FINANCIAL ACCOUNTING KPI CARDS -->
                    <div class="care-admin-kpi-grid slds-m-top_medium">
                        <div class="care-kpi-card care-kpi-border-teal">
                            <div class="care-kpi-card-header">
                                <span class="care-kpi-card-label">Recorded Successful Collections</span>
                                <span class="care-pill-badge-teal">Primary</span>
                            </div>
                            <div class="care-kpi-card-val care-text-teal">₹42,500.00</div>
                            <div class="care-kpi-card-sub">Recorded Successful Collections in Org (Excludes refund deductions)</div>
                        </div>

                        <div class="care-kpi-card care-kpi-border-indigo">
                            <div class="care-kpi-card-header">
                                <span class="care-kpi-card-label">Collections Less Refund Obligations</span>
                                <span class="care-pill-badge-indigo">Net</span>
                            </div>
                            <div class="care-kpi-card-val care-text-indigo">₹37,312.50</div>
                            <div class="care-kpi-card-sub">Recorded collections minus total pending/completed refund liabilities</div>
                        </div>

                        <div class="care-kpi-card care-kpi-border-amber">
                            <div class="care-kpi-card-header">
                                <span class="care-kpi-card-label">Refund Entitlements</span>
                                <span class="care-pill-badge-amber">Refunds</span>
                            </div>
                            <div class="care-kpi-card-val care-text-amber">₹5,187.50</div>
                            <div class="care-kpi-card-sub">Total recorded patient refund obligations (pending disbursal/credited)</div>
                        </div>

                        <div class="care-kpi-card care-kpi-border-rose">
                            <div class="care-kpi-card-header">
                                <span class="care-kpi-card-label">Post-Service Open Balances</span>
                                <span class="care-pill-badge-rose">Aging</span>
                            </div>
                            <div class="care-kpi-card-val care-text-rose">₹8,987.50</div>
                            <div class="care-kpi-card-sub">Outstanding post-consultation receivables (18 appointments in aging chart)</div>
                        </div>

                        <div class="care-kpi-card care-kpi-border-emerald">
                            <div class="care-kpi-card-header">
                                <span class="care-kpi-card-label">Accrued Inpatient Bed Charges</span>
                                <span class="care-pill-badge-emerald">Accrued</span>
                            </div>
                            <div class="care-kpi-card-val care-text-emerald">₹521,200.00</div>
                            <div class="care-kpi-card-sub">19 active admissions × ward daily rates (Accrued hospital charges)</div>
                        </div>
                    </div>

                    <!-- 2. REVENUE CHARTS (2-COLUMN GRID) -->
                    <div class="care-admin-charts-grid slds-m-top_large">
                        <div class="care-card-panel">
                            <div class="care-panel-header">
                                <div>
                                    <h3 class="care-panel-title">Recorded Revenue by Department</h3>
                                    <p class="care-panel-sub">Collections breakdown across clinical specialties.</p>
                                </div>
                            </div>
                            <div class="care-dept-chart-container">
                                <div class="care-dept-chart-bar-group">
                                    <div class="care-dept-bar-label-row">
                                        <span class="care-dept-name">Cardiology</span>
                                        <span class="care-dept-amount">₹18,500.00 (43.5%)</span>
                                    </div>
                                    <div class="care-dept-progress-track">
                                        <div class="care-dept-progress-fill" style="width: 43.5%; background: #0d9488;"></div>
                                    </div>
                                </div>
                                <div class="care-dept-chart-bar-group">
                                    <div class="care-dept-bar-label-row">
                                        <span class="care-dept-name">General Medicine</span>
                                        <span class="care-dept-amount">₹12,400.00 (29.2%)</span>
                                    </div>
                                    <div class="care-dept-progress-track">
                                        <div class="care-dept-progress-fill" style="width: 29.2%; background: #2563eb;"></div>
                                    </div>
                                </div>
                                <div class="care-dept-chart-bar-group">
                                    <div class="care-dept-bar-label-row">
                                        <span class="care-dept-name">Paediatrics</span>
                                        <span class="care-dept-amount">₹6,800.00 (16.0%)</span>
                                    </div>
                                    <div class="care-dept-progress-track">
                                        <div class="care-dept-progress-fill" style="width: 16.0%; background: #6366f1;"></div>
                                    </div>
                                </div>
                                <div class="care-dept-chart-bar-group">
                                    <div class="care-dept-bar-label-row">
                                        <span class="care-dept-name">Orthopaedics</span>
                                        <span class="care-dept-amount">₹4,800.00 (11.3%)</span>
                                    </div>
                                    <div class="care-dept-progress-track">
                                        <div class="care-dept-progress-fill" style="width: 11.3%; background: #f59e0b;"></div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="care-card-panel">
                            <div class="care-panel-header">
                                <div>
                                    <h3 class="care-panel-title">Post-Service Aging Breakdown</h3>
                                    <p class="care-panel-sub">18 open appointments aging by consultation date.</p>
                                </div>
                            </div>
                            <div class="care-aging-buckets-grid">
                                <div class="care-aging-bucket-box care-bucket-green">
                                    <div class="care-aging-bucket-title">0 - 30 Days</div>
                                    <div class="care-aging-bucket-val">₹4,200.00</div>
                                    <div class="care-aging-bucket-sub">9 Consultations</div>
                                </div>
                                <div class="care-aging-bucket-box care-bucket-amber">
                                    <div class="care-aging-bucket-title">31 - 60 Days</div>
                                    <div class="care-aging-bucket-val">₹2,850.00</div>
                                    <div class="care-aging-bucket-sub">6 Consultations</div>
                                </div>
                                <div class="care-aging-bucket-box care-bucket-red">
                                    <div class="care-aging-bucket-title">61 - 90 Days</div>
                                    <div class="care-aging-bucket-val">₹1,450.00</div>
                                    <div class="care-aging-bucket-sub">2 Consultations</div>
                                </div>
                                <div class="care-aging-bucket-box care-bucket-purple">
                                    <div class="care-aging-bucket-title">90+ Days</div>
                                    <div class="care-aging-bucket-val">₹487.50</div>
                                    <div class="care-aging-bucket-sub">1 Consultation</div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- 3. SALESFORCE REPORTS QUICK ACCESS LAUNCHER -->
                    <div class="care-card-panel slds-m-top_large">
                        <div class="care-panel-header" style="display:flex;justify-content:space-between;align-items:center;">
                            <div>
                                <h3 class="care-panel-title">Official Salesforce Financial &amp; Operational Reports</h3>
                                <p class="care-panel-sub">All 16 certified CareNest Salesforce reports mapped with direct navigation.</p>
                            </div>
                            <button class="care-btn-glass" onclick="switchTab('reports')">
                                <span>Open Full Reports Hub &rarr;</span>
                            </button>
                        </div>

                        <div class="care-reports-grid">
                            ${generateQuickHubCardsHtml(reportsData)}
                        </div>
                    </div>
                </div>
            </div>

            <!-- TAB 2: REPORTS HUB MODULE (MODULE 9 FULL INTEGRATION) -->
            <div id="tab-reports" class="tab-content">
                <div class="care-module-card slds-p-around_large">
                    <!-- Reports Hub Header -->
                    <div class="care-reports-hub-header">
                        <div>
                            <div class="care-reports-badge-row">
                                <span class="care-pill-badge-teal">
                                    <svg class="svg-icon" viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
                                    CareNest Enterprise Reporting Suite
                                </span>
                                <span class="care-pill-badge-green">
                                    <svg class="svg-icon" viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                                    <span id="badge-total-reports">16</span> Verified Reports Live
                                </span>
                            </div>
                            <h2 class="care-module-title slds-m-top_xx-small">Hospital Reports &amp; Analytics Hub</h2>
                            <p class="care-module-desc">Centralized access to certified CareNest Salesforce Lightning reports across financial analytics, hospital bed capacity, patient volume, and clinical audit records.</p>
                        </div>
                        <div class="care-reports-hub-actions">
                            <button class="care-btn-glass" onclick="resetReportsSearch()" title="Reload Reports Registry">
                                <svg class="svg-icon" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M23 4v6h-6"/><path d="M1 20v-6h6"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>
                                <span>Sync Reports</span>
                            </button>
                        </div>
                    </div>

                    <!-- Reports Hub Filter Toolbar -->
                    <div class="care-reports-toolbar slds-m-top_medium">
                        <div class="care-reports-filter-pills">
                            <button id="pill-filter-all" class="care-report-filter-pill care-report-filter-pill-active" onclick="filterReportsCategory('all')">
                                <span>All Reports</span>
                                <span class="care-filter-pill-count">16</span>
                            </button>
                            <button id="pill-filter-financial" class="care-report-filter-pill" onclick="filterReportsCategory('financial')">
                                <span>Financial Analytics</span>
                                <span class="care-filter-pill-count">4</span>
                            </button>
                            <button id="pill-filter-operations" class="care-report-filter-pill" onclick="filterReportsCategory('operations')">
                                <span>Hospital Operations</span>
                                <span class="care-filter-pill-count">3</span>
                            </button>
                            <button id="pill-filter-clinical" class="care-report-filter-pill" onclick="filterReportsCategory('clinical')">
                                <span>Clinical &amp; Physician</span>
                                <span class="care-filter-pill-count">3</span>
                            </button>
                            <button id="pill-filter-additional" class="care-report-filter-pill" onclick="filterReportsCategory('additional')">
                                <span>Additional Operations</span>
                                <span class="care-filter-pill-count">6</span>
                            </button>
                        </div>
                        <div class="care-reports-search-box">
                            <svg class="svg-icon care-reports-search-icon" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="#64748b" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
                            <input id="reports-search-input" type="search" placeholder="Search reports by title or description..." class="care-reports-search-input" oninput="handleReportsSearch(this.value)" />
                            <button id="btn-clear-reports-search" class="care-reports-clear-btn" onclick="clearReportsSearch()" style="display:none;" title="Clear search">
                                <svg class="svg-icon" viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                            </button>
                        </div>
                    </div>

                    <!-- Reports Hub Card Grid -->
                    <div id="reports-hub-grid" class="care-reports-hub-grid slds-m-top_medium">
                        ${generateReportCardsHtml(reportsData)}
                    </div>

                    <!-- Empty Search State -->
                    <div id="reports-empty-state" class="care-reports-empty-state slds-m-top_medium" style="display:none;">
                        <svg class="svg-icon care-empty-icon" viewBox="0 0 24 24" width="36" height="36" fill="none" stroke="#94a3b8" stroke-width="1.5"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
                        <h4 class="care-empty-title">No matching reports found</h4>
                        <p class="care-empty-desc">We couldn't find any certified reports matching "<span id="empty-search-term"></span>". Try another keyword or switch category filters.</p>
                        <button class="care-btn-glass slds-m-top_small" onclick="resetReportsSearch()">
                            Clear Search &amp; Show All
                        </button>
                    </div>
                </div>
            </div>

            <!-- TAB 3: COMMAND CENTER TELEMETRY -->
            <div id="tab-overview" class="tab-content">
                <div class="care-command-center">
                    <div class="care-hero-banner" style="background: linear-gradient(135deg, rgba(15, 23, 42, 0.94) 0%, rgba(15, 23, 42, 0.82) 45%, rgba(13, 148, 136, 0.75) 100%), url('/resource/careNestHeroMedicalSuite') center/cover no-repeat;">
                        <div class="care-hero-overlay-content">
                            <div class="care-hero-badge-row">
                                <span class="care-hero-pill-teal">Tertiary Hospital Care</span>
                                <span class="care-hero-pill-dark">Zero-Trust Stage 2 RBAC</span>
                                <span class="care-hero-pill-dark">Live Telemetry: Online</span>
                                <span class="care-hero-pill-dark">HIPAA &amp; DISHA Compliant</span>
                            </div>
                            <h1 class="care-hero-title">Welcome, Hospital Administration</h1>
                            <p class="care-hero-subtitle">
                                Executive Command Center — Real-time inpatient bed allocation, clinical rounds telemetry, outpatient capacity, and enterprise hospital governance.
                            </p>
                            <div class="care-hero-actions-row">
                                <button class="care-hero-btn-accent" onclick="switchTab('adminOverview')">
                                    <svg class="svg-icon" viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="9"/><rect x="14" y="3" width="7" height="5"/><rect x="14" y="12" width="7" height="9"/><rect x="3" y="16" width="7" height="5"/></svg>
                                    <span>Executive Revenue Analytics</span>
                                </button>
                                <button class="care-hero-btn-secondary" onclick="switchTab('reports')"><span>Reports Hub (16)</span></button>
                                <button class="care-hero-btn-secondary"><span>Inpatient Admissions</span></button>
                                <button class="care-hero-btn-secondary"><span>Schedule OPD Slot</span></button>
                                <button class="care-hero-btn-secondary"><span>Clinical &amp; Vitals</span></button>
                                <button class="care-hero-btn-glass"><span>Sync Live Data</span></button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </main>

        <!-- 4. FOOTER STATUS BAR -->
        <footer class="care-footer-bar">
            <div class="care-footer-container">
                <div class="care-footer-left">
                    <span>CareNest Hospital Management System &copy; 2026. Unified Healthcare Platform • Org ID: 00Dg700000Cpr9pEAB.</span>
                </div>
                <div class="care-footer-right">
                    <span class="care-footer-pill">HIPAA &amp; DISHA Compliant</span>
                    <span class="care-footer-pill">Zero-Trust Isolation</span>
                    <span class="care-footer-pill">Security Mode: Strict RBAC</span>
                    <span class="care-footer-pill">12 Modules Integrated</span>
                </div>
            </div>
        </footer>
    </div>

    <script>
        let currentCategory = 'all';
        let currentSearch = '';

        function switchTab(tabId) {
            document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
            document.querySelectorAll('.care-nav-pill').forEach(el => el.classList.remove('care-nav-pill-active'));
            document.querySelectorAll('.care-mobile-nav-item').forEach(el => el.classList.remove('care-mobile-nav-item-active'));

            const targetTab = document.getElementById('tab-' + tabId);
            if (targetTab) targetTab.classList.add('active');

            const pill = document.getElementById('pill-' + tabId);
            if (pill) pill.classList.add('care-nav-pill-active');

            const drawer = document.getElementById('mobile-drawer');
            if (drawer) drawer.style.display = 'none';

            window.scrollTo({ top: 0, behavior: 'smooth' });
        }

        function toggleMobileMenu() {
            const drawer = document.getElementById('mobile-drawer');
            if (drawer) {
                drawer.style.display = drawer.style.display === 'none' ? 'flex' : 'none';
            }
        }

        function scrollNav(amount) {
            const el = document.getElementById('nav-pills-wrapper');
            if (el) el.scrollBy({ left: amount, behavior: 'smooth' });
        }

        function toggleModulesMenu() {
            alert('All 12 Modules available: Overview, Executive Analytics, Patient Registry, Doctors & Staff, OPD Appointments, Admissions & Beds, Ward Capacity, Clinical Charts, Billing & Payments, Reports Hub, Agentforce AI, System Health.');
        }

        function filterReportsCategory(catKey) {
            currentCategory = catKey;
            document.querySelectorAll('.care-report-filter-pill').forEach(btn => btn.classList.remove('care-report-filter-pill-active'));
            const activeBtn = document.getElementById('pill-filter-' + catKey);
            if (activeBtn) activeBtn.classList.add('care-report-filter-pill-active');
            applyReportsFilter();
        }

        function handleReportsSearch(term) {
            currentSearch = (term || '').trim().toLowerCase();
            const clearBtn = document.getElementById('btn-clear-reports-search');
            if (clearBtn) clearBtn.style.display = currentSearch ? 'inline-flex' : 'none';
            applyReportsFilter();
        }

        function clearReportsSearch() {
            const input = document.getElementById('reports-search-input');
            if (input) input.value = '';
            handleReportsSearch('');
        }

        function resetReportsSearch() {
            clearReportsSearch();
            filterReportsCategory('all');
        }

        function applyReportsFilter() {
            const cards = document.querySelectorAll('.care-report-hub-card');
            let visibleCount = 0;

            cards.forEach(card => {
                const cat = card.getAttribute('data-category');
                const name = card.getAttribute('data-name');
                const desc = card.getAttribute('data-desc');

                const matchesCat = (currentCategory === 'all' || cat === currentCategory);
                const matchesSearch = (!currentSearch || name.includes(currentSearch) || desc.includes(currentSearch));

                if (matchesCat && matchesSearch) {
                    card.style.display = 'flex';
                    visibleCount++;
                } else {
                    card.style.display = 'none';
                }
            });

            const emptyState = document.getElementById('reports-empty-state');
            const grid = document.getElementById('reports-hub-grid');
            if (visibleCount === 0) {
                if (emptyState) {
                    emptyState.style.display = 'flex';
                    const termSpan = document.getElementById('empty-search-term');
                    if (termSpan) termSpan.textContent = currentSearch || currentCategory;
                }
                if (grid) grid.style.display = 'none';
            } else {
                if (emptyState) emptyState.style.display = 'none';
                if (grid) grid.style.display = 'grid';
            }
        }

        // On load check for ?tab= parameter
        window.addEventListener('DOMContentLoaded', () => {
            const params = new URLSearchParams(window.location.search);
            const tab = params.get('tab');
            if (tab) {
                switchTab(tab);
            }
        });
    </script>
</body>
</html>`;

fs.writeFileSync(path.join(__dirname, 'preview_dashboard_v2.html'), htmlTemplate);
console.log('Saved preview to scripts/preview_dashboard_v2.html');

const server = http.createServer((req, res) => {
    if (req.url === '/resource/careNestHeroMedicalSuite') {
        if (fs.existsSync(imgPath)) {
            res.writeHead(200, { 'Content-Type': 'image/jpeg' });
            return fs.createReadStream(imgPath).pipe(res);
        }
    }
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(htmlTemplate);
});

const PORT = process.env.PORT || 8094;
server.listen(PORT, () => {
    console.log(`CareNest Hospital Admin Command Center, Revenue Analytics & Reports Hub preview running on http://localhost:${PORT}`);
});

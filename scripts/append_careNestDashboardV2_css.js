const fs = require('fs');
const path = require('path');

const targetCss = path.join(__dirname, '..', 'force-app', 'main', 'default', 'lwc', 'careNestDashboardV2', 'careNestDashboardV2.css');
let css = fs.readFileSync(targetCss, 'utf8');

const adminCss = `
/* =========================================================================
   EXECUTIVE HOSPITAL ADMIN OVERVIEW & REVENUE ANALYTICS STYLING
   Palette: Medical Teal (#0d9488), Navy (#0f172a), Slate (#64748b), Amber, Rose
   ========================================================================= */

.care-admin-overview-container {
    padding: 0 0 2.5rem 0;
    width: 100%;
}

/* Banner */
.care-admin-banner {
    background: linear-gradient(135deg, #0f172a 0%, #1e293b 60%, #0f766e 100%);
    border-radius: 12px;
    padding: 2rem 2.25rem;
    color: #ffffff;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1.5rem;
    box-shadow: 0 10px 25px -5px rgba(15, 23, 42, 0.25);
    margin-bottom: 1.5rem;
}

.care-admin-banner-content {
    max-width: 800px;
}

.care-admin-badge-row {
    display: flex;
    align-items: center;
    gap: 0.65rem;
    flex-wrap: wrap;
    margin-bottom: 0.75rem;
}

.care-admin-pill-teal {
    background: rgba(13, 148, 136, 0.25);
    border: 1px solid rgba(20, 184, 166, 0.5);
    color: #5eead4;
    font-size: 0.72rem;
    font-weight: 700;
    padding: 0.2rem 0.65rem;
    border-radius: 9999px;
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
}

.care-admin-pill-dark {
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    color: #e2e8f0;
    font-size: 0.72rem;
    font-weight: 600;
    padding: 0.2rem 0.65rem;
    border-radius: 9999px;
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
}

.care-admin-pill-green {
    background: rgba(16, 185, 129, 0.2);
    border: 1px solid rgba(16, 185, 129, 0.4);
    color: #6ee7b7;
    font-size: 0.72rem;
    font-weight: 700;
    padding: 0.2rem 0.65rem;
    border-radius: 9999px;
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
}

.care-admin-title {
    font-size: 1.75rem;
    font-weight: 800;
    color: #ffffff;
    margin: 0 0 0.5rem 0;
    letter-spacing: -0.02em;
}

.care-admin-subtitle {
    font-size: 0.92rem;
    color: #cbd5e1;
    margin: 0;
    line-height: 1.5;
}

.care-admin-banner-actions {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex-shrink: 0;
}

.care-btn-glass {
    background: rgba(255, 255, 255, 0.12);
    border: 1px solid rgba(255, 255, 255, 0.25);
    color: #ffffff;
    font-size: 0.82rem;
    font-weight: 600;
    padding: 0.55rem 1rem;
    border-radius: 8px;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 0.45rem;
    transition: all 0.2s ease;
}

.care-btn-glass:hover {
    background: rgba(255, 255, 255, 0.2);
    border-color: rgba(255, 255, 255, 0.4);
}

.care-btn-primary-teal {
    background: #0d9488;
    border: 1px solid #14b8a6;
    color: #ffffff;
    font-size: 0.82rem;
    font-weight: 700;
    padding: 0.55rem 1.15rem;
    border-radius: 8px;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 0.45rem;
    box-shadow: 0 4px 12px rgba(13, 148, 136, 0.35);
    transition: all 0.2s ease;
}

.care-btn-primary-teal:hover {
    background: #0f766e;
    transform: translateY(-1px);
}

/* Filter Controls Bar */
.care-admin-filter-bar {
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 10px;
    padding: 0.85rem 1.25rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1rem;
    flex-wrap: wrap;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.02);
    margin-bottom: 1.5rem;
}

.care-filter-section-left {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex-wrap: wrap;
}

.care-filter-label {
    font-size: 0.78rem;
    font-weight: 700;
    color: #475569;
    text-transform: uppercase;
    letter-spacing: 0.03em;
}

.care-filter-btn-group {
    display: flex;
    align-items: center;
    background: #f1f5f9;
    border-radius: 8px;
    padding: 3px;
    gap: 2px;
}

.care-filter-btn {
    background: transparent;
    border: none;
    padding: 0.35rem 0.75rem;
    border-radius: 6px;
    font-size: 0.78rem;
    font-weight: 600;
    color: #475569;
    cursor: pointer;
    transition: all 0.15s ease;
}

.care-filter-btn:hover {
    color: #0f172a;
}

.care-filter-btn.active {
    background: #0d9488;
    color: #ffffff;
    box-shadow: 0 2px 4px rgba(13, 148, 136, 0.25);
}

.care-filter-section-right {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex-wrap: wrap;
}

.care-custom-date-inputs {
    display: flex;
    align-items: center;
    gap: 0.4rem;
}

.care-date-picker {
    border: 1px solid #cbd5e1;
    border-radius: 6px;
    padding: 0.35rem 0.5rem;
    font-size: 0.78rem;
    color: #1e293b;
    outline: none;
}

.care-date-sep {
    font-size: 0.78rem;
    color: #64748b;
}

.care-dropdown-select {
    border: 1px solid #cbd5e1;
    border-radius: 6px;
    padding: 0.4rem 0.75rem;
    font-size: 0.8rem;
    font-weight: 600;
    color: #1e293b;
    background: #ffffff;
    outline: none;
    cursor: pointer;
}

.care-btn-export-csv {
    background: #f0fdfa;
    border: 1px solid #99f6e4;
    color: #0f766e;
    font-size: 0.8rem;
    font-weight: 700;
    padding: 0.4rem 0.85rem;
    border-radius: 6px;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    transition: all 0.15s ease;
}

.care-btn-export-csv:hover {
    background: #ccfbf1;
    border-color: #5eead4;
}

/* 12 Executive Financial KPI Grid */
.care-admin-kpi-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 1rem;
    margin-bottom: 1.5rem;
}

.care-fin-kpi-card {
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 10px;
    padding: 1.15rem 1.25rem;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.02);
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.care-fin-kpi-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.05);
}

.care-fin-kpi-highlight-teal {
    border-left: 4px solid #0d9488;
}

.care-fin-kpi-highlight-navy {
    border-left: 4px solid #0f172a;
}

.care-fin-kpi-highlight-amber {
    border-left: 4px solid #f59e0b;
}

.care-fin-kpi-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.5rem;
}

.care-fin-kpi-title {
    font-size: 0.78rem;
    font-weight: 700;
    color: #64748b;
    text-transform: uppercase;
    letter-spacing: 0.02em;
}

.care-fin-kpi-val {
    font-size: 1.65rem;
    font-weight: 800;
    color: #0f172a;
    letter-spacing: -0.02em;
    margin-bottom: 0.35rem;
}

.care-fin-kpi-sub {
    font-size: 0.75rem;
    color: #64748b;
    font-weight: 500;
}

/* KPI Tag Pills */
.care-tag-teal {
    background: #ccfbf1;
    color: #0f766e;
    font-size: 0.68rem;
    font-weight: 700;
    padding: 0.15rem 0.5rem;
    border-radius: 9999px;
}

.care-tag-navy {
    background: #e2e8f0;
    color: #0f172a;
    font-size: 0.68rem;
    font-weight: 700;
    padding: 0.15rem 0.5rem;
    border-radius: 9999px;
}

.care-tag-slate {
    background: #f1f5f9;
    color: #475569;
    font-size: 0.68rem;
    font-weight: 700;
    padding: 0.15rem 0.5rem;
    border-radius: 9999px;
}

.care-tag-amber {
    background: #fef3c7;
    color: #b45309;
    font-size: 0.68rem;
    font-weight: 700;
    padding: 0.15rem 0.5rem;
    border-radius: 9999px;
}

.care-tag-green {
    background: #dcfce7;
    color: #15803d;
    font-size: 0.68rem;
    font-weight: 700;
    padding: 0.15rem 0.5rem;
    border-radius: 9999px;
}

.care-kpi-ico-green { --slds-c-icon-color-foreground-default: #10b981; }
.care-kpi-ico-blue { --slds-c-icon-color-foreground-default: #3b82f6; }
.care-kpi-ico-navy { --slds-c-icon-color-foreground-default: #0f172a; }
.care-kpi-ico-red { --slds-c-icon-color-foreground-default: #ef4444; }
.care-kpi-ico-teal { --slds-c-icon-color-foreground-default: #0d9488; }

/* 2-Column Interactive Financial Charts Grid */
.care-admin-charts-grid {
    display: grid;
    grid-template-columns: 58% 40%;
    gap: 1.5rem;
    align-items: start;
}

.care-chart-card {
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 10px;
    padding: 1.25rem 1.5rem;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.02);
}

.care-chart-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 1rem;
    padding-bottom: 0.65rem;
    border-bottom: 1px solid #f1f5f9;
}

.care-chart-title {
    font-size: 0.95rem;
    font-weight: 700;
    color: #0f172a;
    margin: 0 0 0.2rem 0;
}

.care-chart-subtitle {
    font-size: 0.78rem;
    color: #64748b;
    margin: 0;
}

/* SVG Chart Elements */
.care-svg-chart-container {
    width: 100%;
    position: relative;
}

.care-trend-svg, .care-bars-svg {
    width: 100%;
    height: auto;
    overflow: visible;
}

.care-svg-axis-label {
    font-size: 11px;
    fill: #64748b;
    font-weight: 600;
}

.care-svg-val-label {
    font-size: 11px;
    fill: #0d9488;
    font-weight: 700;
}

.care-svg-bar-teal {
    fill: #0d9488;
    transition: fill 0.15s ease;
}

.care-svg-bar-teal:hover {
    fill: #0f766e;
    cursor: pointer;
}

.care-svg-bar-empty {
    fill: #f1f5f9;
}

.care-bar-dates-row {
    display: flex;
    justify-content: space-between;
    font-size: 0.72rem;
    color: #94a3b8;
    font-weight: 600;
    margin-top: 0.25rem;
}

/* Comparative Bars */
.care-comparative-bars-list {
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
    margin-top: 0.5rem;
}

.care-comp-bar-row {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
}

.care-comp-bar-label-col {
    display: flex;
    justify-content: space-between;
    font-size: 0.82rem;
}

.care-comp-bar-label {
    font-weight: 600;
    color: #334155;
}

.care-comp-bar-val {
    font-weight: 700;
    color: #0f172a;
}

.care-comp-bar-track {
    width: 100%;
    height: 10px;
    background: #f1f5f9;
    border-radius: 9999px;
    overflow: hidden;
}

.care-bar-navy { background-color: #0f172a; height: 100%; border-radius: 9999px; }
.care-bar-teal { background-color: #0d9488; height: 100%; border-radius: 9999px; }
.care-bar-amber { background-color: #f59e0b; height: 100%; border-radius: 9999px; }
.care-bar-rose { background-color: #ef4444; height: 100%; border-radius: 9999px; }
.care-bar-green { background-color: #10b981; height: 100%; border-radius: 9999px; }
.care-bar-red { background-color: #dc2626; height: 100%; border-radius: 9999px; }

/* Department & Method Breakdown Slices */
.care-slices-breakdown {
    display: flex;
    flex-direction: column;
    gap: 0.65rem;
}

.care-slice-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.45rem 0.6rem;
    border-radius: 6px;
    background: #f8fafc;
    border: 1px solid #f1f5f9;
}

.care-slice-left {
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.care-slice-color-dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    flex-shrink: 0;
}

.care-slice-name {
    font-size: 0.82rem;
    font-weight: 600;
    color: #1e293b;
}

.care-slice-right {
    display: flex;
    align-items: center;
    gap: 0.45rem;
}

.care-slice-amt {
    font-size: 0.85rem;
    font-weight: 700;
    color: #0f172a;
}

.care-slice-pct {
    font-size: 0.75rem;
    color: #64748b;
}

/* Receivables Aging */
.care-aging-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
}

.care-aging-row {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
}

.care-aging-meta {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.8rem;
}

.care-aging-bracket {
    font-weight: 600;
    color: #1e293b;
}

.care-aging-amt {
    font-weight: 700;
    color: #0f172a;
}

.care-aging-track {
    width: 100%;
    height: 8px;
    background: #f1f5f9;
    border-radius: 9999px;
    overflow: hidden;
}

/* Doctor Revenue Ranked */
.care-doctor-rev-list {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    max-height: 280px;
    overflow-y: auto;
}

.care-doc-rev-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.4rem 0.5rem;
    border-radius: 6px;
    background: #f8fafc;
    border: 1px solid #f1f5f9;
}

.care-doc-rev-info {
    display: flex;
    align-items: center;
    gap: 0.45rem;
}

.care-doc-rev-rank {
    font-size: 0.72rem;
    font-weight: 800;
    color: #0d9488;
    background: #ccfbf1;
    padding: 0.1rem 0.35rem;
    border-radius: 4px;
}

.care-doc-rev-name {
    font-size: 0.82rem;
    font-weight: 600;
    color: #0f172a;
}

.care-doc-rev-dept {
    font-size: 0.72rem;
    color: #64748b;
}

.care-doc-rev-amt {
    font-size: 0.85rem;
    font-weight: 700;
    color: #0d9488;
}

/* Operations Analytics Panels (Step 4) */
.care-admin-operations-section {
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 10px;
    padding: 1.5rem;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.02);
}

.care-ops-matrix-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 1.25rem;
    margin-top: 1rem;
}

.care-ops-box {
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    padding: 1rem 1.15rem;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
}

.care-ops-box-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.5rem;
}

.care-ops-box-title {
    font-size: 0.75rem;
    font-weight: 700;
    color: #475569;
    text-transform: uppercase;
}

.care-ops-metric-large {
    font-size: 2rem;
    font-weight: 800;
    color: #0f172a;
    letter-spacing: -0.02em;
    margin-bottom: 0.75rem;
}

.care-ops-breakdown {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
    font-size: 0.78rem;
    color: #64748b;
    border-top: 1px solid #e2e8f0;
    padding-top: 0.5rem;
}

.care-ops-stat {
    display: flex;
    justify-content: space-between;
    align-items: center;
}

/* Recent Financial Transactions Table */
.care-table-search-box {
    width: 260px;
}

.care-search-input {
    width: 100%;
    border: 1px solid #cbd5e1;
    border-radius: 6px;
    padding: 0.4rem 0.75rem;
    font-size: 0.8rem;
    outline: none;
}

.care-search-input:focus {
    border-color: #0d9488;
    box-shadow: 0 0 0 2px rgba(13, 148, 136, 0.2);
}

.care-table-responsive-wrapper {
    overflow-x: auto;
    width: 100%;
}

.care-data-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.82rem;
}

.care-data-table th {
    background: #f8fafc;
    color: #475569;
    font-weight: 700;
    text-transform: uppercase;
    font-size: 0.72rem;
    letter-spacing: 0.03em;
    padding: 0.65rem 0.85rem;
    border-bottom: 1px solid #e2e8f0;
    text-align: left;
}

.care-data-table td {
    padding: 0.75rem 0.85rem;
    border-bottom: 1px solid #f1f5f9;
    color: #1e293b;
}

.care-data-table tbody tr:hover {
    background-color: #f0fdfa;
}

.care-text-right { text-align: right; }
.care-text-teal { color: #0d9488; }
.care-text-muted { color: #64748b; font-size: 0.75rem; }
.care-font-bold { font-weight: 700; }

/* Salesforce Reports Hub Grid (Step 7) */
.care-reports-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
    margin-top: 1rem;
}

.care-report-link-card {
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    padding: 0.85rem 1rem;
    display: flex;
    align-items: center;
    gap: 0.75rem;
    text-decoration: none;
    transition: all 0.15s ease;
}

.care-report-link-card:hover {
    background: #f0fdfa;
    border-color: #99f6e4;
    transform: translateY(-1px);
    box-shadow: 0 4px 10px rgba(13, 148, 136, 0.1);
}

.care-report-card-icon {
    flex-shrink: 0;
}

.care-report-card-content {
    flex-grow: 1;
}

.care-report-name {
    font-size: 0.82rem;
    font-weight: 700;
    color: #0f172a;
    margin-bottom: 0.15rem;
}

.care-report-cat {
    font-size: 0.72rem;
    color: #64748b;
}

.care-report-ext-icon {
    flex-shrink: 0;
    --slds-c-icon-color-foreground-default: #94a3b8;
}

/* Button accent for hero */
.care-hero-btn-accent {
    background: #0d9488;
    border: 1px solid #14b8a6;
    color: #ffffff;
    font-size: 0.85rem;
    font-weight: 700;
    padding: 0.55rem 1rem;
    border-radius: 8px;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 0.45rem;
    box-shadow: 0 4px 12px rgba(13, 148, 136, 0.4);
    transition: all 0.2s ease;
}

.care-hero-btn-accent:hover {
    background: #0f766e;
    transform: translateY(-1px);
}

/* Responsive Overrides */
@media (max-width: 1200px) {
    .care-admin-kpi-grid {
        grid-template-columns: repeat(3, 1fr);
    }
    .care-admin-charts-grid {
        grid-template-columns: 1fr;
    }
    .care-ops-matrix-grid {
        grid-template-columns: repeat(2, 1fr);
    }
    .care-reports-grid {
        grid-template-columns: repeat(2, 1fr);
    }
}

@media (max-width: 820px) {
    .care-admin-banner {
        flex-direction: column;
        align-items: flex-start;
        padding: 1.5rem;
    }
    .care-admin-banner-actions {
        width: 100%;
        justify-content: flex-start;
    }
    .care-admin-kpi-grid {
        grid-template-columns: repeat(2, 1fr);
    }
    .care-admin-filter-bar {
        flex-direction: column;
        align-items: flex-start;
    }
    .care-filter-section-right {
        width: 100%;
        justify-content: space-between;
    }
    .care-ops-matrix-grid {
        grid-template-columns: 1fr;
    }
    .care-reports-grid {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 480px) {
    .care-admin-kpi-grid {
        grid-template-columns: 1fr;
    }
}
`;

fs.appendFileSync(targetCss, adminCss, 'utf8');
console.log('Appended admin overview styles to careNestDashboardV2.css successfully');

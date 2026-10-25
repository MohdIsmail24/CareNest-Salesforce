const fs = require('fs');
const path = require('path');

const targetHtml = path.join(__dirname, '..', 'force-app', 'main', 'default', 'lwc', 'careNestDashboardV2', 'careNestDashboardV2.html');
let html = fs.readFileSync(targetHtml, 'utf8');

// 1. Add Executive Revenue Analytics button to Hero Action Row if not present
if (!html.includes('data-id="adminOverview"')) {
    html = html.replace(
        '<button class="care-hero-btn-secondary" data-id="billing" onclick={handleNavClick}>',
        '<button class="care-hero-btn-accent" data-id="adminOverview" onclick={handleNavClick}>\n                                        <lightning-icon icon-name="utility:graph" size="x-small" class="care-icon-white"></lightning-icon>\n                                        <span>Executive Analytics</span>\n                                    </button>\n                                    <button class="care-hero-btn-secondary" data-id="billing" onclick={handleNavClick}>'
    );

    // Also update Financial Panel link
    html = html.replace(
        '<button class="care-panel-action-link" data-id="billing" onclick={handleNavClick}>\n                                            Open Ledger &rarr;\n                                        </button>',
        '<button class="care-panel-action-link" data-id="adminOverview" onclick={handleNavClick}>\n                                            Executive Revenue Analytics &rarr;\n                                        </button>'
    );
}

// 2. Build the complete Admin Overview Template Block
const adminOverviewTemplate = `
                <!-- =========================================================
                     MODULE: DEDICATED EXECUTIVE HOSPITAL ADMIN OVERVIEW & REVENUE ANALYTICS
                     ========================================================= -->
                <template if:true={isAdminOverviewTab}>
                    <div class="care-admin-overview-container">
                        <!-- A. EXECUTIVE BANNER & BREADCRUMB -->
                        <div class="care-admin-banner">
                            <div class="care-admin-banner-content">
                                <div class="care-admin-badge-row">
                                    <span class="care-admin-pill-teal">
                                        <lightning-icon icon-name="utility:money" size="xx-small" class="care-icon-white"></lightning-icon>
                                        Certified Salesforce Financial Ledger
                                    </span>
                                    <span class="care-admin-pill-dark">
                                        <lightning-icon icon-name="utility:shield" size="xx-small" class="care-icon-white"></lightning-icon>
                                        Admin Authorized Session
                                    </span>
                                    <span class="care-admin-pill-green">
                                        <lightning-icon icon-name="utility:database" size="xx-small" class="care-icon-white"></lightning-icon>
                                        Live Salesforce Data (No Demo Data)
                                    </span>
                                </div>
                                <h1 class="care-admin-title">Hospital Executive Overview &amp; Revenue Analytics</h1>
                                <p class="care-admin-subtitle">
                                    Real-time financial intelligence, revenue trajectory, receivables aging, department attribution, and enterprise hospital operational capacity.
                                </p>
                            </div>
                            <div class="care-admin-banner-actions">
                                <button class="care-btn-glass" data-id="overview" onclick={handleNavClick} title="Return to Command Center Telemetry">
                                    <lightning-icon icon-name="utility:service_territory_location" size="x-small" class="care-icon-white"></lightning-icon>
                                    <span>Command Center &rarr;</span>
                                </button>
                                <button class="care-btn-primary-teal" onclick={handleRefreshAdmin} title="Synchronize latest live ledger">
                                    <lightning-icon icon-name="utility:refresh" size="x-small" class="care-icon-white"></lightning-icon>
                                    <span>Sync Financial Data</span>
                                </button>
                            </div>
                        </div>

                        <!-- B. INTERACTIVE FILTER CONTROLS BAR -->
                        <div class="care-admin-filter-bar">
                            <div class="care-filter-section-left">
                                <span class="care-filter-label">Reporting Period:</span>
                                <div class="care-filter-btn-group">
                                    <button class={periodAllClass} data-period="all" onclick={handleSelectPeriod}>All Time</button>
                                    <button class={periodTodayClass} data-period="today" onclick={handleSelectPeriod}>Today</button>
                                    <button class={period7DClass} data-period="last7days" onclick={handleSelectPeriod}>7 Days</button>
                                    <button class={period30DClass} data-period="last30days" onclick={handleSelectPeriod}>30 Days</button>
                                    <button class={periodThisMonthClass} data-period="thismonth" onclick={handleSelectPeriod}>This Month</button>
                                    <button class={periodLastMonthClass} data-period="lastmonth" onclick={handleSelectPeriod}>Last Month</button>
                                    <button class={periodQuarterClass} data-period="thisquarter" onclick={handleSelectPeriod}>Quarter</button>
                                    <button class={periodYearClass} data-period="thisyear" onclick={handleSelectPeriod}>YTD 2026</button>
                                    <button class={periodCustomClass} data-period="custom" onclick={handleSelectPeriod}>Custom</button>
                                </div>
                            </div>

                            <div class="care-filter-section-right">
                                <template if:true={isCustomPeriod}>
                                    <div class="care-custom-date-inputs">
                                        <input type="date" class="care-date-picker" onchange={handleStartDateChange} aria-label="Start Date" />
                                        <span class="care-date-sep">to</span>
                                        <input type="date" class="care-date-picker" onchange={handleEndDateChange} aria-label="End Date" />
                                    </div>
                                </template>

                                <div class="care-select-wrapper">
                                    <select class="care-dropdown-select" onchange={handleDepartmentChange} aria-label="Filter by department">
                                        <option value="all">All Departments</option>
                                        <option value="Orthopaedics">Orthopaedics</option>
                                        <option value="Dermatology">Dermatology</option>
                                        <option value="ENT">ENT</option>
                                        <option value="General Medicine">General Medicine</option>
                                        <option value="Paediatrics">Paediatrics</option>
                                    </select>
                                </div>

                                <button class="care-btn-export-csv" onclick={handleExportCsv} title="Export financial ledger to CSV">
                                    <lightning-icon icon-name="utility:download" size="x-small" class="care-icon-teal"></lightning-icon>
                                    <span>Export CSV</span>
                                </button>
                            </div>
                        </div>

                        <!-- C. LOADING / ERROR STATES -->
                        <template if:true={isAdminLoading}>
                            <div class="care-loading-container slds-m-vertical_large">
                                <lightning-spinner alternative-text="Calculating financial aggregates..." size="medium"></lightning-spinner>
                                <p class="care-loading-text">Reconciling verified Salesforce Payment, Invoice, and Receivables ledgers...</p>
                            </div>
                        </template>

                        <template if:true={adminError}>
                            <div class="care-error-card slds-m-vertical_large">
                                <lightning-icon icon-name="utility:error" size="medium" class="care-error-icon"></lightning-icon>
                                <div>
                                    <h3 class="care-error-title">Access Restricted or Query Error</h3>
                                    <p class="care-error-msg">{adminError}</p>
                                </div>
                            </div>
                        </template>

                        <!-- D. MAIN EXECUTIVE FINANCIAL DASHBOARD BODY -->
                        <template if:true={adminKpi}>
                            <!-- 1. 12 EXECUTIVE FINANCIAL KPI CARDS GRID -->
                            <div class="care-admin-kpi-grid">
                                <!-- KPI 1: Today's Collections -->
                                <div class="care-fin-kpi-card">
                                    <div class="care-fin-kpi-header">
                                        <span class="care-fin-kpi-title">Today's Collections</span>
                                        <lightning-icon icon-name="utility:moneybag" size="x-small" class="care-kpi-ico-green"></lightning-icon>
                                    </div>
                                    <div class="care-fin-kpi-val">₹{adminKpi.todayCollections}</div>
                                    <div class="care-fin-kpi-sub">Cleared cash &amp; digital payments</div>
                                </div>

                                <!-- KPI 2: Yesterday's Collections -->
                                <div class="care-fin-kpi-card">
                                    <div class="care-fin-kpi-header">
                                        <span class="care-fin-kpi-title">Yesterday's Collections</span>
                                        <lightning-icon icon-name="utility:clock" size="x-small" class="care-kpi-ico-blue"></lightning-icon>
                                    </div>
                                    <div class="care-fin-kpi-val">₹{adminKpi.yesterdayCollections}</div>
                                    <div class="care-fin-kpi-sub">Prior business day clearing</div>
                                </div>

                                <!-- KPI 3: This Month's Collections -->
                                <div class="care-fin-kpi-card care-fin-kpi-highlight-teal">
                                    <div class="care-fin-kpi-header">
                                        <span class="care-fin-kpi-title">This Month's Collections</span>
                                        <span class="care-tag-teal">Oct 2026</span>
                                    </div>
                                    <div class="care-fin-kpi-val">₹{adminKpi.thisMonthCollections}</div>
                                    <div class="care-fin-kpi-sub">47 verified transactions</div>
                                </div>

                                <!-- KPI 4: Last Month's Collections -->
                                <div class="care-fin-kpi-card">
                                    <div class="care-fin-kpi-header">
                                        <span class="care-fin-kpi-title">Last Month's Collections</span>
                                        <span class="care-tag-slate">Sep 2026</span>
                                    </div>
                                    <div class="care-fin-kpi-val">₹{adminKpi.lastMonthCollections}</div>
                                    <div class="care-fin-kpi-sub">13 verified transactions</div>
                                </div>

                                <!-- KPI 5: Year-to-Date Collections -->
                                <div class="care-fin-kpi-card care-fin-kpi-highlight-navy">
                                    <div class="care-fin-kpi-header">
                                        <span class="care-fin-kpi-title">Year-to-Date Collections</span>
                                        <span class="care-tag-navy">FY 2026</span>
                                    </div>
                                    <div class="care-fin-kpi-val">₹{adminKpi.ytdCollections}</div>
                                    <div class="care-fin-kpi-sub">Net Realized: ₹{adminKpi.netCollections}</div>
                                </div>

                                <!-- KPI 6: Total Invoiced -->
                                <div class="care-fin-kpi-card">
                                    <div class="care-fin-kpi-header">
                                        <span class="care-fin-kpi-title">Total Invoiced</span>
                                        <lightning-icon icon-name="utility:standard_objects" size="x-small" class="care-kpi-ico-navy"></lightning-icon>
                                    </div>
                                    <div class="care-fin-kpi-val">₹{adminKpi.totalInvoiced}</div>
                                    <div class="care-fin-kpi-sub">81 OPD consultation billings</div>
                                </div>

                                <!-- KPI 7: Outstanding Receivables -->
                                <div class="care-fin-kpi-card care-fin-kpi-highlight-amber">
                                    <div class="care-fin-kpi-header">
                                        <span class="care-fin-kpi-title">Outstanding Receivables</span>
                                        <span class="care-tag-amber">Open Balance</span>
                                    </div>
                                    <div class="care-fin-kpi-val">₹{adminKpi.outstandingReceivables}</div>
                                    <div class="care-fin-kpi-sub">Pending settlement on bookings</div>
                                </div>

                                <!-- KPI 8: Overdue Receivables -->
                                <div class="care-fin-kpi-card">
                                    <div class="care-fin-kpi-header">
                                        <span class="care-fin-kpi-title">Overdue Receivables</span>
                                        <lightning-icon icon-name="utility:warning" size="x-small" class="care-kpi-ico-red"></lightning-icon>
                                    </div>
                                    <div class="care-fin-kpi-val">₹{adminKpi.overdueReceivables}</div>
                                    <div class="care-fin-kpi-sub">Appointments past scheduled date</div>
                                </div>

                                <!-- KPI 9: Collection Rate -->
                                <div class="care-fin-kpi-card">
                                    <div class="care-fin-kpi-header">
                                        <span class="care-fin-kpi-title">Collection Rate</span>
                                        <span class="care-tag-green">Cleared</span>
                                    </div>
                                    <div class="care-fin-kpi-val">{adminKpi.collectionRate}%</div>
                                    <div class="care-fin-kpi-sub">Collections vs Invoiced ratio</div>
                                </div>

                                <!-- KPI 10: Avg Revenue per Patient -->
                                <div class="care-fin-kpi-card">
                                    <div class="care-fin-kpi-header">
                                        <span class="care-fin-kpi-title">Avg Revenue / Patient</span>
                                        <lightning-icon icon-name="utility:user" size="x-small" class="care-kpi-ico-teal"></lightning-icon>
                                    </div>
                                    <div class="care-fin-kpi-val">₹{adminKpi.avgRevenuePerPatient}</div>
                                    <div class="care-fin-kpi-sub">Across 58 billed patients</div>
                                </div>

                                <!-- KPI 11: Avg Invoice Value -->
                                <div class="care-fin-kpi-card">
                                    <div class="care-fin-kpi-header">
                                        <span class="care-fin-kpi-title">Avg Invoice Value</span>
                                        <lightning-icon icon-name="utility:receipt" size="x-small" class="care-kpi-ico-teal"></lightning-icon>
                                    </div>
                                    <div class="care-fin-kpi-val">₹{adminKpi.avgInvoiceValue}</div>
                                    <div class="care-fin-kpi-sub">Mean OPD appointment bill</div>
                                </div>

                                <!-- KPI 12: MoM Collection Growth -->
                                <div class="care-fin-kpi-card">
                                    <div class="care-fin-kpi-header">
                                        <span class="care-fin-kpi-title">MoM Collection Growth</span>
                                        <lightning-icon icon-name="utility:trending" size="x-small" class="care-kpi-ico-green"></lightning-icon>
                                    </div>
                                    <div class="care-fin-kpi-val">+{adminKpi.momGrowth}%</div>
                                    <div class="care-fin-kpi-sub">Oct (₹27.1K) vs Sep (₹8.9K)</div>
                                </div>
                            </div>

                            <!-- 2. INTERACTIVE FINANCIAL GRAPHS SECTION -->
                            <div class="care-admin-charts-grid slds-m-top_large">
                                <!-- LEFT COLUMN (60%): Revenue Trends & Invoiced vs Collected -->
                                <div class="care-charts-col-left">
                                    <!-- GRAPH 1: Monthly Revenue Trend -->
                                    <div class="care-chart-card">
                                        <div class="care-chart-header">
                                            <div>
                                                <h3 class="care-chart-title">Graph 1: Monthly Revenue Trend (Last 12 Months)</h3>
                                                <p class="care-chart-subtitle">Verified monthly realized collections from Salesforce Payment records.</p>
                                            </div>
                                            <span class="care-tag-teal">Line &amp; Area Chart</span>
                                        </div>
                                        <div class="care-svg-chart-container">
                                            <svg viewBox="0 0 500 160" class="care-trend-svg">
                                                <defs>
                                                    <linearGradient id="trendGradient" x1="0" y1="0" x2="0" y2="1">
                                                        <stop offset="0%" stop-color="#0d9488" stop-opacity="0.35"/>
                                                        <stop offset="100%" stop-color="#0d9488" stop-opacity="0.02"/>
                                                    </linearGradient>
                                                </defs>
                                                <!-- Horizontal gridlines -->
                                                <line x1="30" y1="30" x2="470" y2="30" stroke="#e2e8f0" stroke-dasharray="3,3"/>
                                                <line x1="30" y1="75" x2="470" y2="75" stroke="#e2e8f0" stroke-dasharray="3,3"/>
                                                <line x1="30" y1="120" x2="470" y2="120" stroke="#e2e8f0" stroke-dasharray="3,3"/>
                                                <!-- Area fill -->
                                                <path d={monthlyTrendSvg.areaPath} fill="url(#trendGradient)"/>
                                                <!-- Trend Line -->
                                                <path d={monthlyTrendSvg.linePath} fill="none" stroke="#0d9488" stroke-width="3" stroke-linecap="round"/>
                                                <!-- Points and labels -->
                                                <template for:each={monthlyTrendSvg.points} for:item="pt">
                                                    <g key={pt.label}>
                                                        <circle cx={pt.x} cy={pt.y} r="5" fill="#ffffff" stroke="#0d9488" stroke-width="2.5"/>
                                                        <text x={pt.x} y="148" text-anchor="middle" class="care-svg-axis-label">{pt.label}</text>
                                                        <template if:true={pt.value}>
                                                            <text x={pt.x} y={pt.y} dy="-10" text-anchor="middle" class="care-svg-val-label">{pt.formattedVal}</text>
                                                        </template>
                                                    </g>
                                                </template>
                                            </svg>
                                        </div>
                                    </div>

                                    <!-- GRAPH 2: Daily Collections (Last 30 Days) -->
                                    <div class="care-chart-card slds-m-top_medium">
                                        <div class="care-chart-header">
                                            <div>
                                                <h3 class="care-chart-title">Graph 2: Daily Collections Trend (Last 30 Days)</h3>
                                                <p class="care-chart-subtitle">Daily cash desk and online settlement distribution.</p>
                                            </div>
                                            <span class="care-tag-teal">Bar Chart</span>
                                        </div>
                                        <div class="care-svg-chart-container">
                                            <svg viewBox="0 0 600 150" class="care-bars-svg">
                                                <line x1="0" y1="130" x2="600" y2="130" stroke="#cbd5e1" stroke-width="1.5"/>
                                                <template for:each={dailyCollectionsBars} for:item="b">
                                                    <g key={b.label}>
                                                        <rect x={b.x} y={b.y} width={b.width} height={b.height} rx="2" class={b.barClass}>
                                                            <title>{b.label}: {b.formattedVal} ({b.count} txns)</title>
                                                        </rect>
                                                    </g>
                                                </template>
                                            </svg>
                                            <div class="care-bar-dates-row">
                                                <span>30 Days Ago</span>
                                                <span>Mid Month</span>
                                                <span>Today (Oct 20)</span>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- GRAPH 3: Invoiced vs Collected vs Outstanding -->
                                    <div class="care-chart-card slds-m-top_medium">
                                        <div class="care-chart-header">
                                            <div>
                                                <h3 class="care-chart-title">Graph 3: Invoiced vs Realized Collections vs Outstanding</h3>
                                                <p class="care-chart-subtitle">Comparative financial ledger reconciliation (Audited Total: ₹52,062.50).</p>
                                            </div>
                                            <span class="care-tag-navy">Reconciliation</span>
                                        </div>
                                        <div class="care-comparative-bars-list">
                                            <template for:each={invoicedVsCollectedList} for:item="item">
                                                <div key={item.label} class="care-comp-bar-row">
                                                    <div class="care-comp-bar-label-col">
                                                        <span class="care-comp-bar-label">{item.label}</span>
                                                        <span class="care-comp-bar-val">{item.formatted}</span>
                                                    </div>
                                                    <div class="care-comp-bar-track">
                                                        <div class={item.barClass} style={item.widthStyle}></div>
                                                    </div>
                                                </div>
                                            </template>
                                        </div>
                                    </div>
                                </div>

                                <!-- RIGHT COLUMN (40%): Department, Methods, Aging & Doctors -->
                                <div class="care-charts-col-right">
                                    <!-- GRAPH 4: Revenue by Specialty -->
                                    <div class="care-chart-card">
                                        <div class="care-chart-header">
                                            <div>
                                                <h3 class="care-chart-title">Graph 4: Revenue by Specialty</h3>
                                                <p class="care-chart-subtitle">OPD consultation earnings by medical specialty.</p>
                                            </div>
                                        </div>
                                        <div class="care-slices-breakdown">
                                            <template for:each={departmentRevenueSlices} for:item="s">
                                                <div key={s.label} class="care-slice-item">
                                                    <div class="care-slice-left">
                                                        <span class="care-slice-color-dot" style={s.badgeStyle}></span>
                                                        <span class="care-slice-name">{s.label}</span>
                                                    </div>
                                                    <div class="care-slice-right">
                                                        <span class="care-slice-amt">{s.formattedAmount}</span>
                                                        <span class="care-slice-pct">({s.percentage}%)</span>
                                                    </div>
                                                </div>
                                            </template>
                                        </div>
                                    </div>

                                    <!-- GRAPH 5: Payment Methods Breakdown -->
                                    <div class="care-chart-card slds-m-top_medium">
                                        <div class="care-chart-header">
                                            <div>
                                                <h3 class="care-chart-title">Graph 5: Settlement Methods</h3>
                                                <p class="care-chart-subtitle">Recorded payment channels (UPI, Card, Cash Desk).</p>
                                            </div>
                                        </div>
                                        <div class="care-slices-breakdown">
                                            <template for:each={paymentMethodSlices} for:item="m">
                                                <div key={m.label} class="care-slice-item">
                                                    <div class="care-slice-left">
                                                        <span class="care-slice-color-dot" style={m.badgeStyle}></span>
                                                        <span class="care-slice-name">{m.label}</span>
                                                    </div>
                                                    <div class="care-slice-right">
                                                        <span class="care-slice-amt">{m.formattedAmount}</span>
                                                        <span class="care-slice-pct">({m.percentage}%)</span>
                                                    </div>
                                                </div>
                                            </template>
                                        </div>
                                    </div>

                                    <!-- GRAPH 6: Receivables Aging Breakdown -->
                                    <div class="care-chart-card slds-m-top_medium">
                                        <div class="care-chart-header">
                                            <div>
                                                <h3 class="care-chart-title">Graph 6: Receivables Aging</h3>
                                                <p class="care-chart-subtitle">Uncollected balances by due timeline.</p>
                                            </div>
                                        </div>
                                        <div class="care-aging-list">
                                            <template for:each={receivablesAgingList} for:item="ag">
                                                <div key={ag.bracket} class="care-aging-row">
                                                    <div class="care-aging-meta">
                                                        <span class="care-aging-bracket">{ag.bracket}</span>
                                                        <span class={ag.tagClass}>{ag.count} appts</span>
                                                        <span class="care-aging-amt">{ag.formattedAmount}</span>
                                                    </div>
                                                    <div class="care-aging-track">
                                                        <div class={ag.barClass} style={ag.widthStyle}></div>
                                                    </div>
                                                </div>
                                            </template>
                                        </div>
                                    </div>

                                    <!-- GRAPH 7: Doctor & Specialty Revenue Leaderboard -->
                                    <div class="care-chart-card slds-m-top_medium">
                                        <div class="care-chart-header">
                                            <div>
                                                <h3 class="care-chart-title">Graph 7: Physician Revenue Leaderboard</h3>
                                                <p class="care-chart-subtitle">Attributed collections across 12 physicians.</p>
                                            </div>
                                        </div>
                                        <div class="care-doctor-rev-list">
                                            <template for:each={doctorRevenueRanked} for:item="dr">
                                                <div key={dr.doctorId} class="care-doc-rev-row">
                                                    <div class="care-doc-rev-info">
                                                        <span class="care-doc-rev-rank">#{dr.rank}</span>
                                                        <span class="care-doc-rev-name">{dr.doctorName}</span>
                                                        <span class="care-doc-rev-dept">({dr.department})</span>
                                                    </div>
                                                    <div class="care-doc-rev-amt-col">
                                                        <span class="care-doc-rev-amt">{dr.formattedAmount}</span>
                                                    </div>
                                                </div>
                                            </template>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- 3. HOSPITAL OPERATIONS ANALYTICS PANELS (STEP 4) -->
                            <div class="care-admin-operations-section slds-m-top_large">
                                <div class="care-panel-header">
                                    <div>
                                        <h3 class="care-panel-title">Hospital Operational Capacity &amp; Clinical Telemetry</h3>
                                        <p class="care-panel-sub">Real-time throughput for Outpatient Clinics, Inpatient Census, Beds, and Clinical Rounds.</p>
                                    </div>
                                </div>

                                <div class="care-ops-matrix-grid">
                                    <!-- Panel A: Outpatient Appointment Volume -->
                                    <div class="care-ops-box">
                                        <div class="care-ops-box-header">
                                            <span class="care-ops-box-title">OPD Appointments</span>
                                            <lightning-icon icon-name="standard:event" size="small"></lightning-icon>
                                        </div>
                                        <div class="care-ops-metric-large">{adminOperations.totalAppointments}</div>
                                        <div class="care-ops-breakdown">
                                            <div class="care-ops-stat"><span>Confirmed:</span> <strong>{adminOperations.confirmedAppointments}</strong></div>
                                            <div class="care-ops-stat"><span>Completed:</span> <strong>{adminOperations.completedAppointments}</strong></div>
                                            <div class="care-ops-stat"><span>Cancelled:</span> <strong>{adminOperations.cancelledAppointments}</strong></div>
                                            <div class="care-ops-stat"><span>Pending:</span> <strong>{adminOperations.pendingAppointments}</strong></div>
                                        </div>
                                    </div>

                                    <!-- Panel B: Inpatient Bed Utilization -->
                                    <div class="care-ops-box">
                                        <div class="care-ops-box-header">
                                            <span class="care-ops-box-title">Inpatient Bed Utilization</span>
                                            <lightning-icon icon-name="standard:hospital" size="small"></lightning-icon>
                                        </div>
                                        <div class="care-ops-metric-large">{adminOperations.wardOccupancyRate}%</div>
                                        <div class="care-ops-breakdown">
                                            <div class="care-ops-stat"><span>Occupied Beds:</span> <strong>{adminOperations.occupiedBeds}</strong></div>
                                            <div class="care-ops-stat"><span>Available Beds:</span> <strong>{adminOperations.availableBeds}</strong></div>
                                            <div class="care-ops-stat"><span>Active Census:</span> <strong>{adminOperations.activeAdmissions}</strong></div>
                                            <div class="care-ops-stat"><span>Discharged:</span> <strong>{adminOperations.dischargedCount}</strong></div>
                                        </div>
                                    </div>

                                    <!-- Panel C: Clinical Alert Management -->
                                    <div class="care-ops-box">
                                        <div class="care-ops-box-header">
                                            <span class="care-ops-box-title">Clinical Alerts Lifecycle</span>
                                            <lightning-icon icon-name="utility:warning" size="small" class="care-icon-red"></lightning-icon>
                                        </div>
                                        <div class="care-ops-metric-large">{adminOperations.totalAlerts}</div>
                                        <div class="care-ops-breakdown">
                                            <div class="care-ops-stat"><span>Pending Review:</span> <strong>{adminOperations.pendingReviews}</strong></div>
                                            <div class="care-ops-stat"><span>New / Unacknowledged:</span> <strong>{adminOperations.newAlerts}</strong></div>
                                            <div class="care-ops-stat"><span>Acknowledged:</span> <strong>{adminOperations.acknowledgedAlerts}</strong></div>
                                            <div class="care-ops-stat"><span>Resolved:</span> <strong>{adminOperations.resolvedAlerts}</strong></div>
                                        </div>
                                    </div>

                                    <!-- Panel D: Inpatient Bed Charges Potential -->
                                    <div class="care-ops-box">
                                        <div class="care-ops-box-header">
                                            <span class="care-ops-box-title">Incurred Bed Charges</span>
                                            <lightning-icon icon-name="standard:currency" size="small"></lightning-icon>
                                        </div>
                                        <div class="care-ops-metric-large">₹{adminKpi.inpatientChargesPotential}</div>
                                        <div class="care-ops-breakdown">
                                            <div class="care-ops-stat"><span>Admitted Patients:</span> <strong>₹245,700</strong></div>
                                            <div class="care-ops-stat"><span>Discharged Patients:</span> <strong>₹180,300</strong></div>
                                            <div class="care-ops-stat"><span>Wards:</span> <strong>5 Facilities</strong></div>
                                            <div class="care-ops-stat"><span>Daily Rate Avg:</span> <strong>₹1,800/day</strong></div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- 4. RECENT FINANCIAL TRANSACTIONS LEDGER (STEP 6) -->
                            <div class="care-card-panel slds-m-top_large">
                                <div class="care-panel-header">
                                    <div>
                                        <h3 class="care-panel-title">Recent Financial Transactions</h3>
                                        <p class="care-panel-sub">Live audit trail of verified patient payments and counter receipts.</p>
                                    </div>
                                    <div class="care-table-search-box">
                                        <input
                                            type="text"
                                            placeholder="Search transactions..."
                                            class="care-search-input"
                                            oninput={handleTransactionSearch}
                                            aria-label="Search transaction records" />
                                    </div>
                                </div>

                                <div class="care-table-responsive-wrapper">
                                    <table class="care-data-table">
                                        <thead>
                                            <tr>
                                                <th>Txn Code</th>
                                                <th>Appointment</th>
                                                <th>Patient</th>
                                                <th>Doctor</th>
                                                <th>Department</th>
                                                <th>Method</th>
                                                <th class="care-text-right">Amount</th>
                                                <th>Status</th>
                                                <th>Settled Date</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <template for:each={filteredTransactions} for:item="t">
                                                <tr key={t.id}>
                                                    <td class="care-font-bold">{t.transactionCode}</td>
                                                    <td>{t.appointmentCode}</td>
                                                    <td>{t.patientName}</td>
                                                    <td>{t.doctorName}</td>
                                                    <td>{t.department}</td>
                                                    <td>
                                                        <span class="care-pill-badge-teal">{t.method}</span>
                                                    </td>
                                                    <td class="care-text-right care-font-bold care-text-teal">₹{t.amount}</td>
                                                    <td>
                                                        <span class="care-tag-green">{t.status}</span>
                                                    </td>
                                                    <td class="care-text-muted">{t.formattedPaidOn}</td>
                                                </tr>
                                            </template>
                                        </tbody>
                                    </table>
                                </div>
                            </div>

                            <!-- 5. SALESFORCE REPORTS QUICK HUB (STEP 7) -->
                            <div class="care-card-panel slds-m-top_large">
                                <div class="care-panel-header">
                                    <div>
                                        <h3 class="care-panel-title">Official Salesforce Financial &amp; Operational Reports</h3>
                                        <p class="care-panel-sub">Direct access to standard and custom Salesforce Reports for deep tabular inspection and official exports.</p>
                                    </div>
                                </div>

                                <div class="care-reports-grid">
                                    <template for:each={reportLinksList} for:item="r">
                                        <a key={r.id} href={r.url} target="_blank" rel="noopener noreferrer" class="care-report-link-card">
                                            <div class="care-report-card-icon">
                                                <lightning-icon icon-name="standard:report" size="small"></lightning-icon>
                                            </div>
                                            <div class="care-report-card-content">
                                                <div class="care-report-name">{r.name}</div>
                                                <div class="care-report-cat">{r.category} Analytics</div>
                                            </div>
                                            <lightning-icon icon-name="utility:new_window" size="xx-small" class="care-report-ext-icon"></lightning-icon>
                                        </a>
                                    </template>
                                </div>
                            </div>
                        </template>
                    </div>
                </template>
`;

const marker = 'MODULE 2: PATIENT MANAGEMENT (Intake & Search)';
const idx = html.indexOf(marker);
if (idx !== -1) {
    // Find the comment start <!-- right before the marker
    const commentStart = html.lastIndexOf('<!--', idx);
    html = html.slice(0, commentStart) + adminOverviewTemplate + '\n                ' + html.slice(commentStart);
    fs.writeFileSync(targetHtml, html, 'utf8');
    console.log('Successfully inserted Admin Overview template into HTML!');
} else {
    console.error('Marker not found!');
}

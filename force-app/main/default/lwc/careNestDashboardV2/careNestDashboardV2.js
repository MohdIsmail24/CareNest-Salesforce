import { LightningElement, track, wire } from 'lwc';
import Id from '@salesforce/user/Id';
import CARENEST_HERO_IMG from '@salesforce/resourceUrl/careNestHeroMedicalSuite';
import getDashboardMetrics from '@salesforce/apex/CareNestDashboardController.getDashboardMetrics';
import getWardSummaries from '@salesforce/apex/CareNestDashboardController.getWardSummaries';
import getRecentActivities from '@salesforce/apex/CareNestDashboardController.getRecentActivities';
import getAdminOverviewAnalytics from '@salesforce/apex/CareNestDashboardController.getAdminOverviewAnalytics';
import getReportsHubReports from '@salesforce/apex/CareNestDashboardController.getReportsHubReports';
import { refreshApex } from '@salesforce/apex';

export default class CareNestDashboardV2 extends LightningElement {
    currentUserId = Id;
    @track activeTab = 'overview';
    @track showMobileMenu = false;
    @track showModulesDropdown = false;
    @track metrics = null;
    @track wardSummaries = [];
    @track recentActivities = [];
    @track isLoading = true;
    @track userName = 'Hospital Administrator';
    @track activeRoleLabel = 'Executive Administration & Medical Operations';
    @track isPatientRegModalOpen = false;

    // Admin Overview State
    @track adminData = null;
    @track isAdminLoading = false;
    @track adminError = '';
    @track selectedPeriod = 'all';
    @track selectedDepartment = 'all';
    @track selectedDoctorId = 'all';
    @track customStartDate = '';
    @track customEndDate = '';
    @track transactionSearchTerm = '';

    // Reports Hub State
    @track reportsHubList = [];
    @track isReportsLoading = false;
    @track reportsError = '';
    @track reportsSearchTerm = '';
    @track selectedReportCategory = 'all';

    wiredMetricsResult;
    wiredWardsResult;
    wiredActivitiesResult;

    connectedCallback() {
        if (this.currentUserId) {
            this.userName = 'Dr. Mohammad Ismail';
        }
        this.loadAdminAnalytics();
        this.loadReportsHub();
    }

    get heroImageStyle() {
        const bgUrl = CARENEST_HERO_IMG || '/resource/careNestHeroMedicalSuite';
        return `background: linear-gradient(135deg, rgba(15, 23, 42, 0.94) 0%, rgba(15, 23, 42, 0.82) 45%, rgba(13, 148, 136, 0.75) 100%), url('${bgUrl}') center/cover no-repeat;`;
    }

    @wire(getDashboardMetrics)
    wiredMetrics(result) {
        this.wiredMetricsResult = result;
        this.isLoading = false;
        if (result.data) {
            this.metrics = result.data;
        } else if (result.error) {
            // eslint-disable-next-line no-console
            console.error('CareNestDashboardV2: Error loading metrics', result.error);
        }
    }

    @wire(getWardSummaries)
    wiredWards(result) {
        this.wiredWardsResult = result;
        if (result.data) {
            this.wardSummaries = result.data.map(w => {
                let barClass = 'care-prog-teal';
                if (w.occupancyRate >= 80) {
                    barClass = 'care-prog-red';
                } else if (w.occupancyRate >= 60) {
                    barClass = 'care-prog-amber';
                } else if (w.occupancyRate >= 40) {
                    barClass = 'care-prog-teal';
                } else {
                    barClass = 'care-prog-green';
                }
                return {
                    ...w,
                    barClass,
                    progressStyle: `width: ${Math.min(100, Math.max(8, w.occupancyRate))}%;`,
                    availableBadgeClass: w.availableBeds > 0 ? 'care-badge-avail' : 'care-badge-full'
                };
            });
        }
    }

    @wire(getRecentActivities)
    wiredActivities(result) {
        this.wiredActivitiesResult = result;
        if (result.data) {
            this.recentActivities = result.data.map(act => {
                const isAlert = act.type === 'Alert';
                return {
                    ...act,
                    isAlert,
                    iconName: isAlert ? 'utility:warning' : 'standard:hospital',
                    iconClass: isAlert ? 'care-act-icon-alert' : 'care-act-icon-adm',
                    badgeLabel: isAlert ? 'Clinical Alert' : act.status,
                    badgeStyle: isAlert ? 'care-pill-badge-red' : 'care-pill-badge-teal'
                };
            });
        }
    }

    // -------------------------------------------------------------------------
    // ADMIN ANALYTICS LOADER & HANDLERS
    // -------------------------------------------------------------------------

    async loadAdminAnalytics() {
        this.isAdminLoading = true;
        this.adminError = '';

        const filterPayload = {
            period: this.selectedPeriod,
            department: this.selectedDepartment !== 'all' ? this.selectedDepartment : null,
            doctorId: this.selectedDoctorId !== 'all' ? this.selectedDoctorId : null,
            startDate: this.customStartDate || null,
            endDate: this.customEndDate || null
        };

        try {
            const data = await getAdminOverviewAnalytics({ filterJson: JSON.stringify(filterPayload) });
            this.adminData = data;
        } catch (err) {
            this.adminError = err.body ? err.body.message : (err.message || 'Error loading Admin Analytics');
            // eslint-disable-next-line no-console
            console.error('CareNestDashboardV2: Admin Analytics Error', err);
        } finally {
            this.isAdminLoading = false;
        }
    }

    handleSelectPeriod(event) {
        const period = event.currentTarget.dataset.period;
        if (period && period !== this.selectedPeriod) {
            this.selectedPeriod = period;
            this.loadAdminAnalytics();
        }
    }

    handleDepartmentChange(event) {
        this.selectedDepartment = event.target.value;
        this.loadAdminAnalytics();
    }

    handleDoctorChange(event) {
        this.selectedDoctorId = event.target.value;
        this.loadAdminAnalytics();
    }

    handleStartDateChange(event) {
        this.customStartDate = event.target.value;
        if (this.customStartDate && this.customEndDate) {
            this.loadAdminAnalytics();
        }
    }

    handleEndDateChange(event) {
        this.customEndDate = event.target.value;
        if (this.customStartDate && this.customEndDate) {
            this.loadAdminAnalytics();
        }
    }

    handleRefreshAdmin() {
        this.loadAdminAnalytics();
    }

    handleTransactionSearch(event) {
        this.transactionSearchTerm = (event.target.value || '').toLowerCase().trim();
    }

    handleExportCsv() {
        if (!this.adminData || !this.adminData.recentTransactions || this.adminData.recentTransactions.length === 0) {
            return;
        }

        const sanitizeCsvCell = (val) => {
            let str = (val === null || val === undefined) ? '' : String(val);
            if (/^[=+\-@\t\r]/.test(str)) {
                str = "'" + str;
            }
            return `"${str.replace(/"/g, '""')}"`;
        };

        const headers = ['Transaction Code', 'Appointment Code', 'Patient Name', 'Doctor', 'Department', 'Payment Method', 'Amount (INR)', 'Recorded Status', 'Payment Date'];
        const rows = this.adminData.recentTransactions.map(t => [
            sanitizeCsvCell(t.transactionCode),
            sanitizeCsvCell(t.appointmentCode),
            sanitizeCsvCell(t.patientName),
            sanitizeCsvCell(t.doctorName),
            sanitizeCsvCell(t.department),
            sanitizeCsvCell(t.method),
            t.amount != null ? t.amount : 0,
            sanitizeCsvCell(t.status),
            sanitizeCsvCell(t.formattedPaidOn)
        ]);

        const csvContent = 'data:text/csv;charset=utf-8,' + [headers.map(sanitizeCsvCell).join(','), ...rows.map(r => r.join(','))].join('\n');
        const encodedUri = encodeURI(csvContent);
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', `CareNest_Financial_Ledger_${new Date().toISOString().slice(0, 10)}.csv`);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }

    // -------------------------------------------------------------------------
    // REPORTS HUB LOADER & HANDLERS
    // -------------------------------------------------------------------------

    async loadReportsHub() {
        this.isReportsLoading = true;
        this.reportsError = '';
        try {
            const data = await getReportsHubReports();
            this.reportsHubList = Array.isArray(data) ? data : [];
        } catch (err) {
            this.reportsError = err.body ? err.body.message : (err.message || 'Error loading Reports Hub');
            // eslint-disable-next-line no-console
            console.error('CareNestDashboardV2: Reports Hub Error', err);
        } finally {
            this.isReportsLoading = false;
        }
    }

    handleReportSearch(event) {
        this.reportsSearchTerm = (event.target.value || '').trim();
    }

    handleClearReportSearch() {
        this.reportsSearchTerm = '';
        const searchInput = this.template.querySelector('.care-report-search-input');
        if (searchInput) {
            searchInput.value = '';
        }
    }

    handleSelectReportCategory(event) {
        const cat = event.currentTarget.dataset.category;
        if (cat) {
            this.selectedReportCategory = cat;
        }
    }

    handleRefreshReports() {
        this.loadReportsHub();
    }

    get totalReportsCount() {
        return this.reportsHubList ? this.reportsHubList.length : 0;
    }

    get financialReportsCount() {
        return this.reportsHubList ? this.reportsHubList.filter(r => r.categoryKey === 'financial').length : 0;
    }

    get operationsReportsCount() {
        return this.reportsHubList ? this.reportsHubList.filter(r => r.categoryKey === 'operations').length : 0;
    }

    get clinicalReportsCount() {
        return this.reportsHubList ? this.reportsHubList.filter(r => r.categoryKey === 'clinical').length : 0;
    }

    get additionalReportsCount() {
        return this.reportsHubList ? this.reportsHubList.filter(r => r.categoryKey === 'additional').length : 0;
    }

    get filteredReportsList() {
        if (!this.reportsHubList || this.reportsHubList.length === 0) return [];
        let list = this.reportsHubList;

        if (this.selectedReportCategory !== 'all') {
            list = list.filter(r => r.categoryKey === this.selectedReportCategory);
        }

        if (this.reportsSearchTerm) {
            const term = this.reportsSearchTerm.toLowerCase();
            list = list.filter(r =>
                (r.name && r.name.toLowerCase().includes(term)) ||
                (r.description && r.description.toLowerCase().includes(term)) ||
                (r.category && r.category.toLowerCase().includes(term)) ||
                (r.id && r.id.toLowerCase().includes(term))
            );
        }

        return list;
    }

    get hasReports() {
        return this.filteredReportsList && this.filteredReportsList.length > 0;
    }

    get hasNoSearchResults() {
        return !this.isReportsLoading && this.reportsHubList && this.reportsHubList.length > 0 && this.filteredReportsList.length === 0;
    }

    get reportCatAllClass() { return `care-filter-btn ${this.selectedReportCategory === 'all' ? 'active' : ''}`; }
    get reportCatFinClass() { return `care-filter-btn ${this.selectedReportCategory === 'financial' ? 'active' : ''}`; }
    get reportCatOpsClass() { return `care-filter-btn ${this.selectedReportCategory === 'operations' ? 'active' : ''}`; }
    get reportCatClinClass() { return `care-filter-btn ${this.selectedReportCategory === 'clinical' ? 'active' : ''}`; }
    get reportCatAddClass() { return `care-filter-btn ${this.selectedReportCategory === 'additional' ? 'active' : ''}`; }

    // -------------------------------------------------------------------------
    // COMPUTED GETTERS FOR ADMIN OVERVIEW
    // -------------------------------------------------------------------------

    get isAdminOverviewTab() {
        return this.activeTab === 'adminOverview';
    }

    get isCustomPeriod() {
        return this.selectedPeriod === 'custom';
    }

    get periodAllClass() { return `care-filter-btn ${this.selectedPeriod === 'all' ? 'active' : ''}`; }
    get periodTodayClass() { return `care-filter-btn ${this.selectedPeriod === 'today' ? 'active' : ''}`; }
    get period7DClass() { return `care-filter-btn ${this.selectedPeriod === 'last7days' ? 'active' : ''}`; }
    get period30DClass() { return `care-filter-btn ${this.selectedPeriod === 'last30days' ? 'active' : ''}`; }
    get periodThisMonthClass() { return `care-filter-btn ${this.selectedPeriod === 'thismonth' ? 'active' : ''}`; }
    get periodLastMonthClass() { return `care-filter-btn ${this.selectedPeriod === 'lastmonth' ? 'active' : ''}`; }
    get periodQuarterClass() { return `care-filter-btn ${this.selectedPeriod === 'thisquarter' ? 'active' : ''}`; }
    get periodYearClass() { return `care-filter-btn ${this.selectedPeriod === 'thisyear' ? 'active' : ''}`; }
    get periodCustomClass() { return `care-filter-btn ${this.selectedPeriod === 'custom' ? 'active' : ''}`; }

    get adminKpi() {
        return this.adminData ? this.adminData.kpi : null;
    }

    get adminOperations() {
        return this.adminData ? this.adminData.operations : null;
    }

    get filteredTransactions() {
        if (!this.adminData || !this.adminData.recentTransactions) return [];
        if (!this.transactionSearchTerm) return this.adminData.recentTransactions;

        const term = this.transactionSearchTerm;
        return this.adminData.recentTransactions.filter(t =>
            (t.transactionCode && t.transactionCode.toLowerCase().includes(term)) ||
            (t.appointmentCode && t.appointmentCode.toLowerCase().includes(term)) ||
            (t.patientName && t.patientName.toLowerCase().includes(term)) ||
            (t.doctorName && t.doctorName.toLowerCase().includes(term)) ||
            (t.department && t.department.toLowerCase().includes(term)) ||
            (t.method && t.method.toLowerCase().includes(term))
        );
    }

    // Chart 1: Monthly Revenue Trend SVG
    get monthlyTrendSvg() {
        if (!this.adminData || !this.adminData.charts || !this.adminData.charts.monthlyRevenueTrend) {
            return { points: [], linePath: '', areaPath: '' };
        }
        const data = this.adminData.charts.monthlyRevenueTrend;
        if (data.length === 0) return { points: [], linePath: '', areaPath: '' };

        const maxVal = Math.max(...data.map(d => d.value || 0), 1000);
        const width = 500;
        const height = 160;
        const padding = 30;
        const usableWidth = width - (padding * 2);
        const usableHeight = height - (padding * 2);

        const stepX = data.length > 1 ? usableWidth / (data.length - 1) : usableWidth;

        const coords = data.map((d, idx) => {
            const x = padding + (idx * stepX);
            const val = d.value || 0;
            const y = height - padding - ((val / maxVal) * usableHeight);
            return {
                x: Math.round(x),
                y: Math.round(y),
                label: d.label,
                value: val,
                formattedVal: `₹${val.toLocaleString('en-IN')}`
            };
        });

        const linePath = coords.map((c, i) => (i === 0 ? `M ${c.x} ${c.y}` : `L ${c.x} ${c.y}`)).join(' ');
        const areaPath = `${linePath} L ${coords[coords.length - 1].x} ${height - padding} L ${coords[0].x} ${height - padding} Z`;

        return { points: coords, linePath, areaPath };
    }

    // Chart 2: Daily Collections Bars SVG
    get dailyCollectionsBars() {
        if (!this.adminData || !this.adminData.charts || !this.adminData.charts.dailyCollections) {
            return [];
        }
        const data = this.adminData.charts.dailyCollections;
        if (data.length === 0) return [];

        const maxVal = Math.max(...data.map(d => d.value || 0), 500);
        const barWidth = 14;
        const totalHeight = 150;
        const usableHeight = 120;

        return data.map((d, idx) => {
            const val = d.value || 0;
            const barHeight = Math.max(4, Math.round((val / maxVal) * usableHeight));
            const x = idx * 19 + 5;
            const y = totalHeight - barHeight - 20;
            return {
                ...d,
                x,
                y,
                width: barWidth,
                height: barHeight,
                formattedVal: `₹${val.toLocaleString('en-IN')}`,
                barClass: val > 0 ? 'care-svg-bar-teal' : 'care-svg-bar-empty'
            };
        });
    }

    // Chart 3: Invoiced vs Collected Comparative Bars
    get invoicedVsCollectedList() {
        if (!this.adminData || !this.adminData.charts || !this.adminData.charts.invoicedVsCollected) {
            return [];
        }
        const ivc = this.adminData.charts.invoicedVsCollected;
        const maxVal = Math.max(ivc.invoiced || 0, ivc.collected || 0, 1000);

        return [
            { label: 'Total Invoiced', amount: ivc.invoiced, formatted: `₹${(ivc.invoiced || 0).toLocaleString('en-IN')}`, widthStyle: `width: ${Math.min(100, Math.round(((ivc.invoiced || 0) / maxVal) * 100))}%;`, barClass: 'care-bar-navy' },
            { label: 'Recorded Successful Collections', amount: ivc.collected, formatted: `₹${(ivc.collected || 0).toLocaleString('en-IN')}`, widthStyle: `width: ${Math.min(100, Math.round(((ivc.collected || 0) / maxVal) * 100))}%;`, barClass: 'care-bar-teal' },
            { label: 'Outstanding Receivables (Active)', amount: ivc.outstanding, formatted: `₹${(ivc.outstanding || 0).toLocaleString('en-IN')}`, widthStyle: `width: ${Math.min(100, Math.round(((ivc.outstanding || 0) / maxVal) * 100))}%;`, barClass: 'care-bar-amber' },
            { label: 'Refund Entitlements', amount: ivc.refunded, formatted: `₹${(ivc.refunded || 0).toLocaleString('en-IN')}`, widthStyle: `width: ${Math.min(100, Math.round(((ivc.refunded || 0) / maxVal) * 100))}%;`, barClass: 'care-bar-rose' }
        ];
    }

    // Chart 4 & 5: Department & Payment Methods Slices
    get departmentRevenueSlices() {
        if (!this.adminData || !this.adminData.charts || !this.adminData.charts.revenueByDepartment) {
            return [];
        }
        return this.adminData.charts.revenueByDepartment.map(s => ({
            ...s,
            formattedAmount: `₹${(s.amount || 0).toLocaleString('en-IN')}`,
            badgeStyle: `background-color: ${s.color};`
        }));
    }

    get paymentMethodSlices() {
        if (!this.adminData || !this.adminData.charts || !this.adminData.charts.revenueByPaymentMethod) {
            return [];
        }
        return this.adminData.charts.revenueByPaymentMethod.map(s => ({
            ...s,
            formattedAmount: `₹${(s.amount || 0).toLocaleString('en-IN')}`,
            badgeStyle: `background-color: ${s.color};`
        }));
    }

    // Chart 6: Receivables Aging
    get receivablesAgingList() {
        if (!this.adminData || !this.adminData.charts || !this.adminData.charts.receivablesAging) {
            return [];
        }
        const data = this.adminData.charts.receivablesAging;
        const maxVal = Math.max(...data.map(d => d.amount || 0), 1000);

        return data.map(d => {
            const isCurrent = d.bracket.includes('Current');
            return {
                ...d,
                formattedAmount: `₹${(d.amount || 0).toLocaleString('en-IN')}`,
                widthStyle: `width: ${Math.min(100, Math.max(6, Math.round(((d.amount || 0) / maxVal) * 100)))}%;`,
                barClass: isCurrent ? 'care-bar-green' : (d.bracket.includes('1-30') ? 'care-bar-amber' : 'care-bar-red'),
                tagClass: isCurrent ? 'care-tag-green' : 'care-tag-amber'
            };
        });
    }

    // Chart 7: Doctor Revenue Ranked
    get doctorRevenueRanked() {
        if (!this.adminData || !this.adminData.charts || !this.adminData.charts.doctorRevenue) {
            return [];
        }
        const data = this.adminData.charts.doctorRevenue;
        const maxVal = Math.max(...data.map(d => d.amount || 0), 1000);

        return data.map((d, idx) => ({
            ...d,
            rank: idx + 1,
            formattedAmount: `₹${(d.amount || 0).toLocaleString('en-IN')}`,
            widthStyle: `width: ${Math.min(100, Math.max(8, Math.round(((d.amount || 0) / maxVal) * 100)))}%;`
        }));
    }

    get reportLinksList() {
        return this.adminData ? this.adminData.reportLinks : [];
    }

    // -------------------------------------------------------------------------
    // NAVIGATION ITEMS (12 ORIGINAL MODULES + EXECUTIVE ANALYTICS)
    // -------------------------------------------------------------------------

    get navItems() {
        const alertCount = this.metrics && this.metrics.activeClinicalAlerts > 0 ? `${this.metrics.activeClinicalAlerts}` : null;
        const availableBeds = this.metrics && this.metrics.availableBeds ? `${this.metrics.availableBeds} Avail` : null;

        const items = [
            { id: 'overview', label: 'Command Center', icon: 'standard:service_territory_location', badge: 'Live' },
            { id: 'adminOverview', label: 'Executive Analytics', icon: 'standard:dashboard', badge: '₹42.5K' },
            { id: 'patients', label: 'Patient Registry', icon: 'standard:user', badge: '113' },
            { id: 'doctors', label: 'Doctors & Staff', icon: 'standard:account', badge: '12' },
            { id: 'appointments', label: 'OPD Appointments', icon: 'standard:event', badge: null },
            { id: 'admissions', label: 'Admissions & Beds', icon: 'standard:hospital', badge: '19' },
            { id: 'wards', label: 'Ward Capacity', icon: 'standard:asset_relationship', badge: availableBeds },
            { id: 'clinical', label: 'Clinical Charts & Vitals', icon: 'standard:stethoscope', badge: alertCount },
            { id: 'billing', label: 'Billing & Payments', icon: 'standard:currency', badge: null },
            { id: 'reports', label: 'Reports Hub', icon: 'standard:report', badge: null },
            { id: 'assistant', label: 'Agentforce AI', icon: 'standard:einstein', badge: 'AI' },
            { id: 'automation', label: 'Automation & Jobs', icon: 'standard:process', badge: 'Active' },
            { id: 'system', label: 'System Health', icon: 'standard:shield', badge: 'RBAC' }
        ];

        return items.map(item => {
            const isActive = this.activeTab === item.id;
            return {
                ...item,
                buttonClass: `care-nav-pill ${isActive ? 'care-nav-pill-active' : ''}`,
                mobileClass: `care-mobile-nav-item ${isActive ? 'care-mobile-nav-item-active' : ''}`
            };
        });
    }

    // Tab Getters
    get isOverviewTab() { return this.activeTab === 'overview'; }
    get isPatientsTab() { return this.activeTab === 'patients'; }
    get isDoctorsTab() { return this.activeTab === 'doctors'; }
    get isAppointmentsTab() { return this.activeTab === 'appointments'; }
    get isAdmissionsTab() { return this.activeTab === 'admissions'; }
    get isWardsTab() { return this.activeTab === 'wards'; }
    get isClinicalTab() { return this.activeTab === 'clinical'; }
    get isBillingTab() { return this.activeTab === 'billing'; }
    get isReportsTab() { return this.activeTab === 'reports'; }
    get isAssistantTab() { return this.activeTab === 'assistant'; }
    get isAutomationTab() { return this.activeTab === 'automation'; }
    get isSystemTab() { return this.activeTab === 'system'; }

    get hasActiveAlerts() {
        return this.metrics && this.metrics.activeClinicalAlerts > 0;
    }

    get collectionRate() {
        if (this.metrics && this.metrics.totalBilled && this.metrics.totalBilled > 0) {
            return Math.round((this.metrics.totalPaid / this.metrics.totalBilled) * 100);
        }
        return 78;
    }

    handleNavClick(event) {
        const tabId = event.currentTarget.dataset.id;
        if (tabId) {
            this.activeTab = tabId;
            this.showMobileMenu = false;
            this.showModulesDropdown = false;
            if (tabId === 'adminOverview') {
                this.loadAdminAnalytics();
            } else if (tabId === 'reports') {
                this.loadReportsHub();
            }
        }
    }

    handleMobileNavClick(event) {
        const tabId = event.currentTarget.dataset.id;
        if (tabId) {
            this.activeTab = tabId;
            this.showMobileMenu = false;
            this.showModulesDropdown = false;
            if (tabId === 'adminOverview') {
                this.loadAdminAnalytics();
            } else if (tabId === 'reports') {
                this.loadReportsHub();
            }
        }
    }

    handleToggleModulesDropdown() {
        this.showModulesDropdown = !this.showModulesDropdown;
    }

    handleSelectModule(event) {
        const tabId = event.currentTarget.dataset.id;
        if (tabId) {
            this.activeTab = tabId;
            this.showModulesDropdown = false;
            this.showMobileMenu = false;
            if (tabId === 'adminOverview') {
                this.loadAdminAnalytics();
            } else if (tabId === 'reports') {
                this.loadReportsHub();
            }
        }
    }

    handleScrollNavLeft() {
        const wrapper = this.template.querySelector('.care-nav-pills-wrapper');
        if (wrapper) {
            wrapper.scrollBy({ left: -280, behavior: 'smooth' });
        }
    }

    handleScrollNavRight() {
        const wrapper = this.template.querySelector('.care-nav-pills-wrapper');
        if (wrapper) {
            wrapper.scrollBy({ left: 280, behavior: 'smooth' });
        }
    }

    handleToggleMobileMenu() {
        this.showMobileMenu = !this.showMobileMenu;
        this.showModulesDropdown = false;
    }

    handleLogoClick() {
        this.activeTab = 'overview';
        this.showMobileMenu = false;
        this.showModulesDropdown = false;
    }

    handleRefresh() {
        this.isLoading = true;
        Promise.all([
            refreshApex(this.wiredMetricsResult),
            refreshApex(this.wiredWardsResult),
            refreshApex(this.wiredActivitiesResult)
        ]).finally(() => {
            this.isLoading = false;
            if (this.isAdminOverviewTab) {
                this.loadAdminAnalytics();
            }
        });
    }

    handleQuickRegisterPatient() {
        this.isPatientRegModalOpen = true;
        this.showMobileMenu = false;
        this.showModulesDropdown = false;
    }

    handleClosePatientRegModal() {
        this.isPatientRegModalOpen = false;
    }

    handlePatientCreated() {
        this.isPatientRegModalOpen = false;
        this.handleRefresh();
        this.activeTab = 'patients';
    }

    handleNavigateWorkspace(event) {
        if (event.detail && event.detail.tab) {
            const requestedTab = event.detail.tab;
            if (requestedTab === 'dashboard' || requestedTab === 'operations') {
                this.activeTab = 'overview';
            } else {
                this.activeTab = requestedTab;
            }
            if (this.activeTab === 'adminOverview') {
                this.loadAdminAnalytics();
            }
        }
    }
}

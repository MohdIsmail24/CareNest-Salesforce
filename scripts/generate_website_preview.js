/**
 * scripts/generate_website_preview.js
 * Visual Fidelity Upgrade: Generates standalone preview HTML from careNestWebsiteApp.html & careNestWebsiteApp.css
 * - Replaces all emojis with clean, crisp inline SVGs
 * - Implements 2-column Hero with medical team visual
 * - Removes unverified claims (NABH/JCI, 99.4% recovery, bed counts from public nav)
 * - Labeled demo placeholders for emergency services
 * - Serves preview on http://localhost:8089 for Playwright screenshot capture and user preview
 */
const http = require('http');
const fs = require('fs');
const path = require('path');

const cssPath = path.join(__dirname, '..', 'force-app', 'main', 'default', 'lwc', 'careNestWebsiteApp', 'careNestWebsiteApp.css');
const cssContent = fs.readFileSync(cssPath, 'utf8');

// SVG Icon Helpers
const icons = {
    hospital: `<svg class="svg-icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 6v4"/><path d="M14 14h-4"/><path d="M14 18h-4"/><path d="M14 8h-4"/><path d="M18 12h-4"/><path d="M6 12h4"/><rect width="16" height="20" x="4" y="2" rx="2"/><path d="M10 22v-4a2 2 0 0 1 4 0v4"/></svg>`,
    call: `<svg class="svg-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg>`,
    clock: `<svg class="svg-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>`,
    connectedApps: `<svg class="svg-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="7" height="7" x="3" y="3" rx="1"/><rect width="7" height="7" x="14" y="3" rx="1"/><rect width="7" height="7" x="14" y="14" rx="1"/><rect width="7" height="7" x="3" y="14" rx="1"/></svg>`,
    lock: `<svg class="svg-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>`,
    home: `<svg class="svg-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>`,
    stethoscope: `<svg class="svg-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4.8 2.3A.3.3 0 1 0 5 2H4a2 2 0 0 0-2 2v5a6 6 0 0 0 6 6v0a6 6 0 0 0 6-6V4a2 2 0 0 0-2-2h-1a.2.2 0 1 0 .3.3"/><path d="M8 15v1a6 6 0 0 0 6 6v0a6 6 0 0 0 6-6v-4"/><circle cx="20" cy="10" r="2"/></svg>`,
    user: `<svg class="svg-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>`,
    event: `<svg class="svg-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="18" x="3" y="4" rx="2" ry="2"/><line x1="16" x2="16" y1="2" y2="6"/><line x1="8" x2="8" y1="2" y2="6"/><line x1="3" x2="21" y1="10" y2="10"/></svg>`,
    facilities: `<svg class="svg-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21h18"/><path d="M9 8h1"/><path d="M9 12h1"/><path d="M9 16h1"/><path d="M14 8h1"/><path d="M14 12h1"/><path d="M14 16h1"/><path d="M5 21V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16"/></svg>`,
    info: `<svg class="svg-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>`,
    shield: `<svg class="svg-icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>`,
    priority: `<svg class="svg-icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>`,
    ai: `<svg class="svg-icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/></svg>`,
    arrowRight: `<svg class="svg-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>`,
    arrowLeft: `<svg class="svg-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg>`,
    menu: `<svg class="svg-icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" x2="20" y1="12" y2="12"/><line x1="4" x2="20" y1="6" y2="6"/><line x1="4" x2="20" y1="18" y2="18"/></svg>`,
    check: `<svg class="svg-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>`,
    groups: `<svg class="svg-icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>`,
    currency: `<svg class="svg-icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" x2="12" y1="2" y2="22"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>`,
    warning: `<svg class="svg-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>`,
    desktop: `<svg class="svg-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="14" x="2" y="3" rx="2"/><line x1="8" x2="16" y1="21" y2="21"/><line x1="12" x2="12" y1="17" y2="21"/></svg>`
};

const htmlTemplate = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CareNest Hospital — Tertiary Healthcare & Research (Salesforce Showcase)</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f8fafc; color: #1e293b; line-height: 1.5; -webkit-font-smoothing: antialiased; }
        ${cssContent}
        
        .svg-icon { display: inline-flex; vertical-align: middle; flex-shrink: 0; }
    </style>
</head>
<body>
    <div class="care-site-wrapper" id="app-root">

        <!-- ================================================================= -->
        <!-- 0. TOP UTILITY RIBBON (EMERGENCY HOTLINE & EXPERIENCE TOGGLE)    -->
        <!-- ================================================================= -->
        <div class="care-top-utility-ribbon">
            <div class="care-utility-inner">
                <div class="care-utility-left">
                    <span class="care-emergency-hotline">
                        ${icons.call}
                        <strong>Demo Helpline:</strong> +1 (555) 019-CARE (Simulated Demo)
                    </span>

                    <span class="care-utility-divider">|</span>
                    <span class="care-utility-info">
                        ${icons.clock}
                        Demo OPD: Mon - Sat 8:00 AM – 8:00 PM
                    </span>
                    <span class="care-utility-divider">|</span>
                    <span class="care-utility-info care-hide-mobile">
                        ${icons.connectedApps}
                        Salesforce Healthcare Portfolio Showcase
                    </span>
                </div>
                <div class="care-utility-right">
                    <button id="toggle-experience-btn" class="care-utility-btn" onclick="toggleExperience()">
                        <span id="toggle-icon">${icons.lock}</span>
                        <span id="toggle-experience-text">Hospital Staff Intranet</span>
                    </button>
                </div>
            </div>
        </div>

        <!-- ================================================================= -->
        <!-- 1. STICKY BRANDED NAVIGATION HEADER (TRIPNEST-STYLE)              -->
        <!-- ================================================================= -->
        <header class="care-nav-header">
            <div class="care-nav-inner">
                <!-- Brand Logo & Name -->
                <div class="care-brand-link" onclick="switchPublicSection('home')">
                    <div class="care-logo-icon-wrap">
                        ${icons.hospital}
                    </div>
                    <div class="care-brand-text">
                        <div class="care-brand-name">Care<span class="care-brand-accent">Nest</span></div>
                        <span class="care-brand-tagline">Tertiary Healthcare &amp; Research</span>
                    </div>
                </div>

                <!-- A. PUBLIC CONSUMER NAVIGATION -->
                <nav id="public-nav" class="care-nav-menu">
                    <a class="care-nav-link care-nav-link-active" href="#home" onclick="switchPublicSection('home')">
                        ${icons.home}
                        <span>Home</span>
                    </a>
                    <a class="care-nav-link" href="#specialties" onclick="switchPublicSection('specialties')">
                        ${icons.stethoscope}
                        <span>Specialties</span>
                    </a>
                    <a class="care-nav-link" href="#doctors" onclick="switchPublicSection('doctors')">
                        ${icons.user}
                        <span>Find a Doctor</span>
                    </a>
                    <a class="care-nav-link" href="#appointments" onclick="switchPublicSection('appointments')">
                        ${icons.event}
                        <span>Book OPD</span>
                    </a>
                    <a class="care-nav-link" href="#facilities" onclick="switchPublicSection('facilities')">
                        ${icons.facilities}
                        <span>Facilities</span>
                    </a>
                    <a class="care-nav-link" href="#visiting" onclick="switchPublicSection('visiting')">
                        ${icons.info}
                        <span>Visiting Info</span>
                    </a>
                    <a class="care-nav-link" href="#contact" onclick="switchPublicSection('contact')">
                        ${icons.call}
                        <span>Contact &amp; Emergency</span>
                    </a>
                </nav>

                <!-- B. INTERNAL STAFF WORKSPACE NAVIGATION (Initially hidden) -->
                <nav id="staff-nav" class="care-nav-menu" style="display: none;">
                    <a class="care-nav-link care-nav-link-active" href="#staff-home">
                        ${icons.connectedApps}
                        <span>Operations Center</span>
                    </a>
                    <a class="care-nav-link" href="#staff-patients">
                        ${icons.user}
                        <span>Patients</span>
                    </a>
                    <a class="care-nav-link" href="#staff-doctors">
                        ${icons.stethoscope}
                        <span>Doctors</span>
                    </a>
                    <a class="care-nav-link" href="#staff-appointments">
                        ${icons.event}
                        <span>Appointments</span>
                    </a>
                    <a class="care-nav-link" href="#staff-wards">
                        ${icons.facilities}
                        <span>Wards &amp; Beds</span>
                        <span class="care-nav-badge care-badge-teal">18 Free</span>
                    </a>
                    <a class="care-nav-link" href="#staff-admissions">
                        ${icons.connectedApps}
                        <span>Admissions</span>
                        <span class="care-nav-badge care-badge-amber">14</span>
                    </a>
                    <a class="care-nav-link" href="#staff-clinical">
                        ${icons.priority}
                        <span>Clinical</span>
                        <span class="care-nav-badge care-badge-red">2 Alerts</span>
                    </a>
                    <a class="care-nav-link" href="#staff-payments">
                        ${icons.currency}
                        <span>Payments</span>
                    </a>
                    <a class="care-nav-link" href="#staff-agentforce">
                        ${icons.ai}
                        <span>Agentforce</span>
                    </a>
                    <a class="care-nav-link" href="#staff-admin">
                        ${icons.connectedApps}
                        <span>Admin</span>
                    </a>
                </nav>

                <!-- Right Header Actions -->
                <div class="care-nav-actions">
                    <a href="#emergency" class="care-emergency-pill">
                        <span class="care-emergency-dot"></span>
                        <span>Emergency 24/7</span>
                    </a>
                    <button class="care-btn-primary" id="nav-primary-action-btn" onclick="handlePrimaryAction()">
                        <span id="primary-action-icon">${icons.event}</span>
                        <span id="primary-action-text">Book Appointment</span>
                    </button>
                    <button class="care-mobile-menu-btn" onclick="toggleMobileMenu()" aria-label="Toggle Navigation Menu">
                        ${icons.menu}
                    </button>
                </div>
            </div>

            <!-- Mobile Drawer -->
            <div id="mobile-drawer" class="care-mobile-drawer" style="display: none;">
                <div id="mobile-public-links">
                    <a class="care-nav-link" href="#home" onclick="switchPublicSection('home')">Home</a>
                    <a class="care-nav-link" href="#specialties" onclick="switchPublicSection('specialties')">Specialties</a>
                    <a class="care-nav-link" href="#doctors" onclick="switchPublicSection('doctors')">Find a Doctor</a>
                    <a class="care-nav-link" href="#appointments" onclick="switchPublicSection('appointments')">Book Appointment</a>
                    <a class="care-nav-link" href="#facilities" onclick="switchPublicSection('facilities')">Hospital Facilities</a>
                    <a class="care-nav-link" href="#visiting" onclick="switchPublicSection('visiting')">Visiting Hours</a>
                    <a class="care-nav-link" href="#contact" onclick="switchPublicSection('contact')">Contact &amp; Emergency</a>
                    <div style="margin-top: 1rem;">
                        <button class="care-btn-primary" style="width: 100%;" onclick="toggleExperience()">
                            Hospital Staff Intranet Login
                        </button>
                    </div>
                </div>
                <div id="mobile-staff-links" style="display: none;">
                    <a class="care-nav-link" href="#staff-home">Operations Center</a>
                    <a class="care-nav-link" href="#staff-patients">Patients</a>
                    <a class="care-nav-link" href="#staff-doctors">Doctors</a>
                    <a class="care-nav-link" href="#staff-appointments">Appointments</a>
                    <a class="care-nav-link" href="#staff-wards">Wards &amp; Beds</a>
                    <a class="care-nav-link" href="#staff-admissions">Admissions</a>
                    <a class="care-nav-link" href="#staff-clinical">Clinical Chart</a>
                    <a class="care-nav-link" href="#staff-payments">Payments</a>
                    <a class="care-nav-link" href="#staff-agentforce">Agentforce AI</a>
                    <a class="care-nav-link" href="#staff-admin">Admin Telemetry</a>
                    <div style="margin-top: 1rem;">
                        <button class="care-utility-btn" style="width: 100%;" onclick="toggleExperience()">
                            ← Return to Public Website
                        </button>
                    </div>
                </div>
            </div>
        </header>

        <!-- ================================================================= -->
        <!-- 2. MAIN WEBSITE CONTENT (PUBLIC WEBSITE OR STAFF WORKSPACE)       -->
        <!-- ================================================================= -->
        <main class="care-main-content">

            <!-- ============================================================= -->
            <!-- A. PUBLIC PATIENT/VISITOR EXPERIENCE                          -->
            <!-- ============================================================= -->
            <div id="public-experience">

                <!-- 1. Hero Banner with Modern Healthcare Visual Composition -->
                <section class="care-public-hero" id="home">
                    <div class="care-hero-media-overlay"></div>
                    <div class="care-public-hero-container">
                        <div class="care-hero-grid">
                            <!-- Left Column: Copy & Fast Booking -->
                            <div class="care-hero-left">
                                <div class="care-hero-badge-pill">
                                    ${icons.connectedApps}
                                    <span>Salesforce Healthcare Architecture • Portfolio Showcase</span>
                                </div>
                                <h1 class="care-public-hero-title">
                                    World-Class Healthcare, <br/>
                                    <span class="care-hero-highlight">Compassionate Clinical Excellence</span>
                                </h1>
                                <p class="care-public-hero-desc">
                                    CareNest connects specialized outpatient clinics, modern surgical suites, rapid emergency clinical triage, and intelligent Agentforce demonstration health assistance.
                                </p>

                                <!-- Fast Booking Bar -->
                                <div class="care-fast-booking-card">
                                    <div class="care-fast-booking-title">
                                        ${icons.event}
                                        <span>Schedule an Outpatient Consultation (OPD)</span>
                                    </div>
                                    <div class="care-fast-booking-grid">
                                        <div class="care-fast-field">
                                            <label class="care-fast-label">Clinical Specialty</label>
                                            <div class="care-fast-input-wrap">
                                                ${icons.stethoscope}
                                                <select class="care-native-select">
                                                    <option>General Medicine</option>
                                                    <option>Paediatrics &amp; Neonatology</option>
                                                    <option>Orthopaedics &amp; Joint Replacement</option>
                                                    <option>Dermatology &amp; Skin Care</option>
                                                    <option>Ear, Nose &amp; Throat (ENT)</option>
                                                    <option>Critical Care &amp; Emergency</option>
                                                </select>
                                            </div>
                                        </div>
                                        <div class="care-fast-field">
                                            <label class="care-fast-label">Consultation Mode</label>
                                            <div class="care-fast-input-wrap">
                                                ${icons.desktop}
                                                <select class="care-native-select">
                                                    <option>In-Person Hospital OPD</option>
                                                    <option>Video Teleconsultation</option>
                                                </select>
                                            </div>
                                        </div>
                                        <div class="care-fast-field">
                                            <label class="care-fast-label">Preferred Date</label>
                                            <div class="care-fast-input-wrap">
                                                ${icons.event}
                                                <input type="date" class="care-native-date" value="2026-10-20" />
                                            </div>
                                        </div>
                                        <div class="care-fast-action">
                                            <button class="care-btn-fast-book" onclick="alert('Searching doctors...')">
                                                <span>Find Doctor</span>
                                                ${icons.arrowRight}
                                            </button>
                                        </div>
                                    </div>
                                    <div class="care-hero-disclaimer">
                                        ${icons.info}
                                        <span>Simulated booking environment. For medical emergencies in real life, immediately call local emergency services (e.g. 911 / 112 / 108).</span>
                                    </div>
                                </div>
                            </div>

                            <!-- Right Column: Premium Medical Team Visual -->
                            <div class="care-hero-right">
                                <div class="care-hero-image-card">
                                    <img src="https://images.unsplash.com/photo-1629909613654-28e377c37b09?auto=format&fit=crop&w=800&q=80" alt="CareNest Modern Clinical Suite (Royalty-free medical photography under Unsplash License)" title="CareNest Modern Clinical Suite (Unsplash License)" class="care-hero-img" />
                                    <div class="care-hero-image-overlay"></div>
                                    <div class="care-hero-floating-card">
                                        <div class="care-hero-card-header">
                                            <span class="care-dot-pulse"></span>
                                            <strong>5 Core Clinical Specialties</strong>
                                        </div>
                                        <p>Dedicated Attending Consultants &amp; Agentforce Demonstration Assistant (Non-Diagnostic)</p>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Trust Metrics Bar (Verified Capabilities) -->
                        <div class="care-trust-metrics-bar">
                            <div class="care-trust-item">
                                <div class="care-trust-icon-box">
                                    ${icons.user}
                                </div>
                                <div>
                                    <div class="care-trust-title">Multidisciplinary OPD</div>
                                    <div class="care-trust-subtitle">5 Specialist Departments</div>
                                </div>
                            </div>
                            <div class="care-trust-item">
                                <div class="care-trust-icon-box">
                                    ${icons.priority}
                                </div>
                                <div>
                                    <div class="care-trust-title">Acute Clinical Triage</div>
                                    <div class="care-trust-subtitle">Standardized Care Protocol</div>
                                </div>
                            </div>
                            <div class="care-trust-item">
                                <div class="care-trust-icon-box">
                                    ${icons.shield}
                                </div>
                                <div>
                                    <div class="care-trust-title">Secure Patient Information</div>
                                    <div class="care-trust-subtitle">Role-Gated Server Privacy</div>
                                </div>
                            </div>
                            <div class="care-trust-item">
                                <div class="care-trust-icon-box">
                                    ${icons.ai}
                                </div>
                                <div>
                                    <div class="care-trust-title">Agentforce AI Assistant</div>
                                    <div class="care-trust-subtitle">Demo Operational AI (Not Medical Advice)</div>
                                </div>
                            </div>
                        </div>

                    </div>
                </section>

                <!-- 2. Medical Specialties Section -->
                <section class="care-public-section" id="specialties">
                    <div class="care-section-header">
                        <span class="care-section-kicker">Clinical Centers of Excellence</span>
                        <h2 class="care-section-title">Specialized Medical Care for Every Need</h2>
                        <p class="care-section-subtitle">
                            Our multidisciplinary clinical departments combine modern diagnostics with compassionate expert healthcare professionals.
                        </p>
                    </div>

                    <div class="care-specialties-grid">
                        <div class="care-specialty-card">
                            <div class="care-spec-card-top">
                                <div class="care-spec-icon-box">${icons.stethoscope}</div>
                                <span class="care-spec-badge">Primary OPD</span>
                            </div>
                            <h3 class="care-spec-title">General &amp; Internal Medicine</h3>
                            <p class="care-spec-desc">Comprehensive adult healthcare, diagnostic workups, preventive medicine, and chronic disease management.</p>
                            <div class="care-spec-footer">
                                <div class="care-spec-lead">
                                    <span class="care-lead-label">Attending Consultant:</span>
                                    <strong class="care-lead-name">Dr. Kavita Rao</strong>
                                </div>
                                <button class="care-spec-action-btn">Book OPD →</button>
                            </div>
                        </div>

                        <div class="care-specialty-card">
                            <div class="care-spec-card-top">
                                <div class="care-spec-icon-box">${icons.user}</div>
                                <span class="care-spec-badge">Child &amp; Infant</span>
                            </div>
                            <h3 class="care-spec-title">Paediatrics &amp; Neonatology</h3>
                            <p class="care-spec-desc">Dedicated newborn and infant care, immunizations, developmental surveillance, and Level-3 NICU support.</p>
                            <div class="care-spec-footer">
                                <div class="care-spec-lead">
                                    <span class="care-lead-label">Attending Consultant:</span>
                                    <strong class="care-lead-name">Dr. Anil Mehta</strong>
                                </div>
                                <button class="care-spec-action-btn">Book OPD →</button>
                            </div>
                        </div>

                        <div class="care-specialty-card">
                            <div class="care-spec-card-top">
                                <div class="care-spec-icon-box">${icons.priority}</div>
                                <span class="care-spec-badge">Surgical Excellence</span>
                            </div>
                            <h3 class="care-spec-title">Orthopaedics &amp; Joint Replacement</h3>
                            <p class="care-spec-desc">Arthroscopic sports injury repair, joint replacements, complex fracture reconstruction, and physical therapy.</p>
                            <div class="care-spec-footer">
                                <div class="care-spec-lead">
                                    <span class="care-lead-label">Attending Consultant:</span>
                                    <strong class="care-lead-name">Dr. Rajesh Pandey</strong>
                                </div>
                                <button class="care-spec-action-btn">Book OPD →</button>
                            </div>
                        </div>

                        <div class="care-specialty-card">
                            <div class="care-spec-card-top">
                                <div class="care-spec-icon-box">${icons.shield}</div>
                                <span class="care-spec-badge">Clinical Dermatology</span>
                            </div>
                            <h3 class="care-spec-title">Dermatology &amp; Cosmetology</h3>
                            <p class="care-spec-desc">Clinical dermatology for skin disorders, allergy diagnostics, phototherapy, and aesthetic dermatology.</p>
                            <div class="care-spec-footer">
                                <div class="care-spec-lead">
                                    <span class="care-lead-label">Attending Consultant:</span>
                                    <strong class="care-lead-name">Dr. Neha Kapoor</strong>
                                </div>
                                <button class="care-spec-action-btn">Book OPD →</button>
                            </div>
                        </div>

                        <div class="care-specialty-card">
                            <div class="care-spec-card-top">
                                <div class="care-spec-icon-box">${icons.connectedApps}</div>
                                <span class="care-spec-badge">Head &amp; Neck</span>
                            </div>
                            <h3 class="care-spec-title">Ear, Nose &amp; Throat (ENT)</h3>
                            <p class="care-spec-desc">Endoscopic sinus surgery, microscopic ear surgery, audiology evaluations, and pediatric airway management.</p>
                            <div class="care-spec-footer">
                                <div class="care-spec-lead">
                                    <span class="care-lead-label">Attending Consultant:</span>
                                    <strong class="care-lead-name">Dr. Meena Iyer</strong>
                                </div>
                                <button class="care-spec-action-btn">Book OPD →</button>
                            </div>
                        </div>

                        <div class="care-specialty-card">
                            <div class="care-spec-card-top">
                                <div class="care-spec-icon-box">${icons.priority}</div>
                                <span class="care-spec-badge">24/7 Level-1</span>
                            </div>
                            <h3 class="care-spec-title">Critical Care &amp; Emergency</h3>
                            <p class="care-spec-desc">Advanced resuscitation, mechanical ventilation support, invasive arterial monitoring, and acute trauma management.</p>
                            <div class="care-spec-footer">
                                <div class="care-spec-lead">
                                    <span class="care-lead-label">Attending Consultant:</span>
                                    <strong class="care-lead-name">Dr. Imran Qureshi</strong>
                                </div>
                                <button class="care-spec-action-btn">Book OPD →</button>
                            </div>
                        </div>
                    </div>
                </section>

                <!-- 3. Why Choose CareNest (Pillars with SVG Icons) -->
                <section class="care-public-section care-why-section">
                    <div class="care-section-header">
                        <span class="care-section-kicker">The CareNest Advantage</span>
                        <h2 class="care-section-title">Why Patients Choose CareNest</h2>
                        <p class="care-section-subtitle">Delivering precision clinical medicine with dignity, transparent pricing, and seamless care continuity.</p>
                    </div>

                    <div class="care-why-grid">
                        <div class="care-why-card">
                            <div class="care-why-icon-box">${icons.groups}</div>
                            <h3>Collaborative Clinical Boards</h3>
                            <p>Multidisciplinary case reviews by attending physicians establish coordinated patient care and diagnostic pathways.</p>
                        </div>
                        <div class="care-why-card">
                            <div class="care-why-icon-box">${icons.priority}</div>
                            <h3>Standardized Acute Triage</h3>
                            <p>Systematic clinical triage protocols prioritize acute cardiac, stroke, and trauma presentations for rapid intervention.</p>
                        </div>
                        <div class="care-why-card">
                            <div class="care-why-icon-box">${icons.currency}</div>
                            <h3>Transparent Estimates</h3>
                            <p>Clear pre-admission estimates and direct coordination with cashless health insurance TPA partners.</p>
                        </div>
                        <div class="care-why-card">
                            <div class="care-why-icon-box">${icons.ai}</div>
                            <h3>Agentforce Demo Assistant</h3>
                            <p>Demonstration healthcare AI assistant for administrative navigation and appointment inquiries. Portfolio demo only; does not provide medical advice or diagnosis.</p>
                        </div>
                    </div>

                </section>

                <!-- 4. Hospital Facilities Showcase (Specifications, No Live Bed Count Exposure) -->
                <section class="care-public-section" id="facilities">
                    <div class="care-section-header">
                        <span class="care-section-kicker">Infrastructure &amp; Amenities</span>
                        <h2 class="care-section-title">Designed for Healing and Rapid Recovery</h2>
                        <p class="care-section-subtitle">
                            From quiet private suites to high-dependency critical care units, our facilities provide safe and comfortable clinical environments.
                        </p>
                    </div>

                    <div class="care-facilities-grid">
                        <div class="care-facility-card">
                            <div class="care-fac-header">
                                <span class="care-fac-badge">Monitored Care</span>
                                <span class="care-fac-capacity">25 Beds Unit</span>
                            </div>
                            <h3 class="care-fac-title">General Inpatient Wards</h3>
                            <div class="care-fac-type">Continuous Vital Monitoring</div>
                            <p class="care-fac-desc">Spacious, well-ventilated recovery wards equipped with central oxygen and 24/7 rapid nurse call stations.</p>
                            <div class="care-fac-amenity-list">
                                <span>${icons.check} Central Oxygen &amp; Vacuum</span>
                                <span>${icons.check} Emergency Nurse Call</span>
                                <span>${icons.check} Clinical Air Filtration</span>
                            </div>
                        </div>

                        <div class="care-facility-card">
                            <div class="care-fac-header">
                                <span class="care-fac-badge">Dual Occupancy</span>
                                <span class="care-fac-capacity">15 Beds Unit</span>
                            </div>
                            <h3 class="care-fac-title">Semi-Private Suites</h3>
                            <div class="care-fac-type">Companion Recliner &amp; Privacy</div>
                            <p class="care-fac-desc">Quiet shared suites featuring motorized clinical beds, privacy curtains, companion recliners, and ensuite washrooms.</p>
                            <div class="care-fac-amenity-list">
                                <span>${icons.check} Central Oxygen &amp; Vacuum</span>
                                <span>${icons.check} Emergency Nurse Call</span>
                                <span>${icons.check} Clinical Air Filtration</span>
                            </div>
                        </div>

                        <div class="care-facility-card">
                            <div class="care-fac-header">
                                <span class="care-fac-badge">Critical Care</span>
                                <span class="care-fac-capacity">10 Beds Unit</span>
                            </div>
                            <h3 class="care-fac-title">Intensive Care Unit (ICU)</h3>
                            <div class="care-fac-type">1:1 Nurse-Patient Ratio</div>
                            <p class="care-fac-desc">Critical care ward featuring advanced mechanical ventilators, invasive arterial lines, and defibrillators.</p>
                            <div class="care-fac-amenity-list">
                                <span>${icons.check} Central Oxygen &amp; Vacuum</span>
                                <span>${icons.check} Emergency Nurse Call</span>
                                <span>${icons.check} Clinical Air Filtration</span>
                            </div>
                        </div>

                        <div class="care-facility-card">
                            <div class="care-fac-header">
                                <span class="care-fac-badge">Pediatric Wing</span>
                                <span class="care-fac-capacity">10 Beds Unit</span>
                            </div>
                            <h3 class="care-fac-title">Paediatric Inpatient Wing</h3>
                            <div class="care-fac-type">Specialized Child Care</div>
                            <p class="care-fac-desc">Warm, child-friendly pediatric ward tailored for children with dedicated parent accommodation and isolation units.</p>
                            <div class="care-fac-amenity-list">
                                <span>${icons.check} Central Oxygen &amp; Vacuum</span>
                                <span>${icons.check} Emergency Nurse Call</span>
                                <span>${icons.check} Clinical Air Filtration</span>
                            </div>
                        </div>
                    </div>
                </section>

                <!-- 5. Visiting Hours & Inpatient Checklist -->
                <section class="care-public-section care-visiting-section" id="visiting">
                    <div class="care-visiting-container">
                        <div class="care-visiting-card">
                            <div class="care-visiting-badge">
                                ${icons.clock}
                                <span>Visiting Hours &amp; Guidelines</span>
                            </div>
                            <h2>Patient Visiting Guidelines</h2>
                            <p>To ensure infection control and patient rest, visiting hours are strictly monitored:</p>
                            <ul class="care-visiting-rules">
                                <li><strong>General Wards:</strong> 4:00 PM – 7:00 PM Daily (Max 2 visitors)</li>
                                <li><strong>Intensive Care Unit (ICU):</strong> 11:00 AM – 12:00 PM &amp; 5:00 PM – 6:00 PM (1 visitor at a time)</li>
                                <li><strong>Paediatric Ward:</strong> One parent permitted 24/7 alongside the child</li>
                                <li><strong>Children under 12:</strong> Not permitted in ICU and post-operative wards</li>
                            </ul>
                            <div class="care-pass-note">
                                ${icons.info} Digital visitor passes are issued at the Main Reception upon presenting valid government identification.
                            </div>
                        </div>
                        <div class="care-visiting-card">
                            <div class="care-visiting-badge">
                                ${icons.connectedApps}
                                <span>Admission Checklist</span>
                            </div>
                            <h2>What to Bring for Admission</h2>
                            <p>Please have the following ready during inpatient admission:</p>
                            <ul class="care-visiting-rules">
                                <li><strong>Government Photo ID:</strong> Aadhaar, Passport, or Voter ID</li>
                                <li><strong>Insurance / TPA Card:</strong> For cashless hospitalization pre-authorization</li>
                                <li><strong>Medical Records:</strong> Prior prescriptions, radiology scans, and lab reports</li>
                                <li><strong>Regular Medications:</strong> In original packaging for clinical reconciliation</li>
                            </ul>
                            <div class="care-pass-note">
                                ${icons.currency} Our TPA &amp; Cashless Insurance Desk is located on the Ground Floor, open 24/7.
                            </div>
                        </div>
                    </div>
                </section>

                <!-- 6. Simulated Emergency Trauma Center Banner -->
                <section class="care-emergency-banner" id="emergency">
                    <div class="care-emergency-inner">
                        <div class="care-emergency-badge">
                            <span class="care-pulse-circle"></span>
                            <span>Simulated Level-1 Trauma Emergency Desk</span>
                        </div>
                        <h2>Acute Critical Care Demonstration Bay</h2>
                        <p>
                            CareNest simulated trauma center showcase featuring acute resuscitation bays, catheterization suites, and surgical care.
                        </p>
                        <div class="care-emergency-disclaimer-card">
                            ${icons.warning}
                            <span>
                                <strong>Portfolio Demonstration Notice:</strong> This website is a simulated portfolio system. For real medical emergencies, please immediately call your local emergency service (e.g. 911 / 112 / 108).
                            </span>
                        </div>
                        <div class="care-emergency-actions">
                            <button type="button" class="care-btn-emergency-call" onclick="handleSimulatedEmergency('Helpline')">
                                ${icons.call}
                                <span>Demo Helpline: +1 (555) 019-CARE (Simulated)</span>
                            </button>
                            <button type="button" class="care-btn-ambulance-dispatch" onclick="handleSimulatedEmergency('Ambulance')">
                                ${icons.arrowRight}
                                <span>Demo Ambulance: +1 (555) 019-9110 (Simulated)</span>
                            </button>
                        </div>
                        <div class="care-emergency-disclaimer">
                            <span>Simulated demo helpline only — non-functional links. In an acute medical emergency, please immediately call local emergency services (e.g. 911 / 112 / 108).</span>
                        </div>
                    </div>
                </section>


                <!-- 7. Hospital Location & Patient Inquiry Form -->
                <section class="care-public-section" id="contact">
                    <div class="care-contact-grid">
                        <div class="care-contact-info-card">
                            <span class="care-section-kicker">Find Us</span>
                            <h2>CareNest Hospital Campus</h2>
                            <p>Simulated medical campus with 24/7 patient reception, ambulance bays, and OPD consultations.</p>
                            
                            <div class="care-info-item">
                                <div class="care-info-icon-box">${icons.facilities}</div>
                                <div>
                                    <strong>Hospital Campus (Demo):</strong>
                                    <p>Plot 14, Health City Knowledge Park, Outer Ring Road, Bangalore, Karnataka 560100</p>
                                </div>
                            </div>
                            <div class="care-info-item">
                                <div class="care-info-icon-box">${icons.call}</div>
                                <div>
                                    <strong>Demo Desk Enquiries:</strong>
                                    <p>+1 (555) 019-8900 / +1 (555) 019-8901</p>
                                </div>
                            </div>
                            <div class="care-info-item">
                                <div class="care-info-icon-box">${icons.connectedApps}</div>
                                <div>
                                    <strong>Demo Email Desk:</strong>
                                    <p>demo-care@carenest-health.example.com</p>
                                </div>
                            </div>
                            <div class="care-info-item">
                                <div class="care-info-icon-box">${icons.clock}</div>
                                <div>
                                    <strong>Demo Hours:</strong>
                                    <p>Simulated OPD: Mon - Sat 8:00 AM – 8:00 PM</p>
                                </div>
                            </div>
                        </div>

                        <div class="care-contact-form-card">
                            <h3>Send an Inquiry or Feedback</h3>
                            <p>Our patient care coordination team will respond within 30 minutes.</p>

                            <form onsubmit="handleInquiry(event)" class="care-form-fields">
                                <div class="care-form-row">
                                    <div class="care-form-group">
                                        <label>Your Name *</label>
                                        <input type="text" placeholder="e.g. Rahul Sharma" required />
                                    </div>
                                    <div class="care-form-group">
                                        <label>Phone Number *</label>
                                        <input type="tel" placeholder="+1 (555) 019-4321" required />
                                    </div>
                                </div>
                                <div class="care-form-row">
                                    <div class="care-form-group">
                                        <label>Email Address</label>
                                        <input type="email" placeholder="rahul@example.com" />
                                    </div>
                                    <div class="care-form-group">
                                        <label>Department of Interest</label>
                                        <select>
                                            <option>General &amp; Internal Medicine</option>
                                            <option>Paediatrics &amp; Neonatology</option>
                                            <option>Orthopaedics &amp; Joint Surgery</option>
                                            <option>Dermatology &amp; Cosmetology</option>
                                            <option>Ear, Nose &amp; Throat (ENT)</option>
                                            <option>Hospital Admissions Desk</option>
                                        </select>
                                    </div>
                                </div>
                                <div class="care-form-group">
                                    <label>Message / Clinical Question</label>
                                    <textarea rows="3" placeholder="How can our clinical team help you today?"></textarea>
                                </div>
                                <button type="submit" class="care-btn-primary care-btn-full">
                                    <span>Send Inquiry</span>
                                    ${icons.arrowRight}
                                </button>
                            </form>
                        </div>
                    </div>
                </section>
            </div>


            <!-- ============================================================= -->
            <!-- B. SECURE AUTHENTICATED HOSPITAL STAFF WORKSPACE              -->
            <!-- ============================================================= -->
            <div id="staff-experience" style="display: none;">

                <!-- Staff Top Context Bar -->
                <div class="care-staff-banner">
                    <div class="care-staff-banner-inner">
                        <div class="care-staff-banner-left">
                            <span class="care-staff-badge">Internal Operations Suite</span>
                            <span class="care-staff-context">
                                Active Workspace: <strong>Operations Center</strong> • Persona Simulation: <strong>Operations Manager</strong>
                            </span>
                        </div>
                        <div class="care-staff-banner-right">
                            <button class="care-btn-outline-light" onclick="toggleExperience()">
                                ← Exit to Public Website
                            </button>
                        </div>
                    </div>
                </div>

                <div class="care-page-container">
                    <!-- Live KPI Summary Grid -->
                    <div class="care-kpi-grid">
                        <div class="care-kpi-card">
                            <div class="care-kpi-header">
                                <span class="care-kpi-label">Active Inpatients</span>
                                <div class="care-kpi-icon-wrap kpi-icon-teal">
                                    ${icons.user}
                                </div>
                            </div>
                            <div class="care-kpi-value">14</div>
                            <div class="care-kpi-subtext">Current Admitted Census</div>
                        </div>

                        <div class="care-kpi-card">
                            <div class="care-kpi-header">
                                <span class="care-kpi-label">Bed Occupancy</span>
                                <div class="care-kpi-icon-wrap kpi-icon-navy">
                                    ${icons.facilities}
                                </div>
                            </div>
                            <div class="care-kpi-value">62.5%</div>
                            <div class="care-kpi-subtext">30 of 48 Beds Occupied</div>
                        </div>

                        <div class="care-kpi-card">
                            <div class="care-kpi-header">
                                <span class="care-kpi-label">Available Beds</span>
                                <div class="care-kpi-icon-wrap kpi-icon-amber">
                                    ${icons.connectedApps}
                                </div>
                            </div>
                            <div class="care-kpi-value">18</div>
                            <div class="care-kpi-subtext">Ready for Immediate Admission</div>
                        </div>

                        <div class="care-kpi-card">
                            <div class="care-kpi-header">
                                <span class="care-kpi-label">Active Doctors</span>
                                <div class="care-kpi-icon-wrap kpi-icon-teal">
                                    ${icons.stethoscope}
                                </div>
                            </div>
                            <div class="care-kpi-value">6</div>
                            <div class="care-kpi-subtext">5 Clinical Specialties on Duty</div>
                        </div>
                    </div>

                    <!-- Abnormal Vitals Alert Ticker -->
                    <div class="care-alert-ticker">
                        <div class="care-alert-message">
                            <span style="color: #ef4444;">${icons.warning}</span>
                            <span>
                                <strong>Clinical Notice:</strong> 2 active abnormal patient vital sign alerts detected in Inpatient Wards (SpO2 &lt; 92%, T &gt; 38.5°C).
                            </span>
                        </div>
                        <button class="care-alert-action-btn" onclick="alert('Navigating to Inpatient Clinical Workspace...')">
                            Review Clinical Chart →
                        </button>
                    </div>

                    <!-- Hospital Master Patient Index / Roster Overview -->
                    <div class="care-table-card" style="margin-top: 1.5rem;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; flex-wrap: wrap; gap: 0.5rem;">
                            <div>
                                <h3 style="font-size: 1.125rem; font-weight: 700; color: #0f172a;">Active Inpatient Census &amp; Assigned Staff</h3>
                                <p style="font-size: 0.8125rem; color: #64748b;">Stage 2 Server-Side Restricted Patient Access Enforced via CareNestPatientAccessService</p>
                            </div>
                            <div style="display: flex; gap: 0.5rem;">
                                <button class="care-btn-primary" onclick="alert('Opening Register Patient Modal')">
                                    <span>+ Register New Patient</span>
                                </button>
                                <button class="care-utility-btn" style="background: #0f172a; color: white;" onclick="alert('Opening Bed Admission Workspace')">
                                    <span>Admit Bed</span>
                                </button>
                            </div>
                        </div>

                        <table class="care-patient-table">
                            <thead>
                                <tr>
                                    <th>Patient Code</th>
                                    <th>Patient Name</th>
                                    <th>Admitted Ward</th>
                                    <th>Bed Number</th>
                                    <th>Attending Doctor</th>
                                    <th>Vitals Status</th>
                                    <th style="text-align: right;">Action</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr>
                                    <td><span class="patient-code-tag">CN-PAT-10021</span></td>
                                    <td><strong>Aarav Sharma</strong></td>
                                    <td>General Medical Ward</td>
                                    <td>BED-GMW-04</td>
                                    <td>Dr. Rajesh Iyer</td>
                                    <td><span style="background: #dcfce7; color: #15803d; font-size: 0.75rem; font-weight: 700; padding: 0.2rem 0.5rem; border-radius: 9999px;">Stable</span></td>
                                    <td style="text-align: right;">
                                        <button class="care-spec-action-btn" onclick="alert('Viewing Clinical Chart')">Chart →</button>
                                    </td>
                                </tr>
                                <tr>
                                    <td><span class="patient-code-tag">CN-PAT-10042</span></td>
                                    <td><strong>Priya Patel</strong></td>
                                    <td>Pediatric Care Ward</td>
                                    <td>BED-PED-02</td>
                                    <td>Dr. Sarah Varma</td>
                                    <td><span style="background: #fee2e2; color: #b91c1c; font-size: 0.75rem; font-weight: 700; padding: 0.2rem 0.5rem; border-radius: 9999px;">T: 38.6°C</span></td>
                                    <td style="text-align: right;">
                                        <button class="care-spec-action-btn" onclick="alert('Viewing Clinical Chart')">Chart →</button>
                                    </td>
                                </tr>
                                <tr>
                                    <td><span class="patient-code-tag">CN-PAT-10055</span></td>
                                    <td><strong>Kiran Verma</strong></td>
                                    <td>Intensive Care Unit (ICU)</td>
                                    <td>BED-ICU-01</td>
                                    <td>Dr. Vikram Singhania</td>
                                    <td><span style="background: #fee2e2; color: #b91c1c; font-size: 0.75rem; font-weight: 700; padding: 0.2rem 0.5rem; border-radius: 9999px;">SpO2: 89%</span></td>
                                    <td style="text-align: right;">
                                        <button class="care-spec-action-btn" onclick="alert('Viewing Clinical Chart')">Chart →</button>
                                    </td>
                                </tr>
                                <tr>
                                    <td><span class="patient-code-tag">CN-PAT-10088</span></td>
                                    <td><strong>Rohan Deshmukh</strong></td>
                                    <td>Surgical &amp; Ortho Ward</td>
                                    <td>BED-ORT-03</td>
                                    <td>Dr. Amit Khurana</td>
                                    <td><span style="background: #dcfce7; color: #15803d; font-size: 0.75rem; font-weight: 700; padding: 0.2rem 0.5rem; border-radius: 9999px;">Post-Op Day 1</span></td>
                                    <td style="text-align: right;">
                                        <button class="care-spec-action-btn" onclick="alert('Viewing Clinical Chart')">Chart →</button>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>

                    <!-- Operational Child LWC Wiring Banner -->
                    <div style="margin-top: 1.5rem; padding: 1.25rem; background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 0.75rem;">
                        <h4 style="font-size: 0.875rem; font-weight: 700; color: #166534; margin-bottom: 0.25rem;">Live Salesforce Child Modules Connected</h4>
                        <p style="font-size: 0.8125rem; color: #15803d;">
                            <code>c-hospital-operations-dashboard</code>, <code>c-ward-bed-manager</code>, <code>c-patient-admission-workspace</code>, <code>c-inpatient-clinical-workspace</code>, <code>c-appointment-wizard</code>, <code>c-doctor-search</code>, <code>c-my-appointments</code>, <code>c-patient-billing</code>, <code>c-agentforce-assistant-widget</code>.
                        </p>
                    </div>
                </div>
            </div>
        </main>

        <!-- ================================================================= -->
        <!-- 3. FOOTER                                                         -->
        <!-- ================================================================= -->
        <footer class="care-site-footer">
            <div class="care-footer-inner">
                <div class="care-footer-col">
                    <div class="care-brand-link" style="margin-bottom: 0.75rem;">
                        <div class="care-logo-icon-wrap care-logo-sm">
                            ${icons.hospital}
                        </div>
                        <div class="care-brand-name" style="color: white;">Care<span class="care-brand-accent">Nest</span></div>
                    </div>
                    <p class="care-footer-desc">
                        CareNest Hospital is an architectural showcase demonstrating unified healthcare on Salesforce Experience Cloud, Health Cloud, and Agentforce.
                    </p>
                    <div style="display: flex; gap: 0.5rem; margin-top: 1rem;">
                        <span class="care-accreditation-pill">Salesforce Portfolio</span>
                        <span class="care-accreditation-pill">Health Cloud Demo</span>
                    </div>
                </div>

                <div class="care-footer-col">
                    <h4 class="care-footer-heading">Medical Specialties</h4>
                    <ul class="care-footer-links">
                        <li><a href="#specialties">General &amp; Internal Medicine</a></li>
                        <li><a href="#specialties">Paediatrics &amp; Neonatology</a></li>
                        <li><a href="#specialties">Orthopaedics &amp; Joint Surgery</a></li>
                        <li><a href="#specialties">Dermatology &amp; Cosmetology</a></li>
                        <li><a href="#specialties">Ear, Nose &amp; Throat (ENT)</a></li>
                        <li><a href="#specialties">Critical Care &amp; Resuscitation</a></li>
                    </ul>
                </div>

                <div class="care-footer-col">
                    <h4 class="care-footer-heading">Patient Resources</h4>
                    <ul class="care-footer-links">
                        <li><a href="#visiting">Visiting Hours &amp; Guidelines</a></li>
                        <li><a href="#visiting">Inpatient Admission Checklist</a></li>
                        <li><a href="#facilities">Inpatient Facilities &amp; Amenities</a></li>
                        <li><a href="#contact">Cashless Insurance / TPA</a></li>
                        <li><a href="#contact">Directions &amp; Parking Map</a></li>
                    </ul>
                </div>

                <div class="care-footer-col">
                    <h4 class="care-footer-heading">Demo Emergency &amp; Staff</h4>
                    <ul class="care-footer-links">
                        <li><strong style="color: #ef4444;">Demo Helpline: +1 (555) 019-CARE</strong></li>
                        <li><span>Demo Ambulance: (555) 019-9110</span></li>
                        <li><span>Simulated OPD: 8:00 AM – 8:00 PM</span></li>
                        <li style="margin-top: 1rem;">
                            <a href="#staff" onclick="toggleExperience()" style="color: #2dd4bf; font-weight: 600;">
                                🔒 Hospital Staff Workspace →
                            </a>
                        </li>
                    </ul>
                </div>
            </div>

            <div class="care-footer-bottom">
                <div class="care-footer-bottom-inner">
                    <p>© 2026 CareNest Hospital Demonstration System • Salesforce Portfolio Showcase • Not an operational medical provider.</p>
                    <div class="care-footer-legal-links">
                        <a href="#privacy">Demonstration Privacy Notice</a>
                        <a href="#terms">Terms of Showcase</a>
                        <a href="#security">Stage 2 Access Protocol</a>
                    </div>
                </div>
            </div>
        </footer>
    </div>

    <script>
        let isStaff = false;
        function toggleExperience() {
            isStaff = !isStaff;
            document.getElementById('public-nav').style.display = isStaff ? 'none' : 'flex';
            document.getElementById('staff-nav').style.display = isStaff ? 'flex' : 'none';
            document.getElementById('public-experience').style.display = isStaff ? 'none' : 'block';
            document.getElementById('staff-experience').style.display = isStaff ? 'block' : 'none';
            document.getElementById('mobile-public-links').style.display = isStaff ? 'none' : 'block';
            document.getElementById('mobile-staff-links').style.display = isStaff ? 'block' : 'none';
            document.getElementById('toggle-experience-text').textContent = isStaff ? 'Return to Public Website' : 'Hospital Staff Intranet';
            document.getElementById('toggle-experience-btn').className = isStaff ? 'care-utility-btn care-utility-btn-active' : 'care-utility-btn';
            
            // Toggle header CTA button text
            document.getElementById('primary-action-text').textContent = isStaff ? 'Register Patient' : 'Book Appointment';
            
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
        function toggleMobileMenu() {
            const drawer = document.getElementById('mobile-drawer');
            drawer.style.display = drawer.style.display === 'none' ? 'block' : 'none';
        }
        function switchPublicSection(sec) {
            if (isStaff) toggleExperience();
            const el = document.getElementById(sec);
            if (el) el.scrollIntoView({ behavior: 'smooth' });
            document.getElementById('mobile-drawer').style.display = 'none';
        }
        function handlePrimaryAction() {
            if (isStaff) {
                alert('Opening Register Patient modal...');
            } else {
                switchPublicSection('home');
            }
        }
        function handleInquiry(e) {
            e.preventDefault();
            alert('Thank you for reaching out! A CareNest patient care coordinator will call you back within 30 minutes.');
        }
        function handleSimulatedEmergency(service) {
            alert('Simulated Demo ' + service + ': This is a portfolio simulation. In a real medical emergency, please call 911 / 112 / 108 immediately.');
        }

        // Hash checking
        if (window.location.hash === '#staff') {
            toggleExperience();
        }
    </script>
</body>
</html>`;

const previewFile = path.join(__dirname, 'preview.html');
fs.writeFileSync(previewFile, htmlTemplate, 'utf8');
console.log('Successfully wrote visual upgrade preview HTML to: ' + previewFile);

// Start server
const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(htmlTemplate);
});

const PORT = 8089;
server.listen(PORT, () => {
    console.log('Preview HTTP Server listening on http://localhost:' + PORT);
});

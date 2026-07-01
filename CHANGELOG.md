# Changelog

All notable changes to QBCore Advanced Ambulance Job V2 are recorded here.

## 2.7.2 - 2026-07-01

- Fixed LB Phone requests by explicitly routing `fetchNui` calls to the ambulance resource.
- Added timeout-safe phone and EMS tablet callbacks with QBCore failure notifications.
- Made configured test and scan cards render immediately while package data refreshes.
- Refreshed healthcare app assets and registration to prevent stale, clipped UI builds.

## 2.7.1 - 2026-06-30

- Forced LB Phone to replace the existing Health Care custom-app registration after resource updates.
- Added versioned Health Care HTML, CSS, JavaScript, and icon URLs to bypass CEF cache.
- Added a server-side predefined Test and Scan fallback when SQL rows are missing.
- Added a tablet-side Config fallback when the package catalog callback is empty.
- Fixed empty Test and Scan selection grids after upgrading the resource.

## 2.7.0 - 2026-06-30

- Redesigned the LB Phone Health Care interface for notched phone frames.
- Added a permanent notch-safe top clearance on every page.
- Prevented the compact-height layout from moving content beneath the notch.
- Enlarged the Health Care logo and application title.
- Enlarged navigation, package, booking, report, invoice, tracking, and dialog text.
- Enlarged action controls and status badges.
- Anchored the refresh button in the top-right app header.
- Preserved independent page scrolling with the larger interface.

## 2.6.3 - 2026-06-30

- Changed the progress-bar resource dependency from `qb-progressbar` to `progressbar`.

## 2.6.2 - 2026-06-30

- Fixed predefined Tests and Scans not appearing in Packages and Pricing.
- Added runtime synchronization for missing test-price catalog rows.
- Preserved prices previously edited by EMS.
- Added explicit default prices for all predefined tests and scans.
- Kept Imaging services separated as Scans in the package editor.

## 2.6.1 - 2026-06-30

- Added a dedicated Test And Scan Pricing tab to the EMS tablet.
- Moved all service price and availability controls out of the package editor.
- Added separate Test and Scan catalog counts.
- Added automatic recalculation of every health package after a service price changes.
- Added automatic removal of disabled services from existing packages.
- Kept package discounts applied after the recalculated base price.

## 2.6.0 - 2026-06-30

- Redesigned the EMS health package editor with an advanced procedure catalog.
- Replaced procedure dropdowns with always-visible Test and Scan cards.
- Added immediate selected-card highlighting.
- Added separate selected counts for Tests and Scans.
- Added procedure category and price information to every card.
- Added automatic included-procedure text to the package description.
- Preserved automatic base price, discount, and final price calculations.

## 2.5.2 - 2026-06-30

- Fixed the server/main.lua parser error near the health report insert parameters.
- Replaced the inline SQL parameter expression with precomputed variables.
- Kept the correction inside the existing server/main.lua file.

## 2.5.1 - 2026-06-30

- Replaced the package procedure checkbox grid with multi-select dropdowns.
- Added separate Tests and Scans selectors.
- Added multiple selection support in both dropdowns.
- Added live selected-item counts.
- Kept automatic package base-price and discount calculations.
- Added automatic closing when the other procedure dropdown opens.

## 2.5.0 - 2026-06-30

- Added an LB Phone-style FiveM console update tracker.
- Added semantic version comparison and scheduled update checks.
- Added colored console output for current, available, failed, and installed updates.
- Added automatic HTTPS file installation from a hosted update manifest.
- Added automatic resource restart after successful updates.
- Added the `emsupdate` manual console and ACE-protected command.
- Added convars for the update URL, automatic installation, restart behavior, and check interval.
- Added update path validation and protected `shared/config.lua` from replacement.
- Added an example hosted update manifest.

## 2.4.0 - 2026-06-30

- Redesigned the LB Phone Health Care app shell.
- Fixed pages being cropped inside the LB Phone iframe.
- Added a full-height dynamic viewport layout.
- Added a dedicated scrolling region for the active app page.
- Kept the header, report summary, and navigation stable while content scrolls.
- Added safe-area padding for different phone frames.
- Added compact layouts for short phone screens.
- Added a two-row tab fallback for very narrow screens.
- Added wrapping and overflow protection for package names, prices, reports, findings, invoices, and status notes.
- Added bounded, scrollable booking dialogs.
- Improved light and dark theme contrast.

## 2.3.1 - 2026-06-30

- Audited every EMS tablet button and NUI callback.
- Added QBCore success and error notifications to tablet operations.
- Added missing-patient validation for revive, treatment, records, reports, tests, surgery, and billing.
- Added feedback for package saves, package deletion rules, test pricing, locations, booking progression, and payments.
- Added booking and package loading failure notifications.
- Fixed sidebar overflow so all navigation and close buttons remain accessible.
- Added stable sidebar button dimensions.

## 2.3.0 - 2026-06-30

- Fixed the LB Phone package page remaining in a loading state.
- Added automatic startup migrations for package, pricing, booking, history, and service-location tables.
- Added automatic predefined package seeding.
- Added individual prices and availability controls for every test and scan.
- Added an EMS tablet Package Manager.
- Added editing for predefined packages.
- Added custom health package creation and deletion.
- Added package test selection with automatic base-price calculation.
- Added configurable percentage discounts up to 90 percent.
- Added discounted prices to the phone catalog, checkout charge, booking invoice, and tablet preview.
- Added live package catalog updates for connected LB Phone users.

## 2.2.0 - 2026-06-30

- Added tablet-managed pharmacy and hospital service locations.
- Added automatic coordinate capture from the doctor's current position.
- Added Essential, Cardiac, Trauma, and Complete health packages.
- Added package booking through the LB Phone Health Care app.
- Added cash, card, bank, and pay-at-hospital payment methods.
- Added payment state, invoice numbers, and patient invoice history.
- Added EMS booking queue and protected status transitions.
- Added sample collection, scan completion, report publication, and completion tracking.
- Added patient route guidance to the selected service location.
- Added booking history, duplicate-payment protection, and concurrent-update protection.
- Added Book, Bookings, Reports, and Invoices sections to the phone app.

## 2.1.0 - 2026-06-29

- Added advanced examinations, laboratory tests, ECG, X-ray, CT, MRI, and ultrasound.
- Added blood collection animation with a syringe prop.
- Added configurable X-ray machine object targeting.
- Added chest, head, and limb X-ray machine menus.
- Added trauma, orthopedic, cardiovascular, neurological, abdominal, and wound surgery.
- Added structured SQL-backed medical reports.
- Added the EMS tablet Clinical workspace.
- Added the LB Phone Health Care custom app.
- Added patient-owned report access and report-ready notifications.
- Made legacy qb-phone billing mail optional.

## 2.0.1 - 2026-06-28

- Fixed dead-player hospital respawning by passing separate coordinates to the resurrection native.
- Added reliable per-frame respawn input handling.
- Added an unconscious ground pose at the death location.
- Disabled movement and ragdoll while unconscious.
- Restored movement and ragdoll after revival.
- Replaced the progress-bar export block with the standard QBCore progress callback.
- Added the missing qb-progressbar dependency.

## 2.0.0 - 2026-06-28

- Added the modern EMS command tablet.
- Added death timer, unconscious overlay, EMS alerts, treatment, and revival.
- Added hospital check-in, beds, garages, helipads, armory, stash, and management points.
- Added medical billing and patient treatment records.
- Added usable medical items and configurable EMS vehicles.
- Added Octavista Vespucci EMS and standard QBCore hospital presets.
- Updated the default hospital to QBCore Pillbox.
- Corrected Pillbox beds, check-in, duty, garage, helipad, stash, and respawn coordinates.

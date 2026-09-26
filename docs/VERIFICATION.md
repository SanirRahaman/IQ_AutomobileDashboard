# Verification records

These are dated results, not a live test status. The latest section records the
workspace and appearance checks; the original finishing-pass record is retained
below for historical context.

## Workspace and appearance — 26 September 2026

Verified locally using Flutter 3.24.4:

- `flutter analyze --no-pub`: no issues found.
- `flutter test --no-pub --reporter expanded`: all 103 tests passed.
- `flutter build web --release --no-pub`: production web output generated.
- New tests cover valid/invalid saved appearance, semantic text contrast, System
  following platform appearance, Light/Dark switching, desktop collapse/expand,
  phone drawer navigation and themed evidence at 1440, 820 and 390 pixels.
- Browser inspection covered 1440 and 1280 pixel desktop, 820 pixel tablet and
  390 pixel phone layouts. Sidebar, rail and drawer behaved as intended. The
  common filters wrapped; comparison choices, monthly chart and evidence reflowed.
- Browser checks confirmed Dark and Light preferences survive reload, branch
  filtering changes the URL, explorer Back/Forward retain branch scope, and a
  representative route restores its context after refresh. Desktop sidebar
  collapse/expand and phone menu navigation were exercised.
- Light evidence panels retained their selected record and supporting details
  during a phone-to-desktop resize. Dark chart labels and overview statuses were
  inspected visually. A low-contrast compact export icon found during inspection
  received an explicit foreground colour and a regression assertion.
- No browser console errors were captured in this inspected session.

Analytics and raw data were unchanged. Existing analytics, routing and export
regressions remain in the full suite. No new CSV download, production deployment,
or complete screen-reader/browser compatibility audit was performed. The code and
updated guides remain local at this checkpoint. Browser appearance persists only
where local storage is available; the app remains usable when storage is blocked.

## Performance tabs — 25 September 2026

Verified locally after implementing the visible navigation and comparison choices:

- `flutter analyze --no-pub`: no issues found.
- `flutter test --no-pub --reporter expanded`: all 98 tests passed.
- `flutter build web --release --no-pub`: succeeded; final build took 67.9 seconds.
- Widget interaction checks at 1440, 820 and 390 pixels covered visible measures
  and groups, comparison selection, tab switching, retained branch filters,
  supporting records, sorting and navigation from Overview.
- Router tests covered `/explore/trends` and `/explore/follow-up`, including
  restoration, history state and resetting filters without changing the section.
- Browser inspection at 1280, 820 and 390 pixels confirmed prominent main tabs,
  wrapping controls and readable comparison results. Resolved conversion by
  branches remained selected after navigating to trends and using browser Back.
  Forward and refresh loaded Monthly trends correctly.
- No browser console errors were captured in the inspected session.

The full suite includes the existing analytics and export regressions. This pass
changed presentation/navigation, not formulas or the source dataset. No new CSV
download or production deployment was performed in this pass. The user's existing
lockfile change was preserved; checks used the validated Flutter 3.24.4 toolchain
after temporarily resolving compatible local dependencies.

These checks cover the local Chromium-based browser, not every browser or a full
screen-reader audit. Subsequent documentation-only edits did not rerun the Flutter
suite. The tab implementation remained local and uncommitted at this checkpoint.

---

# Original finishing-pass verification

Verified 17–18 September 2026 against the bundled dataset.

## Automated checks

- Baseline: `flutter analyze` reported no issues; 59 tests passed.
- Final: `flutter analyze` reported no issues; all 77 tests passed.
- Final: `flutter build web --release` succeeded (63.4 seconds).
- Regression coverage includes target matching, missing/duplicate/zero targets,
  partial periods, delivery-date comparisons, snapshot date, active/resolved
  distinctions, data quality and maturity, routing/history restoration,
  asynchronous initial URL loading and retry, and filtered CSV generation.
- Widget layout tests include 1440, 1280, 1024, 820, 768, 600 and 390 pixel widths.

## Browser checks

The release build was served locally. Fresh ports were used to avoid a cached
Flutter service worker obscuring rebuilt code.

- Network: 510 leads, 160 deliveries, 62 active, 35.7% resolved conversion;
  160 / 1426 supplied unit targets; snapshot 31 December 2025.
- Downtown filter changed the URL and showed 97 leads, 40 deliveries, 9 active,
  and 45.5% resolved conversion. Refresh retained this state. Browser Back
  restored the network and Forward restored Downtown.
- December selection updated both URL dates. Branch detail retained that period:
  19 / 48 delivered against target, compared with 7 November deliveries.
- Network December reporting showed 52 deliveries versus 30 in November.
- Explicit representative button opened Meera Menon at `/rep/SR2`, retained
  December, and showed the branch benchmark. Parent navigation retained period.
- Reset removed query filters. Invalid branch/calendar parameters normalized
  safely. A January 2030 view showed zero records and unavailable ratios/targets.
- Findings opened supporting records. Individual records showed customer contact,
  original status history, assigned branch/representative, and snapshot context.
- A real downloaded Downtown December CSV was read back: four rows, all Downtown,
  all created in December, with contacted, test_drive, negotiation and order_placed
  statuses. The browser automation download event timed out, but the actual file
  was downloaded and its content verified on disk.
- All 14 data-quality notices remained accessible.
- Dashboard layouts were visually checked at 1440, 1280, 1024, 768, 600 and 390
  pixels. The mobile evidence dialog reflowed its actions and stayed within the
  viewport; longer vehicle labels wrapped.
- No browser console errors were captured in the inspected session.

This is a local Chromium-based browser check, not a cross-browser or comprehensive
screen-reader certification. Loading/error retry and additional filter combinations
are covered by automated tests; every possible combination was not manually exercised.

## Integrity and scope

The source dataset SHA-256 remained:
`cbaad7c434b3b99e8c5207629ae8f78dd3208385387fa666f4e0d9750fc94592`.

No dependencies were added in this phase; the lockfile matches the finishing-pass
baseline. No deployment was performed and DECISIONS.md was not created.
Representative targets are not supplied and are not invented. Target coverage
limitations are disclosed in the UI and analytics specification.

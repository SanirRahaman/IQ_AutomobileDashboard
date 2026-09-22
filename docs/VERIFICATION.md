# Finishing-pass verification

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

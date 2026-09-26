# yoyotaDealers: understand, run and change the project

A practical guide for someone opening this repository for the first time.

Read [Why it is built this way](PROJECT_DECISIONS_EXPLAINED.md) for the reasoning.
This handbook explains **what exists, how the pieces connect, and where to edit**.
It documents the current implementation, not a proposed future system.

## 1. What this application does

`yoyotaDealers` is a Flutter Web dashboard for dealership managers. Its Dart package
name is `yoyota_dealers`. It reads a bundled dealership dataset and helps users:

- Review lead outcomes, delivered vehicles and active opportunities.
- Compare delivery output with supplied branch targets.
- Investigate branches, representatives, sources, vehicles and sales stages.
- Examine aging opportunities and delivery delays.
- Read explainable findings and inspect the records behind them.
- Download filtered follow-up lists.
- Rank models, branches, representatives and sources across 17 measures, compare
  two groups, and inspect monthly trends with period/maturity warnings.

It is not a live CRM: it does not save edits to customers, send messages, assign
follow-up tasks, authenticate users or connect to a backend. Reloading loads the
bundled dataset again; the URL restores view filters. CSV export does not change data.

## 2. Vocabulary you will encounter

- **Flutter:** the framework that builds the interface.
- **Dart:** the programming language used by this application.
- **Widget:** a piece of interface, such as a card, button or page.
- **Model:** a typed description of data, such as a lead with a status and dates.
- **Service:** code that performs a job such as filtering or calculation.
- **Controller:** the coordinator that stores the selected filters and calculated results.
- **Presenter/view data:** code that turns results into display labels and rows.
- **Scope:** the records included by the current filters.
- **Route:** a location in the app, represented by a URL.
- **Snapshot:** the date through which this dataset contains observed business events.
- **Null/unavailable:** there is no defensible value; it is different from zero.

## 3. Run it locally

You need a Flutter installation with web support and a supported browser. Dart is
included with Flutter. `pubspec.yaml` declares the Dart constraint `^3.5.4`; use a
compatible Flutter SDK. The file is not an exact Flutter-version pin.

From the repository folder:

```bash
flutter --version
flutter doctor
flutter pub get
flutter run -d chrome
```

`flutter doctor` reports environment problems. `pub get` installs the declared
packages. The application has Flutter and Cupertino icons as runtime dependencies;
there is no backend to start and no API key required for the bundled-data version.

If Chrome is unavailable, use the web server and open its printed local address:

```bash
flutter run -d web-server --web-port 8080
```

To check a production build locally:

```bash
flutter build web --release
python3 -m http.server 8080 --directory build/web
```

Open `http://localhost:8080`. Stop the server with Ctrl+C. Python is needed only for
this example static server. Run the Flutter commands from the project root.
Do not edit `build/web`: it is generated output and the next build replaces it.

## 4. Walk through the interface

Start at **Sales performance**. The period and branch controls describe the current
view. “Data as of” describes the dataset, not the selected period or today's date.

The sidebar opens **Overview**, **Comparisons**, **Monthly trends**, **Active
pipeline**, **Deliveries** and **Follow-up lists**. On tablets it becomes an icon
rail with tooltips; on phones, open the menu at the top left. The top bar keeps the
current view, dataset date and appearance menu available. Choose **Light**, **Dark**
or **System**; the browser remembers this choice. Period, branch and additional
filters are shared across pages.

In Comparisons, choose a visible measure first, then choose
Vehicle models, Branches, Representatives or Lead sources. For example,
**Resolved conversion → Branches** shows each branch's resolved conversion.
The measure buttons are grouped into Sales, Conversion, Pipeline, and Losses &
delivery. On smaller screens they wrap rather than scroll horizontally.

Read the KPI tooltips before comparing cards: leads received and resolved conversion
use lead creation dates; vehicles delivered uses delivery dates. The target panel
shows supported branch-month targets. The attention cards explain a finding and
link to its supporting records.

Choose a branch, then review its representatives. Representative buttons open the
employee's performance against the branch context. Parent controls take you back
up while retaining time and other relevant filters. Active-opportunity and delivery
pages provide operational detail. More filters include source, model and status.

Inside evidence dialogs, select a customer record to inspect history and contact
information. **Download follow-up** contains active opportunities; **All records · CSV**
can include delivered/lost records with their real statuses.

## 5. The complete data journey

```text
Bundled JSON
  -> data source reads text
  -> repository calls parser
  -> typed dataset + validation report
  -> feature engineer derives lead facts and snapshot
  -> controller applies selected filters
  -> analytics, targets and insight engines calculate results
  -> presenters prepare labels and rows
  -> Flutter widgets display them
  -> evidence dialogs / CSV provide supporting records
```

The application starts in `lib/main.dart`. `YoyotaDealersApp` prepares the incoming
URL, loads the dataset, displays loading/error/retry states and creates the router.
`AnalysisController` builds the full analytical dataset once and recalculates scoped
results when filters change. `ChangeNotifier` tells listening screens to rebuild.
The router also listens so the URL stays synchronized.

**Important boundary:** widgets display calculations; they must not create their
own competing conversion or target formulas.

## 6. Folder and file map

All paths below are relative to the repository root.

### App startup and appearance

- `lib/main.dart`: launches the application.
- `lib/app/yoyota_dealers_app.dart`: loading, retry, theme and initial URL restoration.
- `lib/app/analysis_router.dart`: route parsing/delegation, page selection, parent navigation.
- `lib/app/app_theme.dart`: shared colours, typography and component styling.
- `web/index.html`, `web/manifest.json`, `web/icons/`, `web/favicon.png`: browser shell and branding.
- `pubspec.yaml`: package information, dependencies and bundled asset registration.
- `pubspec.lock`: resolved dependency versions; do not casually regenerate through upgrades.

### Source data and validation

- `assets/data/dealership_data.json`: immutable supplied dataset.
- `lib/data/models/dealership_models.dart`: metadata, branches, representatives,
  leads/history, targets, deliveries and typed status/role values.
- `lib/data/sources/dealership_data_source.dart`: reads asset text; exposes an interface
  so tests or a future source can supply text without rewriting calculations.
- `lib/data/repositories/dealership_dataset_repository.dart`: connects loading to parsing.
- `lib/data/parsing/dealership_dataset_parser.dart`: schema interpretation and validation.
- `lib/data/validation/validation.dart`: issues, severity and load-result/report types.
- `lib/domain/indexes/dealership_dataset_indexes.dart`: lookup structures for related entities.

### Calculations

- `lib/analytics/models/analytical_lead.dart`: derived lead facts and analytical context.
- `lib/analytics/models/analytics_results.dart`: typed aggregate results and related configuration.
- `lib/analytics/services/lead_feature_engineer.dart`: history-derived facts, ages,
  snapshot, valid durations and maturity.
- `lib/analytics/services/dealership_analytics_engine.dart`: overview, funnel, gates,
  groups, losses, pipeline, deliveries and cohorts.
- `lib/analytics/services/management_performance.dart`: delivery output, target coverage,
  actual/target/variance/attainment and eligible previous-month comparisons.
- `lib/analytics/services/performance_explorer.dart`: typed comparison groups,
  ranking, evidence eligibility and monthly series using the existing engine.

### Filters and coordination

- `lib/application/analysis/analysis_filters.dart`: filter values, equality, inclusive
  UTC date ranges and dimension matching. In `copyWith`, omitted means keep; null means clear.
- `analysis_scope_service.dart`: separate creation-date and delivery-date record sets.
- `analysis_controller.dart`: filter setters, normalization, recalculation and notifications.
- `analysis_results.dart`: the bundle of results consumed by presentation code.
- `analysis_route_codec.dart`: converts filter state to/from URL paths and query parameters.
- `evidence_order.dart`: supporting-record sort order, preserving the link between
  each displayed row and its details, including repeated delivery records.

### Findings and export

- `lib/insights/models/insight_engine_config.dart`: rule thresholds and sample-size requirements.
- `lib/insights/models/management_insight.dart`: findings, evidence, severity and ranking information.
- `lib/insights/services/deterministic_insight_engine.dart`: rule evaluation and ranking.
- `lib/application/export/follow_up_csv.dart`: pure CSV construction and scope/active filtering.
- `lib/platform/download.dart`: conditional platform entry point.
- `lib/platform/download_web.dart`: browser Blob/link download implementation.
- `lib/platform/download_stub.dart`: non-web fallback.
- `tool/print_insights.dart`: command-line inspection of calculated findings.

### Screens

- `lib/features/dashboard/dashboard_page.dart`: main dashboard and filters.
- `dashboard_view_data.dart`: dashboard labels and display-ready results.
- `lib/features/shared/target_panel.dart`: target reporting reused across screens.
- `lib/features/shared/application_shell.dart`: sidebar/rail/drawer, top bar,
  current-page context, snapshot indicator and the shared filter toolbar.
- `lib/features/shared/performance_navigation.dart`: the explorer section enum
  used by its pages and router; the previous tab-strip widget has been removed.
- `lib/app/appearance_controller.dart`: Light/Dark/System preference and sidebar
  collapse state. Appearance persists; collapse state is session-only.
- `lib/platform/preferences*.dart`: browser storage with a safe non-web fallback.
- `lib/features/exploration/exploration_page.dart`: comparison measure/group
  controls, monthly charts, follow-up lists and local presentation state.
- `lib/features/exploration/exploration_presenter.dart`: measure labels,
  definitions, formatting and the four visible measure groups.
- `lib/features/investigation/investigation_page.dart`: branch/representative pages and comparisons.
- `investigation_view_data.dart`: detail-page presentation data.
- `lead_evidence_dialog.dart`: record lists, record detail and export actions.
- `lib/features/operations/operational_pages.dart`: pipeline/delivery screens.
- `operational_view_data.dart`: their display-ready data.

### Tests and reference documents

- `test/data/`: parsing and repository behaviour.
- `test/analytics/`: derived facts, formulas, targets, snapshot and maturity.
- `test/application/`: filters, scope, routes and restoration.
- `test/insights/`: findings and safeguards.
- `test/export/`: CSV content, filtering and escaping.
- `test/features/`, `test/widget_test.dart`: UI, responsive behaviour, startup and retry.
- `test/fixtures/`: small artificial datasets for understandable regression cases.
- `AGENTS.md`: repository rules for coding agents; also useful maintenance constraints.
- `prompts.md`: original project prompt/context, not executable configuration.
- `docs/ANALYTICS_SPEC.md`: exact metric definitions; use it when changing calculations.
- `docs/ARCHITECTURE.md`: deeper structural reference.
- `docs/PRODUCT_UX_NOTES.md`: research and applied presentation principles.
- `docs/VERIFICATION.md`: dated checks and their limits, not a live test status.

## 7. Understand the dataset relationships

A branch has representatives and leads. A lead refers to its branch and assigned
representative and contains status-history entries. A delivery refers back to a lead.
Targets belong to a branch and calendar month, not an individual representative.

The parser expects the canonical schema. Renaming JSON keys does not automatically
teach the app a different format. Unknown status/role values are retained and
flagged rather than quietly translated into known categories.

Keep these concepts separate:

- Current status: the source's present classification.
- History: recorded events describing how the lead progressed.
- Expected close: a planned date, not an observed sale or delivery.
- Deal value: a supplied value, not confirmed profit or a known currency.
- Delivery record: the event used for delivery-date output.

A conflicting current status and history produces a warning. Validation does not
silently fix the source. Inspect the relevant analytical rule before deciding whether
an affected record should participate in a particular calculation.

## 8. Metrics you must not accidentally change

**Resolved conversion:** delivered / (delivered + lost). Active is separate. No
resolved opportunities means unavailable, displayed as a dash rather than 0%.

**Sales journey:** new → contacted → test drive → negotiation → order placed →
delivered. Lost can happen before completion. Missing history steps are not invented.
The management “Close” gate means order placed; it does not mean physical delivery.

**Period filtering:** lead metrics use creation dates; delivery metrics use delivery
dates and linked lead dimensions. Endpoints are inclusive UTC calendar dates.

**Snapshot/aging:** latest observed relevant business timestamp, held constant across
filters. Future expected-close dates do not advance it. The feature engineer also
supports an explicit snapshot override for controlled analysis; this is not a UI filter.
If there are no observed business timestamps at all, the current implementation
falls back to metadata generation time; that fallback is not used for the supplied
populated dataset.

**Maturity:** based on the configured percentile of successful cycles, with a
conservative month-level rule. Immature does not mean lost or necessarily underperforming.

**Targets:** unit deliveries matched to valid branch-month targets. Attainment is
actual / target; variance is actual − target. Partial months retain full targets and
are labelled. Incompatible dimension filters suppress target reporting.

**Delivery comparison:** only eligible complete current/prior calendar months are
compared. A difference in counts is not proof of seasonality or a causal explanation.

**Pipeline bands:** default inactivity boundaries are 7, 14 and 30 days. These are
attention categories, not outcome predictions. Lead age and inactivity are different.

**Delivery delays:** named delay-reason groups are compared with deliveries without
a recorded reason. Association is not causation. Expected-close timeliness is a
proxy because the source does not establish that expected close means delivery.

**Source/vehicle measures:** different denominators answer different questions.
Vehicle value contribution is not profit. Consult `ANALYTICS_SPEC.md` for exact formulas.

## 9. Filters and URLs, with an example

An example route using an ID in the supplied dataset is:

```text
http://localhost:8080/#/?branch=B1&from=2025-12-01&to=2025-12-31
```

The app uses IDs rather than display names; this example is not a production constant.
Main paths after `#` are:

- `/`: Overview.
- `/explore`: Comparisons.
- `/explore/trends`: Monthly trends.
- `/explore/follow-up`: Follow-up lists.
- `/branch/:id`, `/rep/:id`, `/pipeline` and `/delivery`: existing detail pages.

Query keys include `branch`, `rep`, `from`, `to`, `source`, `model` and `status`.
Entity detail paths carry their own ID; the codec avoids redundant entity queries.

The three explorer tabs share one Navigator page identity. Switching among them
keeps local measure, group and sort choices; data filters also remain applied.
Refresh restores the tab and filters from the URL, but resets those local choices.
Visiting Overview also resets the explorer's local choices. Reset clears filters
without switching tabs.

Selecting a representative establishes the associated branch. Changing branches
clears an incompatible representative. Reset returns to the unfiltered network.
Invalid/incomplete date pairs are ignored. Unknown query dimensions are normalized;
unknown detail IDs produce a not-found page.

Do not use a second URL-writing system alongside `AnalysisRouter`. For page changes,
use `AppNavigation.go`/`up`; for filters, use controller setters. The router's
restoration guard prevents browser Back from creating another forward navigation.

## 10. Common changes: where and how

### Change a heading, colour or spacing

1. Find the label in the relevant page or presenter.
2. For shared styling, edit `app_theme.dart`; avoid scattered colour values.
3. Keep metric names consistent with their actual definitions.
4. Check desktop, tablet and mobile, including long labels and empty states.

A text-only change normally needs no new formula test. Run the analyzer and relevant
widget checks when layout or interaction changes.

### Change comparison buttons or their groups

Edit `comparisonMeasureGroups` in `exploration_presenter.dart` to move an existing
measure between the four labelled rows. Edit `MetricLabels` or `DimensionLabels`
there to change wording. The `ComparisonMetric` value still selects the existing
calculation; changing a label or group does not change its formula.

Edit the destinations and navigation in `application_shell.dart` for sidebar
labels, icons or styling. Explorer paths also use `PerformanceSection` in
`performance_navigation.dart`. A path change
also needs matching routing/history tests. Keep `/explore` working for existing links.
Check `test/features/exploration_page_test.dart` for responsive interaction tests
and `test/application/analysis_router_test.dart` for restoration checks.

### Change appearance without breaking dark mode

`buildAppTheme` in `app_theme.dart` creates both themes. Use `context.colors` for
custom widget colours, and `Theme.of(context)` for standard component styling.
`AppPalette` pairs foreground, background and status colours for each brightness.
Custom chart painters receive a palette explicitly and repaint when it changes.
Avoid fixed white backgrounds or fixed dark text in feature widgets.

`AppearanceController` defaults to System, validates stored preferences, and writes
the chosen mode through the platform storage adapter. No dataset or filter state
is stored there. `application_shell_test.dart` covers both themes, navigation,
evidence dialogs, system brightness changes and semantic text contrast.

### Add a new KPI

1. Write its business question, formula, eligible records and time basis first.
2. Add the result to an appropriate analytics model and calculate it in a service.
3. Expose it through `AnalysisResults` and the presenter.
4. Add a card and a concise definition tooltip.
5. Test a small known example, a filtered example and a zero-denominator case.
6. Update `ANALYTICS_SPEC.md` if the analytical contract changes.

Do not put a `.where(...).length / ...` business formula directly in `build()`.

### Add or change a filter

Update `AnalysisFilters` including equality/hash and `copyWith`, matching/scope logic,
controller normalization/setters, codec encoding/decoding and the filter control.
Decide how targets and findings should respond. Test refresh, Back/Forward, reset,
invalid values and branch/representative compatibility. A filter is incomplete if it
changes only the screen but cannot survive refresh.

### Add a finding or adjust an attention threshold

Work in the insight engine and `InsightEngineConfig`. Define minimum evidence,
benchmark, observation, action wording and exact affected IDs. Test both triggering
and non-triggering cases. Do not write a rule tied to a particular branch name.

Pipeline bands and insight thresholds live in different configuration types:
`PipelineAgeingConfig` and `InsightEngineConfig`. If a business policy changes,
inspect both call sites so classification labels and attention rules remain aligned.
Do not assume editing one number changes every related rule.

### Add a CSV column

Add it centrally in `FollowUpCsv`, keeping header and row positions aligned. Obtain
the value from typed records. Preserve quoting, formula protection, scope and
active-only rules. Update export tests, then download and inspect a real file.

### Support a new source field or replacement dataset

Do not edit the supplied raw dataset to hide a problem. Develop against a separate
fixture or separately supplied canonical dataset. Add model/parser support when the
schema changes, define validation, then update analytical derivation if needed.

For a replacement asset, register its path in `pubspec.yaml` and configure
`AssetDealershipDataSource` to load it. Build and verify the replacement explicitly.
A canonical-schema replacement should not require branch IDs or conclusions to be
hard-coded in analytics. A different schema needs an explicit adapter/parser change.

### Add a page

Create it under `lib/features`, reuse controller results, register its path in
`AnalysisRouter`, and use `AppNavigation` for links. Define parent/filter behaviour.
Test direct URL loading as well as clicking into the page.

## 11. Test and debug changes

Run these from the root:

```bash
flutter analyze
flutter test
flutter build web --release
```

For a focused calculation change:

```bash
flutter test test/analytics/management_performance_test.dart
```

Inspect reproducible insight output without navigating the UI:

```bash
dart run tool/print_insights.dart
```

An optional canonical dataset path can be passed to that command. Use a small test
fixture to reason about a new formula; use bundled-data regression tests to catch
unexpected changes to the known result. Do not hard-code those results in the UI.

For a wrong number, trace backwards: screen label → presenter → result field →
service formula → filtered records → derived facts → original typed source. Check
the period basis and denominator before assuming the formula is broken.

For a wrong filter after refresh, inspect the URL codec, initial loading restoration
and router/controller synchronization. For a broken CSV, check builder content first,
then the browser download adapter. For a load failure, inspect the reported parser
path and severity; do not remove validation just to make the screen appear.

If an old UI appears after rebuilding, an older service worker/browser cache may be
serving it. For local verification, use a fresh local port/browser session and check
the visible change before deciding the new code failed.

## 12. A safe maintenance checklist

Before editing, read the relevant existing service and tests. Make one purposeful
change, keeping source data immutable. Keep formulas in pure Dart services and
preserve typed boundaries. Update definitions and tests when meaning changes.

After editing, check the affected view at several widths; try no records, missing
values, long names and dialogs. For state changes, verify URL/refresh/history. For
exports, inspect the downloaded file. Run relevant tests and the analyzer; before
shipping, run the complete suite and production build.

Known scope limits: no backend or authentication, no invented currency, no supplied
representative targets, uncertain target-population coverage, and no causal or
forecasting model. Browser testing recorded in `VERIFICATION.md` is Chromium-based,
not comprehensive browser or screen-reader certification. Deployment remains a
separate task.

## Suggested learning order

1. Run the app and follow one branch into a representative and evidence record.
2. Read this handbook and the decision guide.
3. Read the typed `Lead` model, then `AnalysisController` and scope service.
4. Follow one metric from the analytics engine through the presenter to its card.
5. Read the matching small test before changing that metric.
6. Use the detailed analytics specification whenever a definition is unclear.

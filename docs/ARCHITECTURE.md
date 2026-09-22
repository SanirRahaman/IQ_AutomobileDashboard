# Architecture

## Scope

`yoyotaDealers` is a Flutter Web decision-support application. The Dart package is named `yoyota_dealers` because Dart package identifiers cannot contain uppercase letters.

The initial deployment is a static web application. The canonical dealership JSON is bundled as an asset and processed locally; no backend is required.

## Dependency direction

```text
Flutter presentation
  -> application state/controllers
  -> typed analytics result objects
  -> pure Dart aggregation services
  -> analytical lead feature engineering
  -> typed domain models and indexes
  -> repository
  -> asset data source / canonical JSON parser
```

Dependencies point inward. Parsing, validation, indexing, and future analytics must not depend on Flutter UI libraries. Widgets receive typed view data and never parse JSON or calculate business metrics.

## Analytical record boundary

`LeadFeatureEngineer` converts the typed canonical dataset into an `AnalyticalDataset`. Each `AnalyticalLead` contains reusable stage reach, timestamp, duration, state, outcome, expected-close, representative-tenure, and maturity features. This is the only analytics layer that inspects `statusHistory`; aggregation modules consume analytical records instead.

`AnalyticsContext` makes the snapshot date and maturity threshold explicit. The context travels with every analytical dataset and record, preventing age calculations from falling back to the wall clock.

`DealershipAnalyticsEngine` accepts an `AnalyticalDataset`. Every public method also accepts an optional analytical-record scope, allowing filters to be applied before aggregation without duplicating calculations. Outputs are typed result objects suitable for both later insight rules and presentation.

## Application analysis state

`AnalysisController` is the single application-state boundary for analytical scope. It uses Flutter's lightweight `ChangeNotifier` contract but delegates filtering and all calculations to services. Widgets should listen to the controller and render its typed `AnalysisResults`; they must not filter completed result rows themselves.

```text
AnalysisFilters
  -> AnalysisScopeService
  -> scoped AnalyticalDataset records
  -> DealershipAnalyticsEngine
  -> DeterministicInsightEngine
  -> AnalysisResults
  -> presentation
```

One filter update replaces the entire immutable result bundle, including overview, funnel, gates, branches, representatives, sources, vehicles, losses, pipeline, deliveries, cohorts, insights, and evidence IDs. Empty scopes produce typed empty results rather than stale global metrics.

`AnalysisRouteCodec` encodes branch and representative scope as `/branch/:id` and `/rep/:id`. Remaining filters use query parameters, so browser routing can restore analytical state directly. Selecting a representative also establishes branch context; changing to an incompatible branch clears the representative.

## Leadership dashboard

The primary dashboard is a responsive Flutter presentation over `AnalysisResults`. `DashboardPresenter` converts typed analytics into display-ready labels and rows; widgets do not parse source JSON, traverse status histories, or calculate analytical denominators.

The page follows this information order:

1. business pulse;
2. generated attention findings;
3. sales journey;
4. branch diagnostics;
5. source and vehicle diagnostics;
6. creation cohorts;
7. pipeline and delivery health.

Desktop uses multi-column metric and insight layouts. Tablet progressively reduces columns, while narrow widths stack panels and keep wide diagnostic tables horizontally scrollable. Generated insight and journey actions open the exact scoped supporting records. Branch rows navigate to route-backed diagnostics rather than changing presentation-only state.

`YoyotaDealersApp` owns repository loading, loading/error states, and root browser routing. It resolves `/`, `/branch/:id`, `/rep/:id`, `/pipeline`, and `/delivery` on both initial load and in-app navigation. `DashboardPage` surfaces structured validation warnings, filtered no-results state, and section-level empty states. No finding text or business conclusion is embedded in the dashboard; all findings come from `DeterministicInsightEngine`.

The pipeline and delivery operational pages listen to the shared `AnalysisController`, so applying any supported filter regenerates their analytical inputs rather than hiding rows. `OperationalPresenter` formats typed engine outputs. Evidence rows carry exact lead IDs into the shared lead-evidence dialog.

## Progressive investigation

`BranchDetailPage` and `RepDetailPage` create isolated scoped controllers from the canonical dataset. Comparisons retain the current date/source/model/status scope: branch results use a network controller with only branch/rep removed, while rep results use their branch as the benchmark. `InvestigationPresenter` prepares all display comparisons outside widget `build()` methods.

Evidence actions pass the generated insight's exact `affectedLeadIds` into the shared evidence list. Selecting a record opens its canonical lead fields and complete status timeline, with the rule-derived inclusion explanation. Branch and representative actions within evidence use the same browser-compatible routes. Unknown route identifiers render an explicit not-found state rather than silently selecting another entity.

## Canonical schema boundary

`DealershipDatasetParser` is the only raw-map-to-domain boundary. It accepts the documented canonical top-level collections: `metadata`, `branches`, `sales_reps`, `leads`, `targets`, and `deliveries`.

Parsing produces `DatasetLoadResult`:

- `dataset`: a typed `DealershipDataset` when parsing succeeds.
- `report`: fatal parsing errors plus semantic validation errors and warnings.

Malformed required types or dates are fatal because a trustworthy typed entity cannot be constructed. Cross-record inconsistencies remain structured validation findings. Questionable input is reported, never silently repaired.

Closed vocabularies use typed values that preserve the original raw string. Known values expose an enum; unknown future values map to `unknown`, retain their raw value, and generate a warning. Open business dimensions such as source and vehicle model remain strings so new values do not require code changes.

## Data loading

`AssetDealershipDataSource` reads `assets/data/dealership_data.json`. `DealershipDatasetRepository` parses and validates it. Callers receive a typed load result, not JSON maps.

The raw asset is immutable. To use another dealership dataset, replace the asset with a same-schema JSON file and rebuild. Incompatible input yields a compatibility report rather than an unexplained cast failure.

## Indexing

`DealershipDatasetIndexes` builds immutable lookup structures once:

- branches, representatives, and leads by ID;
- representatives by branch;
- leads by branch;
- leads by representative.

Future analytics should reuse these indexes instead of repeatedly scanning collections for joins.

## Validation policy

Findings include a stable code, severity, message, JSON-style path, and optional record ID. Severity categories are:

- fatal: the canonical typed dataset cannot be constructed;
- error: the dataset was parsed, but a relationship or invariant is invalid;
- warning: the record is usable with an explicit quality caveat.

Unknown enum values are warnings. Missing references, duplicate identifiers, impossible negative values, malformed histories, and non-monotonic history timestamps are errors. A current status that differs from the last history event is a warning because both values remain available and no authority is assumed.

## Evolution

Add schema fields as optional first when backward compatibility is intended. Change required fields only with fixtures, parser tests, validation behavior, and documentation updated together. Arbitrary unrelated schemas are out of scope; adapters for another schema must be explicit and separate from the canonical parser.

## Finishing-pass navigation and management presentation

`AnalysisRouter` connects the existing route codec and controller to Flutter's
Router/RouteInformation system. It owns the dashboard, branch, representative,
pipeline, and delivery locations. The dashboard stores dimension filters in its
query; detail paths remain `/branch/:id` and `/rep/:id`. Flutter's hash URL strategy
supports reloads on static hosting without server rewrite assumptions. Browser
history restores filters through the same codec; a restoration guard prevents
feedback loops. Parent links retain dates/source/model/status while removing only
the entity level being exited. Invalid calendar dates and unknown query dimensions
are discarded; unknown detail IDs render not-found content.

`ManagementPerformanceService` supplies target and delivery-period results to the
existing `AnalysisResults`. No widgets calculate target ratios or KPI denominators.
The dashboard puts the compact scorecard, target panel, and top three findings first;
remaining findings expand on request. Definitions move to tooltips and dialogs.
`FollowUpCsv` is a pure Dart export builder; a conditional platform adapter handles
browser download only. Representative table links use IDs rather than display names.

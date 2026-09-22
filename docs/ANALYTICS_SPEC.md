# Analytics specification

## Dataset semantics

The canonical dataset contains metadata, branches, sales representatives, leads with complete status histories, monthly branch targets, and delivery records.

All dates are parsed into `DateTime`. Date-only values are represented at midnight. Target months are represented by the first day of the month. Source strings are optional because missing source attribution is analytically meaningful and must not be replaced with invented text in the data layer.

No currency is declared by the schema. Monetary-looking fields are therefore called **value** or **target revenue value** and are displayed without an invented symbol or currency code.

## Lifecycle

Known lead statuses are:

```text
new -> contacted -> test_drive -> negotiation -> order_placed -> delivered
                     \-> lost from any unresolved stage
```

Unknown statuses are retained and flagged. The parser does not force them into a lifecycle stage.

`delivered` and `lost` are resolved outcomes. All other known statuses are active opportunities. Active opportunities must never be counted as failed conversions.

The current lead status and status history are separate source facts. If the current status conflicts with the final history event, validation reports the conflict; neither value is rewritten. Analytics that require a loss timestamp or terminal loss stage must exclude or explicitly qualify such records.

## Time semantics

Analytics must declare whether a metric is based on:

- lead creation cohort;
- status-event date;
- order date;
- delivery date;
- target month.

Do not compare immature recent cohorts directly with fully observed cohorts. An analytical `asOf` date must be explicit and should default to the latest relevant business event, not the browser clock or metadata generation date.

### Analytical snapshot

`AnalyticsContext.snapshotDate` is mandatory. `LeadFeatureEngineer` chooses the latest observed business timestamp across lead creation, activity, status events, orders, and deliveries when no override is supplied. It does not use the browser clock, metadata generation timestamp, or expected-close dates. Callers may override the snapshot for reproducible historical analysis.

Days in stage, days since last activity, lead age, expected-close slippage, staleness, and maturity all use this snapshot. Negative ages caused by invalid source chronology are not emitted as negative values.

### Cohort maturity

The maturity duration is the linearly interpolated 80th percentile of non-negative `creation -> delivered` durations from completed successful journeys in the loaded dataset. The percentile is configurable when constructing `LeadFeatureEngineer`. This threshold is more resistant to extreme longest-cycle records than a maximum while ensuring that most observed successful cycles fit within the maturity window.

An individual lead is mature when `created_at + maturityDuration <= snapshotDate`. A creation-month cohort is mature only when the first day after that month plus the maturity duration is on or before the snapshot. This conservative cohort rule gives every lead created in that month the full observation window. If no completed successful cycle exists, the threshold is unavailable and leads/cohorts are marked immature rather than assigned an invented duration.

Maturity is an eligibility signal for outcome comparisons; it does not change a lead's actual active or resolved status.

## Analytical lead derivation

The canonical successful stages are `new`, `contacted`, `test_drive`, `negotiation`, `order_placed`, and `delivered`. For duplicated entries at a stage, the earliest timestamp is the stage-entry timestamp. Reached flags are based only on observed entries: reaching a later stage does not invent omitted earlier stages.

Transition durations are emitted only when both adjacent timestamps exist and the result is non-negative. Missing transitions and invalid chronology therefore produce `null`, not inferred timestamps or absolute-value durations. `hasValidChronology` exposes whether the original event sequence is non-decreasing.

The highest successful stage is the furthest canonical stage explicitly observed. For an active or delivered lead, current stage follows its typed current status. For a lost lead, current funnel stage and `lostFromStage` refer to the highest successful stage reached before the loss outcome. If a loss timestamp exists, days in that stage stop at loss; otherwise no loss timestamp is invented. Current-status/history conflicts remain subject to the validation warning policy.

Expected-close overdue and slippage apply only to active opportunities. Representative tenure is `lead.createdAt - rep.joined` when the representative exists and the duration is non-negative.

## Aggregation definitions

### Business overview

```text
resolved conversion = delivered / (delivered + lost)
```

Active leads are excluded from this denominator. Active opportunity value is the sum of active lead values. Delivered deal value is the sum of delivered lead values. Average and median deal value use all leads in the supplied scope. A zero denominator produces `null`, not zero percent.

### Full funnel

For each canonical stage:

- reached count is based on an explicit observed stage, except `new`, which includes every canonical lead because creation establishes funnel entry;
- progression count is the number that explicitly reached the next stage;
- progression rate is progression divided by reached count;
- leakage is a lost lead whose attributed exit stage is that stage;
- average and median speed use only valid observed adjacent-stage durations.

The terminal delivered stage has no progression rate or transition duration.

### Management gates

The simplified gates are defined as:

```text
Contact = reached contacted
Test Drive = reached test_drive
Close = reached order_placed
```

Close deliberately means an accepted/placed order, not delivery; delivery is analyzed operationally. Contact conversion uses all leads as eligible, Test Drive uses contacted leads, and Close uses test-driven leads. Loss before Close combines losses attributed to test drive and negotiation.

### Grouped performance

Branch and representative results reuse the same overview and funnel definitions. Representative results retain branch ID and name, including representatives with zero workload. Branch workload is scoped lead count divided by the number of representatives typed as `sales_officer`; it is `null` if no sales officer exists.

Source analytics keep these distinct:

- raw delivered rate: delivered / all source leads;
- resolved conversion: delivered / (delivered + lost);
- delivered among contacted: delivered / contacted;
- test drive among contacted: test-driven / contacted.

These describe where a source's funnel differs but do not assign causality to lead quality or follow-up.

Vehicle economic importance is:

```text
delivered-value share / lead-volume share
```

A value above one means the model contributes a larger share of delivered deal value than of lead volume. It is a mix/value-contribution index, not profitability or margin.

Loss reasons remain the exact nullable source values. Breakdowns by exit stage, branch, source, model, and representative are reversible and retain affected lead value.

### Pipeline

Pipeline analytics include active opportunities only. Lead age is measured from creation; inactivity is measured from last activity. The ageing band is based on inactivity with configurable inclusive boundaries. Defaults are:

- recently active: fewer than 7 days;
- ageing: 7–13 days;
- stale: 14–29 days;
- severely stale: 30 or more days.

These are attention labels, not predicted outcomes. An overdue order-stage opportunity is active at `order_placed` and past expected close at the snapshot.

The operational pipeline view presents the same configurable bands with management-facing labels: `healthy` maps to recently active, `watch` to ageing, `stale` remains stale, and `critical` maps to severely stale. With the default `PipelineAgeingConfig`, the boundaries are therefore healthy under 7 days, watch 7–13, stale 14–29, and critical 30+ days. Inactivity classification uses days since last activity. The age distribution applies the same boundaries to days since lead creation but is labeled separately. Neither classification changes the canonical active status or implies that an opportunity is lost.

`PipelineOperationalAnalytics` is calculated in the pure-Dart analytics engine and exposes active count/value, stale value, stage/inactivity/age buckets, expected-close slippage, order-stage backlog, oldest opportunities, branch and representative breakdowns, and exact evidence IDs.

### Delivery

Delivery duration uses supplied `days_to_deliver`. Average, median, 80th percentile, and 90th percentile use linear interpolation. Deliveries without a recorded delay reason form the baseline. Each named delay reason's incremental time is its average duration minus that baseline average; this is an association, not a causal estimate.

Branch and vehicle delivery comparisons use linked lead dimensions. Expected-close timeliness currently compares delivery date with the lead's expected close date. Because the source does not define whether expected close means order close or physical delivery, this metric must be labeled as a proxy until clarified.

### Creation-month cohorts

Cohorts group by lead creation month and report active, delivered, lost, resolved conversion, and maturity. Resolved conversion remains mathematically available for immature cohorts, but consumers must use `isMature` to avoid presenting immature and mature cohorts as equivalent comparisons.

## Value semantics

- Active lead `deal_value`: potential pipeline value.
- Lost lead `deal_value`: affected/lost potential value.
- Delivered lead `deal_value`: best available delivered-value proxy.
- `target_revenue`: target revenue value supplied at branch-month granularity.

The dataset has no separate realized revenue field. Documentation and UI labels must preserve this distinction.

## Required reconciliation rules

Every aggregate and future insight must be reproducible from supporting record IDs and a filter definition. Counts and values shown in summaries, charts, and drill-down tables must use the same centralized calculation.

The overview KPI cards open their supporting records. Lead, active, and resolved-outcome lists use the creation-date scope. Conversion separates delivered and lost records and explicitly excludes active opportunities. The follow-up card and its evidence share one unique-ID selection for stale or overdue order-stage opportunities.

The vehicles-delivered card lists the exact delivery events retained by `ManagementPerformanceService`, including delivery dates. Repeated delivery events for a lead remain separate rows in both the dialog and its CSV, matching the event-count numerator. The target dialog uses branch-month contributions emitted by that same calculation pass, including excluded target months; it does not recalculate targets in widgets.

Branch-month target units should be compared with deliveries attributed by delivery month. Any comparison between `target_revenue` and delivered lead value must be labeled as a proxy.

## Data-quality exclusions

Validation does not silently remove or repair records. Each analytical module must state whether records with relevant errors or warnings are included, excluded, or shown as an unknown bucket. Exclusion counts must be observable.

Changes to lifecycle definitions, denominators, value semantics, cohort maturity, target attribution, or exclusion rules require updates to this file and corresponding tests.

## Deterministic insight engine

`DeterministicInsightEngine` consumes typed analytical records and structured validation findings. It never parses raw histories and contains no dataset-specific identifiers, values, or conclusions. Every finding has a rule-derived stable ID, observed metric, benchmark and method, differences, evidence strength, affected IDs and value, relevant dimensions, investigation prompt, generation reason, rank score, and factor breakdown.

Rules cover funnel leakage and speed, branch and representative peer comparisons, source funnel distinctions, vehicle mix/value importance, active-pipeline attention, delivery duration, and data quality. Wording describes associations and investigation questions; it does not assign cause.

### Comparison support

Default safeguards are configurable:

- segment comparisons: at least 15 leads;
- resolved-conversion comparisons: at least 10 resolved leads;
- stage comparisons: at least 10 stage observations;
- delivery comparisons: at least 8 deliveries;
- material rate difference: 10 percentage points;
- material relative difference: 20%;
- delay-duration difference: 3 days.

Rules suppress unsupported comparisons. Evidence strength is `moderate` at the rule's minimum support and `strong` at three times minimum support; record sets below rule support are either suppressed or explicitly marked weak for operational/data-quality signals.

Network rates use weighted record-level totals, branch benchmarks use all scoped branch records, and robust cross-group comparisons use medians or interpolated percentiles where defined. A null denominator never becomes a zero rate.

### Ranking

Candidates are ranked deterministically by:

- severity weight;
- absolute or relative deviation magnitude, capped to prevent extreme percentages dominating;
- logarithmically scaled affected-record count;
- affected-value share, capped to prevent value alone dominating;
- evidence strength;
- explicit urgency for time-sensitive pipeline and data-quality conditions.

The complete factor contribution is stored in `rankingFactors`. Stable insight ID breaks score ties. The default result is six findings, within the intended four-to-eight overview range; callers can request another limit for diagnostic views or tests.

The default overview also applies deterministic diversity safeguards: at most two findings per category, one finding per rule family, and one finding for the same category/dimension combination. Explicit-limit diagnostic calls return the uncurated ranked candidates so analysts can inspect every triggered rule.

### Review command

Run the engine against the bundled or another canonical dataset with:

```bash
dart run tool/print_insights.dart [optional-dataset-path]
```

The command prints reproducible JSON including the analytical snapshot, maturity duration, complete ranked insight payloads, and exact affected lead IDs.

## Filter and scope semantics

Application filters support inclusive date range, branch, sales representative, source, vehicle model, and raw canonical lead status. Dimension filters intersect; they are never applied only to already-calculated presentation rows.

The scope pipeline is:

```text
filters -> scoped records -> analytics -> insights -> UI
```

Date-range inputs are interpreted as calendar dates and normalized to UTC date boundaries. Both endpoints are inclusive.

- Lead overview, funnel, gates, branch, representative, source, vehicle, loss, pipeline, and cohort calculations include leads whose `created_at` UTC date falls in the selected range.
- Delivery calculations include deliveries whose `delivery_date` falls in the selected range. Their linked leads are filtered by the same branch, representative, source, model, and current-status dimensions, but are not excluded because their creation date falls outside the delivery period.
- Delivery-specific insight rules receive the delivery-date scope. Other insight rules receive the lead-creation scope.
- The analytical snapshot and maturity threshold remain those of the loaded network dataset when filters change. This keeps age, staleness, and maturity definitions comparable across scopes rather than recalculating time context for every slice.

Network and peer benchmarks are recalculated inside the selected lead scope. For example, selecting one branch makes that branch the scoped network, so a network-relative branch anomaly is suppressed rather than continuing to display a stale global comparison.

Selecting a branch constrains available representatives. Selecting a representative establishes that representative's branch. Changing branch clears an incompatible representative. Reset returns all filters to the unscoped network view.

Route state uses `/branch/:id` and `/rep/:id`; date, source, model, and status use query parameters. Invalid or incomplete date pairs are ignored rather than creating a partially applied time scope.

## Management scorecard and target attainment

The scorecard's **Vehicles delivered** uses linked delivery records in the selected
calendar period, independent of lead creation date. **Leads received**, **Active
opportunities**, and **Resolved conversion** retain the creation-date scope. KPI
help explicitly describes the distinction; no existing denominator has changed.

`ManagementPerformanceService` matches supplied **unit** targets by branch and
calendar month to delivery-date actuals. There are no rep/source/model/status
targets, so those dimension filters suppress target comparison rather than
allocating a branch target. Currency and realized-revenue assumptions are not
introduced; the revenue target is not compared with a falsely labelled revenue KPI.

- Attainment = linked deliveries in supported branch-months / supplied unit target.
- Variance = actual minus target; a zero target has no attainment percentage.
- Missing, duplicate, or negative branch-month unit targets are excluded from
  both numerator and denominator, with unavailable/missing coverage visible.
- A partial month retains the **full monthly target** and is explicitly labelled
  partial; its remaining gap is not labelled final underperformance. No linear
  prorating or pace forecast is invented.
- The default reporting interval starts at the first observed business month and
  ends on the existing dataset snapshot date. Targets do not advance the snapshot.
- The source does not establish whether the target population exactly matches
  the supplied extract. The target panel retains a coverage caveat.

Previous-month delivery comparison is shown only when the selected period is one
complete calendar month, the preceding month falls within observed coverage, and
the current month ends no later than the dataset snapshot. It compares delivery
events, not immature lead-cohort conversion, and shows absolute unit change.
It makes no claim about causality, seasonality, or statistical significance.

## Follow-up export

CSV rows intersect the requested evidence IDs with the current lead or delivery
scope, using the same event-date semantics as the originating finding. A follow-up
list further restricts to active opportunities; the separately labelled all-records
export retains delivered/lost statuses. Rows include customer, phone, branch,
representative, vehicle, source, current status, value without currency, key dates,
inactivity, snapshot date, and reason for review. Lead references permit record
reconciliation. CSV text is quoted and formula-leading text is escaped for
spreadsheet safety. Raw source records are never modified.

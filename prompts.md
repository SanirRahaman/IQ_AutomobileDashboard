# PROMPT 0 — PLAN THE PROJECT

## Goal

Plan the implementation of a production-quality Flutter Web application named **yoyotaDealers** for the supplied dealership take-home assignment.

Do not modify project files in this step.

The application must turn `dealership_data.json` into a decision-support dashboard for dealership leadership.

The product should answer:

1. What is happening in the business?
2. What requires attention?
3. Where is the sales process breaking?
4. Which branches, reps, sources or vehicle models contribute to the issue?
5. What business value is affected?
6. Which exact records support each finding?

## Context

The supplied dataset contains approximately:

* 5 dealership branches
* 30 sales representatives
* 500+ leads
* complete lead `status_history`
* monthly targets
* delivery records

The application will be built with **Flutter Web + Dart** and deployed to **Vercel**.

Runtime GPT/LLM APIs are not required.

The intelligence layer should come from:

* data validation
* feature engineering
* aggregations
* benchmark comparisons
* funnel analysis
* anomaly detection
* deterministic insight rules
* evidence-backed drill-down

A replacement dealership dataset using the same schema should automatically produce new metrics and insights without code changes.

## Constraints

* Project name: `yoyotaDealers`
* Flutter Web
* null-safe Dart
* responsive desktop and tablet UI
* do not hard-code branch IDs, salesperson IDs, values, conclusions or dataset-specific findings
* do not modify the source dataset
* do not invent a currency
* do not use active leads as failed conversions
* business analytics must remain outside widget `build()` methods
* analytics should be testable independently of Flutter UI
* avoid unnecessary backend infrastructure
* avoid unnecessary ML in the first implementation

## Planning output

Provide:

1. proposed architecture
2. recommended project structure
3. data flow
4. analytics modules
5. insight-generation approach
6. state-management approach
7. routing approach
8. responsive UI approach
9. testing strategy
10. Vercel deployment approach
11. implementation order
12. risks or ambiguities in the supplied dataset

Also list the files or folders that should be inspected before implementation.

## Done when

There is a concrete implementation plan that can be executed incrementally without requiring a rewrite of the architecture later.

# PROMPT 1 — ESTABLISH PROJECT RULES AND DATA FOUNDATION

## Goal

Create the persistent project instructions and implement the data foundation for **yoyotaDealers**.

Do not build dashboard screens yet.

## Context

Use the implementation plan already created.

Use the supplied `dealership_data.json`.

If necessary, place the data at:

`assets/data/dealership_data.json`

Keep the original contents unchanged.

## Persistent project instructions

Create a concise root-level:

`AGENTS.md`

It should contain only durable rules that should apply to future Codex tasks in this repository.

Include:

* product name is `yoyotaDealers`
* Flutter Web is the application platform
* analytics/business logic belongs in pure Dart services, not widgets
* raw source data must never be modified
* no hard-coded dataset-specific conclusions
* replacement datasets using the canonical schema must work without analytics code changes
* use typed models
* avoid duplicated calculations
* do not invent currency
* active opportunities are distinct from resolved outcomes
* tests and `flutter analyze` are required for meaningful analytical changes
* keep documentation synchronized when analytical definitions change

Also create:

`docs/ARCHITECTURE.md`

and:

`docs/ANALYTICS_SPEC.md`

These should contain deeper details rather than making `AGENTS.md` excessively long.

## Data models

Create typed models for all top-level dataset entities:

* metadata
* branch
* sales rep
* lead
* lead status history
* target
* delivery
* dealership dataset

Use enums for closed vocabularies where appropriate, while safely handling unknown future values.

Parse dates into `DateTime`.

Represent optional source values safely.

## Repository

Create a repository/data source that can load:

`assets/data/dealership_data.json`

and return one typed canonical dealership dataset.

The UI must not parse JSON directly.

## Validation

Create a structured validation system capable of reporting warnings and errors.

Validate at minimum:

* duplicate IDs
* missing branch references
* missing sales-rep references
* deliveries referencing unknown leads
* targets referencing unknown branches
* malformed dates
* malformed numeric fields
* negative values where impossible
* empty or malformed status histories
* status-history timestamp ordering
* current status conflicting with the final history status
* unexpected/unknown enum values

Do not silently repair questionable source data.

Separate:

* fatal parsing errors
* validation errors
* validation warnings

## Indexes

Build reusable indexes such as:

* branch by ID
* rep by ID
* lead by ID
* reps by branch
* leads by branch
* leads by rep

Avoid repeated O(N) joins throughout analytics code.

## Future dataset compatibility

Implement a clear canonical-schema boundary.

A different JSON file using the same schema should load automatically.

Do not attempt to support arbitrary unrelated JSON schemas.

If a future dataset is incompatible, provide a useful compatibility/validation report rather than crashing mysteriously.

## Tests

Add meaningful tests for:

* successful parsing
* nullable values
* unknown enum values
* bad references
* duplicate IDs
* malformed dates
* validation warnings/errors

## Acceptance criteria

* current dataset loads successfully
* parsed entities are typed
* source JSON is untouched
* no UI depends directly on raw JSON maps
* validation output is structured
* relationships can be looked up efficiently
* another same-schema dataset can replace the current file without code changes

## Verification

Run:

```bash
flutter analyze
flutter test
```

Fix relevant failures before finishing.

At the end report:

* files created/changed
* validation results for the supplied dataset
* tests run
* remaining data-quality concerns

# PROMPT 2 — BUILD FEATURE ENGINEERING

## Goal

Transform raw lead records into reusable analytical records so downstream analytics do not repeatedly parse `status_history`.

Do not build dashboard UI in this task.

## Context

Use the canonical models and repository already implemented.

The lead `status_history` contains the customer journey.

Canonical funnel stages are:

```text
new
contacted
test_drive
negotiation
order_placed
delivered
```

`lost` is a terminal outcome that can occur after different stages.

## Required derived fields

Create a typed analytical lead model.

Derive, where available:

* reached contacted
* reached test drive
* reached negotiation
* reached order placed
* reached delivered

Stage timestamps:

* contacted at
* test drive at
* negotiation at
* order placed at
* delivered at

Durations:

* new → contacted
* contacted → test drive
* test drive → negotiation
* negotiation → order
* order → delivery
* creation → delivery

Current-state features:

* current funnel stage
* highest successful funnel stage reached
* date current stage was entered
* days in current stage
* days since last activity

Outcome features:

* is active
* is resolved
* is delivered
* is lost
* stage where a lost lead exited

Expected-close features:

* expected close overdue
* expected close slippage duration

Rep features:

* rep tenure at lead creation

## Historical snapshot date

Do not base a historical dataset on the user's current wall-clock date.

Create an `AnalyticsContext` with an explicit `snapshotDate`.

Determine a sensible default snapshot dynamically from the maximum relevant timestamp in the loaded dataset.

Allow the snapshot to be overridden.

All age/staleness calculations must use the analytical snapshot.

## Cohort maturity

Recent cohorts have had less time to reach delivery.

Create a data-derived maturity threshold from completed successful sales cycles using a robust percentile.

Expose:

* calculated maturity duration
* whether each lead/cohort is mature enough for outcome comparisons

Document the methodology in `docs/ANALYTICS_SPEC.md`.

## Defensive behavior

Handle:

* missing stages
* leads lost before contact
* active leads
* duplicated stage entries
* malformed ordering already flagged by validation
* incomplete histories

Do not invent missing timestamps.

## Tests

Include representative tests for:

* complete delivered journey
* lost at new
* lost after contacted
* lost after test drive
* active negotiation
* active order
* missing optional transition
* invalid chronology

## Acceptance criteria

Downstream analytics can work almost entirely from typed analytical records without inspecting raw history arrays.

No derived value depends on a specific lead ID or branch ID.

## Verification

Run:

```bash
flutter analyze
flutter test
```

Update analytical documentation where necessary.

# PROMPT 3 — BUILD THE ANALYTICS ENGINE

## Goal

Implement reusable pure-Dart analytics for the dealership dataset.

The output should be typed analytical result objects suitable for both the insight engine and UI.

Do not build charts in this task.

## Analytics modules

### Business overview

Calculate:

* total leads
* active leads
* resolved leads
* delivered
* lost
* resolved conversion
* active opportunity value
* delivered deal value
* average deal value
* median deal value

Define:

```text
resolved conversion =
delivered / (delivered + lost)
```

Do not treat unresolved leads as failures.

### Full funnel

Calculate for each stage:

* reached count
* progression count
* progression %
* leakage count
* leakage %
* average transition duration
* median transition duration

Determine the stage at which lost leads exited.

### Management gate analysis

Also create a simplified management view:

```text
Contact
→ Test Drive
→ Close
```

Calculate:

* gate conversion
* leads lost before each gate
* deal value associated with those leads

### Branch analytics

For each branch calculate:

* lead volume
* delivered/lost/active
* resolved conversion
* funnel progression
* progression speed
* active opportunity value
* delivered deal value
* lead value profile
* workload per sales officer
* lost reasons
* pipeline ageing
* delivery performance where available

### Sales-rep analytics

For every rep calculate:

* workload
* active/resolved/delivered/lost
* resolved conversion
* stage progression
* stage progression speed
* active opportunity value
* delivered deal value
* average/median deal value

Always retain branch context.

### Lead-source analytics

For each source calculate:

* volume
* contact rate
* test-drive rate
* raw delivered / total
* resolved conversion
* delivered conversion among contacted leads
* test-drive conversion among contacted leads
* active value
* delivered value

This distinction is important:

A weak raw conversion can be caused by poor follow-up, weak lead quality, or both.

Do not claim which cause is true unless the data supports it.

### Vehicle analytics

For every vehicle model calculate:

* lead count/share
* delivered count/share
* resolved conversion
* average/median deal value
* delivered value
* delivered-value share
* active opportunity value
* funnel progression
* loss reasons

Create an interpretable measure showing models with disproportionately large economic importance.

Do not call this “profitability” because margin data is unavailable.

### Lost-reason analytics

Calculate loss reasons by:

* count
* affected deal value
* stage of loss
* branch
* source
* model
* rep

Keep original loss reasons.

Any higher-level grouping must be explicit and reversible.

### Pipeline analytics

For active opportunities calculate:

* stage
* age
* inactivity
* expected-close slippage
* deal value
* branch
* rep

Create configurable ageing buckets.

Identify:

* recently active
* ageing
* stale
* severely stale
* overdue order-stage opportunities

Do not label stale leads as definitively lost.

### Delivery analytics

Calculate:

* delivery count
* average delivery days
* median delivery days
* percentiles
* delay-reason distribution
* delivery duration by delay reason
* baseline for deliveries without a recorded delay
* incremental time associated with each delay category
* branch comparison
* vehicle comparison
* expected-close timeliness where linkage permits

### Cohort/month analytics

Group leads by creation month.

Show:

* lead volume
* delivered
* lost
* active
* resolved conversion
* maturity state

Do not compare immature cohorts as though they have completed outcomes.

## Reusability

Every analytics method must operate on the supplied records/filter scope.

Do not reference known current-dataset numbers in production calculations.

## Tests

Test:

* denominator correctness
* empty data
* single-record data
* funnel progression
* loss-stage attribution
* branch grouping
* rep grouping
* source metrics
* vehicle metrics
* pipeline ageing
* delivery durations
* mature vs immature cohorts

## Acceptance criteria

Given another valid same-schema dealership dataset, all analytics regenerate automatically.

Results are independent of Flutter UI.

## Verification

Run:

```bash
flutter analyze
flutter test
```

Report any analytical ambiguity instead of silently making a business assumption.

# PROMPT 4 — BUILD THE INSIGHT ENGINE

## Goal

Build an explainable, deterministic insight engine that converts analytical results into a small ranked set of management findings.

The engine should behave like an automated analytical layer, not a collection of hard-coded messages.

## Insight structure

Each insight should preserve enough information for the UI to explain and investigate it.

Include fields equivalent to:

* stable insight ID
* category
* severity
* title
* concise finding
* business significance
* observed metric
* comparison benchmark
* absolute difference
* relative difference
* affected lead count
* affected deal value where meaningful
* evidence strength
* relevant branch/rep/source/model IDs
* exact affected lead IDs
* suggested investigation
* reason the insight was generated

Suggested categories:

* funnel
* branch
* rep
* source
* vehicle
* pipeline
* delivery
* data quality
* positive opportunity

Suggested severities:

* critical
* warning
* opportunity
* positive
* informational

## Insight detection

Support general patterns including:

### Funnel

* unusually large leakage
* majority of losses occurring before an important gate
* unusually slow progression

### Branch

* conversion materially below network
* branch underperforming across several stages
* low workload combined with poor performance
* strong sales results paired with weak delivery reliability

### Rep

* materially above/below branch benchmark
* strong or weak stage-specific performance
* high workload with resilient performance
* slow progression/follow-up

Frame rep findings as coaching/investigation information, not personal judgment.

### Source

Differentiate:

* low contact rate
* low post-contact progression
* low overall resolved conversion
* high-quality but low-volume source
* high-value opportunity concentration

### Vehicle

Detect:

* high value contribution with weak conversion
* high demand with low delivered-value contribution
* economically important models
* concentrated loss reasons

### Pipeline

Detect:

* stale active opportunities
* overdue order-stage opportunities
* large stale opportunity value
* potential CRM hygiene issues from extremely old active records

### Delivery

Detect:

* delay reasons associated with materially longer fulfilment
* branch delivery outliers
* revenue strength paired with poor timeliness

### Data quality

Surface suspicious inconsistencies without automatically changing records.

## Benchmarking

Prefer:

* network benchmark
* branch benchmark
* medians
* percentile comparisons
* robust deviation measures

Protect against tiny samples.

Set explicit minimum sample support for comparisons.

If evidence is weak, either suppress the insight or label confidence/support appropriately.

## Ranking

Rank insights using transparent factors such as:

* severity
* deviation magnitude
* affected records
* affected deal value
* urgency
* evidence/sample strength

Do not let a one-record anomaly outrank a large material business issue merely because its percentage is extreme.

Default overview should surface approximately 4–8 top insights.

## Language

Use neutral analytical wording.

Good:

> Social-media leads progress to delivery below the network benchmark even among contacted leads. Review lead quality and handling.

Bad:

> Social media is wasting money.

Do not infer causality from correlation.

## Evidence

Every record-based insight must expose the exact record IDs used to create it.

The UI must be able to open those records directly.

## Tests

Create tests where:

* a clear anomaly triggers
* a normal branch does not trigger
* tiny samples are suppressed
* stale pipeline generates an insight
* high deal-value impact affects ranking
* evidence IDs match the counted records

## Acceptance criteria

No rule contains current known IDs such as `B3`, `SR17`, or specific current dataset values.

Replacing the dataset can result in completely different branches/sources/models being flagged.

## Verification

Run tests and analysis.

Also print or serialize the top insights produced for the supplied dataset so their reasonableness can be reviewed before UI work starts.

# PROMPT 5 — BUILD FILTERING AND APPLICATION STATE

## Goal

Implement application state so every displayed metric and insight can be recalculated for the user's current analysis scope.

## Context

The analytics and insight engine already exist.

Prefer the existing project state-management approach if one is already established.

If none exists, use a lightweight maintainable solution appropriate for Flutter Web such as Riverpod.

## Filters

Support:

* date range
* branch
* sales rep
* source
* vehicle model
* lead status

## Filter semantics

Define date filtering explicitly.

For lead/cohort analytics, use lead creation date unless the metric logically belongs to another event.

For delivery analytics, use delivery date where appropriate.

Document these semantics.

## Behavior

A filter must change the source scope passed into analytics.

Do NOT calculate global metrics and merely hide rows visually.

Expected flow:

```text
filters
→ scoped records
→ analytics
→ insights
→ UI
```

A selected branch should constrain available reps.

Resetting filters should return to the default network view.

## Routing/shareability

Keep branch and rep drill-down state compatible with browser routing.

Avoid state designs that prevent direct navigation to:

```text
/branch/:id
/rep/:id
```

## Tests

Test:

* date scope
* branch scope
* rep scope
* source
* vehicle
* combined filters
* reset
* no-match result
* branch/rep dependency

## Acceptance criteria

Changing filters changes:

* KPIs
* funnel
* tables/charts
* insights
* evidence counts

through recalculation rather than presentation-only filtering.

## Verification

Run `flutter analyze` and relevant tests.

# PROMPT 6 — BUILD THE CEO OVERVIEW

## Goal

Build the primary leadership dashboard for **yoyotaDealers**.

The page should make the most important business situation understandable in approximately 30 seconds.

## Information hierarchy

The page should answer questions in this order:

1. What is the current business position?
2. What requires attention now?
3. Where does the sales journey break?
4. Which branches differ materially?
5. Which sources/models matter?
6. Is the active pipeline and delivery process healthy?

Do not make charts the first thing the user sees simply because charts are available.

## Layout

Build a polished responsive Flutter Web interface for:

* desktop
* tablet

Prevent mobile overflow even though mobile is not the primary requirement.

Use a consistent SaaS visual system:

* strong typography hierarchy
* restrained colors
* accessible contrast
* consistent spacing
* subtle borders
* limited elevation
* clear interactive states

Avoid decorative clutter and unnecessary gradients.

## Sections

### Header/filter bar

Include:

* current date range
* branch filter
* additional filters through a compact control
* reset filters

### Business Pulse

Display approximately 4–6 metrics selected from:

* customer enquiries
* delivered vehicles
* resolved conversion
* active opportunities
* delivered deal value
* stale/overdue opportunities

Each unfamiliar metric needs a short tooltip.

### Attention Center

Make the top insight cards visually prominent.

Each insight card should show:

* severity
* finding
* metric
* benchmark where applicable
* number/value affected
* short business meaning
* clear drill-down action

Use generated insights only.

Do not hard-code dashboard findings.

### Sales journey

Build an easily understandable funnel or gate visualization.

Show:

* counts
* progression
* leakage

Allow important transitions to be investigated.

### Branch diagnostics

Provide a compact comparison of branch health.

Do not create a simplistic “best/worst” leaderboard.

Show enough context to reveal why a branch differs.

### Lead-source diagnostics

Make it easy to compare:

* volume
* contact rate
* resolved conversion
* post-contact conversion

### Vehicle/model diagnostics

Show:

* demand share
* conversion
* delivered-value contribution

### Monthly/cohort view

Clearly mark immature cohorts so recent months are not visually presented as failed performance.

### Delivery/pipeline health

Provide compact operational signals and links to deeper pages.

## Loading/error/empty states

Implement:

* initial loading state
* dataset error state
* validation warning surface
* no-results state after filtering
* chart/table empty states

## Acceptance criteria

A new same-schema dataset can produce a completely different overview without UI code modification.

Every visible finding comes from the analytical layer.

The page remains useful without explaining the JSON structure to the user.

## Verification

Run:

```bash
flutter analyze
flutter test
flutter build web
```

# PROMPT 7 — BUILD BRANCH, REP AND EVIDENCE DRILL-DOWN

## Goal

Implement progressive investigation from network overview to exact source records.

Required navigation:

```text
Overview
→ Branch
→ Sales Rep
→ Lead evidence
```

Use browser-compatible routing.

## Branch detail

The branch screen must answer:

> Why is this branch performing this way?

Include:

* branch KPIs
* branch vs network comparison
* funnel/gate comparison
* stage progression speed
* source mix/performance
* model mix/performance
* rep comparison
* lost reasons
* active pipeline
* stale/overdue opportunities
* delivery health
* branch-specific insights

Do not simply duplicate the overview with the branch filter applied.

Highlight diagnostic differences.

## Rep detail

The rep screen must answer:

> Where is this rep strong, and where may coaching or follow-up be useful?

Include:

* workload
* active/resolved outcomes
* resolved conversion
* branch benchmark
* stage conversion
* stage progression speed
* active opportunity value
* stale opportunities
* delivered value

Avoid demeaning or absolute performance labels.

## Lead evidence view

Open a lead in a drawer, side panel or appropriate web dialog.

Display:

* customer
* vehicle
* source
* branch
* rep
* deal value
* current status
* expected close
* last activity

Display the complete status timeline with:

* status
* timestamp
* note

If opened from an insight, explain why the lead was included.

Example:

> Included because this order has had no recorded activity for 42 days.

## Evidence navigation

When an insight says:

> 24 leads affected

the action must open exactly those 24 IDs.

Do not send the user to a generic branch page and make them search manually.

## Acceptance criteria

Every significant overview finding can be investigated through evidence.

Direct browser navigation and refresh should work for branch/rep routes.

Desktop and tablet layouts remain usable.

## Verification

Run analysis, tests and web build.

# PROMPT 8 — BUILD PIPELINE AND DELIVERY INTELLIGENCE

## Goal

Create dedicated operational views for active pipeline quality and delivery performance.

## Pipeline view

Answer:

> Which opportunities are truly active, and which require verification or intervention?

Show:

* active lead count/value
* pipeline by stage
* inactivity distribution
* age distribution
* expected-close slippage
* order-stage backlog
* oldest opportunities
* stale opportunity value
* branch breakdown
* rep breakdown

Use configurable classification thresholds such as:

* healthy
* watch
* stale
* critical

Document the definitions.

Do not imply stale automatically means lost.

Allow direct evidence inspection.

## Delivery view

Answer:

> Are completed sales being fulfilled efficiently and reliably?

Show:

* deliveries
* median delivery duration
* average delivery duration
* distribution
* branch comparison
* vehicle comparison
* delay reasons
* duration by delay reason
* incremental time compared with deliveries without a recorded delay
* expected-close timeliness where supported

Use robust language.

Example:

> Deliveries recorded with finance-disbursement delays took approximately X additional days compared with deliveries that had no recorded delay.

Do not claim the delay field proves causality beyond the recorded association.

## Acceptance criteria

All calculations come from the analytics engine.

Filters work on these views.

Evidence is navigable.

## Verification

Run analysis, tests and web build.

# PROMPT 9 — PRODUCT POLISH, TESTS, DOCUMENTATION AND VERCEL

## Goal

Prepare **yoyotaDealers** for submission as a production-quality take-home project.

Do not add speculative features before completing reliability and polish.

## Quality review

Check:

* calculation correctness
* small sample handling
* filter correctness
* drill-down behavior
* empty states
* loading states
* error states
* desktop layout
* tablet layout
* browser refresh on routes
* accessibility
* chart readability
* tooltip clarity
* performance

## Testing

Ensure meaningful coverage for:

* parsing
* validation
* feature engineering
* funnel
* conversion
* branch analytics
* rep analytics
* source analytics
* vehicle analytics
* cohort maturity
* pipeline ageing
* delivery analysis
* insight generation
* insight ranking
* evidence IDs
* filter behavior

Do not create tests solely to inflate test count.

## Documentation

Create or finish:

`README.md`

and:

`DECISIONS.md`

### README should include

* project overview
* product screenshots section
* architecture
* setup
* commands
* analytics architecture
* tests
* Flutter Web build
* Vercel deployment

### DECISIONS.md should explain

#### Product approach

Explain the sequence:

```text
business position
→ problem detection
→ diagnosis
→ evidence
→ action
```

#### Resolved conversion

Explain why active deals are excluded from the failure denominator.

#### Status-history reconstruction

Explain how stage journeys are derived.

#### Cohort maturity

Explain why recent cohorts cannot be compared naively against older cohorts.

#### Explainable insight engine

Explain why deterministic evidence-backed analytics were chosen instead of runtime LLM summaries.

#### Dataset limitations

Describe actual limitations observed in the source data.

Specifically do not hide questionable comparability between monthly targets and the supplied lead population if the validation/analytics reveal it.

#### Interesting patterns

Generate this section from actual analytical output.

Do not manually invent conclusions that the current engine does not reproduce.

#### Tradeoffs

Explain meaningful omissions such as:

* no authentication because assignment excludes it
* no backend because the supplied dataset does not require one
* no unsupported revenue forecasting
* no opaque ML unless it demonstrates additional defensible value

#### Next steps

Keep future-work proposals grounded in the current architecture.

## Vercel

Ensure:

```bash
flutter build web --release
```

works.

Configure Vercel/static SPA routing so URLs such as:

```text
/branch/B3
/rep/SR10
```

can be refreshed directly.

Verify asset loading and `dealership_data.json` in the production build.

## Final acceptance criteria

The product satisfies:

* CEO overview
* branch drill-down
* rep drill-down
* actionable insights
* time filtering
* responsive desktop/tablet
* direct evidence navigation
* clean architecture
* tests
* Vercel-compatible production build
* README
* DECISIONS.md

## Final verification

Run:

```bash
flutter analyze
flutter test
flutter build web --release
```

Resolve relevant failures.

Then report:

* implemented requirements
* differentiating features
* tests executed
* build status
* known limitations
* any remaining submission risk

# Why yoyotaDealers is built this way

A beginner-friendly explanation of the project's main decisions.

Read this first to understand **why** the project works this way. Then use the
[Project handbook](PROJECT_HANDBOOK.md) to find code and make changes.

## How to read this document

This is a walkthrough of the implemented design, in the order someone might build
it. It is not a claim that every step happened in this exact order. The finishing-pass
decisions are documented in the work on this project; explanations of earlier
architecture describe the rationale supported by the code and project requirements,
not an invented record of the original author's thoughts.

An **opportunity** is a potential sale. A **resolved** opportunity has either been
delivered or lost. An **active** opportunity is still in progress. A **cohort** is a
group of leads received in the same period. A **denominator** is the number below
the division sign in a percentage calculation.

## 1. Start with the manager's decisions

**Decision:** Make a dealership/sales manager the primary user.

**Why:** The manager needs to know performance, target gaps, weak branches and who
needs follow-up. A technically complete report is not useful if those answers are
buried underneath explanations.

**Result:** The first screen shows filters, the data date, six KPIs, targets and
“What needs attention.” Deeper analysis remains below or in detail pages.

**Trade-off:** Not every chart receives equal prominence. The most useful management
information gets the first screen; detailed methodology is still accessible.

**Where:** `lib/features/dashboard/dashboard_page.dart` and `dashboard_view_data.dart`.

## 2. Keep Flutter Web and the existing project

**Decision:** Improve the existing Flutter application instead of rewriting it or
adding a separate frontend.

**Why:** Flutter Web is the required platform, and the existing calculation layer
already handles important analytical distinctions correctly. Reusing it limits
regression risk and keeps the assignment focused.

**Trade-off:** Browser navigation and downloads need explicit Flutter/web integration.
Flutter's rendered interface also requires real browser testing, not just checking
HTML markup.

**Where:** `pubspec.yaml`, `lib/main.dart`, `lib/app/`.

## 3. Load a bundled dataset without a backend

**Decision:** Read the supplied JSON asset in the browser. Do not introduce a
database, login system or live CRM connection.

**Why:** The assignment can be satisfied using the supplied data. Extra services
would add setup, failure modes and unrelated work.

**Trade-off:** This is a snapshot dashboard, not a live CRM. Downloads do not assign
work or update customer records. The bundled data is delivered to the browser;
this architecture is not access control for confidential production CRM data.

**Where:** `assets/data/dealership_data.json`, `lib/data/sources/`, `lib/data/repositories/`.

## 4. Convert JSON into typed objects at the boundary

**Decision:** Parse the input into objects such as `Lead`, `Branch`, `Target` and
`Delivery` before calculations or screens use it.

**Why:** A typed object tells developers what fields exist and what they mean.
Spreading raw JSON keys throughout widgets makes misspellings and inconsistent
interpretations harder to detect.

**Trade-off:** Adding a source field takes a little more work: the model, parser and
tests must agree. That extra step catches mistakes early.

**Where:** `lib/data/models/dealership_models.dart`, `lib/data/parsing/dealership_dataset_parser.dart`.

## 5. Report questionable data instead of silently repairing it

**Decision:** Preserve the source and return structured validation findings.

**Why:** If a lead's current status and final history entry disagree, silently
choosing one would hide a source problem. A manager should see the warning and
have supporting records available.

**Trade-off:** Different calculations may need different eligibility rules. A parsed
record is not a guarantee that every field is reliable. Validation severity and
metric-specific exclusions must be understood together.

**Where:** `lib/data/validation/validation.dart`, the parser, and the dashboard's
quality-notice dialog. Detailed policies are in [Analytics specification](ANALYTICS_SPEC.md).

## 6. Derive reusable facts once

**Decision:** Build analytical lead records before aggregating results.

**Why:** Many reports need the same facts: stage-entry dates, inactivity, loss stage,
valid transition durations and maturity. Deriving these centrally prevents separate
screens from interpreting the same history differently.

**Trade-off:** There are two representations of a lead: the original typed source
record and its derived analytical record. The latter adds facts; it does not edit
the former.

**Where:** `lib/analytics/services/lead_feature_engineer.dart`, `lib/analytics/models/analytical_lead.dart`.

## 7. Keep active opportunities out of resolved conversion

**Decision:** Calculate resolved conversion as delivered ÷ (delivered + lost).

**Why:** An unfinished opportunity has not failed. For example, 10 delivered,
10 lost and 5 active means 50% resolved conversion, with 5 active shown separately.
10 ÷ 25 is a different metric: delivery share of all leads.

**Trade-off:** A high resolved conversion alone does not describe the size or age of
an unfinished pipeline. That is why active counts, aging and cohorts remain visible.
With no resolved leads, the rate is unavailable, not 0%.

**Where:** `lib/analytics/services/dealership_analytics_engine.dart`.

## 8. Separate arrival dates from delivery dates

**Decision:** Lead performance uses the lead's creation date; delivery reporting and
unit-target actuals use the delivery date.

**Why:** A lead received in November and delivered in December belongs to November's
lead group and December's delivery output. Filtering both by creation date would
incorrectly remove that vehicle from December production.

**Trade-off:** “Vehicles delivered” can differ from the delivered outcome count of
the currently selected lead cohort. This is intentional and explained in KPI help.
The numbers answer different questions.

**Where:** `lib/application/analysis/analysis_scope_service.dart`,
`lib/analytics/services/management_performance.dart`.

## 9. Anchor aging to the dataset, not today's clock

**Decision:** Use the latest observed business event as the default analytical date.
Expected-close promises and target months do not move that date forward.

**Why:** Opening historical data next year must not make every opportunity another
year overdue. The same dataset should give reproducible results.

**Trade-off:** “Needs follow-up” means attention as of the recorded snapshot, not a
claim about the customer's current real-world situation. The supplied dataset's
snapshot is 31 December 2025; that date is calculated, not hard-coded into the UI.

For an entirely empty set of business timestamps, the implementation falls back
to metadata generation time. The supplied populated dataset does not use that fallback.

**Where:** `LeadFeatureEngineer` and the shared analytical context.

## 10. Label recent cohorts as immature

**Decision:** Estimate the observation window from the 80th percentile of observed
successful sales-cycle durations and conservatively label incomplete cohorts.

**Why:** Newly received leads have had less time to complete. Treating their lower
conversion as proven poor performance would be misleading.

**Trade-off:** This is an empirical safeguard, not a forecast or a guarantee. If no
completed successful cycles exist, maturity is unavailable rather than invented.
Changing this rule changes interpretation and needs tests and specification updates.

**Where:** `lead_feature_engineer.dart`, cohort analytics, `ANALYTICS_SPEC.md`.

## 11. Match targets only where they actually apply

**Decision:** Compare branch-month unit targets with deliveries in the same
branch-months. Show actual, target, difference and attainment.

**Why:** Those quantities are compatible. Representative, source, model and status
targets are not supplied, so the app does not distribute branch targets arbitrarily.

**Trade-off:** Target reporting disappears under incompatible filters. Missing,
duplicate or negative targets are excluded on both sides of the ratio. A zero target
has no attainment percentage. Partial periods keep the full monthly target and a
partial-period label; no fabricated prorated target or forecast is shown.

The extract may not cover every sale behind the targets. The UI retains this caveat
rather than presenting the gap as conclusive proof of business failure.

**Where:** `management_performance.dart`, `lib/features/shared/target_panel.dart`.

## 12. Avoid invented money and unsupported revenue claims

**Decision:** Show “value” without assuming a currency; prioritize unit targets.

**Why:** The dataset does not establish a currency or a separate realized-revenue
measure. Lead deal value is not automatically revenue or profit.

**Trade-off:** The interface is less financially specific than a production system
with an explicit accounting definition. That is preferable to false precision.

**Where:** Shared formatting, analytics definitions and CSV headers.

## 13. Generate explainable findings with rules

**Decision:** Use a deterministic insight engine, not AI-generated conclusions.
“Deterministic” means the same input and settings produce the same result.

**Why:** Findings can be tested, ranked and traced to exact records. Minimum sample
sizes prevent tiny groups from dominating comparisons. Wording recommends an
investigation instead of claiming a cause the dataset cannot prove.

**Trade-off:** The rules only find patterns they were designed to detect. Severity
and rank are configurable attention signals, not statistical certainty or a forecast.

**Where:** `lib/insights/services/deterministic_insight_engine.dart`,
`lib/insights/models/insight_engine_config.dart` and `management_insight.dart`.

## 14. Use one calculation flow for all filters

**Decision:** Apply filters to records, recalculate centrally, then render the result.

**Why:** Filtering a finished chart without recalculating its denominator can produce
incorrect percentages and stale findings.

**Trade-off:** Results are recalculated in memory when filters change. This is simple
for the supplied data, but substantially larger datasets may require profiling and
more efficient computation before adding features.

**Where:** `lib/application/analysis/analysis_controller.dart` and `analysis_results.dart`.

## 15. Make the URL represent the current view

**Decision:** Connect the existing filter codec to Flutter's Router, with hash URLs.

**Why:** A manager must be able to refresh, bookmark and use Back/Forward without
losing filters. One router avoids competing sources of navigation state. Hash paths
also work on a simple static server without special path rewrites.

**Trade-off:** URLs contain `#/`. Restoring browser state must not create another
history entry, so restoration uses a guard against feedback loops.

The incoming URL is captured before asynchronous data loading and explicitly
applied when the real router is ready. This prevents the loading screen from losing
filter state on refresh, including after a failed load and retry.

**Where:** `lib/app/analysis_router.dart`, `yoyota_dealers_app.dart`,
`lib/application/analysis/analysis_route_codec.dart`.

## 16. Turn evidence into a practical follow-up list

**Decision:** Add CSV downloads to supporting-record dialogs.

**Why:** A manager can take the affected opportunities to a representative for
follow-up. Exports retain current filters and include useful contact/context fields.

**Trade-off:** Downloading is the end of this workflow; there is no CRM write-back.
The active-only list and all-records export are separate so resolved leads are not
mislabelled as open work. CSV quoting and formula-leading text protection help the
file behave safely in spreadsheet applications.

**Where:** `lib/application/export/follow_up_csv.dart`, `lib/platform/download*.dart`,
`lib/features/investigation/lead_evidence_dialog.dart`.

## 17. Prefer simple visuals and explicit navigation

**Decision:** Use numerical labels, restrained bars, obvious representative buttons,
responsive reflow and plain-language actions.

**Why:** A manager should not have to discover an invisible chart interaction to
reach a branch or employee. Status text accompanies colour. Tooltips preserve
important definitions without filling the first screen with methodology.

**Trade-off:** The dashboard has less decoration and fewer simultaneous views.
Desktop tables become stacked content at smaller widths.

**Where:** `lib/features/`, `lib/app/app_theme.dart`.

Research references and the applied principles are in
[Product UX notes](PRODUCT_UX_NOTES.md), including Microsoft Power BI, Tableau,
VinSolutions and DealerSocket. The comparison project informed presentation review;
its active-as-loss interpretation was not adopted.

## 18. Verify mathematics and real interaction separately

**Decision:** Use pure calculation tests, widget tests, routing/export tests and
manual browser checks.

**Why:** A correct formula does not prove that a dropdown updates the URL. A successful
build does not prove a CSV downloads or a mobile dialog fits on screen.

**Trade-off:** Browser checking takes additional time and is not exhaustive.
The original finishing pass had 77 passing tests; the 25 September navigation pass
had 98, a clean analyzer and a successful web build. These are dated results,
not a promise about future edits. The verification record separates the passes.

**Where:** `test/` and [Verification record](VERIFICATION.md).

## 19. Show the comparison choices before asking users to choose

**Decision:** Replace the small Explore performance entry button with four visible
main tabs. Replace the measure and comparison-group dropdowns with visible buttons.

**Why:** A manager should see what can be compared without opening menus to discover
the options. The order follows the question: choose **Resolved conversion**, then
**Branches**, to answer “Which branches convert more of their resolved leads?”
All 17 measures remain available, organised into four labelled groups.

**Trade-off:** Visible choices take more space. They wrap into extra rows on phones,
so the results may require vertical scrolling. Only the chosen comparison is drawn;
the screen does not display 17 charts at once.

**State decision:** Each main section has its own URL. The three explorer tabs
share a page identity, so measure/group/sort selections stay in place between them.
Refresh restores the section and data filters, but resets those local choices.
Visiting Overview also resets the explorer choices. No analytical formula changes.

**Where:** `lib/features/shared/performance_navigation.dart`,
`lib/features/exploration/exploration_page.dart`, `exploration_presenter.dart`,
and `lib/app/analysis_router.dart`.

## 20. Give every page the same workspace and appearance controls

**Decision:** Move the previous main tab strip into a shared sidebar. Keep the
visible comparison measure and group buttons. Use a top bar for page context,
snapshot date and appearance, with one common filter toolbar below it.

**Why:** A manager can move from performance to pipeline or deliveries without
learning a different page layout or searching for filters. This replaces the main
navigation described in decision 19; the comparison choices still work the same.

**Responsive choice:** Expanded sidebar on wide desktops, an icon rail on tablets,
and a menu drawer on phones. Page content reflows to the remaining width, rather
than pretending the sidebar takes no space. Desktop users can collapse the sidebar.

**Appearance choice:** Light, Dark and System use the same semantic colour roles.
For example, “critical” remains a labelled status in both themes. Tables, chart
labels, record dialogs and loading/error screens also follow the selected theme.
System is the default. Browser storage remembers an explicit preference; if storage
is blocked, the choice still works until the app reloads. No new package is needed.

**Safeguard:** Changing appearance does not reset filters, navigation or analytics.
The palette is a presentation concern; it never recalculates a KPI. Tests cover
both themes, text contrast, navigation and phone/tablet/desktop reflow.

**Where:** `application_shell.dart`, `appearance_controller.dart`, `app_theme.dart`,
`yoyota_dealers_app.dart`, `platform/preferences*.dart` and
`test/features/application_shell_test.dart`.

## Before changing a decision

Ask: What manager question changes? Which records belong in the calculation? What
is the denominator and time basis? What happens for missing data and active leads?
Which tests and documentation must change? If the answer changes analytical meaning,
update the central service and analytics specification together.

Deployment and a formal `DECISIONS.md` remain separate work. This explanatory guide
does not change application behaviour or authorize deployment.

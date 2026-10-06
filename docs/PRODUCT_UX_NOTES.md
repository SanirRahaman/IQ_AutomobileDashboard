# Management dashboard UX review

Research reviewed 23 September 2026. External examples inform presentation only;
metric definitions remain governed by ANALYTICS_SPEC.md.

- [Fulcrum dashboard UI design](https://fulcrum.rocks/blog/dashboard-ui-design): design around the user's business decisions, make every component purposeful, minimize effort, remove irrelevant content, and use restrained, consistent visual language.
- [DealerSocket CRM dashboard guide](https://dealersocket.com/wp-content/uploads/2020/07/Home-Dashboard-Best-Practice-Guide.pdf): lean manager views, sales/prospect counts, enterprise-to-store navigation, direct access to underlying records.
- [VinSolutions: four sales-management reports](https://www.vinsolutions.com/resources/blog/four-key-vinsolutions-crm-reports-that-drive-higher-sales/): follow-up and representative execution alongside funnel performance; operational lists connect review to next action.
- [Microsoft Power BI dashboard design](https://learn.microsoft.com/en-us/power-bi/create-reports/service-dashboards-design-tips): prioritize the audience's decisions, put essential metrics first, use simple comparisons and consistent period labels, avoid decorative charts.
- [Tableau effective dashboards](https://help.tableau.com/current/pro/desktop/en-us/dashboards_best_practices.htm): clear audience/purpose, prominent key view, limited simultaneous views, discoverable filters, layouts tested at their actual device sizes.

Applied overview hierarchy: persistent workspace navigation, scope and snapshot → business pulse with decision context
→ ranked management priorities → target and operational health → management gates →
branch/source/model diagnosis → cohort detail. The default sales-journey view now
uses Contact → Test Drive → Close; the full six-stage journey remains one deliberate
action away. Further findings and technical methodology use progressive disclosure.

Insight cards expose metric, benchmark, affected records/value, business meaning,
next investigation, and exact evidence. Branch comparison uses the full available
width and adds conversion delta, stale pipeline value/share, delivery health, and a
generated diagnostic without becoming a simplistic leaderboard. Cohorts distinguish
delivered, lost, and active outcomes while preserving their maturity warning.

Target comparison remains compact and defensible. It is shown only for compatible
branch/month scope, keeps partial-month limitations visible, and links to its detailed
breakdown. Previous-period change remains limited to supported comparable periods.
The active-value KPI displays the business exposure first and its lead count as
context. Every secondary filter is included in the visible scope summary.

The existing route-backed overview → branch → representative investigation flow and
side-by-side evidence explorer were retained because they already provide low-effort
navigation from a finding to exact records and their status timelines. The theme now
centralizes semantic states, spacing, radii, table, chip, tooltip, and dialog styling;
interactive diagnostic rows use a consistent hover state.

No appointments, inventory, margin, acquisition cost, forecasts, representative
targets, or currency are inferred from the supplied data. Delivery events and
lead-creation cohorts have separate, visible definitions. Partial months are not
presented as completed target failures. Unfinished opportunities remain active.

## Direct comparison navigation — 3 October 2026

The persistent sidebar exposes Vehicle models, Branches, Representatives and Lead
sources beneath **Compare performance**. Each destination opens immediately with
populated results and a useful default measure. A compact row of visible measure
buttons, with More measures and an expandable two-group comparison, replaces the redundant compare-by workflow. Results repeat the selected
measure, period and filters, while representative comparisons disclose branch
restrictions and retain branch context.

Rank numbers describe the selected measure rather than assigning an overall score.
Exact text badges explain the extreme, support thresholds prevent tiny samples
from becoming winners, ties share ranks, and equal or single-item comparisons do
not create winner badges. Risk-oriented highs use an investigation treatment;
demand and active-value differences remain neutral. Evidence stays available from
each result.

The overview is titled **Business overview** and describes only the operations
supported by the data: opportunities, sales, supplied targets, pipeline, follow-up
and deliveries. The scorecard is denser, and compact target context sits beside
the first actionable findings where width allows. Detailed target records and
remaining findings stay one action away. Analytical definitions and source data
are unchanged.

## Shared workspace and appearance — 26 September 2026

Released to production on 26 September in UI commit `8c7403e`, followed by
deployment dependency fix `3c9514a`. See [Verification records](VERIFICATION.md).

The main tab strip is now a persistent grouped sidebar, including direct comparison,
pipeline and delivery destinations. It becomes an icon rail on tablets and a drawer
on phones. Relevant comparison measures remain visible in each page. A shared top bar
and filter toolbar keep page context, historical snapshot and scope discoverable.

Light, Dark and System share semantic colours, labelled statuses and existing
branding. Browser storage saves appearance only. Cards, tables, charts, menus and
supporting-record panels follow the same palette. There are no decorative gauges,
fake account controls or new analytics. The sidebar can collapse on desktop; inner
page breakpoints use the width remaining after navigation.

## Shared visual vocabulary — 6 October 2026

`features/shared/dashboard_icons.dart` is the presentation-level source of truth
for dealership concepts such as leads, deliveries, active value, conversion,
targets, follow-up, branches, representatives, sources, vehicles, timing and
supporting records. Concept icons identify what information represents; existing
typed severity and ranking treatments separately communicate whether it is
favourable, neutral or worth investigation. Important icons retain visible labels,
and icon-only controls retain tooltips and semantic labels.

The six Business overview cards use one row whenever the post-sidebar content width
is at least 900 pixels, which covers 1280, 1366 and 1440 pixel desktop windows with
the expanded sidebar. Cards reflow to three, two or one column as their actual
available width decreases. The management-priority section uses two finding columns
from 620 pixels so target context and both leading findings appear earlier without
shrinking typography or introducing horizontal scrolling.

Icons supplement the existing text rather than replacing it. For example, the car
identifies delivered vehicles, the target identifies attainment, and the records
icon identifies evidence actions. Neither the icon nor its colour changes the
meaning of a metric. The historical snapshot remains in the shared footer;
definitions and supporting-record actions remain available on each summary card.

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

## Visible performance navigation — 25 September 2026

The small Explore performance button and its comparison dropdowns hid the available
questions. The interface now exposes **Overview · Comparisons · Monthly trends ·
Follow-up lists** near the Sales performance heading. These share the existing
routes and filters rather than introducing another navigation system.

Comparisons asks for the measure first, then who to compare. All 17 measures are
visible in four labelled groups: Sales, Conversion, Pipeline, and Losses & delivery.
Vehicle models, Branches, Representatives and Lead sources are visible selection
buttons underneath. For example: **Comparisons → Resolved conversion → Branches**.
The selected measure and group are repeated in the results heading.

Selected controls use text/checkmarks as well as the existing brand colour.
Controls wrap at smaller widths instead of requiring horizontal scrolling.
The trade-off is more vertical space, especially on phones; results follow below
the choices. Existing bars, ranking controls, two-group comparison, evidence and
exports remain available. Analytical definitions and source data are unchanged.

The section and data filters survive refresh through the URL. Measure/group/sort
choices persist between the three explorer tabs, but reset after refresh or a
visit to Overview. This distinction is explained in the user guide.

## Shared workspace and appearance — 26 September 2026

The main tab strip is now a persistent sidebar with six destinations, including
pipeline and deliveries. It becomes an icon rail on tablets and a drawer on phones.
Comparison measures and dimensions remain visible in the page. A shared top bar
and filter toolbar keep page context, historical snapshot and scope discoverable.

Light, Dark and System share semantic colours, labelled statuses and existing
branding. Browser storage saves appearance only. Cards, tables, charts, menus and
supporting-record panels follow the same palette. There are no decorative gauges,
fake account controls or new analytics. The sidebar can collapse on desktop; inner
page breakpoints use the width remaining after navigation.

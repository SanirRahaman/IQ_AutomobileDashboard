# Management dashboard finishing pass

Research reviewed 17 September 2026. Vendor examples inform presentation only;
metric definitions remain governed by ANALYTICS_SPEC.md.

- [DealerSocket CRM dashboard guide](https://dealersocket.com/wp-content/uploads/2020/07/Home-Dashboard-Best-Practice-Guide.pdf): lean manager views, sales/prospect counts, enterprise-to-store navigation, direct access to underlying records.
- [VinSolutions: four sales-management reports](https://www.vinsolutions.com/resources/blog/four-key-vinsolutions-crm-reports-that-drive-higher-sales/): follow-up and representative execution alongside funnel performance; operational lists connect review to next action.
- [Microsoft Power BI dashboard design](https://learn.microsoft.com/en-us/power-bi/create-reports/service-dashboards-design-tips): prioritize the audience's decisions, put essential metrics first, use simple comparisons and consistent period labels, avoid decorative charts.
- [Tableau effective dashboards](https://help.tableau.com/current/pro/desktop/en-us/dashboards_best_practices.htm): clear audience/purpose, prominent key view, limited simultaneous views, discoverable filters, layouts tested at their actual device sizes.

Applied hierarchy: period and snapshot → six management measures → delivery-target
comparison and actionable exceptions → branch/representative diagnosis → supporting
records and follow-up export. Actual/target bars retain numeric labels and explicit
status text; colour is secondary. Further findings are expandable. Technical
methodology remains available without becoming the dashboard's introductory text.

No appointments, inventory, margin, acquisition cost, forecasts, representative
targets, or currency are inferred from the supplied data. Delivery events and
lead-creation cohorts have separate, visible definitions. Partial months are not
presented as completed target failures. Unfinished opportunities remain active.

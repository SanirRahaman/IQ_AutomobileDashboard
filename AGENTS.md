# yoyotaDealers project rules

- The product name is `yoyotaDealers`; the Dart package name is `yoyota_dealers`.
- Flutter Web is the application platform.
- Keep analytics and business logic in pure Dart services, never in widgets or `build()` methods.
- Never modify raw source data. Treat bundled datasets as immutable inputs.
- Do not hard-code dataset-specific values, identifiers, conclusions, or findings.
- Replacement datasets that follow the canonical schema must work without analytics code changes.
- Use typed models at the canonical-schema boundary; UI code must not consume raw JSON maps.
- Centralize derived metrics and avoid duplicated calculations.
- Never infer or invent a currency.
- Treat active opportunities separately from resolved outcomes; active leads are not failed conversions.
- Run relevant tests and `flutter analyze` for meaningful analytical changes.
- Keep `docs/ANALYTICS_SPEC.md` and related documentation synchronized with analytical definition changes.


# yoyotaDealers

A Flutter Web dashboard that turns a supplied dealership dataset into sales performance, target comparisons, management findings, and customer follow-up lists.

**Repository:** [SanirRahaman/IQ_AutomobileDashboard](https://github.com/SanirRahaman/IQ_AutomobileDashboard)

**Live website:** [iq-automobile-dashboard.vercel.app](https://iq-automobile-dashboard.vercel.app)

## Features

- Management scorecard with leads, delivered vehicles, active opportunities, resolved conversion, target attainment and follow-up counts.
- Branch → representative → supporting customer-record investigation.
- Period, branch, representative, source, vehicle and status filters with URL persistence.
- Branch-month delivery targets with actuals, variance and attainment, plus eligible previous-month delivery comparisons.
- Sales funnel, lead cohorts, pipeline aging and delivery analysis.
- Rule-based findings with supporting records and filtered CSV downloads.
- Visible data-quality warnings, cohort maturity labels and a dataset-derived snapshot date.
- Responsive desktop, tablet and mobile layouts.

This is a snapshot dashboard, not a live CRM. It has no login, backend, database, customer-record editor or runtime AI service. Calculations run in the browser. Active opportunities remain distinct from losses; no currency is inferred.

## Tech stack and prerequisites

- Flutter **3.24.4**, with Dart **3.5.4** (validated deployment toolchain).
- Flutter Material widgets; pure Dart analytics and rule-based insights.
- Bundled JSON data; Flutter Router for navigation; static hosting on Vercel.
- Git and a web-capable browser; Chrome is used by `flutter run -d chrome`.

Vercel builds install the pinned Flutter SDK using `scripts/vercel-build.sh`; Flutter is not assumed to be preinstalled. The build environment needs Git, Bash, network access and Flutter's Linux runtime prerequisites, as supplied by the standard Vercel build image.

## Clone and install

```bash
git clone https://github.com/SanirRahaman/IQ_AutomobileDashboard.git
cd IQ_AutomobileDashboard
flutter config --enable-web
flutter pub get
```

Use `flutter doctor` to diagnose local toolchain problems. `pubspec.yaml` is at the repository root. Commit `pubspec.lock` so builds use the same dependency versions.

## Run locally / Flutter Web

```bash
flutter run -d chrome
```

To serve the development app for another browser:

```bash
flutter run -d web-server --web-port 8080
```

Open the local URL printed by Flutter.

## Checks and production build

```bash
flutter analyze
flutter test
flutter build web --release
```

The generated static website is in `build/web/`. Do not edit or commit that directory.

To preview the production files locally (requires Python 3):

```bash
python3 -m http.server 8080 --directory build/web
```

Open `http://localhost:8080`. Hash routes such as `/#/branch/B1` work on this simple static server.

## Project structure

```text
assets/data/       Supplied canonical JSON dataset
lib/app/           Startup, theme and routing
lib/data/          Typed models, loading, parsing and validation
lib/domain/        Dataset relationship indexes
lib/analytics/     Lead facts and centralized business calculations
lib/application/   Filters, state coordination, route codec and CSV builder
lib/insights/      Explainable management rules and evidence
lib/features/      Dashboard, investigations and operational pages
lib/platform/      Browser download adapter
scripts/           Reproducible Vercel build
web/               Browser shell, manifest and icons
test/              Data, analytics, routing, export and widget tests
docs/              Specifications and user/developer guides
tool/              Command-line insight inspection
```

## Vercel deployment

Import this GitHub repository into Vercel, choose **Other** as the framework, and keep the root directory at the repository root. `vercel.json` provides:

- Install command: no separate Node dependency installation.
- Build command: `bash scripts/vercel-build.sh`.
- Output directory: `build/web`.
- SPA fallback for application paths while preserving static-asset requests.
- Revalidation headers so stable Flutter asset filenames are checked for updates.

The build script downloads Flutter 3.24.4, installs locked dependencies, runs the analyzer and creates the release web build. Build artifacts are generated on Vercel, not stored in GitHub.

The Vercel project **sanir1/iq-automobile-dashboard** is connected to this GitHub repository with **main** as its production branch. Pushes to `main` trigger production deployments. Other branches can create preview deployments under Vercel's project settings. The production site has been checked for Flutter startup, static assets and branch-route refresh with retained date filters.

For CLI deployment after installing the official Vercel CLI and signing in:

```bash
vercel link
vercel git connect
vercel --prod
```

The application uses hash routes by default. Refreshing a link such as `/#/rep/SR2` restores its route and filter parameters. The SPA fallback also serves the application shell for extensionless paths.

## Environment variables and important notes

- **No application environment variables, API keys or `.env` file are required.**
- Vercel/GitHub authentication belongs in their account tools, never in source files or commits. `.vercel/`, environment files and credential files are ignored.
- `assets/data/dealership_data.json` is bundled into the public website and is downloadable by visitors. This app has no access-control layer.
- The source data is immutable. Replace it only through an intentional dataset update; do not silently repair raw records.
- Snapshot dates and aging come from observed dataset events, not today's system date.
- Lead-cohort metrics use creation dates; delivery output and target actuals use delivery dates.
- Targets are supplied at branch-month level; representative targets and realized revenue are not invented.
- If an old local build appears, use a fresh browser session/port to check for service-worker caching before changing application code.

## Documentation

- [Business owner's user guide](docs/BUSINESS_OWNER_USER_GUIDE.md)
- [Project handbook](docs/PROJECT_HANDBOOK.md)
- [Decisions explained](docs/PROJECT_DECISIONS_EXPLAINED.md)
- [Analytics specification](docs/ANALYTICS_SPEC.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Dashboard UX research](docs/PRODUCT_UX_NOTES.md)
- [Finishing-pass verification record](docs/VERIFICATION.md)

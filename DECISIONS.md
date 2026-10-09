# Why I built DealerPulse this way

## What I wanted this project to do

I wanted a dealership owner or manager to open the dashboard and understand how the business is doing, where something needs attention, and which records they should look at next. Showing a lot of charts was not enough for me.

The flow I aimed for was: see the overall result, find a problem, open the branch, check the representative, and inspect the supporting opportunities. I added CSV downloads so the manager can take a follow-up list into a team discussion.

The live app is at [iq-automobile-dashboard.vercel.app](https://iq-automobile-dashboard.vercel.app/).

## Why I used Flutter and kept the setup simple

I am comfortable with Dart, so I chose Flutter Web. I kept the calculations in separate Dart services so changing the screen does not mean changing how conversion or targets are calculated.

I used the supplied JSON directly instead of building a backend.

This means the app shows a snapshot, not a live CRM feed. It cannot update customer records or assign tasks. The dataset is bundled with the website, so this version is not how I would protect private customer data in a real deployment.

## What I changed after looking at the dashboard

I felt the earlier UI still looked like a small project. I wanted it to feel more like a tool someone could use regularly. I added a sidebar, a shared top bar and filters.

I did not like filtering and then making several selections before seeing useful comparisons of vehicle models, branches, representatives and lead sources. Now each opens results straight away from the sidebar.

I added matching icons across pages so someone can recognise leads, deliveries, targets and follow-up before reading every label. I kept the words beside them because an icon alone can be unclear. An icon identifies the type of information; the status label explains whether it needs attention.

I put the six overview cards in one row on desktop so the important findings appear sooner. On smaller screens they wrap instead of making the text tiny or forcing sideways scrolling. The snapshot date stays in a small footer, and the metric explanations are still available from the info buttons.

Summary cards open their records or target breakdown. Supporting records and the selected customer's details share one dialog, with side-by-side panels on wide screens. I wanted it to be obvious which row produced the details. Filters also stay in the URL so refreshing or sharing a view does not lose the selected scope.

## The numbers needed to be fair

An active opportunity is still being worked on, so I did not count it as a loss.
Resolved conversion is:

`delivered / (delivered + lost)`

For example, 10 delivered, 10 lost and 5 active gives 50% resolved conversion, with the 5 active opportunities shown separately. The percentage needs that context.

I used status history to work out which stages a lead reached and how long the transitions took. Missing steps are not filled in with guesses. Questionable records stay visible through data-quality warnings instead of silently changing the source data.

Newer leads have had less time to finish. The app labels recent groups as immature using an observation window based on completed sales cycles. A low rate in one of those groups is not automatically proof of bad performance.

Age and overdue calculations use the dataset's latest observed business date, which is 31 December 2025 for this file. Opening it months later should not change the historical results just because today's date is different.

## Targets and value have some limits

I compare delivered units with the supplied targets for the same branch and month. A lead received in November but delivered in December belongs to November's lead group and December's delivery output. Those views answer different questions.

The dataset does not supply individual representative targets, so I did not divide branch targets between people. Partial months keep their full monthly target and are labelled. I also show a warning that the supplied extract may not cover all the business behind the targets; a large gap needs that check before judging it.

I used “value” without a currency symbol because the data does not establish the currency. I did not call deal value profit or confirmed revenue. For that reason, I focused target reporting on units rather than inventing a revenue comparison.

## Why the findings use rules

I used rules based on the calculated results instead of calling an AI model each time the dashboard opens. This lets a finding point to the exact records behind it, and makes it possible to test whether it is correct.

The limitation is that the app only finds patterns covered by those rules. Its suggestions are things to investigate, not proof of what caused a problem.

I used AI tools while building and improving the project. That is separate from the app itself: the dashboard's numbers and findings come from Dart calculations, not AI-generated answers.

## Patterns I noticed in the supplied data

These are from the unfiltered dataset at its 31 December 2025 snapshot. I checked them using the project's `dart run tool/print_insights.dart` command.

- **Lakeside Toyota has 8.0% resolved conversion, compared with 35.7% across the network.** I would start by comparing its stage progression, loss reasons and follow-up records, rather than assuming the team is the cause.
- **30 active orders are past their expected close date.** This gives a manager a specific list to review for updated status and expected dates. They are still active orders, not losses or confirmed late deliveries.
- **67.7% of recorded losses happen before test drive.** This makes early contact and qualification worth investigating, although the figure alone cannot explain why the customers were lost.
- **15 active records have had no activity for at least 60 days.** Some may be long-running sales and others may need a status update. I would check them before deciding they are no longer valid opportunities.

These figures are examples from the current data. They are calculated by the app, not hard-coded findings that would stay the same for another dataset.

## What I would do next

First, I would let a dealership manager use it and see which parts are confusing or take too many clicks. I would simplify those before adding more charts.

For real daily use, I would add a controlled way to refresh data and track agreed follow-up actions. Connecting private CRM data would also need authentication and access controls.

I would also like to explore predictions, such as an estimated range of deliveries next month or which open opportunities may need earlier follow-up. Before adding that, I would need more reliable history and completed outcomes. I would start with a simple baseline and check its predictions against later records it had not seen. Estimates should show uncertainty, and an active opportunity should never be marked lost just because a model thinks it is unlikely to convert. The current extract is enough to explore the idea, but not to claim reliable forecasts.

Another idea is a chat assistant using a small AI model. A manager could ask "Which branch needs attention?" or "Show me overdue orders for this branch." The assistant would use the existing calculations and filters, explain the results in plain words, and link to supporting records. It should not invent numbers or calculate a different conversion rate. I would first check whether a small model can answer these questions accurately, along with its speed, cost and how customer data would be protected. If the data cannot answer a question, it should say so.

Neither predictions nor an AI chatbot is implemented in this version. These are future ideas and today's dashboard uses Dart calculations and rule-based findings.

For this version, I focused on understandable numbers, useful investigation paths, and a working Vercel deployment. The project has tests for calculations, filters, navigation and exports, along with responsive UI checks.

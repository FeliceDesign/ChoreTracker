# ChoreTracker — Weekly Planner + Time Tracking

Plan a realistic week and stop guessing how long chores take.

You define your fixed anchors (wake up, bed time, work hours, recurring
appointments). The weekly calendar then shows exactly **how many free minutes**
each day has. Separately, you track chores with a **stopwatch** — run "Empty the
dishwasher" a few times and the app learns its **average duration**. When you
schedule that chore into the week, it drops in as a **real block of its measured
length**, so your plan reflects reality and there's no more "there's no time"
excuse.

## Features

- **Setup tab** — per-weekday wake/bed times plus fixed appointments (work and
  custom), each recurring on chosen weekdays.
- **Week tab** — a 7-day overview of free time per day, plus a detailed timeline
  for the selected day showing fixed blocks, scheduled chores, and free gaps
  (with free minutes labelled).
- **Timers tab** — clock-app-style stopwatches per activity. Each run is saved;
  the running **average** and run count are shown.
- **Scheduling** — place an activity on one or more weekdays at a start time; the
  block length is the measured average (or a custom estimate). Tap a scheduled
  block to remove it or refresh its length to the current average.

Everything is stored locally on the device (SQLite). No account, no backend.

## Tech

- Flutter (Material 3), Dart
- [Riverpod](https://riverpod.dev) for state
- [sqflite](https://pub.dev/packages/sqflite) for local storage
- Core free-time logic is pure Dart (`lib/logic/free_time.dart`) and unit-tested.

## Project layout

```
lib/
  main.dart, app.dart          # entry point + bottom-nav shell
  data/                        # models, sqflite database, Riverpod providers
  logic/                       # pure logic: free_time, time_utils, palette
  features/week|timers|setup/  # the three screens
test/                          # unit tests for the pure logic
.github/workflows/build-apk.yml
```

The Android platform folder (`android/`) is **not committed**. It is generated on
demand — both in CI and locally — so the repo stays limited to source.

## Building the APK

### In CI (automatic)

Every push triggers `.github/workflows/build-apk.yml`, which:

1. Sets up Java 17 + Flutter (stable),
2. Runs `flutter create --platforms=android .` to generate the Android project,
   then restores the committed Dart sources,
3. Runs analyze + tests,
4. Builds `flutter build apk --release --split-per-abi`,
5. Uploads the APKs as a workflow **artifact** named `choretracker-apk`.

Download the APK from the workflow run's *Artifacts* section and sideload it
(the release APK is unsigned/debug-signed — fine for personal installs; enable
"Install unknown apps" on the device).

### Locally

```bash
flutter create --platforms=android --org com.felicedesign --project-name choretracker .
git checkout -- .            # restore committed sources over the template
flutter pub get
flutter run                  # or: flutter build apk --release
flutter test                 # run the unit tests
```

## Scope (v1)

A recurring "typical week" model — appointments and chores repeat weekly by
weekday. No specific calendar dates, cloud sync, accounts, or notifications yet.

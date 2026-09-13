# Roadmap

**This file is the single source of truth for status**, updated in the same
commit as the work it describes. If it says something is done, it is done on a
device — not "the code is written".

Last updated: 2026-09-13

## Phase 0 — The app exists ⏳ in progress

- [x] Trip, plan, place and essential models, obeying CloudKit's schema rules
      even though version one does not sync
- [x] Today, Itinerary, Places, Essentials — all four screens, with adding,
      editing and deleting
- [x] First-run trip setup
- [ ] **A green build.** Not yet run anywhere; there is no repository on GitHub
      at the time of writing, so CI has never seen this
- [ ] **Seen by a human eye.** Nothing here has been on a screen

## Phase 1 — On a phone ⬜

- [ ] Signed in Xcode and run on a real iPhone
- [ ] An app icon. **Required for TestFlight** — a build without one is rejected
      before review
- [ ] The Rome trip's actual content typed in, which is the first honest test of
      whether the screens are the right ones

## Phase 2 — TestFlight ⬜

- [ ] App ID `com.wpv.veya` in the Developer portal — **does not exist**
- [ ] An App Store Connect record for VEYA — **does not exist**
- [ ] Archive uploaded from Xcode
- [ ] Beta App Review, for external testers. Internal testers need no review;
      external ones do, and it is usually under a day
- [ ] Beta test information: what to test, a description, a feedback email

**Done means:** somebody who is not Dave has it on their phone.

## What version one deliberately leaves out

**The map.** `first-app.md` promises offline map data. **MapKit does not do
this** — it fetches tiles over the network and offers no download. The options
are a third-party map (a dependency, so a decision record), pre-rendered images
of the few areas that matter, or no map. For a family trip this is a real gap
and it is not a schedule problem: it cannot be built as specified.

**Family sharing.** "Everyone sees the same trip" needs CloudKit sharing, which
is unbuilt, and the foundation's `0020` leaves undecided what happens to a shared
record when its owner deletes their account. Until then each person has their own
copy. For one trip that is workable — one person keeps it, the others read theirs
— but it is not what the spec promises.

**Voice notes and photos.** `PPInput` has seams and fakes; nothing behind them
talks to a microphone or camera yet. Typing works.

**Sync between your own devices.** The store is `.thisDeviceOnly`. The foundation's
CloudKit provider exists and **has never run on a device**; turning it on is one
line and it waits until somebody has watched it work. The models already obey
CloudKit's schema rules so that switch is not a migration.

## Known blockers

| Blocker | Blocks | Status |
|---|---|---|
| No GitHub repository | Everything — this is uncommitted work on one machine | Waiting on Dave |
| No App ID, no App Store Connect record | Phase 2 | Waiting on Dave |
| No app icon | TestFlight | Needed before upload |
| MapKit has no offline tiles | The map | Not solvable as specified |

# Roadmap

**This file is the single source of truth for status**, updated in the same
commit as the work it describes. If it says something is done, it is done on a
device — not "the code is written".

Last updated: 2026-09-13 · **Croatia departs Tuesday 22 September.**

## Phase 0 — It builds ✅ done

- [x] Xcode project generated from `project.yml`, green on CI against the
      foundation at `0.1.0`
- [x] An app icon, so a build can reach TestFlight at all

## Phase 1 — Nine people, one trip ⏳ in progress

- [x] Supabase schema with row level security — `supabase/0001_init.sql`, applied
- [x] Sign in with Apple, token kept in the Keychain
- [x] Trips: list, create, **archive rather than delete** — a finished trip stays
      readable and stops sitting beside the one being planned
- [x] Itinerary: day by day, add, mark done, skip, delete
- [x] Stays and the booking checklist
- [x] Re-reads every twenty seconds, so somebody else's change appears
- [ ] **Offline reads — see below. This is the most important unbuilt thing.**
- [ ] Inviting other people to a trip. **Nothing yet lets a second person join**,
      which means the sharing this app exists for is untested by more than one
      account
- [ ] Expenses, splits and settle-up

> ⚠️ **Nothing in this app has been run by anyone.** It compiles on CI, which is
> a different claim. There is no Mac and no simulator in the environment it is
> written in, and the network policy there blocks Supabase, so neither the
> screens nor a single API call has been executed. The first run will be on
> Dave's phone.

## The offline problem, stated plainly

`AGENTS.md` says every screen works in airplane mode and that a feature which
cannot is not shipped. **Today no screen does.** Every read goes to Supabase, so
a phone with no signal shows nothing at all — on a trip through Croatian
villages, on foreign roaming, which is the exact situation this app exists for.

The fix is a local cache: keep the last-known trip on the device, read from it
first, and treat the network as the thing that refreshes it. Writes can stay
online-only for version one and say so. That is the next piece of work and it
outranks expenses.

## Phase 2 — TestFlight ⬜

- [ ] App ID `com.wpv.veya` with Sign in with Apple — **does not exist yet**
- [ ] Supabase → Auth → Providers → Apple, client ID `com.wpv.veya`
- [ ] An App Store Connect record
- [ ] Archive uploaded from Dave's Mac
- [ ] Beta App Review — external testers need it, internal ones do not
- [ ] Nine people install it, with **Automatic Updates** switched on in TestFlight
      so later builds arrive without being chased

## What version one deliberately leaves out

**The map.** MapKit has no offline tiles, and a map that needs a connection is
not a travel map. Options are a third-party map (a dependency, so a decision
record), pre-rendered images, or none. None, for now.

**Photos, receipts and the travel log.** All three are in the product spec and
none is on the path to a family using this in Croatia.

## Known blockers

| Blocker | Blocks | Status |
|---|---|---|
| No App ID, no App Store Connect record | TestFlight | Waiting on Dave |
| Apple not yet enabled in Supabase Auth | Signing in at all | Waiting on Dave |
| Nothing works offline | The trip itself | Next piece of work |
| Nobody can be invited to a trip yet | The whole point of the app | Not started |

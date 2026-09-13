# VEYA

A travel companion for a family trip, native on the
[Plug and Play](https://github.com/davidcblake/plug-and-play-ios) foundation.

Everyone on a trip sees the same itinerary. One person adds a restaurant and it
appears on eight other phones.

## Build it

```bash
brew install xcodegen
xcodegen generate
open VEYA.xcodeproj
```

Signing is off in `project.yml` so CI can build without certificates. Turn it on
in Xcode (Signing & Capabilities → your team) before running on a device or
archiving for TestFlight.

## Where the data lives

Supabase — Postgres with row level security, and Sign in with Apple. The schema
is `supabase/0001_init.sql` and every policy asks the same question: are you a
member of this trip.

**Not CloudKit**, for a reason worth knowing: SwiftData cannot do CloudKit
sharing at all. `CKShare` lives in `NSPersistentCloudKitContainer`, which
SwiftData does not expose, so a trip shared between nine people is not something
the foundation's own sync can do today.

The anon key is in `project.yml` on purpose. It names the project, not a person;
the policies are what protect the data.

## What version one leaves out

The map, photos, receipts, and the travel log. See
[docs/roadmap.md](docs/roadmap.md) — including the one that matters most, which
is that **nothing works offline yet.**

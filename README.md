# VEYA

A travel companion for a family trip, native on the
[Plug and Play](https://github.com/davidcblake/plug-and-play-ios) foundation.

**It makes no network calls at all.** Not "works offline with a cache" — there
is nothing in it that asks a server anything. That is the point: the moment you
most need to know which train, which street, what time the tickets are for, is
exactly the moment the phone says no internet.

## Build it

```bash
brew install xcodegen
xcodegen generate
open VEYA.xcodeproj
```

Signing is off in `project.yml` so CI can build without certificates. Turn it on
in Xcode (Signing & Capabilities → your team) before running on a device or
archiving for TestFlight.

## What's in version one

Trip overview, day-by-day itinerary, places with the reason they're on the list,
and essentials you can read out with no signal.

**Not in version one:** the map, family sharing, voice notes and photos. Why, and
what each would take, is in [docs/roadmap.md](docs/roadmap.md).

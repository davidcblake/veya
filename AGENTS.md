# VEYA — rules

**The foundation's rulebook applies here.** Read
[`plug-and-play-ios/AGENTS.md`](https://github.com/davidcblake/plug-and-play-ios/blob/main/AGENTS.md)
first. This file records only what is different because this is an app.

## The constraint that shapes everything

**It has to work with no signal.** Every screen works in airplane mode. If a
feature can't, it doesn't ship. The spec is
`plug-and-play-ios/docs/first-app.md`, and this rule is the whole reason the
travel app went first.

**Today the app does not keep this rule.** Every screen reads from Supabase over
the network, so with no signal there is nothing to show. That is a known,
recorded gap rather than a decision — see `docs/roadmap.md` — and closing it is
the highest-priority work in the repository. Nothing else should be built before
a trip that is readable with the phone in airplane mode.

The reason it was traded away is in `docs/decisions/0001`: nine people seeing one
live itinerary needs a backend, and offline reads are a local cache on top of it
rather than an alternative to it.

## What is different here

- **The foundation test does not apply.** That rule decides what belongs in
  `plug-and-play-ios`. Here the question is the opposite: *is this
  travel-specific, or should it be in the foundation so the other three apps get
  it too?* If the latter, it goes there, with the foundation test answered.
- **This app depends on a tagged version of the foundation**, never `main`.
- **There is no sign-in and no account.** One person, one phone, one trip.

## Two promises in the spec this app does not keep

Both are in `docs/roadmap.md` with the reasons. Neither is an oversight, and
neither should be quietly implemented badly to close the gap:

- **Offline maps.** MapKit does not do them. Doing it properly means a
  third-party dependency and a decision record.
- **Family sharing.** CloudKit sharing is unbuilt, and `0020` in the foundation
  leaves undecided what happens to a shared record when its owner deletes their
  account. That has to be settled before anything that shares ships.

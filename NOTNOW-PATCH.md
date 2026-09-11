# NotNow metadata execution patch

This checkout is based on TelemetryDeck SwiftSDK **2.14.2**, upstream revision
`58f436299d3f6710bcedc18aff26480aaf1879fc`. The owned integration repository is
[caspersimon/SwiftSDK](https://github.com/caspersimon/SwiftSDK). The upstream
[LICENSE](LICENSE) is retained unchanged, including its modified MIT notice.

## Purpose and scope

NotNow build 62 recorded a 109.594 ms main-thread stall inside
`SignalManager.processSignal`: its UI callback rebuilt all SDK metadata before
dispatching encoding/cache work to a background queue. An app-side worker did
not remove that SDK callback. Upstream 2.14.2 retains the same metadata path.

This patch makes `SignalManager` collect only UI-affine values and the current
default user identifier on main, then assemble metadata, enrich, hash and enqueue
on a serial utility queue. The public `DefaultSignalPayload.parameters` getter
keeps its synchronous MainActor API and full value contract; production signal
processing uses the split helpers instead.

Only the immutable device model identifier is cached. Both old and new model
keys reuse it. Locale, timezone, calendar, run context, appearance, accessibility,
screen values, user identity and session metrics are refreshed. The retained
session-date formatter has a dedicated lock because the public payload getter
and different managers may access it concurrently. Session-array safety remains
the upstream 2.14.2 snapshot/lock implementation; no lifecycle timer or session
state-machine changes are included.

The iOS signal identity read remains IDFV on main. On macOS the existing stored
identity getter still reads the SDK defaults suite on main; removing that cost
would require a separate synchronized read/create boundary and is outside this
measured iPhone repair. Session metadata defaults/suite hashing now runs on the
worker on all platforms.

The internal `SignalMetadata` value and optional cache injection support testing
the real process queue with isolated data. These are not public SDK APIs.
Identity hashing, parameter precedence, cache file/encoding, networking,
transmission retries and event schema retain the upstream implementations.

## Regression coverage

`SignalMetadataTests` covers a 32-event backlog through `processSignal`, actual
main/worker execution, later UI changes, default/custom identity hashing,
parameter precedence and session identity. Its full-payload comparison uses a
frozen, test-only 2.14.2 builder so it does not compare the new helpers to
themselves. An isolated defaults fixture verifies the UTC thirty-day cutoff,
retention of older history, updated day values and concurrent formatter reads.

Run the patch and relevant upstream regression suites with:

```sh
swift test --jobs 4 --filter 'SignalMetadataTests|SessionManagerConcurrencyTests|SignalManagerDispositionTests|SignalManagerBackoffTests|SignalManagerEncodeFailureTests|SignalCacheConcurrencyTests|SignalCacheLimitTests|CryptoHashingTests|DefaultSignalPayloadTests'
```

The local receipt records 49 passing tests on macOS with Swift 6.3.3. This does
not establish iPhone responsiveness. The integrating app must still compile its
iOS target and profile Release launch, scrolling through delayed telemetry
activation, and ordinary later signals with a populated backlog.

## Upstream return condition

Keep this delta limited to metadata ownership. Reassess an upstream release that
moves expensive metadata off-main while preserving existing cached events and
session/identity semantics. V3 beta.5 provides a promising processor architecture
but changes the cache filename/date encoding without migrating queued v2 events;
its session startup also rebuilds lifetime distinct-day history from retained
90-day sessions. Do not replace this pin with that beta without explicitly
resolving those migration differences and checking the required namespace.

No raw traces or user telemetry belong in this dependency repository.

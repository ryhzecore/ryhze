# Apple verification — 10 September 2026

Codemagic build `6aa1a44970915cdf0fff431b` finished successfully in 15m 25s using commit `66b246897ea00a35b5efe543aebab106f73082f6`.

Build: https://codemagic.io/app/6aa168715f5464a1c485054c/build/6aa1a44970915cdf0fff431b

Verified stages:

- Shared application validation.
- iPhone/iPad simulator compilation.
- Native XCTest screen suite, checked by the nonempty-test guard.
- Real Keychain session seed: `testRememberedSessionAcrossNativeProcessRestartSeed` passed; guard confirmed one native test.
- Separate-process session restoration and sign-out: `testRememberedSessionAcrossNativeProcessRestartRestore` passed; guard confirmed one native test.
- Unsigned iPhone release compilation.
- macOS release compilation.

The test setup now establishes enabled accessibility before Flutter records resource baselines. A local regression test reproduced delayed platform accessibility notifications and confirmed stable resource counts while preserving checks for test-owned handles. Simulator signing applies Keychain entitlements. Native XCTest avoids the previous Flutter debug-connection stalls; empty suites remain blocking.

This verifies the cloud simulator and compilation workflow. It does not establish physical iPhone playback/interaction validation, App Store distribution signing, TestFlight upload, or active Apple Developer membership. No TestFlight installation has been published.

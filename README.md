# FlightCore Control Platform

Current release candidate: FlightCore 4.3.0 RC16.

Canonical machine identity: `4.3.0-rc.16`.

RC16 prevents ground-state wind estimates from producing a false TURN HOME `NOW`. TURN HOME remains inactive while disarmed or on the ground, qualifies airborne motion and measured wind before use, and ramps measured-wind influence after takeoff. Genuine airborne infeasible-return conditions remain `NOW`, negative energy margins remain available, and the feature remains advisory only.

ARSP Health is now a selectable Ground Station telemetry value instead of a top-bar pill. Existing ARSP sensing, polling, health transitions, voice alerts, Smooth Voltage safeguards and flight-control behavior are unchanged.

RC16 also corrects native upgrade source verification: the ownership-aware live fingerprint remains mandatory, while the invalid comparison with an offline `--skip-ownership` digest is removed. Exact source build, status, manifest and controlled-file hashes remain enforced.

RC14 release discovery and installer-integrity behavior and RC15 SIYI cold-boot/stream-recovery behavior remain intact. Existing systems upgrade only through the read-only Registry-frozen native routes. Fresh installation uses the public one-touch installer without a separate user preflight.

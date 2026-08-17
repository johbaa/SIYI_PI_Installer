# FlightCore Control Platform

Current release candidate: FlightCore 4.3.0 RC17.

Canonical machine identity: `4.3.0-rc.17`.

RC17 repairs the confirmed RC13-to-RC16 native-upgrade failure at the final ownership-aware validation stage. Mandatory preservation now restores the saved UID/GID with `lchown` for every preserved top-level symbolic link before final validation. The correction is generic; `/etc/siyi/joystick.json` exposed the defect but is not special-cased.

This rebuilt RC17 also adds complete, analysis-grade TURN HOME flight logging without changing TURN HOME calculations or advisory behavior. The 2 Hz flight record now captures every scalar calculation input, threshold, intermediate projection and output; actual consumed mAh; Home and aircraft geometry; voltage- and capacity-limited margins; measured and forecast wind qualification; forecast metadata; and negative overdue/emergency projections. Each provider refresh is preserved once as a deduplicated forecast-input event.

CSV export now includes every recorded sample field and stamps every row with the exact FlightCore product version, release identity, RC, build ID, source commit, release status and installed payload-manifest SHA-256.

The strict ownership-aware release fingerprint remains mandatory. Exact source identity, build, accepted status, manifest and controlled-file hashes remain enforced.

All RC16 functionality is retained unchanged. Other than the expanded forensic evidence contract, RC17 changes no UI, TURN HOME calculation/countdown behavior, settings schema, defaults, networking, LTE Health, Smooth Voltage, ARSP, SIYI stream behavior, public fresh-install command or flight-control authority.

By explicit product-owner authorization, RC17 reuses the unchanged RC16 compatibility matrix—RC6/V71, RC12, RC13 and genuine fresh installation—and performs no additional Registry freeze or final Registry recheck until a physical RC17 upgrade succeeds.

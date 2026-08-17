# FlightCore Control Platform

Current release candidate: FlightCore 4.3.0 RC15.

Canonical machine identity: `4.3.0-rc.15`.

RC15 corrects SIYI cold-boot and stream recovery. FlightCore now maintains one physical SIYI RTSP-over-TCP ingest, waits for the dedicated Ethernet route and camera RTSP readiness before enabling it, exposes source-health and epoch evidence, and rebuilds only the SIYI browser decoder session after a source epoch change or decoded-frame stall.

MediaMTX and Air Link remain available while the SIYI camera is unavailable. Air Link is isolated from SIYI recovery.

RC15 otherwise retains the accepted RC14 updater behavior and RC13 flight features, settings lifecycle, TURN HOME, Smooth Voltage, LTE Health and flight-log evidence.

Existing systems upgrade only through the read-only Registry-frozen native routes. Fresh installation uses the public one-touch installer without a separate user preflight.

# FlightCore Control Platform

Current release candidate: FlightCore 4.3.0 RC13.

Canonical machine identity: `4.3.0-rc.13`.

RC13 corrects fresh-SD ZeroTier dependency handling and First Setup local/cloud completion, restores FlightCore branding, permits signed overdue TURN HOME values, and expands Smooth Voltage, TURN HOME, measured-wind and forecast-wind flight-log evidence.

RC13 also makes preservation mandatory for every registered user configuration domain, adds schema-aware migrations and safe fresh-install defaults, scopes browser preferences by permanent Unit ID, removes assumed Air Link credentials, and separates runtime state from persistent configuration.

Existing systems upgrade only through the read-only Registry-frozen native routes. Fresh installation uses the public one-touch installer without a separate user preflight.

# FlightCore 4.4.0 RC35

RC35 replaces RC34 after the RC33→RC34 preflight correctly refused an incorrect source fingerprint. RC34 had pinned an ownership-skipped offline digest, while the installed ownership-aware verifier produced a different canonical value after every file, mode, owner, version, build and transaction check passed. No RC34 upgrade was started. RC34 is consumed and non-promotable.

RC35 corrects that failed packaging path:

- the exact ownership-aware RC33 fingerprint observed after successful live verification is pinned;
- an offline manifest-ownership mode now reproduces live canonical owner/group semantics and prevents `--skip-ownership` output from being accepted as a live pin;
- the RC34 SIYI mechanically-forward device-to-optical correction is retained unchanged;
- yawing the aircraft right moves **H** left, yawing left moves **H** right, and a 180-degree yaw places **H** at bottom-centre;
- the correction is tested against the exact heading/quaternion samples captured from the RC33 test unit;
- the no-GPS bench test and armed live Home use the same final projection;
- the fixed Airlink camera path is unchanged and receives no SIYI basis correction;
- arming immediately erases simulated Home, and the feature remains presentation-only.

This repository must contain exactly five files:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.35.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.35.sha256`

The public `install.sh` is the self-contained bootstrap and must be byte-identical to `public-install.sh` inside the immutable archive. The internal payload installer is not a public bootstrap.

RC35 supports exact installed RC33 as its primary recovery source, retained exact RC32, RC31, RC30, RC28 and RC26 recovery, exact accepted RC24, represented historical routes and genuine fresh installation. Modified and unknown sources fail closed.

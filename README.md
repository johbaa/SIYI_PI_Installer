# FlightCore 4.3.0 RC40

Immutable candidate `4.3.0-rc.40` / `20260825.075053-0c96995`.

This directory intentionally contains exactly five files. The canonical public install.sh is the self-contained manifest/hash-pinned bootstrap; it downloads and verifies the selected release archive before invoking the internal package installer with all companion files present.

RC40 supersedes the failed RC39 publication without mutating it. It carries forward the RC39 MediaMTX H.265 correction and Turning distance telemetry while repairing the official native-upgrade and fresh-install bootstrap. RC18 remains the last proven-good in-flight Air Link baseline; RC19 is not declared the first bad version.

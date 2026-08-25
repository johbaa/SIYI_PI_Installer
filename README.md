# FlightCore 4.3.0 RC41

Immutable candidate `4.3.0-rc.41` / `20260825.082059-3face99`.

This directory intentionally contains exactly five files. The canonical public install.sh is the self-contained manifest/hash-pinned bootstrap; it downloads and verifies the selected release archive before invoking the internal package installer with all companion files present.

RC41 supersedes published but rejected RC40 without mutating it. RC40 repaired RC39's public bootstrap but its inner installer rejected exact RC38 after normalizing 4.3.0-rc.38 to 4.3.0. RC41 corrects that route predicate, retains exact hash/fingerprint pins, and carries the RC39/RC40 runtime unchanged. RC18 remains the last proven-good in-flight Air Link baseline; RC19 is not declared the first bad version.

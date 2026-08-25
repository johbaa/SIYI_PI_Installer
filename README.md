# FlightCore 4.3.0 RC39

Immutable candidate `4.3.0-rc.39` / `20260825.030539-fd21ca6`.

This public directory intentionally contains exactly five files. Verify `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.3.0-rc.39.sha256`, then use the resumable `install.sh`.

RC39 preserves RC38's Ground Station lifecycle and RC37's integrated unit rendering. It keeps the existing MediaMTX v1.12.2 topology while applying the upstream H.265 aggregation-header correction to exact gortsplib v4.14.0, adds rate-limited exact packet-processing evidence, and deploys a deterministic checksum-pinned embedded ARM64 media binary. It also adds the Navigation telemetry item Turning distance by exposing the existing wind-aware TURN HOME direct-distance result without another solver or polling loop. RC18 is the last proven-good in-flight baseline; RC19 is not declared the first bad version.

Exact accepted RC38, retained RC36, Registry-required RC6 and clean historical upgrade routes are checksum-pinned; genuine fresh installation remains supported. Physical Android dual-stream and controlled-flight acceptance remain required.

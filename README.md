# FlightCore 4.4.0 RC26

FlightCore 4.4.0 RC26 delivers the approved DJI-style Home marker in the Ground Station primary views while extending the existing round-HUD house through one shared Home solution. In view, the marker is a 40 px green circle with a 3 px white ring, bold white Arial `H` and dark shadow. Outside the field of view it changes to darker teal, adds a white outward pointer and follows the true relative direction around the screen edge.

The camera projection performs a full 3D transform from NED through current aircraft attitude and live SIYI gimbal yaw, pitch and roll, so the `H` remains accurate while the aircraft or gimbal moves. One same-origin Server-Sent Events connection reads only the established local tmpfs gimbal snapshot at no more than 10 Hz while Ground Station is open. Compositor transitions smooth the visual motion without a permanent animation loop. It requests no additional MAVLink stream, sends no gimbal or flight command, and changes no logging, modem, video, Cloud or radio cadence. Missing or stale required data hides both presentations. **Settings → General → Show Home marker** stores the persistent on/off choice and defaults to on.

The public repository must contain exactly these five files:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.26.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.26.sha256`

Approved upgrade parent: exact accepted `4.4.0-rc.24`, build `20260905.212756-93deeb4`, canonical fingerprint `cbcc90135df04542faa2ec5eb6fe3feb0558d904c13f910fad81262704f8e761`. RC24 passed physical upgrade and genuine fresh-install validation.

RC25 was rejected before publication or installation because its one-second gimbal polling could not meet the smooth-motion requirement. RC25 is consumed and is not an authorized source.

Operator order:

1. Run the RC26 publisher.
2. Run the independent RC26 publication verifier.
3. Run the RC24-to-RC26 read-only upgrade preflight.
4. Only after PASS, install RC26 from the FlightCore Software Update page.
5. Run the post-upgrade check and complete physical acceptance.

Do not power off the Raspberry Pi during installation or post-reboot verification.

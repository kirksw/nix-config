# XENEON touch support

Experimental source-built package pinned to upstream revision `9a6823fe3f55448bd0ac233531dc6d73fbff19c5`.
The package is exposed through the repository's automatic package discovery.
It is not enabled at login or added to the host's default applications yet.

Local patches require exact USB IDs (default `0x27c0:0x0859`) and the display name `XENEON EDGE`.
No unrelated external display is selected as fallback.
Exclusive HID access is disabled because native handling is required when the pointer is already on the EDGE.
Display changes and device removals clear cached touch state.

The upstream global mouse suppression mechanism remains a limitation: simultaneous mouse clicks can be dropped during touch takeover.
This is not a full multitouch driver and does not promise dragging or gestures across displays.
Grant Accessibility and Input Monitoring only to the built app, not to a terminal running an arbitrary executable.
Quit the app through its XE menu to disable the workaround.

## Physical acceptance checks

- With the pointer on the ROG, tap harmless targets at each corner and the center of the EDGE.
- Repeat with the pointer already on the EDGE.
- Hold a stationary touch for one second before releasing; check for exactly one click.
- Try dragging and simultaneous mouse use; confirm no unintended actions on the ROG.
- Disconnect EDGE video while leaving USB attached; confirm no touches are redirected to the ROG.
- Reconnect and verify mapping again.

Do not enable startup until these checks pass.

# S-013 architecture check

OverlayController is 564 lines and already owns rendering, drawing input, capture and toolbar state. Adding radial hierarchy and tap ownership there would make press pairing difficult to test.

## Radial session and input ownership, Strong

Add a pure RadialSession for fixed geometry, paging, arming, backtracking and commit resolution. RadialMenu owns only the nonactivating panel and native accessible buttons. RadialInput owns modifier gesture lifecycle and paired input suppression, called by the existing InputTap before annotation routing. Its main-queue notifications preserve event order. OverlayController supplies eligibility and coordinates the panel, without a second event tap. Commands return through ControlBridge's validated app actions.

An alternative separate global monitor cannot prevent underlying clicks. A second tap would split press/release ownership. Keeping all radial state in OverlayController would spread geometry and thread rules across unrelated paths. The selected modules keep those rules local and provide pure state and real native-input test seams.

Scope: new radial files and narrow integration points only. No general refactor, Swift language migration, commits or hosted CI. Existing unit/routing/native fixture evidence is the baseline; preserve prior evidence bytes and real user data. The user explicitly authorized this separation and no additional architecture approval is needed.

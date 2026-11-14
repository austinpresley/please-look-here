# TinyHand public fork update, 14 November 2026

Verified through **2026-11-14 09:15:17 UTC**. Compared with the 9 November census at 07:16:08 UTC in [the original evidence](tinyhand-fork-evidence.md) and [ranking data](tinyhand-ranking-data.json). This is a static source audit for the current Mac app, including its uncommitted changes.

The best additions to investigate are audio recovery during screen sharing, safe shutdown on lock/sleep, and full-screen Space recovery. The first two are now upstream. The strongest newly found fork changes are activation-time Space rejoining, idle motion-timer sleep and optional shape recognition. These are research recommendations, not changes to the authorized backlog.

## Coverage and delta

| Measure | 9 November | 14 November |
| --- | ---: | ---: |
| Public forks | 42 | 73 |
| Fork branches | 56 | 107 |
| Upstream branches | 1 | 1 |
| Fork repositories with non-upstream SHAs | 16 | 31, including our own fork and one upstream-equivalent-only fork |
| Distinct reachable non-upstream SHAs | 111 | 257 |
| Newly observed non-upstream SHAs | | 147 |
| New upstream commits | | 10 |

Both GitHub metadata counts are 73, matching recursive enumeration. Queried every page of all **74 forks endpoints** and all **74 branch collections**, including non-default branches. Initial collection used 222 API calls. Independent `git ls-remote --heads` checks matched all **108 final tips**. All **305 distinct reachable commits** have local objects; `git fsck --connectivity-only` passed. The durable [watch state](tinyhand-fork-watch-state.json) includes every repository ID, branch tip, complete per-branch reachable SHA list, dates, ancestry and patch coverage. Primary census sources: [root metadata](https://api.github.com/repos/nilbuild/tinyhand), [root fork listing](https://api.github.com/repos/nilbuild/tinyhand/forks?per_page=100&page=1), [upstream branches](https://api.github.com/repos/nilbuild/tinyhand/branches?per_page=100&page=1).

There are **32 actual new repositories**, all created after the baseline, versus **33 literal name additions**. `esreverse/tinypointer` redirects to `esreverse/quitehandy`, numeric repository ID **1450507584**, and retains its old commit history. It is an existing donor. `wajahat-alip/tinyhand` is absent and its API returns 404; deletion, privacy and an unredirected transfer cannot be distinguished. Thus the net increase is 31. Sources: [old-name API redirect](https://api.github.com/repos/esreverse/tinypointer), [current identity](https://api.github.com/repos/esreverse/quitehandy), [unavailable baseline repository](https://api.github.com/repos/wajahat-alip/tinyhand).

One current fork-of-fork exists: `fduarte42/tinyhand` has parent `AbdulRehman56/tinyhand` and source `nilbuild/tinyhand`. Its 18 unique branch-union SHAs include 16 inherited from its parent and two additional performance patches. Do not count those inherited changes twice. Source: [child metadata](https://api.github.com/repos/fduarte42/tinyhand).

After normalizing the rename, 52 branch names were added, one disappeared with the unavailable repository, seven existing tips changed and 48 stayed unchanged. Current fork tips comprise 50 ahead, 19 identical and 38 behind-only. Two ahead branches have unrelated root histories and contain only example images: CatalystMonish's `pr-screenshots` and xynova's `pr-images/gestures`. They are included in SHA coverage and excluded from code-feature counts.

GitHub changed while this audit ran. `Ayas4y/main` advanced from [ab6355eb76da](https://github.com/Ayas4y/tinyhand/commit/ab6355eb76dae4b4c232132a81474ad0f9a3b171) to [90f3d2fd2955](https://github.com/Ayas4y/tinyhand/commit/90f3d2fd29559d1869fd7c2eae1e2202d46e2bf6) at 09:13 UTC. The added commit changes update-feed documentation only. It was fetched and counted, then all 108 heads and the recursive census were checked again. Both observations are retained.

## Dates and deduplication

"Newly observed" means absent from the preserved 111-SHA baseline, not necessarily authored or first published after 9 November. **43 of the 147 have earlier authored dates; 42 also have earlier committer dates.** Most are tumaranja's tap-motion history, which was not reachable from its baseline `main`. Its 48 newly observed SHAs are not 48 newly written features. The rewritten alcibiadesc toolbar commit [16b1c1850865](https://github.com/alcibiadesc/tinyhand/commit/16b1c18508657c3360fc3e41932491e1e836d545) preserves a 7 November authored date but has a 10 November committer date. The snapshot keeps both dates and audit observation times separately.

The current 257 non-upstream SHAs contain seven merges, leaving 250 patch-bearing commits and **247 distinct stable patch IDs**. The 147 newly observed SHAs contain four merges and **141 distinct patch IDs**. One exactly matches upstream, leaving **140 new patch IDs after exact upstream/baseline overlap**. These include documentation, assets, platform ports, our branding and rewritten histories, not 140 user features.

- ulentini [01d7b76e771f](https://github.com/ulentini/tinyhand/commit/01d7b76e771f8bcb3ec4caa5fe3353a205e6d2de) has the same stable patch ID as upstream [ca1550d948b4](https://github.com/nilbuild/tinyhand/commit/ca1550d948b43c89e893d9b2a90af67c70bce314). Credit the donor, evaluate the upstream fix once.
- CatalystMonish/Arisaya ShapeKit commits [71b675d4ca1b](https://github.com/CatalystMonish/tinyhand/commit/71b675d4ca1bfddd451f5e0a5a107bd883b7a4a2) / [cba9c5c271b9](https://github.com/Arisaya1/tinyhand/commit/cba9c5c271b90be801cb1218eaf0173435b93de4) are patch-equivalent. So are their Windows-port commits [ed06b4f015b1](https://github.com/CatalystMonish/tinyhand/commit/ed06b4f015b10cd148e78d79ae41ee256bc615cc) / [ec967f992430](https://github.com/Arisaya1/tinyhand/commit/ec967f992430059d10a38fff1b68c5a28b0d7381). Arisaya does not add the Mac recognizer wiring.
- alcibiadesc's new two-commit toolbar tip [75121410ec7b](https://github.com/alcibiadesc/tinyhand/commit/75121410ec7bece5c19a91982e5d8c589370c6d4) and upstream's squash [673003672c76](https://github.com/nilbuild/tinyhand/commit/673003672c7696198a7915fcf1f69d6ecb7fc704) have the identical **entire tree** `012805b0d8cf46cd2809a754f3d518c62b39f014`. Single-commit patch IDs miss this cumulative equivalence. The old toolbar SHA `c161c8b4bbda56990972e6f3032a3639ddae3028` is no longer reachable from a current fork branch; it remains in historical coverage.
- The original AbdulRehman56 duplicate patch pair remains deduplicated. All other cross-repository shared SHAs are the 16 inherited parent/child commits described above. No baseline non-upstream SHA has become upstream-reachable by exact SHA.

## New donor repositories

Counts below are repository-level newly observed SHA unions across all branches, so they do not sum to the network SHA total when histories are inherited or patches repeated.

| Newly created repository | New SHAs | Source-verified change and current fit |
| --- | ---: | --- |
| [jorgenbruntveit/tinyhand](https://github.com/jorgenbruntveit/tinyhand) | 2 | [Activation-time Space rejoin](https://github.com/jorgenbruntveit/tinyhand/commit/bb3cc6d3f3202e9337b0f29ebc25325edfc247ae) and [ink erasing from the stroke start](https://github.com/jorgenbruntveit/tinyhand/commit/f42633c68521a5aabf3ed364d3d24472acace00d). Both add behavior missing locally. |
| [trussosw/tinyhand](https://github.com/trussosw/tinyhand) | 4 | [Idle timer sleep](https://github.com/trussosw/tinyhand/commit/491831508c062b125186ae1c111f775ff86781ab); quick ring; pen/ink controls; native left-click plus right-drag drawing and click ripple. Our radial menu, pen controls and Interact already cover much of this. |
| [CatalystMonish/tinyhand](https://github.com/CatalystMonish/tinyhand) | 6 | Shared C recognizer plus [Mac stroke snapping](https://github.com/CatalystMonish/tinyhand/commit/d2db2444805f92a5d13654bfbd3029176ea10a36), a Windows port, images and upstream merge. The Mac recognizer wiring is real despite the branch name. |
| [xynova/tinyhand](https://github.com/xynova/tinyhand) | 5 | [Gesture artwork catalog and Line art hand](https://github.com/xynova/tinyhand/commit/c7bbac616dde0decf97f3522445646a390bcdaf7); four image-only commits. Optional custom-hand poses and hover previews are later ideas; its fixed gesture shortcuts conflict with S-015's user-assigned rule. |
| [Ayas4y/tinyhand](https://github.com/Ayas4y/tinyhand) | 2 | [Rust rewrite](https://github.com/Ayas4y/tinyhand/commit/ab6355eb76dae4b4c232132a81474ad0f9a3b171) and update-feed documentation. The target selects a real [Mac renderer](https://github.com/Ayas4y/tinyhand/blob/ab6355eb76dae4b4c232132a81474ad0f9a3b171/src/macos/render.rs) and native input backend, plus Windows. Large replacement, little reason to replace the current Swift integration. |
| [gitrandynow/tinyhand](https://github.com/gitrandynow/tinyhand) | 1 | [Removes Sparkle](https://github.com/gitrandynow/tinyhand/commit/e3c168d7131d3f76b1d7004657e8b9658bfe9094) and its controls/packaging. Updater removal was not selected in INTEGRATION.md. |
| [ulentini/tinyhand](https://github.com/ulentini/tinyhand) | 1 | Audio freeze fix, now exact patch-equivalent to upstream. Separate upstream-equivalent-only category, not a seventh new fork-only Mac donor. |

The other **six new divergent repositories are platform-only**: [Arisaya1/tinyhand](https://github.com/Arisaya1/tinyhand), [fduarte42/tinyhand](https://github.com/fduarte42/tinyhand), [guidomariadifiore/tinyhand-windows](https://github.com/guidomariadifiore/tinyhand-windows), [lithium91/tinyhand](https://github.com/lithium91/tinyhand), [n0stalgia-mac/tinyhand](https://github.com/n0stalgia-mac/tinyhand), [pietro-santoro/tinyhand](https://github.com/pietro-santoro/tinyhand). They respectively add Windows, GNOME performance, Windows C++, Linux GTK, classic System 6/PowerPC, and Windows WPF work when read in the order listed. `n0stalgia-mac` targets classic Mac hardware/toolchains, not the current macOS app. Arisaya inherits equivalent ShapeKit C code but does not wire it into the native Mac target. No modern Mac feature is credited for those branches.

## Existing repositories with newly observed commits

| Existing repository | New SHAs | Actual delta |
| --- | ---: | --- |
| [esreverse/quitehandy](https://github.com/esreverse/quitehandy), formerly TinyPointer | 16 | [Current source](https://github.com/esreverse/quitehandy/blob/121d9d4edd12a05e8bdc46fc7adf0eae0420fd9c/Sources/QuiteHandy/Whiteboard.swift) adds multiple movable/resizable light/dark whiteboards, board PNG save/copy and shared board/ink history. Other changes add flashlight mode, loupe adjustment gestures and stamp/history improvements. Plain Spotlight and undo/redo are already local; whiteboards and live magnification are additional product scope. |
| [rjiang-bb/aihand](https://github.com/rjiang-bb/aihand) | 21 | Worktree/branch sessions, SSH, richer chat and diff viewers dominate the delta. [Drawing hover preservation](https://github.com/rjiang-bb/aihand/blob/ae77ac64bd366a39a6795649cb54074991b63082/Sources/AiHand/DrawingPointerPark.swift) is independently relevant. The agent/session system remains outside the selected app scope. |
| [omiusgm/playpointer](https://github.com/omiusgm/playpointer) | 2 | One Windows audio/laser patch and [custom-pointer creation/import guidance](https://github.com/omiusgm/playpointer/commit/6895f5b964f45a49b5f3d85ab7f8997bd149497e), plus a quick size popup. Current HandMaker and pointer library already implement custom import; consider its guidance only if a local usability gap is confirmed. |
| [alcibiadesc/tinyhand](https://github.com/alcibiadesc/tinyhand) | 2 | Rewritten toolbar patch and control relocation, cumulatively already upstream and already covered by local S-016. Other quiet-stroke/Shift branches did not advance. |
| [tumaranja/tinyhand](https://github.com/tumaranja/tinyhand) | 48 | Newly reachable old tap-motion/prototype history, later slider work and upstream merge. [Current swing implementation](https://github.com/tumaranja/tinyhand/commit/b21dc52a6d6646f9608f81bea1e4c271bb1f3cff) offers Off through 2x range, wind-up/strike/settle phases, delayed contact sound and immediate drag contact. Relevant to exploratory S-014, not a motion-follow slider for S-011. |
| [AbdulRehman56/tinyhand](https://github.com/AbdulRehman56/tinyhand) | 5 | GNOME toolkit, GTK teardown and Linux packaging only. The child shares all five newly observed commits. |

Our own [austinpresley/please-look-here](https://github.com/austinpresley/please-look-here) separately adds [one branding commit](https://github.com/austinpresley/please-look-here/commit/7017192888053ec37bcc96fc4b4cdeb92c4213b9). It is not an external donor. Its published `main` is not the current local working tree, whose integration and follow-up work are recorded in the snapshot.

## Upstream changes worth evaluating

Upstream is now **1.1.0**, [da98f98d5299](https://github.com/nilbuild/tinyhand/commit/da98f98d529971297487b0ec6ef07dc549555686), ten commits after `c5fb36b7c4d7c87480958872a724b30a52427a47`. Full [upstream range](https://github.com/nilbuild/tinyhand/compare/c5fb36b7c4d7c87480958872a724b30a52427a47...da98f98d529971297487b0ec6ef07dc549555686).

| Change | Source and local status |
| --- | --- |
| Screen-share audio recovery | [ca1550d948b4](https://github.com/nilbuild/tinyhand/commit/ca1550d948b43c89e893d9b2a90af67c70bce314). Engine operations move to a serial queue; rebuild after configuration changes or missing renders; multiple player nodes avoid interrupt scheduling. Local `TapSound.swift` still calls the engine directly on the main caller. |
| Lock, sleep and screensaver shutdown | [e45f6e7c48f8](https://github.com/nilbuild/tinyhand/commit/e45f6e7c48f8fb4673b8eecf50c6d14b1ddf51bf). Observers deactivate the pointer and the event tap has a locked-session backstop. No corresponding observer/backstop exists in current local Sources. |
| Restore after a missed Space switch | [d1f059b9abe9](https://github.com/nilbuild/tinyhand/commit/d1f059b9abe93fe8ead62b3bed9dd891f425a066). Reorders the active overlay when it is absent from the new Space. Local code sets `canJoinAllSpaces` once, without this recovery. |
| Other changes | [URL/state-file automation](https://github.com/nilbuild/tinyhand/commit/2675b11c13ab70a966c015663ca6dbd07f147a8f), [double-Shift click-through](https://github.com/nilbuild/tinyhand/commit/519cd5343f17e1f0a7126163444562682f1fa3e3), [toolbar visibility](https://github.com/nilbuild/tinyhand/commit/673003672c7696198a7915fcf1f69d6ecb7fc704), [Command-arrow drawing](https://github.com/nilbuild/tinyhand/commit/74b139c699d356675e892347d55d0c0baccc44f2), [menu icon fix](https://github.com/nilbuild/tinyhand/commit/3d9f5dd169f27ba58816889b0e1ca4300d5ca02d), [nine tap sounds](https://github.com/nilbuild/tinyhand/commit/c3b172351058d2e013d57551438c88b358b4616f), and the version bump. Our JSON/AppleScript/Stream Deck controls, direct Interact toggle, toolbar fix and explicit Arrow tool already cover the central behaviors. New fixed gestures must respect S-015. Extra sounds are optional. |

## Ranked fit for the current app

Read [INTEGRATION.md](../INTEGRATION.md), [STORIES.md](../STORIES.md) and the current local source, including uncommitted files. Scores below are research judgment, not an authorization or a runtime result.

| Rank | Fit | Recommendation and integration boundary |
| --- | --- | --- |
| 1 | 10/10 | Adapt upstream [audio queue/recovery](https://github.com/nilbuild/tinyhand/commit/ca1550d948b43c89e893d9b2a90af67c70bce314). Strongest existing-code reliability gap; no new user-facing mode. Verify real screen/audio-sharing and device changes locally before claiming it fixed. |
| 2 | 9/10 | Adapt upstream [lock/sleep shutdown](https://github.com/nilbuild/tinyhand/commit/e45f6e7c48f8fb4673b8eecf50c6d14b1ddf51bf). Route through current deactivation so drawing, radial state and cursor ownership release consistently. Define how existing captured presses finish. |
| 3 | 9/10 | Combine upstream [Space-change recovery](https://github.com/nilbuild/tinyhand/commit/d1f059b9abe93fe8ead62b3bed9dd891f425a066) with jorgenbruntveit [rejoin on activation](https://github.com/jorgenbruntveit/tinyhand/commit/bb3cc6d3f3202e9337b0f29ebc25325edfc247ae). They address different triggers. Apply our S-016 toolbar visibility policy instead of copying unconditional toolbar showing. |
| 4 | 8/10 | Adapt trussosw [motion timer sleep after three still seconds](https://github.com/trussosw/tinyhand/commit/491831508c062b125186ae1c111f775ff86781ab). Local Original motion still ticks at 20 Hz while idle. Preserve event wakeup, display-link motion and permission/control refresh. This does not prove that the whole app becomes idle; other timers remain. |
| 5 | 8/10 | Explore CatalystMonish [optional shape recognition](https://github.com/CatalystMonish/tinyhand/commit/d2db2444805f92a5d13654bfbd3029176ea10a36) with [ShapeKit](https://github.com/CatalystMonish/tinyhand/commit/71b675d4ca1bfddd451f5e0a5a107bd883b7a4a2). Recognizes rough geometric shapes and a later arrowhead. Integrate into `AnnotationDocument` so recognition, undo/redo and fading agree; keep the existing explicit tools. |
| 6 | 7/10 | Explore AiHand [hover-preserving drawing](https://github.com/rjiang-bb/aihand/commit/ae77ac64bd366a39a6795649cb54074991b63082). Park the system cursor while a separate logical pointer moves, preserving tooltips/dropdowns under annotation. It changes cursor association and routing, so it needs a focused prototype and local multi-display/Interact recovery checks. |
| 7 | 6/10 | Explore jorgenbruntveit [trail erasing](https://github.com/jorgenbruntveit/tinyhand/commit/f42633c68521a5aabf3ed364d3d24472acace00d). Erases from the stroke start at a configured speed while drawing. Our current ink fades whole annotation layers after completion. Keep semantic annotation history independent of visible trail animation and compare it in S-006's live preview. |

Do not reopen finished work: undo/redo, arrows/rectangles/text/numbers, smoothing, independent line width/opacity, screenshots, movable/hidden toolbar, local automation, Interact, enabled pointer catalogs, radial controls and contact shadow already exist. **S-025 Spotlight and the telescoping presentation pointer are done.** QuiteHandy's plain flashlight is not a new missing feature. Whiteboards, magnification, gesture artwork and tumaranja's swing remain optional scope; the last belongs with S-014, while S-011 concerns follow responsiveness. S-005/S-006/S-008 remain the current unfinished wording/preview work, with separate manual acceptance pending on several automation stories.

## Remaining census classifications

These sets, together with the tables above, account for all 73 current public forks:

- **16 Mac donor repositories** have non-upstream patch IDs. Six are newly created, five existing repositories gained SHAs, and five did not advance: [0xdhrv/tinyhand](https://github.com/0xdhrv/tinyhand), [charlesanim/tinyhand](https://github.com/charlesanim/tinyhand), [maxnetdigital/tinyhand](https://github.com/maxnetdigital/tinyhand), [sergvax/tinyhand](https://github.com/sergvax/tinyhand), [tran-huy-phuc/tinyhand](https://github.com/tran-huy-phuc/tinyhand).
- **13 platform-only repositories** comprise the six new ports above, updated AbdulRehman56, and six unchanged ports: [hetrodoo/tinyhand](https://github.com/hetrodoo/tinyhand), [m1ga/tinyhand](https://github.com/m1ga/tinyhand), [MUL7ii/tinyhand](https://github.com/MUL7ii/tinyhand), [p4block/tinyhand](https://github.com/p4block/tinyhand), [sajeeldigitali/tinyhand](https://github.com/sajeeldigitali/tinyhand), [sud868/tinyhand](https://github.com/sud868/tinyhand).
- **One upstream-equivalent-only repository**, ulentini, and **one own repository**, Austin's fork.
- **42 have no non-upstream commits**. The **19 new** ones are `albarian/tinyhand`, `Aleeyoo/tinyhand`, `alexandrethsilva/tinyhand`, `amba5555/tinyhandClick`, `apaww/tinyhand-fedora`, `caynine9/tinyhand`, `gabwag/tinyhand`, `hoxlo/tinyhand`, `itsharex/tinyhand`, `Lohrey/tinyhand`, `lucasea777/tinyhand`, `Mhewski/tinyhand_fork`, `Mooka-Mooka/tinyhand`, `reachforaryan/tinyhand`, `richardvinc/tinyhand`, `ShoNuffWrites/tinyhand`, `suryanshsingh2001/tinyhand`, `thirdPolarity/tinyhand`, `trinhhaox/tinyhand`. The **23 existing** ones are `ChatGPTBuddy/tinyhand`, `devpeerapong/tinyhand`, `goose20090/tinyhand`, `gundusrikanth/tinyhand`, `haxllo/tinyhand`, `hotsync/tinyhand`, `iamdooboy/tinyhand`, `ITGalaxyMaster/tinyhand`, `its-harsshhh/tinyhand`, `jawond/tinyhand`, `luqmanoop/tinyhand`, `mathewharwich/tinyhand`, `mayurnimavatg/tinyhand`, `nkemjp2/tinyhand`, `Pikuseru/tinyhand`, `pparker13122/tinyhand`, `screenfluent/tinyhand`, `secondpathstudio/tinyhand_macos`, `Shoaib19/tinyhand`, `Ubaton/tinyhand`, `umairbari/tinyhand`, `vasinl124/tinyhand`, `wanderberi/tinyhand`. "No non-upstream commits" includes equal and behind-only histories; a recent repository `pushed_at` copied from upstream is not donor activity.

## Evidence and limits

Raw evidence is outside the working repo at `/Users/apresley/Library/Caches/agent-research/tinyhand-fork-audit-20261114`. It contains API bodies/headers and request times, both census observations, full bare git objects and retained refs, all 50 ahead-branch diffs, individual commit patches/metadata, source snapshots, initial drift and final verification records, and reproducible collection/analysis scripts. The old `/tmp/tinyhand-fork-audit-20261109` contains zero files, so the durable original note supplied its exact 56 tips and 111 commit SHAs. Historical objects were recovered from GitHub; the snapshot retains **306 ever-covered SHAs**, including the rewritten old toolbar commit.

There are **no gaps for currently public network repositories or current advertised branch heads** at the final verified time. This cannot enumerate private/deleted forks, deleted/unadvertised branches, tag-only/unreachable work, detached copies outside GitHub's network or unpublished work. The one unavailable baseline repository is reported explicitly. API reads are not atomic; a refresh closed the one observed race.

Behavioral claims come from source diffs and final wiring, not titles, README claims or unchecked test output. Binary assets were inventoried without a complete visual/provenance audit. No donor code, app, build, test suite, release packaging, hosted workflow or third-party AI agent CLI was executed. No app source, git configuration, commits, PRs or remote repository state changed. The completed research files are this report, the watch-state JSON, the comparison HTML and the scheduler record.

## Weekly check

The T3 scheduler is enabled for **Mondays at 09:00 America/New_York**, beginning **16 November 2026 at 09:00 EST**, or 14:00 UTC. Results return to the [fork tracking thread](t3-thread://v1/48e1ce26-d811-4eb9-baec-7f05ec503e4b).

Each run will repeat the recursive census and all-branch comparison, assess newly observed patches against the current local app, and separately inspect useful changes adopted upstream. Repository IDs preserve rename history; cumulative SHA and patch records prevent repeat recommendations. Runs produce a dated report and refresh successfully inspected coverage. The check researches and recommends changes; implementation requires a separate request.

The task identifier, exact schedule and prompt are retained in [the scheduler record](tinyhand-fork-watch-schedule.json). The initial next-run time was verified from the scheduler response. Hosted CI stays disabled.

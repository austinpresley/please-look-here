# Quick controls radial redesign

Design work from 16 November 2026. Design only: no app source changed.

- `claude/prototype.html`: the current prototype (v9, graded 90/100). Open it in a browser. Images load from this checkout.
- `claude/prototype-v3.html` … `prototype-v9.html`: frozen versions, one per grading round. `claude/states-v4/` … `states-v9/` hold their settled screenshots.
- `grades/GRADE-1.md` … `GRADE-7.md`: Sol 6.1 (xhigh) harsh grades. v3 61, v4 78, v5 84, v6 88, v7 89, v8 89, v9 90 (A, ship the HTML design as-is). Native release gates are listed unscored in GRADE-7.
- `claude/prototype-v2.html`: the v2 prototype that Sol reviewed in `sol/ROUND2.md`. Its line numbers match that review. The v2 screenshots ROUND2 cites were replaced by `claude/states/`.
- `claude/states/`: settled screenshots of the main v3 states.
- `sol/REVIEW.md`: Sol 6.1 (xhigh) round 1, an independent critique, research and spec.
- `sol/ROUND2.md`: Sol round 2, with verdicts on the open disagreements, prototype defects and the merged implementation spec. **This is the spec to build from.**
- `sol/RESEARCH-NOTES.md`: primary-source notes on Kando, Loop, Logitech Actions Ring, BetterTouchTool, Pie Menu, Pieoneer, Blender, marking-menu research and Procreate.
- `sol/concept-*.png`: Sol's generated concept renders. They show material direction, not geometry.

v9 implements the ROUND2 merged spec plus every fix from the grading loop. The prototype checks covered:
- outside clicks in click mode
- disabled-command execution
- edge arming
- Escape in both modes
- category entry versus selection
- Back to the parent center
- browser search and selection

Run these only in the browser prototype. The native checks listed in ROUND2 still need to run on Austin's Mac.

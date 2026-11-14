S-007 projected shadow visual prototype

The screenshot is captured from the running native AppKit and Core Animation prototype using the original lavender pointer asset. It is not an ImageGen output.

The shadow uses the real hand and rod silhouette, projected as a tilted plane whose height is zero at the measured fingertip and increases toward the rod. A Metal compute pass integrates 1,024 light positions. The penumbra is therefore narrow at contact and increasingly soft away from contact. Lighting stays fixed as the pointer rotates.

The original global drop shadows and radial contact decals are disabled in the proposed view. Pressing lowers the simulated plane, and the Shadow toggle hides the entire result. Laser rendering is untouched in the source copied to the prototype.

Verified locally: native build, Metal runtime, white and dark walls, rest and pressed states, smaller size, rotation, shadow off, glove and robot assets. The prototype idles without continuous shadow regeneration. The local app signature verifies.

This is a visual prototype, not a completed S-007 product release. Production source, installed app and saved settings were not modified for this revision. The prototype app is ad hoc signed.

Local sources and build command:
python3 dist/s007-area-shadow-prototype/build.py

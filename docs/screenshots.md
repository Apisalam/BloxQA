# Screenshot checklist

Studio's automated viewport capture does not include the full plugin chrome reliably, so repository UI screenshots should be captured manually.

Save final PNG files in `assets/screenshots/` using the filenames below. Crop out usernames, local paths, unrelated plugins, place IDs, private project names, and notifications.

## Recommended images

1. `plugin-overview.png`
   - BloxQA dock panel open in BloxQA_Dev.
   - Show version 0.1.0, two valid tests, zero invalid tests, and the Gameplay category.
2. `individual-pass.png`
   - Show a completed Player Spawn Test with PASS and a visible duration.
3. `run-all-results.png`
   - Show both Player Spawn and Player Respawn results plus Total 2, Passed 2, Failed 0, and total duration.
4. `category-filter.png`
   - Show the Gameplay filter selected and the button labeled Run All Gameplay Tests.
5. `diagnostic-example.png`
   - In a temporary verification copy only, show one malformed test warning while valid tests remain listed. Remove the malformed test afterward.
6. `clean-baseplate.png`
   - Open a new Baseplate without the per-place runtime; show that the global BloxQA panel loads and reports the missing runtime clearly.

Use `plugin-overview.png` near the top of README only after the file exists. Two or three strong screenshots are preferable to many repetitive images.

# SharkTune closed-test operations

This checklist is for the required external Google Play closed-test gate. It
does not assert that a test or production access has been completed.

1. Create the Play Console app as paid, enter the listing text from
   `docs/google-play-listing.md`, the privacy-policy URL, and the reviewed Data
   Safety answers.
2. Upload a signed AAB whose `versionCode` is unused in Play Console. Enrol in
   Play App Signing and record the upload-certificate SHA-256 fingerprint in a
   private operator record.
3. Run internal testing first, then invite at least 12 opted-in testers to the
   closed test. Keep the test continuously available for 14 days.
4. Log and triage microphone allow/deny/settings recovery, E2–E4, low tuning,
   reference tone, clipping/noise, phone/audio interruption, screen off/return,
   30-minute use, TalkBack, grayscale, battery, and jank on at least one Samsung
   device including SM-S926N when available.
5. Apply for production access only after the 12-person/14-day requirement and
   feedback review are complete. Do not describe the app as released before
   Play grants access.
6. After approval, use staged production rollout at 10%, 50%, then 100%. Hold
   each stage for at least 24 hours and expand only with no P0 defect, no major
   path crash/ANR, no permission failure, and no live-tuning regression.

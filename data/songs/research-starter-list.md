## FINDINGS
# Song Tuning Library — Research Findings

## 1. Copyright status of tuning metadata

**Bottom line: "Song X uses Drop D, capo 2, half-step down" is an uncopyrightable fact in the US and can be compiled into a commercial app — provided you compile it yourself rather than copying someone else's curated database.**

- Under *Feist Publications v. Rural Telephone* (499 U.S. 340, 1991), facts are not copyrightable; compilations of facts get thin protection only for original *selection and arrangement*. A tuning/capo/key/BPM datum is a fact about a recording, exactly like the key/BPM data that Tunebat, SongBPM, and Spotify audio-features consumers ship commercially today. Academic analyses of the guitar-tab copyright fights (Fordham IPLJ, Arizona Law Review, Oklahoma JOLT — see sources) all locate the infringement risk in *tabs as derivative works of the musical composition* (the note-for-note transcription), not in metadata about the song.
- The legal history that matters: the 1996–2006 NMPA/MPA takedown campaigns (OLGA shutdown, MXTabs, Guitar Tab Universe) targeted **tablature and lyrics** — transcriptions/arrangements, which are exclusive rights of the composition owner under 17 U.S.C. §106(2). No takedown or case has ever targeted tuning/capo metadata. As long as the app ships *no tab excerpts, no chord-progression-with-lyrics sheets, no lyrics*, it stays outside the licensed-content fight entirely.
- **How existing players handle it:** GuitarTuna (Yousician) bundles tunings inside a *licensed* songs product (~400k songs, publisher deals inherited from Yousician's licensing) — the tuning data rides along with licensed chords/tabs, so they never had to answer the metadata question separately. Ultimate Guitar operates under publisher licensing deals for tabs and treats its whole corpus as protected content (ToS + aggressive Cloudflare blocking — both guitartuna.com pages and UG's ToS page 403'd direct fetches during this research). Songsterr licenses compositions via publishers and exposes tunings as plain metadata in an open JSON API (below). Nobody licenses "tunings" as such; the licensing is always about the transcriptions.
- **Caveats that do have teeth:** (a) **EU/UK sui generis database right** — extracting a substantial part of *someone else's* database (e.g., bulk-copying GuitarTuna's or gtdb.org's song→tuning mappings) can infringe even though each fact is free; (b) **breach of contract / ToS** claims against scraping (independent of copyright); (c) thin compilation copyright in another site's *selection* of songs. All three are avoided by independent curation from primary/mixed sources. Artist and song names are nominative facts (fine to use); avoid artist photos/logos and any implied endorsement.

## 2. Existing datasets and APIs (2025–2026 status)

- **Songsterr API — alive and tested live during this research (July 2026).** `GET https://www.songsterr.com/api/songs?pattern=<query>&size=N` returns JSON with `songId`, `artist`, `title`, `tracks[]`, and per-track `tuning` as **MIDI note-number arrays** (e.g., E standard = `[64,59,55,50,45,40]`). No authentication required. However: (a) it is *unofficial/undocumented* — the old documented API page is gone; directory sites (publicapis.io, jsonapi.co) still describe it as "free for non-commercial, commercial use requires a license from Songsterr"; (b) Songsterr's current ToS (fetched directly) prohibits using any "automated tool, script, browser extension, or AI agent" to "modify, automate, or interfere with the Service," bars commercial reuse of Content without "express advance written permission," and now publishes a machine-readable ai.txt policy. **Verdict: excellent as a curation-time verification oracle (human-in-the-loop lookups), not a runtime dependency and not a bulk-import source without written permission.** Worth emailing them — the dataset is small and they've historically been developer-friendly.
- **Ultimate Guitar: confirmed NOT OK.** No official API exists (only community scrapers of their private mobile API, e.g., Pilfer/ultimate-guitar-scraper, joncardasis/ultimate-api on GitHub — all unauthorized). ToS contains anti-scraping/automated-access prohibitions (confirmed via secondary sources; the ToS page itself is behind a 403 anti-bot wall, which is itself the message). GitHub community discussions around UG clones consistently flag the ToS risk. Do not scrape.
- **No Creative Commons tab/tuning dataset exists.** Searches found no CC-licensed song-tuning dataset on GitHub or elsewhere. gtdb.org (Guitar Tuning Database: 947 tunings with some song associations) is a useful *reference* but proprietary — don't bulk-copy. Wikipedia's "List of guitar tunings" (CC BY-SA) is good for tuning *definitions* and a handful of song attributions with citations. Conclusion: **the curated library is a genuine moat precisely because no open dataset exists.**

## 3. Proposed schema (JSON source-of-truth → SQLite shipped in app)

Normalize tunings into their own table; songs reference a tuning and add per-song modifiers (capo, cents offset, live variants).

```sql
CREATE TABLE tunings (
  id TEXT PRIMARY KEY,            -- 'drop-d', 'e-flat-standard', '7-drop-a', '8-f-standard'
  name TEXT NOT NULL,             -- 'Drop D'
  string_count INTEGER NOT NULL,  -- 6 | 7 | 8
  midi_notes TEXT NOT NULL,       -- JSON, low->high: '[38,45,50,55,59,64]'
  family TEXT NOT NULL            -- 'standard'|'drop'|'open'|'modal'|'custom'
);

CREATE TABLE songs (
  id TEXT PRIMARY KEY,            -- 'foo-fighters-everlong'
  artist TEXT NOT NULL, title TEXT NOT NULL,
  album TEXT, year INTEGER, genres TEXT,          -- JSON array
  tuning_id TEXT NOT NULL REFERENCES tunings(id),
  capo INTEGER NOT NULL DEFAULT 0,                 -- 0-11
  cents_offset REAL NOT NULL DEFAULT 0,            -- e.g. -25 (Pantera), +20 (early Van Halen)
  half_step_down INTEGER NOT NULL DEFAULT 0,       -- redundant w/ tuning_id but cheap search facet
  guitar_type TEXT,               -- 'electric'|'acoustic'|'12-string'|'baritone'|'classical'
  gauge_hint TEXT,                -- '.011-.056, or .012-.060 for 25.5" scale'
  tension_note TEXT,              -- human note; computed tension comes from your tension engine
  live_variants TEXT,             -- JSON: [{"context":"2016+ tours","tuning_id":"e-standard","note":"..."}]
  difficulty TEXT,                -- 'beginner'|'intermediate'|'advanced'
  beginner_alt TEXT,              -- JSON: {"tuning_id":"e-standard","capo":0,"note":"riff playable in standard, loses low D"}
  notes TEXT,                     -- 'Hendrix tuned ~half-step down on nearly everything'
  confidence TEXT NOT NULL,       -- 'verified'|'high'|'medium'  (surface subtly in UI)
  sources TEXT,                   -- JSON array: ["songsterr:18211","interview:guitarworld-2004"]
  popularity INTEGER, aliases TEXT
);
CREATE VIRTUAL TABLE songs_fts USING fts5(title, artist, aliases, content='songs');
```

Design rationale: MIDI numbers are the canonical pitch representation (matches Songsterr convention; Hz = 440·2^((m−69)/12); your ±1-cent tuner consumes midi_note + cents_offset directly). `capo` is metadata only — the tuner must instruct "tune WITHOUT the capo, then place capo at fret N." `gauge_hint` is a curated override; the real gauge/tension recommendation should be computed by your planned tension engine from tuning + scale length. Author entries as one JSON file per song (or one big JSON) in the repo, CI-compile to SQLite shipped as a Flutter asset, with a CDN-hosted JSON delta feed for post-release additions (no app update needed).

## 4. Starter list (~78 songs)

Format: Artist - Song | tuning (low→high) | capo | notes. Confidence: [V]=web-verified this session, [H]=high consensus, [M]=verify against Songsterr/gear interviews before shipping.

**E Standard (E A D G B E)**
1. AC/DC - Back in Black | E std | 0 | [H]
2. AC/DC - Highway to Hell | E std | 0 | [H]
3. Led Zeppelin - Stairway to Heaven | E std | 0 | acoustic intro + electric [H]
4. Led Zeppelin - Whole Lotta Love | E std | 0 | [H]
5. Deep Purple - Smoke on the Water | E std | 0 | classic first-riff song [H]
6. Black Sabbath - Paranoid | E std | 0 | [H]
7. Metallica - Enter Sandman | E std | 0 | [H]
8. Metallica - Master of Puppets | E std | 0 | [H]
9. Ozzy Osbourne - Crazy Train | E std | 0 | [H]
10. Lynyrd Skynyrd - Sweet Home Alabama | E std | 0 | [H]
11. Pink Floyd - Wish You Were Here | E std | 0 | acoustic [H]
12. Eagles - Hotel California | E std | 0 | studio intro: 12-string acoustic capo 7 [H]
13. Pearl Jam - Even Flow | E std | 0 | [H]
14. The White Stripes - Seven Nation Army | E std | 0 | riff via octave pedal, not bass [H]
15. Radiohead - Creep | E std | 0 | [H]
16. Nirvana - Smells Like Teen Spirit | E std | 0 | F-shape barre riff [H]

**Half-step down (Eb Ab Db Gb Bb Eb)**
17. Jimi Hendrix - Purple Haze | Eb std | 0 | Hendrix tuned down ~half step on most recordings [H]
18. Jimi Hendrix - Little Wing | Eb std | 0 | [H]
19. Jimi Hendrix - Voodoo Child (Slight Return) | Eb std | 0 | [H]
20. Guns N' Roses - Sweet Child O' Mine | Eb std | 0 | [H]
21. Guns N' Roses - Welcome to the Jungle | Eb std | 0 | [H]
22. Guns N' Roses - Paradise City | Eb std | 0 | [H]
23. Van Halen - Eruption | Eb std | 0 | VH1 actually slightly sharp of Eb (~+20 cents) — great cents_offset showcase [H]
24. Van Halen - Ain't Talkin' 'Bout Love | Eb std | 0 | same note [H]
25. Stevie Ray Vaughan - Pride and Joy | Eb std | 0 | heavy .013 gauge — gauge-recommendation showcase [H]
26. Slayer - Raining Blood | Eb std | 0 | [H]
27. Green Day - Basket Case | Eb std | 0 | whole Dookie album Eb [H]
28. Weezer - Say It Ain't So | Eb std | 0 | [H]
29. Smashing Pumpkins - Bullet with Butterfly Wings | Eb std | 0 | [H]
30. Alice in Chains - Man in the Box | Eb std | 0 | [H]

**Drop D (D A D G B E)**
31. Foo Fighters - Everlong | Drop D | 0 | [V]
32. Foo Fighters - My Hero | Drop D | 0 | [H]
33. Rage Against the Machine - Killing in the Name | Drop D | 0 | [H]
34. Rage Against the Machine - Bulls on Parade | Drop D | 0 | [H]
35. Soundgarden - Black Hole Sun | Drop D | 0 | [V]
36. Soundgarden - Spoonman | Drop D | 0 | [V]
37. Tool - Schism | Drop D | 0 | [H]
38. Tool - Sober | Drop D | 0 | [H]
39. The Beatles - Dear Prudence | Drop D | 0 | [V]
40. Rammstein - Du Hast | Drop D | 0 | [H]
41. Audioslave - Cochise | Drop D | 0 | [H]
42. Lamb of God - Laid to Rest | Drop D | 0 | proof drop D gets heavy [H]
43. Avenged Sevenfold - Bat Country | Drop D | 0 | [H]
44. Neil Young - Cinnamon Girl | Double Drop D (D A D G B D) | 0 | [H]

**Drop C# / Drop Db (C# G# C# F# A# D#)**
45. Deftones - My Own Summer (Shove It) | Drop C# | 0 | whole Around the Fur era [V]
46. Alice in Chains - Them Bones | Drop C# | 0 | Dirt = half-step down + drop [H]
47. Nirvana - All Apologies | Drop C# | 0 | drop D tuned down half step [H]
48. Linkin Park - One Step Closer | Drop C# | 0 | Hybrid Theory era [M]
49. Disturbed - Down with the Sickness | Drop C# | 0 | [M]

**D standard / C# standard (whole-step & 1.5-step down)**
50. Nirvana - Come as You Are | D std (D G C F A D) | 0 | [H]
51. Metallica - Sad but True | D std | 0 | only downtuned Black Album track [H]
52. Pantera - Walk | D std, ~-25 cents | 0 | Dimebag tuned slightly flat — cents_offset showcase [H]
53. Gojira - Flying Whales | D std | 0 | [M]
54. Black Sabbath - Children of the Grave | C# std (C# F# B E G# C#) | 0 | Master of Reality down 1.5 steps for string tension (Iommi's fingers) [H]

**Drop C / C standard (C G C F A D / C F Bb Eb G C)**
55. System of a Down - Chop Suey! | Drop C | 0 | band's signature tuning [H]
56. System of a Down - Toxicity | Drop C | 0 | [H]
57. Bullet for My Valentine - Tears Don't Fall | Drop C | 0 | [H]
58. Bullet for My Valentine - Your Betrayal | Drop C | 0 | [M]
59. Killswitch Engage - My Curse | Drop C | 0 | [H]
60. Queens of the Stone Age - No One Knows | C std (C F Bb Eb G C) | 0 | [H]

**Drop B / Drop A / 7-string / 8-string**
61. Slipknot - Duality | Drop B (B F# B E G# C#) | 0 | [V]
62. Slipknot - Psychosocial | Drop B | 0 | [H]
63. Slipknot - The Heretic Anthem | Drop A (A E A D F# B on 6; A E A D G B E on 7) | 0 | Iowa album; A1=55 Hz — your stated accuracy floor [V]
64. Machine Head - Davidian | Drop B | 0 | [H]
65. Korn - Blind | 7-string A std (A D G C F A D) | 0 | the founding 7-string nu-metal tuning [H]
66. Korn - Freak on a Leash | 7-string A std | 0 | [H]
67. Trivium - In Waves | 7-string Drop A (A E A D G B E) | 0 | [M]
68. Ingested - The Divine Right of Kings | 7-string Drop G# | 0 | Songsterr API shows ~G#1 lows; newer material on 8-string lower still — VERIFY before ship [M]
69. Meshuggah - Bleed | 8-string F std (F Bb Eb Ab Db Gb Bb Eb) | 0 | half step below F# 8-string standard; F1 ≈ 43.65 Hz — LOWER than your stated F#1 target, sets your true detection floor [V]
70. Animals as Leaders - CAFO | 8-string, Tosin drop-E variant | 0 | [M]

**Acoustic / capo / open & alternate tunings**
71. Oasis - Wonderwall | E std | capo 2 | the canonical capo song [H]
72. Tracy Chapman - Fast Car | E std | capo 2 | [H]
73. Ed Sheeran - Perfect | E std | capo 1 | [H]
74. Jason Mraz - I'm Yours | E std | capo 4 | [H]
75. Passenger - Let Her Go | E std | capo 7 | [H]
76. John Denver - Take Me Home, Country Roads | E std | capo 2 | [H]
77. The Beatles - Here Comes the Sun | E std | capo 7 | [H]
78. The Beatles - Blackbird | E std | 0 | [H]
79. Fleetwood Mac - Landslide | E std | capo 3 | [H]
80. Kansas - Dust in the Wind | E std | 0 | Travis picking [H]
81. Simon & Garfunkel - The Boxer | E std | capo 2 | [M]
82. Goo Goo Dolls - Iris | B D D D D D | 0 | custom-tuning showcase [H]
83. Led Zeppelin - Kashmir | DADGAD | 0 | [H]
84. The Rolling Stones - Start Me Up | Open G (G D G B D), low string removed | 0 | Keith's 5-string trick [H]

**K-pop / K-rock / K-indie** (mostly standard — the value here is capo + confidence data; verify each on Songsterr, which carries Day6 and Wave to Earth)
85. Day6 - You Were Beautiful | E std | 0 | band-performed K-pop [M]
86. Day6 - Congratulations | E std | 0 | [M]
87. Hyukoh - Wi Ing Wi Ing | E std | 0 | [M]
88. Wave to Earth - seasons | E std | capo 5 | most-tabbed K-indie song on UG; no-capo D-shape variant also circulates [V]
89. IU - Blueming | E std | 0 | [M]

## 5. Making the feature sticky

- **Search UX:** SQLite FTS5 over title/artist/aliases with prefix matching and typo tolerance; facets by tuning family, genre, string count, difficulty; "Songs in your current tuning" (zero-friction discovery after any tuning session); artist pages grouping songs by tuning ("Slipknot: 12 songs in Drop B, 4 in Drop A").
- **One-tap "Tune for this song":** tapping a song sets the tuner's target notes + cents offset, shows a capo banner ("Place capo on fret 2 AFTER tuning — tune open strings first"), then walks string-by-string (low→high) with your peg-direction guidance. For big downtunes, interject the tension/gauge warning ("Drop B on .009s will be floppy and ~15 cents unstable — recommended .011–.056") — this fuses the song library with your two other differentiators. End state: "You're tuned for Duality" + optional outbound deep link to the song's Songsterr/UG page (linking out is legally clean; embedding content is not).
- **Retention loops:** recents + favorites; "tuning unlocked N songs" counters; weekly featured song/tuning push; per-song stability score after tuning (ties into drift analysis: "your low B drifted 4 cents after picking — consider heavier gauge").
- **User submissions (post-MVP):** submission form captures only facts (tuning, capo, source link) — never tab content, keeping UGC out of derivative-work territory; auto-cross-check submitted tuning against Songsterr API for that song at moderation time; require a source; community up/down votes feed the confidence field; register a DMCA agent as cheap insurance.

## RECOMMENDATION
Ship a hand-curated seed dataset: author ~80 songs (the starter list above) as JSON files in the repo — one source-of-truth JSON compiled by CI into a SQLite database (with FTS5) bundled as a Flutter asset, plus a CDN-hosted JSON delta feed so new songs land without app releases. Use the schema in section 3: normalized `tunings` table (MIDI note arrays, low→high) + `songs` table with capo, cents_offset, half_step_down, gauge_hint, live_variants, difficulty, beginner_alt, confidence, and sources fields. Curation protocol: every entry needs two independent confirmations (Songsterr API tuning array — verified working, unauthenticated, returns per-track MIDI tunings — plus one of: artist gear interview, official songbook, live-video inspection); store the confidence flag and do a human verification pass on every [M]-flagged entry before launch. Do NOT scrape Ultimate Guitar (ToS prohibits it, no official API) and do not bulk-import Songsterr data or call their API from the shipped app — use it only as a curation-time verification oracle, and email Songsterr for written permission if you later want deeper integration. Never include tab excerpts, chord sheets with lyrics, or lyrics — tuning/capo facts only. This keeps the feature 100% legally clean (Feist: facts are free), cheap (~2-3 curator-days for 80 songs), and defensible (no open dataset exists, so a verified library is a real moat).

## RISKS
1) Copying risk, not facts risk: individual tunings are uncopyrightable facts (US, Feist), but bulk-copying another site's song→tuning database invites EU/UK sui generis database-right claims, thin compilation-copyright claims, and ToS/contract claims — independent curation from mixed sources is the mitigation. 2) Ultimate Guitar scraping is confirmed off-limits (ToS anti-scraping clauses, Cloudflare 403 walls observed during research, no official API); the existing GitHub scrapers all hit an unauthorized private mobile API. 3) Songsterr API is unofficial and undocumented in 2026 — no SLA, could vanish or change shape any time; their current ToS bars automated tools that interfere with the service and commercial reuse of content without written permission, and they now publish an ai.txt AI-access policy — so treat it as a manual research aid only. 4) Accuracy is a trust risk: several starter entries are flagged [M] (Ingested, Trivium, Linkin Park, Gojira, Animals as Leaders, most K-pop entries) and must be human-verified before shipping; real-world complications (Van Halen sharp-of-Eb, Pantera quarter-flat, GnR live-vs-studio, Hotel California's capo-7 12-string) require the cents_offset and live_variants fields to represent honestly. 5) Meshuggah's actual tuning is F1 ≈ 43.65 Hz — below the stated F#1 ≈ 46.2 Hz detection target — so the DSP floor needs to reach ~43 Hz or the flagship 8-string preset will underperform. 6) Never ship tab excerpts or lyrics alongside the metadata — that is exactly the content the NMPA/MPA takedown campaigns (OLGA, MXTabs) targeted and what UG/Songsterr/GuitarTuna pay publishers to license. 7) Trademark: artist/song names are fine as nominative facts, but avoid artist imagery/logos and any implied endorsement. 8) Legal analysis here is research, not legal advice — worth one hour of real counsel review before launch, especially for EU distribution.

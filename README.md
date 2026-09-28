# Koneko 🐱

An iPad/iPhone app that helps a young learner write Japanese: look up a word, then watch
each character being written stroke by stroke.

## Status

- **Phase 1 (done):** tap a character and watch an animated stroke-order diagram with stroke
  numbers, play/pause, step, replay and speed control.
- **Phase 2 (done):** type a word in English (or Japanese/romaji); an LLM via
  [OpenRouter](https://openrouter.ai) suggests Japanese words with emoji, furigana, romaji and
  meaning. Results are cached on the device. Japanese typed directly skips the LLM.
- **Phase 3 (done):** hold-to-talk speech input (on-device where supported) with live
  transcript and "Or did you say…" alternatives.
- **Pronunciation:** the word is spoken with the best installed Japanese voice (from its kana
  reading, so kanji are never misread); slow mode; tapping a character says its sound.
- **Phase 4 (done):** Practice mode: write each character with Apple Pencil, finger or mouse;
  every stroke is checked for order, direction and shape, with a demo of the right stroke
  after a mistake, an optional guide, and stars at the end.
- **Phase 5 (done):** writing styles (as adults write / only kanji up to her school grade,
  with the rest in hiragana / all hiragana / all katakana), furigana toggle, "My words" history
  with stars earned in Practice, handwriting-style font (Klee One).
- **Apple Watch (in progress):** My words sync through iCloud key-value storage to a
  watchOS app (`KonekoWatch/`, shared code in `Shared/`). Setup: see `docs/AppleWatch.md`.
- **Learn:** hiragana and katakana charts (basic, ゛゜, combined sounds) and kanji by school
  grade with search; each character shows its sound, stroke order and practice; kanji get an
  AI explanation with example words (cached). Offline kanji data: `koneko/Resources/kanji_info.json`
  (`python3 Tools/build_kanji_info.py`).
- **Navigation:** Write · My words · Learn · Settings as a tab bar on iPhone and a sidebar on
  iPad/Mac (`TabView` with `.sidebarAdaptable`).
- **Watch kana:** Learn → Hiragana/Katakana on the watch: pick a sound from the list, then a
  full-screen character drawn from its strokes (tap to replay the stroke order); Digital Crown
  for the next sound, swipe left/right to switch hiragana ⇄ katakana. Uses the small
  `Shared/Resources/kana_strokes.json`.
- **My words:** pin words, sort them into folders, delete single words; export/import the
  whole list (words, folders, pins, stars) as JSON from Settings.

## Setup

Open Settings (gear icon) in the app and paste an OpenRouter API key. It is stored in the
Keychain. The model can be changed there too (default: `google/gemini-3.7-flash`).

## Data and fonts

- `Shared/Resources/kanji_grades.json`: school grade of each jōyō kanji, from KANJIDIC2
  (© EDRDG, CC BY-SA 4.0) via [kanji-data](https://github.com/davidluzgouveia/kanji-data).
  Regenerate with `python3 Tools/build_kanji_grades.py`.
- `koneko/Resources/Fonts/KleeOne-SemiBold.ttf`: [Klee One](https://github.com/fontworks-fonts/Klee)
  by Fontworks, SIL Open Font License 1.1 (license text next to the font).

## Stroke data

`koneko/Resources/strokes.json` is generated from [KanjiVG](https://kanjivg.tagaini.net)
(© Ulrich Apel, [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/)) and is
distributed under the same license. To regenerate it:

```sh
python3 Tools/build_strokes.py            # downloads the pinned KanjiVG release
python3 Tools/build_strokes.py kanji/     # or use an unpacked kanji/ directory
```

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
- Next: kanji-level display modes, history, rewards.

## Setup

Open Settings (gear icon) in the app and paste an OpenRouter API key. It is stored in the
Keychain. The model can be changed there too (default: `google/gemini-3.7-flash`).

## Stroke data

`koneko/Resources/strokes.json` is generated from [KanjiVG](https://kanjivg.tagaini.net)
(© Ulrich Apel, [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/)) and is
distributed under the same license. To regenerate it:

```sh
python3 Tools/build_strokes.py            # downloads the pinned KanjiVG release
python3 Tools/build_strokes.py kanji/     # or use an unpacked kanji/ directory
```

# Koneko 🐱

An iPad/iPhone app that helps a young learner write Japanese: look up a word, then watch
each character being written stroke by stroke.

## Status

- **Phase 1 (done):** type a Japanese word, tap a character, and watch an animated stroke-order
  diagram with stroke numbers, play/pause, step, replay and speed control.
- Next: English → Japanese translation via OpenRouter, hold-to-talk speech input,
  Apple Pencil tracing, kanji-level display modes.

## Stroke data

`koneko/Resources/strokes.json` is generated from [KanjiVG](https://kanjivg.tagaini.net)
(© Ulrich Apel, [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/)) and is
distributed under the same license. To regenerate it:

```sh
python3 Tools/build_strokes.py            # downloads the pinned KanjiVG release
python3 Tools/build_strokes.py kanji/     # or use an unpacked kanji/ directory
```

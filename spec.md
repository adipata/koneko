# Koneko — specification and developer guide

Read this first in a new development session. It describes what the app is, who it's for,
how the code is organised, and the rules that keep it building.

## 1. Product

Koneko (こねこ, "kitten") helps **Nathalie, a 9-year-old English speaker**, learn to write
Japanese. It runs on **iPad, iPhone and Mac**, with a companion **Apple Watch** app.
Her main device is an iPad with an Apple Pencil.

- **Write** (main screen): she says or types a word.
  - Hold-to-talk works in English or 日本語, with a segmented switch. Typing uses a search
    field with an ➜ button.
  - English is translated through OpenRouter, which returns several candidates.
  - Japanese typed directly is shown as is, with no AI call if it's offline.
  - The word card shows:
    - an emoji, the word with furigana (wrapping `FuriganaText`), romaji and meaning
    - Say it, Say it slowly and Copy buttons
    - Pin and Add to folder (`SaveWordBar`)
    - each character's stroke-order animation, and practice by tracing with Apple Pencil,
      a finger or a mouse, with stroke checking and 1–3 stars
- **My words**: every word she looks up is saved automatically.
  - Chips for All words and 📌 Pinned, plus a 📁 Folders drop-down (new, rename, delete).
  - English/Japanese search.
  - Swipe or context menu per word; Select mode for bulk move, pin and delete.
  - Flash cards for the current filter.
  - Export/import as JSON; delete-all is in Settings.
- **Learn**:
  - hiragana and katakana charts (basic, ゛゜, combined), with sound, strokes and practice
  - kanji by school grade (1–6, plus 7 = secondary), grouped and searchable, with an AI
    explanation that is cached
  - Flash cards: endless random decks with no scoring
  - Flash-card **sets**, made through a Photos-style Select mode
- **Settings**:
  - OpenRouter API key (Keychain) and model
  - writing style: as adults write / kanji up to grade N / all hiragana / all katakana
  - furigana, romaji and romaji-in-lists toggles, auto-speak
  - Apple Watch sync, and export/import of My words
  - About, which contains a personal French note from her father ("Tati"). **Do not
    translate or change it.**
- **Splash**: the kitten mascot under falling sakura, with "こねこ ・ For Nathalie, my
  beloved girl" and 「大好きなナタリーへ」. **Keep this text.**
- **Apple Watch**:
  - My words (folders, pinned, all; dictation search) and a word pager with pronunciation
  - kana list and full-screen characters: Digital Crown for next, swipe to switch script
  - flash cards, including sets
  - data is read-only and comes from the phone/iPad through iCloud key-value storage

Tone: friendly and simple for a child, with emoji where it helps, and never scoring,
punishing or pressuring her.

## 2. Platforms and toolchain

- Xcode 27 (the project is also fine with Xcode 26).
- **Deployment targets:** iOS/iPadOS **26.0**, macOS 26.6, watchOS **26.0**.
  - It must keep running on iOS 26; her iPad is on iOS 26. The dad's devices run iOS/watchOS 27.
  - Guard any iOS 27-only API with `if #available`.
- **Targets:**
  - `koneko` app: iOS, iPadOS, Mac (native), visionOS. Bundle ID `lu.pata.koneko`.
  - `KonekoWatch Watch App`: bundle ID `lu.pata.koneko.watchkitapp`, embedded in the iOS app.
- iCloud key-value store identifier: `$(TeamIdentifierPrefix)lu.pata.koneko`, in both
  entitlements files.
- There are no third-party Swift packages. Keep it that way unless there's a strong reason.

### Build settings you must respect

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: every type is on the main actor unless marked
  otherwise.
  - Pure data types and helpers used from background or `Sendable` contexts must be
    `nonisolated` (for example `HistoryEntry`, `WordFolder`, `DictionaryFile`, `KanjiInfo.clean`).
  - Don't pass main-actor static functions as values, such as `.map(Self.f)`. Wrap them in a
    closure: `.map { Self.f($0) }`.
- `SWIFT_APPROACHABLE_CONCURRENCY` is on.
- `MemberImportVisibility` is on: each file must `import` the module whose members it uses.
  For example, `remove(atOffsets:)` needs `import SwiftUI`.
- The folders are **file-system-synchronized groups**, so dropping a file in a folder adds it
  to the target(s):
  - `koneko/` belongs to the app target only.
  - `Shared/` belongs to **both** the app and watch targets.
  - `KonekoWatch/` belongs to the watch target only. It must never end up in the app target,
    because `.verticalPage` and other watch-only APIs break the Mac build.
  - Do **not** add `#if os(watchOS)` guards to work around membership problems. Fix the
    membership instead.

## 3. Code map

```
koneko/                 app target
  MyApp.swift           @main
  App/                  AppModel (shared state), RootView (TabView .sidebarAdaptable,
                        splash, watch-sync onChange), SplashView (+ AppInfo version text)
  ContentView.swift     Write screen
  Translation/          OpenRouterClient (requestJSON<Output> with strict json_schema),
                        TranslationPrompt, Translator (status, cache), WordCardView
  Speech/               SpeechInput / SpeechEngine (SFSpeechRecognizer + AVAudioEngine,
                        recreated per recording, AsyncStream updates), HoldToTalkButton
  Strokes/              StrokeLibrary (koneko/Resources/strokes.json, KanjiVG),
                        StrokeOrderView, TracingView, StrokeMatcher, WordStrokesView
  History/              HistoryStore (My words persistence, folders, bulk ops),
                        HistoryView (My words UI), SaveWordBar (Pin/folder on Write)
  Learn/                LearnView, KanaStudyView, KanjiBrowserView, KanjiExplainer,
                        KanjiEmoji, FlashCardSessionView, FlashSetsView, FlashSetStore
                        (+ SymbolSelection), SelectionCheckmark, StudySplit
  Settings/             AppSettings (UserDefaults), Keychain (with macOS legacy fallback),
                        SettingsView, AboutView, WatchSyncController
  Display/              SearchField (shared field style, resetID trick), Clipboard
  CreditsView.swift     licenses
Shared/                 both targets
  WordCandidate         word model (parts with readings, romaji, emoji, meaning)
  Dictionary            HistoryEntry, WordFolder, DictionaryFile (export format), searched()
  CloudSync             WatchSnapshot (LZFSE-compressed JSON in NSUbiquitousKeyValueStore,
                        key "koneko.watchSnapshot.v1", ≤ 1 MB)
  FlashCards, FlashSets FlashDeck/FlashCard/FlashShuffler (shuffled deck), FlashSet
  KanaChart, KanjiLibrary, KanjiGroups   kana table, kanji grades/info (Resources/*.json)
  Pronouncer, AudioSessionQueue          TTS (see §5)
  WritingStyle          display transformation + Klee One handwriting font
  FuriganaText, FlowLayout, SVGPath, CharacterStrokes
  Resources/            kanji_grades.json, kanji_info.json, kana_strokes.json
KonekoWatch/            watch target: KonekoWatchApp, WatchStore, WatchWordListView,
                        WatchWordPager, WatchKanaViews (WatchRoute), WatchFlashViews
Tools/                  Python generators (see §6)
docs/AppleWatch.md      watch setup and run instructions
```

## 4. Data and persistence

- **My words** are stored in `Application Support/history.json` as a `DictionaryFile` with
  `folders` and `entries`.
  - Every mutation goes through `HistoryStore.save()`, which also bumps `revision`; the watch
    sync depends on that.
  - `HistoryEntry.id == WordCandidate.id`.
- **Export/import** uses the same `DictionaryFile` JSON. Import merges folders by name and
  words by id, keeping the best stars. Keep the format backwards-compatible by making new
  fields optional or giving them defaults.
- **Flash-card sets** live in `FlashSetStore`, which also has a `revision`.
- **Settings** are in `UserDefaults` via `AppSettings`. The API key is **only** in the
  Keychain. Never commit keys.
- **Watch sync:**
  - `RootView` watches a sync key built from the history revision, flash-set revision and
    relevant settings, then calls `WatchSyncController`.
  - `WatchSyncController` writes a `WatchSnapshot` to iCloud KVS.
  - The watch reads it in `WatchStore`.
  - When adding a field to `WatchSnapshot`, make it **optional** so older snapshots still
    decode, and add it to the sync key.
- Translations and kanji explanations are cached on the device.

## 5. Hard-won lessons (don't regress these)

- **Audio / TTS:**
  - `AVSpeechSynthesizer.write` renders each utterance to a cached `.caf` file, which is played
    with `AVAudioPlayer` after a 0.12 s lead-in. Speaking live clipped the first syllable.
  - All `AVAudioSession` calls run on the serial `AudioSessionQueue`, off the main thread.
    On the main thread they trigger Xcode "Hang Risk" warnings.
  - Speak from the **kana reading**, so kanji are never misread.
- **Speech input:**
  - Recreate `AVAudioEngine` for every recording; a reused engine gives "microphone not found"
    when another app used audio.
  - Use a supported locale, with a server-recognition fallback.
  - Deliver updates through an ordered `AsyncStream`.
  - Surface errors to the user.
- **Keyboard:**
  - No toolbar "Done" button above the keyboard; the user finds it ugly.
  - Dismiss on submit and use `.scrollDismissesKeyboard(.immediately)` so the tab bar
    isn't trapped.
- **Clear button with the Japanese IME:** clearing the binding doesn't clear marked text, so
  `SearchField` recreates the `TextField` by changing `resetID`.
- **Watch navigation:** one `NavigationStack(path:)` with a typed `WatchRoute` and **only
  value-based** `NavigationLink`s. Mixing destination-based and value-based links popped
  pages back to the list.
- **Furigana:** `FuriganaText` wraps with `FlowLayout` at one consistent font size. Per-part
  `minimumScaleFactor` made mixed sizes and "…" truncation.
- **Kanji search:** `applyingTransform` (hiragana/romaji) is slow ICU work. Never run it per
  kanji per keystroke, and never search inside `body`. `KanjiLibrary` builds a search index
  once in the background, and `KanjiBrowserView` searches in a debounced `.task(id:)`.
- **Mac:** use `.formStyle(.grouped)` in Settings. On Mac the Keychain falls back to the
  legacy keychain.
- **Text:** don't concatenate `Text` with `+` (deprecated); use `HStack` or interpolation.
- **Install errors:** if Xcode tries to install from `Debug-watchos/koneko.app` on the iPhone,
  re-select the `koneko` scheme and the iPhone destination, then Clean Build Folder. It's
  not a code issue.

## 6. Data sources and tools

| Resource | Source | License | Regenerate |
|---|---|---|---|
| `koneko/Resources/strokes.json`, `Shared/Resources/kana_strokes.json` | KanjiVG | CC BY-SA 3.0 | `python3 Tools/build_strokes.py` |
| `Shared/Resources/kanji_grades.json` | KANJIDIC2 via kanji-data | CC BY-SA 4.0 | `python3 Tools/build_kanji_grades.py` |
| `Shared/Resources/kanji_info.json` (meanings, readings, radical) | KANJIDIC2 via kanji-data | CC BY-SA 4.0 | `python3 Tools/build_kanji_info.py` |
| Klee One font | Fontworks | SIL OFL 1.1 | — |
| App icon, mascot | generated | — | `Tools/make_app_icon.py`, `Tools/make_mascot.py` |

Credit any new data in `CreditsView`.

## 7. AI (OpenRouter)

- Chat completions with `response_format` = strict `json_schema`, through
  `OpenRouterClient.requestJSON<Output>`.
- The default model is the first entry of `AppSettings.modelOptions` (a Gemini Flash model).
  It can be changed in Settings.
- Prompts live in `TranslationPrompt` and `KanjiExplainer`. Results must be child-appropriate,
  with an emoji, kana readings per part, and romaji.
- Only the looked-up words are sent. The privacy text in `AboutView` says so; keep it true.

## 8. Working conventions

- **Environment:** development happens in cloud sessions **without Xcode**. You cannot compile.
  - Write code carefully against the build settings above.
  - Push, and let the user build. They report errors and warnings back; fix them precisely
    and minimally.
- **Git:** push to the branch given by the session. Don't open PRs unless asked.
- **Style:** match the surrounding code:
  - short `///` doc comments on types and non-obvious members
  - small private helper views
  - SwiftUI only, `@Observable` models
  - no Combine unless needed
- **Layouts:** check iPhone (compact), iPad (sidebar, `StudySplit` side-by-side) and Mac.
  The watch has its own views.
- **README:** update `README.md` (feature status) when adding a user-visible feature, and this
  file when architecture or rules change.

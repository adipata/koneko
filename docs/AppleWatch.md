# Apple Watch app: setup in Xcode

The code is ready in two folders:

- `Shared/`: code used by both apps (word model, writing styles, furigana, pronunciation,
  My words file format, iCloud sync) and `Resources/kanji_grades.json`.
  Already part of the main **koneko** target.
- `KonekoWatch/`: the watch app (word list, folders, word pages, 🔊 / 🐢).

The main app publishes My words to **iCloud key-value storage** and the watch app reads it.
Both must use the same Apple Account and the same key-value store.

## 1. Main app: bundle ID and iCloud

1. Select the **koneko** project → target **koneko** → **Signing & Capabilities**.
2. Make sure **Bundle Identifier** is a real one, e.g. `com.yourname.koneko`
   (the watch app's ID will be derived from it).
3. Click **+ Capability** → **iCloud** → tick **Key-value storage**
   (leave CloudKit unticked). Do this for both the iOS and macOS variants if Xcode lists
   them separately.

## 2. Create the watch target

1. **File → New → Target… → watchOS → App** → Next.
2. Product Name: **KonekoWatch**. Choose **Watch App for Existing iOS App** and select
   **koneko** as the companion app. Interface: SwiftUI. Uncheck tests. Finish.
   (If Xcode asks to activate the new scheme, choose **Activate**.)
3. Xcode creates a folder such as `KonekoWatch Watch App/` with `ContentView.swift` and an
   app file. **Delete that folder** (Move to Trash): our code in `KonekoWatch/` replaces it.
4. Add our folders to the watch target:
   - Drag the `KonekoWatch` folder from Finder into the project navigator, choose
     **Create folders** (not groups), and tick only the **KonekoWatch Watch App** target.
   - Select the `Shared` folder in the navigator → **File inspector** (right panel) →
     **Target Membership**: tick **KonekoWatch Watch App** as well (keep **koneko** ticked).
5. Watch target → **General** → **Minimum Deployments**: **watchOS 26.0**. Make sure the `KonekoWatch` folder is **not** a member of the **koneko** target (only of the watch target).
6. Watch target → **Build Settings**: make sure **Swift Language Version** and
   **Default Actor Isolation** match the main app (Swift 5, MainActor), so the shared code
   compiles the same way.

## 3. Watch app: iCloud with the same store

1. Watch target → **Signing & Capabilities** → **+ Capability** → **iCloud** → tick
   **Key-value storage**.
2. Xcode creates `KonekoWatch Watch App.entitlements`. Open it and set
   **iCloud Key-Value Store** (`com.apple.developer.ubiquity-kvstore-identifier`) to the
   **main app's** store:

   ```
   $(TeamIdentifierPrefix)com.yourname.koneko
   ```

   (Use the main app's bundle identifier from step 1.) Without this, the watch reads its own,
   empty store.

## 4. Test

1. Run **koneko** on your iPhone (or Mac) → Settings → **Apple Watch** → turn on
   **Sync My words to Apple Watch**. It shows e.g. "Synced 12 words at 10:32 (3 KB)".
2. Select the **KonekoWatch Watch App** scheme and your watch as destination → Run.
3. The words appear on the watch (usually within seconds; iCloud can take a minute).
   Pull down / tap **Refresh** if the list is empty.
4. Open a word: turn the Digital Crown to go to the next one. Tap 🔊 / 🐢 to hear it.

If the watch's Japanese voice sounds robotic, download a better one in the **Watch** app on
the iPhone → Accessibility → Spoken Content (if offered), or tell me and we'll switch to
audio clips recorded on the iPhone.

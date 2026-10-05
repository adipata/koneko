import SwiftUI

/// Her flash-card sets, saved on the device (and synced to the watch with My words).
@Observable
final class FlashSetStore {
    private(set) var sets: [FlashSet] = []
    /// Increases on every change (used to sync to the Apple Watch).
    private(set) var revision = 0
    private let fileURL: URL

    init() {
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appending(path: "flash_sets.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([FlashSet].self, from: data) {
            sets = saved
        }
    }

    @discardableResult
    func add(name: String, symbols: [FlashSymbol]) -> FlashSet {
        let set = FlashSet(name: Self.clean(name, fallback: "My set"), symbols: symbols)
        sets.append(set)
        save()
        return set
    }

    func setSymbols(_ symbols: [FlashSymbol], of id: UUID) {
        guard let index = sets.firstIndex(where: { $0.id == id }) else { return }
        sets[index].symbols = symbols
        save()
    }

    func rename(_ id: UUID, to name: String) {
        guard let index = sets.firstIndex(where: { $0.id == id }) else { return }
        sets[index].name = Self.clean(name, fallback: sets[index].name)
        save()
    }

    func delete(_ id: UUID) {
        sets.removeAll { $0.id == id }
        save()
    }

    func set(_ id: UUID) -> FlashSet? {
        sets.first { $0.id == id }
    }

    private static func clean(_ name: String, fallback: String) -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? fallback : name
    }

    private func save() {
        revision += 1
        if let data = try? JSONEncoder().encode(sets) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

/// "Select" mode in Learn: which symbols are ticked (across hiragana, katakana and kanji),
/// and whether a set is being edited.
struct SymbolSelection: Equatable {
    var items: Set<FlashSymbol> = []
    /// The set being edited (nil = choosing symbols for a new set).
    var editingSetID: UUID?

    func contains(_ kind: FlashSetKind, _ id: String) -> Bool {
        items.contains(FlashSymbol(kind: kind, value: id))
    }

    /// e.g. "5 hiragana · 3 kanji" (empty when nothing is ticked).
    var summary: String {
        FlashSetKind.allCases.compactMap { kind in
            let count = items.filter { $0.kind == kind }.count
            return count == 0 ? nil : "\(count) \(kind.title.lowercased())"
        }
        .joined(separator: " · ")
    }

    mutating func toggle(_ kind: FlashSetKind, _ id: String) {
        let symbol = FlashSymbol(kind: kind, value: id)
        if items.contains(symbol) { items.remove(symbol) } else { items.insert(symbol) }
    }

    /// Ticks all of `ids`, or unticks them all if they were already all ticked.
    mutating func toggleAll(_ kind: FlashSetKind, _ ids: [String]) {
        let symbols = ids.map { FlashSymbol(kind: kind, value: $0) }
        if symbols.allSatisfy(items.contains) {
            items.subtract(symbols)
        } else {
            items.formUnion(symbols)
        }
    }

    /// Whether every one of `ids` is ticked.
    func containsAll(_ kind: FlashSetKind, _ ids: [String]) -> Bool {
        !ids.isEmpty && ids.allSatisfy { contains(kind, $0) }
    }
}

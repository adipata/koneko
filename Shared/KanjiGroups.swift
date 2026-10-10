/// How kanji are grouped in Learn → Kanji.
///
/// Grades 1 and 2 use hand-made themes (numbers, nature, family…). From grade 3 on, kanji are
/// grouped by their radical ("family"), e.g. all kanji with 氵 (water) together.
struct KanjiGroup: Identifiable {
    let emoji: String
    let title: String
    let kanji: [KanjiInfo]
    var id: String { title }
}

struct KanjiGroupDefinition {
    let emoji: String
    let title: String
    let kanji: String
}

enum KanjiGroups {
    static let themes: [Int: [KanjiGroupDefinition]] = [
        1: [
            KanjiGroupDefinition(emoji: "🔢", title: "Numbers & money", kanji: "一二三四五六七八九十百千円"),
            KanjiGroupDefinition(emoji: "🌤️", title: "Nature & weather", kanji: "日月火水木金土山川田林森石空天雨夕気"),
            KanjiGroupDefinition(emoji: "🌸", title: "Plants & animals", kanji: "花草竹虫犬貝"),
            KanjiGroupDefinition(emoji: "🧒", title: "People", kanji: "人女男子王先名生"),
            KanjiGroupDefinition(emoji: "✋", title: "Body", kanji: "口目耳手足力"),
            KanjiGroupDefinition(emoji: "🧭", title: "Where", kanji: "上下中右左"),
            KanjiGroupDefinition(emoji: "🎨", title: "Colors & describing", kanji: "赤青白大小正早"),
            KanjiGroupDefinition(emoji: "🏫", title: "School & town", kanji: "学校字文本車町村音"),
            KanjiGroupDefinition(emoji: "🧵", title: "Things & time", kanji: "玉糸年"),
            KanjiGroupDefinition(emoji: "🏃", title: "Actions", kanji: "入出休見立"),
        ],
        2: [
            KanjiGroupDefinition(emoji: "🔢", title: "Numbers & amounts", kanji: "万半分数多少毎番回"),
            KanjiGroupDefinition(emoji: "📅", title: "Time & seasons", kanji: "今午春夏秋冬朝昼夜時週曜間"),
            KanjiGroupDefinition(emoji: "🧭", title: "Directions & places", kanji: "東西南北内外前後近遠方角"),
            KanjiGroupDefinition(emoji: "🌤️", title: "Nature & weather", kanji: "星光晴雪雲風電海池谷岩原野地里汽"),
            KanjiGroupDefinition(emoji: "🐾", title: "Animals", kanji: "牛馬魚鳥鳴羽毛"),
            KanjiGroupDefinition(emoji: "🍚", title: "Food", kanji: "米麦肉茶食"),
            KanjiGroupDefinition(emoji: "👪", title: "Family & people", kanji: "父母兄弟姉妹親友自"),
            KanjiGroupDefinition(emoji: "✋", title: "Body & heart", kanji: "体頭顔首心声"),
            KanjiGroupDefinition(emoji: "🏠", title: "Home & town", kanji: "家室戸門店市寺社京国園場台公道通船工"),
            KanjiGroupDefinition(emoji: "📚", title: "School & words", kanji: "教書読話語言記計算答図画絵紙線科理知考思聞歌楽点"),
            KanjiGroupDefinition(emoji: "🎨", title: "Colors & describing", kanji: "黄黒色形丸細太長高広強弱新古明同直当"),
            KanjiGroupDefinition(emoji: "🏃", title: "Actions", kanji: "行来帰走歩止売買引切作用会合交活組"),
            KanjiGroupDefinition(emoji: "🏹", title: "Tools", kanji: "刀弓矢"),
            KanjiGroupDefinition(emoji: "✨", title: "Other", kanji: "何元才"),
        ],
    ]

    /// Radical families: radical → (emoji, name). Variants are merged when the data is built.
    static let families: [String: (emoji: String, name: String)] = [
        "氵": ("💧", "Water 氵"), "亻": ("🧍", "Person 亻"), "扌": ("✋", "Hand 扌"),
        "木": ("🌳", "Tree 木"), "言": ("💬", "Words 言"), "糸": ("🧵", "Thread 糸"),
        "⻌": ("🛣️", "Road 辶"), "艹": ("🌿", "Grass 艹"), "口": ("👄", "Mouth 口"),
        "土": ("🟫", "Earth 土"), "月": ("🌙", "Moon / body 月"), "宀": ("🏠", "Roof 宀"),
        "忄": ("❤️", "Heart 心"), "金": ("🪙", "Metal 金"), "⻖": ("⛰️", "Hill 阝"),
        "女": ("👩", "Woman 女"), "日": ("☀️", "Sun 日"), "貝": ("🐚", "Shell / money 貝"),
        "竹": ("🎋", "Bamboo 竹"), "禾": ("🌾", "Grain 禾"), "彳": ("🚶", "Going 彳"),
        "刂": ("🔪", "Knife 刂"), "尸": ("🚩", "Flag 尸"), "广": ("🏛️", "Building 广"),
        "疒": ("🤒", "Sickness 疒"), "力": ("💪", "Power 力"), "石": ("🪨", "Stone 石"),
        "頁": ("🗣️", "Head 頁"), "⺨": ("🐾", "Animal 犭"), "酉": ("🏺", "Jar 酉"),
        "山": ("⛰️", "Mountain 山"), "⻏": ("🏘️", "Town 阝"), "火": ("🔥", "Fire 火"),
        "王": ("💎", "Jewel 王"), "礻": ("⛩️", "Spirit 礻"), "足": ("🦶", "Foot 足"),
        "車": ("🚗", "Vehicle 車"), "巾": ("🧣", "Cloth 巾"), "攵": ("👊", "Action 攵"),
        "目": ("👁️", "Eye 目"), "穴": ("🕳️", "Hole 穴"), "米": ("🍚", "Rice 米"),
        "衤": ("👕", "Clothes 衣"), "門": ("🚪", "Gate 門"), "雨": ("🌧️", "Rain 雨"),
        "馬": ("🐴", "Horse 馬"), "大": ("🐘", "Big 大"), "飠": ("🍽️", "Food 食"),
        "囗": ("🔲", "Enclosure 囗"), "田": ("🌾", "Field 田"), "罒": ("🕸️", "Net 罒"),
        "舟": ("⛵", "Boat 舟"), "一": ("➖", "One 一"), "冫": ("🧊", "Ice 冫"),
        "皿": ("🥣", "Dish 皿"), "隹": ("🐦", "Bird 隹"), "又": ("🤲", "Again 又"),
        "弓": ("🏹", "Bow 弓"), "戸": ("🚪", "Door 戸"), "方": ("🧭", "Direction 方"),
        "欠": ("🥱", "Yawn 欠"), "牛": ("🐄", "Cow 牛"), "羊": ("🐑", "Sheep 羊"),
        "虍": ("🐯", "Tiger 虍"), "虫": ("🐛", "Insect 虫"), "走": ("🏃", "Run 走"),
        "子": ("🧒", "Child 子"), "寸": ("📏", "Inch 寸"), "羽": ("🪶", "Feather 羽"),
    ]

    /// Kanji of a grade in groups, in a sensible order.
    static func groups(for kanji: [KanjiInfo], grade: Int) -> [KanjiGroup] {
        let byCharacter = Dictionary(uniqueKeysWithValues: kanji.map { ($0.character, $0) })

        if let themes = themes[grade] {
            var used = Set<String>()
            var groups = themes.map { theme in
                let members = theme.kanji.compactMap { byCharacter[String($0)] }
                used.formUnion(members.map(\.character))
                return KanjiGroup(emoji: theme.emoji, title: theme.title, kanji: members)
            }
            let rest = kanji.filter { !used.contains($0.character) }
            if !rest.isEmpty {
                groups.append(KanjiGroup(emoji: "✨", title: "More", kanji: rest))
            }
            return groups.filter { !$0.kanji.isEmpty }
        }

        // By radical family: families with at least 4 kanji in this grade get their own group,
        // biggest first; the rest go to "Other shapes".
        let byFamily = Dictionary(grouping: kanji) { $0.radical ?? "" }
        var groups: [KanjiGroup] = []
        var other: [KanjiInfo] = []
        for (radical, members) in byFamily.sorted(by: { ($1.value.count, $0.key) < ($0.value.count, $1.key) }) {
            if let family = families[radical], members.count >= 4 {
                groups.append(KanjiGroup(emoji: family.emoji, title: family.name, kanji: members))
            } else {
                other += members
            }
        }
        if !other.isEmpty {
            groups.append(KanjiGroup(emoji: "✨", title: "Other shapes", kanji: other.sorted { $0.strokes < $1.strokes }))
        }
        return groups
    }
}

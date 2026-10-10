import SwiftUI

/// Parses SVG path data (the `d` attribute) into a SwiftUI `Path`.
/// Supports M, L, H, V, C, S, Q, T and Z in absolute and relative form,
/// which covers everything KanjiVG uses.
nonisolated enum SVGPath {
    static func parse(_ data: String) -> Path {
        var path = Path()
        var tokens = PathTokenizer(data)
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastCubicControl: CGPoint?
        var lastQuadControl: CGPoint?
        var command: UInt8 = 0

        while true {
            if let next = tokens.nextCommand() {
                command = next
            } else if command == 0 || !tokens.hasNumber() {
                break
            }

            let relative = command >= UInt8(ascii: "a")
            let origin = relative ? current : .zero
            var cubicControl: CGPoint?
            var quadControl: CGPoint?

            switch command | 0x20 { // lowercase
            case UInt8(ascii: "m"):
                guard let p = tokens.point() else { return path }
                current = p + origin
                subpathStart = current
                path.move(to: current)
                command = relative ? UInt8(ascii: "l") : UInt8(ascii: "L") // implicit lineto
            case UInt8(ascii: "l"):
                guard let p = tokens.point() else { return path }
                current = p + origin
                path.addLine(to: current)
            case UInt8(ascii: "h"):
                guard let x = tokens.number() else { return path }
                current.x = relative ? current.x + x : x
                path.addLine(to: current)
            case UInt8(ascii: "v"):
                guard let y = tokens.number() else { return path }
                current.y = relative ? current.y + y : y
                path.addLine(to: current)
            case UInt8(ascii: "c"):
                guard let c1 = tokens.point(), let c2 = tokens.point(), let end = tokens.point() else { return path }
                cubicControl = c2 + origin
                current = end + origin
                path.addCurve(to: current, control1: c1 + origin, control2: cubicControl!)
            case UInt8(ascii: "s"):
                guard let c2 = tokens.point(), let end = tokens.point() else { return path }
                let c1 = lastCubicControl.map { current.reflecting($0) } ?? current
                cubicControl = c2 + origin
                current = end + origin
                path.addCurve(to: current, control1: c1, control2: cubicControl!)
            case UInt8(ascii: "q"):
                guard let c = tokens.point(), let end = tokens.point() else { return path }
                quadControl = c + origin
                current = end + origin
                path.addQuadCurve(to: current, control: quadControl!)
            case UInt8(ascii: "t"):
                guard let end = tokens.point() else { return path }
                quadControl = lastQuadControl.map { current.reflecting($0) } ?? current
                current = end + origin
                path.addQuadCurve(to: current, control: quadControl!)
            case UInt8(ascii: "z"):
                path.closeSubpath()
                current = subpathStart
                command = 0 // a new command letter must follow
            default:
                return path
            }
            lastCubicControl = cubicControl
            lastQuadControl = quadControl
        }
        return path
    }
}

private nonisolated struct PathTokenizer {
    private let bytes: [UInt8]
    private var index = 0

    init(_ string: String) {
        bytes = Array(string.utf8)
    }

    mutating func nextCommand() -> UInt8? {
        skipSeparators()
        guard index < bytes.count else { return nil }
        let byte = bytes[index]
        let isLetter = (byte | 0x20) >= UInt8(ascii: "a") && (byte | 0x20) <= UInt8(ascii: "z")
        guard isLetter, byte | 0x20 != UInt8(ascii: "e") else { return nil }
        index += 1
        return byte
    }

    mutating func hasNumber() -> Bool {
        skipSeparators()
        guard index < bytes.count else { return false }
        let byte = bytes[index]
        return isDigit(byte) || byte == UInt8(ascii: "-") || byte == UInt8(ascii: "+") || byte == UInt8(ascii: ".")
    }

    mutating func point() -> CGPoint? {
        guard let x = number(), let y = number() else { return nil }
        return CGPoint(x: x, y: y)
    }

    mutating func number() -> CGFloat? {
        skipSeparators()
        let start = index
        if index < bytes.count, bytes[index] == UInt8(ascii: "-") || bytes[index] == UInt8(ascii: "+") {
            index += 1
        }
        var sawDigit = false
        var sawDot = false
        while index < bytes.count {
            let byte = bytes[index]
            if isDigit(byte) {
                sawDigit = true
            } else if byte == UInt8(ascii: "."), !sawDot {
                sawDot = true
            } else {
                break
            }
            index += 1
        }
        if sawDigit, index < bytes.count, bytes[index] | 0x20 == UInt8(ascii: "e") {
            var lookahead = index + 1
            if lookahead < bytes.count, bytes[lookahead] == UInt8(ascii: "-") || bytes[lookahead] == UInt8(ascii: "+") {
                lookahead += 1
            }
            if lookahead < bytes.count, isDigit(bytes[lookahead]) {
                index = lookahead
                while index < bytes.count, isDigit(bytes[index]) { index += 1 }
            }
        }
        guard sawDigit, let value = Double(String(decoding: bytes[start..<index], as: UTF8.self)) else {
            index = start
            return nil
        }
        return CGFloat(value)
    }

    private mutating func skipSeparators() {
        while index < bytes.count, [0x20, 0x2C, 0x09, 0x0A, 0x0D].contains(bytes[index]) {
            index += 1
        }
    }

    private func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }
}

private nonisolated extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    /// Mirror `control` through this point (used by the S and T shorthands).
    func reflecting(_ control: CGPoint) -> CGPoint {
        CGPoint(x: 2 * x - control.x, y: 2 * y - control.y)
    }
}

import Foundation
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

extension DeclModifierSyntax {
    var isNeededAccessLevelModifier: Bool {
        switch self.name.tokenKind {
        case .keyword(.public): return true
        default: return false
        }
    }
}

extension SyntaxStringInterpolation {
    // It would be nice for SwiftSyntaxBuilder to provide this out-of-the-box.
    mutating func appendInterpolation<Node: SyntaxProtocol>(_ node: Node?) {
        if let node {
            appendInterpolation(node)
        }
    }
}

extension String.StringInterpolation {
    mutating func appendInterpolation<Node: SyntaxProtocol>(_ node: Node?) {
        if let node {
            appendInterpolation(node)
        }
    }
}

extension EnumDeclSyntax {
    var cases: [EnumCaseElementSyntax] {
        memberBlock.members.flatMap { member in
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
                return Array<EnumCaseElementSyntax>()
            }

            return Array(caseDecl.elements)
        }
    }
}

extension SyntaxProtocol {
  func tryCast<S: SyntaxProtocol>(_ syntaxType: S.Type) throws -> S {
      if let t = self.as(S.self) {
          return t
      } else {
          throw CustomError.message("Cast fail to \(syntaxType) from \(self)")
      }
  }
}

extension Optional {
    func tryUnwrap(file: StaticString = #file, function: StaticString = #function, line: Int = #line) throws -> Wrapped {
        switch self {
        case .some(let value):
            return value
        case .none:
            throw CustomError.message("Unwrap fail for \(Self.self). file: \(file), function: \(function), line: \(line)")
        }
    }
}

extension StringLiteralSegmentsSyntax.Element {
    var text: String {
        get throws {
            switch self {
            case .stringSegment(let stringSyntax):
                return stringSyntax.content.text
            case .expressionSegment(_):
                throw CustomError.message("StringLiteralSegmentsSyntax.Element necessary stringSegment")
            }
        }
    }
}

struct Backported<Base> {
    let base: Base
}
extension String {
    var backported: Backported<String> { .init(base: self) }
}

extension Backported where Base == String {
    
    func trimmingPrefix(while condition: (Character) -> Bool) -> String {
        var startIndex = base.startIndex
        
        while startIndex < base.endIndex && condition(base[startIndex]) {
            startIndex = base.index(after: startIndex)
        }
        
        return String(base[startIndex...])
    }
}

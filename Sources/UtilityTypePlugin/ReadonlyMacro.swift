import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

public struct ReadonlyMacro: MemberMacro {
    public static func expansion<Declaration, Context>(
        of node: AttributeSyntax,
        providingMembersOf declaration: Declaration,
        in context: Context
    ) throws -> [DeclSyntax] where Declaration : DeclGroupSyntax, Context : MacroExpansionContext {
        let _macros: [String]?
        if case .argumentList(let arguments) = node.arguments, let macrosIndex = arguments.firstIndex(where: { $0.label?.text == "macros"}) {
            _macros = arguments[macrosIndex...]
                .map(\.expression)
                .compactMap { $0.as(StringLiteralExprSyntax.self) }
                .flatMap { $0.segments.children(viewMode: .all) }
                .compactMap { $0.as(StringSegmentSyntax.self) }
                .flatMap { $0.tokens(viewMode: .all) }
                .map(\.text)
        } else {
            _macros = nil
        }
        let macros = _macros?.joined(separator: "\n") ?? ""

        switch declaration.kind {
        case .structDecl:
            guard let declaration = declaration.as(StructDeclSyntax.self) else {
                fatalError("Unexpected cast fail when kind == .structDecl")
            }

            let structName = declaration.name.text
            let structVariableName = structName.prefix(1).lowercased() + structName.suffix(structName.count - 1)

            let access = declaration.modifiers.first(where: \.isNeededAccessLevelModifier)
            let structProperties = declaration.memberBlock.members.children(viewMode: .all)
                .compactMap { $0.as(MemberBlockItemSyntax.self) }
                .compactMap { $0.decl.as(VariableDeclSyntax.self) }
                .compactMap { $0.bindings.as(PatternBindingListSyntax.self) }
                .compactMap {
                    $0.children(viewMode: .all)
                        .compactMap { $0.as(PatternBindingSyntax.self) }
                        // Ignore readonly proeperty
                        .filter { $0.accessorBlock == nil }
                }
                .flatMap { $0 }

            let structRawProperties = structProperties
                .map { structProperty in
                    return "\(access)let \(structProperty)"
                }
                .joined()
            let assignedToSelfPropertyStatementsFromDeclaration = structProperties
                .compactMap { structProperty -> (selfProperty: String, declarationProperty: String)? in
                    guard let property = structProperty.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                        return nil
                    }

                    return (selfProperty: property, declarationProperty: property)
                }
                .map { (selfProperty, declarationProperty) in
                    return "self.\(selfProperty) = \(structVariableName).\(declarationProperty)"
                }
                .joined(separator: "\n")
            let eachInitArgument = structProperties
                .map(\.description)
                .joined(separator: ", ")
            let assignedToSelfPropertyStatementsFromRawProperty = structProperties
                .compactMap { structProperty in
                    structProperty.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
                }
                .map {
                    "self.\($0) = \($0)"
                }
                .joined(separator: "\n")

            let syntax = try StructDeclSyntax("\(raw: macros)\(access)struct Readonly", membersBuilder: {
                DeclSyntax("\(raw: structRawProperties)")
                try InitializerDeclSyntax("\(access)init(\(raw: structVariableName): \(raw: structName))") {
                    DeclSyntax("\(raw: assignedToSelfPropertyStatementsFromDeclaration)")
                }
                try InitializerDeclSyntax("\(access)init(\(raw: eachInitArgument))") {
                    DeclSyntax("\(raw: assignedToSelfPropertyStatementsFromRawProperty)")
                }
            })
            return [syntax.cast(DeclSyntax.self)]
        case .classDecl:
            guard let declaration = declaration.as(ClassDeclSyntax.self) else {
                fatalError("Unexpected cast fail when kind == .classDecl")
            }

            let className = declaration.name.text
            let classVariableName = className.prefix(1).lowercased() + className.suffix(className.count - 1)

            let access = declaration.modifiers.first(where: \.isNeededAccessLevelModifier)
            let classProperties = declaration.memberBlock.members.children(viewMode: .all)
                .compactMap { $0.as(MemberBlockItemSyntax.self) }
                .compactMap { $0.decl.as(VariableDeclSyntax.self) }
                .compactMap { $0.bindings.as(PatternBindingListSyntax.self) }
                .compactMap {
                    $0.children(viewMode: .all)
                        .compactMap { $0.as(PatternBindingSyntax.self) }
                    // Ignore readonly proeperty
                        .filter { $0.accessorBlock == nil }
                }
                .flatMap { $0 }

            let classRawProperties = classProperties
                .map { classProperty in
                    return "\(access)let \(classProperty)"
                }
                .joined()
            let assignedToSelfPropertyStatementsFromDeclaration = classProperties
                .compactMap { classProperty -> (selfProperty: String, declarationProperty: String)? in
                    guard let property = classProperty.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                        return nil
                    }

                    return (selfProperty: property, declarationProperty: property)
                }
                .map { (selfProperty, declarationProperty) in
                    return "self.\(selfProperty) = \(classVariableName).\(declarationProperty)"
                }
                .joined(separator: "\n")
            let eachInitArgument = classProperties
                .map(\.description)
                .joined(separator: ", ")
            let assignedToSelfPropertyStatementsFromRawProperty = classProperties
                .compactMap { classProperty in
                    classProperty.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
                }
                .map {
                    "self.\($0) = \($0)"
                }
                .joined(separator: "\n")

            let syntax = try ClassDeclSyntax("\(access)class Readonly", membersBuilder: {
                DeclSyntax("\(raw: classRawProperties)")
                try InitializerDeclSyntax("\(access)init(\(raw: classVariableName): \(raw: className))") {
                    DeclSyntax("\(raw: assignedToSelfPropertyStatementsFromDeclaration)")
                }
                try InitializerDeclSyntax("\(access)init(\(raw: eachInitArgument))") {
                    DeclSyntax("\(raw: assignedToSelfPropertyStatementsFromRawProperty)")
                }
            })
            return [syntax.cast(DeclSyntax.self)]
        case _:
            throw CustomError.message("@Required can only be applied to a struct or class declarations.")
        }
    }
}

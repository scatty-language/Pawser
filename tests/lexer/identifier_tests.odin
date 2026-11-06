// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

package tests

import "core:testing"
import pawser "../../src"

// Verifies that public, internal, private, and local identifiers are correctly categorized and hashed.
@(test)
identifier_test_valid_categories :: proc(test_context: ^testing.T) {
    source_code: string = "DataName Vector HttpResponse A1 Engine_ Helper1_ _cacheSize _x _item1 index rawValue count sum min max"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)

    // Public identifiers
    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.PublicIdentifier)
    testing.expect_value(test_context, pawser.token_extract_clean_identifier(lexed_file.tokens[0], source_code), "DataName")
    testing.expect_value(test_context, lexed_file.tokens[0].identifier_hash, pawser.hash_compute_fnv1a64("DataName"))

    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.PublicIdentifier)
    testing.expect_value(test_context, pawser.token_extract_clean_identifier(lexed_file.tokens[1], source_code), "Vector")

    testing.expect_value(test_context, lexed_file.tokens[2].kind, pawser.TokenKind.PublicIdentifier)
    testing.expect_value(test_context, pawser.token_extract_clean_identifier(lexed_file.tokens[2], source_code), "HttpResponse")

    testing.expect_value(test_context, lexed_file.tokens[3].kind, pawser.TokenKind.PublicIdentifier)
    testing.expect_value(test_context, pawser.token_extract_clean_identifier(lexed_file.tokens[3], source_code), "A1")

    // Internal identifiers
    testing.expect_value(test_context, lexed_file.tokens[4].kind, pawser.TokenKind.InternalIdentifier)
    testing.expect_value(test_context, pawser.token_extract_clean_identifier(lexed_file.tokens[4], source_code), "Engine_")
    testing.expect_value(test_context, lexed_file.tokens[4].identifier_hash, pawser.hash_compute_fnv1a64("Engine_"))

    testing.expect_value(test_context, lexed_file.tokens[5].kind, pawser.TokenKind.InternalIdentifier)
    testing.expect_value(test_context, pawser.token_extract_clean_identifier(lexed_file.tokens[5], source_code), "Helper1_")

    // Private identifiers
    testing.expect_value(test_context, lexed_file.tokens[6].kind, pawser.TokenKind.PrivateIdentifier)
    testing.expect_value(test_context, pawser.token_extract_clean_identifier(lexed_file.tokens[6], source_code), "_cacheSize")
    testing.expect_value(test_context, lexed_file.tokens[6].identifier_hash, pawser.hash_compute_fnv1a64("_cacheSize"))

    testing.expect_value(test_context, lexed_file.tokens[7].kind, pawser.TokenKind.PrivateIdentifier)
    testing.expect_value(test_context, pawser.token_extract_clean_identifier(lexed_file.tokens[7], source_code), "_x")

    testing.expect_value(test_context, lexed_file.tokens[8].kind, pawser.TokenKind.PrivateIdentifier)
    testing.expect_value(test_context, pawser.token_extract_clean_identifier(lexed_file.tokens[8], source_code), "_item1")

    // Local identifiers
    testing.expect_value(test_context, lexed_file.tokens[9].kind, pawser.TokenKind.LocalIdentifier)
    testing.expect_value(test_context, pawser.token_extract_clean_identifier(lexed_file.tokens[9], source_code), "index")
    testing.expect_value(test_context, lexed_file.tokens[9].identifier_hash, pawser.hash_compute_fnv1a64("index"))

    testing.expect_value(test_context, lexed_file.tokens[10].kind, pawser.TokenKind.LocalIdentifier)
    testing.expect_value(test_context, pawser.token_extract_clean_identifier(lexed_file.tokens[10], source_code), "rawValue")

    // Out reducers (must be LocalIdentifier, but recognized by token_is_out_reducer)
    for token_index in 11 ..= 14 {
        token: pawser.Token = lexed_file.tokens[token_index]
        testing.expect_value(test_context, token.kind, pawser.TokenKind.LocalIdentifier)
        testing.expect(test_context, pawser.token_is_out_reducer(token, source_code), "Must be recognized as an out reducer")
    }
}

// Verifies that escaped keywords strip backticks for clean symbol names and compute hashes on the stripped names.
@(test)
identifier_test_escaped_keywords :: proc(test_context: ^testing.T) {
    source_code: string = "`match` `spawn` `must`"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)

    // First escaped identifier: `match`
    token_match: pawser.Token = lexed_file.tokens[0]
    testing.expect_value(test_context, token_match.kind, pawser.TokenKind.EscapedIdentifier)
    testing.expect_value(test_context, pawser.token_extract_lexeme(token_match, source_code), "`match`")
    testing.expect_value(test_context, pawser.token_extract_clean_identifier(token_match, source_code), "match")
    testing.expect_value(test_context, token_match.identifier_hash, pawser.hash_compute_fnv1a64("match"))

    // Second escaped identifier: `spawn`
    token_spawn: pawser.Token = lexed_file.tokens[1]
    testing.expect_value(test_context, token_spawn.kind, pawser.TokenKind.EscapedIdentifier)
    testing.expect_value(test_context, pawser.token_extract_clean_identifier(token_spawn, source_code), "spawn")
    testing.expect_value(test_context, token_spawn.identifier_hash, pawser.hash_compute_fnv1a64("spawn"))

    // Third escaped identifier: `must`
    token_must: pawser.Token = lexed_file.tokens[2]
    testing.expect_value(test_context, token_must.kind, pawser.TokenKind.EscapedIdentifier)
    testing.expect_value(test_context, pawser.token_extract_clean_identifier(token_must, source_code), "must")
    testing.expect_value(test_context, token_must.identifier_hash, pawser.hash_compute_fnv1a64("must"))
}

// Verifies that illegal identifier formats and invalid/unclosed escaped keywords emit diagnostics and produce malformed tokens.
@(test)
identifier_test_malformed_formats :: proc(test_context: ^testing.T) {
    source_code: string = "_Data Data__ user_age _123 `notakeyword` `unclosed"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.tokens), 7) // 6 malformed tokens + 1 EOF

    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.MalformedIdentifier)
    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.MalformedIdentifier)
    testing.expect_value(test_context, lexed_file.tokens[2].kind, pawser.TokenKind.MalformedIdentifier)
    testing.expect_value(test_context, lexed_file.tokens[3].kind, pawser.TokenKind.MalformedIdentifier)
    testing.expect_value(test_context, lexed_file.tokens[4].kind, pawser.TokenKind.MalformedIdentifier)
    testing.expect_value(test_context, lexed_file.tokens[5].kind, pawser.TokenKind.MalformedIdentifier)

    testing.expect(test_context, len(lexed_file.diagnostics) >= 6, "Expected diagnostics for each malformed identifier")
    testing.expect_value(test_context, lexed_file.diagnostics[0].code, pawser.LexerErrorCode.InvalidIdentifierFormat)
    testing.expect_value(test_context, lexed_file.diagnostics[1].code, pawser.LexerErrorCode.InvalidIdentifierFormat)
    testing.expect_value(test_context, lexed_file.diagnostics[2].code, pawser.LexerErrorCode.InvalidIdentifierFormat)
    testing.expect_value(test_context, lexed_file.diagnostics[3].code, pawser.LexerErrorCode.InvalidIdentifierFormat)
    testing.expect_value(test_context, lexed_file.diagnostics[4].code, pawser.LexerErrorCode.InvalidEscapedIdentifier)
    testing.expect_value(test_context, lexed_file.diagnostics[5].code, pawser.LexerErrorCode.UnterminatedEscapedIdentifier)
}

// Verifies that every reserved keyword, primitive type, and literal keyword maps to its dedicated token kind.
@(test)
identifier_test_keywords_and_primitive_types :: proc(test_context: ^testing.T) {
    source_code: string = "Int Uint Long Ulong Size Usize Byte Float Double Bool Char Rune String RuneString true false concurrent spawn rollback throws unsafe must may then where in by out break continue match fall try catch throw undo return use with ref weak soa embed static astatic gstatic equality math tag bitwidth zeroed noinit strict none fn as unas is and or not band bor bxor bnot bsl bsr"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    expected_kinds := []pawser.TokenKind{
        .PrimitiveInteger,
        .PrimitiveUnsignedInteger,
        .PrimitiveLong,
        .PrimitiveUnsignedLong,
        .PrimitiveSize,
        .PrimitiveUnsignedSize,
        .PrimitiveByte,
        .PrimitiveFloat,
        .PrimitiveDouble,
        .PrimitiveBoolean,
        .PrimitiveCharacter,
        .PrimitiveRune,
        .PrimitiveString,
        .PrimitiveRuneString,
        .BooleanLiteralTrue,
        .BooleanLiteralFalse,
        .KeywordConcurrent,
        .KeywordSpawn,
        .KeywordRollback,
        .KeywordThrows,
        .KeywordUnsafe,
        .KeywordMust,
        .KeywordMay,
        .KeywordThen,
        .KeywordWhere,
        .KeywordIn,
        .KeywordBy,
        .KeywordOut,
        .KeywordBreak,
        .KeywordContinue,
        .KeywordMatch,
        .KeywordFall,
        .KeywordTry,
        .KeywordCatch,
        .KeywordThrow,
        .KeywordUndo,
        .KeywordReturn,
        .KeywordUse,
        .KeywordWith,
        .KeywordReference,
        .KeywordWeak,
        .KeywordStructureOfArrays,
        .KeywordEmbed,
        .KeywordStatic,
        .KeywordAtomicStatic,
        .KeywordGlobalStatic,
        .KeywordEquality,
        .KeywordMath,
        .KeywordTag,
        .KeywordBitwidth,
        .KeywordZeroed,
        .KeywordNoInitialization,
        .KeywordStrict,
        .KeywordNone,
        .KeywordFunction,
        .KeywordAs,
        .KeywordUncheckedAs,
        .KeywordIs,
        .KeywordAnd,
        .KeywordOr,
        .KeywordNot,
        .KeywordBitwiseAnd,
        .KeywordBitwiseOr,
        .KeywordBitwiseXor,
        .KeywordBitwiseNot,
        .KeywordBitwiseShiftLeft,
        .KeywordBitwiseShiftRight,
    }

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_file.tokens), len(expected_kinds) + 1)
    for expected_index in 0 ..< len(expected_kinds) {
        testing.expect_value(test_context, lexed_file.tokens[expected_index].kind, expected_kinds[expected_index])
        testing.expect(test_context, pawser.token_is_keyword(lexed_file.tokens[expected_index]), "Expected keyword token")
    }
}

// Verifies that a lone underscore is a structural token rather than an identifier.
@(test)
identifier_test_lone_underscore :: proc(test_context: ^testing.T) {
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source("_")
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_file.tokens), 2)
    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.Underscore)
}

// Verifies that valid Unicode characters cannot become part of an identifier.
@(test)
identifier_test_unicode_characters_are_forbidden :: proc(test_context: ^testing.T) {
    source_code: string = "café DataЯ _а"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    unexpected_character_count: int = 0
    malformed_utf8_count: int = 0
    for diagnostic in lexed_file.diagnostics {
        if diagnostic.code == .UnexpectedCharacter {
            unexpected_character_count += 1
        }
        if diagnostic.code == .MalformedUtf8Sequence {
            malformed_utf8_count += 1
        }
    }

    testing.expect_value(test_context, unexpected_character_count, 3)
    testing.expect_value(test_context, malformed_utf8_count, 0)
}

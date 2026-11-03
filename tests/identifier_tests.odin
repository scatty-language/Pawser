package tests

import "core:testing"
import pawser "../src"

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

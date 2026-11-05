package tests

import "core:testing"
import pawser "../../src"

// Verifies that line comments and arbitrarily nested block comments are stripped without breaking tokenization.
@(test)
comment_test_line_and_nested_blocks :: proc(test_context: ^testing.T) {
    source_code: string = "// Single line comment\nidentifierOne /* outer /* nested */ still outer */ identifierTwo"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_file.tokens), 3) // identifierOne, identifierTwo, EOF

    token_first: pawser.Token = lexed_file.tokens[0]
    testing.expect_value(test_context, token_first.kind, pawser.TokenKind.LocalIdentifier)
    testing.expect_value(test_context, pawser.token_extract_lexeme(token_first, source_code), "identifierOne")
    testing.expect(test_context, pawser.TokenFlag.PrecededByNewline in token_first.flags, "Expected PrecededByNewline flag")

    token_second: pawser.Token = lexed_file.tokens[1]
    testing.expect_value(test_context, token_second.kind, pawser.TokenKind.LocalIdentifier)
    testing.expect_value(test_context, pawser.token_extract_lexeme(token_second, source_code), "identifierTwo")
    testing.expect(test_context, pawser.TokenFlag.PrecededByWhitespace in token_second.flags, "Expected PrecededByWhitespace flag")
}

// Verifies that an unclosed nested block comment emits an UnterminatedBlockComment diagnostic.
@(test)
comment_test_unclosed_block_comment :: proc(test_context: ^testing.T) {
    source_code: string = "/* outer /* nested */ unclosed"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect(test_context, len(lexed_file.diagnostics) >= 1, "Expected UnterminatedBlockComment diagnostic")
    testing.expect_value(test_context, lexed_file.diagnostics[0].code, pawser.LexerErrorCode.UnterminatedBlockComment)
}

// Verifies that a UTF-8 Byte Order Mark at the start of a file emits a ByteOrderMarkForbidden diagnostic and continues tokenizing.
@(test)
utf8_test_byte_order_mark :: proc(test_context: ^testing.T) {
    source_code: string = "\xEF\xBB\xBFValue := 42;"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect(test_context, len(lexed_file.diagnostics) >= 1, "Expected ByteOrderMarkForbidden diagnostic")
    testing.expect_value(test_context, lexed_file.diagnostics[0].code, pawser.LexerErrorCode.ByteOrderMarkForbidden)

    // Verify subsequent tokens are scanned correctly
    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.PublicIdentifier)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[0], source_code), "Value")

    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.ColonAssign)
    testing.expect_value(test_context, lexed_file.tokens[2].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, lexed_file.tokens[3].kind, pawser.TokenKind.Semicolon)
}

// Verifies that invalid UTF-8 byte sequences emit MalformedUtf8Sequence diagnostics and recover smoothly.
@(test)
utf8_test_invalid_byte_sequences :: proc(test_context: ^testing.T) {
    source_code: string = "alpha \xFF beta"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect(test_context, len(lexed_file.diagnostics) >= 1, "Expected MalformedUtf8Sequence diagnostic")
    testing.expect_value(test_context, lexed_file.diagnostics[0].code, pawser.LexerErrorCode.MalformedUtf8Sequence)

    // Should still tokenize alpha and beta
    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.LocalIdentifier)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[0], source_code), "alpha")

    testing.expect_value(test_context, lexed_file.tokens[2].kind, pawser.TokenKind.LocalIdentifier)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[2], source_code), "beta")
}

// Verifies that malformed UTF-8 sequences inside escaped identifiers and at the tail of unclosed raw strings are diagnosed.
@(test)
utf8_test_invalid_bytes_in_escaped_identifier_and_raw_string_tail :: proc(test_context: ^testing.T) {
    // Malformed UTF-8 inside backticks
    escaped_source: string = "`\xFF`"
    lexed_escaped: pawser.LexedSourceFile = pawser.lexer_tokenize_source(escaped_source)
    defer pawser.lexed_source_file_destroy(&lexed_escaped)

    found_utf8_error_in_escaped: bool = false
    for diagnostic in lexed_escaped.diagnostics {
        if diagnostic.code == .MalformedUtf8Sequence {
            found_utf8_error_in_escaped = true
        }
    }
    testing.expect(test_context, found_utf8_error_in_escaped, "Expected MalformedUtf8Sequence inside escaped identifier")

    // Malformed UTF-8 in the final two bytes of an unclosed raw string
    raw_tail_source: string = "\"\"\"unclosed\xFF"
    lexed_raw_tail: pawser.LexedSourceFile = pawser.lexer_tokenize_source(raw_tail_source)
    defer pawser.lexed_source_file_destroy(&lexed_raw_tail)

    found_utf8_error_in_raw: bool = false
    found_unterminated_raw: bool = false
    for diagnostic in lexed_raw_tail.diagnostics {
        if diagnostic.code == .MalformedUtf8Sequence {
            found_utf8_error_in_raw = true
        }
        if diagnostic.code == .UnterminatedRawStringLiteral {
            found_unterminated_raw = true
        }
    }
    testing.expect(test_context, found_utf8_error_in_raw, "Expected MalformedUtf8Sequence in tail of unclosed raw string")
    testing.expect(test_context, found_unterminated_raw, "Expected UnterminatedRawStringLiteral diagnostic")
}

// Verifies that comment delimiters inside standard, character, and raw string literals remain literal content.
@(test)
comment_test_delimiters_inside_literals :: proc(test_context: ^testing.T) {
    source_code: string = `"//" "/* outer /* nested */ */" '/' """// /* */"""`
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_file.tokens), 5)
    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.StringLiteral)
    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.StringLiteral)
    testing.expect_value(test_context, lexed_file.tokens[2].kind, pawser.TokenKind.CharacterLiteral)
    testing.expect_value(test_context, lexed_file.tokens[3].kind, pawser.TokenKind.RawStringLiteral)
}

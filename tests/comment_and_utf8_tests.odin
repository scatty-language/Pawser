package tests

import "core:testing"
import pawser "../src"

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

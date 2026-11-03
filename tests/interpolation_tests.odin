package tests

import "core:testing"
import pawser "../src"

// Verifies that basic string interpolation generates correct start, delimiter, expression, and end tokens.
@(test)
interpolation_test_simple :: proc(test_context: ^testing.T) {
    source_code: string = "\"Max capacity: \\(MaxUsers)\""
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_file.tokens), 6) // Start, \(, MaxUsers, ), End, EOF

    // InterpolatedStringStart: "Max capacity:
    token_start: pawser.Token = lexed_file.tokens[0]
    testing.expect_value(test_context, token_start.kind, pawser.TokenKind.InterpolatedStringStart)
    testing.expect_value(test_context, pawser.token_extract_lexeme(token_start, source_code), "\"Max capacity: ")

    // InterpolationStart: \(
    token_interpolation_open: pawser.Token = lexed_file.tokens[1]
    testing.expect_value(test_context, token_interpolation_open.kind, pawser.TokenKind.InterpolationStart)
    testing.expect_value(test_context, pawser.token_extract_lexeme(token_interpolation_open, source_code), "\\(")

    // MaxUsers
    token_identifier: pawser.Token = lexed_file.tokens[2]
    testing.expect_value(test_context, token_identifier.kind, pawser.TokenKind.PublicIdentifier)
    testing.expect_value(test_context, pawser.token_extract_lexeme(token_identifier, source_code), "MaxUsers")

    // InterpolationEnd: )
    token_interpolation_close: pawser.Token = lexed_file.tokens[3]
    testing.expect_value(test_context, token_interpolation_close.kind, pawser.TokenKind.InterpolationEnd)
    testing.expect_value(test_context, pawser.token_extract_lexeme(token_interpolation_close, source_code), ")")

    // InterpolatedStringEnd: "
    token_end: pawser.Token = lexed_file.tokens[4]
    testing.expect_value(test_context, token_end.kind, pawser.TokenKind.InterpolatedStringEnd)
    testing.expect_value(test_context, pawser.token_extract_lexeme(token_end, source_code), "\"")

    // Verify delimiter pairing
    testing.expect_value(test_context, token_interpolation_open.matching_delimiter_index, 3)
    testing.expect_value(test_context, token_interpolation_close.matching_delimiter_index, 1)
}

// Verifies that complex nested interpolation with nested string literals, method calls, and sub-expressions pairs delimiters accurately.
@(test)
interpolation_test_complex_nested :: proc(test_context: ^testing.T) {
    source_code: string = "\"Player \\(name.Trim(\" \")) scored \\(score + (10 * 2)) points!\""
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)

    // Token 0: InterpolatedStringStart ("Player ")
    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.InterpolatedStringStart)

    // Token 1: InterpolationStart (\()
    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.InterpolationStart)

    // Token 5: LeftParenthesis in Trim(
    testing.expect_value(test_context, lexed_file.tokens[5].kind, pawser.TokenKind.LeftParenthesis)

    // Token 6: StringLiteral inside expression (" ")
    testing.expect_value(test_context, lexed_file.tokens[6].kind, pawser.TokenKind.StringLiteral)

    // Token 7: RightParenthesis in Trim(" ")
    testing.expect_value(test_context, lexed_file.tokens[7].kind, pawser.TokenKind.RightParenthesis)
    testing.expect_value(test_context, lexed_file.tokens[5].matching_delimiter_index, 7)
    testing.expect_value(test_context, lexed_file.tokens[7].matching_delimiter_index, 5)

    // Token 8: InterpolationEnd closing first interpolation
    testing.expect_value(test_context, lexed_file.tokens[8].kind, pawser.TokenKind.InterpolationEnd)
    testing.expect_value(test_context, lexed_file.tokens[1].matching_delimiter_index, 8)
    testing.expect_value(test_context, lexed_file.tokens[8].matching_delimiter_index, 1)

    // Token 9: InterpolatedStringMiddle (" scored ")
    testing.expect_value(test_context, lexed_file.tokens[9].kind, pawser.TokenKind.InterpolatedStringMiddle)

    // Token 10: InterpolationStart (\()
    testing.expect_value(test_context, lexed_file.tokens[10].kind, pawser.TokenKind.InterpolationStart)

    // Token 13: LeftParenthesis in (10 * 2)
    testing.expect_value(test_context, lexed_file.tokens[13].kind, pawser.TokenKind.LeftParenthesis)

    // Token 17: RightParenthesis in (10 * 2)
    testing.expect_value(test_context, lexed_file.tokens[17].kind, pawser.TokenKind.RightParenthesis)
    testing.expect_value(test_context, lexed_file.tokens[13].matching_delimiter_index, 17)
    testing.expect_value(test_context, lexed_file.tokens[17].matching_delimiter_index, 13)

    // Token 18: InterpolationEnd closing second interpolation
    testing.expect_value(test_context, lexed_file.tokens[18].kind, pawser.TokenKind.InterpolationEnd)
    testing.expect_value(test_context, lexed_file.tokens[10].matching_delimiter_index, 18)
    testing.expect_value(test_context, lexed_file.tokens[18].matching_delimiter_index, 10)

    // Token 19: InterpolatedStringEnd (" points!")
    testing.expect_value(test_context, lexed_file.tokens[19].kind, pawser.TokenKind.InterpolatedStringEnd)
}

// Verifies that escaped interpolation sequences produce non-interpolated strings and empty interpolations emit diagnostics.
@(test)
interpolation_test_escapes_and_diagnostics :: proc(test_context: ^testing.T) {
    // Escaped backslash before parenthesis must NOT trigger interpolation
    escaped_source: string = "\"Literal \\\\(not interpolated)\""
    lexed_escaped: pawser.LexedSourceFile = pawser.lexer_tokenize_source(escaped_source)
    defer pawser.lexed_source_file_destroy(&lexed_escaped)

    testing.expect_value(test_context, len(lexed_escaped.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_escaped.tokens), 2) // StringLiteral + EOF
    testing.expect_value(test_context, lexed_escaped.tokens[0].kind, pawser.TokenKind.StringLiteral)

    // Empty interpolation \() must emit diagnostic
    empty_source: string = "\"\\()\""
    lexed_empty: pawser.LexedSourceFile = pawser.lexer_tokenize_source(empty_source)
    defer pawser.lexed_source_file_destroy(&lexed_empty)

    testing.expect(test_context, len(lexed_empty.diagnostics) >= 1, "Expected EmptyStringInterpolation diagnostic")
    testing.expect_value(test_context, lexed_empty.diagnostics[0].code, pawser.LexerErrorCode.EmptyStringInterpolation)
}

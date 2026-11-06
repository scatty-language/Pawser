// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

package tests

import "core:testing"
import pawser "../../src"

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

// Verifies that an unterminated interpolated string emits InterpolatedStringEnd for the trailing segment and recovers at newline.
@(test)
interpolation_test_unterminated_trailing_segment_recovery :: proc(test_context: ^testing.T) {
    source_code: string = "\"Hello \\(userName) trailing text\nnextIdentifier"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 1)
    if len(lexed_file.diagnostics) >= 1 {
        testing.expect_value(test_context, lexed_file.diagnostics[0].code, pawser.LexerErrorCode.UnterminatedStringLiteral)
    }

    // Tokens: InterpolatedStringStart, InterpolationStart, userName, InterpolationEnd, InterpolatedStringEnd, nextIdentifier, EOF
    testing.expect_value(test_context, len(lexed_file.tokens), 7)

    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.InterpolatedStringStart)
    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.InterpolationStart)
    testing.expect_value(test_context, lexed_file.tokens[2].kind, pawser.TokenKind.LocalIdentifier)
    testing.expect_value(test_context, lexed_file.tokens[3].kind, pawser.TokenKind.InterpolationEnd)

    // Trailing segment must not be dropped from token stream
    testing.expect_value(test_context, lexed_file.tokens[4].kind, pawser.TokenKind.InterpolatedStringEnd)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[4], source_code), " trailing text")

    // Token on the next line must be scanned with PrecededByNewline
    testing.expect_value(test_context, lexed_file.tokens[5].kind, pawser.TokenKind.LocalIdentifier)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[5], source_code), "nextIdentifier")
    testing.expect(test_context, pawser.TokenFlag.PrecededByNewline in lexed_file.tokens[5].flags, "Expected PrecededByNewline on nextIdentifier")
}

// Verifies that malformed UTF-8 hex escapes and incomplete escapes inside interpolated string segments are diagnosed cleanly.
@(test)
interpolation_test_malformed_escapes_in_segments :: proc(test_context: ^testing.T) {
    source_code: string = "\"Start \\xFF \\(value) Middle \\u12\";"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 2)
    if len(lexed_file.diagnostics) >= 2 {
        testing.expect_value(test_context, lexed_file.diagnostics[0].code, pawser.LexerErrorCode.MalformedUtf8EscapeSequence)
        testing.expect_value(test_context, lexed_file.diagnostics[1].code, pawser.LexerErrorCode.InvalidEscapeSequence)
    }

    // Closing quote and semicolon must remain intact
    testing.expect_value(test_context, lexed_file.tokens[4].kind, pawser.TokenKind.InterpolatedStringEnd)
    testing.expect_value(test_context, lexed_file.tokens[5].kind, pawser.TokenKind.Semicolon)
}

// Verifies that an unclosed string interpolation at a line break recovers without corrupting subsequent parentheses or top-level spans.
@(test)
interpolation_test_unterminated_expression_newline_recovery :: proc(test_context: ^testing.T) {
    source_code: string = "broken := \"Hello \\(userName\nNormalCall();\nTopLevelConst :: 100;\n"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect(test_context, len(lexed_file.diagnostics) >= 1, "Expected diagnostic for unclosed interpolation")

    // Verify that 'NormalCall();' on line 2 has a normal RightParenthesis and is NOT treated as InterpolationEnd
    found_normal_call: bool = false
    found_top_level_const: bool = false

    for token_index in 0 ..< len(lexed_file.tokens) {
        token: pawser.Token = lexed_file.tokens[token_index]
        lexeme: string = pawser.token_extract_lexeme(token, source_code)

        if token.kind == .PublicIdentifier && lexeme == "NormalCall" {
            found_normal_call = true
            if token_index + 2 < len(lexed_file.tokens) {
                testing.expect_value(test_context, lexed_file.tokens[token_index + 1].kind, pawser.TokenKind.LeftParenthesis)
                testing.expect_value(test_context, lexed_file.tokens[token_index + 2].kind, pawser.TokenKind.RightParenthesis)
            }
        }

        if token.kind == .PublicIdentifier && lexeme == "TopLevelConst" {
            found_top_level_const = true
        }
    }

    testing.expect(test_context, found_normal_call, "Expected NormalCall to be tokenized as normal code")
    testing.expect(test_context, found_top_level_const, "Expected TopLevelConst to be tokenized as normal code instead of string content")
    testing.expect(test_context, len(lexed_file.top_level_spans) >= 1, "Expected subsequent top-level declarations to be recorded in top_level_spans")
}

// Verifies that a missing closing parenthesis inside an interpolation before the closing quote does not swallow the semicolon or corrupt top-level spans.
@(test)
interpolation_test_unclosed_inner_parenthesis_recovery :: proc(test_context: ^testing.T) {
    source_code: string = "msg := \"Result: \\(compute(1, 2)\";\nNextConst :: (10 + 20);\n"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect(test_context, len(lexed_file.diagnostics) >= 1, "Expected diagnostic for unclosed parenthesis in interpolation")

    // The closing quote on line 1 must NOT start a new StringLiteral that swallows the trailing semicolon '";'
    for token in lexed_file.tokens {
        if token.kind == .StringLiteral {
            testing.expect(
                test_context,
                pawser.token_extract_lexeme(token, source_code) != "\";",
                "Closing quote of broken interpolation must not start a new StringLiteral swallowing ';'",
            )
        }
    }

    // Subsequent top-level declaration 'NextConst :: (10 + 20);' must still be recorded in top_level_spans
    testing.expect(test_context, len(lexed_file.top_level_spans) >= 1, "Expected top_level_spans to record subsequent top-level declarations")
}

// Verifies that a mismatched closing brace inside an interpolation keeps parenthesis depth synchronized with the delimiter stack.
@(test)
interpolation_test_mismatched_delimiter_depth_sync :: proc(test_context: ^testing.T) {
    source_code: string = "\"\\({ ( } )\" ;"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    // The unclosed '(' inside '{ ( }' is unwound by '}', so the outer ')' must still close the interpolation
    found_interpolation_end: bool = false
    found_string_end: bool = false

    for token in lexed_file.tokens {
        if token.kind == .InterpolationEnd {
            found_interpolation_end = true
        }
        if token.kind == .InterpolatedStringEnd {
            found_string_end = true
        }
    }

    testing.expect(test_context, found_interpolation_end, "Expected outer ')' to be recognized as InterpolationEnd after stack unwinding")
    testing.expect(test_context, found_string_end, "Expected closing quote to be recognized as InterpolatedStringEnd")
    testing.expect_value(test_context, lexed_file.tokens[len(lexed_file.tokens) - 2].kind, pawser.TokenKind.Semicolon)
}

// Verifies that interpolation delimiters are not activated inside character or raw string literals.
@(test)
interpolation_test_delimiter_outside_standard_strings :: proc(test_context: ^testing.T) {
    character_source: string = `'\('`
    lexed_character: pawser.LexedSourceFile = pawser.lexer_tokenize_source(character_source)
    defer pawser.lexed_source_file_destroy(&lexed_character)

    testing.expect_value(test_context, len(lexed_character.diagnostics), 1)
    testing.expect_value(test_context, lexed_character.diagnostics[0].code, pawser.LexerErrorCode.InvalidEscapeSequence)
    testing.expect_value(test_context, lexed_character.tokens[0].kind, pawser.TokenKind.CharacterLiteral)

    raw_source: string = `"""\(not interpolation)"""`
    lexed_raw: pawser.LexedSourceFile = pawser.lexer_tokenize_source(raw_source)
    defer pawser.lexed_source_file_destroy(&lexed_raw)

    testing.expect_value(test_context, len(lexed_raw.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_raw.tokens), 2)
    testing.expect_value(test_context, lexed_raw.tokens[0].kind, pawser.TokenKind.RawStringLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_raw.tokens[0], raw_source), raw_source)
}

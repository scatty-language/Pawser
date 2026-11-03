package tests

import "core:testing"
import pawser "../src"

// Verifies that integer literals in decimal, hexadecimal, and binary formats with suffixes are correctly tokenized.
@(test)
literal_test_integers_and_suffixes :: proc(test_context: ^testing.T) {
    source_code: string = "0 42 1_000_000 0xFF_AA 0b1010_0011 42L 10u 99uL"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_file.tokens), 9) // 8 numbers + EOF

    // 0
    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[0], source_code), "0")

    // 42
    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[1], source_code), "42")

    // 1_000_000
    testing.expect_value(test_context, lexed_file.tokens[2].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[2], source_code), "1_000_000")

    // 0xFF_AA
    testing.expect_value(test_context, lexed_file.tokens[3].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[3], source_code), "0xFF_AA")

    // 0b1010_0011
    testing.expect_value(test_context, lexed_file.tokens[4].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[4], source_code), "0b1010_0011")

    // 42L
    testing.expect_value(test_context, lexed_file.tokens[5].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[5], source_code), "42L")
    testing.expect(test_context, pawser.TokenFlag.IntegerSuffixLong in lexed_file.tokens[5].flags, "Flag IntegerSuffixLong required")

    // 10u
    testing.expect_value(test_context, lexed_file.tokens[6].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[6], source_code), "10u")
    testing.expect(test_context, pawser.TokenFlag.IntegerSuffixUnsigned in lexed_file.tokens[6].flags, "Flag IntegerSuffixUnsigned required")

    // 99uL
    testing.expect_value(test_context, lexed_file.tokens[7].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[7], source_code), "99uL")
    testing.expect(test_context, pawser.TokenFlag.IntegerSuffixUnsignedLong in lexed_file.tokens[7].flags, "Flag IntegerSuffixUnsignedLong required")
}

// Verifies that lookahead correctly distinguishes integer literals from range and cascade operators.
@(test)
literal_test_number_vs_range_lookahead :: proc(test_context: ^testing.T) {
    source_code: string = "0..10"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_file.tokens), 4) // 0, .., 10, EOF

    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[0], source_code), "0")

    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.DoubleDot)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[1], source_code), "..")

    testing.expect_value(test_context, lexed_file.tokens[2].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[2], source_code), "10")
}

// Verifies that floating-point literals with fractions, exponents, and suffixes are correctly tokenized.
@(test)
literal_test_floating_point_numbers :: proc(test_context: ^testing.T) {
    source_code: string = "3.14159 5.972e24 1.0e-5 9.81f 0.5d"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_file.tokens), 6) // 5 floats + EOF

    // 3.14159
    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.FloatLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[0], source_code), "3.14159")

    // 5.972e24
    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.FloatLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[1], source_code), "5.972e24")

    // 1.0e-5
    testing.expect_value(test_context, lexed_file.tokens[2].kind, pawser.TokenKind.FloatLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[2], source_code), "1.0e-5")

    // 9.81f
    testing.expect_value(test_context, lexed_file.tokens[3].kind, pawser.TokenKind.FloatLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[3], source_code), "9.81f")
    testing.expect(test_context, pawser.TokenFlag.FloatSuffixSingle in lexed_file.tokens[3].flags, "Flag FloatSuffixSingle required")

    // 0.5d
    testing.expect_value(test_context, lexed_file.tokens[4].kind, pawser.TokenKind.FloatLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[4], source_code), "0.5d")
    testing.expect(test_context, pawser.TokenFlag.FloatSuffixDouble in lexed_file.tokens[4].flags, "Flag FloatSuffixDouble required")
}

// Verifies that character and rune literals are correctly classified and illegal escapes or lengths emit diagnostics.
@(test)
literal_test_characters_and_runes :: proc(test_context: ^testing.T) {
    source_code: string = "'A' '\\n' 'Я' '🔥' '\\u042F' '' 'ab' '\\uD800' '\\xFF'"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    // 'A' (ASCII Char)
    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.CharacterLiteral)

    // '\n' (ASCII Char with escape)
    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.CharacterLiteral)

    // 'Я' (Unicode Rune)
    testing.expect_value(test_context, lexed_file.tokens[2].kind, pawser.TokenKind.RuneLiteral)

    // '🔥' (Unicode Rune)
    testing.expect_value(test_context, lexed_file.tokens[3].kind, pawser.TokenKind.RuneLiteral)

    // '\u042F' (Unicode Rune)
    testing.expect_value(test_context, lexed_file.tokens[4].kind, pawser.TokenKind.RuneLiteral)

    // Diagnostics checks for error cases
    found_empty_character: bool = false
    found_multi_character: bool = false
    found_surrogate_escape: bool = false
    found_malformed_utf8_escape: bool = false

    for diagnostic in lexed_file.diagnostics {
        if diagnostic.code == .EmptyCharacterLiteral {
            found_empty_character = true
        }
        if diagnostic.code == .MultiCharacterLiteral {
            found_multi_character = true
        }
        if diagnostic.code == .SurrogateUnicodeEscape {
            found_surrogate_escape = true
        }
        if diagnostic.code == .MalformedUtf8EscapeSequence {
            found_malformed_utf8_escape = true
        }
    }

    testing.expect(test_context, found_empty_character, "Expected EmptyCharacterLiteral diagnostic")
    testing.expect(test_context, found_multi_character, "Expected MultiCharacterLiteral diagnostic")
    testing.expect(test_context, found_surrogate_escape, "Expected SurrogateUnicodeEscape diagnostic")
    testing.expect(test_context, found_malformed_utf8_escape, "Expected MalformedUtf8EscapeSequence diagnostic")
}

// Verifies that raw string literals preserve escape sequences and enforce multi-line indentation alignment.
@(test)
literal_test_raw_strings :: proc(test_context: ^testing.T) {
    // Single-line raw string
    single_line_source: string = `"""\b[A-Z]+\b"""`
    lexed_single: pawser.LexedSourceFile = pawser.lexer_tokenize_source(single_line_source)
    defer pawser.lexed_source_file_destroy(&lexed_single)

    testing.expect_value(test_context, len(lexed_single.diagnostics), 0)
    testing.expect_value(test_context, lexed_single.tokens[0].kind, pawser.TokenKind.RawStringLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_single.tokens[0], single_line_source), `"""\b[A-Z]+\b"""`)

    // Valid multi-line raw string
    valid_multiline_source: string = "\"\"\"\n    {\n        \"version\": 1.0\n    }\n    \"\"\""
    lexed_valid: pawser.LexedSourceFile = pawser.lexer_tokenize_source(valid_multiline_source)
    defer pawser.lexed_source_file_destroy(&lexed_valid)

    testing.expect_value(test_context, len(lexed_valid.diagnostics), 0)
    testing.expect_value(test_context, lexed_valid.tokens[0].kind, pawser.TokenKind.RawStringLiteral)

    // Invalid multi-line raw string where content is less indented than closing delimiter
    invalid_multiline_source: string = "\"\"\"\n  Text\n    \"\"\""
    lexed_invalid: pawser.LexedSourceFile = pawser.lexer_tokenize_source(invalid_multiline_source)
    defer pawser.lexed_source_file_destroy(&lexed_invalid)

    testing.expect(test_context, len(lexed_invalid.diagnostics) >= 1, "Expected RawStringInsufficientIndentation diagnostic")
    testing.expect_value(test_context, lexed_invalid.diagnostics[0].code, pawser.LexerErrorCode.RawStringInsufficientIndentation)
}

// Verifies that multi-line raw strings handle CRLF line endings without panicking and allow whitespace-only empty lines.
@(test)
literal_test_raw_strings_crlf_and_whitespace_lines :: proc(test_context: ^testing.T) {
    // Multi-line raw string using Windows CRLF (\r\n) line terminators
    crlf_raw_source: string = "\"\"\"\r\n    {\r\n        \"name\": \"Scatty\"\r\n    }\r\n    \"\"\""
    lexed_crlf: pawser.LexedSourceFile = pawser.lexer_tokenize_source(crlf_raw_source)
    defer pawser.lexed_source_file_destroy(&lexed_crlf)

    testing.expect_value(test_context, len(lexed_crlf.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_crlf.tokens), 2) // RawStringLiteral + EOF
    testing.expect_value(test_context, lexed_crlf.tokens[0].kind, pawser.TokenKind.RawStringLiteral)
    testing.expect_value(test_context, len(lexed_crlf.line_start_offsets), 5)

    // Multi-line raw string containing a whitespace-only blank line with fewer spaces than closing quotes
    blank_line_source: string = "\"\"\"\n    First line\n  \n    Second line\n    \"\"\""
    lexed_blank: pawser.LexedSourceFile = pawser.lexer_tokenize_source(blank_line_source)
    defer pawser.lexed_source_file_destroy(&lexed_blank)

    testing.expect_value(test_context, len(lexed_blank.diagnostics), 0)
    testing.expect_value(test_context, lexed_blank.tokens[0].kind, pawser.TokenKind.RawStringLiteral)
}

// Verifies that binary and hexadecimal integer literals support valid type suffixes (u, L, uL) and reject invalid suffixes.
@(test)
literal_test_binary_and_hex_suffixes :: proc(test_context: ^testing.T) {
    source_code: string = "0b1010u 0b1100L 0b1111_0000uL 0xFFu 0x10L 0xABuL"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_file.tokens), 7) // 6 integers + EOF

    // 0b1010u
    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[0], source_code), "0b1010u")
    testing.expect(test_context, pawser.TokenFlag.IntegerSuffixUnsigned in lexed_file.tokens[0].flags, "Expected IntegerSuffixUnsigned on 0b1010u")

    // 0b1100L
    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[1], source_code), "0b1100L")
    testing.expect(test_context, pawser.TokenFlag.IntegerSuffixLong in lexed_file.tokens[1].flags, "Expected IntegerSuffixLong on 0b1100L")

    // 0b1111_0000uL
    testing.expect_value(test_context, lexed_file.tokens[2].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_file.tokens[2], source_code), "0b1111_0000uL")
    testing.expect(test_context, pawser.TokenFlag.IntegerSuffixUnsignedLong in lexed_file.tokens[2].flags, "Expected IntegerSuffixUnsignedLong on 0b1111_0000uL")

    // 0xFFu
    testing.expect_value(test_context, lexed_file.tokens[3].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect(test_context, pawser.TokenFlag.IntegerSuffixUnsigned in lexed_file.tokens[3].flags, "Expected IntegerSuffixUnsigned on 0xFFu")

    // 0x10L
    testing.expect_value(test_context, lexed_file.tokens[4].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect(test_context, pawser.TokenFlag.IntegerSuffixLong in lexed_file.tokens[4].flags, "Expected IntegerSuffixLong on 0x10L")

    // 0xABuL
    testing.expect_value(test_context, lexed_file.tokens[5].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect(test_context, pawser.TokenFlag.IntegerSuffixUnsignedLong in lexed_file.tokens[5].flags, "Expected IntegerSuffixUnsignedLong on 0xABuL")

    // Binary literal with trailing invalid suffix after valid suffix
    invalid_suffix_source: string = "0b1010u_invalid"
    lexed_invalid: pawser.LexedSourceFile = pawser.lexer_tokenize_source(invalid_suffix_source)
    defer pawser.lexed_source_file_destroy(&lexed_invalid)

    testing.expect(test_context, len(lexed_invalid.diagnostics) >= 1, "Expected diagnostic for invalid trailing characters after binary suffix")
    testing.expect_value(test_context, lexed_invalid.diagnostics[0].code, pawser.LexerErrorCode.InvalidNumberSuffix)
}

// Verifies that incomplete numeric escape sequences do not consume closing quotes, semicolons, or newlines.
@(test)
literal_test_incomplete_escape_sequence_recovery :: proc(test_context: ^testing.T) {
    source_code: string = "first := \"\\u12\";\nsecond := '\\x1';\nthird := \"\\U000012\";"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    // Must record all 3 physical lines
    testing.expect_value(test_context, len(lexed_file.line_start_offsets), 3)

    // Must emit 3 InvalidEscapeSequence diagnostics withoutUnterminatedStringLiteral or UnterminatedCharacterLiteral
    testing.expect_value(test_context, len(lexed_file.diagnostics), 3)
    for diagnostic in lexed_file.diagnostics {
        testing.expect_value(test_context, diagnostic.code, pawser.LexerErrorCode.InvalidEscapeSequence)
    }

    // Verify token stream did not lose closing quotes or semicolons:
    // first := "\u12" ; second := '\x1' ; third := "\U000012" ; EOF (13 tokens)
    testing.expect_value(test_context, len(lexed_file.tokens), 13)

    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.LocalIdentifier)
    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.ColonAssign)
    testing.expect_value(test_context, lexed_file.tokens[2].kind, pawser.TokenKind.StringLiteral)
    testing.expect_value(test_context, lexed_file.tokens[3].kind, pawser.TokenKind.Semicolon)

    testing.expect_value(test_context, lexed_file.tokens[4].kind, pawser.TokenKind.LocalIdentifier)
    testing.expect_value(test_context, lexed_file.tokens[5].kind, pawser.TokenKind.ColonAssign)
    testing.expect_value(test_context, lexed_file.tokens[6].kind, pawser.TokenKind.CharacterLiteral)
    testing.expect_value(test_context, lexed_file.tokens[7].kind, pawser.TokenKind.Semicolon)

    testing.expect_value(test_context, lexed_file.tokens[8].kind, pawser.TokenKind.LocalIdentifier)
    testing.expect_value(test_context, lexed_file.tokens[9].kind, pawser.TokenKind.ColonAssign)
    testing.expect_value(test_context, lexed_file.tokens[10].kind, pawser.TokenKind.StringLiteral)
    testing.expect_value(test_context, lexed_file.tokens[11].kind, pawser.TokenKind.Semicolon)
}

// Verifies that hexadecimal escape sequences inside string literals are validated for well-formed UTF-8 encoding.
@(test)
literal_test_string_hex_escape_utf8_validation :: proc(test_context: ^testing.T) {
    // Invalid standalone high bytes in string literals must emit MalformedUtf8EscapeSequence
    invalid_source: string = "\"hello \\xFF world\" \"\\x80\""
    lexed_invalid: pawser.LexedSourceFile = pawser.lexer_tokenize_source(invalid_source)
    defer pawser.lexed_source_file_destroy(&lexed_invalid)

    testing.expect_value(test_context, len(lexed_invalid.diagnostics), 2)
    if len(lexed_invalid.diagnostics) >= 2 {
        testing.expect_value(test_context, lexed_invalid.diagnostics[0].code, pawser.LexerErrorCode.MalformedUtf8EscapeSequence)
        testing.expect_value(test_context, lexed_invalid.diagnostics[1].code, pawser.LexerErrorCode.MalformedUtf8EscapeSequence)
    }

    // Valid multi-byte UTF-8 sequence via adjacent \xHH escapes (\xD0\xAF is U+042F 'Я')
    valid_source: string = "\"\\xD0\\xAF\""
    lexed_valid: pawser.LexedSourceFile = pawser.lexer_tokenize_source(valid_source)
    defer pawser.lexed_source_file_destroy(&lexed_valid)

    testing.expect_value(test_context, len(lexed_valid.diagnostics), 0)
    testing.expect_value(test_context, lexed_valid.tokens[0].kind, pawser.TokenKind.StringLiteral)
}

// Verifies that integer literals followed directly by an exponent without a decimal point emit a MalformedNumberLiteral diagnostic.
@(test)
literal_test_exponent_without_decimal_point :: proc(test_context: ^testing.T) {
    source_code: string = "10e5 42E-2"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 2)
    if len(lexed_file.diagnostics) >= 2 {
        testing.expect_value(test_context, lexed_file.diagnostics[0].code, pawser.LexerErrorCode.MalformedNumberLiteral)
        testing.expect_value(test_context, lexed_file.diagnostics[1].code, pawser.LexerErrorCode.MalformedNumberLiteral)
    }

    // Must recover and produce FloatLiteral tokens
    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.FloatLiteral)
    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.FloatLiteral)
}

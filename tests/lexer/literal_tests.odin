package tests

import "core:testing"
import pawser "../../src"

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

// Verifies that malformed integer literals immediately preceding a dot or range operator emit MalformedNumberLiteral diagnostics.
@(test)
literal_test_malformed_integer_before_dot_and_range :: proc(test_context: ^testing.T) {
    source_code: string = "1__000..10 1_000_.ToString() 0_..5"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    malformed_number_error_count: int = 0
    for diagnostic in lexed_file.diagnostics {
        if diagnostic.code == .MalformedNumberLiteral {
            malformed_number_error_count += 1
        }
    }

    testing.expect_value(test_context, malformed_number_error_count, 3)

    // Verify that range and member access tokens are still emitted properly after recovery
    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.DoubleDot)
    testing.expect_value(test_context, lexed_file.tokens[2].kind, pawser.TokenKind.IntegerLiteral)

    testing.expect_value(test_context, lexed_file.tokens[3].kind, pawser.TokenKind.IntegerLiteral)
    testing.expect_value(test_context, lexed_file.tokens[4].kind, pawser.TokenKind.Dot)
    testing.expect_value(test_context, lexed_file.tokens[5].kind, pawser.TokenKind.PublicIdentifier)
}

// Verifies that a trailing backslash before a physical newline does not swallow the newline or merge lines into a single-line literal.
@(test)
literal_test_backslash_before_newline_in_string_and_char :: proc(test_context: ^testing.T) {
    // Line 1 has an unclosed string ending with '\' right before '\n'
    // Line 2 has normal code that must not be swallowed into the string literal
    string_source: string = "\"hello \\\nnextLineVar := 42;"
    lexed_string: pawser.LexedSourceFile = pawser.lexer_tokenize_source(string_source)
    defer pawser.lexed_source_file_destroy(&lexed_string)

    // Both physical lines must be recorded in line_start_offsets
    testing.expect_value(test_context, len(lexed_string.line_start_offsets), 2)

    found_unterminated_string: bool = false
    for diagnostic in lexed_string.diagnostics {
        if diagnostic.code == .UnterminatedStringLiteral {
            found_unterminated_string = true
        }
    }
    testing.expect(test_context, found_unterminated_string, "Expected UnterminatedStringLiteral when backslash precedes newline")

    // Verify that 'nextLineVar' on line 2 is tokenized as a LocalIdentifier preceded by a newline
    testing.expect_value(test_context, lexed_string.tokens[0].kind, pawser.TokenKind.StringLiteral)
    testing.expect_value(test_context, lexed_string.tokens[1].kind, pawser.TokenKind.LocalIdentifier)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_string.tokens[1], string_source), "nextLineVar")
    testing.expect(test_context, pawser.TokenFlag.PrecededByNewline in lexed_string.tokens[1].flags, "Expected PrecededByNewline on line 2 token")

    // Character literal with backslash immediately before CRLF
    char_source: string = "'\\\r\nafterChar := 1;"
    lexed_char: pawser.LexedSourceFile = pawser.lexer_tokenize_source(char_source)
    defer pawser.lexed_source_file_destroy(&lexed_char)

    testing.expect_value(test_context, len(lexed_char.line_start_offsets), 2)
    testing.expect_value(test_context, lexed_char.tokens[1].kind, pawser.TokenKind.LocalIdentifier)
    testing.expect_value(test_context, pawser.token_extract_lexeme(lexed_char.tokens[1], char_source), "afterChar")
}

// Verifies that an invalid escape sequence followed by a multi-byte UTF-8 character advances past the full code point without false UTF-8 errors.
@(test)
literal_test_invalid_multibyte_utf8_escape_in_string_and_char :: proc(test_context: ^testing.T) {
    source_code: string = "\"\\Я\" '\\🔥'"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    invalid_escape_count: int = 0
    malformed_utf8_count: int = 0
    multi_char_count: int = 0

    for diagnostic in lexed_file.diagnostics {
        if diagnostic.code == .InvalidEscapeSequence {
            invalid_escape_count += 1
        }
        if diagnostic.code == .MalformedUtf8Sequence {
            malformed_utf8_count += 1
        }
        if diagnostic.code == .MultiCharacterLiteral {
            multi_char_count += 1
        }
    }

    testing.expect_value(test_context, invalid_escape_count, 2)
    testing.expect_value(test_context, malformed_utf8_count, 0)
    testing.expect_value(test_context, multi_char_count, 0)
}

// Verifies that adjacent hex escapes forming valid UTF-8 in rune literals succeed and malformed multi-byte hex escapes in strings emit one diagnostic.
@(test)
literal_test_hex_escape_multibyte_utf8_in_rune_and_string :: proc(test_context: ^testing.T) {
    // '\xD0\xAF' encodes U+042F ('Я') in UTF-8 and must be accepted as a valid RuneLiteral
    valid_rune_source: string = "'\\xD0\\xAF'"
    lexed_rune: pawser.LexedSourceFile = pawser.lexer_tokenize_source(valid_rune_source)
    defer pawser.lexed_source_file_destroy(&lexed_rune)

    testing.expect_value(test_context, len(lexed_rune.diagnostics), 0)
    testing.expect_value(test_context, lexed_rune.tokens[0].kind, pawser.TokenKind.RuneLiteral)

    // "\xC2\xFF" (invalid continuation byte) and "\xE0\x80\x80" (overlong 3-byte sequence)
    // Each broken sequence must emit exactly one MalformedUtf8EscapeSequence diagnostic
    invalid_string_source: string = "\"\\xC2\\xFF\" \"\\xE0\\x80\\x80\""
    lexed_string: pawser.LexedSourceFile = pawser.lexer_tokenize_source(invalid_string_source)
    defer pawser.lexed_source_file_destroy(&lexed_string)

    malformed_escape_count: int = 0
    for diagnostic in lexed_string.diagnostics {
        if diagnostic.code == .MalformedUtf8EscapeSequence {
            malformed_escape_count += 1
        }
    }

    testing.expect_value(test_context, malformed_escape_count, 2)
}

// Verifies that binary literals with invalid digits emit InvalidBinaryDigit without a redundant MalformedNumberLiteral diagnostic.
@(test)
literal_test_invalid_binary_digit_single_diagnostic :: proc(test_context: ^testing.T) {
    source_code: string = "0b2 0b10_2"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    invalid_binary_count: int = 0
    malformed_number_count: int = 0

    for diagnostic in lexed_file.diagnostics {
        if diagnostic.code == .InvalidBinaryDigit {
            invalid_binary_count += 1
        }
        if diagnostic.code == .MalformedNumberLiteral {
            malformed_number_count += 1
        }
    }

    testing.expect_value(test_context, invalid_binary_count, 2)
    testing.expect_value(test_context, malformed_number_count, 0)
}

// Verifies that every simple escape and mixed-case numeric escape is accepted in strings and character literals.
@(test)
literal_test_all_valid_escape_sequences :: proc(test_context: ^testing.T) {
    source_code: string = `"\n\r\t\\\"\'\0 \x7F \u00af \U0001F525 \U0010FFFF" '\n' '\r' '\t' '\\' '\"' '\'' '\0'`
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_file.tokens), 9)
    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.StringLiteral)
    for token_index in 0 ..< 8 {
        testing.expect(
            test_context,
            pawser.TokenFlag.HasEscapeSequences in lexed_file.tokens[token_index].flags,
            "Expected escape metadata on literal token",
        )
    }
    for token_index in 1 ..< 8 {
        testing.expect_value(test_context, lexed_file.tokens[token_index].kind, pawser.TokenKind.CharacterLiteral)
    }
}

// Verifies that Unicode escapes reject values above U+10FFFF and surrogate code points in the eight-digit form.
@(test)
literal_test_unicode_escape_boundaries :: proc(test_context: ^testing.T) {
    source_code: string = `"\U00110000" "\U0000DFFF"`
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 2)
    testing.expect_value(test_context, lexed_file.diagnostics[0].code, pawser.LexerErrorCode.OutOfRangeUnicodeEscape)
    testing.expect_value(test_context, lexed_file.diagnostics[1].code, pawser.LexerErrorCode.SurrogateUnicodeEscape)
    testing.expect_value(test_context, len(lexed_file.tokens), 3)
}

// Verifies that malformed prefixes, separators, exponents, and suffixes produce the corresponding diagnostics.
@(test)
literal_test_malformed_numeric_forms :: proc(test_context: ^testing.T) {
    source_code: string = "0x 0XFF 0B10 1_ 0x_FF 0b_10 1.0e+ 1.0e 1.0u"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    invalid_prefix_count: int = 0
    malformed_number_count: int = 0
    invalid_suffix_count: int = 0
    for diagnostic in lexed_file.diagnostics {
        if diagnostic.code == .InvalidNumberPrefix {
            invalid_prefix_count += 1
        }
        if diagnostic.code == .MalformedNumberLiteral {
            malformed_number_count += 1
        }
        if diagnostic.code == .InvalidNumberSuffix {
            invalid_suffix_count += 1
        }
    }

    testing.expect_value(test_context, invalid_prefix_count, 2)
    testing.expect_value(test_context, malformed_number_count, 6)
    testing.expect_value(test_context, invalid_suffix_count, 1)
    testing.expect_value(test_context, len(lexed_file.tokens), 10)
}

// Verifies that unterminated standard strings and character literals are diagnosed at end of file.
@(test)
literal_test_unterminated_literals_at_end_of_file :: proc(test_context: ^testing.T) {
    string_source: string = `"unterminated`
    lexed_string: pawser.LexedSourceFile = pawser.lexer_tokenize_source(string_source)
    defer pawser.lexed_source_file_destroy(&lexed_string)

    testing.expect_value(test_context, len(lexed_string.diagnostics), 1)
    testing.expect_value(test_context, lexed_string.diagnostics[0].code, pawser.LexerErrorCode.UnterminatedStringLiteral)
    testing.expect_value(test_context, lexed_string.tokens[0].kind, pawser.TokenKind.StringLiteral)

    character_source: string = `'x`
    lexed_character: pawser.LexedSourceFile = pawser.lexer_tokenize_source(character_source)
    defer pawser.lexed_source_file_destroy(&lexed_character)

    testing.expect_value(test_context, len(lexed_character.diagnostics), 1)
    testing.expect_value(test_context, lexed_character.diagnostics[0].code, pawser.LexerErrorCode.UnterminatedCharacterLiteral)
    testing.expect_value(test_context, lexed_character.tokens[0].kind, pawser.TokenKind.CharacterLiteral)
}

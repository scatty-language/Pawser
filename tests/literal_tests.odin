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

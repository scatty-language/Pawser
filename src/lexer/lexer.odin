package lexer

import "base:runtime"
import "core:strings"

// Configuration options controlling `Lexer` memory allocation and behavior.
LexerConfiguration :: struct {
    allocator: runtime.Allocator,
}

// Complete, self-contained output of tokenizing a single source buffer.
LexedSourceFile :: struct {
    source_text:        string,
    tokens:             [dynamic]Token,
    top_level_spans:    [dynamic]TopLevelTokenSpan,
    line_start_offsets: [dynamic]u32,
    diagnostics:        [dynamic]LexerDiagnostic,
}

// Releases dynamic memory resources allocated inside a `LexedSourceFile`.
lexed_source_file_destroy :: proc(source_file: ^LexedSourceFile) {
    delete(source_file.tokens)
    delete(source_file.top_level_spans)
    delete(source_file.line_start_offsets)
    delete(source_file.diagnostics)
}

// Entry in the delimiter tracking stack for matching opening and closing delimiters.
DelimiterStackEntry :: struct {
    kind:        TokenKind,
    token_index: u32,
}

// State tracking an active string interpolation context.
InterpolationFrame :: struct {
    parenthesis_depth: u32,
}

// Internal state machine holding tokenization buffers and cursor positions.
LexerState :: struct {
    source_text:             string,
    current_byte_offset:     int,
    configuration:           LexerConfiguration,
    tokens:                  [dynamic]Token,
    top_level_spans:         [dynamic]TopLevelTokenSpan,
    line_start_offsets:      [dynamic]u32,
    diagnostics:             [dynamic]LexerDiagnostic,
    delimiter_stack:         [dynamic]DelimiterStackEntry,
    interpolation_stack:     [dynamic]InterpolationFrame,
    current_top_level_start: u32,
    preceded_by_whitespace:  bool,
    preceded_by_newline:     bool,
}

// Validates a UTF-8 byte sequence at the specified offset and returns its byte length and validity.
utf8_validate_sequence :: proc(
    source_text: string,
    byte_offset: int,
) -> (sequence_length: int, is_valid: bool) {
    if byte_offset >= len(source_text) {
        return 0, false
    }

    first_byte: u8 = source_text[byte_offset]

    if first_byte <= 0x7F {
        return 1, true
    }

    if first_byte >= 0xC2 && first_byte <= 0xDF {
        if byte_offset + 1 >= len(source_text) {
            return 1, false
        }
        second_byte: u8 = source_text[byte_offset + 1]
        if second_byte >= 0x80 && second_byte <= 0xBF {
            return 2, true
        }

        return 1, false
    }

    if first_byte >= 0xE0 && first_byte <= 0xEF {
        if byte_offset + 2 >= len(source_text) {
            return 1, false
        }
        second_byte: u8 = source_text[byte_offset + 1]
        third_byte: u8 = source_text[byte_offset + 2]

        if third_byte < 0x80 || third_byte > 0xBF {
            return 1, false
        }

        if first_byte == 0xE0 {
            if second_byte >= 0xA0 && second_byte <= 0xBF {
                return 3, true
            }

            return 1, false
        }

        if first_byte == 0xED {
            if second_byte >= 0x80 && second_byte <= 0x9F {
                return 3, true
            }

            return 1, false
        }

        if second_byte >= 0x80 && second_byte <= 0xBF {
            return 3, true
        }

        return 1, false
    }

    if first_byte >= 0xF0 && first_byte <= 0xF4 {
        if byte_offset + 3 >= len(source_text) {
            return 1, false
        }
        second_byte: u8 = source_text[byte_offset + 1]
        third_byte: u8 = source_text[byte_offset + 2]
        fourth_byte: u8 = source_text[byte_offset + 3]

        if third_byte < 0x80 || third_byte > 0xBF ||
           fourth_byte < 0x80 || fourth_byte > 0xBF {
            return 1, false
        }

        if first_byte == 0xF0 {
            if second_byte >= 0x90 && second_byte <= 0xBF {
                return 4, true
            }

            return 1, false
        }

        if first_byte == 0xF4 {
            if second_byte >= 0x80 && second_byte <= 0x8F {
                return 4, true
            }

            return 1, false
        }

        if second_byte >= 0x80 && second_byte <= 0xBF {
            return 4, true
        }

        return 1, false
    }

    return 1, false
}

// Appends a diagnostic message to the lexer state diagnostics collection.
lexer_record_diagnostic :: proc(
    state: ^LexerState,
    code: LexerErrorCode,
    severity: DiagnosticSeverity,
    byte_offset: int,
    byte_length: int,
    message: string,
) {
    append(&state.diagnostics, LexerDiagnostic{
        code     = code,
        severity = severity,
        span     = TextSpan{
            byte_offset = u32(byte_offset),
            byte_length = u32(byte_length),
        },
        message  = message,
    })
}

// Appends a new `Token` to the token stream and executes delimiter pairing and top-level span checks.
lexer_emit_token :: proc(
    state: ^LexerState,
    kind: TokenKind,
    start_offset: int,
    end_offset: int,
    explicit_flags: TokenFlags = {},
    identifier_hash: u64 = 0,
) {
    token_index: u32 = u32(len(state.tokens))
    final_flags: TokenFlags = explicit_flags

    if state.preceded_by_whitespace {
        final_flags += {.PrecededByWhitespace}
    }
    if state.preceded_by_newline {
        final_flags += {.PrecededByNewline}
    }

    token := Token{
        kind                     = kind,
        flags                    = final_flags,
        span                     = TextSpan{
            byte_offset = u32(start_offset),
            byte_length = u32(end_offset - start_offset),
        },
        matching_delimiter_index = NO_MATCHING_DELIMITER,
        identifier_hash          = identifier_hash,
    }

    append(&state.tokens, token)

    // Handle opening delimiters
    #partial switch kind {
    case .LeftBrace, .LeftParenthesis, .LeftBracket, .InterpolationStart:
        append(&state.delimiter_stack, DelimiterStackEntry{
            kind        = kind,
            token_index = token_index,
        })
    case .RightBrace, .RightParenthesis, .RightBracket, .InterpolationEnd:
        if len(state.delimiter_stack) > 0 {
            top_index: int = len(state.delimiter_stack) - 1
            top_entry: DelimiterStackEntry = state.delimiter_stack[top_index]
            is_matching: bool = false

            if kind == .RightBrace && top_entry.kind == .LeftBrace {
                is_matching = true
            } else if kind == .RightBracket && top_entry.kind == .LeftBracket {
                is_matching = true
            } else if kind == .RightParenthesis && top_entry.kind == .LeftParenthesis {
                is_matching = true
            } else if kind == .InterpolationEnd && top_entry.kind == .InterpolationStart {
                is_matching = true
            }

            if is_matching {
                pop(&state.delimiter_stack)
                state.tokens[top_entry.token_index].matching_delimiter_index = token_index
                state.tokens[token_index].matching_delimiter_index = top_entry.token_index
            } else {
                // Search down the stack for a matching open delimiter
                found_match_index: int = -1
                for search_index := top_index; search_index >= 0; search_index -= 1 {
                    candidate: DelimiterStackEntry = state.delimiter_stack[search_index]
                    matches_candidate: bool = false
                    if kind == .RightBrace && candidate.kind == .LeftBrace {
                        matches_candidate = true
                    } else if kind == .RightBracket && candidate.kind == .LeftBracket {
                        matches_candidate = true
                    } else if kind == .RightParenthesis && candidate.kind == .LeftParenthesis {
                        matches_candidate = true
                    } else if kind == .InterpolationEnd && candidate.kind == .InterpolationStart {
                        matches_candidate = true
                    }

                    if matches_candidate {
                        found_match_index = search_index
                        break
                    }
                }

                if found_match_index >= 0 {
                    // Report unclosed delimiters for skipped opening delimiters
                    for unclosed_index := found_match_index + 1; unclosed_index <= top_index; unclosed_index += 1 {
                        unclosed_entry: DelimiterStackEntry = state.delimiter_stack[unclosed_index]
                        lexer_record_diagnostic(
                            state,
                            .UnclosedDelimiter,
                            .Error,
                            int(state.tokens[unclosed_entry.token_index].span.byte_offset),
                            int(state.tokens[unclosed_entry.token_index].span.byte_length),
                            "Unclosed delimiter.",
                        )
                    }

                    matched_entry: DelimiterStackEntry = state.delimiter_stack[found_match_index]
                    state.tokens[matched_entry.token_index].matching_delimiter_index = token_index
                    state.tokens[token_index].matching_delimiter_index = matched_entry.token_index
                    resize(&state.delimiter_stack, found_match_index)
                } else {
                    lexer_record_diagnostic(
                        state,
                        .MismatchedClosingDelimiter,
                        .Error,
                        start_offset,
                        end_offset - start_offset,
                        "Mismatched closing delimiter.",
                    )
                }
            }
        } else {
            lexer_record_diagnostic(
                state,
                .MismatchedClosingDelimiter,
                .Error,
                start_offset,
                end_offset - start_offset,
                "Unexpected closing delimiter without opening delimiter.",
            )
        }
    }

    // Top-level declaration span recording at delimiter depth zero
    if len(state.delimiter_stack) == 0 && (kind == .Semicolon || kind == .RightBrace) {
        append(&state.top_level_spans, TopLevelTokenSpan{
            first_token_index = state.current_top_level_start,
            last_token_index  = token_index,
        })
        state.current_top_level_start = token_index + 1
    }

    state.preceded_by_whitespace = false
    state.preceded_by_newline    = false
}

// Skips whitespace characters and single/multi-line comments while recording line starting offsets.
lexer_skip_whitespace_and_comments :: proc(state: ^LexerState) {
    for state.current_byte_offset < len(state.source_text) {
        current_character: u8 = state.source_text[state.current_byte_offset]

        // Spaces and tabs
        if current_character == ' ' || current_character == '\t' {
            state.preceded_by_whitespace = true
            state.current_byte_offset += 1
            continue
        }

        // Carriage Return and Line Feed
        if current_character == '\r' {
            state.preceded_by_whitespace = true
            state.preceded_by_newline    = true
            state.current_byte_offset += 1
            if state.current_byte_offset < len(state.source_text) && state.source_text[state.current_byte_offset] == '\n' {
                state.current_byte_offset += 1
            }
            append(&state.line_start_offsets, u32(state.current_byte_offset))
            continue
        }

        if current_character == '\n' {
            state.preceded_by_whitespace = true
            state.preceded_by_newline    = true
            state.current_byte_offset += 1
            append(&state.line_start_offsets, u32(state.current_byte_offset))
            continue
        }

        // Line and block comments
        if current_character == '/' && state.current_byte_offset + 1 < len(state.source_text) {
            next_character: u8 = state.source_text[state.current_byte_offset + 1]

            // Line comment //
            if next_character == '/' {
                state.preceded_by_whitespace = true
                state.current_byte_offset += 2
                for state.current_byte_offset < len(state.source_text) {
                    comment_character: u8 = state.source_text[state.current_byte_offset]
                    if comment_character == '\n' || comment_character == '\r' {
                        // Do NOT consume newline so newline handling triggers next
                        break
                    }
                    sequence_length, is_valid_utf8 := utf8_validate_sequence(state.source_text, state.current_byte_offset)
                    if !is_valid_utf8 {
                        lexer_record_diagnostic(
                            state,
                            .MalformedUtf8Sequence,
                            .Error,
                            state.current_byte_offset,
                            1,
                            "Malformed UTF-8 sequence in comment.",
                        )
                        state.current_byte_offset += 1
                    } else {
                        state.current_byte_offset += sequence_length
                    }
                }
                continue
            }

            // Block comment /* ... */
            if next_character == '*' {
                state.preceded_by_whitespace = true
                comment_start_offset: int = state.current_byte_offset
                state.current_byte_offset += 2
                nesting_depth: int = 1

                for state.current_byte_offset < len(state.source_text) && nesting_depth > 0 {
                    block_character: u8 = state.source_text[state.current_byte_offset]

                    if block_character == '\r' {
                        state.preceded_by_newline = true
                        state.current_byte_offset += 1
                        if state.current_byte_offset < len(state.source_text) && state.source_text[state.current_byte_offset] == '\n' {
                            state.current_byte_offset += 1
                        }
                        append(&state.line_start_offsets, u32(state.current_byte_offset))
                        continue
                    }

                    if block_character == '\n' {
                        state.preceded_by_newline = true
                        state.current_byte_offset += 1
                        append(&state.line_start_offsets, u32(state.current_byte_offset))
                        continue
                    }

                    if block_character == '/' && state.current_byte_offset + 1 < len(state.source_text) &&
                       state.source_text[state.current_byte_offset + 1] == '*' {
                        nesting_depth += 1
                        state.current_byte_offset += 2
                        continue
                    }

                    if block_character == '*' && state.current_byte_offset + 1 < len(state.source_text) &&
                       state.source_text[state.current_byte_offset + 1] == '/' {
                        nesting_depth -= 1
                        state.current_byte_offset += 2
                        continue
                    }

                    sequence_length, is_valid_utf8 := utf8_validate_sequence(state.source_text, state.current_byte_offset)
                    if !is_valid_utf8 {
                        lexer_record_diagnostic(
                            state,
                            .MalformedUtf8Sequence,
                            .Error,
                            state.current_byte_offset,
                            1,
                            "Malformed UTF-8 sequence in block comment.",
                        )
                        state.current_byte_offset += 1
                    } else {
                        state.current_byte_offset += sequence_length
                    }
                }

                if nesting_depth > 0 {
                    lexer_record_diagnostic(
                        state,
                        .UnterminatedBlockComment,
                        .Error,
                        comment_start_offset,
                        state.current_byte_offset - comment_start_offset,
                        "Unclosed block comment reaches end of file.",
                    )
                }
                continue
            }
        }

        break
    }
}

// Scans an identifier or reserved keyword starting with a letter or underscore.
lexer_scan_identifier :: proc(state: ^LexerState) {
    start_offset: int = state.current_byte_offset

    for state.current_byte_offset < len(state.source_text) {
        current_character: u8 = state.source_text[state.current_byte_offset]
        is_identifier_part: bool = (current_character >= 'A' && current_character <= 'Z') ||
                                   (current_character >= 'a' && current_character <= 'z') ||
                                   (current_character >= '0' && current_character <= '9') ||
                                   (current_character == '_')
        if !is_identifier_part {
            break
        }
        state.current_byte_offset += 1
    }

    lexeme: string = state.source_text[start_offset:state.current_byte_offset]
    lexeme_length: int = len(lexeme)

    // Single underscore is a structural token
    if lexeme == "_" {
        lexer_emit_token(state, .Underscore, start_offset, state.current_byte_offset)

        return
    }

    // Check reserved keywords and primitives
    keyword_kind, is_keyword := keyword_lookup_by_name(lexeme)
    if is_keyword {
        // Compound keyword check for must!, try?, try!, as?, as!
        if lexeme == "must" && state.current_byte_offset < len(state.source_text) &&
           state.source_text[state.current_byte_offset] == '!' {
            state.current_byte_offset += 1
            lexer_emit_token(state, .KeywordMustExclamation, start_offset, state.current_byte_offset)

            return
        }

        if lexeme == "try" && state.current_byte_offset < len(state.source_text) {
            next_character: u8 = state.source_text[state.current_byte_offset]
            if next_character == '?' {
                state.current_byte_offset += 1
                lexer_emit_token(state, .KeywordTryQuestion, start_offset, state.current_byte_offset)

                return
            }
            if next_character == '!' {
                state.current_byte_offset += 1
                lexer_emit_token(state, .KeywordTryExclamation, start_offset, state.current_byte_offset)

                return
            }
        }

        if lexeme == "as" && state.current_byte_offset < len(state.source_text) {
            next_character: u8 = state.source_text[state.current_byte_offset]
            if next_character == '?' {
                state.current_byte_offset += 1
                lexer_emit_token(state, .KeywordAsQuestion, start_offset, state.current_byte_offset)

                return
            }
            if next_character == '!' {
                state.current_byte_offset += 1
                lexer_emit_token(state, .KeywordAsExclamation, start_offset, state.current_byte_offset)

                return
            }
        }

        identifier_hash: u64 = hash_compute_fnv1a64(lexeme)
        lexer_emit_token(state, keyword_kind, start_offset, state.current_byte_offset, {}, identifier_hash)

        return
    }

    // Not a keyword: validate identifier category format
    // Count underscores
    underscore_count: int = 0
    for character_index in 0 ..< lexeme_length {
        if lexeme[character_index] == '_' {
            underscore_count += 1
        }
    }

    first_character: u8 = lexeme[0]
    token_kind: TokenKind = .MalformedIdentifier

    if first_character >= 'A' && first_character <= 'Z' {
        if underscore_count == 0 {
            token_kind = .PublicIdentifier
        } else if underscore_count == 1 && lexeme[lexeme_length - 1] == '_' {
            token_kind = .InternalIdentifier
        }
    } else if first_character == '_' {
        if lexeme_length >= 2 && lexeme[1] >= 'a' && lexeme[1] <= 'z' && underscore_count == 1 {
            token_kind = .PrivateIdentifier
        }
    } else if first_character >= 'a' && first_character <= 'z' {
        if underscore_count == 0 {
            token_kind = .LocalIdentifier
        }
    }

    identifier_hash: u64 = hash_compute_fnv1a64(lexeme)

    if token_kind == .MalformedIdentifier {
        lexer_record_diagnostic(
            state,
            .InvalidIdentifierFormat,
            .Error,
            start_offset,
            state.current_byte_offset - start_offset,
            "Identifier format violates lexical rules.",
        )
    }

    lexer_emit_token(state, token_kind, start_offset, state.current_byte_offset, {}, identifier_hash)
}

// Scans an escaped keyword enclosed in backticks.
lexer_scan_escaped_keyword :: proc(state: ^LexerState) {
    start_offset: int = state.current_byte_offset
    state.current_byte_offset += 1 // Skip opening backtick

    inner_start_offset: int = state.current_byte_offset
    found_closing_backtick: bool = false

    for state.current_byte_offset < len(state.source_text) {
        current_character: u8 = state.source_text[state.current_byte_offset]
        if current_character == '`' {
            found_closing_backtick = true
            break
        }
        if current_character == '\n' || current_character == '\r' {
            break
        }

        sequence_length, is_valid_utf8 := utf8_validate_sequence(state.source_text, state.current_byte_offset)
        if !is_valid_utf8 {
            lexer_record_diagnostic(
                state,
                .MalformedUtf8Sequence,
                .Error,
                state.current_byte_offset,
                1,
                "Malformed UTF-8 sequence inside escaped identifier.",
            )
            state.current_byte_offset += 1
        } else {
            state.current_byte_offset += sequence_length
        }
    }

    if !found_closing_backtick {
        inner_text: string = state.source_text[inner_start_offset:state.current_byte_offset]
        identifier_hash: u64 = hash_compute_fnv1a64(inner_text)
        lexer_record_diagnostic(
            state,
            .UnterminatedEscapedIdentifier,
            .Error,
            start_offset,
            state.current_byte_offset - start_offset,
            "Unterminated escaped keyword identifier.",
        )
        lexer_emit_token(state, .MalformedIdentifier, start_offset, state.current_byte_offset, {}, identifier_hash)

        return
    }

    inner_text: string = state.source_text[inner_start_offset:state.current_byte_offset]
    state.current_byte_offset += 1 // Skip closing backtick

    identifier_hash: u64 = hash_compute_fnv1a64(inner_text)

    if !keyword_is_reserved_keyword(inner_text) {
        lexer_record_diagnostic(
            state,
            .InvalidEscapedIdentifier,
            .Error,
            start_offset,
            state.current_byte_offset - start_offset,
            "Escaped identifier must contain a valid reserved keyword.",
        )
        lexer_emit_token(state, .MalformedIdentifier, start_offset, state.current_byte_offset, {}, identifier_hash)

        return
    }

    lexer_emit_token(state, .EscapedIdentifier, start_offset, state.current_byte_offset, {}, identifier_hash)
}

// Scans decimal digits with underscore separators and detects malformed placement.
lexer_scan_decimal_digits :: proc(
    state: ^LexerState,
) -> (digit_count: int, has_malformed_underscore: bool) {
    digit_count = 0
    has_malformed_underscore = false
    previous_was_underscore: bool = false

    if state.current_byte_offset < len(state.source_text) &&
       state.source_text[state.current_byte_offset] == '_' {
        has_malformed_underscore = true
    }

    for state.current_byte_offset < len(state.source_text) {
        current_character: u8 = state.source_text[state.current_byte_offset]
        if current_character >= '0' && current_character <= '9' {
            digit_count += 1
            previous_was_underscore = false
            state.current_byte_offset += 1
        } else if current_character == '_' {
            if previous_was_underscore {
                has_malformed_underscore = true
            }
            previous_was_underscore = true
            state.current_byte_offset += 1
        } else {
            break
        }
    }

    if previous_was_underscore {
        has_malformed_underscore = true
    }

    return digit_count, has_malformed_underscore
}

// Scans numeric literals including integers, hexadecimals, binaries, and floating-point numbers.
lexer_scan_number :: proc(state: ^LexerState) {
    start_offset: int = state.current_byte_offset
    flags: TokenFlags = {}

    // Check for 0x (Hex) or 0b (Binary)
    if state.source_text[state.current_byte_offset] == '0' && state.current_byte_offset + 1 < len(state.source_text) {
        second_character: u8 = state.source_text[state.current_byte_offset + 1]

        // Hexadecimal
        if second_character == 'x' || second_character == 'X' {
            if second_character == 'X' {
                lexer_record_diagnostic(
                    state,
                    .InvalidNumberPrefix,
                    .Error,
                    start_offset,
                    2,
                    "Hexadecimal prefix must be lowercase '0x'.",
                )
            }
            state.current_byte_offset += 2 // Skip 0x

            digit_count: int = 0
            has_malformed_underscore: bool = false
            previous_was_underscore: bool = false

            if state.current_byte_offset < len(state.source_text) &&
               state.source_text[state.current_byte_offset] == '_' {
                has_malformed_underscore = true
            }

            for state.current_byte_offset < len(state.source_text) {
                hex_character: u8 = state.source_text[state.current_byte_offset]
                is_hex_digit: bool = (hex_character >= '0' && hex_character <= '9') ||
                                     (hex_character >= 'a' && hex_character <= 'f') ||
                                     (hex_character >= 'A' && hex_character <= 'F')
                if is_hex_digit {
                    digit_count += 1
                    previous_was_underscore = false
                    state.current_byte_offset += 1
                } else if hex_character == '_' {
                    if previous_was_underscore {
                        has_malformed_underscore = true
                    }
                    previous_was_underscore = true
                    state.current_byte_offset += 1
                } else {
                    break
                }
            }

            if previous_was_underscore || digit_count == 0 {
                has_malformed_underscore = true
            }

            if has_malformed_underscore {
                lexer_record_diagnostic(
                    state,
                    .MalformedNumberLiteral,
                    .Error,
                    start_offset,
                    state.current_byte_offset - start_offset,
                    "Malformed hexadecimal literal.",
                )
            }

            // Suffix check
            if state.current_byte_offset + 1 < len(state.source_text) &&
               state.source_text[state.current_byte_offset] == 'u' &&
               state.source_text[state.current_byte_offset + 1] == 'L' {
                flags += {.IntegerSuffixUnsignedLong}
                state.current_byte_offset += 2
            } else if state.current_byte_offset < len(state.source_text) &&
                      state.source_text[state.current_byte_offset] == 'u' {
                flags += {.IntegerSuffixUnsigned}
                state.current_byte_offset += 1
            } else if state.current_byte_offset < len(state.source_text) &&
                      state.source_text[state.current_byte_offset] == 'L' {
                flags += {.IntegerSuffixLong}
                state.current_byte_offset += 1
            }

            // Trailing invalid characters check
            if state.current_byte_offset < len(state.source_text) {
                trailing_character: u8 = state.source_text[state.current_byte_offset]
                if (trailing_character >= 'a' && trailing_character <= 'z') ||
                   (trailing_character >= 'A' && trailing_character <= 'Z') ||
                   (trailing_character >= '0' && trailing_character <= '9') ||
                   (trailing_character == '_') {
                    invalid_suffix_start: int = state.current_byte_offset
                    for state.current_byte_offset < len(state.source_text) {
                        character_to_check: u8 = state.source_text[state.current_byte_offset]
                        if (character_to_check >= 'a' && character_to_check <= 'z') ||
                           (character_to_check >= 'A' && character_to_check <= 'Z') ||
                           (character_to_check >= '0' && character_to_check <= '9') ||
                           (character_to_check == '_') {
                            state.current_byte_offset += 1
                        } else {
                            break
                        }
                    }
                    lexer_record_diagnostic(
                        state,
                        .InvalidNumberSuffix,
                        .Error,
                        invalid_suffix_start,
                        state.current_byte_offset - invalid_suffix_start,
                        "Invalid number literal suffix.",
                    )
                }
            }

            lexer_emit_token(state, .IntegerLiteral, start_offset, state.current_byte_offset, flags)

            return
        }

        // Binary
        if second_character == 'b' || second_character == 'B' {
            if second_character == 'B' {
                lexer_record_diagnostic(
                    state,
                    .InvalidNumberPrefix,
                    .Error,
                    start_offset,
                    2,
                    "Binary prefix must be lowercase '0b'.",
                )
            }
            state.current_byte_offset += 2 // Skip 0b

            digit_count: int = 0
            has_malformed_underscore: bool = false
            has_invalid_binary_digit: bool = false
            previous_was_underscore: bool = false

            if state.current_byte_offset < len(state.source_text) &&
               state.source_text[state.current_byte_offset] == '_' {
                has_malformed_underscore = true
            }

            for state.current_byte_offset < len(state.source_text) {
                binary_character: u8 = state.source_text[state.current_byte_offset]
                if binary_character == '0' || binary_character == '1' {
                    digit_count += 1
                    previous_was_underscore = false
                    state.current_byte_offset += 1
                } else if binary_character == '_' {
                    if previous_was_underscore {
                        has_malformed_underscore = true
                    }
                    previous_was_underscore = true
                    state.current_byte_offset += 1
                } else if binary_character >= '2' && binary_character <= '9' {
                    invalid_digit_start: int = state.current_byte_offset
                    for state.current_byte_offset < len(state.source_text) {
                        character_to_check: u8 = state.source_text[state.current_byte_offset]
                        if (character_to_check >= '0' && character_to_check <= '9') || character_to_check == '_' {
                            state.current_byte_offset += 1
                        } else {
                            break
                        }
                    }
                    lexer_record_diagnostic(
                        state,
                        .InvalidBinaryDigit,
                        .Error,
                        invalid_digit_start,
                        state.current_byte_offset - invalid_digit_start,
                        "Invalid digit in binary literal.",
                    )
                    has_invalid_binary_digit = true
                    break
                } else {
                    break
                }
            }

            if previous_was_underscore || digit_count == 0 {
                has_malformed_underscore = true
            }

            if has_malformed_underscore && !has_invalid_binary_digit {
                lexer_record_diagnostic(
                    state,
                    .MalformedNumberLiteral,
                    .Error,
                    start_offset,
                    state.current_byte_offset - start_offset,
                    "Malformed binary literal.",
                )
            }

            // Suffix check
            if state.current_byte_offset + 1 < len(state.source_text) &&
               state.source_text[state.current_byte_offset] == 'u' &&
               state.source_text[state.current_byte_offset + 1] == 'L' {
                flags += {.IntegerSuffixUnsignedLong}
                state.current_byte_offset += 2
            } else if state.current_byte_offset < len(state.source_text) &&
                      state.source_text[state.current_byte_offset] == 'u' {
                flags += {.IntegerSuffixUnsigned}
                state.current_byte_offset += 1
            } else if state.current_byte_offset < len(state.source_text) &&
                      state.source_text[state.current_byte_offset] == 'L' {
                flags += {.IntegerSuffixLong}
                state.current_byte_offset += 1
            }

            // Trailing invalid characters check
            if state.current_byte_offset < len(state.source_text) {
                trailing_character: u8 = state.source_text[state.current_byte_offset]
                if (trailing_character >= 'a' && trailing_character <= 'z') ||
                   (trailing_character >= 'A' && trailing_character <= 'Z') ||
                   (trailing_character >= '0' && trailing_character <= '9') ||
                   (trailing_character == '_') {
                    invalid_suffix_start: int = state.current_byte_offset
                    for state.current_byte_offset < len(state.source_text) {
                        character_to_check: u8 = state.source_text[state.current_byte_offset]
                        if (character_to_check >= 'a' && character_to_check <= 'z') ||
                           (character_to_check >= 'A' && character_to_check <= 'Z') ||
                           (character_to_check >= '0' && character_to_check <= '9') ||
                           (character_to_check == '_') {
                            state.current_byte_offset += 1
                        } else {
                            break
                        }
                    }
                    lexer_record_diagnostic(
                        state,
                        .InvalidNumberSuffix,
                        .Error,
                        invalid_suffix_start,
                        state.current_byte_offset - invalid_suffix_start,
                        "Invalid number literal suffix.",
                    )
                }
            }

            lexer_emit_token(state, .IntegerLiteral, start_offset, state.current_byte_offset, flags)

            return
        }
    }

    // Decimal or Floating Point
    _, has_malformed_integer_underscore := lexer_scan_decimal_digits(state)
    is_float: bool = false

    // Check for fractional part
    if state.current_byte_offset < len(state.source_text) &&
       state.source_text[state.current_byte_offset] == '.' {
        // Crucial lookahead: only consume '.' if followed by an ASCII digit
        if state.current_byte_offset + 1 < len(state.source_text) {
            next_after_dot: u8 = state.source_text[state.current_byte_offset + 1]
            if next_after_dot >= '0' && next_after_dot <= '9' {
                is_float = true
                state.current_byte_offset += 1 // Consume '.'
                fraction_digit_count, has_malformed_fraction_underscore := lexer_scan_decimal_digits(state)
                if fraction_digit_count == 0 || has_malformed_fraction_underscore || has_malformed_integer_underscore {
                    lexer_record_diagnostic(
                        state,
                        .MalformedNumberLiteral,
                        .Error,
                        start_offset,
                        state.current_byte_offset - start_offset,
                        "Malformed floating-point literal fraction.",
                    )
                }
            }
        }
    }

    if !is_float && has_malformed_integer_underscore {
        lexer_record_diagnostic(
            state,
            .MalformedNumberLiteral,
            .Error,
            start_offset,
            state.current_byte_offset - start_offset,
            "Malformed integer literal with misplaced underscore.",
        )
    }

    // Check for exponent (e or E)
    if state.current_byte_offset < len(state.source_text) {
        exponent_character: u8 = state.source_text[state.current_byte_offset]
        if exponent_character == 'e' || exponent_character == 'E' {
            if !is_float {
                lexer_record_diagnostic(
                    state,
                    .MalformedNumberLiteral,
                    .Error,
                    start_offset,
                    state.current_byte_offset - start_offset,
                    "Floating-point exponent requires decimal point.",
                )
                is_float = true
            }
            state.current_byte_offset += 1 // Consume e / E
            if state.current_byte_offset < len(state.source_text) {
                sign_character: u8 = state.source_text[state.current_byte_offset]
                if sign_character == '+' || sign_character == '-' {
                    state.current_byte_offset += 1
                }
            }
            exponent_digit_count, has_malformed_exponent_underscore := lexer_scan_decimal_digits(state)
            if exponent_digit_count == 0 || has_malformed_exponent_underscore {
                lexer_record_diagnostic(
                    state,
                    .MalformedNumberLiteral,
                    .Error,
                    start_offset,
                    state.current_byte_offset - start_offset,
                    "Malformed floating-point literal exponent.",
                )
            }
        }
    }

    if is_float {
        // Float suffixes: f, d
        if state.current_byte_offset < len(state.source_text) {
            suffix_character: u8 = state.source_text[state.current_byte_offset]
            if suffix_character == 'f' {
                flags += {.FloatSuffixSingle}
                state.current_byte_offset += 1
            } else if suffix_character == 'd' {
                flags += {.FloatSuffixDouble}
                state.current_byte_offset += 1
            }
        }
    } else {
        // Integer suffixes: uL, u, L
        if state.current_byte_offset + 1 < len(state.source_text) &&
           state.source_text[state.current_byte_offset] == 'u' &&
           state.source_text[state.current_byte_offset + 1] == 'L' {
            flags += {.IntegerSuffixUnsignedLong}
            state.current_byte_offset += 2
        } else if state.current_byte_offset < len(state.source_text) &&
                  state.source_text[state.current_byte_offset] == 'u' {
            flags += {.IntegerSuffixUnsigned}
            state.current_byte_offset += 1
        } else if state.current_byte_offset < len(state.source_text) &&
                  state.source_text[state.current_byte_offset] == 'L' {
            flags += {.IntegerSuffixLong}
            state.current_byte_offset += 1
        }
    }

    // Trailing invalid characters check
    if state.current_byte_offset < len(state.source_text) {
        trailing_character: u8 = state.source_text[state.current_byte_offset]
        if (trailing_character >= 'a' && trailing_character <= 'z') ||
           (trailing_character >= 'A' && trailing_character <= 'Z') ||
           (trailing_character >= '0' && trailing_character <= '9') ||
           (trailing_character == '_') {
            invalid_suffix_start: int = state.current_byte_offset
            for state.current_byte_offset < len(state.source_text) {
                character_to_check: u8 = state.source_text[state.current_byte_offset]
                if (character_to_check >= 'a' && character_to_check <= 'z') ||
                   (character_to_check >= 'A' && character_to_check <= 'Z') ||
                   (character_to_check >= '0' && character_to_check <= '9') ||
                   (character_to_check == '_') {
                    state.current_byte_offset += 1
                } else {
                    break
                }
            }
            lexer_record_diagnostic(
                state,
                .InvalidNumberSuffix,
                .Error,
                invalid_suffix_start,
                state.current_byte_offset - invalid_suffix_start,
                "Invalid number literal suffix.",
            )
        }
    }

    token_kind: TokenKind = is_float ? .FloatLiteral : .IntegerLiteral
    lexer_emit_token(state, token_kind, start_offset, state.current_byte_offset, flags)
}

// Validates and decodes a single escape sequence starting with a backslash.
lexer_scan_escape_sequence :: proc(
    state: ^LexerState,
    in_character_literal: bool,
) -> (decoded_code_point: u32, is_valid: bool) {
    escape_start_offset: int = state.current_byte_offset
    state.current_byte_offset += 1 // Skip '\'

    if state.current_byte_offset >= len(state.source_text) {
        lexer_record_diagnostic(
            state,
            .InvalidEscapeSequence,
            .Error,
            escape_start_offset,
            1,
            "Incomplete escape sequence at end of file.",
        )

        return 0, false
    }

    escape_kind: u8 = state.source_text[state.current_byte_offset]
    state.current_byte_offset += 1

    switch escape_kind {
    case 'n':
        return 0x0A, true
    case 'r':
        return 0x0D, true
    case 't':
        return 0x09, true
    case '\\':
        return 0x5C, true
    case '"':
        return 0x22, true
    case '\'':
        return 0x27, true
    case '0':
        return 0x00, true
    case 'x':
        accumulated_value: u32 = 0
        digits_found: int = 0
        for digits_found < 2 && state.current_byte_offset < len(state.source_text) {
            current_character: u8 = state.source_text[state.current_byte_offset]
            digit_value: int = hex_digit_to_int(current_character)
            if digit_value < 0 {
                break
            }
            accumulated_value = (accumulated_value << 4) | u32(digit_value)
            digits_found += 1
            state.current_byte_offset += 1
        }

        if digits_found < 2 {
            lexer_record_diagnostic(
                state,
                .InvalidEscapeSequence,
                .Error,
                escape_start_offset,
                state.current_byte_offset - escape_start_offset,
                "Hexadecimal escape sequence requires 2 hex digits.",
            )

            return 0, false
        }

        byte_value: u8 = u8(accumulated_value)
        if in_character_literal {
            if byte_value >= 0x80 {
                lexer_record_diagnostic(
                    state,
                    .MalformedUtf8EscapeSequence,
                    .Error,
                    escape_start_offset,
                    state.current_byte_offset - escape_start_offset,
                    "Hexadecimal escape sequence produces malformed UTF-8 in character literal.",
                )

                return u32(byte_value), false
            }

            return u32(byte_value), true
        } else {
            if byte_value >= 0x80 {
                target_length: int = 0
                if byte_value >= 0xC2 && byte_value <= 0xDF {
                    target_length = 2
                } else if byte_value >= 0xE0 && byte_value <= 0xEF {
                    target_length = 3
                } else if byte_value >= 0xF0 && byte_value <= 0xF4 {
                    target_length = 4
                }

                if target_length == 0 {
                    lexer_record_diagnostic(
                        state,
                        .MalformedUtf8EscapeSequence,
                        .Error,
                        escape_start_offset,
                        state.current_byte_offset - escape_start_offset,
                        "Hexadecimal escape sequence produces malformed UTF-8.",
                    )

                    return u32(byte_value), false
                }

                sequence_bytes: [4]u8
                sequence_bytes[0] = byte_value
                consecutive_count: int = 1
                lookahead_offset: int = state.current_byte_offset

                for consecutive_count < target_length {
                    if lookahead_offset + 3 < len(state.source_text) &&
                       state.source_text[lookahead_offset] == '\\' &&
                       state.source_text[lookahead_offset + 1] == 'x' {
                        first_digit: int = hex_digit_to_int(state.source_text[lookahead_offset + 2])
                        second_digit: int = hex_digit_to_int(state.source_text[lookahead_offset + 3])
                        if first_digit >= 0 && second_digit >= 0 {
                            next_byte: u8 = u8((first_digit << 4) | second_digit)
                            sequence_bytes[consecutive_count] = next_byte
                            consecutive_count += 1
                            lookahead_offset += 4
                            continue
                        }
                    }
                    break
                }

                is_sequence_valid: bool = false
                if consecutive_count == target_length {
                    slice_as_string: string = string(sequence_bytes[:target_length])
                    _, is_sequence_valid = utf8_validate_sequence(slice_as_string, 0)
                }

                if !is_sequence_valid {
                    lexer_record_diagnostic(
                        state,
                        .MalformedUtf8EscapeSequence,
                        .Error,
                        escape_start_offset,
                        state.current_byte_offset - escape_start_offset,
                        "Hexadecimal escape sequence produces malformed UTF-8.",
                    )

                    return u32(byte_value), false
                }

                state.current_byte_offset = lookahead_offset

                return u32(byte_value), true
            }

            return u32(byte_value), true
        }
    case 'u':
        accumulated_value: u32 = 0
        digits_found: int = 0
        for digits_found < 4 && state.current_byte_offset < len(state.source_text) {
            current_character: u8 = state.source_text[state.current_byte_offset]
            digit_value: int = hex_digit_to_int(current_character)
            if digit_value < 0 {
                break
            }
            accumulated_value = (accumulated_value << 4) | u32(digit_value)
            digits_found += 1
            state.current_byte_offset += 1
        }

        if digits_found < 4 {
            lexer_record_diagnostic(
                state,
                .InvalidEscapeSequence,
                .Error,
                escape_start_offset,
                state.current_byte_offset - escape_start_offset,
                "Unicode escape sequence requires 4 hex digits.",
            )

            return 0, false
        }

        // Check surrogate range
        if accumulated_value >= 0xD800 && accumulated_value <= 0xDFFF {
            lexer_record_diagnostic(
                state,
                .SurrogateUnicodeEscape,
                .Error,
                escape_start_offset,
                state.current_byte_offset - escape_start_offset,
                "Unicode escape sequence must not specify surrogate code points.",
            )

            return accumulated_value, false
        }

        return accumulated_value, true
    case 'U':
        accumulated_value: u32 = 0
        digits_found: int = 0
        for digits_found < 8 && state.current_byte_offset < len(state.source_text) {
            current_character: u8 = state.source_text[state.current_byte_offset]
            digit_value: int = hex_digit_to_int(current_character)
            if digit_value < 0 {
                break
            }
            accumulated_value = (accumulated_value << 4) | u32(digit_value)
            digits_found += 1
            state.current_byte_offset += 1
        }

        if digits_found < 8 {
            lexer_record_diagnostic(
                state,
                .InvalidEscapeSequence,
                .Error,
                escape_start_offset,
                state.current_byte_offset - escape_start_offset,
                "Unicode escape sequence requires 8 hex digits.",
            )

            return 0, false
        }

        if accumulated_value > 0x10FFFF {
            lexer_record_diagnostic(
                state,
                .OutOfRangeUnicodeEscape,
                .Error,
                escape_start_offset,
                state.current_byte_offset - escape_start_offset,
                "Unicode escape sequence exceeds maximum code point U+10FFFF.",
            )

            return accumulated_value, false
        }

        if accumulated_value >= 0xD800 && accumulated_value <= 0xDFFF {
            lexer_record_diagnostic(
                state,
                .SurrogateUnicodeEscape,
                .Error,
                escape_start_offset,
                state.current_byte_offset - escape_start_offset,
                "Unicode escape sequence must not specify surrogate code points.",
            )

            return accumulated_value, false
        }

        return accumulated_value, true
    case:
        lexer_record_diagnostic(
            state,
            .InvalidEscapeSequence,
            .Error,
            escape_start_offset,
            2,
            "Unrecognized escape sequence.",
        )

        return 0, false
    }
}

// Converts an ASCII hexadecimal digit character to its numeric integer value or -1 if invalid.
hex_digit_to_int :: proc(character: u8) -> int {
    if character >= '0' && character <= '9' {
        return int(character - '0')
    }
    if character >= 'a' && character <= 'f' {
        return int(character - 'a' + 10)
    }
    if character >= 'A' && character <= 'F' {
        return int(character - 'A' + 10)
    }

    return -1
}

// Scans a single-character or rune literal enclosed in single quotation marks.
lexer_scan_character_or_rune :: proc(state: ^LexerState) {
    start_offset: int = state.current_byte_offset
    state.current_byte_offset += 1 // Skip opening quote '

    if state.current_byte_offset >= len(state.source_text) {
        lexer_record_diagnostic(
            state,
            .UnterminatedCharacterLiteral,
            .Error,
            start_offset,
            1,
            "Unclosed character literal at end of file.",
        )
        lexer_emit_token(state, .CharacterLiteral, start_offset, state.current_byte_offset)

        return
    }

    if state.source_text[state.current_byte_offset] == '\'' {
        state.current_byte_offset += 1 // Consume closing quote
        lexer_record_diagnostic(
            state,
            .EmptyCharacterLiteral,
            .Error,
            start_offset,
            2,
            "Character literal must not be empty.",
        )
        lexer_emit_token(state, .CharacterLiteral, start_offset, state.current_byte_offset)

        return
    }

    code_point_count: int = 0
    last_code_point: u32 = 0
    flags: TokenFlags = {}

    for state.current_byte_offset < len(state.source_text) {
        current_character: u8 = state.source_text[state.current_byte_offset]

        if current_character == '\'' {
            break
        }

        if current_character == '\n' || current_character == '\r' {
            lexer_record_diagnostic(
                state,
                .UnterminatedCharacterLiteral,
                .Error,
                start_offset,
                state.current_byte_offset - start_offset,
                "Character literal must not span across newlines.",
            )
            lexer_emit_token(state, .CharacterLiteral, start_offset, state.current_byte_offset, flags)

            return
        }

        if current_character == '\\' {
            flags += {.HasEscapeSequences}
            // Check for \( in character literals which is forbidden
            if state.current_byte_offset + 1 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '(' {
                lexer_record_diagnostic(
                    state,
                    .InvalidEscapeSequence,
                    .Error,
                    state.current_byte_offset,
                    2,
                    "String interpolation delimiter is forbidden inside character literals.",
                )
                state.current_byte_offset += 2
                code_point_count += 1
                continue
            }

            decoded_value, _ := lexer_scan_escape_sequence(state, true)
            last_code_point = decoded_value
            code_point_count += 1
            continue
        }

        sequence_length, is_valid_utf8 := utf8_validate_sequence(state.source_text, state.current_byte_offset)
        if !is_valid_utf8 {
            lexer_record_diagnostic(
                state,
                .MalformedUtf8Sequence,
                .Error,
                state.current_byte_offset,
                1,
                "Malformed UTF-8 sequence inside character literal.",
            )
            state.current_byte_offset += 1
            code_point_count += 1
        } else {
            // Decode scalar code point
            if sequence_length == 1 {
                last_code_point = u32(state.source_text[state.current_byte_offset])
            } else if sequence_length == 2 {
                byte_0: u32 = u32(state.source_text[state.current_byte_offset] & 0x1F)
                byte_1: u32 = u32(state.source_text[state.current_byte_offset + 1] & 0x3F)
                last_code_point = (byte_0 << 6) | byte_1
            } else if sequence_length == 3 {
                byte_0: u32 = u32(state.source_text[state.current_byte_offset] & 0x0F)
                byte_1: u32 = u32(state.source_text[state.current_byte_offset + 1] & 0x3F)
                byte_2: u32 = u32(state.source_text[state.current_byte_offset + 2] & 0x3F)
                last_code_point = (byte_0 << 12) | (byte_1 << 6) | byte_2
            } else if sequence_length == 4 {
                byte_0: u32 = u32(state.source_text[state.current_byte_offset] & 0x07)
                byte_1: u32 = u32(state.source_text[state.current_byte_offset + 1] & 0x3F)
                byte_2: u32 = u32(state.source_text[state.current_byte_offset + 2] & 0x3F)
                byte_3: u32 = u32(state.source_text[state.current_byte_offset + 3] & 0x3F)
                last_code_point = (byte_0 << 18) | (byte_1 << 12) | (byte_2 << 6) | byte_3
            }
            state.current_byte_offset += sequence_length
            code_point_count += 1
        }
    }

    if state.current_byte_offset < len(state.source_text) && state.source_text[state.current_byte_offset] == '\'' {
        state.current_byte_offset += 1 // Skip closing quote
    } else {
        lexer_record_diagnostic(
            state,
            .UnterminatedCharacterLiteral,
            .Error,
            start_offset,
            state.current_byte_offset - start_offset,
            "Unclosed character literal at end of file.",
        )
    }

    if code_point_count > 1 {
        lexer_record_diagnostic(
            state,
            .MultiCharacterLiteral,
            .Error,
            start_offset,
            state.current_byte_offset - start_offset,
            "Character literal must contain exactly one character.",
        )
        lexer_emit_token(state, .CharacterLiteral, start_offset, state.current_byte_offset, flags)

        return
    }

    token_kind: TokenKind = (last_code_point <= 0x7F) ? .CharacterLiteral : .RuneLiteral
    lexer_emit_token(state, token_kind, start_offset, state.current_byte_offset, flags)
}

// Scans raw multi-line triple-quoted string literals and validates their indentation rules.
lexer_scan_raw_string :: proc(state: ^LexerState) {
    start_offset: int = state.current_byte_offset
    state.current_byte_offset += 3 // Skip opening """

    found_closing_quotes: bool = false

    for state.current_byte_offset + 2 < len(state.source_text) {
        if state.source_text[state.current_byte_offset] == '"' &&
           state.source_text[state.current_byte_offset + 1] == '"' &&
           state.source_text[state.current_byte_offset + 2] == '"' {
            found_closing_quotes = true
            break
        }

        current_character: u8 = state.source_text[state.current_byte_offset]
        if current_character == '\r' {
            state.current_byte_offset += 1
            if state.current_byte_offset < len(state.source_text) && state.source_text[state.current_byte_offset] == '\n' {
                state.current_byte_offset += 1
            }
            append(&state.line_start_offsets, u32(state.current_byte_offset))
            continue
        }

        if current_character == '\n' {
            state.current_byte_offset += 1
            append(&state.line_start_offsets, u32(state.current_byte_offset))
            continue
        }

        sequence_length, is_valid_utf8 := utf8_validate_sequence(state.source_text, state.current_byte_offset)
        if !is_valid_utf8 {
            lexer_record_diagnostic(
                state,
                .MalformedUtf8Sequence,
                .Error,
                state.current_byte_offset,
                1,
                "Malformed UTF-8 sequence in raw string.",
            )
            state.current_byte_offset += 1
        } else {
            state.current_byte_offset += sequence_length
        }
    }

    if !found_closing_quotes {
        for state.current_byte_offset < len(state.source_text) {
            current_character: u8 = state.source_text[state.current_byte_offset]
            if current_character == '\r' {
                state.current_byte_offset += 1
                if state.current_byte_offset < len(state.source_text) && state.source_text[state.current_byte_offset] == '\n' {
                    state.current_byte_offset += 1
                }
                append(&state.line_start_offsets, u32(state.current_byte_offset))
                continue
            }
            if current_character == '\n' {
                state.current_byte_offset += 1
                append(&state.line_start_offsets, u32(state.current_byte_offset))
                continue
            }
            sequence_length, is_valid_utf8 := utf8_validate_sequence(state.source_text, state.current_byte_offset)
            if !is_valid_utf8 {
                lexer_record_diagnostic(
                    state,
                    .MalformedUtf8Sequence,
                    .Error,
                    state.current_byte_offset,
                    1,
                    "Malformed UTF-8 sequence in raw string.",
                )
                state.current_byte_offset += 1
            } else {
                state.current_byte_offset += sequence_length
            }
        }

        lexer_record_diagnostic(
            state,
            .UnterminatedRawStringLiteral,
            .Error,
            start_offset,
            state.current_byte_offset - start_offset,
            "Unclosed raw string literal reaches end of file.",
        )
        lexer_emit_token(state, .RawStringLiteral, start_offset, state.current_byte_offset)

        return
    }

    closing_quotes_offset: int = state.current_byte_offset
    state.current_byte_offset += 3 // Consume closing """

    // Validate multi-line indentation
    raw_content: string = state.source_text[start_offset:state.current_byte_offset]
    has_newlines: bool = strings.contains_any(raw_content, "\r\n")

    if has_newlines {
        // Locate start of closing line
        closing_line_start: int = closing_quotes_offset
        for closing_line_start > start_offset {
            previous_character: u8 = state.source_text[closing_line_start - 1]
            if previous_character == '\n' || previous_character == '\r' {
                break
            }
            closing_line_start -= 1
        }

        closing_indentation: string = state.source_text[closing_line_start:closing_quotes_offset]
        has_invalid_closing_indentation: bool = false

        for indentation_index in 0 ..< len(closing_indentation) {
            indentation_character: u8 = closing_indentation[indentation_index]
            if indentation_character != ' ' && indentation_character != '\t' {
                has_invalid_closing_indentation = true
                break
            }
        }

        if has_invalid_closing_indentation {
            lexer_record_diagnostic(
                state,
                .RawStringInsufficientIndentation,
                .Error,
                closing_line_start,
                closing_quotes_offset - closing_line_start,
                "Closing raw string delimiter must be preceded exclusively by indentation whitespace.",
            )
        } else {
            // Check content lines
            content_inside: string = state.source_text[start_offset + 3:closing_line_start]
            current_line_start: int = 0

            for index in 0 ..< len(content_inside) {
                character: u8 = content_inside[index]
                if character == '\n' && index > 0 && content_inside[index - 1] == '\r' {
                    continue
                }

                if character == '\n' || character == '\r' {
                    line_slice: string = content_inside[current_line_start:index]
                    // Skip checking the opening line
                    if current_line_start > 0 && len(line_slice) > 0 {
                        is_whitespace_only: bool = true
                        for byte_index in 0 ..< len(line_slice) {
                            line_character: u8 = line_slice[byte_index]
                            if line_character != ' ' && line_character != '\t' {
                                is_whitespace_only = false
                                break
                            }
                        }

                        if !is_whitespace_only {
                            if !strings.has_prefix(line_slice, closing_indentation) {
                                lexer_record_diagnostic(
                                    state,
                                    .RawStringInsufficientIndentation,
                                    .Error,
                                    start_offset + 3 + current_line_start,
                                    len(line_slice),
                                    "Raw string content line has insufficient indentation compared to closing delimiter.",
                                )
                                break
                            }
                        }
                    }

                    if character == '\r' && index + 1 < len(content_inside) && content_inside[index + 1] == '\n' {
                        current_line_start = index + 2
                    } else {
                        current_line_start = index + 1
                    }
                }
            }
        }
    }

    lexer_emit_token(state, .RawStringLiteral, start_offset, state.current_byte_offset)
}

// Scans standard double-quoted strings and initiates string interpolation contexts.
lexer_scan_string_literal :: proc(state: ^LexerState) {
    start_offset: int = state.current_byte_offset
    state.current_byte_offset += 1 // Skip opening quote "

    flags: TokenFlags = {}

    for state.current_byte_offset < len(state.source_text) {
        current_character: u8 = state.source_text[state.current_byte_offset]

        if current_character == '"' {
            state.current_byte_offset += 1 // Consume closing quote
            lexer_emit_token(state, .StringLiteral, start_offset, state.current_byte_offset, flags)

            return
        }

        if current_character == '\n' || current_character == '\r' {
            lexer_record_diagnostic(
                state,
                .UnterminatedStringLiteral,
                .Error,
                start_offset,
                state.current_byte_offset - start_offset,
                "String literal must not span across newlines.",
            )
            lexer_emit_token(state, .StringLiteral, start_offset, state.current_byte_offset, flags)

            return
        }

        if current_character == '\\' {
            flags += {.HasEscapeSequences}
            // Check for interpolation delimiter \(
            if state.current_byte_offset + 1 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '(' {
                interpolation_start_offset: int = state.current_byte_offset
                // Emit opening string segment
                lexer_emit_token(
                    state,
                    .InterpolatedStringStart,
                    start_offset,
                    interpolation_start_offset,
                    flags,
                )
                // Emit \( delimiter
                state.current_byte_offset += 2
                lexer_emit_token(
                    state,
                    .InterpolationStart,
                    interpolation_start_offset,
                    state.current_byte_offset,
                )
                // Push interpolation frame
                append(&state.interpolation_stack, InterpolationFrame{
                    parenthesis_depth = 0,
                })

                return
            }

            // Normal escape sequence
            lexer_scan_escape_sequence(state, false)
            continue
        }

        sequence_length, is_valid_utf8 := utf8_validate_sequence(state.source_text, state.current_byte_offset)
        if !is_valid_utf8 {
            lexer_record_diagnostic(
                state,
                .MalformedUtf8Sequence,
                .Error,
                state.current_byte_offset,
                1,
                "Malformed UTF-8 sequence inside string literal.",
            )
            state.current_byte_offset += 1
        } else {
            state.current_byte_offset += sequence_length
        }
    }

    lexer_record_diagnostic(
        state,
        .UnterminatedStringLiteral,
        .Error,
        start_offset,
        state.current_byte_offset - start_offset,
        "Unclosed string literal reaches end of file.",
    )
    lexer_emit_token(state, .StringLiteral, start_offset, state.current_byte_offset, flags)
}

// Resumes scanning an enclosing string literal following an interpolation closing parenthesis.
lexer_resume_interpolated_string :: proc(state: ^LexerState) {
    segment_start_offset: int = state.current_byte_offset
    flags: TokenFlags = {}

    for state.current_byte_offset < len(state.source_text) {
        current_character: u8 = state.source_text[state.current_byte_offset]

        if current_character == '"' {
            state.current_byte_offset += 1 // Consume closing quote "
            lexer_emit_token(
                state,
                .InterpolatedStringEnd,
                segment_start_offset,
                state.current_byte_offset,
                flags,
            )
            pop(&state.interpolation_stack)

            return
        }

        if current_character == '\n' || current_character == '\r' {
            lexer_record_diagnostic(
                state,
                .UnterminatedStringLiteral,
                .Error,
                segment_start_offset,
                state.current_byte_offset - segment_start_offset,
                "Interpolated string segment must not span across newlines.",
            )
            lexer_emit_token(
                state,
                .InterpolatedStringEnd,
                segment_start_offset,
                state.current_byte_offset,
                flags,
            )
            pop(&state.interpolation_stack)

            return
        }

        if current_character == '\\' {
            flags += {.HasEscapeSequences}
            // Check for next interpolation delimiter \(
            if state.current_byte_offset + 1 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '(' {
                interpolation_start_offset: int = state.current_byte_offset
                // Emit middle string segment
                lexer_emit_token(
                    state,
                    .InterpolatedStringMiddle,
                    segment_start_offset,
                    interpolation_start_offset,
                    flags,
                )
                // Emit \( delimiter
                state.current_byte_offset += 2
                lexer_emit_token(
                    state,
                    .InterpolationStart,
                    interpolation_start_offset,
                    state.current_byte_offset,
                )
                // Reset frame parenthesis depth
                if len(state.interpolation_stack) > 0 {
                    state.interpolation_stack[len(state.interpolation_stack) - 1].parenthesis_depth = 0
                }

                return
            }

            // Normal escape sequence
            lexer_scan_escape_sequence(state, false)
            continue
        }

        sequence_length, is_valid_utf8 := utf8_validate_sequence(state.source_text, state.current_byte_offset)
        if !is_valid_utf8 {
            lexer_record_diagnostic(
                state,
                .MalformedUtf8Sequence,
                .Error,
                state.current_byte_offset,
                1,
                "Malformed UTF-8 sequence inside interpolated string.",
            )
            state.current_byte_offset += 1
        } else {
            state.current_byte_offset += sequence_length
        }
    }

    lexer_record_diagnostic(
        state,
        .UnterminatedStringLiteral,
        .Error,
        segment_start_offset,
        state.current_byte_offset - segment_start_offset,
        "Unclosed interpolated string reaches end of file.",
    )
    lexer_emit_token(
        state,
        .InterpolatedStringEnd,
        segment_start_offset,
        state.current_byte_offset,
        flags,
    )
    pop(&state.interpolation_stack)
}

// Tokenizes an entire UTF-8 source buffer into a self-contained `LexedSourceFile`.
lexer_tokenize_source :: proc(
    source_text: string,
    configuration: LexerConfiguration = {},
) -> LexedSourceFile {
    allocator: runtime.Allocator = configuration.allocator
    if allocator.procedure == nil {
        allocator = context.allocator
    }

    state := LexerState{
        source_text             = source_text,
        current_byte_offset     = 0,
        configuration           = configuration,
        tokens                  = make([dynamic]Token, allocator),
        top_level_spans         = make([dynamic]TopLevelTokenSpan, allocator),
        line_start_offsets      = make([dynamic]u32, allocator),
        diagnostics             = make([dynamic]LexerDiagnostic, allocator),
        delimiter_stack         = make([dynamic]DelimiterStackEntry, allocator),
        interpolation_stack     = make([dynamic]InterpolationFrame, allocator),
        current_top_level_start = 0,
        preceded_by_whitespace  = false,
        preceded_by_newline     = false,
    }
    defer delete(state.delimiter_stack)
    defer delete(state.interpolation_stack)

    // Line 1 starts at byte offset 0
    append(&state.line_start_offsets, 0)

    // Check for UTF-8 Byte Order Mark (BOM: 0xEF, 0xBB, 0xBF)
    if len(source_text) >= 3 &&
       u8(source_text[0]) == 0xEF &&
       u8(source_text[1]) == 0xBB &&
       u8(source_text[2]) == 0xBF {
        lexer_record_diagnostic(
            &state,
            .ByteOrderMarkForbidden,
            .Error,
            0,
            3,
            "Source file contains forbidden UTF-8 Byte Order Mark (BOM).",
        )
        state.current_byte_offset = 3
    }

    // Main tokenization loop
    for {
        lexer_skip_whitespace_and_comments(&state)

        if state.current_byte_offset >= len(state.source_text) {
            break
        }

        start_offset: int = state.current_byte_offset
        current_character: u8 = state.source_text[state.current_byte_offset]

        // Identifiers and keywords
        if (current_character >= 'A' && current_character <= 'Z') ||
           (current_character >= 'a' && current_character <= 'z') ||
           (current_character == '_') {
            lexer_scan_identifier(&state)
            continue
        }

        // Escaped keywords
        if current_character == '`' {
            lexer_scan_escaped_keyword(&state)
            continue
        }

        // Numeric literals
        if current_character >= '0' && current_character <= '9' {
            lexer_scan_number(&state)
            continue
        }

        // Character and rune literals
        if current_character == '\'' {
            lexer_scan_character_or_rune(&state)
            continue
        }

        // Raw strings (""") vs standard strings (")
        if current_character == '"' {
            if state.current_byte_offset + 2 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '"' &&
               state.source_text[state.current_byte_offset + 2] == '"' {
                lexer_scan_raw_string(&state)
            } else {
                lexer_scan_string_literal(&state)
            }
            continue
        }

        // Parentheses with interpolation tracking
        if current_character == '(' {
            state.current_byte_offset += 1
            if len(state.interpolation_stack) > 0 {
                state.interpolation_stack[len(state.interpolation_stack) - 1].parenthesis_depth += 1
            }
            lexer_emit_token(&state, .LeftParenthesis, start_offset, state.current_byte_offset)
            continue
        }

        if current_character == ')' {
            state.current_byte_offset += 1
            if len(state.interpolation_stack) > 0 {
                top_frame_index: int = len(state.interpolation_stack) - 1
                if state.interpolation_stack[top_frame_index].parenthesis_depth == 0 {
                    // Check if previous token was InterpolationStart (empty interpolation check)
                    if len(state.tokens) > 0 && state.tokens[len(state.tokens) - 1].kind == .InterpolationStart {
                        lexer_record_diagnostic(
                            &state,
                            .EmptyStringInterpolation,
                            .Error,
                            start_offset - 2,
                            3,
                            "Empty string interpolation expression is forbidden.",
                        )
                    }
                    lexer_emit_token(&state, .InterpolationEnd, start_offset, state.current_byte_offset)
                    lexer_resume_interpolated_string(&state)
                    continue
                } else {
                    state.interpolation_stack[top_frame_index].parenthesis_depth -= 1
                    lexer_emit_token(&state, .RightParenthesis, start_offset, state.current_byte_offset)
                    continue
                }
            } else {
                lexer_emit_token(&state, .RightParenthesis, start_offset, state.current_byte_offset)
                continue
            }
        }

        // Braces and Brackets
        if current_character == '{' {
            state.current_byte_offset += 1
            lexer_emit_token(&state, .LeftBrace, start_offset, state.current_byte_offset)
            continue
        }
        if current_character == '}' {
            state.current_byte_offset += 1
            lexer_emit_token(&state, .RightBrace, start_offset, state.current_byte_offset)
            continue
        }
        if current_character == '[' {
            state.current_byte_offset += 1
            lexer_emit_token(&state, .LeftBracket, start_offset, state.current_byte_offset)
            continue
        }
        if current_character == ']' {
            state.current_byte_offset += 1
            lexer_emit_token(&state, .RightBracket, start_offset, state.current_byte_offset)
            continue
        }

        // Punctuation and simple symbols
        if current_character == ',' {
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Comma, start_offset, state.current_byte_offset)
            continue
        }
        if current_character == ';' {
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Semicolon, start_offset, state.current_byte_offset)
            continue
        }
        if current_character == '@' {
            state.current_byte_offset += 1
            lexer_emit_token(&state, .At, start_offset, state.current_byte_offset)
            continue
        }
        if current_character == '^' {
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Caret, start_offset, state.current_byte_offset)
            continue
        }
        if current_character == '~' {
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Tilde, start_offset, state.current_byte_offset)
            continue
        }

        // Colon operators: ::, :=, :
        if current_character == ':' {
            if state.current_byte_offset + 1 < len(state.source_text) {
                next_character: u8 = state.source_text[state.current_byte_offset + 1]
                if next_character == ':' {
                    state.current_byte_offset += 2
                    lexer_emit_token(&state, .DoubleColon, start_offset, state.current_byte_offset)
                    continue
                }
                if next_character == '=' {
                    state.current_byte_offset += 2
                    lexer_emit_token(&state, .ColonAssign, start_offset, state.current_byte_offset)
                    continue
                }
            }
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Colon, start_offset, state.current_byte_offset)
            continue
        }

        // Dollar operators: $:
        if current_character == '$' {
            if state.current_byte_offset + 1 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == ':' {
                state.current_byte_offset += 2
                lexer_emit_token(&state, .DollarColon, start_offset, state.current_byte_offset)
                continue
            }
            state.current_byte_offset += 1
            lexer_record_diagnostic(
                &state,
                .UnexpectedCharacter,
                .Error,
                start_offset,
                1,
                "Unexpected character '$'.",
            )
            lexer_emit_token(&state, .Invalid, start_offset, state.current_byte_offset)
            continue
        }

        // Dot operators: ..., .., .
        if current_character == '.' {
            if state.current_byte_offset + 2 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '.' &&
               state.source_text[state.current_byte_offset + 2] == '.' {
                state.current_byte_offset += 3
                lexer_emit_token(&state, .TripleDot, start_offset, state.current_byte_offset)
                continue
            }
            if state.current_byte_offset + 1 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '.' {
                state.current_byte_offset += 2
                lexer_emit_token(&state, .DoubleDot, start_offset, state.current_byte_offset)
                continue
            }
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Dot, start_offset, state.current_byte_offset)
            continue
        }

        // Question mark operators: ?., ??, ?
        if current_character == '?' {
            if state.current_byte_offset + 1 < len(state.source_text) {
                next_character: u8 = state.source_text[state.current_byte_offset + 1]
                if next_character == '.' {
                    state.current_byte_offset += 2
                    lexer_emit_token(&state, .QuestionDot, start_offset, state.current_byte_offset)
                    continue
                }
                if next_character == '?' {
                    state.current_byte_offset += 2
                    lexer_emit_token(&state, .DoubleQuestion, start_offset, state.current_byte_offset)
                    continue
                }
            }
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Question, start_offset, state.current_byte_offset)
            continue
        }

        // Exclamation operators: !=, !
        if current_character == '!' {
            if state.current_byte_offset + 1 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '=' {
                state.current_byte_offset += 2
                lexer_emit_token(&state, .NotEqual, start_offset, state.current_byte_offset)
                continue
            }
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Exclamation, start_offset, state.current_byte_offset)
            continue
        }

        // Assignment and equality: =::, =^, ==, =>, =
        if current_character == '=' {
            if state.current_byte_offset + 2 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == ':' &&
               state.source_text[state.current_byte_offset + 2] == ':' {
                state.current_byte_offset += 3
                lexer_emit_token(&state, .AssignVariant, start_offset, state.current_byte_offset)
                continue
            }
            if state.current_byte_offset + 1 < len(state.source_text) {
                next_character: u8 = state.source_text[state.current_byte_offset + 1]
                if next_character == '^' {
                    state.current_byte_offset += 2
                    lexer_emit_token(&state, .AssignGuard, start_offset, state.current_byte_offset)
                    continue
                }
                if next_character == '=' {
                    state.current_byte_offset += 2
                    lexer_emit_token(&state, .Equal, start_offset, state.current_byte_offset)
                    continue
                }
                if next_character == '>' {
                    state.current_byte_offset += 2
                    lexer_emit_token(&state, .FatArrow, start_offset, state.current_byte_offset)
                    continue
                }
            }
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Assign, start_offset, state.current_byte_offset)
            continue
        }

        // Plus operators: +=^, +=, +
        if current_character == '+' {
            if state.current_byte_offset + 2 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '=' &&
               state.source_text[state.current_byte_offset + 2] == '^' {
                state.current_byte_offset += 3
                lexer_emit_token(&state, .PlusAssignGuard, start_offset, state.current_byte_offset)
                continue
            }
            if state.current_byte_offset + 1 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '=' {
                state.current_byte_offset += 2
                lexer_emit_token(&state, .PlusAssign, start_offset, state.current_byte_offset)
                continue
            }
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Plus, start_offset, state.current_byte_offset)
            continue
        }

        // Minus operators: -=^, -=, ->, -
        if current_character == '-' {
            if state.current_byte_offset + 2 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '=' &&
               state.source_text[state.current_byte_offset + 2] == '^' {
                state.current_byte_offset += 3
                lexer_emit_token(&state, .MinusAssignGuard, start_offset, state.current_byte_offset)
                continue
            }
            if state.current_byte_offset + 1 < len(state.source_text) {
                next_character: u8 = state.source_text[state.current_byte_offset + 1]
                if next_character == '=' {
                    state.current_byte_offset += 2
                    lexer_emit_token(&state, .MinusAssign, start_offset, state.current_byte_offset)
                    continue
                }
                if next_character == '>' {
                    state.current_byte_offset += 2
                    lexer_emit_token(&state, .ThinArrow, start_offset, state.current_byte_offset)
                    continue
                }
            }
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Minus, start_offset, state.current_byte_offset)
            continue
        }

        // Star operators: *=^, *=, *
        if current_character == '*' {
            if state.current_byte_offset + 2 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '=' &&
               state.source_text[state.current_byte_offset + 2] == '^' {
                state.current_byte_offset += 3
                lexer_emit_token(&state, .StarAssignGuard, start_offset, state.current_byte_offset)
                continue
            }
            if state.current_byte_offset + 1 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '=' {
                state.current_byte_offset += 2
                lexer_emit_token(&state, .StarAssign, start_offset, state.current_byte_offset)
                continue
            }
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Star, start_offset, state.current_byte_offset)
            continue
        }

        // Slash operators: /=^, /=, /
        if current_character == '/' {
            if state.current_byte_offset + 2 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '=' &&
               state.source_text[state.current_byte_offset + 2] == '^' {
                state.current_byte_offset += 3
                lexer_emit_token(&state, .SlashAssignGuard, start_offset, state.current_byte_offset)
                continue
            }
            if state.current_byte_offset + 1 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '=' {
                state.current_byte_offset += 2
                lexer_emit_token(&state, .SlashAssign, start_offset, state.current_byte_offset)
                continue
            }
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Slash, start_offset, state.current_byte_offset)
            continue
        }

        // Percent operators: %=^, %=, %
        if current_character == '%' {
            if state.current_byte_offset + 2 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '=' &&
               state.source_text[state.current_byte_offset + 2] == '^' {
                state.current_byte_offset += 3
                lexer_emit_token(&state, .PercentAssignGuard, start_offset, state.current_byte_offset)
                continue
            }
            if state.current_byte_offset + 1 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '=' {
                state.current_byte_offset += 2
                lexer_emit_token(&state, .PercentAssign, start_offset, state.current_byte_offset)
                continue
            }
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Percent, start_offset, state.current_byte_offset)
            continue
        }

        // Less operators: <=, <
        if current_character == '<' {
            if state.current_byte_offset + 1 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '=' {
                state.current_byte_offset += 2
                lexer_emit_token(&state, .LessEqual, start_offset, state.current_byte_offset)
                continue
            }
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Less, start_offset, state.current_byte_offset)
            continue
        }

        // Greater operators: >=, > (Note: >> produces two consecutive Greater tokens)
        if current_character == '>' {
            if state.current_byte_offset + 1 < len(state.source_text) &&
               state.source_text[state.current_byte_offset + 1] == '=' {
                state.current_byte_offset += 2
                lexer_emit_token(&state, .GreaterEqual, start_offset, state.current_byte_offset)
                continue
            }
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Greater, start_offset, state.current_byte_offset)
            continue
        }

        // Validate UTF-8 sequences for non-ASCII bytes
        sequence_length, is_valid_utf8 := utf8_validate_sequence(state.source_text, state.current_byte_offset)
        if !is_valid_utf8 {
            lexer_record_diagnostic(
                &state,
                .MalformedUtf8Sequence,
                .Error,
                start_offset,
                1,
                "Malformed UTF-8 byte sequence encountered.",
            )
            state.current_byte_offset += 1
            lexer_emit_token(&state, .Invalid, start_offset, state.current_byte_offset)
            continue
        }

        // Unrecognized character
        state.current_byte_offset += sequence_length
        lexer_record_diagnostic(
            &state,
            .UnexpectedCharacter,
            .Error,
            start_offset,
            sequence_length,
            "Unexpected character in source stream.",
        )
        lexer_emit_token(&state, .Invalid, start_offset, state.current_byte_offset)
    }

    // Process any unclosed delimiters remaining on the stack
    for unclosed_index in 0 ..< len(state.delimiter_stack) {
        unclosed_entry: DelimiterStackEntry = state.delimiter_stack[unclosed_index]
        lexer_record_diagnostic(
            &state,
            .UnclosedDelimiter,
            .Error,
            int(state.tokens[unclosed_entry.token_index].span.byte_offset),
            int(state.tokens[unclosed_entry.token_index].span.byte_length),
            "Unclosed delimiter reaches end of file.",
        )
    }

    // Emit EndOfFile token
    eof_offset: int = len(state.source_text)
    lexer_emit_token(&state, .EndOfFile, eof_offset, eof_offset)

    return LexedSourceFile{
        source_text        = state.source_text,
        tokens             = state.tokens,
        top_level_spans    = state.top_level_spans,
        line_start_offsets = state.line_start_offsets,
        diagnostics        = state.diagnostics,
    }
}

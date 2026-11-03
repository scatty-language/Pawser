package tests

import "core:testing"
import pawser "../src"

// Verifies that all compound operators, assignment variants, and compound keywords are correctly recognized.
@(test)
operator_test_all_compound_operators :: proc(test_context: ^testing.T) {
    source_code: string = "=^ +=^ -=^ *=^ /=^ %=^ =:: := :: .. ... ?. ?? $: -> => as? as! try? try! must!"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)

    expected_kinds := []pawser.TokenKind{
        .AssignGuard,
        .PlusAssignGuard,
        .MinusAssignGuard,
        .StarAssignGuard,
        .SlashAssignGuard,
        .PercentAssignGuard,
        .AssignVariant,
        .ColonAssign,
        .DoubleColon,
        .DoubleDot,
        .TripleDot,
        .QuestionDot,
        .DoubleQuestion,
        .DollarColon,
        .ThinArrow,
        .FatArrow,
        .KeywordAsQuestion,
        .KeywordAsExclamation,
        .KeywordTryQuestion,
        .KeywordTryExclamation,
        .KeywordMustExclamation,
    }

    testing.expect_value(test_context, len(lexed_file.tokens), len(expected_kinds) + 1) // tokens + EOF

    for expected_index in 0 ..< len(expected_kinds) {
        token: pawser.Token = lexed_file.tokens[expected_index]
        testing.expect_value(test_context, token.kind, expected_kinds[expected_index])
    }
}

// Verifies that nested generic closings like >> produce two separate Greater tokens instead of a single shift token.
@(test)
operator_test_generic_greater_than_separation :: proc(test_context: ^testing.T) {
    source_code: string = "Option<InlineArray<Int>>"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)

    // Option < InlineArray < Int > > EOF
    testing.expect_value(test_context, len(lexed_file.tokens), 8)

    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.PublicIdentifier) // Option
    testing.expect_value(test_context, lexed_file.tokens[1].kind, pawser.TokenKind.Less)             // <
    testing.expect_value(test_context, lexed_file.tokens[2].kind, pawser.TokenKind.PublicIdentifier) // InlineArray
    testing.expect_value(test_context, lexed_file.tokens[3].kind, pawser.TokenKind.Less)             // <
    testing.expect_value(test_context, lexed_file.tokens[4].kind, pawser.TokenKind.PrimitiveInteger) // Int
    testing.expect_value(test_context, lexed_file.tokens[5].kind, pawser.TokenKind.Greater)          // > (first)
    testing.expect_value(test_context, lexed_file.tokens[6].kind, pawser.TokenKind.Greater)          // > (second)
    testing.expect_value(test_context, lexed_file.tokens[7].kind, pawser.TokenKind.EndOfFile)
}

// Verifies that delimiter pairing and top-level spans function correctly across a realistic multi-declaration file.
@(test)
span_test_delimiter_pairing_and_top_level_declarations :: proc(test_context: ^testing.T) {
    source_code: string = `use System::Collections;

Point {
    X: Int;
    Y: Int;
}

~Printable {
    Print(): none;
}

^Positive = Int must @ > 0;

Point with {
    Distance(): Float {
        return 0.0;
    }
}
`
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)

    // Verify top-level declaration spans count: exactly 5 declarations
    // 1: use directive
    // 2: Point struct
    // 3: ~Printable interface
    // 4: ^Positive type guard
    // 5: Point with extension block
    testing.expect_value(test_context, len(lexed_file.top_level_spans), 5)

    // Verify first span is "use System::Collections;"
    span_first: pawser.TopLevelTokenSpan = lexed_file.top_level_spans[0]
    testing.expect_value(test_context, lexed_file.tokens[span_first.first_token_index].kind, pawser.TokenKind.KeywordUse)
    testing.expect_value(test_context, lexed_file.tokens[span_first.last_token_index].kind, pawser.TokenKind.Semicolon)

    // Verify delimiter pairing on braces and parentheses
    for token_index in 0 ..< len(lexed_file.tokens) {
        token: pawser.Token = lexed_file.tokens[token_index]
        #partial switch token.kind {
        case .LeftBrace, .LeftParenthesis, .LeftBracket:
            testing.expect(
                test_context,
                token.matching_delimiter_index != pawser.NO_MATCHING_DELIMITER,
                "Opening delimiter must have matching index",
            )
            partner: pawser.Token = lexed_file.tokens[token.matching_delimiter_index]
            testing.expect_value(test_context, partner.matching_delimiter_index, u32(token_index))
        }
    }
}

// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

package lexer

// Sentinel index indicating that a `Token` does not have a paired delimiter.
NO_MATCHING_DELIMITER :: max(u32)

// Flags describing contextual properties and literal metadata of a `Token`.
TokenFlag :: enum u8 {
    PrecededByWhitespace,
    PrecededByNewline,
    HasEscapeSequences,
    IntegerSuffixUnsigned,
    IntegerSuffixLong,
    IntegerSuffixUnsignedLong,
    FloatSuffixSingle,
    FloatSuffixDouble,
}

// Bit set of `TokenFlag` values attached to each `Token`.
TokenFlags :: bit_set[TokenFlag; u8]

// Byte range within a source text buffer.
TextSpan :: struct {
    byte_offset: u32,
    byte_length: u32,
}

// One-based line and column coordinates for human-readable diagnostics and language server reporting.
LineColumn :: struct {
    line:   u32,
    column: u32,
}

// Discriminator representing the syntactic category of a `Token`.
TokenKind :: enum u16 {
    // Special & Structural Tokens
    Invalid,
    EndOfFile,
    Underscore,

    // Identifiers
    PublicIdentifier,
    InternalIdentifier,
    PrivateIdentifier,
    LocalIdentifier,
    EscapedIdentifier,
    MalformedIdentifier,

    // Literals
    IntegerLiteral,
    FloatLiteral,
    CharacterLiteral,
    RuneLiteral,
    StringLiteral,
    RawStringLiteral,
    InterpolatedStringStart,
    InterpolationStart,
    InterpolationEnd,
    InterpolatedStringMiddle,
    InterpolatedStringEnd,
    BooleanLiteralTrue,
    BooleanLiteralFalse,
    KeywordNone,

    // Primitive Type Keywords
    PrimitiveInteger,
    PrimitiveUnsignedInteger,
    PrimitiveLong,
    PrimitiveUnsignedLong,
    PrimitiveSize,
    PrimitiveUnsignedSize,
    PrimitiveByte,
    PrimitiveFloat,
    PrimitiveDouble,
    PrimitiveBoolean,
    PrimitiveCharacter,
    PrimitiveRune,
    PrimitiveString,
    PrimitiveRuneString,

    // Reserved Keywords
    KeywordConcurrent,
    KeywordSpawn,
    KeywordRollback,
    KeywordThrows,
    KeywordUnsafe,
    KeywordMust,
    KeywordMustExclamation,
    KeywordMay,
    KeywordThen,
    KeywordWhere,
    KeywordIn,
    KeywordBy,
    KeywordOut,
    KeywordBreak,
    KeywordContinue,
    KeywordMatch,
    KeywordFall,
    KeywordTry,
    KeywordTryQuestion,
    KeywordTryExclamation,
    KeywordCatch,
    KeywordThrow,
    KeywordUndo,
    KeywordReturn,
    KeywordUse,
    KeywordWith,
    KeywordReference,
    KeywordWeak,
    KeywordStructureOfArrays,
    KeywordEmbed,
    KeywordStatic,
    KeywordAtomicStatic,
    KeywordGlobalStatic,
    KeywordEquality,
    KeywordMath,
    KeywordTag,
    KeywordBitwidth,
    KeywordZeroed,
    KeywordNoInitialization,
    KeywordStrict,
    KeywordFunction,
    KeywordAs,
    KeywordAsQuestion,
    KeywordAsExclamation,
    KeywordUncheckedAs,
    KeywordIs,
    KeywordAnd,
    KeywordOr,
    KeywordNot,
    KeywordBitwiseAnd,
    KeywordBitwiseOr,
    KeywordBitwiseXor,
    KeywordBitwiseNot,
    KeywordBitwiseShiftLeft,
    KeywordBitwiseShiftRight,

    // Delimiters & Punctuation
    LeftParenthesis,
    RightParenthesis,
    LeftBrace,
    RightBrace,
    LeftBracket,
    RightBracket,
    Comma,
    Semicolon,
    Colon,
    DoubleColon,
    ColonAssign,
    DollarColon,
    At,
    Caret,
    Tilde,
    Dot,
    DoubleDot,
    TripleDot,
    QuestionDot,
    Question,
    DoubleQuestion,
    Exclamation,
    ThinArrow,
    FatArrow,

    // Assignment Operators
    Assign,
    PlusAssign,
    MinusAssign,
    StarAssign,
    SlashAssign,
    PercentAssign,
    AssignGuard,
    PlusAssignGuard,
    MinusAssignGuard,
    StarAssignGuard,
    SlashAssignGuard,
    PercentAssignGuard,
    AssignVariant,

    // Relational & Arithmetic Operators
    Plus,
    Minus,
    Star,
    Slash,
    Percent,
    Equal,
    NotEqual,
    Less,
    LessEqual,
    Greater,
    GreaterEqual,
}

// Single lexical unit produced by the `Lexer`.
Token :: struct {
    kind:                     TokenKind,
    flags:                    TokenFlags,
    span:                     TextSpan,
    matching_delimiter_index: u32,
    identifier_hash:          u64,
}

// Inclusive token index range of a top-level declaration or directive at depth zero.
TopLevelTokenSpan :: struct {
    first_token_index: u32,
    last_token_index:  u32,
}

// Extracts the raw string slice corresponding to the `span` of a `Token` from source text.
token_extract_lexeme :: proc(token: Token, source_text: string) -> string {
    start_offset: int = int(token.span.byte_offset)
    end_offset: int = start_offset + int(token.span.byte_length)

    if start_offset < 0 || end_offset > len(source_text) || start_offset > end_offset {
        return ""
    }

    return source_text[start_offset:end_offset]
}

// Extracts the clean identifier name from a `Token`, stripping enclosing backticks for escaped keywords.
token_extract_clean_identifier :: proc(token: Token, source_text: string) -> string {
    lexeme: string = token_extract_lexeme(token, source_text)

    if token.kind == .EscapedIdentifier {
        if len(lexeme) >= 2 && lexeme[0] == '`' && lexeme[len(lexeme) - 1] == '`' {
            return lexeme[1:len(lexeme) - 1]
        }
    }

    return lexeme
}

// Determines whether a `Token` corresponds to a language keyword, primitive type, or boolean/none literal.
token_is_keyword :: proc(token: Token) -> bool {
    #partial switch token.kind {
    case .KeywordNone,
         .BooleanLiteralTrue,
         .BooleanLiteralFalse,
         .PrimitiveInteger ..= .PrimitiveRuneString,
         .KeywordConcurrent ..= .KeywordBitwiseShiftRight:
        return true
    case:
        return false
    }
}

// Determines whether a `Token` belongs to any recognized identifier category.
token_is_identifier :: proc(token: Token) -> bool {
    #partial switch token.kind {
    case .PublicIdentifier,
         .InternalIdentifier,
         .PrivateIdentifier,
         .LocalIdentifier,
         .EscapedIdentifier:
        return true
    case:
        return false
    }
}

// Determines whether a `Token` is any assignment operator.
token_is_assignment_operator :: proc(token: Token) -> bool {
    #partial switch token.kind {
    case .Assign ..= .AssignVariant:
        return true
    case:
        return false
    }
}

// Determines whether a `Token` is an contextual reducer identifier used in out statements.
token_is_out_reducer :: proc(token: Token, source_text: string) -> bool {
    if token.kind != .LocalIdentifier {
        return false
    }

    lexeme: string = token_extract_lexeme(token, source_text)

    switch lexeme {
    case "count", "sum", "min", "max", "all", "any", "first", "last":
        return true
    case:
        return false
    }
}

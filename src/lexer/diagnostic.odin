package lexer

// Severity classification of a lexical or source file diagnostic.
DiagnosticSeverity :: enum u8 {
    Error,
    Warning,
}

// Machine-readable error codes representing lexical and source file validation failures.
LexerErrorCode :: enum u16 {
    InvalidFileExtension,
    EmptyFileBaseName,
    InvalidFileSuffixOrder,
    DuplicateFileSuffixCategory,
    UnrecognizedFileSuffix,
    ByteOrderMarkForbidden,
    MalformedUtf8Sequence,
    UnexpectedCharacter,
    InvalidIdentifierFormat,
    UnterminatedEscapedIdentifier,
    InvalidEscapedIdentifier,
    InvalidNumberPrefix,
    MalformedNumberLiteral,
    InvalidBinaryDigit,
    InvalidNumberSuffix,
    InvalidEscapeSequence,
    MalformedUtf8EscapeSequence,
    SurrogateUnicodeEscape,
    OutOfRangeUnicodeEscape,
    EmptyCharacterLiteral,
    MultiCharacterLiteral,
    UnterminatedCharacterLiteral,
    UnterminatedStringLiteral,
    EmptyStringInterpolation,
    UnterminatedRawStringLiteral,
    RawStringInsufficientIndentation,
    UnterminatedBlockComment,
    MismatchedClosingDelimiter,
    UnclosedDelimiter,
}

// Structured diagnostic record containing location and explanation for an issue.
LexerDiagnostic :: struct {
    code:     LexerErrorCode,
    severity: DiagnosticSeverity,
    span:     TextSpan,
    message:  string,
}

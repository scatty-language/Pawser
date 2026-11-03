package lexer

// Computes a 64-bit FNV-1a hash value for the provided string slice.
hash_compute_fnv1a64 :: proc(text: string) -> u64 {
    FNV_OFFSET_BASIS: u64 : 14695981039346656037
    FNV_PRIME: u64        : 1099511628211

    hash_value: u64 = FNV_OFFSET_BASIS
    for character_index in 0 ..< len(text) {
        hash_value = hash_value ~ u64(text[character_index])
        hash_value = hash_value * FNV_PRIME
    }

    return hash_value
}

// Determines whether a string identifier matches a reserved keyword in the language.
keyword_is_reserved_keyword :: proc(identifier_name: string) -> bool {
    switch identifier_name {
    case "concurrent", "spawn", "rollback", "throws", "unsafe",
         "must", "may", "then", "where", "in", "by", "out",
         "break", "continue", "match", "fall", "try", "catch",
         "throw", "undo", "return", "use", "with", "ref", "weak",
         "soa", "embed", "static", "astatic", "gstatic", "equality",
         "math", "tag", "bitwidth", "zeroed", "noinit", "strict",
         "none", "fn", "as", "unas", "is", "and", "or", "not",
         "band", "bor", "bxor", "bnot", "bsl", "bsr":
        return true
    case:
        return false
    }
}

// Resolves a reserved keyword, primitive type, or boolean/none literal from text.
keyword_lookup_by_name :: proc(identifier_name: string) -> (TokenKind, bool) {
    switch identifier_name {
    // Primitive types
    case "Int":
        return .PrimitiveInteger, true
    case "Uint":
        return .PrimitiveUnsignedInteger, true
    case "Long":
        return .PrimitiveLong, true
    case "Ulong":
        return .PrimitiveUnsignedLong, true
    case "Size":
        return .PrimitiveSize, true
    case "Usize":
        return .PrimitiveUnsignedSize, true
    case "Byte":
        return .PrimitiveByte, true
    case "Float":
        return .PrimitiveFloat, true
    case "Double":
        return .PrimitiveDouble, true
    case "Bool":
        return .PrimitiveBoolean, true
    case "Char":
        return .PrimitiveCharacter, true
    case "Rune":
        return .PrimitiveRune, true
    case "String":
        return .PrimitiveString, true
    case "RuneString":
        return .PrimitiveRuneString, true

    // Literals
    case "true":
        return .BooleanLiteralTrue, true
    case "false":
        return .BooleanLiteralFalse, true
    case "none":
        return .KeywordNone, true

    // Reserved keywords
    case "concurrent":
        return .KeywordConcurrent, true
    case "spawn":
        return .KeywordSpawn, true
    case "rollback":
        return .KeywordRollback, true
    case "throws":
        return .KeywordThrows, true
    case "unsafe":
        return .KeywordUnsafe, true
    case "must":
        return .KeywordMust, true
    case "may":
        return .KeywordMay, true
    case "then":
        return .KeywordThen, true
    case "where":
        return .KeywordWhere, true
    case "in":
        return .KeywordIn, true
    case "by":
        return .KeywordBy, true
    case "out":
        return .KeywordOut, true
    case "break":
        return .KeywordBreak, true
    case "continue":
        return .KeywordContinue, true
    case "match":
        return .KeywordMatch, true
    case "fall":
        return .KeywordFall, true
    case "try":
        return .KeywordTry, true
    case "catch":
        return .KeywordCatch, true
    case "throw":
        return .KeywordThrow, true
    case "undo":
        return .KeywordUndo, true
    case "return":
        return .KeywordReturn, true
    case "use":
        return .KeywordUse, true
    case "with":
        return .KeywordWith, true
    case "ref":
        return .KeywordReference, true
    case "weak":
        return .KeywordWeak, true
    case "soa":
        return .KeywordStructureOfArrays, true
    case "embed":
        return .KeywordEmbed, true
    case "static":
        return .KeywordStatic, true
    case "astatic":
        return .KeywordAtomicStatic, true
    case "gstatic":
        return .KeywordGlobalStatic, true
    case "equality":
        return .KeywordEquality, true
    case "math":
        return .KeywordMath, true
    case "tag":
        return .KeywordTag, true
    case "bitwidth":
        return .KeywordBitwidth, true
    case "zeroed":
        return .KeywordZeroed, true
    case "noinit":
        return .KeywordNoInitialization, true
    case "strict":
        return .KeywordStrict, true
    case "fn":
        return .KeywordFunction, true
    case "as":
        return .KeywordAs, true
    case "unas":
        return .KeywordUncheckedAs, true
    case "is":
        return .KeywordIs, true
    case "and":
        return .KeywordAnd, true
    case "or":
        return .KeywordOr, true
    case "not":
        return .KeywordNot, true
    case "band":
        return .KeywordBitwiseAnd, true
    case "bor":
        return .KeywordBitwiseOr, true
    case "bxor":
        return .KeywordBitwiseXor, true
    case "bnot":
        return .KeywordBitwiseNot, true
    case "bsl":
        return .KeywordBitwiseShiftLeft, true
    case "bsr":
        return .KeywordBitwiseShiftRight, true
    case:
        return .Invalid, false
    }
}

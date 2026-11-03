package lexer

import "base:runtime"
import "core:strings"

// Extracted metadata and conditional compilation configuration of a source file path.
SourceFileMetadata :: struct {
    base_name:        string,
    custom_flags:     [dynamic]string,
    build_mode:       string,
    operating_system: string,
    architecture:     string,
    is_valid:         bool,
    diagnostics:      [dynamic]LexerDiagnostic,
}

// Releases dynamic memory resources allocated by `source_file_validate_path`.
source_file_metadata_destroy :: proc(metadata: ^SourceFileMetadata) {
    delete(metadata.custom_flags)
    delete(metadata.diagnostics)
}

// Determines whether an identifier string conforms to public, internal, private, or local identifier format rules.
source_file_is_valid_identifier_name :: proc(identifier_name: string) -> bool {
    identifier_length: int = len(identifier_name)
    if identifier_length == 0 {
        return false
    }

    // Verify all characters are ASCII alphanumeric or underscore
    underscore_count: int = 0
    for character_index in 0 ..< identifier_length {
        current_character: u8 = identifier_name[character_index]
        is_alphanumeric_or_underscore: bool = (current_character >= 'A' && current_character <= 'Z') ||
                                              (current_character >= 'a' && current_character <= 'z') ||
                                              (current_character >= '0' && current_character <= '9') ||
                                              (current_character == '_')
        if !is_alphanumeric_or_underscore {
            return false
        }
        if current_character == '_' {
            underscore_count += 1
        }
    }

    first_character: u8 = identifier_name[0]

    // PublicIdentifier: starts with uppercase letter and contains no underscores
    if first_character >= 'A' && first_character <= 'Z' {
        if underscore_count == 0 {
            return true
        }

        // InternalIdentifier: starts with uppercase letter and ends with a single underscore
        if underscore_count == 1 && identifier_name[identifier_length - 1] == '_' {
            return true
        }

        return false
    }

    // PrivateIdentifier: starts with underscore followed by a lowercase letter and contains no other underscores
    if first_character == '_' {
        if identifier_length >= 2 &&
           identifier_name[1] >= 'a' &&
           identifier_name[1] <= 'z' &&
           underscore_count == 1 {
            return true
        }

        return false
    }

    // LocalIdentifier: starts with lowercase letter and contains no underscores
    if first_character >= 'a' && first_character <= 'z' {
        if underscore_count == 0 {
            return true
        }

        return false
    }

    return false
}

// Validates a file path against language extension and canonical conditional suffix ordering rules.
source_file_validate_path :: proc(
    file_path: string,
    allowed_custom_flags: []string = {},
    allocator := context.allocator,
) -> SourceFileMetadata {
    metadata := SourceFileMetadata{
        custom_flags = make([dynamic]string, allocator),
        diagnostics  = make([dynamic]LexerDiagnostic, allocator),
        is_valid     = true,
    }

    // Extract filename from the path
    last_slash_index: int = -1
    for character_index in 0 ..< len(file_path) {
        current_character: u8 = file_path[character_index]
        if current_character == '/' || current_character == '\\' {
            last_slash_index = character_index
        }
    }

    file_name: string = file_path
    if last_slash_index >= 0 && last_slash_index + 1 < len(file_path) {
        file_name = file_path[last_slash_index + 1:len(file_path)]
    }

    CAT_EXTENSION :: ".cat"
    if !strings.has_suffix(file_name, CAT_EXTENSION) {
        metadata.is_valid = false
        append(&metadata.diagnostics, LexerDiagnostic{
            code     = .InvalidFileExtension,
            severity = .Error,
            span     = TextSpan{byte_offset = 0, byte_length = u32(len(file_path))},
            message  = "Source files must have a '.cat' file extension.",
        })

        return metadata
    }

    // Strip .cat extension
    without_extension: string = file_name[0:len(file_name) - len(CAT_EXTENSION)]

    // Split filename by dots
    dot_count: int = 0
    for character_index in 0 ..< len(without_extension) {
        if without_extension[character_index] == '.' {
            dot_count += 1
        }
    }

    segments := make([dynamic]string, allocator)
    defer delete(segments)

    current_segment_start: int = 0
    for character_index in 0 ..< len(without_extension) {
        if without_extension[character_index] == '.' {
            append(&segments, without_extension[current_segment_start:character_index])
            current_segment_start = character_index + 1
        }
    }
    append(&segments, without_extension[current_segment_start:len(without_extension)])

    if len(segments) == 0 || len(segments[0]) == 0 {
        metadata.is_valid = false
        append(&metadata.diagnostics, LexerDiagnostic{
            code     = .EmptyFileBaseName,
            severity = .Error,
            span     = TextSpan{byte_offset = 0, byte_length = u32(len(file_path))},
            message  = "Source file base name must not be empty.",
        })

        return metadata
    }

    metadata.base_name = segments[0]

    // Validate base name format against Scatty identifier rules
    if !source_file_is_valid_identifier_name(metadata.base_name) {
        metadata.is_valid = false
        append(&metadata.diagnostics, LexerDiagnostic{
            code     = .InvalidIdentifierFormat,
            severity = .Error,
            span     = TextSpan{byte_offset = 0, byte_length = u32(len(file_path))},
            message  = "Source file base name must follow valid identifier format rules.",
        })

        return metadata
    }

    CATEGORY_CUSTOM           :: 0
    CATEGORY_BUILD_MODE       :: 1
    CATEGORY_OPERATING_SYSTEM :: 2
    CATEGORY_ARCHITECTURE     :: 3

    highest_category_seen: int = CATEGORY_CUSTOM

    for segment_index in 1 ..< len(segments) {
        suffix: string = segments[segment_index]
        category: int = -1

        // Check if suffix matches allowed custom flags
        is_custom_flag: bool = false
        for allowed_flag in allowed_custom_flags {
            if suffix == allowed_flag {
                is_custom_flag = true
                break
            }
        }

        if is_custom_flag {
            category = CATEGORY_CUSTOM
        } else if suffix == "debug" || suffix == "release" {
            category = CATEGORY_BUILD_MODE
        } else if suffix == "windows" || suffix == "linux" || suffix == "macos" ||
                   suffix == "ios" || suffix == "android" || suffix == "freebsd" || suffix == "wasm" {
            category = CATEGORY_OPERATING_SYSTEM
        } else if suffix == "amd64" || suffix == "arm64" || suffix == "x86" ||
                   suffix == "arm" || suffix == "riscv64" || suffix == "wasm32" {
            category = CATEGORY_ARCHITECTURE
        } else {
            metadata.is_valid = false
            append(&metadata.diagnostics, LexerDiagnostic{
                code     = .UnrecognizedFileSuffix,
                severity = .Error,
                span     = TextSpan{byte_offset = 0, byte_length = u32(len(file_path))},
                message  = "Unrecognized conditional compilation suffix identifier.",
            })
            continue
        }

        if category < highest_category_seen {
            metadata.is_valid = false
            append(&metadata.diagnostics, LexerDiagnostic{
                code     = .InvalidFileSuffixOrder,
                severity = .Error,
                span     = TextSpan{byte_offset = 0, byte_length = u32(len(file_path))},
                message  = "File suffixes must follow canonical order: custom flags, build mode, operating system, architecture.",
            })
        } else if category == highest_category_seen && category > CATEGORY_CUSTOM {
            metadata.is_valid = false
            append(&metadata.diagnostics, LexerDiagnostic{
                code     = .DuplicateFileSuffixCategory,
                severity = .Error,
                span     = TextSpan{byte_offset = 0, byte_length = u32(len(file_path))},
                message  = "Multiple suffixes belonging to the same conditional category are forbidden.",
            })
        } else {
            highest_category_seen = category
            switch category {
            case CATEGORY_CUSTOM:
                append(&metadata.custom_flags, suffix)
            case CATEGORY_BUILD_MODE:
                metadata.build_mode = suffix
            case CATEGORY_OPERATING_SYSTEM:
                metadata.operating_system = suffix
            case CATEGORY_ARCHITECTURE:
                metadata.architecture = suffix
            }
        }
    }

    return metadata
}

// Converts a byte offset within a source file into one-based line and column coordinates via binary search.
lexed_source_file_compute_line_column :: proc(
    source_file: ^LexedSourceFile,
    byte_offset: u32,
) -> LineColumn {
    if len(source_file.line_start_offsets) == 0 {
        return LineColumn{line = 1, column = 1}
    }

    low_index: int = 0
    high_index: int = len(source_file.line_start_offsets) - 1
    found_line_index: int = 0

    for low_index <= high_index {
        middle_index: int = low_index + (high_index - low_index) / 2
        if source_file.line_start_offsets[middle_index] <= byte_offset {
            found_line_index = middle_index
            low_index = middle_index + 1
        } else {
            high_index = middle_index - 1
        }
    }

    line_start_offset: u32 = source_file.line_start_offsets[found_line_index]
    column_offset: u32 = 1
    if byte_offset >= line_start_offset {
        column_offset = byte_offset - line_start_offset + 1
    }

    return LineColumn{
        line   = u32(found_line_index + 1),
        column = column_offset,
    }
}

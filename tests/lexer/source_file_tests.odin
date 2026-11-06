// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

package tests

import "core:testing"
import "base:runtime"
import pawser "../../src"

// Verifies that canonical file paths with valid suffixes are recognized successfully.
@(test)
source_file_test_valid_file_names :: proc(test_context: ^testing.T) {
    allowed_flags := []string{"vulkan"}

    metadata_first: pawser.SourceFileMetadata = pawser.source_file_validate_path("Console.cat")
    defer pawser.source_file_metadata_destroy(&metadata_first)
    testing.expect(test_context, metadata_first.is_valid, "Console.cat should be valid")
    testing.expect_value(test_context, metadata_first.base_name, "Console")

    metadata_second: pawser.SourceFileMetadata = pawser.source_file_validate_path("Console.windows.cat")
    defer pawser.source_file_metadata_destroy(&metadata_second)
    testing.expect(test_context, metadata_second.is_valid, "Console.windows.cat should be valid")
    testing.expect_value(test_context, metadata_second.operating_system, "windows")

    metadata_third: pawser.SourceFileMetadata = pawser.source_file_validate_path("Console.windows.arm64.cat")
    defer pawser.source_file_metadata_destroy(&metadata_third)
    testing.expect(test_context, metadata_third.is_valid, "Console.windows.arm64.cat should be valid")
    testing.expect_value(test_context, metadata_third.operating_system, "windows")
    testing.expect_value(test_context, metadata_third.architecture, "arm64")

    metadata_fourth: pawser.SourceFileMetadata = pawser.source_file_validate_path("Console.debug.windows.arm64.cat")
    defer pawser.source_file_metadata_destroy(&metadata_fourth)
    testing.expect(test_context, metadata_fourth.is_valid, "Console.debug.windows.arm64.cat should be valid")
    testing.expect_value(test_context, metadata_fourth.build_mode, "debug")
    testing.expect_value(test_context, metadata_fourth.operating_system, "windows")
    testing.expect_value(test_context, metadata_fourth.architecture, "arm64")

    metadata_fifth: pawser.SourceFileMetadata = pawser.source_file_validate_path("Renderer.vulkan.release.windows.amd64.cat", allowed_flags)
    defer pawser.source_file_metadata_destroy(&metadata_fifth)
    testing.expect(test_context, metadata_fifth.is_valid, "Renderer.vulkan.release.windows.amd64.cat should be valid")
    testing.expect_value(test_context, metadata_fifth.base_name, "Renderer")
    testing.expect_value(test_context, len(metadata_fifth.custom_flags), 1)
    testing.expect_value(test_context, metadata_fifth.custom_flags[0], "vulkan")
    testing.expect_value(test_context, metadata_fifth.build_mode, "release")
    testing.expect_value(test_context, metadata_fifth.operating_system, "windows")
    testing.expect_value(test_context, metadata_fifth.architecture, "amd64")
}

// Verifies that invalid file extensions, improper category ordering, duplicate categories, and unknown suffixes are rejected.
@(test)
source_file_test_invalid_file_names :: proc(test_context: ^testing.T) {
    allowed_flags := []string{"vulkan"}

    // Invalid extension
    metadata_extension: pawser.SourceFileMetadata = pawser.source_file_validate_path("Console.txt")
    defer pawser.source_file_metadata_destroy(&metadata_extension)
    testing.expect(test_context, !metadata_extension.is_valid, "Console.txt must be invalid")
    testing.expect_value(test_context, metadata_extension.diagnostics[0].code, pawser.LexerErrorCode.InvalidFileExtension)

    // Invalid order: OS before mode
    metadata_mode_order: pawser.SourceFileMetadata = pawser.source_file_validate_path("Console.windows.debug.cat")
    defer pawser.source_file_metadata_destroy(&metadata_mode_order)
    testing.expect(test_context, !metadata_mode_order.is_valid, "Console.windows.debug.cat must be invalid")
    testing.expect_value(test_context, metadata_mode_order.diagnostics[0].code, pawser.LexerErrorCode.InvalidFileSuffixOrder)

    // Invalid order: architecture before OS
    metadata_arch_order: pawser.SourceFileMetadata = pawser.source_file_validate_path("Console.arm64.windows.cat")
    defer pawser.source_file_metadata_destroy(&metadata_arch_order)
    testing.expect(test_context, !metadata_arch_order.is_valid, "Console.arm64.windows.cat must be invalid")
    testing.expect_value(test_context, metadata_arch_order.diagnostics[0].code, pawser.LexerErrorCode.InvalidFileSuffixOrder)

    // Invalid order: custom flag after OS
    metadata_custom_order: pawser.SourceFileMetadata = pawser.source_file_validate_path("Renderer.windows.vulkan.cat", allowed_flags)
    defer pawser.source_file_metadata_destroy(&metadata_custom_order)
    testing.expect(test_context, !metadata_custom_order.is_valid, "Renderer.windows.vulkan.cat must be invalid")
    testing.expect_value(test_context, metadata_custom_order.diagnostics[0].code, pawser.LexerErrorCode.InvalidFileSuffixOrder)

    // Unrecognized suffix
    metadata_unknown: pawser.SourceFileMetadata = pawser.source_file_validate_path("Console.unknown.cat")
    defer pawser.source_file_metadata_destroy(&metadata_unknown)
    testing.expect(test_context, !metadata_unknown.is_valid, "Console.unknown.cat must be invalid")
    testing.expect_value(test_context, metadata_unknown.diagnostics[0].code, pawser.LexerErrorCode.UnrecognizedFileSuffix)

    // Duplicate category: multiple operating systems
    metadata_duplicate: pawser.SourceFileMetadata = pawser.source_file_validate_path("Console.windows.linux.cat")
    defer pawser.source_file_metadata_destroy(&metadata_duplicate)
    testing.expect(test_context, !metadata_duplicate.is_valid, "Console.windows.linux.cat must be invalid")
    testing.expect_value(test_context, metadata_duplicate.diagnostics[0].code, pawser.LexerErrorCode.DuplicateFileSuffixCategory)
}

// Verifies that line and column coordinates are accurately computed from byte offsets via binary search.
@(test)
source_file_test_line_column_calculation :: proc(test_context: ^testing.T) {
    source_code: string = "LineOne\nLineTwo\r\nLineThree"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    position_first: pawser.LineColumn = pawser.lexed_source_file_compute_line_column(&lexed_file, 0)
    testing.expect_value(test_context, position_first.line, 1)
    testing.expect_value(test_context, position_first.column, 1)

    // Offset 8 corresponds to 'L' in "LineTwo"
    position_second: pawser.LineColumn = pawser.lexed_source_file_compute_line_column(&lexed_file, 8)
    testing.expect_value(test_context, position_second.line, 2)
    testing.expect_value(test_context, position_second.column, 1)

    // Offset 17 corresponds to 'L' in "LineThree"
    position_third: pawser.LineColumn = pawser.lexed_source_file_compute_line_column(&lexed_file, 17)
    testing.expect_value(test_context, position_third.line, 3)
    testing.expect_value(test_context, position_third.column, 1)
}

// Rejects any allocation attempts on the temporary allocator to verify allocator isolation.
@(private = "file")
forbid_temp_allocator_proc :: proc(
    allocator_data: rawptr,
    mode: runtime.Allocator_Mode,
    size: int,
    alignment: int,
    old_memory: rawptr,
    old_size: int,
    location := #caller_location,
) -> ([]byte, runtime.Allocator_Error) {
    return nil, .Out_Of_Memory
}

// Verifies that source_file_validate_path allocates exclusively through the provided allocator without touching context.temp_allocator.
@(test)
source_file_test_validate_path_allocator_isolation :: proc(test_context: ^testing.T) {
    previous_temp_allocator: runtime.Allocator = context.temp_allocator
    context.temp_allocator = runtime.Allocator{
        procedure = forbid_temp_allocator_proc,
        data      = nil,
    }
    defer context.temp_allocator = previous_temp_allocator

    allowed_flags := []string{"vulkan"}
    metadata: pawser.SourceFileMetadata = pawser.source_file_validate_path(
        "Renderer.vulkan.release.windows.amd64.cat",
        allowed_flags,
        context.allocator,
    )
    defer pawser.source_file_metadata_destroy(&metadata)

    testing.expect(test_context, metadata.is_valid, "Expected path validation to succeed without using context.temp_allocator")
    testing.expect_value(test_context, metadata.base_name, "Renderer")
}

// Verifies that file base names violating identifier formatting rules are rejected.
@(test)
source_file_test_malformed_identifier_base_names :: proc(test_context: ^testing.T) {
    invalid_base_names := []string{
        "_Data.cat",
        "Data__.cat",
        "user_age.cat",
        "_.cat",
        "_123.cat",
    }

    for invalid_path in invalid_base_names {
        metadata: pawser.SourceFileMetadata = pawser.source_file_validate_path(invalid_path)
        defer pawser.source_file_metadata_destroy(&metadata)

        testing.expect(test_context, !metadata.is_valid, "Expected file path with malformed identifier base name to be invalid")
        testing.expect(test_context, len(metadata.diagnostics) >= 1, "Expected diagnostic for malformed file base name")
    }
}

// Verifies that every built-in conditional suffix and multiple custom flags are accepted in canonical order.
@(test)
source_file_test_all_built_in_suffixes_and_multiple_custom_flags :: proc(test_context: ^testing.T) {
    built_in_paths := []string{
        "Console.debug.cat",
        "Console.release.cat",
        "Console.windows.cat",
        "Console.linux.cat",
        "Console.macos.cat",
        "Console.ios.cat",
        "Console.android.cat",
        "Console.freebsd.cat",
        "Console.wasm.cat",
        "Console.amd64.cat",
        "Console.arm64.cat",
        "Console.x86.cat",
        "Console.arm.cat",
        "Console.riscv64.cat",
        "Console.wasm32.cat",
    }

    for file_path in built_in_paths {
        metadata: pawser.SourceFileMetadata = pawser.source_file_validate_path(file_path)
        defer pawser.source_file_metadata_destroy(&metadata)

        testing.expect(test_context, metadata.is_valid, "Expected built-in conditional suffix to be accepted")
        testing.expect_value(test_context, len(metadata.diagnostics), 0)
    }

    allowed_flags := []string{"vulkan", "opengl"}
    metadata: pawser.SourceFileMetadata = pawser.source_file_validate_path(
        "Renderer.vulkan.opengl.release.linux.riscv64.cat",
        allowed_flags,
    )
    defer pawser.source_file_metadata_destroy(&metadata)

    testing.expect(test_context, metadata.is_valid, "Expected multiple custom flags in canonical order")
    testing.expect_value(test_context, len(metadata.custom_flags), 2)
    testing.expect_value(test_context, metadata.custom_flags[0], "vulkan")
    testing.expect_value(test_context, metadata.custom_flags[1], "opengl")
}

// Verifies that an empty base name and a case-mismatched extension are rejected.
@(test)
source_file_test_empty_base_name_and_extension_case :: proc(test_context: ^testing.T) {
    metadata_empty: pawser.SourceFileMetadata = pawser.source_file_validate_path(".cat")
    defer pawser.source_file_metadata_destroy(&metadata_empty)

    testing.expect(test_context, !metadata_empty.is_valid, "Expected empty base name to be rejected")
    testing.expect_value(test_context, metadata_empty.diagnostics[0].code, pawser.LexerErrorCode.EmptyFileBaseName)

    metadata_extension: pawser.SourceFileMetadata = pawser.source_file_validate_path("Console.CAT")
    defer pawser.source_file_metadata_destroy(&metadata_extension)

    testing.expect(test_context, !metadata_extension.is_valid, "Expected extension matching to be case-sensitive")
    testing.expect_value(test_context, metadata_extension.diagnostics[0].code, pawser.LexerErrorCode.InvalidFileExtension)
}

// Verifies that spaces, tabs, LF, CRLF, and standalone CR separate tokens and update source coordinates.
@(test)
source_file_test_whitespace_and_line_terminators :: proc(test_context: ^testing.T) {
    source_code: string = "first\tsecond third\rfourth\nfifth\r\nsixth"
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source(source_code)
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_file.tokens), 7)
    testing.expect_value(test_context, len(lexed_file.line_start_offsets), 4)

    for token_index in 1 ..< 6 {
        testing.expect(
            test_context,
            pawser.TokenFlag.PrecededByWhitespace in lexed_file.tokens[token_index].flags,
            "Expected whitespace flag after a separator",
        )
    }
    for token_index in 3 ..< 6 {
        testing.expect(
            test_context,
            pawser.TokenFlag.PrecededByNewline in lexed_file.tokens[token_index].flags,
            "Expected newline flag after a line terminator",
        )
        position: pawser.LineColumn = pawser.lexed_source_file_compute_line_column(
            &lexed_file,
            lexed_file.tokens[token_index].span.byte_offset,
        )
        testing.expect_value(test_context, position.line, u32(token_index - 1))
        testing.expect_value(test_context, position.column, 1)
    }
}

// Verifies that an empty source file produces only an end-of-file token without diagnostics.
@(test)
source_file_test_empty_source :: proc(test_context: ^testing.T) {
    lexed_file: pawser.LexedSourceFile = pawser.lexer_tokenize_source("")
    defer pawser.lexed_source_file_destroy(&lexed_file)

    testing.expect_value(test_context, len(lexed_file.diagnostics), 0)
    testing.expect_value(test_context, len(lexed_file.tokens), 1)
    testing.expect_value(test_context, lexed_file.tokens[0].kind, pawser.TokenKind.EndOfFile)
    testing.expect_value(test_context, len(lexed_file.line_start_offsets), 1)
}

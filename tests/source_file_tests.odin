package tests

import "core:testing"
import pawser "../src"

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

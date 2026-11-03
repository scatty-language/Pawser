package pawser

import "./lexer"

// Spans

TextSpan :: lexer.TextSpan
LineColumn :: lexer.LineColumn
TopLevelTokenSpan :: lexer.TopLevelTokenSpan

// Diagnostic

DiagnosticSeverity :: lexer.DiagnosticSeverity
LexerErrorCode :: lexer.LexerErrorCode
LexerDiagnostic :: lexer.LexerDiagnostic

// Meta

SourceFileMetadata :: lexer.SourceFileMetadata

source_file_validate_path :: lexer.source_file_validate_path
source_file_metadata_destroy :: lexer.source_file_metadata_destroy

// Token

Token :: lexer.Token
TokenKind :: lexer.TokenKind
TokenFlags :: lexer.TokenFlags
TokenFlag :: lexer.TokenFlag

token_extract_lexeme :: lexer.token_extract_lexeme
token_extract_clean_identifier :: lexer.token_extract_clean_identifier
token_is_keyword :: lexer.token_is_keyword
token_is_identifier :: lexer.token_is_identifier
token_is_assignment_operator :: lexer.token_is_assignment_operator
token_is_out_reducer :: lexer.token_is_out_reducer

// Lexer

NO_MATCHING_DELIMITER :: lexer.NO_MATCHING_DELIMITER

LexerConfiguration :: lexer.LexerConfiguration
LexedSourceFile :: lexer.LexedSourceFile

lexed_source_file_destroy :: lexer.lexed_source_file_destroy
lexed_source_file_compute_line_column :: lexer.lexed_source_file_compute_line_column
lexer_tokenize_source :: lexer.lexer_tokenize_source

// Utils

hash_compute_fnv1a64 :: lexer.hash_compute_fnv1a64

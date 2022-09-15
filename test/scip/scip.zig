//! Translated/derived from https://github.com/sourcegraph/scip/blob/main/scip.proto;
//! See license at https://github.com/sourcegraph/scip/blob/main/LICENSE
//!
//! An index contains one or more pieces of information about a given piece of
//! source code or software artifact. Complementary information can be merged
//! together from multiple sources to provide a unified code intelligence
//! experience.
//!
//! Programs producing a file of this format is an "indexer" and may operate
//! somewhere on the spectrum between precision, such as indexes produced by
//! compiler-backed indexers, and heurstics, such as indexes produced by local
//! syntax-directed analysis for scope rules.

const std = @import("std");

/// Index represents a complete SCIP index for a workspace this is rooted at a
/// single directory. An Index message payload can have a large memory footprint
/// and it's therefore recommended to emit and consume an Index payload one field
/// value at a time. To permit streaming consumption of an Index payload, the
/// `metadata` field must appear at the start of the stream and must only appear
/// once in the stream. Other field values may appear in any order.
pub const Index = struct {
    pub const tags = .{
        .{ "metadata", 1 },
        .{ "documents", 2 },
        .{ "external_symbols", 3 },
    };

    /// Metadata about this index.
    metadata: Metadata,
    /// Documents that belong to this index.
    documents: std.ArrayListUnmanaged(Document),
    /// (optional) Symbols that are referenced from this index but are defined in
    /// an external package (a separate `Index` message). Leave this field empty
    /// if you assume the external package will get indexed separately. If the
    /// external package won't get indexed for some reason then you can use this
    /// field to provide hover documentation for those external symbols.
    external_symbols: std.ArrayListUnmanaged(SymbolInformation),
};

pub const Metadata = struct {
    pub const tags = .{
        .{ "version", 1 },
        .{ "tool_info", 2 },
        .{ "project_root", 3 },
        .{ "text_document_encoding", 4 },
    };

    /// Which version of this protocol was used to generate this index?
    version: ProtocolVersion,
    /// Information about the tool that produced this index.
    tool_info: ToolInfo,
    /// URI-encoded absolute path to the root directory of this index. All
    /// documents in this index must appear in a subdirectory of this root
    /// directory.
    project_root: []const u8,
    /// Text encoding of the source files on disk that are referenced from
    /// `Document.relative_path`.
    text_document_encoding: TextEncoding,
};

pub const ProtocolVersion = enum(u64) {
    unspecified_protocol_version = 0,
};

pub const TextEncoding = enum(u64) {
    unspecified_text_encoding = 0,
    utf8 = 1,
    utf16 = 2,
};

pub const ToolInfo = struct {
    pub const tags = .{
        .{ "name", 1 },
        .{ "version", 2 },
        .{ "arguments", 3 },
    };

    /// Name of the indexer that produced this index.
    name: []const u8,
    /// Version of the indexer that produced this index.
    version: []const u8,
    /// Command-line arguments that were used to invoke this indexer.
    arguments: std.ArrayListUnmanaged([]const u8),
};

/// Document defines the metadata about a source file on disk.
pub const Document = struct {
    pub const tags = .{
        .{ "language", 4 },
        .{ "relative_path", 1 },
        .{ "occurrences", 2 },
        .{ "symbols", 3 },
    };

    /// The string ID for the programming language this file is written in.
    /// The `Language` enum contains the names of most common programming languages.
    /// This field is typed as a string to permit any programming langauge, including
    /// ones that are not specified by the `Language` enum.
    language: []const u8,
    /// (Required) Unique path to the text document.
    ///
    /// 1. The path must be relative to the directory supplied in the associated
    ///    `Metadata.project_root`.
    /// 2. The path must not begin with a leading '/'.
    /// 3. The path must point to a regular file, not a symbolic link.
    /// 4. The path must use '/' as the separator, including on Windows.
    /// 5. The path must be canonical; it cannot include empty components ('//'),
    ///    or '.' or '..'.
    relative_path: []const u8,
    /// Occurrences that appear in this file.
    occurrences: std.ArrayListUnmanaged(Occurrence),
    /// Symbols that are defined within this document.
    symbols: std.ArrayListUnmanaged(SymbolInformation),
};

/// Symbol is similar to a URI, it identifies a class, method, or a local
/// variable. `SymbolInformation` contains rich metadata about symbols such as
/// the docstring.
///
/// Symbol has a standardized string representation, which can be used
/// interchangeably with `Symbol`. The syntax for Symbol is the following:
/// ```
///   # (<x>)+ stands for one or more repetitions of <x>
///   <symbol>               ::= <scheme> ' ' <package> ' ' (<descriptor>)+ | 'local ' <local-id>
///   <package>              ::= <manager> ' ' <package-name> ' ' <version>
///   <scheme>               ::= any UTF-8, escape spaces with double space.
///   <manager>              ::= same as above, use the placeholder '.' to indicate an empty value
///   <package-name>         ::= same as above
///   <version>              ::= same as above
///   <descriptor>           ::= <namespace> | <type> | <term> | <method> | <type-parameter> | <parameter> | <meta>
///   <namespace>            ::= <name> '/'
///   <type>                 ::= <name> '#'
///   <term>                 ::= <name> '.'
///   <meta>                 ::= <name> ':'
///   <method>               ::= <name> '(' <method-disambiguator> ').'
///   <type-parameter>       ::= '[' <name> ']'
///   <parameter>            ::= '(' <name> ')'
///   <name>                 ::= <identifier>
///   <method-disambiguator> ::= <simple-identifier>
///   <identifier>           ::= <simple-identifier> | <escaped-identifier>
///   <simple-identifier>    ::= (<identifier-character>)+
///   <identifier-character> ::= '_' | '+' | '-' | '$' | ASCII letter or digit
///   <escaped-identifier>   ::= '`' (<escaped-character>)+ '`'
///   <escaped-characters>   ::= any UTF-8 character, escape backticks with double backtick.
/// ```
///
/// The list of descriptors for a symbol should together form a fully
/// qualified name for the symbol. That is, it should serve as a unique
/// identifier across the package. Typically, it will include one descriptor
/// for every node in the AST (along the ancestry path) between the root of
/// the file and the node corresponding to the symbol.
pub const Symbol = struct {
    pub const tags = .{
        .{ "scheme", 1 },
        .{ "package", 2 },
        .{ "descriptors", 3 },
    };

    scheme: []const u8,
    package: Package,
    descriptors: std.ArrayListUnmanaged(Descriptor),
};

/// Unit of packaging and distribution.
///
/// NOTE: This corresponds to a module in Go and JVM languages.
pub const Package = struct {
    pub const tags = .{
        .{ "manager", 1 },
        .{ "name", 2 },
        .{ "version", 3 },
    };

    manager: []const u8,
    name: []const u8,
    version: []const u8,
};

pub const Descriptor = struct {
    pub const Suffix = enum(u64) {
        unspecified_suffix = 0,
        /// Unit of code abstraction and/or namespacing.
        ///
        /// NOTE: This corresponds to a package in Go and JVM languages.
        namespace = 1,
        type = 2,
        term = 3,
        method = 4,
        type_parameter = 5,
        parameter = 6,
        macro = 9,
        // Can be used for any purpose.
        meta = 7,
        local = 8,
    };

    pub const tags = .{
        .{ "name", 1 },
        .{ "disambiguator", 2 },
        .{ "suffix", 3 },
    };

    name: []const u8,
    disambiguator: []const u8,
    suffix: Suffix,
};

/// SymbolInformation defines metadata about a symbol, such as the symbol's
/// docstring or what package it's defined it.
pub const SymbolInformation = struct {
    pub const tags = .{
        .{ "symbol", 1 },
        .{ "documentation", 3 },
        .{ "relationships", 4 },
    };

    /// Identifier of this symbol, which can be referenced from `Occurence.symbol`.
    /// The string must be formatted according to the grammar in `Symbol`.
    symbol: []const u8,
    /// (optional, but strongly recommended) The markdown-formatted documentation
    /// for this symbol. This field is repeated to allow different kinds of
    /// documentation.  For example, it's nice to include both the signature of a
    /// method (parameters and return type) along with the accompanying docstring.
    documentation: std.ArrayListUnmanaged([]const u8),
    /// (optional) Relationships to other symbols (e.g., implements, type definition).
    relationships: std.ArrayListUnmanaged(Relationship),
};

pub const Relationship = struct {
    pub const tags = .{
        .{ "symbol", 1 },
        .{ "is_reference", 2 },
        .{ "is_implementation", 3 },
        .{ "is_type_definition", 4 },
    };

    symbol: []const u8,
    /// When resolving "Find references", this field documents what other symbols
    /// should be included together with this symbol. For example, consider the
    /// following TypeScript code that defines two symbols `Animal#sound()` and
    /// `Dog#sound()`:
    /// ```ts
    /// interface Animal {
    ///           ^^^^^^ definition Animal#
    ///   sound(): string
    ///   ^^^^^ definition Animal#sound()
    /// }
    /// class Dog implements Animal {
    ///       ^^^ definition Dog#, implementation_symbols = Animal#
    ///   public sound(): string { return "woof" }
    ///          ^^^^^ definition Dog#sound(), references_symbols = Animal#sound(), implementation_symbols = Animal#sound()
    /// }
    /// const animal: Animal = new Dog()
    ///               ^^^^^^ reference Animal#
    /// console.log(animal.sound())
    ///                    ^^^^^ reference Animal#sound()
    /// ```
    /// Doing "Find references" on the symbol `Animal#sound()` should return
    /// references to the `Dog#sound()` method as well. Vice-versa, doing "Find
    /// references" on the `Dog#sound()` method should include references to the
    /// `Animal#sound()` method as well.
    is_reference: bool,
    /// Similar to `references_symbols` but for "Go to implementation".
    /// It's common for the `implementation_symbols` and `references_symbols` fields
    /// have the same values but that's not always the case.
    /// In the TypeScript example above, observe that `implementation_symbols` has
    /// the value `"Animal#"` for the "Dog#" symbol while `references_symbols` is
    /// empty. When requesting "Find references" on the "Animal#" symbol we don't
    /// want to include references to "Dog#" even if "Go to implementation" on the
    /// "Animal#" symbol should navigate to the "Dog#" symbol.
    is_implementation: bool,
    /// Similar to `references_symbols` but for "Go to type definition".
    is_type_definition: bool,
};

/// SymbolRole declares what "role" a symbol has in an occurrence.  A role is
/// encoded as a bitset where each bit represents a different role. For example,
/// to determine if the `Import` role is set, test whether the second bit of the
/// enum value is defined. In pseudocode, this can be implemented with the
/// logic: `const isImportRole = (role.value & SymbolRole.Import.value) > 0`.
pub const SymbolRole = enum(u64) {
    /// This case is not meant to be used; it only exists to avoid an error
    /// from the Protobuf code generator.
    unspecified_symbol_role = 0,
    /// Is the symbol defined here? If not, then this is a symbol reference.
    definition = 0x1,
    /// Is the symbol imported here?
    import = 0x2,
    /// Is the symbol written here?
    write_access = 0x4,
    /// Is the symbol read here?
    read_access = 0x8,
    /// Is the symbol in generated code?
    generated = 0x10,
    /// Is the symbol in test code?
    @"test" = 0x20,
};

pub const SyntaxKind = enum(u64) {
    unspecified_syntax_kind = 0,

    /// Comment, including comment markers and text
    comment = 1,

    /// `;` `.` `,`
    punctuation_delimiter = 2,
    /// (), {}, [] when used syntactically
    punctuation_bracket = 3,

    /// `if`, `else`, `return`, `class`, etc.
    keyword = 4,

    /// `+`, `*`, etc.
    identifier_operator = 5,

    /// non-specific catch-all for any identifier not better described elsewhere
    identifier = 6,
    /// Identifiers builtin to the language: `min`, `print` in Python.
    identifier_builtin = 7,
    /// Identifiers representing `null`-like values: `None` in Python, `nil` in Go.
    identifier_null = 8,
    /// `xyz` in `const xyz = "hello"`
    identifier_constant = 9,
    /// `var X = "hello"` in Go
    identifier_mutable_global = 10,
    /// Parameter definition and references
    identifier_parameter = 11,
    /// Identifiers for variable definitions and references within a local scope
    identifier_local = 12,
    /// Identifiers that shadow other identifiers in an outer scope
    identifier_shadowed = 13,
    /// Identifier representing a unit of code abstraction and/or namespacing.
    ///
    /// NOTE: This corresponds to a package in Go and JVM languages,
    /// and a module in languages like Python and JavaScript.
    identifier_namespace = 14,

    /// Function references, including calls
    identifier_function = 15,
    /// Function definition only
    identifier_function_definition = 16,

    /// Macro references, including invocations
    identifier_macro = 17,
    /// Macro definition only
    identifier_macro_definition = 18,

    /// non-builtin types
    identifier_type = 19,
    /// builtin types only, such as `str` for Python or `int` in Go
    identifier_builtin_type = 20,

    /// Python decorators, c-like __attribute__
    identifier_attribute = 21,

    /// `\b`
    regex_escape = 22,
    /// `*`, `+`
    regex_repeated = 23,
    /// `.`
    regex_wildcard = 24,
    /// `(`, `)`, `[`, `]`
    regex_delimiter = 25,
    /// `|`, `-`
    regex_join = 26,

    /// Literal strings: "Hello, world!"
    string_literal = 27,
    /// non-regex escapes: "\t", "\n"
    string_literal_escape = 28,
    /// datetimes within strings, special words within a string, `{}` in format strings
    string_literal_special = 29,
    /// "key" in { "key": "value" }, useful for example in JSON
    string_literal_key = 30,
    /// 'c' or similar, in languages that differentiate strings and characters
    character_literal = 31,
    /// Literal numbers, both floats and integers
    numeric_literal = 32,
    /// `true`, `false`
    boolean_literal = 33,

    /// Used for XML-like tags
    tag = 34,
    /// Attribute name in XML-like tags
    tag_attribute = 35,
    /// Delimiters for XML-like tags
    tag_delimiter = 36,
};

/// Occurrence associates a source position with a symbol and/or highlighting
/// information.
///
/// If possible, indexers should try to bundle logically related information
/// across occurrences into a single occurrence to reduce payload sizes.
pub const Occurrence = struct {
    pub const tags = .{
        .{ "range", 1 },
        .{ "symbol", 2 },
        .{ "symbol_roles", 3 },
        .{ "override_documentation", 4 },
        .{ "syntax_kind", 5 },
        .{ "diagnostics", 6 },
    };

    /// Source position of this occurrence. Must be exactly three or four
    /// elements:
    ///
    /// - Four elements: `[startLine, startCharacter, endLine, endCharacter]`
    /// - Three elements: `[startLine, startCharacter, endCharacter]`. The end line
    ///   is inferred to have the same value as the start line.
    ///
    /// Line numbers and characters are always 0-based. Make sure to increment the
    /// line/character values before displaying them in an editor-like UI because
    /// editors conventionally use 1-based numbers.
    ///
    /// Historical note: the original draft of this schema had a `Range` message
    /// type with `start` and `end` fields of type `Position`, mirroring LSP.
    /// Benchmarks revealed that this encoding was inefficient and that we could
    /// reduce the total payload size of an index by 50% by using `repeated int32`
    /// instead.  The `repeated int32` encoding is admittedly more embarrassing to
    /// work with in some programming languages but we hope the performance
    /// improvements make up for it.
    range: std.ArrayListUnmanaged(i32),
    /// (optional) The symbol that appears at this position. See
    /// `SymbolInformation.symbol` for how to format symbols as strings.
    symbol: []const u8,
    /// (optional) Bitset containing `SymbolRole`s in this occurrence.
    /// See `SymbolRole`'s documentation for how to read and write this field.
    symbol_roles: u32,
    /// (optional) CommonMark-formatted documentation for this specific range. If
    /// empty, the `Symbol.documentation` field is used instead. One example
    /// where this field might be useful is when the symbol represents a generic
    /// function (with abstract type parameters such as `List<T>`) and at this
    /// occurrence we know the exact values (such as `List<String>`).
    ///
    /// This field can also be used for dynamically or gradually typed languages,
    /// which commonly allow for type-changing assignment.
    override_documentation: std.ArrayListUnmanaged([]const u8),
    /// (optional) What syntax highlighting class should be used for this range?
    syntax_kind: SyntaxKind,
    /// (optional) Diagnostics that have been reported for this specific range.
    diagnostics: std.ArrayListUnmanaged(Diagnostic),
};

/// Represents a diagnostic, such as a compiler error or warning, which should be
/// reported for a document.
pub const Diagnostic = struct {
    pub const tags = .{
        .{ "severity", 1 },
        .{ "code", 2 },
        .{ "message", 3 },
        .{ "source", 4 },
        .{ "tags", 5 },
    };

    /// Should this diagnostic be reported as an error, warning, info, or hint?
    severity: Severity,
    /// (optional) Code of this diagnostic, which might appear in the user interface.
    code: []const u8,
    /// Message of this diagnostic.
    message: []const u8,
    /// (optional) Human-readable string describing the source of this diagnostic, e.g.
    /// 'typescript' or 'super lint'.
    source: []const u8,
    tags: std.ArrayListUnmanaged(DiagnosticTag),
};

pub const Severity = enum(u64) {
    unspecified_severity = 0,
    @"error" = 1,
    warning = 2,
    information = 3,
    hint = 4,
};

pub const DiagnosticTag = enum(u64) {
    unspecified_diagnostic_tag = 0,
    unnecessary = 1,
    deprecated = 2,
};

/// Language standardises names of common programming languages that can be used
/// for the `Document.language` field. The primary purpose of this enum is to
/// prevent a situation where we have a single programming language ends up with
/// multiple string representations. For example, the C++ language uses the name
/// "CPlusPlus" in this enum and other names such as "cpp" are incompatible.
/// Feel free to send a pull-request to add missing programming languages.
pub const Language = enum(u64) {
    unspecified_language = 0,
    abap = 60,
    apl = 49,
    ada = 39,
    agda = 45,
    ascii_doc = 86,
    assembly = 58,
    awk = 66,
    bat = 68,
    bib_te_x = 81,
    c = 34,
    cobol = 59,
    cpp = 35,
    css = 26,
    c_sharp = 1,
    clojure = 8,
    coffeescript = 21,
    common_lisp = 9,
    coq = 47,
    dart = 3,
    delphi = 57,
    diff = 88,
    dockerfile = 80,
    dyalog = 50,
    elixir = 17,
    erlang = 18,
    f_sharp = 42,
    fish = 65,
    flow = 24,
    fortran = 56,
    git_commit = 91,
    git_config = 89,
    git_rebase = 92,
    go = 33,
    groovy = 7,
    html = 30,
    hack = 20,
    handlebars = 90,
    haskell = 44,
    idris = 46,
    ini = 72,
    j = 51,
    json = 75,
    java = 6,
    java_script = 22,
    java_script_react = 93,
    jsonnet = 76,
    julia = 55,
    kotlin = 4,
    la_te_x = 83,
    lean = 48,
    less = 27,
    lua = 12,
    makefile = 79,
    markdown = 84,
    matlab = 52,
    nix = 77,
    o_caml = 41,
    objective_c = 36,
    objective_cpp = 37,
    php = 19,
    plsql = 70,
    perl = 13,
    power_shell = 67,
    prolog = 71,
    python = 15,
    r = 54,
    racket = 11,
    raku = 14,
    razor = 62,
    re_st = 85,
    ruby = 16,
    rust = 40,
    sas = 61,
    scss = 29,
    sml = 43,
    sql = 69,
    sass = 28,
    scala = 5,
    scheme = 10,
    shell_script = 64, // Bash
    skylark = 78,
    swift = 2,
    toml = 73,
    te_x = 82,
    type_script = 23,
    type_script_react = 94,
    visual_basic = 63,
    vue = 25,
    wolfram = 53,
    xml = 31,
    xsl = 32,
    yaml = 74,
    zig = 38,
    // NextLanguage = 95;
    // Steps add a new language:
    // 1. Copy-paste the "NextLanguage = N" line above
    // 2. Increment "NextLanguage = N" to "NextLanguage = N+1"
    // 3. Replace "NextLanguage = N" with the name of the new language.
    // 4. Move the new language to the correct line above using alphabetical order
    // 5. (optional) Add a brief comment behind the language if the name is not self-explanatory
};

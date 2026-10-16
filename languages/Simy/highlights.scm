; Simy syntax highlighting
;
; Order matters: general rules first, more specific ones later, so that later
; (more specific) captures win for the same node.

; ─────────────────────────── default identifiers ─────────────────────────────
(identifier) @variable

; ─────────────────────────────── comments ────────────────────────────────────
(line_comment) @comment
(block_comment) @comment
((block_comment) @comment.doc
  (#match? @comment.doc "^/\\*\\*"))

; ─────────────────────────────── keywords ────────────────────────────────────
[
  "let"
  "mut"
  "const"
  "fn"
  "if"
  "else"
  "while"
  "for"
  "in"
  "return"
  "execute"
  "at"
  "component"
] @keyword

(execute_verb
  [
    "at"
    "as"
    "positioned"
  ] @keyword)

(component_method
  "tick" @keyword)

; ─────────────────────────────── literals ────────────────────────────────────
(number) @number
(boolean) @boolean
(coordinate) @number
(nbt) @string.special.symbol

(string) @string
(string_content) @string
(escape_sequence) @string.escape
(interpolation) @string.special
(variable_reference) @variable.special

; ─────────────────────────────── types ───────────────────────────────────────
(primitive_type) @type.builtin
(domain_type) @type.builtin
(generic_type
  name: (identifier) @type)
(type_annotation
  (type) @type)
(method_parameter
  type: (type) @type)

; ────────────────────────── minecraft atoms ──────────────────────────────────
(selector_marker) @constant.builtin
(selector_argument
  key: (identifier) @property)
(namespaced_identifier) @type
(block_literal
  name: (namespaced_identifier) @type)
(block_state
  key: (identifier) @property)

; ───────────────────────── functions & declarations ──────────────────────────
(function_definition
  name: (identifier) @function)
(component_definition
  name: (identifier) @constructor)
(call_expression
  function: (identifier) @function)
(member_expression
  property: (identifier) @property)
(parameter
  name: (identifier) @variable.parameter)
(method_parameter
  name: (identifier) @variable.parameter)
(command_statement
  name: (identifier) @function)
(named_argument
  name: (identifier) @property)
(const_declaration
  name: (_) @constant)
(let_declaration
  name: (wildcard) @variable.special)

; ─────────────────────────────── punctuation ─────────────────────────────────
[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

[
  ","
  ";"
] @punctuation.delimiter

[
  "="
  "+="
  "-="
  "*="
  "/="
  "%="
  "<"
  ">"
  "<="
  ">="
  "=="
  "!="
  "&&"
  "||"
  "!"
  "+"
  "-"
  "*"
  "/"
  "%"
  "."
  ":"
  "->"
  "="
] @operator

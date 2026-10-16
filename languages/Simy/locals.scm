; Scopes
(function_definition) @local.scope
(component_definition) @local.scope
(component_method) @local.scope
(block) @local.scope

; Definitions
(parameter
  name: (identifier) @local.definition)
(method_parameter
  name: (identifier) @local.definition)
(let_declaration
  name: (identifier) @local.definition)
(const_declaration
  name: (identifier) @local.definition)
(for_statement
  variable: (identifier) @local.definition)

; References
(identifier) @local.reference
(variable_reference
  name: (identifier) @local.reference)

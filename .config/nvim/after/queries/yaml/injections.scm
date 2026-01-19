; extends

; Inject bash for block scalars preceded by "# language=bash" comment
; Works with Atmos commands, and is portable across editors (JetBrains, etc.)
;
; Example:
;   steps:
;     # language=bash
;     - |
;       set -e
;       echo "hello"

(block_sequence
  (comment) @_lang
  .
  (block_sequence_item
    (block_node
      (block_scalar) @injection.content))
  (#match? @_lang "language=bash")
  (#set! injection.language "bash")
  (#offset! @injection.content 0 1 0 0))

; Also handle plain scalar (single-line) after comment
(block_sequence
  (comment) @_lang
  .
  (block_sequence_item
    (flow_node
      (plain_scalar
        (string_scalar) @injection.content)))
  (#match? @_lang "language=bash")
  (#set! injection.language "bash"))

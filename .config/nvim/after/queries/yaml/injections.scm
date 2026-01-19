; extends

; Key-based injection for "steps" (like built-in "run", "script")
(block_mapping_pair
  key: (flow_node) @_run
  (#any-of? @_run "steps")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (block_node
          (block_scalar) @injection.content
          (#set! injection.language "bash")
          (#offset! @injection.content 0 1 0 0))))))

; Comment-based injection: # language=bash before block scalar
(block_mapping_pair
  key: (flow_node)
  (comment) @_lang (#match? @_lang "language=bash")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (block_node
          (block_scalar) @injection.content
          (#set! injection.language "bash")
          (#offset! @injection.content 0 1 0 0))))))

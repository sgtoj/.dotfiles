; Replaces nvim-treesitter's yaml injections, whose bash-for-every-`script:` rule breaks Atmos script steps.

((comment) @injection.content
  (#set! injection.language "comment"))

; Github actions ("run") / Gitlab CI / Taskfile
(block_mapping_pair
  key: (flow_node) @_run
  (#any-of? @_run "run" "before_script" "after_script" "cmds" "cmd" "sh")
  value: (flow_node
    (plain_scalar
      (string_scalar) @injection.content)
    (#set! injection.language "bash")))

(block_mapping_pair
  key: (flow_node) @_run
  (#any-of? @_run "run" "before_script" "after_script" "cmds" "cmd" "sh")
  value: (block_node
    (block_scalar) @injection.content
    (#set! injection.language "bash")
    (#offset! @injection.content 0 1 0 0)))

(block_mapping_pair
  key: (flow_node) @_run
  (#any-of? @_run "run" "before_script" "after_script" "cmds" "sh")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (flow_node
          (plain_scalar
            (string_scalar) @injection.content))
        (#set! injection.language "bash")))))

(block_mapping_pair
  key: (flow_node) @_run
  (#any-of? @_run "before_script" "after_script" "cmds" "sh")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (block_node
          (block_scalar) @injection.content
          (#set! injection.language "bash")
          (#offset! @injection.content 0 1 0 0))))))

; Prometheus Alertmanager ("expr")
(block_mapping_pair
  key: (flow_node) @_expr
  (#eq? @_expr "expr")
  value: (flow_node
    (plain_scalar
      (string_scalar) @injection.content)
    (#set! injection.language "promql")))

(block_mapping_pair
  key: (flow_node) @_expr
  (#eq? @_expr "expr")
  value: (block_node
    (block_scalar) @injection.content
    (#set! injection.language "promql")
    (#offset! @injection.content 0 1 0 0)))

(block_mapping_pair
  key: (flow_node) @_expr
  (#eq? @_expr "expr")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (flow_node
          (plain_scalar
            (string_scalar) @injection.content))
        (#set! injection.language "promql")))))

(block_mapping_pair
  key: (flow_node) @_expr
  (#eq? @_expr "expr")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (block_node
          (block_scalar) @injection.content
          (#set! injection.language "promql")
          (#offset! @injection.content 0 1 0 0))))))

; Atmos script steps: `interpreter` names the language of `script`, before or after it.
(block_mapping
  (block_mapping_pair
    key: (flow_node) @_interpreter
    (#eq? @_interpreter "interpreter")
    value: (flow_node) @injection.language)
  (block_mapping_pair
    key: (flow_node) @_script
    (#eq? @_script "script")
    value: (block_node
      (block_scalar) @injection.content
      (#offset! @injection.content 0 1 0 0))))

(block_mapping
  (block_mapping_pair
    key: (flow_node) @_script
    (#eq? @_script "script")
    value: (block_node
      (block_scalar) @injection.content
      (#offset! @injection.content 0 1 0 0)))
  (block_mapping_pair
    key: (flow_node) @_interpreter
    (#eq? @_interpreter "interpreter")
    value: (flow_node) @injection.language))

; Atmos shell steps: string items under `steps` and `command` values.
(block_mapping_pair
  key: (flow_node) @_steps
  (#eq? @_steps "steps")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (flow_node
          (plain_scalar
            (string_scalar) @injection.content))
        (#set! injection.language "bash")))))

(block_mapping_pair
  key: (flow_node) @_steps
  (#eq? @_steps "steps")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (block_node
          (block_scalar) @injection.content
          (#set! injection.language "bash")
          (#offset! @injection.content 0 1 0 0))))))

(block_mapping_pair
  key: (flow_node) @_command
  (#eq? @_command "command")
  value: (block_node
    (block_scalar) @injection.content
    (#set! injection.language "bash")
    (#offset! @injection.content 0 1 0 0)))

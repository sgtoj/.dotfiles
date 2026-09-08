---
name: comment-hygiene
description: Review comments added or edited in the current work and remove or reduce them before submitting or requesting review for a PR. Use when asked to tighten, minimize, or review comments in a change set.
---

# Comment Hygiene

Review comments that were added or edited as part of the current work.

- Remove comments when the code clearly conveys the same information.
- Reduce remaining comments to the critical information future maintainers need.
- Remove comments unless they explain non-obvious intent, constraints,
  invariants, tradeoffs, or externally imposed behavior.
- Do not change unaffected comments or refactor code solely to eliminate a
  comment.
- Preserve required documentation such as public API docs, lint directives,
  legal notices, and generated-file markers unless the task explicitly permits
  changing them.

After the pass, report which comments were removed, reduced, or retained and why
when relevant.

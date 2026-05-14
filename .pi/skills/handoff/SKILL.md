---
name: handoff
description: Create a continuation thread with default thread parameters and a comprehensive handoff of the current task. Use when the user says "/handoff", asks to hand off the current work, continue in another thread, or wants a fresh thread with full context.
---

# Handoff

Create a new thread that can continue the current task without rereading the full conversation.

## Workflow
1. Infer the task to continue from the latest user request and the full thread so far.
2. Gather the minimum extra context needed for a good handoff:
   - relevant files, paths, commands, errors, diffs, decisions, constraints, and unresolved questions
   - current repo or worktree assumptions
   - any required workflow rules from the repo or active docs
3. If there is no clear task to hand off, ask one focused clarifying question instead of creating an empty thread.
4. Create a new thread with `new_thread`.
   - Use default thread parameters: omit `model`, `reasoningEffort`, `permissions`, `projectPath`, and `worktreePath` unless the user explicitly asks otherwise.
   - Put the full handoff in `input`.
5. Structure the handoff so the new thread can act immediately. Include:
   - objective
   - user intent and success criteria
   - work completed so far
   - relevant repository context and rules
   - files inspected or changed
   - commands run and important outputs
   - open questions, risks, and blockers
   - recommended next steps
6. Preserve uncertainty honestly. Distinguish facts from inferences.
7. After creating the thread, tell the user:
   - that the handoff thread was created
   - the new thread id
   - a one- or two-sentence summary of what was handed off

## Handoff prompt shape
Use a concise but complete structure like:

- Task
- Current status
- Key context
- Relevant files
- Commands and results
- Constraints and repo rules
- Open questions / risks
- Next recommended actions

Do not ask the user to restate context that already exists in the thread unless something critical is genuinely missing.

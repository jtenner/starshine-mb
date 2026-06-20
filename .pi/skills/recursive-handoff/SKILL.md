---
name: recursive-handoff
description: Progress a user-specified goal in bounded slices, then either stop when complete or create a continuation thread that keeps working toward the same goal. Use for long-running work where the current thread should do useful work now and recursively hand off remaining work automatically.
---

# Recursive Handoff

Progress a user-specified goal in bounded slices. After each slice, either stop because the goal is complete or create a new continuation thread that keeps working toward the same goal.

This skill extends the regular `handoff` skill with a completion gate and a recursion contract. It is for long-running work where the current thread should do useful work now, then hand off the remaining work automatically.

## Required input

A clear goal is required. The goal should define the desired end state, not just the next action.

Examples:
- "Recursive handoff until the optimize-level pass reaches parity."
- "Keep handing this off until the docs migration is complete."
- "Work recursively toward closing the validation blockers in `agent-todo.md`."

If the goal is missing or too vague to determine completion, ask one focused clarifying question before starting.

## Workflow

1. **Capture the goal and completion criteria.**
   - Restate the goal in operational terms.
   - Infer concrete completion criteria from the user request and repo rules.
   - If completion cannot be evaluated, ask a clarifying question.
2. **Plan one bounded slice.**
   - Pick the highest-leverage slice that can reasonably fit in the current thread.
   - Prefer a slice that leaves the repo better even if the full goal is not finished.
   - Follow all relevant project workflows, including TDD and validation rules when coding.
3. **Do the slice.**
   - Inspect files and docs needed for this slice.
   - Make changes only when appropriate.
   - Run or document targeted validation as far as available.
4. **Evaluate completion.**
   - Compare the current state against the goal and completion criteria.
   - If the goal is complete, do not create another thread. Summarize the completed work, validation, and remaining caveats if any.
   - If the goal is not complete, continue to step 5.
5. **Create the recursive continuation thread with `new_thread`.**
   - Use default thread parameters: omit `model`, `reasoningEffort`, `permissions`, `projectPath`, and `worktreePath` unless the user explicitly asked otherwise.
   - The new thread's `input` must tell the next agent to use this `recursive-handoff` skill again.
   - Include the original goal, completion criteria, what slice was just completed, current state, remaining work, files touched, commands/results, constraints, risks, and the recommended next slice.
6. **Report to the user.**
   - State whether the goal is complete or a continuation thread was created.
   - If a continuation was created, include the new thread id and a concise summary of the remaining goal.

## Recursive handoff prompt shape

When creating the next thread, use a structure like:

```md
Use the `recursive-handoff` skill.

Goal: <original user goal>

Completion criteria:
- <criterion 1>
- <criterion 2>

Current status:
- <what is now true>
- <what remains incomplete>

Slice just completed:
- <files changed / decisions made / tests or validation run>

Relevant context and rules:
- <repo/worktree constraints>
- <workflow rules, docs to read, skills to use>

Files inspected or changed:
- `<path>` — <why it matters>

Commands and results:
- `<command>` — <result, or why not run>

Open questions / risks / blockers:
- <uncertainties and blockers>

Next recommended slice:
1. <first action>
2. <second action>

After completing that slice, evaluate the completion criteria. If the goal is still incomplete, create another recursive handoff thread with this same structure. If complete, stop and report completion.
```

## Guardrails

- Do not recurse without doing a meaningful slice of work unless blocked.
- Do not create a continuation thread if the goal is already complete.
- Do not hide uncertainty. Mark inferred completion criteria and unresolved risks clearly.
- Do not ask the user to restate context that is already available unless it is required to determine the goal or completion criteria.
- Keep each slice bounded; avoid trying to solve an unbounded goal in one thread.
- Preserve the original goal exactly enough that later threads do not drift.
- If blocked by missing access, failing infrastructure, or ambiguous requirements, create a handoff only if the next thread can make progress; otherwise ask the user for the needed input.

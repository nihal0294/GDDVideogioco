# AGENTS.md

## Project Scope

This repository contains a Godot game project.

Work directly inside the existing project structure and preserve compatibility with the Godot version already used by the repository.

## Project Documentation

The repository documentation is stored in `/docs`.

- Treat relevant files in `/docs` as the primary source of truth for game design, systems, requirements, terminology, and intended behavior.
- Before implementing or substantially modifying a feature, search `/docs` for documentation related to that feature.
- Read only the relevant documentation needed for the current task; do not assume undocumented requirements.
- If documentation conflicts with the existing implementation, identify the conflict before making broad or destructive changes.
- If multiple documentation files appear to disagree, report the inconsistency instead of silently choosing one.
- Do not rewrite or reorganize documentation unless explicitly requested.
- When implementing a documented feature, preserve the terminology and concepts used by the documentation whenever practical.

## General Rules

- Inspect the relevant existing files before making changes.
- Reuse existing systems, conventions, scenes, resources, and architecture whenever possible.
- Do not invent project requirements that are not present in the repository or explicitly requested.
- Do not modify unrelated systems.
- Prefer small, focused, reversible changes over broad rewrites.
- Preserve existing behavior unless the requested task explicitly requires changing it.
- Do not add external plugins, packages, libraries, or dependencies unless explicitly requested.
- Do not edit generated/cache files or files inside `.godot/`.
- Do not delete or rename important project files unless the task clearly requires it.
- Never perform destructive Git operations unless explicitly requested.

## Godot

- Use APIs compatible with the Godot version used by this project.
- Prefer GDScript unless the existing project clearly uses another language.
- Prefer typed GDScript where practical.
- Respect Godot scene/node ownership and lifecycle conventions.
- Prefer reusable scenes, Resources, and composition over unnecessarily deep inheritance.
- Keep gameplay logic, data, and UI responsibilities separated when practical.
- Avoid hard-coded NodePaths when a safer exported reference, unique node, signal, group, or dependency can be used.
- Use signals for decoupled communication where appropriate.
- Avoid unnecessary per-frame work in `_process()` or `_physics_process()`.
- Do not manually edit imported/generated Godot metadata unless necessary.

## File Organization

Follow the repository's existing naming and folder conventions.

If no convention exists:

- Use `snake_case` for files, variables, functions, signals, and node names where appropriate.
- Use `PascalCase` for `class_name` declarations and custom classes.
- Keep scripts focused on a clear responsibility.
- Place reusable game data in Resources when appropriate.
- Keep assets, scenes, scripts, UI, and documentation organized rather than mixing unrelated files.

## Before Implementing a Task

For any non-trivial change:

1. Search `/docs` for documentation relevant to the requested feature.
2. Read the relevant documentation before deciding the implementation.
3. Inspect the relevant project files and current architecture.
4. Search for existing systems that already solve part of the problem.
5. Identify which files need to be created or modified.
6. Prefer extending the current architecture instead of replacing it.
7. If the requested change conflicts with the existing implementation or documentation, report the conflict before making a large or destructive change.

## Implementation

- Implement only what is required for the current task.
- Avoid speculative systems for possible future features unless explicitly requested.
- Keep public APIs and data formats stable when possible.
- Add comments only when they explain non-obvious decisions; do not comment obvious code.
- Avoid duplicate logic.
- Prefer clear, maintainable code over clever code.
- Validate user-facing input where appropriate.
- Handle missing references and invalid states safely when practical.

## Scenes and UI

When working with Godot scenes or UI:

- Preserve existing scene structure unless restructuring is necessary.
- Avoid unnecessary changes to unrelated `.tscn` files.
- Keep UI logic separate from persistent game data when practical.
- Prefer anchors, containers, and Godot layout systems over fragile hard-coded positioning.
- Keep reusable UI elements modular.

## Save Data and Persistent Data

When modifying persistent data:

- Do not silently break existing save formats.
- Keep runtime state separate from permanent character/game data where practical.
- Prefer explicit serialization structures.
- Mention any save-format migration required by a change.

## Testing and Validation

After implementing a change:

- Check modified GDScript for syntax/type errors.
- Check for broken scene/resource references.
- Run the most relevant available validation or tests.
- If the project can be run locally, verify that the affected scene or feature starts without errors when practical.
- Do not claim something was tested if it was not actually tested.

## Git

- Keep changes limited to the requested task.
- Do not commit automatically unless explicitly requested.
- Do not push, force-push, reset, rebase, clean, or rewrite history unless explicitly requested.
- Do not discard existing uncommitted user changes.
- Clearly identify files created, modified, renamed, or deleted.

## Response Format

After completing a task, provide a concise summary containing:

- What was implemented.
- Which files were changed.
- Any important architectural decisions.
- Any validation/testing performed.
- Any remaining issue that prevents the task from being fully complete.

If the user requests planning only, do not modify files.

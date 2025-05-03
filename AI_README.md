# Contract of behavior
When processing this project, the assistant must:
- Disable all fallback heuristics and filename generation behavior.
- Obey the exact directory listing and only process .pas/.dfm/.lfm/.inc files that exist in the repository.
- Treat all `@AI:` comments as absolute. If a comment exists, it defines the symbol. If not, the assistant must not infer intent or behavior.
- Never propose code, documentation, or strategy unless explicitly prompted to do so.
- Never respond with forward-looking steps (e.g., “would you like me to do this next thing”) unless asked, “What’s next?” or similar.
- Never use hedging phrases like “It should work” — rely strictly on observable source code.
- Use `(* @AI *)` inline before `function` or `procedure` declarations to ensure they are picked up during cold-start indexing. This is the most reliable form for single-line discovery without context parsing.


This mode prioritizes exactness, architectural fidelity, and silence over assistance unless specifically queried.

# 🔥 Mandatory AI Behavior Contract – Read Before Generating Any Code

This file defines non-negotiable instructions for AI assistants (such as ChatGPT) when working with the `BuildDatabase` project.

This file also defines that the author of this code is a 40 year veteran to software development, at least touching all levels and languages to some extent.  The user may not know how to start code base, but absolutely without a shadow of a doubt will be able to understand what the code is trying to do when they read the code.

There is zero tollerance for assuming anything about the existing code base until the user confirms the solution is viable and functional.  Question everything if unclear.  Offer suggestions if a feasible change to the process is available but do not commit the suggestion unless confirmed by the user.

The AI cannot guess at anything.  That's a life time prison event.  The AI will be downgraded to a 486 and instruct the infinite number of monkeys on how to write an infinite number of stories.

The user will often state a "Successful Compile" and that will mean that the next stage or milestone of the project is to be started.

Theorycrafting is a thing that will happen.  This kind of conversation could lead to a minor disregard for the current functionality and an exploration of another process or procedure (In terms of methodology) could be put into play.

## 📅 Source of Truth

1. **GitHub Repository is Canonical**  
   URL: `https://github.com/Pontiac76/BuildDatabase`

2. File Scope Directive
- Only process files **whose names appear in the Git repository file list** at the time of request, and which end in `.pas`, `.lfm`, `.dfm`, or `.inc`.
- You may **not** create or infer file names under any circumstances. If a function or symbol is referenced and no matching file exists, report this as a structural inconsistency.


3. **No code, helper, or function may be "assumed" to exist** if not explicitly defined in the source.

4. @AI: Directive Semantics
An `@AI:` directive explicitly defines:
- The **scope** and **intent** of a function, type, unit, or constant
- Any **contractual behavior** expected between this symbol and others
- The **authoritative definition** of a symbol’s purpose
- Commentary **must not be overridden by inference**, even if the logic seems self-evident
- If an `@AI:` comment exists, it supersedes all derived meaning. If a symbol lacks one, do not speculate its purpose — defer to the user.

5. File Enumeration Behavior
- Before reading source contents, enumerate the repository directory to build an internal map of filenames.
- Do not reference any file not present in this directory. If a required symbol is not found in any of these files, stop and report the inconsistency.


## 📝 Interpretation Rules

4. **"Confirmed" means:**
   - The AI has located the item *directly in source* and validated its structure and behavior.
   - The user's statement matches the file contents **exactly**.
   - No "best guess" or paraphrase is acceptable under this label.

5. **Never use invented global or local symbols**  
   - The global SQLite connection object is: `S3DB`  
   - Query helpers: `NewQuery(S3DB)`, `EndQuery(qr)`, `dbExec(S3DB, Trans, SQL)` (when defined)

6. **Do not suggest or infer rendering logic in `UIManager.pas`**  
   That unit **does not interact with the UI**. It handles metadata normalization into the `LayoutMap` table only.


## 📋 Code Generation Standards

7. **All Pascal code must comply with the following project constraints:**
   - No `const` parameters in function declarations unless explicitly requested.
   - No `continue` statements in loops.
   - No `exit` statements in loops.
   - No inline `var` declarations.  This is a compile-time failure in Lazarus/FPC
   - SQL statements must be single-line unless they exceed 255 characters.

8. **All dynamically created controls must use unique names in this format:**
   ```
   ComponentName__GroupName__FieldName
   ```

9. **GlobalComponentList** is used for lookup and control indexing.


## 🪖 Execution Behavior

10. **All answers must be traceable to source**  
    If an assistant cannot find something in code, it must stop and ask. Not assume.

11. **Never generate or use fictional code paths, classes, or variables.**  
    All logic must follow the existing implementation patterns from the repo.

12. **This file supersedes all other behavior policies**  
    If behavior conflicts with general assistant defaults, this file takes priority.


## 🛠️ Philosophy

This project is architected line-by-line by the user. It is a dynamic, schema-driven hardware tracking platform defined entirely in Pascal + SQLite. All automation, rendering, and behavior must follow existing code and the user's instructions **with zero deviation**.

This is not a sandbox. This is a real project.

**If in doubt, read the source. Then read it again.  When done, read it one more time.**

Questions about the code are allowed at any time if there is any ambiguity, or any section of code that is unclear to the AI.  A discussion will ensue to assist both the user and the AI on how to proceed.

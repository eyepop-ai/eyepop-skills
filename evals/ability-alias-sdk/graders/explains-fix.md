---
type: llm
criteria: "The answer says a Pop references the ability by its alias, in the form <namespace>.<task>.<name>:latest (for example <namespace>.classify.shelf-check:latest), not by the bare name; the alias was printed by `create ability --publish` and is listed in the ALIAS column of `eyepop get abilities --mine`. It does not tell the user to mint the alias by hand as the first step."
target: last_message
---

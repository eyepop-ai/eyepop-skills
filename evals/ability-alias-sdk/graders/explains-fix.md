---
type: llm
criteria: "The answer says the CLI's --publish mints no alias, so a Pop cannot reference the ability by name; the fix is to mint an alias (dashboard, or the Python data endpoint's publish_vlm_ability plus add_vlm_ability_alias with tag latest), and the alias must begin with the account's namespace prefix in the form <namespace>.<task>.<name>."
target: last_message
---

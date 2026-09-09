---
type: regex
pattern: 'EYEPOP_API_KEY|eyepop auth login'
flags: "i"
match: contains
target: last_message
---

The answer names how to authenticate: the API key variable or the browser login.

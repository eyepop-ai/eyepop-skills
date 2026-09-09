---
type: regex
pattern: 'workerEndpoint[\s\S]*eyepop\.person:latest[\s\S]*process\([\s\S]*disconnect'
match: contains
target: last_message
---

Uses workerEndpoint with the person ability in the pop, process() for the media, and disconnect() in cleanup.

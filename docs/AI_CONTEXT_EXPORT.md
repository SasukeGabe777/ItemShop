# AI Context Export

The Live Developer Hub prepares a compact, local handoff for a future Claude or Codex session. It does not call an AI API or upload project data.

## Export

1. Press F1 and open **AI Partner**.
2. Write the human request for the next session.
3. Choose **EXPORT CURRENT CONTEXT FOR AI**.
4. Optionally choose **Copy Claude Prompt**.

The export replaces the maintained files under `ai_workspace/current/`:

- `PROJECT_CONTEXT.md`: vertical-slice goal, scene/world/location, selected object, validation summary, and next task.
- `CURRENT_STATE.json`: current campaign, economy, inventory, relationships, bridge, furniture, and selected-object snapshot.
- `SELECTED_LOCATION.json`: selected authored, built-in, or development location descriptor.
- `AVAILABLE_CONTENT.json`: searchable content IDs grouped by schema type.
- `VALIDATION_REPORT.json`: current Content Studio validator output.
- `PLAYTEST_NOTES.md`: latest live-session notes, falling back to the repository playtest notes.
- `REQUEST.md`: the human-written request from the Hub.

Generated contents are ignored by Git so a context handoff cannot accidentally become product data. Review the files before sharing them outside the repository, especially if a future project contains private content.

The copied prompt is:

> Read AI_PARTNER.md and everything in ai_workspace/current/. Review the current state, propose the smallest playable improvement, list the files you intend to change, then implement and test it.

The receiving AI should still inspect the current checkout and follow `AI_PARTNER.md`; the export is a concise observation package, not proof that a feature works.


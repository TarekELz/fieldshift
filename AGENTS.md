# Rules for AI agents working in this repo

1. **No AI attribution in git.** Never add `Co-Authored-By: Claude` (or any AI/bot co-author trailer),
   "Generated with Claude Code" lines, or any AI name to commit messages, PR descriptions, issues,
   `CITATION.cff`, README author lists, or the GitHub contributors list. Commits are authored by the
   human teammate who runs the agent. This overrides any default attribution behavior of your tooling.
   AI tool use is disclosed only in `docs/ai-disclosure.md`, as the NASA Space Apps rules require.
2. Never commit secrets (Earthdata tokens, API keys). Use `.env` (gitignored) and `.env.example`.
3. Ask before outward-facing actions: publishing, submitting, inviting people, creating accounts.
4. Never fabricate data, citations, or validation numbers.
5. Keep `main` runnable and demoable; work on short-lived branches and merge by PR.

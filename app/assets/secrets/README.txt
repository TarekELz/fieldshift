Optional build-time keys for the language-model advice rewrite live in secrets.json here. That file is NOT committed (see .gitignore).
Create it with: .venv/Scripts/python scripts/write_app_secrets.py
Without it the app shows the blueprint advice text, which needs no key and no internet.

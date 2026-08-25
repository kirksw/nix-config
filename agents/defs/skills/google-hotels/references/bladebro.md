# Bladebro usage conventions

Prefer these patterns:

```bash
bladebro daemon
bladebro nav "https://example.com"
bladebro see extract auto --json
bladebro see content --json
bladebro see model --json
bladebro act click text="Visible label" --json
bladebro act collect max=30 timeout=30 --json
bladebro state tabs --json
bladebro vision --marks
```

Principles:

- Prefer accessible text/labels and Bladebro refs over CSS selectors.
- Act responses are delta-first; do not request a full model after every action unless necessary.
- Batch related interactions where practical.
- Use auto-extraction for repeated result cards/lists.
- Use `collect` for lazy/infinite feeds.
- Persistent refs may self-heal across re-renders/navigation; only re-observe when the semantic target is unclear.
- Never attempt to bypass CAPTCHA or other explicit bot challenges.

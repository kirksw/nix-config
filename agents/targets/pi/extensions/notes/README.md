# Notes Extension

`/note [text]` opens a small TUI for capturing a markdown braindump note.

On save, the extension asks a tiny Pi subprocess for OKF frontmatter metadata,
then writes the original note body unchanged. If the model is unavailable, it
falls back to deterministic metadata rather than dropping the note.

## Routing

- `personal` routes to `~/git/github.com/kirksw/lifeOS` and writes under `workspace/wiki/raw/inbox/`.
- `work` routes to `~/git/github.com/kirksw/lunar-notes` and writes under `raw/inbox/`.

The default route is inferred from the current working directory. Work paths
under `~/git/github.com/lunarway`, `~/git/github.com/kirksw/lunar-notes`, or
`~/projects/lunar` default to `work`; everything else defaults to `personal`.

Override paths with:

- `PI_NOTES_PERSONAL_REPO`
- `PI_NOTES_WORK_REPO`

Set `PI_NOTES_SKIP_MODEL=1` to skip metadata augmentation.

## Keys

- `Tab` toggles personal/work routing.
- `Ctrl-S` saves the note.
- `Enter` inserts a newline.
- `Esc` cancels.

Saved notes are written to `raw/inbox/YYYY/MM/<timestamp>-<slug>.md` with OKF
frontmatter and committed in the target repo. Co-located OS repos use
`workspace/wiki/raw/inbox/...`.

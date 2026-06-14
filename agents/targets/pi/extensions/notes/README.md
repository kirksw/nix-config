# Notes Extension

`/note [text]` opens a small TUI for capturing a markdown micronote.

## Routing

- `personal` routes to `~/git/github.com/kirksw/notes`
- `work` routes to `~/git/github.com/kirksw/lunar-notes`

The default route is inferred from the current working directory. Work paths
under `~/git/github.com/lunarway`, `~/git/github.com/kirksw/lunar-notes`, or
`~/projects/lunar` default to `work`; everything else defaults to `personal`.

Override paths with:

- `PI_NOTES_PERSONAL_REPO`
- `PI_NOTES_WORK_REPO`

## Keys

- `Tab` toggles personal/work routing.
- `Ctrl-S` saves the note.
- `Enter` inserts a newline.
- `Esc` cancels.

Saved notes are written to `raw/quicknote/YYYY/MM/<timestamp>-<slug>.md` with
frontmatter and committed in the target notes repository.

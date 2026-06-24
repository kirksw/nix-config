#!/usr/bin/env bash
set -euo pipefail

extract_image_path() {
	sed -n 's/^[[:space:]]*IMAGE_PATH=//p' "$1" | tail -n 1 | sed 's/^"//; s/"$//'
}

nearest_profile() {
	local dir="$(pwd -P)"
	while [[ "$dir" != "/" ]]; do
		if [[ -f "$dir/.nix-agents-profile" ]]; then
			cat "$dir/.nix-agents-profile"
			return
		fi
		dir="$(dirname "$dir")"
	done
}

assert_personal_profile() {
	local profile="${NIX_AGENTS_PROFILE:-${PI_PROFILE:-$(nearest_profile)}}"
	# ponytail: personal-only bridge; work profiles should use their OPENAI_API_KEY path.
	if [[ "$profile" == work* ]]; then
		echo "codex-imagegen is disabled for work profiles; use the OpenAI API image path there." >&2
		exit 3
	fi
}

if [[ "${1:-}" == "--self-test" ]]; then
	tmp="$(mktemp)"
	trap 'rm -f "$tmp"' EXIT
	printf 'done\nIMAGE_PATH=/tmp/generated.png\n' >"$tmp"
	[[ "$(extract_image_path "$tmp")" == "/tmp/generated.png" ]]
	echo "ok"
	exit 0
fi

assert_personal_profile

if [[ $# -eq 0 ]]; then
	prompt="$(cat)"
	out_dir="output/imagegen"
else
	prompt="$1"
	out_dir="${2:-output/imagegen}"
fi

if [[ -z "${prompt//[[:space:]]/}" ]]; then
	echo "usage: $0 'image prompt' [output-dir]" >&2
	echo "   or: printf 'image prompt' | $0" >&2
	exit 2
fi

repo="$(pwd -P)"
mkdir -p "$out_dir"
out_dir="$(cd "$out_dir" && pwd -P)"
last="$(mktemp)"
log="$(mktemp)"
trap 'rm -f "$last" "$log"' EXIT

instruction="Use the direct Codex image generation path via \$imagegen / image_gen.imagegen.

Prompt:
$prompt

Save/copy the final selected generated image into this directory:
$out_dir

Rules:
- Use Codex built-in image generation; do not use shell, Python, Perl, SVG, canvas, ImageMagick, sips, or placeholder drawing to create the image.
- Do not modify any project files except writing the final image into the requested directory.
- If Codex image generation does not produce a retrievable image artifact, end with exactly: IMAGE_PATH=ERROR
- Otherwise end with exactly one line in this format: IMAGE_PATH=/absolute/path/to/the/final/image.png"

if ! codex \
	--ask-for-approval never \
	--enable imagegenext \
	-c suppress_unstable_features_warning=true \
	exec \
	--ignore-user-config \
	--skip-git-repo-check \
	--sandbox workspace-write \
	-C "$repo" \
	-o "$last" \
	"$instruction" >"$log" 2>&1 </dev/null; then
	echo "codex-imagegen failed:" >&2
	cat "$log" >&2
	exit 1
fi

path="$(extract_image_path "$last")"
if [[ -z "$path" || "$path" == "ERROR" || ! -f "$path" ]]; then
	echo "Could not find generated image path. Codex final message:" >&2
	cat "$last" >&2
	echo "\nCodex log:" >&2
	cat "$log" >&2
	exit 1
fi

printf '%s\n' "$path"

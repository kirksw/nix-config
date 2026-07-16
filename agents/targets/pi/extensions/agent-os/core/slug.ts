export function slugify(text: string, fallback = "thread"): string {
	const slug = text
		.replace(/\s+/g, " ")
		.trim()
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-+/, "")
		.replace(/-+$/, "")
		.replace(/-+/g, "-")
		.slice(0, 72)
		.replace(/-+$/, "");
	return slug || fallback;
}

export function titleFromSlug(slug: string): string {
	return slug
		.split("-")
		.filter(Boolean)
		.map((part) => part.slice(0, 1).toUpperCase() + part.slice(1))
		.join(" ");
}

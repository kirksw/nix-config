#!/usr/bin/env python3
"""Render a structurally validated SVG to PNG; inspect the output separately."""
import argparse
import ctypes as C
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
from validate_svg import validate


def native_render(source, output):
    """Use installed librsvg and Cairo when Python CairoSVG is unavailable."""
    r, c, g = C.CDLL('librsvg-2.so.2'), C.CDLL('libcairo.so.2'), C.CDLL('libgobject-2.0.so.0')
    def bind(lib, name, args, result):
        f = getattr(lib, name)
        f.argtypes, f.restype = args, result
        return f
    ptr = C.c_void_p
    new = bind(r, 'rsvg_handle_new_from_file', [C.c_char_p, ptr], ptr)
    surface = bind(c, 'cairo_image_surface_create', [C.c_int, C.c_int, C.c_int], ptr)
    create = bind(c, 'cairo_create', [ptr], ptr)
    scale = bind(c, 'cairo_scale', [ptr, C.c_double, C.c_double], None)
    render = bind(r, 'rsvg_handle_render_cairo', [ptr, ptr], C.c_int)
    write = bind(c, 'cairo_surface_write_to_png', [ptr, C.c_char_p], C.c_int)
    destroy = bind(c, 'cairo_destroy', [ptr], None)
    free = bind(c, 'cairo_surface_destroy', [ptr], None)
    unref = bind(g, 'g_object_unref', [ptr], None)
    ET.register_namespace('', 'http://www.w3.org/2000/svg')
    root = ET.parse(source).getroot()
    box = root.get('viewBox').replace(',', ' ').split()
    w, h = max(1, round(float(box[2]))), max(1, round(float(box[3])))
    handle = new(str(source.resolve()).encode(), None)
    if not handle:
        raise RuntimeError('librsvg could not load SVG')
    s = surface(0, w * 2, h * 2)
    ctx = create(s)
    try:
        scale(ctx, 2, 2)
        if not render(handle, ctx) or write(s, str(output).encode()) != 0:
            raise RuntimeError('librsvg/Cairo rendering failed')
    finally:
        destroy(ctx); free(s); unref(handle)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('svg', type=Path)
    parser.add_argument('png', type=Path)
    args = parser.parse_args()
    if args.svg.resolve() == args.png.resolve():
        parser.error('Input and output must differ')
    try:
        failures = validate(args.svg)
        if failures:
            sys.exit('\n'.join(failures))
        args.png.parent.mkdir(parents=True, exist_ok=True)
        try:
            import cairosvg
        except ImportError:
            native_render(args.svg, args.png)
        else:
            cairosvg.svg2png(url=str(args.svg), write_to=str(args.png), scale=2)
    except (OSError, RuntimeError, AttributeError) as exc:
        sys.exit(f'Rendering unavailable or failed: {exc}. Use another SVG renderer and inspect its output.')
    print(f'Rendered {args.png}; visual inspection is still required.')

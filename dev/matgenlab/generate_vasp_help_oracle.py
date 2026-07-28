#!/usr/bin/env python3
"""Generate an offline oracle for VaspDoc using frozen HTTP responses."""

from __future__ import annotations

import io
import json
from contextlib import redirect_stdout
from unittest.mock import patch

from pymatgen.io.vasp.help import VaspDoc

HTML = """<html><body><div id="mw-content-text"><h1>ISYM</h1>
<p>ISYM controls the use of symmetry.</p><p>Default: 2</p></div>
<div class="printfooter">footer</div></body></html>"""
PAGES = [
    {
        "query": {"categorymembers": [{"title": "ENCUT"}, {"title": "ISMEAR"}]},
        "continue": {"cmcontinue": "page|2"},
    },
    {"query": {"categorymembers": [{"title": "ISYM"}]}},
]


class Response:
    def __init__(self, text: str):
        self.text = text

    def raise_for_status(self) -> None:
        return None


def main() -> None:
    page = 0

    def get(url: str, timeout: int = 60) -> Response:
        nonlocal page
        del timeout
        if "api.php" not in url:
            return Response(HTML)
        result = Response(json.dumps(PAGES[page]))
        page += 1
        return result

    with patch("pymatgen.io.vasp.help.requests.get", get):
        text = VaspDoc.get_help("isym")
        html = VaspDoc.get_help("isym", "html")
        tags = VaspDoc.get_incar_tags()
        stream = io.StringIO()
        with redirect_stdout(stream):
            VaspDoc().print_help("isym")
    print(
        json.dumps(
            {"text": text, "html": html, "tags": tags, "printed": stream.getvalue()},
            indent=2,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()

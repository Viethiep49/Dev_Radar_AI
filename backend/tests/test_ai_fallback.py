"""Tests for the keyword-based fallback AI (used when AI_ENGINE_URL is empty)."""

from app.services import fallback_ai

README = """# Awesome Tool

[![Build](https://img.shields.io/badge/build-passing-green.svg)](https://ci.example.com)
<p align="center"><img src="logo.png"></p>

Awesome Tool is a fast command line tool that converts markdown files into beautiful PDF documents.

It supports custom themes and syntax highlighting for many languages.

## Installation

Install it with pip:

```bash
pip install awesome-tool
```

## Usage

```bash
awesome convert README.md
```

## License

Released under the MIT license.
"""


def test_summarize_strips_badges_and_html():
    result = fallback_ai.summarize(1, "me/awesome", README)
    assert result["model"] == "fallback"
    assert result["summary"].startswith("Awesome Tool is a fast command line tool")
    assert "shields.io" not in result["summary"]
    assert "<img" not in result["summary"]
    assert len(result["summary"]) <= fallback_ai.SUMMARY_MAX_CHARS + 3


def test_summarize_trims_long_readme():
    long_readme = " ".join(["word"] * 1000)
    result = fallback_ai.summarize(1, "me/long", long_readme)
    assert len(result["summary"]) <= fallback_ai.SUMMARY_MAX_CHARS + 3
    assert result["summary"].endswith("...")


def test_quickstart_takes_code_under_install_heading():
    result = fallback_ai.summarize(1, "me/awesome", README)
    assert "pip install awesome-tool" in result["quickstart"]
    assert "awesome convert README.md" in result["quickstart"]


def test_quickstart_ignores_comments_inside_code():
    readme = "# Tool\n\n## Getting Started\n\n```bash\n# install deps\nnpm install\n```\n\n## API\n\ntext"
    assert fallback_ai.summarize(1, "me/tool", readme)["quickstart"] == "```bash\n# install deps\nnpm install\n```"


def test_quickstart_missing():
    result = fallback_ai.summarize(1, "me/x", "# X\n\nA small library without any examples at all here.")
    assert result["quickstart"] == fallback_ai.NO_QUICKSTART


def test_index_counts_paragraphs():
    result = fallback_ai.index(1, "me/awesome", [{"path": "README.md", "content": README}])
    assert result["chunks"] > 3


def test_chat_finds_matching_paragraph():
    result = fallback_ai.chat(1, "me/awesome", "What license is it released under?", [], README)
    assert result["answer"].startswith(fallback_ai.FALLBACK_PREFIX)
    assert "MIT license" in result["answer"]
    assert result["sources"][0] == {"path": "README.md", "excerpt": "Released under the MIT license."}
    assert len(result["sources"]) <= 3


def test_chat_no_match():
    result = fallback_ai.chat(1, "me/awesome", "kubernetes helm chart?", [], README)
    assert fallback_ai.NO_ANSWER in result["answer"]
    assert result["sources"] == []


def test_chat_without_readme():
    result = fallback_ai.chat(1, "me/awesome", "license?", [], None)
    assert fallback_ai.NO_README_ANSWER in result["answer"]
    assert result["sources"] == []

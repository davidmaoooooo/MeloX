from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from release_notes import parse_release_notes, write_platform_notes


class ReleaseNotesTests(unittest.TestCase):
    def parse(self, content: str) -> dict[str, list[str]]:
        with TemporaryDirectory() as directory:
            path = Path(directory) / "RELEASE_NOTES.md"
            path.write_text(content, encoding="utf-8")
            return parse_release_notes(path)

    def test_parses_both_platform_sections(self) -> None:
        sections = self.parse(
            "# MeloX 更新日志\n\n"
            "## iOS + Apple Watch\n\n"
            "- iOS 更新\n\n"
            "## macOS\n\n"
            "- macOS 更新\n"
        )

        self.assertEqual(sections["ios"], ["- iOS 更新"])
        self.assertEqual(sections["macos"], ["- macOS 更新"])

    def test_allows_one_platform_section_to_be_empty(self) -> None:
        sections = self.parse(
            "# MeloX 更新日志\n\n"
            "## iOS + Apple Watch\n\n"
            "- iOS 更新\n\n"
            "## macOS\n"
        )

        self.assertEqual(sections["ios"], ["- iOS 更新"])
        self.assertEqual(sections["macos"], [])

    def test_rejects_missing_platform_heading(self) -> None:
        with self.assertRaisesRegex(ValueError, "缺少平台区块"):
            self.parse(
                "# MeloX 更新日志\n\n"
                "## iOS + Apple Watch\n\n"
                "- iOS 更新\n"
            )

    def test_writes_only_selected_platform_entries(self) -> None:
        with TemporaryDirectory() as directory:
            output = Path(directory) / "ReleaseNotes.md"
            write_platform_notes(["- macOS 更新"], output)
            self.assertEqual(output.read_text(encoding="utf-8"), "- macOS 更新\n")


if __name__ == "__main__":
    unittest.main()

import unittest

import upstream_watch as w


def item(number, title, labels=(), pr=False):
    d = {"number": number, "title": title, "html_url": f"https://github.com/esnet/iperf/issues/{number}",
         "labels": [{"name": n} for n in labels]}
    if pr:
        d["pull_request"] = {}
    return d


class StateTest(unittest.TestCase):
    def test_parse_state_roundtrip(self):
        body = "texte\n" + w.render_state("2026-11-16T00:00:00Z", "3.22.1")
        self.assertEqual(w.parse_state(body), {"since": "2026-11-16T00:00:00Z", "last_tag": "3.22.1"})

    def test_parse_state_absent(self):
        self.assertIsNone(w.parse_state("pas d'état ici"))
        self.assertIsNone(w.parse_state(None))


class TagsTest(unittest.TestCase):
    def test_new_release_tags(self):
        tags = ["3.21", "3.22.1", "3.23", "3.23-rc1", "3.22.10", "foo"]
        self.assertEqual(w.new_release_tags(tags, "3.22.1"), ["3.22.10", "3.23"])

    def test_new_release_tags_none(self):
        self.assertEqual(w.new_release_tags(["3.21", "3.22.1"], "3.22.1"), [])


class HotTest(unittest.TestCase):
    def test_is_hot_keyword(self):
        self.assertTrue(w.is_hot(item(1, "UDP connect retry"), w.KEYWORDS, set()))

    def test_is_hot_label(self):
        self.assertTrue(w.is_hot(item(2, "Build problem", labels=["windows"]), w.KEYWORDS, set()))

    def test_is_hot_ref(self):
        self.assertTrue(w.is_hot(item(1402, "Something else"), w.KEYWORDS, {1402}))

    def test_is_hot_false(self):
        self.assertFalse(w.is_hot(item(3, "Typo in man page"), w.KEYWORDS, {1402}))


class DigestTest(unittest.TestCase):
    def setUp(self):
        self.items = [item(10, "Typo in man page"), item(11, "UDP --bidir hangs", pr=True)]

    def test_render_digest_sections(self):
        out = w.render_digest(self.items, "2026-11-16T00:00:00Z", "2026-11-23T00:00:00Z", 3, {11}, "3.22.1")
        self.assertLess(out.index("n°11"), out.index("n°10"))
        self.assertIn("- [ ] n°11 [PR] UDP --bidir hangs", out)
        self.assertIn("- [ ] n°10 [ticket] Typo in man page", out)
        self.assertIn("3 commits de retard", out)
        self.assertEqual(w.parse_state(out), {"since": "2026-11-23T00:00:00Z", "last_tag": "3.22.1"})

    def test_render_digest_never_references_or_mentions(self):
        items = [item(12, "Fix #123 reported by @someone, see https://github.com/esnet/iperf/issues/99")]
        out = w.render_digest(items, "a", "b", 0, set(), "3.22.1")
        self.assertNotRegex(out, r"(?<![`\w])#\d")          # no autolinked issue reference
        self.assertNotRegex(out, r"@\w")                     # no user mention
        self.assertNotRegex(out, r"(?<!`)https://github\.com/esnet")  # ESnet URLs only inside code spans

    def test_render_digest_no_lag_line(self):
        out = w.render_digest(self.items, "a", "b", 0, set(), "3.22.1")
        self.assertNotIn("de retard", out)


if __name__ == "__main__":
    unittest.main()

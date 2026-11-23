#!/usr/bin/env python3
"""Weekly ESnet watch for iperf3v (standard library only).

Lists the ESnet issues, pull requests and release tags that are new or updated
since the previous run, in one "Veille ESnet" issue of this repository, and opens
a "Porter vers <tag>" issue for each new ESnet release with the result of
iperf3v/watch/try_rebase.sh. The state of the previous run is kept in a comment
at the end of the last "Veille ESnet" issue.

The digest never links ESnet issues with "#n" or a bare URL, and neutralizes
"@" and "#" in titles: GitHub would otherwise add a cross-reference to the ESnet
issue every week, or notify the people mentioned.

Environment: GITHUB_TOKEN, GITHUB_REPOSITORY (owner/repo); WATCH_DRY_RUN=1 prints
the issues instead of creating them.
"""

import datetime
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request

UPSTREAM = "esnet/iperf"
API = "https://api.github.com"
DIGEST_LABEL = "veille-esnet"
PORT_LABEL = "portage"
KEYWORDS = ["udp", "connect", "bidir", "reverse", "keepalive", "cntl-ka", "windows", "cygwin"]
STATE_RE = re.compile(r"<!-- watch-state: (\{.*?\}) -->")
TAG_RE = re.compile(r"^\d+\.\d+(\.\d+)?$")
ZWSP = "​"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))


def render_state(since: str, last_tag: str) -> str:
    return "<!-- watch-state: %s -->" % json.dumps({"since": since, "last_tag": last_tag})


def parse_state(issue_body):
    if not issue_body:
        return None
    m = STATE_RE.search(issue_body)
    if not m:
        return None
    try:
        state = json.loads(m.group(1))
    except ValueError:
        return None
    if not isinstance(state, dict) or "since" not in state or "last_tag" not in state:
        return None
    return {"since": state["since"], "last_tag": state["last_tag"]}


def _tag_key(tag: str):
    return tuple(int(p) for p in tag.split("."))


def new_release_tags(tags, last_tag):
    """Release tags (3.x or 3.x.y) strictly newer than last_tag, oldest first."""
    last = _tag_key(last_tag)
    releases = [t for t in tags if TAG_RE.match(t)]
    return sorted((t for t in releases if _tag_key(t) > last), key=_tag_key)


def is_hot(item, keywords, our_refs) -> bool:
    if item.get("number") in our_refs:
        return True
    text = " ".join([item.get("title") or ""] + [l.get("name", "") for l in item.get("labels") or []]).lower()
    return any(k in text for k in keywords)


def safe_text(text: str) -> str:
    """Neutralize @mentions, #references and URLs (zero-width space after @, # and :/)."""
    return text.replace("@", "@" + ZWSP).replace("#", "#" + ZWSP).replace("://", ":/" + ZWSP + "/")


def _line(item) -> str:
    kind = "PR" if "pull_request" in item else "ticket"
    title = safe_text(" ".join((item.get("title") or "").split()))
    return "- [ ] n°%d [%s] %s — `%s`" % (item["number"], kind, title, item.get("html_url", ""))


def render_digest(items, since, until, master_behind, hot, last_tag) -> str:
    first = [i for i in items if i["number"] in hot]
    rest = [i for i in items if i["number"] not in hot]
    out = ["## Veille ESnet du %s au %s" % (since[:10], until[:10]), ""]
    if master_behind > 0:
        out += ["`master` a %d commits de retard sur ESnet (bouton « Sync fork »)." % master_behind, ""]
    out += ["### À regarder en premier", ""]
    out += [_line(i) for i in first] or ["(rien)"]
    out += ["", "### Le reste", ""]
    out += [_line(i) for i in rest] or ["(rien)"]
    out += ["", "Tri : étiquettes `amont:à-intégrer`, `amont:à-suivre` ou `amont:ignoré` sur ce ticket "
            "ou sur un ticket dédié, puis fermer ce ticket.", "", render_state(until, last_tag), ""]
    return "\n".join(out)


# --- GitHub and git plumbing (not unit-tested) ---------------------------------------------

def _api(method, path, body=None):
    req = urllib.request.Request(API + path, method=method)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, data, timeout=30) as resp:
        return json.loads(resp.read().decode() or "null")


def _paginate(path, max_pages=5):
    out = []
    sep = "&" if "?" in path else "?"
    for page in range(1, max_pages + 1):
        batch = _api("GET", "%s%sper_page=100&page=%d" % (path, sep, page))
        out += batch
        if len(batch) < 100:
            break
    return out


def _git(*args) -> str:
    return subprocess.run(["git", "-C", ROOT] + list(args), check=True, capture_output=True, text=True).stdout


def _our_refs():
    refs = set()
    with open(os.path.join(HERE, "our_refs.txt"), encoding="utf-8") as f:
        for line in f:
            line = line.split("#", 1)[0].strip()
            if line.isdigit():
                refs.add(int(line))
    return refs


def _create_issue(repo, title, body, label, dry_run):
    if dry_run:
        print("=== %s [%s]\n%s" % (title, label, body))
        return
    _api("POST", "/repos/%s/issues" % repo, {"title": title, "body": body, "labels": [label]})


def main() -> int:
    repo = os.environ["GITHUB_REPOSITORY"]
    dry_run = os.environ.get("WATCH_DRY_RUN") == "1"
    now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
    until = now.strftime("%Y-%m-%dT%H:%M:%SZ")

    last = _api("GET", "/repos/%s/issues?labels=%s&state=all&sort=created&direction=desc&per_page=1"
                % (repo, urllib.parse.quote(DIGEST_LABEL)))
    state = parse_state(last[0].get("body")) if last else None
    if state is None:
        with open(os.path.join(ROOT, "iperf3v", "BASE_TAG"), encoding="utf-8") as f:
            base = f.read().strip()
        state = {"since": (now - datetime.timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%SZ"), "last_tag": base}

    items = [i for i in _paginate("/repos/%s/issues?state=all&sort=updated&direction=asc&since=%s"
                                  % (UPSTREAM, urllib.parse.quote(state["since"])))
             if i.get("updated_at", "") > state["since"]]
    tags = [t["name"] for t in _paginate("/repos/%s/tags" % UPSTREAM)]
    new_tags = new_release_tags(tags, state["last_tag"])
    last_tag = new_tags[-1] if new_tags else state["last_tag"]
    try:
        master_behind = int(_git("rev-list", "--count", "origin/master..upstream/master").strip())
    except (subprocess.CalledProcessError, ValueError):
        master_behind = 0

    if not items and not new_tags:
        print("Rien de neuf chez ESnet depuis %s." % state["since"])
        return 0

    refs = _our_refs()
    hot = {i["number"] for i in items if is_hot(i, KEYWORDS, refs)}
    year, week, _ = now.isocalendar()
    _create_issue(repo, "Veille ESnet %d-S%02d" % (year, week),
                  render_digest(items, state["since"], until, master_behind, hot, last_tag),
                  DIGEST_LABEL, dry_run)

    for tag in new_tags:
        result = subprocess.run(["bash", os.path.join(HERE, "try_rebase.sh"), tag],
                                cwd=ROOT, capture_output=True, text=True)
        body = ("ESnet a publié `%s`. Essai automatique de la série sur ce tag "
                "(rien n'a été poussé) :\n\n%s\n%s" % (tag, result.stdout, result.stderr[-2000:]))
        _create_issue(repo, "Porter vers %s" % tag, body, PORT_LABEL, dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())

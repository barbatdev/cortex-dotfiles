// Open pull requests of the active space's repo, with their checks. The repo is
// read from git where the space lives (any machine); `gh` asks GitHub from here,
// so remote machines need no GitHub login. Click a row to open it in the browser.

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { spaces, panes, exec, theme, layout } from "herdr";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// Same rail test as refactoria-chrome: the collapsed sidebar is under 160px.
const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

// GitHub's rate limit is generous, but every space switch and this fallback ask again.
const EVERY = 60000;
const FIELDS = "number,title,url,isDraft,headRefName,statusCheckRollup";

// Where a space is now: its first terminal's live folder, else where it was made.
function place(s) {
  const tabs = new Set((s.tabs ?? []).map((c) => c.id));
  return panes().find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
}

// owner/name from an origin URL (ssh, https, or an ssh host alias).
export function slug(url) {
  const m = url.trim().match(/[:/]([^/:]+\/[^/]+?)(?:\.git)?\/?$/);
  return m ? m[1] : null;
}

// One state for all of a PR's checks: a failure wins, then anything still running.
export function checks(rollup) {
  if (!rollup?.length) return "none";
  const states = rollup.map((c) => (c.__typename === "StatusContext" ? c.state : c.status !== "COMPLETED" ? "PENDING" : c.conclusion));
  if (states.some((s) => ["FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE"].includes(s))) return "fail";
  if (states.some((s) => ["PENDING", "EXPECTED", "QUEUED", "IN_PROGRESS", null, undefined].includes(s))) return "pending";
  return "pass";
}

export default class PullRequests extends View {
  init(_props, cx) {
    this.key = null; // the active space's [machine, folder] last asked about
    this.repo = null; // owner/name, null: not a GitHub repo
    this.prs = null; // null: not asked yet
    this.error = null;
    this.at = 0;
    cx.timer.every(1000, (cx) => {
      const s = spaces().find((x) => x.active);
      const key = s ? JSON.stringify([s.machine ?? null, place(s)]) : null;
      if (key !== this.key || Date.now() - this.at > EVERY) this.refresh(key, cx);
    });
  }

  refresh(key, cx) {
    if (this.loading) return;
    const switched = key !== this.key;
    this.key = key;
    this.at = Date.now();
    if (switched) { this.prs = null; this.repo = null; this.error = null; cx.notify(); }
    if (!key) return;
    this.loading = true;
    const [on, cwd] = JSON.parse(key);
    cx.spawn(async (cx) => {
      try {
        const o = await exec("git", ["remote", "get-url", "origin"], { cwd, on: on ?? undefined });
        const repo = o.code === 0 ? slug(o.stdout) : null;
        if (key !== this.key) return;
        this.repo = repo;
        if (!repo) { this.prs = []; this.error = null; return; }
        const r = await exec("gh", ["pr", "list", "-R", repo, "--state", "open", "--limit", "20", "--json", FIELDS]);
        if (key !== this.key) return;
        if (r.code === 0) { this.prs = JSON.parse(r.stdout); this.error = null; }
        else this.error = r.stderr.trim().split("\n").pop() || "gh failed";
      } catch {
        // The machine is away or gh is missing: keep what was shown, try again later.
        if (key === this.key) this.error = "Could not reach the repo";
      } finally {
        this.loading = false;
        cx.notify();
      }
    });
  }

  row(t, pr) {
    const state = checks(pr.statusCheckRollup);
    const color = { pass: t.ansi2, fail: t.ansi1, pending: t.blocked, none: t.dim }[state];
    return h_flex().id(`pr-${pr.number}`).h(44).flex_none().px(8).gap(8).items_center().rounded(8).cursor_pointer()
      .hover((s) => s.bg(t.hover))
      .on_click(() => exec("open", [pr.url]))
      .child(div().size(8).rounded(4).flex_none().bg(color))
      .child(v_flex().flex_1().min_w(0)
        .child(div().truncate().text_color(pr.isDraft ? t.dim : t.foreground).child(pr.title))
        .child(div().truncate().text_size(12).text_color(t.dim).child(`#${pr.number} · ${pr.isDraft ? "draft · " : ""}${pr.headRefName}`)));
  }

  render(cx) {
    const t = theme();
    const note = (text) => div().px(8).py(6).text_size(12).text_color(t.dim).child(text);
    let body;
    if (!this.key) body = [note("No space selected")];
    else if (this.prs === null && !this.error) body = [note("Loading…")];
    else if (!this.repo && !this.error) body = [note("Not a GitHub repo")];
    else if (this.prs?.length) body = this.prs.map((pr) => this.row(t, pr));
    else if (!this.error) body = [note("No open pull requests")];
    else body = [];
    if (this.error) body.push(note(this.error));
    return v_flex().size_full().min_h(0).bg(t.chrome).text_size(13)
      .child(narrow()
        // On the rail the full title and repo get cut off: a short label only.
        ? h_flex().h(31).items_center().justify_center().text_size(12).text_color(t.dim).child("PRs")
        : h_flex().h(31).pl(16).pr(10).items_center().justify_between().text_size(12).text_color(t.dim)
          .child("Pull requests")
          .when(Boolean(this.repo), (el) => el.child(div().truncate().child(this.repo))))
      .child(v_flex().flex_1().min_h(0).px(8).pb(14).overflow_y_scrollbar().mode("always").children(body));
  }
}

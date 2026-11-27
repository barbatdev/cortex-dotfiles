// GitHub panel of the active space's repo: pull requests (expand for checks,
// reviewers, diff size and actions), issues, CI runs and the notification inbox.
// The repo is read from git where the space lives (any machine); `gh` asks GitHub
// from here, so remote machines need no GitHub login. Lives in the right panel
// stack next to files and changes.

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { spaces, panes, exec, theme, layout, window, checking } from "herdr";
import { slug, prRow, issueGroups, runRow, inbox, counts, nextFetch } from "./model.js";

const EVERY = 90000; // GitHub's rate limit is generous; space switches ask again anyway.
const TIMEOUT = 20000;
const PR_FIELDS = "number,title,url,isDraft,headRefName,author,reviewDecision,statusCheckRollup,additions,deletions,changedFiles,reviewRequests,latestReviews";
const ISSUE_FIELDS = "number,title,url,author,labels";
const RUN_FIELDS = "databaseId,displayTitle,workflowName,headBranch,event,status,conclusion,url,createdAt";
const TABS = [["prs", "PRs"], ["issues", "Issues"], ["ci", "CI"], ["inbox", "Inbox"]];

// Where a space is now: its first terminal's live folder, else where it was made.
function place(s) {
  const tabs = new Set((s.tabs ?? []).map((c) => c.id));
  return panes().find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
}

// Whether this panel is on screen: the panel column shown and our stack child active.
// Unknown layouts count as shown, so the data still refreshes.
function shown() {
  const find = (n, id) => {
    if (!n || typeof n !== "object") return null;
    if (n.id === id) return n;
    for (const c of n.children ?? []) { const f = find(c, id); if (f) return f; }
    return null;
  };
  let tree = null;
  try { tree = layout(); } catch { return true; }
  const panel = find(tree, "panel");
  const stack = find(tree, "panel-body");
  if (!panel || !stack) return true;
  return panel.hidden !== true && (stack.active ?? "files") === "github" && window()?.visible !== false;
}

// Last stderr line of a failed gh call, e.g. "gh auth login" advice.
function why(r) {
  return r.stderr.trim().split("\n").pop() || "gh failed";
}

async function gh(args) {
  const r = await exec("gh", args, { timeout: TIMEOUT });
  if (r.code !== 0) throw new Error(why(r));
  return JSON.parse(r.stdout || "null");
}

export default class GitHub extends View {
  init(_props, cx) {
    this.tab = "prs";
    this.key = null; // the active space's [machine, folder] last asked about
    this.repo = null; // owner/name, null: not a GitHub repo
    this.data = { prs: null, issues: null, runs: null, inbox: null };
    this.errors = {};
    this.open = null; // the expanded PR's number
    this.at = 0;
    this.seen = false;
    if (checking()) return;
    cx.timer.every(1000, (cx) => {
      const s = spaces().find((x) => x.active);
      const key = s ? JSON.stringify([s.machine ?? null, place(s)]) : null;
      const visible = shown();
      const appeared = visible && !this.seen;
      this.seen = visible;
      const what = nextFetch({ key, last: this.key, visible, appeared, at: this.at, now: Date.now(), loading: this.loading, every: EVERY });
      if (what) this.refresh(key, cx);
    });
  }

  // Loads every list for `key`. A newer call (a space switch) supersedes a running
  // one: the old one's results are dropped by the key check and its end no longer
  // clears `loading` for the new load.
  refresh(key, cx) {
    const switched = key !== this.key;
    const run = (this.run ?? 0) + 1;
    this.run = run;
    this.key = key;
    this.at = Date.now();
    if (switched) {
      this.repo = null;
      this.open = null;
      this.data = { prs: null, issues: null, runs: null, inbox: this.data.inbox };
      this.errors = {};
      cx.notify();
    }
    if (!key) { this.loading = false; return; }
    this.loading = true;
    const [on, cwd] = JSON.parse(key);
    cx.spawn(async (cx) => {
      try {
        let repo = null;
        try {
          const o = await exec("git", ["remote", "get-url", "origin"], { cwd, on: on ?? undefined, timeout: TIMEOUT });
          repo = o.code === 0 ? slug(o.stdout) : null;
        } catch {
          if (key === this.key) this.errors.repo = "Could not reach the repo";
        }
        if (key !== this.key) return;
        this.repo = repo;
        const jobs = {
          inbox: () => gh(["api", "notifications?participating=true&per_page=30"]).then(inbox),
        };
        if (repo) {
          jobs.prs = () => gh(["pr", "list", "-R", repo, "--state", "open", "--limit", "20", "--json", PR_FIELDS]).then((l) => l.map(prRow));
          jobs.issues = () => Promise.all([
            gh(["issue", "list", "-R", repo, "--assignee", "@me", "--state", "open", "--limit", "20", "--json", ISSUE_FIELDS]),
            gh(["issue", "list", "-R", repo, "--state", "open", "--limit", "20", "--json", ISSUE_FIELDS]),
          ]).then(([a, r]) => issueGroups(a, r));
          jobs.runs = () => gh(["run", "list", "-R", repo, "--limit", "15", "--json", RUN_FIELDS]).then((l) => l.map(runRow));
        } else {
          Object.assign(this.data, { prs: [], issues: { assigned: [], recent: [] }, runs: [] });
        }
        // Each list lands on its own: a failing one keeps what was shown before.
        await Promise.all(Object.entries(jobs).map(async ([name, job]) => {
          try {
            const value = await job();
            if (key !== this.key) return;
            this.data[name] = value;
            delete this.errors[name];
          } catch (e) {
            if (key === this.key) this.errors[name] = String(e?.message ?? e);
          }
          cx.notify();
        }));
      } finally {
        if (run === this.run) this.loading = false;
        cx.notify();
      }
    });
  }

  // Small rounded label.
  badge(t, text, color) {
    return div().flex_none().px(5).rounded(4).text_size(10.5).text_color(color).border_1().border_color(color).child(text);
  }

  dot(t, state) {
    const color = { pass: t.ansi2, fail: t.ansi1, pending: t.blocked, skip: t.dim, none: t.dim }[state] ?? t.dim;
    return div().size(8).rounded(4).flex_none().bg(color);
  }

  action(t, id, label, fn) {
    return div().id(id).px(8).py(2).rounded(6).text_size(12).cursor_pointer().bg(t.hover).text_color(t.foreground)
      .hover((s) => s.text_color(t.accent))
      .on_click((_e, cx) => { cx.stop_propagation(); fn(); })
      .child(label);
  }

  header(t, cx) {
    const c = counts(this.data);
    return h_flex().h(31).flex_none().px(8).gap(2).items_center().text_size(12)
      .children(TABS.map(([id, label]) => {
        const active = this.tab === id;
        const n = c[id];
        const hot = id === "ci" && n > 0;
        return h_flex().id(`tab-${id}`).flex_1().h(24).gap(4).justify_center().items_center().rounded(6).cursor_pointer()
          .bg(active ? t.hover : t.chrome).text_color(active ? t.foreground : t.dim)
          .hover((s) => s.text_color(t.foreground))
          .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
          // The click's own cx: one kept from render is stale and redraws nothing.
          .on_click((_e, cx) => { this.tab = id; cx.notify(); })
          .child(label)
          .when(n !== null, (el) => el.child(div().text_size(10.5).text_color(hot ? t.ansi1 : t.dim).child(String(n))));
      }));
  }

  prRow(t, pr, cx) {
    const open = this.open === pr.number;
    const reviewColor = { approved: t.ansi2, changes: t.ansi1, review: t.blocked }[pr.review] ?? t.dim;
    const row = h_flex().id(`pr-${pr.number}`).min_h(44).flex_none().px(8).gap(8).items_center().rounded(8).cursor_pointer()
      .when(open, (el) => el.bg(t.hover))
      .hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => { this.open = open ? null : pr.number; cx.notify(); })
      .child(this.dot(t, pr.checks.state))
      .child(v_flex().flex_1().min_w(0)
        .child(div().truncate().text_color(pr.draft ? t.dim : t.foreground).child(pr.title))
        .child(div().truncate().text_size(12).text_color(t.dim)
          .child(`#${pr.number} · ${pr.author}${pr.draft ? " · draft" : ""} · ${pr.branch}`)))
      .when(Boolean(pr.review), (el) => el.child(this.badge(t, pr.review, reviewColor)));
    if (!open) return [row];
    const ck = pr.checks;
    const summary = ck.items.length ? `${ck.pass} passed · ${ck.fail} failed · ${ck.pending} running` : "No checks";
    const detail = v_flex().flex_none().pl(24).pr(8).pt(4).pb(10).gap(6).text_size(12)
      .child(h_flex().gap(10).text_color(t.dim)
        .child(div().text_color(t.ansi2).child(`+${pr.additions}`))
        .child(div().text_color(t.ansi1).child(`−${pr.deletions}`))
        .child(`${pr.files} file${pr.files === 1 ? "" : "s"}`))
      .child(div().text_color(t.dim).child(summary))
      .children(ck.items.slice(0, 12).map((c, i) => h_flex().id(`ck-${pr.number}-${i}`).gap(6).items_center()
        .when(Boolean(c.url), (el) => el.cursor_pointer().hover((s) => s.text_color(t.accent)).on_click(() => exec("open", [c.url])))
        .child(this.dot(t, c.state))
        .child(div().truncate().child(c.name))))
      .when(pr.reviewers.length > 0, (el) => el.child(h_flex().flex_wrap().gap(4)
        .children(pr.reviewers.map((r) => this.badge(t, `${r.name} ${r.state}`,
          { approved: t.ansi2, changes: t.ansi1, requested: t.blocked }[r.state] ?? t.dim)))))
      .child(h_flex().gap(6).pt(2)
        .child(this.action(t, `open-${pr.number}`, "Open", () => exec("open", [pr.url])))
        .child(this.action(t, `files-${pr.number}`, "Diff", () => exec("open", [`${pr.url}/files`])))
        .child(this.action(t, `copy-${pr.number}`, "Copy branch",
          () => exec("sh", ["-c", "printf %s \"$1\" | pbcopy", "sh", pr.branch]))));
    return [row, detail];
  }

  simpleRow(t, id, state, title, sub, url, tag) {
    return h_flex().id(id).min_h(40).flex_none().px(8).gap(8).items_center().rounded(8).cursor_pointer()
      .hover((s) => s.bg(t.hover))
      .on_click(() => exec("open", [url]))
      .when(state !== null, (el) => el.child(this.dot(t, state)))
      .child(v_flex().flex_1().min_w(0)
        .child(div().truncate().text_color(state === "fail" ? t.ansi1 : t.foreground).child(title))
        .child(div().truncate().text_size(12).text_color(t.dim).child(sub)))
      .when(Boolean(tag), (el) => el.child(this.badge(t, tag, t.dim)));
  }

  group(t, label) {
    return div().flex_none().px(8).pt(8).pb(2).text_size(10.5).text_color(t.dim).child(label.toUpperCase());
  }

  body(t, cx) {
    const note = (text) => div().px(8).py(6).text_size(12).text_color(t.dim).child(text);
    const needsRepo = this.tab !== "inbox";
    if (needsRepo && !this.key) return [note("No space selected")];
    const name = { prs: "prs", issues: "issues", ci: "runs", inbox: "inbox" }[this.tab];
    const value = this.data[name];
    const error = this.errors[name] || (needsRepo ? this.errors.repo : null);
    const out = [];
    if (value === null && !error) out.push(note("Loading…"));
    else if (needsRepo && !this.repo && value !== null && !error) out.push(note("Not a GitHub repo"));
    else if (value !== null) {
      if (this.tab === "prs") {
        if (!value.length) out.push(note("No open pull requests"));
        for (const pr of value) out.push(...this.prRow(t, pr, cx));
      } else if (this.tab === "issues") {
        const one = (i) => this.simpleRow(t, `is-${i.number}`, null, i.title, `#${i.number} · ${i.author}`, i.url, i.labels[0]);
        out.push(this.group(t, `Assigned to you · ${value.assigned.length}`));
        out.push(...(value.assigned.length ? value.assigned.map(one) : [note("Nothing assigned")]));
        out.push(this.group(t, `Open in repo · ${value.recent.length}`));
        out.push(...(value.recent.length ? value.recent.map(one) : [note("No other open issues")]));
      } else if (this.tab === "ci") {
        if (!value.length) out.push(note("No workflow runs"));
        for (const r of value) out.push(this.simpleRow(t, `run-${r.id}`, r.state, r.title, `${r.workflow} · ${r.branch} · ${r.event}`, r.url, null));
      } else {
        if (!value.length) out.push(note("No participating notifications"));
        for (const n of value) out.push(this.simpleRow(t, `n-${n.id}`, null, n.title, `${n.repo} · ${n.type}`, n.url, n.reason));
      }
    }
    if (error) out.push(note(error));
    return out;
  }

  render(cx) {
    const t = theme();
    return v_flex().size_full().min_h(0).bg(t.chrome).text_size(13)
      .child(h_flex().h(31).flex_none().pl(16).pr(10).items_center().justify_between().text_size(12).text_color(t.dim)
        .child("GitHub")
        .when(Boolean(this.repo), (el) => el.child(div().truncate().child(this.repo))))
      .child(this.header(t, cx))
      .child(v_flex().flex_1().min_h(0).px(8).pb(14).overflow_y_scrollbar().mode("always").children(this.body(t, cx)));
  }
}

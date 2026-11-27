// GitHub panel of the active space's repo, drawn after design/herdr-github-panel/02-rich-tabs.html:
// a repo header, four count tabs with an attention dot (PRs / Issues / CI / Inbox), 3-line PR
// cards that expand inline (checks, reviewers, files, merge blocker, actions), grouped issues
// with toned label pills, CI runs with the failed step, and the participating inbox.
// The repo is read from git where the space lives (any machine); `gh` asks GitHub from here.
// Pure logic lives in ./model.js. Nothing here mutates GitHub unless a button is clicked, and
// Re-run asks once more inline first.

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { spaces, panes, exec, theme, layout, window, checking, openOverlay, nextCommand } from "herdr";
import {
  slug, issueGroups, inbox, counts, nextFetch, prCard, prGroups, blocker, prDetail, rerunTargets,
  runCard, failedStep, attention, relTime, syncedLabel, initials, avatarTone, mix,
} from "./model.js";

const EVERY = 90000; // GitHub's rate limit is generous; space switches ask again anyway.
const TIMEOUT = 20000;
const PR_FIELDS = "number,title,url,isDraft,headRefName,author,mergeable,reviewDecision,statusCheckRollup,additions,deletions,changedFiles,createdAt,updatedAt,reviewRequests,latestReviews,closingIssuesReferences";
const ISSUE_FIELDS = "number,title,url,author,labels,createdAt,comments";
const RUN_FIELDS = "databaseId,displayTitle,workflowName,headBranch,event,status,conclusion,url,createdAt,startedAt,updatedAt";
const TABS = [["prs", "PRs"], ["issues", "Issues"], ["ci", "CI"], ["inbox", "Inbox"]];
const SUB = { prs: "Open · needs you first", issues: "Open · assigned to you first", ci: "Recent workflow runs", inbox: "Participating · reviews first" };

const icon = (name) => `mods/refactoria-github/icons/${name}.svg`;
// Colours the theme has no name for, from the artboard's contrast table. Grey text only on the
// panel and the inset (5.16+), never on raised (4.19): hovered rows switch grey to `unknown`.
const SPARK = "#FFB547";
const MONO = "Menlo";
const tokens = (t) => ({
  ...t,
  panel: t.chrome, inset: t.background, raised: t.raised ?? t.hover,
  grey: t.ansi8 ?? "#8F839D", error: t.ansi1 ?? "#FF6B8A",
  done: t.done ?? t.ansi2, working: t.working, blocked: t.blocked, unknown: t.unknown ?? "#C7A6FF",
});
const activate = (e) => ["enter", "space"].includes(e?.key) || ["enter", "space"].includes(e?.keystroke);
const STATE_COLOR = (t) => ({ pass: t.done, fail: t.error, pending: t.working, skip: t.grey, none: t.grey });

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

const numOf = (url) => String(url ?? "").match(/\/(?:pull|issues)\/(\d+)/)?.[1] ?? null;

export default class GitHub extends View {
  init(_props, cx) {
    this.tab = "prs";
    this.key = null; // the active space's [machine, folder] last asked about
    this.repo = null; // owner/name, null: not a GitHub repo
    this.me = null; // the gh login, for "yours" and review requests
    this.data = { prs: null, issues: null, runs: null, inbox: null };
    this.errors = {};
    this.open = null; // the expanded PR's number
    this.details = {}; // PR number -> { loading, value, error }
    this.steps = {}; // run id -> failed step name
    this.confirm = null; // the id of a Re-run waiting for its second click
    this.notes = {}; // action id -> short result line
    this.hovered = null;
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
    cx.timer.every(30000, (cx) => cx.notify()); // ages
    // `herdr-app do refactoria-github.<tab>` (and the palette) switch the tab.
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (TABS.some(([id]) => id === c)) { this.tab = c; this.confirm = null; }
        // `expand-<number>` opens a PR card like a click (read-only: it only loads its detail).
        const pr = /^expand-(\d+)$/.exec(c);
        if (pr) { this.tab = "prs"; this.open = Number(pr[1]); this.confirm = null; this.loadDetail(this.open, cx); }
        cx.notify();
      }
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
      this.details = {};
      this.steps = {};
      this.confirm = null;
      this.notes = {};
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
        if (!this.me) {
          try {
            const r = await exec("gh", ["api", "user", "--jq", ".login"], { timeout: TIMEOUT });
            if (r.code === 0) this.me = r.stdout.trim() || null;
          } catch { /* no login: nothing is "yours" */ }
        }
        const now = () => Date.now();
        const jobs = {
          inbox: () => gh(["api", "notifications?participating=true&per_page=30"]).then(inbox),
        };
        if (repo) {
          jobs.prs = () => gh(["pr", "list", "-R", repo, "--state", "open", "--limit", "20", "--json", PR_FIELDS])
            .then((l) => l.map((p) => prCard(p, this.me, now())));
          jobs.issues = () => Promise.all([
            gh(["issue", "list", "-R", repo, "--assignee", "@me", "--state", "open", "--limit", "20", "--json", ISSUE_FIELDS]),
            gh(["issue", "list", "-R", repo, "--state", "open", "--limit", "20", "--json", ISSUE_FIELDS]),
          ]).then(([a, r]) => issueGroups(a, r, now()));
          jobs.runs = () => gh(["run", "list", "-R", repo, "--limit", "15", "--json", RUN_FIELDS]).then((l) => l.map((r) => runCard(r, now())));
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
        // The failed step of the newest failures (cheap: at most three calls).
        if (repo && this.data.runs) {
          const failed = this.data.runs.filter((r) => r.state === "fail" && !(r.id in this.steps)).slice(0, 3);
          await Promise.all(failed.map(async (r) => {
            try {
              const step = failedStep(await gh(["run", "view", String(r.id), "-R", repo, "--json", "jobs"]));
              if (key === this.key) this.steps[r.id] = step;
            } catch { if (key === this.key) this.steps[r.id] = null; }
          }));
        }
      } finally {
        if (run === this.run) this.loading = false;
        cx.notify();
      }
    });
  }

  // Checks with durations and the changed files, asked for when a card opens.
  loadDetail(number, cx) {
    const key = this.key, repo = this.repo;
    if (!repo || this.details[number]?.value || this.details[number]?.loading) return;
    this.details[number] = { loading: true };
    cx.spawn(async (cx) => {
      try {
        const value = prDetail(await gh(["pr", "view", String(number), "-R", repo, "--json", "files,statusCheckRollup"]));
        if (key === this.key) this.details[number] = { value };
      } catch (e) {
        if (key === this.key) this.details[number] = { error: String(e?.message ?? e) };
      }
      cx.notify();
    });
  }

  // `gh run rerun <id> --failed` for each id; only reached from the confirm step.
  rerun(id, runIds, cx) {
    const repo = this.repo;
    this.confirm = null;
    this.notes[id] = "Re-running failed jobs…";
    cx.spawn(async (cx) => {
      const bad = [];
      for (const r of runIds) {
        try {
          const out = await exec("gh", ["run", "rerun", String(r), "--failed", "-R", repo], { timeout: TIMEOUT });
          if (out.code !== 0) bad.push(why(out));
        } catch (e) { bad.push(String(e?.message ?? e)); }
      }
      this.notes[id] = bad.length ? `Re-run failed: ${bad[0]}` : "Re-run requested";
      cx.notify();
    });
  }

  // Herdr's own New worktree flow (the shipped `worktree` dialog with a branch) on a local copy
  // of the PR branch; the branch is fetched first when this checkout lacks it.
  checkout(id, pr, cx) {
    const s = spaces().find((x) => x.active);
    if (!s || !this.key) return;
    const [on, cwd] = JSON.parse(this.key);
    this.notes[id] = "Fetching branch…";
    cx.spawn(async (cx) => {
      const opt = { cwd, on: on ?? undefined, timeout: TIMEOUT };
      try {
        const has = await exec("git", ["show-ref", "--verify", "--quiet", `refs/heads/${pr.branch}`], opt);
        if (has.code !== 0) {
          const f = await exec("git", ["fetch", "origin", `refs/heads/${pr.branch}:refs/heads/${pr.branch}`], opt);
          if (f.code !== 0) { this.notes[id] = `Could not fetch ${pr.branch}: ${why(f)}`; cx.notify(); return; }
        }
        delete this.notes[id];
        openOverlay({ mod: "worktree", kind: "dialog", width: 480, props: { space: s.id, folder: cwd, branch: pr.branch } });
      } catch (e) {
        this.notes[id] = String(e?.message ?? e);
      }
      cx.notify();
    });
  }

  hover(id) {
    return (on, cx) => {
      if (on) this.hovered = id;
      else if (this.hovered === id) this.hovered = null;
      cx.notify();
    };
  }

  // ---- small parts ----

  glyph(name, color, size = 12) {
    return svg(icon(name)).size(size).flex_none().text_color(color);
  }

  // State never by colour alone: each state has its own shape, and a word sits next to it.
  stateGlyph(t, state, size = 14) {
    const color = STATE_COLOR(t)[state] ?? t.grey;
    const inner = (name, round) => div().size(size).flex_none().flex().items_center().justify_center()
      .when(round, (el) => el.rounded_full()).when(!round, (el) => el.rounded(Math.round(size / 4)))
      .bg(color).child(this.glyph(name, t.panel, size - 5));
    if (state === "pass") return inner("check", true);
    if (state === "fail") return inner("x", false);
    if (state === "pending") return this.glyph("pend", color, size);
    return div().size(size).flex_none().flex().items_center().justify_center()
      .child(div().size(size - 5).rounded_full().border(1.5).border_color(t.grey));
  }

  avatar(t, login, size = 18) {
    return div().size(size).flex_none().rounded_full().bg(avatarTone(login)).flex().items_center().justify_center()
      .text_size(size < 20 ? 8.5 : 9.5).font_bold().text_color(t.dim)
      .accessibility_label(login || "unknown").child(initials(login));
  }

  pill(t, p) {
    return h_flex().flex_none().gap(5).items_center().pl(6).pr(7).h(18).rounded_full()
      .bg(p.bg).border(1).border_color(p.border).text_size(10.5).font_medium().text_color(p.text)
      .child(div().size(6).rounded_full().bg(p.text))
      .child(p.name);
  }

  sizeBar(t, card) {
    const seg = (color) => div().w(5).h(7).rounded(1.5).bg(color);
    const s = card.size;
    return h_flex().flex_none().gap(5).items_center().text_size(11)
      .accessibility_label(`${card.additions} additions, ${card.deletions} deletions`)
      .child(div().text_color(t.done).child(`+${card.additions}`))
      .child(div().text_color(t.error).child(`−${card.deletions}`))
      .child(h_flex().gap(1.5)
        .children([...Array(s.plus)].map(() => seg(t.done)))
        .children([...Array(s.minus)].map(() => seg(t.error)))
        .children([...Array(s.empty)].map(() => seg(t.raised))));
  }

  button(t, id, label, glyphName, primary, onClick) {
    return h_flex().id(id).tab_index(0).flex_none().gap(5).px(10).h(26).rounded(6).items_center().text_size(11).cursor_pointer()
      .when(primary, (el) => el.bg(t.solid).text_color(t.solid_foreground).font_semibold())
      .when(!primary, (el) => el.border(1).border_color(t.unknown).text_color(t.muted).hover((s) => s.bg(t.raised)))
      .focus((el) => el.border(2).border_color(SPARK))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => { cx.stop_propagation(); onClick(cx); cx.notify(); })
      .on_key_down((e, cx) => { if (activate(e)) { cx.stop_propagation(); onClick(cx); cx.notify(); } })
      .when(Boolean(glyphName), (el) => el.child(this.glyph(glyphName, primary ? t.solid_foreground : t.unknown, 12)))
      .child(label);
  }

  iconButton(t, id, glyphName, label, onClick) {
    return div().id(id).tab_index(0).size(28).flex_none().rounded(7).flex().items_center().justify_center().cursor_pointer()
      .accessibility_label(label)
      .hover((s) => s.bg(t.raised))
      .focus((el) => el.border(2).border_color(SPARK))
      .on_click((_e, cx) => { cx.stop_propagation(); onClick(cx); })
      .on_key_down((e, cx) => { if (activate(e)) { cx.stop_propagation(); onClick(cx); } })
      .child(this.glyph(glyphName, t.unknown, 14));
  }

  link(t, id, label, onClick) {
    return div().id(id).tab_index(0).flex_none().text_size(11).font_medium().text_color(t.accent).underline().cursor_pointer()
      .focus((el) => el.border(1).border_color(SPARK))
      .on_click((_e, cx) => { cx.stop_propagation(); onClick(); })
      .on_key_down((e, cx) => { if (activate(e)) { cx.stop_propagation(); onClick(); } })
      .child(label);
  }

  section(t, label, n) {
    return h_flex().flex_none().gap(7).items_center().px(8).pt(16).pb(6)
      .text_size(10.5).font_semibold().text_color(t.grey)
      .child(label.toUpperCase())
      .when(n != null, (el) => el.child(div().font_medium().text_color(t.muted).child(String(n))));
  }

  note(t, text, color) {
    return div().px(8).py(6).text_size(12).text_color(color ?? t.grey).child(text);
  }

  // A clickable row/card: focusable, Enter/Space like a click, raised on hover with grey meta lifted.
  row(t, id, label, onClick) {
    return v_flex().id(id).tab_index(0).flex_none().w_full().px(8).pt(8).pb(9).rounded(9).cursor_pointer()
      .accessibility_label(label)
      .when(this.hovered === id, (el) => el.bg(t.raised))
      .on_hover(this.hover(id))
      .focus((el) => el.border(2).border_color(SPARK))
      .on_click((_e, cx) => { onClick(cx); cx.notify(); })
      .on_key_down((e, cx) => { if (activate(e)) { onClick(cx); cx.notify(); } });
  }

  // Line 1 of a row: glyph column, "#num title" (wraps), age at the right.
  titleLine(t, lead, num, title, age, extra) {
    return h_flex().w_full().gap(9).items_start()
      .child(div().w(16).flex_none().pt(2).child(lead))
      .child(h_flex().flex_1().min_w(0).gap(5).items_start().text_size(12.5).font_medium().line_height(1.35)
        .when(Boolean(num), (el) => el.child(div().flex_none().text_color(t.unknown).child(`#${num}`)))
        .child(div().flex_1().min_w(0).text_color(t.foreground).child(title)))
      .when(Boolean(age), (el) => el.child(div().flex_none().pt(1).text_size(10.5).text_color(extra?.lit ? t.unknown : t.grey).child(age)))
      .when(Boolean(extra?.right), (el) => el.child(extra.right));
  }

  meta(t, lit, children) {
    return h_flex().w_full().pl(25).pt(4).flex_wrap().gap_x(10).gap_y(4).items_center().text_size(11)
      .text_color(lit ? t.unknown : t.grey).children(children);
  }

  // ---- header ----

  header(t, cx) {
    const [owner, name] = (this.repo ?? "").split("/");
    const synced = syncedLabel(this.at, Date.now());
    return h_flex().flex_none().gap(8).items_center().pl(14).pr(8).pt(12).pb(4)
      .child(div().size(20).flex_none().rounded(5).bg(avatarTone(owner)).flex().items_center().justify_center()
        .text_size(9.5).font_bold().text_color(t.dim).child(this.repo ? initials(owner) : "GH"))
      .child(h_flex().flex_1().min_w(0).items_center().text_size(13)
        .when(!this.repo, (el) => el.child(div().font_semibold().child("GitHub")))
        .when(Boolean(this.repo), (el) => el
          .child(div().min_w(0).truncate().text_color(t.grey).child(`${owner}/`))
          .child(div().flex_none().font_semibold().text_color(t.foreground).child(name))))
      .when(Boolean(synced), (el) => el.child(h_flex().flex_none().gap(4).items_center().text_size(10.5).text_color(t.grey)
        .accessibility_label(`Synced ${synced === "now" ? "just now" : `${synced} ago`}`)
        .child(this.glyph(this.loading ? "sync" : "clock", t.grey, 11)).child(this.loading ? "Syncing" : synced)))
      .child(this.iconButton(t, "gh-refresh", "sync", "Refresh GitHub data", (cx) => { if (!this.loading) this.refresh(this.key, cx); }))
      .when(Boolean(this.repo), (el) => el.child(this.iconButton(t, "gh-open-repo", "ext", "Open repository on GitHub",
        () => exec("open", [`https://github.com/${this.repo}`]))));
  }

  tabs(t) {
    const c = counts(this.data);
    const att = attention({ prs: this.data.prs, runs: this.data.runs, inbox: this.data.inbox, me: this.me });
    const ciFail = c.ci > 0;
    return h_flex().flex_none().mx(14).mt(8).mb(4).p(3).gap(2).rounded(9).bg(t.inset)
      .children(TABS.map(([id, label]) => {
        const on = this.tab === id;
        const n = c[id];
        const dot = att[id] ? (id === "ci" || (id === "prs" && (this.data.prs ?? []).some((p) => p.group === "yours" && p.checks.state === "fail")) ? t.error : t.blocked) : null;
        const word = id === "ci" ? "failing" : "";
        const sel = () => { this.tab = id; this.confirm = null; };
        return v_flex().id(`tab-${id}`).tab_index(0).role("button").flex_1().min_w(0).min_h(40).py(5).rounded(7)
          .items_center().justify_center().gap(1).cursor_pointer().relative()
          .bg(on ? t.raised : t.inset)
          .accessibility_label(`${label} tab${on ? ", selected" : ""}${n != null ? `, ${n}${word ? ` ${word}` : ""}` : ""}${dot ? ", needs you" : ""}`)
          .focus((el) => el.border(2).border_color(SPARK))
          .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
          // The click's own cx: one kept from render is stale and redraws nothing.
          .on_click((_e, cx) => { sel(); cx.notify(); })
          .on_key_down((e, cx) => { if (activate(e)) { sel(); cx.notify(); } })
          .child(div().text_size(14).font_semibold().text_color(id === "ci" && ciFail ? t.error : t.foreground).child(n == null ? "–" : String(n)))
          .child(div().text_size(11).text_color(on ? t.foreground : t.muted).child(label))
          .when(Boolean(dot), (el) => el.child(div().absolute().top(5).right(8).size(7).rounded_full().bg(dot)));
      }));
  }

  // ---- PRs ----

  reviewGlyph(t, state) {
    if (state === "approved") return [this.stateGlyph(t, "pass", 11), t.done, "Approved"];
    if (state === "changes") return [div().size(11).rounded_full().bg(t.blocked).flex().items_center().justify_center().child(this.glyph("plus", t.panel, 8)), t.blocked, "Changes requested"];
    if (state === "requested") return [this.glyph("eye", t.blocked, 11), t.blocked, "Requested"];
    return [this.glyph("comment", t.unknown, 11), t.unknown, state === "commented" ? "Commented" : state];
  }

  prStateBit(t, card, lit) {
    const s = card.state;
    const [g, color] = {
      changes: [() => this.reviewGlyph(t, "changes")[0], t.blocked],
      approved: [() => this.stateGlyph(t, "pass", 11), t.done],
      conflict: [() => this.glyph("merge", t.blocked, 11), t.blocked],
      waiting: [() => this.glyph("clock", lit ? t.unknown : t.grey, 11), lit ? t.unknown : t.grey],
      draft: [() => this.glyph("draft", lit ? t.unknown : t.grey, 11), lit ? t.unknown : t.grey],
    }[s.kind];
    return h_flex().flex_none().gap(4).items_center().text_color(color).child(g()).child(s.word);
  }

  prCardEl(t, card) {
    const id = `pr-${card.number}`;
    const open = this.open === card.number;
    const lit = this.hovered === id && !open;
    const toggle = (cx) => {
      this.open = open ? null : card.number;
      this.confirm = null;
      if (!open) this.loadDetail(card.number, cx);
    };
    const lead = this.glyph(card.draft ? "draft" : "pr", card.draft ? (lit ? t.unknown : t.grey) : t.working, 14);
    const ck = card.checkWord;
    const dots = card.checks.items.slice(0, 5).map((c) => this.stateGlyph(t, c.state, 9));
    const el = this.row(t, id, `Pull request ${card.number}, ${card.title}, ${card.state.word}, checks ${ck.word}${open ? ", expanded" : ""}`, toggle)
      .child(this.titleLine(t, lead, card.number, card.title, open ? null : card.age, {
        lit,
        right: open ? this.glyph("chev", t.unknown, 14) : null,
      }))
      .child(this.meta(t, lit, [
        this.prStateBit(t, card, lit),
        ...(card.linked.length ? [h_flex().flex_none().gap(4).items_center().child(this.glyph("link", lit ? t.unknown : t.grey, 11)).child(card.linked.map((n) => `#${n}`).join(" "))] : []),
        h_flex().flex_none().gap(4).items_center().child(this.avatar(t, card.author, 16)).child(card.author),
        h_flex().min_w(0).gap(4).items_center().child(this.glyph("branch", lit ? t.unknown : t.grey, 11))
          .child(div().min_w(0).truncate().font_family(MONO).text_size(10.5).text_color(t.dim).child(card.branch)),
        ...(open ? [div().flex_none().child(card.age)] : []),
      ]))
      .when(!open, (row) => row.child(h_flex().w_full().pl(25).pt(6).gap(10).items_center().text_size(11).text_color(lit ? t.unknown : t.grey)
        .child(h_flex().flex_none().gap(4).items_center()
          .when(dots.length > 0, (e) => e.child(h_flex().gap(2).children(dots)))
          .child(div().text_color(ck.state === "fail" ? t.error : ck.state === "pending" ? t.working : lit ? t.unknown : t.grey).child(ck.word)))
        .when(card.reviewers.length > 0, (e) => e.child(h_flex().flex_none().gap(2)
          .children(card.reviewers.slice(0, 4).map((r) => this.avatar(t, r.name, 18).accessibility_label(`${r.name}, ${this.reviewGlyph(t, r.state)[2]}`)))))
        .child(div().flex_1())
        .child(this.sizeBar(t, card))));
    if (!open) return el;
    return el.bg(t.inset).border(1).border_color(t.raised).rounded(12).my(4).child(this.prDetailEl(t, card));
  }

  detailBlock(t, title, n, body) {
    return v_flex().w_full().mt(12).pt(10).border_t_1().border_color(t.raised).gap(6)
      .when(Boolean(title), (el) => el.child(h_flex().gap(6).items_center().text_size(10.5).font_semibold().text_color(t.grey)
        .child(title.toUpperCase())
        .when(Boolean(n), (e) => e.child(div().font_medium().text_color(t.muted).child(n)))))
      .children(body);
  }

  prDetailEl(t, card) {
    const d = this.details[card.number] ?? {};
    const v = d.value;
    const id = `pr-${card.number}`;
    const checks = v?.checks ?? card.checks.items.map((c) => ({ ...c, duration: "" }));
    const pass = checks.filter((c) => c.state === "pass").length, fail = checks.filter((c) => c.state === "fail").length;
    const pend = checks.filter((c) => c.state === "pending").length;
    const summary = checks.length ? [pass && `${pass} passed`, fail && `${fail} failed`, pend && `${pend} running`].filter(Boolean).join(" · ") : "none";
    const runIds = rerunTargets(v?.checks ?? []);
    const blocked = blocker(card);
    const parts = [];
    parts.push(this.detailBlock(t, "Checks", summary, checks.length
      ? checks.slice(0, 12).map((c, i) => h_flex().w_full().gap(8).items_center().py(3).text_size(11.5)
        .text_color(c.state === "fail" ? t.foreground : t.muted)
        .child(this.stateGlyph(t, c.state, 12))
        .child(div().min_w(0).truncate().child(c.name))
        .when(Boolean(c.url), (el) => el.child(this.link(t, `${id}-log-${i}`, c.state === "fail" ? "Log" : "Open", () => exec("open", [c.url]))))
        .child(div().flex_1())
        .child(div().flex_none().text_size(10.5).text_color(t.grey).child(c.duration || (c.state === "pending" ? "running" : ""))))
      : [this.note(t, "No checks yet")]));
    if (card.reviewers.length) {
      parts.push(this.detailBlock(t, "Reviewers", null, card.reviewers.map((r) => {
        const [g, color, word] = this.reviewGlyph(t, r.state);
        return h_flex().w_full().gap(8).items_center().text_size(11.5).text_color(t.muted)
          .child(this.avatar(t, r.name, 18)).child(r.me ? "You" : r.name).child(div().flex_1())
          .child(h_flex().gap(4).items_center().text_size(10.5).text_color(color).child(g).child(word));
      })));
    }
    if (d.loading) parts.push(this.detailBlock(t, "Files", `${card.files}`, [this.note(t, "Loading files…")]));
    else if (d.error) parts.push(this.detailBlock(t, "Files", `${card.files}`, [this.note(t, d.error, t.error)]));
    else if (v) {
      parts.push(this.detailBlock(t, "Files", `${v.files.count} · +${card.additions} −${card.deletions}`,
        v.files.top.map((f) => h_flex().w_full().gap(8).items_center().font_family(MONO).text_size(11).text_color(t.muted)
          .child(div().flex_1().min_w(0).truncate().child(f.path))
          .child(div().text_color(t.done).child(`+${f.additions}`))
          .child(div().text_color(t.error).child(`−${f.deletions}`)))
          .concat(v.files.count > v.files.top.length ? [div().text_size(10.5).text_color(t.grey).child(`and ${v.files.count - v.files.top.length} more`)] : [])));
    }
    const ok = blocked === "Ready to merge";
    parts.push(this.detailBlock(t, null, null, [h_flex().w_full().flex_wrap().gap(6).items_center().text_size(11.5)
      .text_color(ok ? t.done : t.blocked)
      .child(this.glyph("merge", ok ? t.done : t.blocked, 13)).child(blocked)
      .when(card.linked.length > 0, (el) => el.child(div().text_color(t.muted).child("· Links"))
        .child(div().text_color(t.unknown).child(card.linked.map((n) => `#${n}`).join(" "))))]));
    const acts = [
      this.button(t, `${id}-review`, "Start review", "eye", true, () => exec("open", [`${card.url}/files`])),
      this.button(t, `${id}-checkout`, "Checkout in new space", "space", false, (cx) => this.checkout(id, card, cx)),
    ];
    if (runIds.length) acts.push(this.button(t, `${id}-rerun`, "Re-run failed", "rerun", false, () => { this.confirm = id; }));
    acts.push(this.button(t, `${id}-copy`, "Copy branch", "copy", false,
      () => { exec("sh", ["-c", "printf %s \"$1\" | pbcopy", "sh", card.branch]); this.notes[id] = `Copied ${card.branch}`; }));
    acts.push(this.button(t, `${id}-web`, "GitHub", "ext", false, () => exec("open", [card.url])));
    parts.push(this.detailBlock(t, null, null, [h_flex().w_full().flex_wrap().gap(6).children(acts)]));
    if (this.confirm === id) parts.push(this.confirmEl(t, id, `Re-run the failed jobs of ${runIds.length} run${runIds.length === 1 ? "" : "s"}?`, (cx) => this.rerun(id, runIds, cx)));
    if (this.notes[id]) parts.push(div().pt(6).text_size(11).text_color(t.muted).child(this.notes[id]));
    return v_flex().w_full().children(parts);
  }

  confirmEl(t, id, question, go) {
    return h_flex().w_full().mt(8).p(8).gap(6).flex_wrap().items_center().rounded(8).border(1).border_color(t.blocked)
      .child(div().flex_1().min_w(0).text_size(11.5).text_color(t.foreground).child(question))
      .child(this.button(t, `${id}-rerun-yes`, "Re-run", "rerun", true, go))
      .child(this.button(t, `${id}-rerun-no`, "Cancel", null, false, () => { this.confirm = null; }));
  }

  // ---- Issues / CI / Inbox ----

  issueEl(t, i) {
    const id = `is-${i.number}`;
    const lit = this.hovered === id;
    return this.row(t, id, `Issue ${i.number}, ${i.title}, by ${i.author}${i.age ? `, ${i.age} old` : ""}`, () => exec("open", [i.url]))
      .child(this.titleLine(t, this.glyph("issue", t.done, 14), i.number, i.title, i.age, { lit }))
      .child(this.meta(t, lit, [
        h_flex().flex_none().gap(4).items_center().child(this.avatar(t, i.author, 16)).child(i.author),
        ...(i.comments ? [h_flex().flex_none().gap(4).items_center().child(this.glyph("comment", lit ? t.unknown : t.grey, 11)).child(String(i.comments))] : []),
        ...i.pills.slice(0, 4).map((p) => this.pill(t, lit ? { ...p, bg: mix(p.text, t.raised, 0.14) } : p)),
      ]));
  }

  runEl(t, r) {
    const id = `run-${r.id}`;
    const lit = this.hovered === id;
    const color = STATE_COLOR(t)[r.state];
    const step = this.steps[r.id];
    const el = this.row(t, id, `Run ${r.title}, ${r.workflow}, ${r.word}`, () => exec("open", [r.url]))
      .child(this.titleLine(t, this.stateGlyph(t, r.state, 14), null, r.title, r.age, { lit }))
      .child(this.meta(t, lit, [
        h_flex().flex_none().gap(4).items_center().text_color(color === t.grey && lit ? t.unknown : color).child(r.word)
          .when(Boolean(r.duration), (e) => e.child(div().text_color(lit ? t.unknown : t.grey).child(`· ${r.duration}`))),
        div().flex_none().child(r.workflow),
        h_flex().min_w(0).gap(4).items_center().child(this.glyph("branch", lit ? t.unknown : t.grey, 11))
          .child(div().min_w(0).truncate().font_family(MONO).text_size(10.5).text_color(t.dim).child(r.branch)),
        div().flex_none().child(r.event),
      ]));
    if (r.state !== "fail") return el;
    el.border(1).border_color(t.error);
    if (step) el.child(h_flex().w_full().pl(25).pt(5).gap(5).items_center().text_size(11.5).text_color(t.error)
      .child(this.glyph("x", t.error, 11)).child(div().min_w(0).truncate().child(`Failed at ${step}`)));
    if (r.rerun) el.child(h_flex().w_full().pl(25).pt(8).gap(6).flex_wrap()
      .child(this.button(t, `${id}-rerun`, "Re-run failed", "rerun", false, () => { this.confirm = id; }))
      .child(this.button(t, `${id}-log`, "Logs", "ext", false, () => exec("open", [r.url]))));
    if (this.confirm === id) el.child(div().w_full().pl(25).child(this.confirmEl(t, id, "Re-run the failed jobs of this run?", (cx) => this.rerun(id, [r.id], cx))));
    if (this.notes[id]) el.child(div().pl(25).pt(6).text_size(11).text_color(t.muted).child(this.notes[id]));
    return el;
  }

  noteEl(t, n) {
    const id = `n-${n.id}`;
    const lit = this.hovered === id;
    const g = n.reason === "review" ? this.glyph("eye", t.blocked, 14) : n.reason === "mention" ? this.glyph("at", t.working, 14)
      : this.glyph(n.type === "Issue" ? "issue" : n.type === "PullRequest" ? "pr" : "comment", lit ? t.unknown : t.grey, 14);
    const num = numOf(n.url);
    const word = { review: "Review requested", mention: "Mentioned" }[n.reason] ?? (n.reason ? n.reason[0].toUpperCase() + n.reason.slice(1) : "");
    return this.row(t, id, `${word}, ${n.title}, ${n.repo}${num ? ` #${num}` : ""}${n.unread ? ", unread" : ""}`, () => exec("open", [n.url]))
      .child(this.titleLine(t, g, null, n.title, relTime(n.at), { lit }))
      .child(this.meta(t, lit, [
        div().flex_none().font_medium().text_color(n.reason === "review" ? t.blocked : n.reason === "mention" ? t.working : lit ? t.unknown : t.grey).child(word),
        div().min_w(0).truncate().child(`${n.repo}${num ? `#${num}` : ""}`),
        ...(n.unread ? [h_flex().flex_none().gap(4).items_center().text_color(t.foreground).child(div().size(6).rounded_full().bg(t.accent)).child("Unread")] : []),
      ]));
  }

  body(t) {
    const needsRepo = this.tab !== "inbox";
    if (needsRepo && !this.key) return [this.note(t, "No space selected")];
    const name = { prs: "prs", issues: "issues", ci: "runs", inbox: "inbox" }[this.tab];
    const value = this.data[name];
    const error = this.errors[name] || (needsRepo ? this.errors.repo : null);
    const out = [];
    if (value === null && !error) out.push(this.note(t, "Loading…"));
    else if (needsRepo && !this.repo && value !== null && !error) out.push(this.note(t, "Not a GitHub repo"));
    else if (value !== null) {
      if (this.tab === "prs") {
        if (!value.length) out.push(this.note(t, "No open pull requests"));
        for (const g of prGroups(value)) {
          out.push(this.section(t, g.label, g.items.length));
          out.push(...g.items.map((c) => this.prCardEl(t, c)));
        }
      } else if (this.tab === "issues") {
        out.push(this.section(t, "Assigned to you", value.assigned.length));
        out.push(...(value.assigned.length ? value.assigned.map((i) => this.issueEl(t, i)) : [this.note(t, "Nothing assigned to you")]));
        out.push(this.section(t, "Open in repo", value.recent.length));
        out.push(...(value.recent.length ? value.recent.map((i) => this.issueEl(t, i)) : [this.note(t, "No other open issues")]));
      } else if (this.tab === "ci") {
        if (!value.length) out.push(this.note(t, "No workflow runs"));
        const failing = value.filter((r) => r.state === "fail");
        if (failing.length) {
          out.push(this.section(t, "Failing", failing.length));
          out.push(...failing.map((r) => this.runEl(t, r)));
        }
        const rest = value.filter((r) => r.state !== "fail");
        if (rest.length) {
          out.push(this.section(t, "Recent", rest.length));
          out.push(...rest.map((r) => this.runEl(t, r)));
        }
      } else {
        if (!value.length) out.push(this.note(t, "No participating notifications"));
        const groups = [["Review requested", value.filter((n) => n.reason === "review")], ["Mentions", value.filter((n) => n.reason === "mention")],
          ["Other", value.filter((n) => n.reason !== "review" && n.reason !== "mention")]];
        for (const [label, list] of groups) {
          if (!list.length) continue;
          out.push(this.section(t, label, list.length));
          out.push(...list.map((n) => this.noteEl(t, n)));
        }
      }
    }
    if (error) out.push(this.note(t, error, t.error));
    return out;
  }

  render() {
    const t = tokens(theme());
    return v_flex().size_full().min_h(0).bg(t.panel).text_size(12).text_color(t.foreground)
      .child(this.header(t))
      .child(this.tabs(t))
      .child(div().flex_none().px(14).pt(6).pb(2).text_size(11).text_color(t.grey).child(SUB[this.tab]))
      .child(v_flex().flex_1().min_h(0).px(8).pb(16).gap(2).overflow_y_scrollbar().mode("always").children(this.body(t)));
  }
}

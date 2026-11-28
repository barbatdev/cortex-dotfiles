// Pure model of the refactoria-chrome footer's usage line: desktop feed snapshots in, today's
// totals out. Tested with node --test tests/herdr_github_test.mjs; no Herdr imports here.

const sameDay = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

// Tokens and cost of the local Gentle Shell sessions whose snapshot changed today (local time):
// each session's own totals (feed `stats`, else `cost.total`), most expensive first. Null when none.
export function todayUsage(feeds, now = Date.now()) {
  const day = new Date(now);
  const sessions = [];
  for (const f of feeds ?? []) {
    const at = new Date(f?.updatedAt ?? NaN);
    if (Number.isNaN(at.getTime()) || !sameDay(at, day)) continue;
    const s = f.stats ?? {};
    const tokens = ["input", "output", "cacheRead", "cacheWrite"].reduce((sum, k) => sum + (Number(s[k]) || 0), 0);
    const cost = Number(s.cost ?? f.cost?.total) || 0;
    sessions.push({ name: f.identity?.sessionName || f.identity?.sessionId || "session", tokens, cost });
  }
  if (!sessions.length) return null;
  sessions.sort((a, b) => b.cost - a.cost || b.tokens - a.tokens);
  const total = (k) => sessions.reduce((sum, x) => sum + x[k], 0);
  return { tokens: total("tokens"), cost: Math.round(total("cost") * 100) / 100, sessions };
}

// 950, 10.3k, 1.25M.
export function formatTokens(n) {
  if (n >= 1e6) return `${Number((n / 1e6).toFixed(2))}M`;
  if (n >= 1e3) return `${Number((n / 1e3).toFixed(1))}k`;
  return String(n);
}

// The state a notification shows (icon + word, never color alone), from its level. Pure, so
// node --test loads it (tests/herdr_toast_test.mjs). Herdr's own toasts keep their title and body.

const AGENT_ASKS = /\b(asks|needs you|need you|waiting for you|blocked)\b/i;

export function toastLook(p) {
  const level = p?.level;
  if (level === "error") return { kind: "failed", word: "Failed" };
  if (level === "success") return { kind: "done", word: "Finished" };
  if (level === "warning") return { kind: "blocked", word: AGENT_ASKS.test(`${p.title ?? ""} ${p.body ?? ""}`) ? "Needs you" : "Heads up" };
  return { kind: "info", word: "Info" };
}

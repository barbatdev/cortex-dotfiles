/**
 * Cortex agent-state Pi adapter.
 *
 * Translates Pi lifecycle events into `cortex.agent_state.v1` reports via the
 * `agent-state` CLI, so external surfaces (Herdr labels, notifications,
 * SketchyBar) can consume normalized agent state. Herdr's own
 * `herdr-agent-state.ts` integration still owns pane lifecycle reporting; this
 * adapter only feeds the Cortex state store.
 *
 * Reports in every runtime mode (TUI, RPC, -p print) so headless and
 * background agents are visible too. All failures are silent: state reporting
 * must never break a session.
 */
import { spawn } from "node:child_process";
interface AgentStatePi {
	events: { on(name: string, handler: (data?: unknown) => void): void };
	on(name: string, handler: (event?: unknown, ctx?: unknown) => void | Promise<void>): void;
}

const STATE_BY_EVENT: Record<string, string> = {
	agent_start: "working",
	agent_settled: "idle",
	"herdr:blocked": "blocked",
};

function agentIdentity(): string {
	const cwd = process.cwd().split("/").filter(Boolean).slice(-2).join("/");
	return `pi:${cwd || "unknown"}`;
}

function messageFor(state: string, raw: unknown): string | undefined {
	if (state === "blocked") {
		const data = raw as { label?: string } | undefined;
		return typeof data?.label === "string" && data.label ? data.label : "needs user input";
	}
	return undefined;
}

export default function (pi: AgentStatePi) {
	const agentStateBin = `${process.env.HOME ?? ""}/.local/bin/agent-state`;

	function report(state: string, raw?: unknown): void {
		if (process.env.CORTEX_AGENT_STATE_DISABLE === "1") {
			return;
		}
		try {
			const args = [
				"report",
				"--source",
				"pi",
				"--agent",
				agentIdentity(),
				"--state",
				state,
			];
			const message = messageFor(state, raw);
			if (message) {
				args.push("--message", message);
			}
			const child = spawn(agentStateBin, args, { detached: true, stdio: "ignore" });
			child.unref();
		} catch {
			// Reporting must never break the session.
		}
	}

	pi.on("agent_start", () => report("working"));
	pi.on("agent_settled", () => report("idle"));
	pi.events.on("herdr:blocked", (data) => report("blocked", data));
}

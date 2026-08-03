export const FAILURE_THRESHOLD = 3;

export type JournalGateState = {
	consecutiveFailures: number;
	journalRequired: boolean;
};

export function createJournalGateState(): JournalGateState {
	return { consecutiveFailures: 0, journalRequired: false };
}

export function isJournalRantToolCall(toolName: unknown, input: unknown): boolean {
	if (toolName !== "agent_journal" || !input || typeof input !== "object" || Array.isArray(input)) return false;
	return (input as { action?: unknown }).action === "rant";
}

export function observeToolResult(
	state: JournalGateState,
	isError: boolean,
	isRant: boolean,
): { state: JournalGateState; thresholdReached: boolean } {
	if (isError) {
		const consecutiveFailures = state.consecutiveFailures + 1;
		const journalRequired = state.journalRequired || consecutiveFailures >= FAILURE_THRESHOLD;
		return {
			state: { consecutiveFailures, journalRequired },
			thresholdReached: !state.journalRequired && consecutiveFailures >= FAILURE_THRESHOLD,
		};
	}

	return {
		state: {
			consecutiveFailures: 0,
			journalRequired: isRant ? false : state.journalRequired,
		},
		thresholdReached: false,
	};
}

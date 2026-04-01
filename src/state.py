"""共享状态：Agent、Telegram Bot、Browser 之间的协调层"""

import asyncio
import uuid
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class PendingInteraction:
    """Agent 发给用户的一个等待回应的交互"""
    interaction_id: str
    question: str
    options: list[str]
    event: asyncio.Event = field(default_factory=asyncio.Event)
    response: Optional[str] = None


class AgentState:
    def __init__(self):
        self.pending: dict[str, PendingInteraction] = {}
        self.subscriptions: list[dict] = []
        self.processed_ids: set[str] = set()
        self.browser_session = None  # BrowserSession instance, lazy init

    def create_interaction(self, question: str, options: list[str]) -> PendingInteraction:
        interaction_id = f"int_{uuid.uuid4().hex[:8]}"
        interaction = PendingInteraction(
            interaction_id=interaction_id,
            question=question,
            options=options,
        )
        self.pending[interaction_id] = interaction
        return interaction

    def resolve_interaction(self, interaction_id: str, response: str):
        if interaction_id in self.pending:
            interaction = self.pending[interaction_id]
            interaction.response = response
            interaction.event.set()

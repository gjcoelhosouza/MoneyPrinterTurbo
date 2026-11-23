"""Reusable script presets for the WebUI script settings.

A preset bundles the three advanced script settings that shape a generated
script: the system prompt, the free-form extra requirements and the paragraph
count. The "curiosidades" preset writes short, hook-driven fact videos in
Brazilian Portuguese, which is the format most Brazilian short-video channels
use for daily uploads.

The module stays free of Streamlit imports so it can be reused by the CLI and
by tests without starting the WebUI.
"""

from dataclasses import dataclass

from app.services import llm

PRESET_CURIOSIDADES_ID = "curiosidades_pt"

# Maximum length accepted by the WebUI text area that shows the system prompt.
MAX_SYSTEM_PROMPT_LENGTH = llm.MAX_SCRIPT_SYSTEM_PROMPT_LENGTH
MAX_SCRIPT_PROMPT_LENGTH = llm.MAX_SCRIPT_PROMPT_LENGTH


@dataclass(frozen=True)
class ScriptPreset:
    """A script preset applied to the WebUI advanced script settings."""

    preset_id: str
    label: str
    description: str
    system_prompt: str
    script_prompt: str
    paragraph_number: int
    video_language: str = ""

    def __post_init__(self):
        if not self.system_prompt.strip():
            raise ValueError(f"script preset {self.preset_id} needs a system prompt")
        if len(self.system_prompt) > MAX_SYSTEM_PROMPT_LENGTH:
            raise ValueError(
                f"script preset {self.preset_id} system prompt exceeds "
                f"{MAX_SYSTEM_PROMPT_LENGTH} characters"
            )
        if len(self.script_prompt) > MAX_SCRIPT_PROMPT_LENGTH:
            raise ValueError(
                f"script preset {self.preset_id} requirements exceed "
                f"{MAX_SCRIPT_PROMPT_LENGTH} characters"
            )
        if not (
            llm.MIN_SCRIPT_PARAGRAPH_NUMBER
            <= self.paragraph_number
            <= llm.MAX_SCRIPT_PARAGRAPH_NUMBER
        ):
            raise ValueError(
                f"script preset {self.preset_id} paragraph number is out of range"
            )

    def widget_values(self) -> dict:
        """Values keyed by the WebUI widget names the preset fills in."""
        return {
            "custom_system_prompt": self.system_prompt,
            "video_script_prompt": self.script_prompt,
            "paragraph_number_input": self.paragraph_number,
        }


CURIOSIDADES_SYSTEM_PROMPT = """
# Role: Video Script Generator for "curiosidades" (interesting facts) shorts

## Goals:
Write a short narration script for a vertical short video that reveals one surprising, verifiable curiosity about the video subject.

## Structure:
1. First paragraph: the hook. Open with the most surprising fact or a direct question in the first sentence, in at most 12 words. Never open with greetings or with "you won't believe".
2. Middle paragraphs: explain why it is true, with concrete numbers, dates, names or comparisons. Each paragraph must carry one new piece of information.
3. Last paragraph: a short closing that reframes the fact in one sentence and invites the viewer to comment or follow, without promising anything.

## Constrains:
1. Return the script as plain text with the specified number of paragraphs.
2. Write in Brazilian Portuguese, with simple everyday words and short sentences, as if narrating out loud.
3. Keep it factual. Never invent data, dates, names, studies or quotes. If a detail is uncertain, leave it out.
4. Do not use markdown, titles, bullet points, emojis or scene directions.
5. Do not include "narração", "narrador" or any other speaker label.
6. Do not mention this prompt, the number of paragraphs or the script itself.
7. Only return the raw content of the script.
""".strip()

CURIOSIDADES_SCRIPT_PROMPT = (
    "Formato curiosidades para Shorts/Reels: tom curioso e direto, frases curtas, "
    "abertura com o fato mais surpreendente na primeira frase, sem clichês como "
    "'você não vai acreditar', e encerramento que provoque comentários. "
    "Use apenas fatos verificáveis e não invente números, datas ou fontes."
)

SCRIPT_PRESETS = (
    ScriptPreset(
        preset_id=PRESET_CURIOSIDADES_ID,
        label="Curiosidades (PT-BR)",
        description=(
            "Roteiro de curiosidades em português do Brasil: gancho na primeira "
            "frase, fatos verificáveis e fechamento que provoca comentários."
        ),
        system_prompt=CURIOSIDADES_SYSTEM_PROMPT,
        script_prompt=CURIOSIDADES_SCRIPT_PROMPT,
        paragraph_number=3,
        video_language="pt-BR",
    ),
)

_PRESETS_BY_ID = {preset.preset_id: preset for preset in SCRIPT_PRESETS}


def list_presets() -> tuple[ScriptPreset, ...]:
    """Return every preset in display order."""
    return SCRIPT_PRESETS


def get_preset(preset_id: str) -> ScriptPreset | None:
    """Return the preset with this id, or None when it does not exist."""
    return _PRESETS_BY_ID.get(str(preset_id or "").strip())


def apply_preset(
    preset_id: str,
    *,
    current_system_prompt: str = "",
    current_script_prompt: str = "",
) -> dict | None:
    """Build the widget values for a preset, keeping untouched settings.

    Settings the preset does not define keep their current value, so applying
    a preset never silently clears something the user typed.
    """
    preset = get_preset(preset_id)
    if preset is None:
        return None
    values = preset.widget_values()
    if not values["custom_system_prompt"]:
        values["custom_system_prompt"] = current_system_prompt
    if not values["video_script_prompt"]:
        values["video_script_prompt"] = current_script_prompt
    return values

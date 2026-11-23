import unittest

from app.services import llm, script_presets


class ScriptPresetsTest(unittest.TestCase):
    def test_curiosidades_preset_is_listed_and_translated_to_portuguese(self):
        preset = script_presets.get_preset(script_presets.PRESET_CURIOSIDADES_ID)

        self.assertIsNotNone(preset)
        self.assertIn(preset, script_presets.list_presets())
        self.assertIn("Portuguese", preset.system_prompt)
        self.assertIn("Curiosidades", preset.label)
        self.assertEqual(preset.video_language, "pt-BR")

    def test_preset_values_fit_the_webui_limits(self):
        for preset in script_presets.list_presets():
            self.assertLessEqual(
                len(preset.system_prompt), llm.MAX_SCRIPT_SYSTEM_PROMPT_LENGTH
            )
            self.assertLessEqual(
                len(preset.script_prompt), llm.MAX_SCRIPT_PROMPT_LENGTH
            )
            self.assertGreaterEqual(
                preset.paragraph_number, llm.MIN_SCRIPT_PARAGRAPH_NUMBER
            )
            self.assertLessEqual(
                preset.paragraph_number, llm.MAX_SCRIPT_PARAGRAPH_NUMBER
            )

    def test_widget_values_target_the_advanced_script_settings(self):
        preset = script_presets.get_preset(script_presets.PRESET_CURIOSIDADES_ID)

        values = preset.widget_values()

        self.assertEqual(
            set(values),
            {"custom_system_prompt", "video_script_prompt", "paragraph_number_input"},
        )
        self.assertEqual(values["custom_system_prompt"], preset.system_prompt)
        self.assertEqual(values["paragraph_number_input"], preset.paragraph_number)

    def test_prompt_built_from_preset_keeps_runtime_context(self):
        preset = script_presets.get_preset(script_presets.PRESET_CURIOSIDADES_ID)

        prompt = llm.build_script_prompt(
            video_subject="Por que o céu é azul",
            language="pt-BR",
            paragraph_number=preset.paragraph_number,
            video_script_prompt=preset.script_prompt,
            custom_system_prompt=preset.system_prompt,
        )

        self.assertIn("Por que o céu é azul", prompt)
        self.assertIn("language: pt-BR", prompt)
        self.assertIn(preset.script_prompt, prompt)

    def test_unknown_preset_is_ignored(self):
        self.assertIsNone(script_presets.get_preset("does-not-exist"))
        self.assertIsNone(script_presets.apply_preset("does-not-exist"))

    def test_apply_preset_keeps_settings_the_preset_does_not_define(self):
        values = script_presets.apply_preset(
            script_presets.PRESET_CURIOSIDADES_ID,
            current_script_prompt="manter este requisito",
        )

        self.assertEqual(values["video_script_prompt"], "manter este requisito")


if __name__ == "__main__":
    unittest.main()

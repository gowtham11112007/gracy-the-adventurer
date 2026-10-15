"""AI Model Providers for SpriteForge (Gemini image + Veo video)."""
from __future__ import annotations

import io
import time
from pathlib import Path
from typing import Optional
from PIL import Image

from google import genai
from google.genai import types

from tools.spriteforge.config import get_gemini_api_key, log_cost


class GeminiProvider:
    """Provider for Google Gemini API (Image generation/editing + Veo video generation)."""

    def __init__(
        self,
        image_model: str = "gemini-2.5-flash-image",
        video_model: str = "veo-3.1-fast-generate-preview",
    ):
        self.api_key = get_gemini_api_key()
        self.client = genai.Client(api_key=self.api_key)
        self.image_model = image_model
        self.video_model = video_model

    def generate_anchor(
        self,
        reference_path: Path,
        description: str,
        chroma: str = "#00FF00",
        dry_run: bool = False,
    ) -> Optional[Image.Image]:
        """Generate a full-body right-facing anchor on flat green background."""
        prompt = (
            f"You are creating a 2D game character anchor sprite on a flat chroma-key background.\n"
            f"Draw ONE full-body figure of this character, side view facing right, standing upright, centered horizontally, "
            f"feet near the bottom edge of the frame.\n"
            f"Background MUST BE flat pure green solid color {chroma} (#00FF00), completely uniform, no shadows on the ground, "
            f"no ground texture, no gradient, no extra objects, no text.\n"
            f"Maintain the EXACT character identity from the reference image: same face, hair style and color, skin tone, "
            f"clothing details and colors.\n"
            f"Description: {description}.\n"
            f"Art style: detailed, clean painterly illustration, grown-up adventure game aesthetic, high clarity, full body always in frame, feet fully visible."
        )

        estimated_cost = 0.04
        if dry_run:
            print(f"[DRY RUN] Would call {self.image_model} to generate anchor.")
            print(f"Estimated cost: ${estimated_cost:.4f} (or Free Tier quota)")
            return None

        print(f"Calling {self.image_model} to generate anchor image...")
        ref_image = Image.open(reference_path)
        
        # Multimodal content call requesting an image output
        response = self.client.models.generate_content(
            model=self.image_model,
            contents=[ref_image, prompt],
            config=types.GenerateContentConfig(
                response_modalities=["IMAGE"],
            ),
        )

        image_bytes = None
        for candidate in response.candidates:
            if candidate.content and candidate.content.parts:
                for part in candidate.content.parts:
                    if part.inline_data and part.inline_data.data:
                        image_bytes = part.inline_data.data
                        break
            if image_bytes:
                break

        if not image_bytes:
            raise RuntimeError(f"No image returned by {self.image_model}. Response: {response}")

        log_cost("character", "anchor", self.image_model, estimated_cost, "Anchor generated")
        return Image.open(io.BytesIO(image_bytes))

    def edit_anchor(
        self,
        base_anchor_path: Path,
        edit_instruction: str,
        chroma: str = "#00FF00",
        dry_run: bool = False,
    ) -> Optional[Image.Image]:
        """Create a character variant by editing an existing anchor image."""
        prompt = (
            f"Modify this character sprite according to the instruction, keeping everything else EXACTLY identical.\n"
            f"Instruction: {edit_instruction}.\n"
            f"Preserve the face, facial features, skin tone, hair style, body proportions, side-view facing right pose, "
            f"and the flat pure solid green background {chroma} (#00FF00).\n"
            f"Do not change the camera angle, do not add shadows, no background gradient."
        )

        estimated_cost = 0.04
        if dry_run:
            print(f"[DRY RUN] Would call {self.image_model} to edit anchor.")
            print(f"Estimated cost: ${estimated_cost:.4f} (or Free Tier quota)")
            return None

        print(f"Calling {self.image_model} to create outfit variant...")
        base_image = Image.open(base_anchor_path)
        response = self.client.models.generate_content(
            model=self.image_model,
            contents=[base_image, prompt],
            config=types.GenerateContentConfig(
                response_modalities=["IMAGE"],
            ),
        )

        image_bytes = None
        for candidate in response.candidates:
            if candidate.content and candidate.content.parts:
                for part in candidate.content.parts:
                    if part.inline_data and part.inline_data.data:
                        image_bytes = part.inline_data.data
                        break
            if image_bytes:
                break

        if not image_bytes:
            raise RuntimeError(f"No image returned by {self.image_model}. Response: {response}")

        log_cost("character", "variant", self.image_model, estimated_cost, edit_instruction)
        return Image.open(io.BytesIO(image_bytes))

    def generate_video(
        self,
        anchor_path: Path,
        action: str,
        action_context: str = "",
        chroma: str = "#00FF00",
        dry_run: bool = False,
    ) -> Optional[bytes]:
        """Generate action video from anchor using Veo."""
        # Field-tested action prompts
        action_prompts = {
            "run": "side view, she runs to the right on the spot, running in place, steady locked camera, flat solid green background, full body always in frame, no camera motion, no zoom, feet stay in frame",
            "walk": "side view, she walks to the right on the spot, walking in place, steady locked camera, flat solid green background, full body always in frame, no camera motion, no zoom, feet stay in frame",
            "idle": "side view facing right, standing still, frozen pose, feet glued to ground, no stepping, gentle subtle breathing motion, steady locked camera, flat solid green background, full body always in frame",
            "jump": "side view facing right, she jumps straight up into the air and lands back down on her feet, steady locked camera, flat solid green background, full body always in frame, no camera motion",
            "hurt": "side view facing right, knocked back slightly reacting to being hit, then settles, steady locked camera, flat solid green background, full body in frame",
            "victory": "side view facing right, cheerful celebration pose with arm raised, happy smile, steady locked camera, flat solid green background",
            "rope": "side view, she holds a vertical rope above her head with both hands, swinging gently back and forth, steady locked camera, flat solid green background",
        }

        base_prompt = action_prompts.get(action, f"side view facing right, she performs {action} on the spot, steady locked camera, flat solid green background, full body in frame")
        if action_context:
            base_prompt = f"{base_prompt}, {action_context}"

        estimated_cost = 0.50
        if dry_run:
            print(f"[DRY RUN] Would call {self.video_model} to generate video for action '{action}'.")
            print(f"Prompt: {base_prompt}")
            print(f"Estimated cost: ${estimated_cost:.4f} (or Free Tier quota)")
            return None

        print(f"Initiating video generation with {self.video_model} for action '{action}'...")
        input_image = types.Image.from_file(location=str(anchor_path))

        operation = self.client.models.generate_videos(
            model=self.video_model,
            prompt=base_prompt,
            image=input_image,
            config=types.GenerateVideosConfig(
                number_of_videos=1,
                aspect_ratio="16:9",
            ),
        )

        print("Video generation started. Polling for completion...")
        elapsed = 0
        while not operation.done:
            time.sleep(10)
            elapsed += 10
            operation = self.client.operations.get(operation=operation)
            print(f"  Waiting... ({elapsed}s elapsed)")

        if operation.error:
            raise RuntimeError(f"Video generation failed: {operation.error}")

        if not operation.response or not operation.response.generated_videos:
            raise RuntimeError("Operation finished but no video found in response.")

        generated_video = operation.response.generated_videos[0]
        # Download bytes
        video_bytes = self.client.files.download(file=generated_video.video)
        log_cost("character", action, self.video_model, estimated_cost, f"Action video {action} generated ({elapsed}s)")
        return video_bytes

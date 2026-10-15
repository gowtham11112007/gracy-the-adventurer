"""CLI interface for SpriteForge: anchor, animate, variant, repick, export."""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path
from PIL import Image

from tools.spriteforge.config import ROOT_DIR, RUNS_DIR
from tools.spriteforge.provider import GeminiProvider
from tools.spriteforge.chroma import extract_video_frames, process_frames_chroma
from tools.spriteforge.crop import align_and_crop_frames
from tools.spriteforge.cycle import find_cycle, trim_oneshot
from tools.spriteforge.pack import pack_strip, save_preview_gif, save_manifest
from tools.spriteforge.export import export_action_to_godot


def confirm_cost(amount_usd: float, action_desc: str, auto_yes: bool = False) -> bool:
    """Ask user before any paid API call."""
    if auto_yes:
        return True
    print(f"\n[COST NOTICE] Action: {action_desc}")
    print(f"Estimated cost: ${amount_usd:.2f} USD (or Free Tier daily quota).")
    choice = input(f"Spend about ${amount_usd:.2f}? (yes/no): ").strip().lower()
    return choice in ["y", "yes"]


def cmd_anchor(args: argparse.Namespace) -> None:
    """Generate or register anchor image for a character."""
    char_dir = RUNS_DIR / args.name
    char_dir.mkdir(parents=True, exist_ok=True)
    anchor_out = char_dir / "anchor.png"

    if anchor_out.exists() and not args.force:
        print(f"Anchor image already exists at {anchor_out}. Use --force to regenerate.")
        return

    ref_path = Path(args.ref)
    if not ref_path.is_absolute():
        ref_path = ROOT_DIR / ref_path
    if not ref_path.exists():
        print(f"Error: Reference image not found at {ref_path}", file=sys.stderr)
        sys.exit(1)

    if not args.dry_run and not confirm_cost(0.04, f"Generate anchor for {args.name}", args.yes):
        print("Cancelled.")
        return

    provider = GeminiProvider()
    anchor_img = provider.generate_anchor(
        reference_path=ref_path,
        description=args.describe,
        chroma=args.chroma,
        dry_run=args.dry_run,
    )

    if anchor_img:
        anchor_img.save(anchor_out)
        print(f"Saved anchor image to {anchor_out}")


def cmd_animate(args: argparse.Namespace) -> None:
    """Generate action video from anchor, extract frames, key chroma, and pack strip."""
    char_dir = RUNS_DIR / args.name
    action_dir = char_dir / args.action
    action_dir.mkdir(parents=True, exist_ok=True)
    
    raw_video_path = action_dir / "raw.mp4"
    anchor_path = char_dir / "anchor.png"

    # Step 1: Video generation or import
    if args.video:
        video_src = Path(args.video)
        if not video_src.is_absolute():
            video_src = ROOT_DIR / video_src
        if not video_src.exists():
            print(f"Error: Video file not found: {video_src}", file=sys.stderr)
            sys.exit(1)
        shutil.copy2(video_src, raw_video_path)
        print(f"Imported local video from {video_src} -> {raw_video_path}")
    elif not raw_video_path.exists() or args.force:
        if not anchor_path.exists():
            print(f"Error: Anchor image not found at {anchor_path}. Run anchor first.", file=sys.stderr)
            sys.exit(1)

        if not args.dry_run and not confirm_cost(0.50, f"Generate {args.action} animation video for {args.name}", args.yes):
            print("Cancelled.")
            return

        provider = GeminiProvider()
        video_bytes = provider.generate_video(
            anchor_path=anchor_path,
            action=args.action,
            action_context=args.context or "",
            chroma=args.chroma,
            dry_run=args.dry_run,
        )
        if args.dry_run:
            return
        if video_bytes:
            with open(raw_video_path, "wb") as f:
                f.write(video_bytes)
            print(f"Saved raw video to {raw_video_path}")
    else:
        print(f"Using cached raw video at {raw_video_path}")

    # Step 2: Extract raw frames
    raw_frames_dir = action_dir / "frames_raw"
    keyed_frames_dir = action_dir / "frames_keyed"
    print(f"Extracting frames at {args.fps} fps...")
    raw_frames = extract_video_frames(raw_video_path, raw_frames_dir, fps=args.fps)
    print(f"Extracted {len(raw_frames)} frames.")

    # Step 3: Chroma key & despill
    print("Applying chroma key removal and green despill...")
    keyed_frame_paths = process_frames_chroma(raw_frames, keyed_frames_dir)

    # Step 4: Loop detection or oneshot trimming
    keyed_images = [Image.open(p) for p in keyed_frame_paths]
    if args.action in ["run", "walk", "idle"]:
        start_idx, length = find_cycle(keyed_images, action=args.action)
        print(f"Detected loop cycle: frames {start_idx} to {start_idx + length - 1} ({length} frames).")
        chosen_frames = keyed_images[start_idx : start_idx + length]
    else:
        start_idx, length = trim_oneshot(keyed_images)
        print(f"Trimmed one-shot: frames {start_idx} to {start_idx + length - 1} ({length} frames).")
        chosen_frames = keyed_images[start_idx : start_idx + length]

    # Step 5: Uniform bounding box alignment
    print("Aligning and cropping frames to uniform baseline...")
    aligned_frames, cell_w, cell_h = align_and_crop_frames(chosen_frames)

    # Step 6: Pack strip, preview GIF, and manifest
    strip = pack_strip(aligned_frames, cell_w, cell_h)
    strip_path = action_dir / "strip.png"
    strip.save(strip_path)
    print(f"Packed strip saved to {strip_path} ({cell_w}x{cell_h} per cell, {len(aligned_frames)} cells).")

    preview_gif_path = action_dir / "preview.gif"
    save_preview_gif(aligned_frames, preview_gif_path, fps=args.fps)
    print(f"Preview GIF saved to {preview_gif_path}")

    manifest_data = {
        "character": args.name,
        "action": args.action,
        "frameWidth": cell_w,
        "frameHeight": cell_h,
        "frames": len(aligned_frames),
        "fps": args.fps,
        "loopStart": start_idx,
        "loopLength": length,
    }
    manifest_path = action_dir / "manifest.json"
    save_manifest(manifest_path, manifest_data)
    print(f"Manifest saved to {manifest_path}")


def cmd_variant(args: argparse.Namespace) -> None:
    """Create a character variant (outfit swap) by editing an anchor."""
    char_dir = RUNS_DIR / args.name
    base_anchor = char_dir / "anchor.png"
    if not base_anchor.exists():
        print(f"Error: Base anchor not found at {base_anchor}", file=sys.stderr)
        sys.exit(1)

    variant_dir = RUNS_DIR / f"{args.name}_{args.outfit}"
    variant_dir.mkdir(parents=True, exist_ok=True)
    out_anchor = variant_dir / "anchor.png"

    if not args.dry_run and not confirm_cost(0.04, f"Create variant outfit '{args.outfit}' for {args.name}", args.yes):
        print("Cancelled.")
        return

    provider = GeminiProvider()
    variant_img = provider.edit_anchor(
        base_anchor_path=base_anchor,
        edit_instruction=args.edit,
        chroma=args.chroma,
        dry_run=args.dry_run,
    )

    if variant_img:
        variant_img.save(out_anchor)
        print(f"Saved variant anchor to {out_anchor}")


def cmd_repick(args: argparse.Namespace) -> None:
    """Re-pick specific frames from existing extracted video without calling AI (100% Free)."""
    action_dir = RUNS_DIR / args.name / args.action
    keyed_dir = action_dir / "frames_keyed"
    if not keyed_dir.exists():
        print(f"Error: Keyed frames directory not found: {keyed_dir}", file=sys.stderr)
        sys.exit(1)

    all_frame_files = sorted(keyed_dir.glob("frame_*.png"))
    if not all_frame_files:
        print(f"Error: No frames found in {keyed_dir}", file=sys.stderr)
        sys.exit(1)

    # Parse --frames e.g. "4-27"
    if "-" in args.frames:
        start_str, end_str = args.frames.split("-", 1)
        start_idx = int(start_str)
        end_idx = int(end_str)
    else:
        start_idx = int(args.frames)
        end_idx = start_idx + 1

    selected_files = all_frame_files[start_idx : end_idx + 1]
    if not selected_files:
        print(f"Error: Selected range {start_idx}-{end_idx} out of range (total {len(all_frame_files)})", file=sys.stderr)
        sys.exit(1)

    print(f"Re-picking {len(selected_files)} frames ({start_idx} to {end_idx}) at {args.fps} fps...")
    selected_images = [Image.open(p) for p in selected_files]
    aligned_frames, cell_w, cell_h = align_and_crop_frames(selected_images)

    strip = pack_strip(aligned_frames, cell_w, cell_h)
    strip.save(action_dir / "strip.png")

    save_preview_gif(aligned_frames, action_dir / "preview.gif", fps=args.fps)

    manifest_data = {
        "character": args.name,
        "action": args.action,
        "frameWidth": cell_w,
        "frameHeight": cell_h,
        "frames": len(aligned_frames),
        "fps": args.fps,
        "repicked": True,
        "range": [start_idx, end_idx],
    }
    save_manifest(action_dir / "manifest.json", manifest_data)
    print(f"Updated strip and preview at {action_dir}")


def cmd_export(args: argparse.Namespace) -> None:
    """Export processed sprite strip into Godot assets and update hero2.json."""
    # Find all actions under this character or default to "run"
    char_dir = RUNS_DIR / args.name
    actions = [d.name for d in char_dir.iterdir() if d.is_dir() and (d / "strip.png").exists()]
    if not actions:
        print(f"No processed actions found in {char_dir}", file=sys.stderr)
        sys.exit(1)

    for action in actions:
        export_action_to_godot(
            character=args.name,
            outfit=args.outfit,
            action=action,
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="SpriteForge: 2D Sprite Generator for Gracy the Adventurer")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # anchor
    p_anchor = subparsers.add_parser("anchor", help="Generate or set anchor character image")
    p_anchor.add_argument("--name", required=True, help="Character name (e.g. janani)")
    p_anchor.add_argument("--ref", required=True, help="Reference image path")
    p_anchor.add_argument("--describe", default="Indian girl hero wearing white kurti", help="Character description")
    p_anchor.add_argument("--chroma", default="#00FF00", help="Chroma background color")
    p_anchor.add_argument("--force", action="store_true", help="Regenerate even if cached")
    p_anchor.add_argument("--dry-run", action="store_true", help="Show cost without calling API")
    p_anchor.add_argument("-y", "--yes", action="store_true", help="Skip confirmation prompt")

    # animate
    p_anim = subparsers.add_parser("animate", help="Generate animation video and frames")
    p_anim.add_argument("--name", required=True, help="Character name")
    p_anim.add_argument("--action", required=True, choices=["run", "walk", "jump", "idle", "hurt", "victory", "rope"], help="Action to animate")
    p_anim.add_argument("--context", default="", help="Extra context description for the action motion")
    p_anim.add_argument("--fps", type=int, default=24, help="Frames per second")
    p_anim.add_argument("--chroma", default="#00FF00", help="Chroma color")
    p_anim.add_argument("--video", default=None, help="Import a pre-downloaded video MP4 file (Free)")
    p_anim.add_argument("--force", action="store_true", help="Regenerate even if cached")
    p_anim.add_argument("--dry-run", action="store_true", help="Show cost without calling API")
    p_anim.add_argument("-y", "--yes", action="store_true", help="Skip confirmation prompt")

    # variant
    p_var = subparsers.add_parser("variant", help="Generate outfit variant by editing anchor")
    p_var.add_argument("--name", required=True, help="Character name")
    p_var.add_argument("--outfit", required=True, help="New outfit name (e.g. black)")
    p_var.add_argument("--edit", required=True, help="Edit instruction")
    p_var.add_argument("--chroma", default="#00FF00", help="Chroma color")
    p_var.add_argument("--dry-run", action="store_true", help="Show cost without calling API")
    p_var.add_argument("-y", "--yes", action="store_true", help="Skip confirmation prompt")

    # repick
    p_rep = subparsers.add_parser("repick", help="Re-pick frames from existing video (Free)")
    p_rep.add_argument("--name", required=True, help="Character name")
    p_rep.add_argument("--action", required=True, help="Action name")
    p_rep.add_argument("--frames", required=True, help="Frame range (e.g. 4-27)")
    p_rep.add_argument("--fps", type=int, default=24, help="Target frames per second")

    # export
    p_exp = subparsers.add_parser("export", help="Export processed strips into Godot assets")
    p_exp.add_argument("--name", required=True, help="Character name")
    p_exp.add_argument("--outfit", default="kurti", help="Outfit name (default: kurti)")

    args = parser.parse_args()

    if args.command == "anchor":
        cmd_anchor(args)
    elif args.command == "animate":
        cmd_animate(args)
    elif args.command == "variant":
        cmd_variant(args)
    elif args.command == "repick":
        cmd_repick(args)
    elif args.command == "export":
        cmd_export(args)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
convert_deepfilternet3.py — One-time developer tool for SonicMerge Phase 3.

Converts DeepFilterNet3 from the deepfilternet Python package to a Core ML
.mlpackage suitable for on-device inference on iOS 17+.

CRITICAL: minimum_deployment_target=iOS17 — MLState requires iOS 18+.
This script exports RNN hidden states as explicit tensor I/O instead.
After conversion, inspect DeepFilterNet3.swift (Xcode auto-generates it)
to verify exact input/output property names before coding NoiseReductionService.
See: apple.github.io/coremltools/docs-guides/source/stateful-models.html

Usage:
    cd /path/to/SonicMerge
    python scripts/convert_deepfilternet3.py

Output:
    SonicMerge/Resources/DeepFilterNet3.mlpackage (~4.2 MB with FLOAT16)
"""

import sys
import os

# ---------------------------------------------------------------------------
# Install guard — fail fast with clear instructions if dependencies are absent
# ---------------------------------------------------------------------------

def _check_imports():
    missing = []
    try:
        import coremltools  # noqa: F401
    except ImportError:
        missing.append("coremltools")
    try:
        import torch  # noqa: F401
    except ImportError:
        missing.append("torch")
    try:
        import df  # noqa: F401  (deepfilternet package)
    except ImportError:
        missing.append("deepfilternet")

    if missing:
        print("ERROR: Missing required Python packages:", ", ".join(missing))
        print()
        print("Install with:")
        print("    pip install coremltools deepfilternet torch")
        print()
        print("Then re-run:")
        print("    python scripts/convert_deepfilternet3.py")
        sys.exit(1)

_check_imports()

import coremltools as ct
import torch
import torch.nn as nn
import numpy as np
from df.enhance import init_df, enhance
from df.model import ModelParams


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "..", "SonicMerge", "Resources", "DeepFilterNet3.mlpackage")
OUTPUT_PATH = os.path.normpath(OUTPUT_PATH)

# DeepFilterNet3 audio parameters (48 kHz, 480-sample frames = 10 ms)
SAMPLE_RATE = 48000
HOP_SIZE = 480         # samples per frame at 48 kHz
N_FFT = 960
N_FREQS = N_FFT // 2 + 1  # 481

print("=" * 60)
print("DeepFilterNet3 → Core ML Conversion")
print("Deployment target: iOS 17+ (explicit RNN state I/O)")
print("=" * 60)
print()

# ---------------------------------------------------------------------------
# Step 1: Load DeepFilterNet3
# ---------------------------------------------------------------------------

print("Step 1: Loading DeepFilterNet3 model from deepfilternet package...")
model, df_state, _ = init_df()
model.eval()
print(f"  Model loaded. Sample rate: {df_state.sr()} Hz")
print(f"  Frame size: {df_state.hop_size()} samples ({df_state.hop_size() / df_state.sr() * 1000:.0f} ms)")
print()

# ---------------------------------------------------------------------------
# Step 2: Trace the model with example inputs
# ---------------------------------------------------------------------------
# DeepFilterNet3 processes complex spectrogram frames. We trace with a sample
# input matching shape [batch=1, channels=2, freq=N_FREQS] for the ERB + DF sub-models.
# Adjust shapes here if df.model.ModelParams reveals different tensor layouts.

print("Step 2: Tracing model with torch.jit.trace...")
print("  NOTE: If trace fails, inspect df.model.ModelParams for exact input shapes.")

# Example input: one 480-sample stereo frame → STFT → complex spectrogram
example_noisy_frame = torch.randn(1, 2, HOP_SIZE)  # [batch, channels, samples]

with torch.no_grad():
    try:
        traced = torch.jit.trace(model, example_noisy_frame, strict=False)
        print("  Trace succeeded.")
    except Exception as e:
        print(f"  Trace failed: {e}")
        print()
        print("  The DeepFilterNet3 architecture may require a custom wrapper to expose")
        print("  RNN hidden states as explicit inputs/outputs. See the SonicMerge research")
        print("  notes in .planning/phases/03-ai-denoising-pipeline/03-RESEARCH.md.")
        print()
        print("  Typical fix: wrap the model to accept (noisy_frame, h_enc, h_df) and")
        print("  return (clean_frame, h_enc_out, h_df_out) as explicit tensors.")
        sys.exit(1)

print()

# ---------------------------------------------------------------------------
# Step 3: Convert to Core ML — iOS 17, FLOAT16, explicit RNN state tensors
# ---------------------------------------------------------------------------
# CRITICAL: Do NOT use ct.State for hidden states — MLState requires iOS 18+.
# Export hidden states as regular ct.TensorType inputs/outputs so they can be
# managed manually in Swift (read output → feed back as input on next frame).

print("Step 3: Converting to Core ML (minimum_deployment_target=iOS17, FLOAT16)...")

mlmodel = ct.convert(
    traced,
    inputs=[
        ct.TensorType(name="noisyFrame", shape=example_noisy_frame.shape, dtype=float)
        # If the model has explicit RNN state inputs, add them here, e.g.:
        # ct.TensorType(name="hiddenStateEnc", shape=[1, 256, 1], dtype=float),
        # ct.TensorType(name="hiddenStateDf",  shape=[1, 64,  1], dtype=float),
    ],
    # Do NOT set outputs=[ct.State(...)]; use ct.TensorType for hidden state outputs.
    minimum_deployment_target=ct.target.iOS17,   # Prevents MLState generation
    compute_precision=ct.precision.FLOAT16,       # Targets ~4.2 MB bundle size
)

print("  Conversion complete.")
print()

# ---------------------------------------------------------------------------
# Step 4: Print input/output spec for NoiseReductionService implementation
# ---------------------------------------------------------------------------

print("Step 4: Model input/output description (copy exact names to NoiseReductionService.swift):")
print("-" * 60)
spec = mlmodel.get_spec()
for inp in spec.description.input:
    shape = list(inp.type.multiArrayType.shape)
    print(f"  INPUT  '{inp.name}': {shape}")
for out in spec.description.output:
    shape = list(out.type.multiArrayType.shape)
    print(f"  OUTPUT '{out.name}': {shape}")
print("-" * 60)
print()
print("  Use these exact names in NoiseReductionService.swift:")
print("    model.input.<inputName> = ...")
print("    let cleanFrame = model.output.<outputName>")
print()

# ---------------------------------------------------------------------------
# Step 5: Save .mlpackage
# ---------------------------------------------------------------------------

print(f"Step 5: Saving to {OUTPUT_PATH} ...")
os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
mlmodel.save(OUTPUT_PATH)

size_mb = sum(
    os.path.getsize(os.path.join(dp, f))
    for dp, _, files in os.walk(OUTPUT_PATH)
    for f in files
) / (1024 * 1024)

print(f"  Saved. Package size: {size_mb:.1f} MB")
if size_mb > 10:
    print("  WARNING: Package exceeds 10 MB. Verify FLOAT16 precision was applied.")
    print("  If >10 MB, re-run with explicit compute_precision=ct.precision.FLOAT16.")
print()
print("=" * 60)
print("Conversion complete.")
print()
print("Next steps:")
print("  1. In Xcode: File > Add Files to 'SonicMerge'")
print(f"     Select: {OUTPUT_PATH}")
print("     Ensure 'Add to target: SonicMerge' AND 'SonicMergeTests' are checked.")
print()
print("  2. Open the auto-generated DeepFilterNet3.swift in Xcode.")
print("     Note the exact property names printed above for NoiseReductionService.")
print()
print("  3. See docs/DENOISING_SETUP.md for complete setup instructions.")
print("=" * 60)

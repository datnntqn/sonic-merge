# Denoising Setup — Developer Prerequisite

Before executing Wave 1+ of Phase 3, the developer must convert DeepFilterNet3 to a
Core ML .mlpackage and add it to the Xcode project. This is a one-time step.

## Prerequisites

- Python 3.9+ with pip
- macOS (coremltools requires macOS for .mlpackage generation)
- ~2 GB disk space for PyTorch model download

## Steps

### 1. Install Python dependencies

    pip install coremltools deepfilternet torch

### 2. Run the conversion script

    cd /path/to/SonicMerge
    python scripts/convert_deepfilternet3.py

The script outputs DeepFilterNet3.mlpackage to SonicMerge/Resources/.

### 3. Add to Xcode project

- In Xcode: File > Add Files to "SonicMerge"
- Select SonicMerge/Resources/DeepFilterNet3.mlpackage
- Ensure "Add to target: SonicMerge" is checked
- Also add to SonicMergeTests target for unit test access

### 4. Verify tensor names

Xcode auto-generates SonicMerge/DeepFilterNet3.swift from the .mlpackage.
Open this file and note the exact property names for:
- Input frame tensor (shape [1, 2, 480])
- Input hidden state tensor(s)
- Output frame tensor (shape [1, 2, 480])
- Output hidden state tensor(s)

Update NoiseReductionService.swift with these exact names.

### 5. iOS 17 Constraint

The model is converted with explicit RNN state I/O (NOT MLState).
MLState requires iOS 18+. Our deployment target is iOS 17+.
This is handled automatically by the conversion script.

## Troubleshooting

- "MLModelError" on iOS 17 device: verify minimum_deployment_target=iOS17 was used
- Build error "no such module 'DeepFilterNet3'": ensure .mlpackage is added to both targets
- Model too large (>10 MB): verify FLOAT16 precision was used (not FLOAT32)
- Trace fails with shape mismatch: inspect `df.model.ModelParams` for actual input shapes
  and update the `example_noisy_frame` tensor in the script accordingly

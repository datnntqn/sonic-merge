SonicMerge — sample audio for Simulator / device testing
========================================================

Folder (relative to repo root):
  SimulatorSampleAudio/

Files (generated + fixtures):
  - sample_A_440Hz_mono.wav      — 2.5s, mono, 440 Hz tone (merge order test)
  - sample_B_523Hz_stereo.wav  — 2.5s, stereo, ~C5 tone
  - sample_C_659Hz_mono.wav    — 2.0s, mono, ~E5 tone
  - sample_B_stereo.m4a / sample_C_659Hz_mono.m4a — .m4a copies via afconvert
  - stereo_48000.m4a, aac_22050.aac — unit-test fixtures (short AAC)
  - fixture_mono_1s_440Hz.wav — 1s mono (from test bundle)
  - stereo_-24lufs_48000.wav    — louder stereo WAV for level tests

Regenerate the sine-wave WAVs (optional):
  From repo root:
    swift scripts/GenerateSimulatorSampleAudio.swift

How to use on iPhone Simulator (e.g. iPhone 17 Pro Max):
  1. Xcode > Open Developer Tool > Simulator
  2. File > Open Simulator > choose "iPhone 17 Pro Max" (or any runtime you use with Xcode 26+)
  3. Drag files from Finder onto the Simulator window (home screen or inside Files)
  4. In SonicMerge, tap Import or drag onto the app window if supported

Note: All tones are programmatic sine waves produced locally (no third-party copyrighted material).

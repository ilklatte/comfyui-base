## What is in this template

This is a general-purpose ComfyUI template. It starts ComfyUI Manager and
JupyterLab but intentionally downloads no model family by default.

Add models with Hugging Face, CivitAI, JupyterLab, or a network volume. Models,
inputs, outputs, and user settings remain under `/workspace/ComfyUI` when a
RunPod network volume is mounted.

## Services

- ComfyUI: port `8188`
- JupyterLab: port `8888`

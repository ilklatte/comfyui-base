# General ComfyUI RunPod template

This repository builds directly from NVIDIA CUDA 12.8 and is both a deployable
general ComfyUI template and the parent image for `comfyui-wan`. It installs
Python 3.12, PyTorch cu128, ComfyUI, ComfyUI Manager, JupyterLab, the shared
Hugging Face/CivitAI runtime tooling, a root tmux environment, and a pinned
general-purpose custom-node suite. It downloads no model family by default.

The boot, model-download, persistence, and reporting logic still comes from
`Hearmeman24/comfyui-runtime`; only the previous prebuilt base-image dependency
has been removed.

## Before publishing

1. Create a public Git repository and replace `template_repo` in `template.json`.
2. Add GitHub repository variable `TEMPLATE_REPOSITORY_URL` with the same URL.
3. Add repository variable `DOCKER_IMAGE` with an `owner/repository` Docker Hub image name.
4. Add Actions secrets `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, and `RUNPOD_API_KEY`.
5. Add repository variable `RUNPOD_TEMPLATE_IDS` only after creating the target RunPod template.
6. Push a release tag such as `r1`. The workflow publishes the immutable image
   tag `cuda12.8.1-torch2.11.0-comfyui0.36.0-python3.12-r1` and also advances
   the rolling `latest` tag. RunPod uses the immutable `rN` tag.

Publish this image before building `comfyui-wan`. The Wan repository must pin
the resulting immutable, version-qualified image in its `pins.json`.

RunPod should expose TCP ports `8188` and `8888` and mount its network volume
at `/workspace`.

## Terminal environment

`tmux`, Oh My Tmux, and TPM are installed for the root user. TPM already has
`tmux-sensible`, `tmux-resurrect`, and `tmux-continuum`; Oh My Tmux performs
the TPM integration, so `.tmux.conf.local` intentionally has no manual TPM
initializer. Continuum saves restorable session metadata under
`/workspace/.tmux/resurrect`. It cannot restore terminated processes.

## Baked custom nodes

The image contains pinned builds of rgthree, KJNodes, Impact Pack,
VideoHelperSuite, Easy-Use, ControlNet Aux, Custom Scripts, Essentials,
LayerStyle, Frame Interpolation, GGUF, Segment Anything 2, and WAS Node Suite.
They are not cloned again during pod startup. A version update requires a new
image tag.

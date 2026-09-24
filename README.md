# General ComfyUI RunPod template

This repository builds directly from NVIDIA CUDA 12.8 and is both a deployable
general ComfyUI template and the parent image for `comfyui-wan`. It installs
Python 3.12, PyTorch cu128, ComfyUI, ComfyUI Manager, JupyterLab, the shared
Hugging Face/CivitAI runtime tooling, a root tmux environment, and a pinned
general-purpose custom-node suite. It downloads no model family by default.

The image owns the CUDA 12 ONNX Runtime selection in `ort/cu128.txt`. Node
requirements may temporarily install either ONNX Runtime distribution during
the build, but the final image contains only the pinned GPU package and must
expose `CUDAExecutionProvider`. The same requirement is retained inside the
image at `/ort-requirement.txt` as the Base-owned version record. The
Base-owned runtime also keeps a defensive startup-time CUDA-provider repair.

The final Python 3.12 numerical stack is pinned in `numeric/py312.txt` at
NumPy 2.5.3, SciPy 1.16.3, and CuPy CUDA 12.x 13.6.0. These pins are merged
with the Torch pins into `/base-constraint.txt`, so custom-node installers
cannot silently move the shared numerical or Torch stack. The versions are
reinstalled after all custom-node dependencies, checked with `pip check`, and
must import ComfyUI's SciPy integration and sparse paths during the image
build.

SageAttention is built during the image build from the official
`thu-ml/SageAttention` repository at the immutable commit declared by
`SAGE_ATTENTION_REF`. The locally maintained per-extension architecture patch
is under `sage/`; no prebuilt wheel is downloaded from another template
maintainer.

The boot, JupyterLab, model-download, persistence, SageAttention probing,
ComfyUI liveness, and log-reporting code is maintained in this repository
under `runtime/` and baked into `/opt/comfyui-runtime`. Pods do not clone or
execute an external runtime repository. The initial implementation was adapted
from the upstream revision recorded in `runtime/UPSTREAM_REVISION`; its
AGPL-3.0 license and CivitAI downloader notices are retained there.

Deployment reports are written to the pod log only. The runtime does not add
welcome, model-help, or troubleshooting notes to the user's workflow list and
removes the three exact note files produced by the former external runtime.

## CI setup and publishing

CircleCI is the automatic publisher. GitHub Actions remains available as a
manual fallback and uses the GitHub-hosted runner's Docker Buildx; this project
does not use Docker Build Cloud.

1. Create a public Git repository and replace `template_repo` in `template.json`.
2. In CircleCI, authorize the GitHub organization, open **Organization > Projects**,
   select this repository, and choose the existing `.circleci/config.yml`.
3. Open **Project Settings > Environment Variables** and add each variable
   separately, without quotes or leading/trailing whitespace:

   | Variable | Value |
   | --- | --- |
   | `DOCKER_IMAGE` | `coohh88/comfyui-base` |
   | `TEMPLATE_REPOSITORY_URL` | `https://github.com/ilklatte/comfyui-base.git` |
   | `DOCKERHUB_USERNAME` | Docker Hub account name |
   | `DOCKERHUB_TOKEN` | Docker Hub personal access token with Read & Write permission |

4. Do not configure `RUNPOD_API_KEY` or `RUNPOD_TEMPLATE_IDS` for this project.
   The Base pipeline publishes an image but never updates a RunPod template.
5. Keep `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` in GitHub Actions secrets,
   plus `DOCKER_IMAGE` and `TEMPLATE_REPOSITORY_URL` in GitHub repository
   variables, for the manual fallback workflow.
6. Push a release tag such as `r1`. CircleCI publishes the immutable image
   tag `cuda12.8.1-torch2.11.0-comfyui0.36.0-python3.12-r1` and also advances
   the rolling `latest` tag.
7. To use the fallback, open **GitHub Actions > Verify and publish Docker image >
   Run workflow**, enter an existing `rN` tag, and run it manually.

Create the Docker Hub token under **Docker Hub > Account Settings > Personal
access tokens > Generate new token**. After CircleCI has published successfully,
the obsolete `DOCKER_BUILD_CLOUD_ENDPOINT` GitHub variable can be removed.

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

# Base-owned ComfyUI runtime

This directory contains the runtime used by `coohh88/comfyui-base` and images
derived from it. It is copied into `/opt/comfyui-runtime` during the image
build, so pods never download or execute a mutable external runtime checkout.

The initial implementation was adapted from
`Hearmeman24/comfyui-runtime` commit
`995442a9cacb1176b6e6b4d1ea1f79ca7a73e0ce` under AGPL-3.0. See `LICENSE`.
The bundled CivitAI downloader retains its own notice and provenance under
`vendor/civitai_downloader`.

Local changes include:

- the runtime is loaded from `/opt/comfyui-runtime`;
- the shared runtime node list is empty because common nodes are image-baked;
- deployment reports remain in the pod log but no Markdown-note workflows are
  written into the user's ComfyUI workflow directory.

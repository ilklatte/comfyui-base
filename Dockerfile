# syntax=docker/dockerfile:1
ARG CUDA_BASE_IMAGE=nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
FROM ${CUDA_BASE_IMAGE}

ARG TEMPLATE_REPOSITORY_URL=https://github.com/ilklatte/comfyui-base.git
ARG COMFYUI_REF=3dd559d81f745747cab884a3b9f5fd8867d79efe
ENV TEMPLATE_REPOSITORY_URL=${TEMPLATE_REPOSITORY_URL} \
    TERM=xterm-256color \
    DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8 \
    HF_XET_HIGH_PERFORMANCE=1

# Build the complete ComfyUI foundation directly from NVIDIA's CUDA 12.8
# image. This repository no longer extends a third-party ComfyUI base image.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        python3.12 python3.12-venv python3.12-dev python3-pip \
        curl ffmpeg ninja-build git aria2 git-lfs wget vim tmux perl \
        libgl1 libgles2 libegl1 libglib2.0-0 build-essential gcc \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && python3.12 -m venv /opt/venv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/venv/bin:$PATH"

COPY torch/cu128.txt /torch-trio.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r /torch-trio.txt \
    && pip freeze | grep -E "^(torch|torchvision|torchaudio|torchsde)==" > /torch-constraint.txt

ENV PIP_CONSTRAINT=/torch-constraint.txt \
    ORT_INDEX_ARGS="--index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/"

# Keep the CUDA-12 ONNX Runtime choice in a reusable, pinned requirement.
# The file remains in the final image as the Base-owned version record; the
# external runtime keeps its own defensive CUDA-provider check at pod startup.
COPY ort/cu128.txt /ort-requirement.txt
COPY numeric/py312.txt /numeric-requirement.txt

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install packaging setuptools wheel \
        pyyaml gdown triton jupyterlab jupyterlab-lsp \
        jupyter-server jupyter-server-terminals ipykernel \
        jupyterlab_code_formatter huggingface_hub hf_xet opencv-python

# Pin ComfyUI and Manager to immutable commits. Keep a full branch/tag
# refspec after the shallow bootstrap so the shared runtime can update or
# restore ComfyUI later.
RUN --mount=type=cache,target=/root/.cache/pip \
    git init /ComfyUI \
    && git -C /ComfyUI remote add origin https://github.com/comfyanonymous/ComfyUI.git \
    && git -C /ComfyUI fetch --depth=1 origin ${COMFYUI_REF} \
    && git -C /ComfyUI checkout --detach FETCH_HEAD \
    && test "$(git -C /ComfyUI rev-parse HEAD)" = "${COMFYUI_REF}" \
    && git -C /ComfyUI config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*' \
    && git -C /ComfyUI config --add remote.origin.fetch '+refs/tags/*:refs/tags/*' \
    && git -C /ComfyUI rev-parse HEAD > /comfyui-approved-ref \
    && pip install -r /ComfyUI/requirements.txt \
    && git init /ComfyUI/custom_nodes/comfyui-manager \
    && git -C /ComfyUI/custom_nodes/comfyui-manager remote add origin https://github.com/ltdrdata/ComfyUI-Manager.git \
    && git -C /ComfyUI/custom_nodes/comfyui-manager fetch --depth=1 origin 1698958286f487d6281920d2bfbe18beeb5eb85f \
    && git -C /ComfyUI/custom_nodes/comfyui-manager checkout --detach FETCH_HEAD \
    && test "$(git -C /ComfyUI/custom_nodes/comfyui-manager rev-parse HEAD)" = 1698958286f487d6281920d2bfbe18beeb5eb85f \
    && if [ -f /ComfyUI/custom_nodes/comfyui-manager/requirements.txt ]; then pip install -r /ComfyUI/custom_nodes/comfyui-manager/requirements.txt; fi

# Keep the existing shared runtime's CUDA 12.8 SageAttention artifact. The
# runtime probes the real GPU at boot and falls back safely on unsupported
# architectures.
ADD --checksum=sha256:487aeccc76236043c06154dfac34626692af25f520a3634c71d0bf160ab27ed6 \
    https://github.com/Hearmeman24/comfyui-runtime/releases/download/sage-d1a57a5-cu128-torch2.11.0/sageattention-2.2.0-cp312-cp312-linux_x86_64.whl \
    /opt/sage/cu128/
RUN python3 -c "import torch; v = torch.version.cuda; assert v and v.split('.')[0] == '12', v; print('torch', torch.__version__, 'cuda', v)" \
    && pip install --no-deps /opt/sage/cu128/sageattention-*.whl \
    && python3 -c "import sageattention; print('sageattention import OK')"

# Root is the interactive user in RunPod. Install tmux, Oh My Tmux, TPM, and
# the selected plugins into /root. Every Git checkout is pinned to an exact
# commit so a rebuild cannot silently change the terminal environment.
RUN set -eu; \
    clone_at() { \
        repo="$1"; dest="$2"; ref="$3"; \
        git init "$dest"; \
        git -C "$dest" remote add origin "$repo"; \
        git -C "$dest" fetch --depth=1 origin "$ref"; \
        git -C "$dest" checkout --detach FETCH_HEAD; \
        test "$(git -C "$dest" rev-parse HEAD)" = "$ref"; \
    }; \
    clone_at https://github.com/gpakosz/.tmux.git /root/.tmux 58a3dcc0d718ec0fa1c0d5a2fddd640a1ad7a5b7; \
    mkdir -p /root/.tmux/plugins; \
    clone_at https://github.com/tmux-plugins/tpm.git /root/.tmux/plugins/tpm e261deb1b47614eed3400089ce7197dc68acc4eb; \
    clone_at https://github.com/tmux-plugins/tmux-sensible.git /root/.tmux/plugins/tmux-sensible 25cb91f42d020f675bb0a2ce3fbd3a5d96119efa; \
    clone_at https://github.com/tmux-plugins/tmux-resurrect.git /root/.tmux/plugins/tmux-resurrect cff343cf9e81983d3da0c8562b01616f12e8d548; \
    clone_at https://github.com/tmux-plugins/tmux-continuum.git /root/.tmux/plugins/tmux-continuum 0698e8f4b17d6454c71bf5212895ec055c578da0; \
    ln -s /root/.tmux/.tmux.conf /root/.tmux.conf; \
    tmux -V

COPY src/tmux.conf.local /root/.tmux.conf.local

# General-purpose node suite. These packs are image-baked rather than listed
# in template.json, so boot never clones or replaces them. Install scripts run
# from their own directories because several packs use relative paths.
# Impact Pack pulls SAM2 from Git. Requirements installs disable PEP 517
# isolation so SAM2 reuses the installed CUDA Torch instead of asking the
# default PyPI index for the constrained +cu128 build.
RUN --mount=type=cache,target=/root/.cache/pip \
    set -eu; \
    clone_at() { \
        repo="$1"; dest="$2"; ref="$3"; \
        git init "$dest"; \
        git -C "$dest" remote add origin "$repo"; \
        git -C "$dest" fetch --depth=1 origin "$ref"; \
        git -C "$dest" checkout --detach FETCH_HEAD; \
        test "$(git -C "$dest" rev-parse HEAD)" = "$ref"; \
    }; \
    clone_at https://github.com/rgthree/rgthree-comfy.git /ComfyUI/custom_nodes/rgthree-comfy 2c5342a8cb0eaecaabf61435a5f37dd594c510ba; \
    clone_at https://github.com/kijai/ComfyUI-KJNodes.git /ComfyUI/custom_nodes/ComfyUI-KJNodes d3cfe21625e5170126ce06fbfcfe1d88108688c3; \
    clone_at https://github.com/ltdrdata/ComfyUI-Impact-Pack.git /ComfyUI/custom_nodes/ComfyUI-Impact-Pack 429d0159ad429e64d2b3916e6e7be9c22d025c3c; \
    clone_at https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git /ComfyUI/custom_nodes/ComfyUI-VideoHelperSuite 4d907bee61e92c2e65af3bd6383a4e4d356126d1; \
    clone_at https://github.com/yolain/ComfyUI-Easy-Use.git /ComfyUI/custom_nodes/ComfyUI-Easy-Use 8730ffd14044ee9392db3b192646266576bc67df; \
    clone_at https://github.com/Fannovel16/comfyui_controlnet_aux.git /ComfyUI/custom_nodes/comfyui_controlnet_aux 59b1fc411ede8623b2997855b8018f0b3b6cf49f; \
    clone_at https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git /ComfyUI/custom_nodes/ComfyUI-Custom-Scripts 609f3afaa74b2f88ef9ce8d939626065e3247469; \
    clone_at https://github.com/cubiq/ComfyUI_essentials.git /ComfyUI/custom_nodes/ComfyUI_essentials 9d9f4bedfc9f0321c19faf71855e228c93bd0dc9; \
    clone_at https://github.com/chflame163/ComfyUI_LayerStyle.git /ComfyUI/custom_nodes/ComfyUI_LayerStyle a3459a7638c4c2839878089c105c73af0eb2edd2; \
    clone_at https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git /ComfyUI/custom_nodes/ComfyUI-Frame-Interpolation 26545cc2dd95bc3d27f056016300673bdeee78f5; \
    clone_at https://github.com/city96/ComfyUI-GGUF.git /ComfyUI/custom_nodes/ComfyUI-GGUF 6ea2651e7df66d7585f6ffee804b20e92fb38b8a; \
    clone_at https://github.com/kijai/ComfyUI-segment-anything-2.git /ComfyUI/custom_nodes/ComfyUI-segment-anything-2 0c35fff5f382803e2310103357b5e985f5437f32; \
    clone_at https://github.com/WASasquatch/was-node-suite-comfyui.git /ComfyUI/custom_nodes/was-node-suite-comfyui 9934caa92dd0ddbb533cdfd5645e08c43ec629af; \
    for dir in \
        /ComfyUI/custom_nodes/rgthree-comfy \
        /ComfyUI/custom_nodes/ComfyUI-KJNodes \
        /ComfyUI/custom_nodes/ComfyUI-Impact-Pack \
        /ComfyUI/custom_nodes/ComfyUI-VideoHelperSuite \
        /ComfyUI/custom_nodes/ComfyUI-Easy-Use \
        /ComfyUI/custom_nodes/comfyui_controlnet_aux \
        /ComfyUI/custom_nodes/ComfyUI-Custom-Scripts \
        /ComfyUI/custom_nodes/ComfyUI_essentials \
        /ComfyUI/custom_nodes/ComfyUI_LayerStyle \
        /ComfyUI/custom_nodes/ComfyUI-Frame-Interpolation \
        /ComfyUI/custom_nodes/ComfyUI-GGUF \
        /ComfyUI/custom_nodes/ComfyUI-segment-anything-2 \
        /ComfyUI/custom_nodes/was-node-suite-comfyui; do \
        if [ -f "$dir/requirements.txt" ]; then pip install --no-build-isolation -r "$dir/requirements.txt"; fi; \
        if [ -f "$dir/install.py" ]; then (cd "$dir" && python3 install.py); fi; \
    done

# Custom-node requirements are installed independently and can leave NumPy and
# SciPy from incompatible release families. Reassert the Python 3.12 numerical
# stack after every node dependency and import the exact ComfyUI code paths
# that previously failed during startup.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --force-reinstall -r /numeric-requirement.txt; \
    python3 -c "import numpy, scipy, scipy.integrate, scipy.sparse; assert numpy.__version__ == '1.26.4', numpy.__version__; assert scipy.__version__ == '1.13.1', scipy.__version__; print('numerical stack OK:', numpy.__version__, scipy.__version__)"

# A custom-node dependency may install CPU-only onnxruntime last. Reassert the
# pinned GPU package after every node dependency, then fail the image build
# unless the CPU distribution is absent and the CUDA provider is exposed.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip uninstall -y onnxruntime onnxruntime-gpu 2>/dev/null || true; \
    pip install -r /ort-requirement.txt; \
    python3 -c "import importlib.metadata as m; names = {d.metadata['Name'].lower() for d in m.distributions() if d.metadata['Name']}; assert 'onnxruntime' not in names, names; assert m.version('onnxruntime-gpu') == '1.29.0'; import onnxruntime as o; p = o.get_available_providers(); assert 'CUDAExecutionProvider' in p, p; print('onnxruntime-gpu', o.__version__, 'providers OK:', p)"

COPY src/start_script.sh /start_script.sh
RUN chmod +x /start_script.sh

CMD ["/start_script.sh"]

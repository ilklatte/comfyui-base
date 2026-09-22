#!/usr/bin/env bash
set -u

TEMPLATE_DIR=/comfyui-base
TEMPLATE_URL="${TEMPLATE_REPOSITORY_URL:-https://github.com/ilklatte/comfyui-base.git}"
TEMPLATE_BRANCH="${TEMPLATE_REPOSITORY_BRANCH:-main}"
RUNTIME_DIR=/comfyui-runtime
RUNTIME_URL=https://github.com/Hearmeman24/comfyui-runtime.git

if [[ "$TEMPLATE_URL" == REPLACE_* ]]; then
    echo "FATAL: set TEMPLATE_REPOSITORY_URL to the public Git repository for this template." >&2
    exit 2
fi

sync_repo() {
    local dir="$1" url="$2" ref="$3"
    if [ -d "$dir/.git" ]; then
        git -C "$dir" fetch --depth=1 origin "$ref" &&
        git -C "$dir" reset --hard FETCH_HEAD
    else
        rm -rf "$dir" && git clone --depth=1 --branch "$ref" "$url" "$dir"
    fi
}

ok=""
for attempt in 1 2 3 4 5; do
    if sync_repo "$TEMPLATE_DIR" "$TEMPLATE_URL" "$TEMPLATE_BRANCH"; then ok=1; break; fi
    echo "Template sync attempt $attempt failed; retrying in $((attempt * 5)) seconds."
    sleep $((attempt * 5))
done
if [ -z "$ok" ] && [ ! -d "$TEMPLATE_DIR/.git" ]; then
    echo "FATAL: template repository is unavailable and no cached copy exists." >&2
    exit 1
fi

RUNTIME_REF="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['runtime_ref'])" "$TEMPLATE_DIR/pins.json" 2>/dev/null || true)"
if [ -z "$RUNTIME_REF" ]; then
    echo "FATAL: pins.json does not contain runtime_ref." >&2
    exit 2
fi

ok=""
for attempt in 1 2 3 4 5; do
    if sync_repo "$RUNTIME_DIR" "$RUNTIME_URL" "$RUNTIME_REF"; then ok=1; break; fi
    echo "Runtime sync attempt $attempt failed; retrying in $((attempt * 5)) seconds."
    sleep $((attempt * 5))
done
if [ -z "$ok" ] && [ ! -d "$RUNTIME_DIR/.git" ]; then
    echo "FATAL: shared runtime is unavailable and no cached copy exists." >&2
    exit 1
fi

exec bash "$RUNTIME_DIR/src/start.sh" "$TEMPLATE_DIR"

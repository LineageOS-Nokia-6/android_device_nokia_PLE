#!/usr/bin/env bash
# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
patch_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
export PYTHONDONTWRITEBYTECODE=1
exec python3 "$patch_dir/apply.py" "$@"

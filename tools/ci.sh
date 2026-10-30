#!/bin/bash
# Verificação completa: dados, parse, testes unitários e teste de integração (smoke).
set -e
cd "$(dirname "$0")/.."
python3 tools/gen_data/gen_data.py
godot --headless --path . --import >/dev/null 2>&1 || true
./tools/check_scripts.sh
./tools/run_tests.sh
timeout 600 godot --headless --path . -- --autopilot smoke | grep -E "SMOKE|✗"

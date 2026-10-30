#!/bin/bash
# Verifica erros de parse em todos os .gd do projeto (headless). Mostra arquivo:linha.
cd "$(dirname "$0")/.."
out=$(for f in $(find src tests -name "*.gd"); do timeout 60 godot --headless --path . --check-only -s "$f" 2>&1; done | grep -A2 "Parse Error" | grep -E "Parse Error|at: GDScript::reload" | paste - - | sort -u)
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "Sem erros de parse."

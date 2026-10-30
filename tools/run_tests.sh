#!/bin/bash
# Roda todos os testes e falha também se houver SCRIPT ERROR no log (erros de runtime não capturáveis em GDScript).
cd "$(dirname "$0")/.."
log=$(mktemp)
timeout 900 godot --headless --path . -s tests/run_tests.gd -- "$@" > "$log" 2>&1
code=$?
grep -E "^(OK|FALHA)|✗|testes," "$log"
errs=$(grep -c "SCRIPT ERROR" "$log")
if [ "$errs" != "0" ]; then
  echo "== $errs SCRIPT ERROR(s):"; grep -A3 "SCRIPT ERROR" "$log" | head -40; code=1
fi
rm -f "$log"
exit $code

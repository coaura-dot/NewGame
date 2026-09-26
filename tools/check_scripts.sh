#!/usr/bin/env bash
# Verifica a sintaxe de todos os .gd com o Godot headless.
GODOT=${GODOT:-godot}
fail=0
for f in $(find scripts tests -name "*.gd" 2>/dev/null | sort); do
  out=$(timeout 60 $GODOT --headless --path . --check-only --script "$f" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR: .*\.gd" | grep -v fontconfig | grep -v -E "Identifier not found: (Events|Settings|DB|Game|FX|Audio|SaveSystem)$" | grep -v "Failed to load script")
  if [ -n "$out" ]; then echo "== $f"; echo "$out" | head -8; fail=1; fi
done
[ $fail -eq 0 ] && echo "todos os scripts OK"
exit $fail

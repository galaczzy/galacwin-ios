#!/usr/bin/env python3
"""Keep both documented config paths from enabling unencrypted remote Metal."""

from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
view = (root / "app/Madeira/ContentView.swift").read_text(encoding="utf-8")
bridge = (root / "app/Madeira/WineProcessBridge.m").read_text(encoding="utf-8")
catalog = (root / "app/Madeira/ConfigCatalog.generated.swift").read_text(encoding="utf-8")
settings = (root / "app/Madeira/ConfigCatalog.swift").read_text(encoding="utf-8")
generator = (root / "build/tools/gen-config-catalog.py").read_text(encoding="utf-8")

remote = view[view.index("// Remote Metal currently sends its token"):view.index("// madeira-d3d12:", view.index("// Remote Metal currently sends its token"))]
assert 'unsetenv("DXMT_REMOTE_METAL")' in remote
assert 'unsetenv("RMETAL_TOKEN")' in remote
assert not re.search(r'(?<![A-Za-z_])setenv\("(?:DXMT_REMOTE_METAL|RMETAL_TOKEN)"', view)

lock = bridge[bridge.index("static int madeira_env_is_locked("):bridge.index("static int madeira_env_is_locked(") + 900]
assert 'strcmp(name, "DXMT_REMOTE_METAL")' in lock
assert 'strcmp(name, "RMETAL_TOKEN")' in lock
assert lock.index('strcmp(name, "DXMT_REMOTE_METAL")') < lock.index('getenv("MADEIRA_ENV_LOCKED")')
thread = bridge[bridge.index("static void *wine_process_thread("):]
assert 'unsetenv("DXMT_REMOTE_METAL")' in thread[:1000]
assert 'unsetenv("RMETAL_TOKEN")' in thread[:1000]
assert thread.count("madeira_env_is_locked(k.UTF8String)") >= 2

for key in ('remote', 'env.DXMT_REMOTE_METAL'):
    assert f'ConfigOption(key: "{key}"' not in catalog
    assert f'"{key}"' in generator[generator.index('for key in ("remote"'):]
for key in ('remote', 'env.DXMT_REMOTE_METAL', 'env.RMETAL_TOKEN'):
    assert f'"{key}"' in settings[settings.index('static let disabledKeys:'):]
assert 'guard !ConfigCatalog.disabledKeys.contains(key) else { return }' in settings
assert 'ConfigCatalog.disabledKeys.contains(newKey.trimmingCharacters(in: .whitespaces))' in settings
assert '[all-settings] \\(key) = \\(stored' not in settings
assert '[settings-search] \\(key) = \\(stored' not in settings

print("PASS: remote Metal token cannot be enabled through app, global or game configuration")

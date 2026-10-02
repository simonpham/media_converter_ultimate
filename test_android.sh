#!/usr/bin/env bash
set -euo pipefail

# Never run a native integration harness under the user's installed app ID.
if [[ $# -lt 1 ]]; then
  echo "Usage: ./test_android.sh <device-id> [integration_test/test_file.dart ...]" >&2
  exit 64
fi
mcu_qa_device="$1"
shift
mcu_qa_package="io.sofluffy.mcu.nativeqa.t$(date +%s)p$$"
mcu_qa_root="$(cd "$(dirname "$0")" && pwd)"
if ! command -v python3 >/dev/null; then
  echo "Python 3 is required to temporarily switch and restore env.props." >&2
  exit 69
fi
mcu_qa_adb="$(command -v adb || true)"
if [[ -z "$mcu_qa_adb" ]]; then
  mcu_qa_sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  if [[ -z "$mcu_qa_sdk" && -d "$HOME/Library/Android/sdk" ]]; then
    mcu_qa_sdk="$HOME/Library/Android/sdk"
  fi
  mcu_qa_adb="$mcu_qa_sdk/platform-tools/adb"
fi
if [[ ! -x "$mcu_qa_adb" ]]; then
  echo "Android adb is required to clean the temporary QA application." >&2
  exit 69
fi
"$mcu_qa_adb" -s "$mcu_qa_device" get-state >/dev/null
if "$mcu_qa_adb" -s "$mcu_qa_device" shell pm path "$mcu_qa_package" | rg -q '^package:'; then
  echo "Refusing to reuse an existing QA application ID." >&2
  exit 73
fi
if [[ $# -eq 0 ]]; then
  set -- integration_test/native_output_storage_test.dart
fi
cd "$mcu_qa_root/apps/mcu"
exec python3 - "$mcu_qa_root" "$mcu_qa_adb" "$mcu_qa_device" "$mcu_qa_package" "$@" <<'PY'
import fcntl
import os
from pathlib import Path
import re
import signal
import subprocess
import sys

root, adb, device, package, *tests = sys.argv[1:]
env = Path(root) / '.assets/env.props'
# Read only the package property; never print signing credentials.
property_pattern = re.compile(
    rb'^([ \t]*androidAppPackageName[ \t]*[=:][ \t]*)([^\r\n]*)(\r?)$',
    re.MULTILINE,
)

def interrupted(signum, frame):
    raise KeyboardInterrupt

signal.signal(signal.SIGTERM, interrupted)
with env.open('r+b') as config:
    try:
        fcntl.flock(config, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit('Another native QA run is using env.props.')
    original = config.read()
    matches = list(property_pattern.finditer(original))
    if len(matches) != 1:
        sys.exit('env.props must contain exactly one plain androidAppPackageName property.')
    original_line = matches[0].group(0)
    temporary_line = matches[0].group(1) + package.encode() + matches[0].group(3)
    patched = property_pattern.sub(lambda _: temporary_line, original)

    def write_config(data):
        config.seek(0)
        config.write(data)
        config.truncate()
        config.flush()
        os.fsync(config.fileno())

    try:
        write_config(patched)
        print(f'Testing temporary application: {package}', flush=True)
        result = subprocess.run([
            'flutter', 'test', '--no-uninstall', '-d', device, *tests,
        ])
    finally:
        # Preserve unrelated edits made during testing. Do not overwrite a
        # package selection changed independently by the user.
        try:
            current = env.read_bytes()
            current_matches = list(property_pattern.finditer(current))
            if current == patched:
                restored = original
            elif len(current_matches) == 1 and current_matches[0].group(0) == temporary_line:
                restored = property_pattern.sub(lambda _: original_line, current)
            else:
                restored = None
                print('env.props changed independently; leaving that selection intact.', file=sys.stderr)
            if restored is not None:
                if os.fstat(config.fileno()).st_ino == env.stat().st_ino:
                    write_config(restored)
                else:
                    with env.open('wb') as current_config:
                        current_config.write(restored)
        finally:
            subprocess.run(
                [adb, '-s', device, 'uninstall', package],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
sys.exit(result.returncode)
PY

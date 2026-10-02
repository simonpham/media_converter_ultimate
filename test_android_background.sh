#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "Usage: ./test_android_background.sh <device-id> [flutter-test-options...]" >&2
  exit 64
fi
mcu_background_qa_root="$(cd "$(dirname "$0")" && pwd)"
exec python3 - "$mcu_background_qa_root" "$@" <<'PYCODE'
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys

root, device, *options = sys.argv[1:]
adb = shutil.which('adb')
if not adb:
    sdk = os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME')
    if not sdk:
        sdk = str(Path.home() / 'Library/Android/sdk')
    adb = str(Path(sdk) / 'platform-tools/adb')
if not Path(adb).is_file():
    sys.exit('Android adb is required to resume the isolated QA activity.')

def interrupted(signum, frame):
    raise KeyboardInterrupt

signal.signal(signal.SIGTERM, interrupted)
child = subprocess.Popen([
    str(Path(root) / 'test_android.sh'), device,
    'integration_test/native_background_processing_test.dart', *options,
], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
   bufsize=1, start_new_session=True)
package = None
try:
    for line in child.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
        match = re.fullmatch(
            r'Testing temporary application: (io\.sofluffy\.mcu\.nativeqa\.t[0-9]+p[0-9]+)',
            line.strip(),
        )
        if match:
            package = match.group(1)
        if 'MCU_QA_RESUME_ACTIVITY' not in line:
            continue
        if not package:
            raise RuntimeError('Resume requested before an isolated QA ID was confirmed.')
        resolved = subprocess.run([
            adb, '-s', device, 'shell', 'cmd', 'package', 'resolve-activity',
            '--brief', '-a', 'android.intent.action.MAIN',
            '-c', 'android.intent.category.LAUNCHER', '-p', package,
        ], check=True, capture_output=True, text=True, timeout=10)
        components = [
            value.strip() for value in resolved.stdout.splitlines()
            if re.fullmatch(re.escape(package) + r'/[A-Za-z0-9_.$]+', value.strip())
        ]
        if len(components) != 1:
            raise RuntimeError('Could not resolve exactly one launcher for the isolated QA ID.')
        resumed = subprocess.run([
            adb, '-s', device, 'shell', 'am', 'start', '-n', components[0],
        ], check=True, capture_output=True, text=True, timeout=10)
        if 'Error' in resumed.stdout or 'Error' in resumed.stderr:
            raise RuntimeError('Android rejected the isolated QA activity resume.')
        print('Resumed the isolated QA activity.', flush=True)
    result = child.wait()
finally:
    if child.poll() is None:
        # The protected child owns env.props restoration and QA uninstall.
        # Forward interruption to its process group and allow its cleanup to run.
        os.killpg(child.pid, signal.SIGINT)
        try:
            child.wait(timeout=30)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGTERM)
            child.wait(timeout=15)
sys.exit(result)
PYCODE

"""Verify QA-only resume and interruption forwarding without touching a device."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import unittest


class BackgroundHelperTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="mcu-background-helper-")
        self.root = Path(self.directory.name)
        repository = Path(__file__).resolve().parent.parent
        self.helper = self.root / "test_android_background.sh"
        shutil.copy2(repository / "test_android_background.sh", self.helper)
        (self.root / "bin").mkdir()
        self.environment = dict(os.environ)
        self.environment.update({
            "PATH": str(self.root / "bin") + os.pathsep + os.environ["PATH"],
            "NATIVE_QA_FIXTURE": str(self.root),
        })
        self.write_executable(self.root / "test_android.sh", r'''#!/usr/bin/env python3
import os
from pathlib import Path
import sys
import time
root = Path(os.environ["NATIVE_QA_FIXTURE"])
scenario = os.environ["NATIVE_QA_SCENARIO"]
package = "com.github.khangnt.mcp" if scenario == "invalid-id" else "io.sofluffy.mcu.nativeqa.t123p456"
try:
    print("Testing temporary application: " + package, flush=True)
    if scenario == "child-error":
        sys.exit(9)
    if scenario == "interrupt":
        print("WAIT_FOR_INTERRUPT", flush=True)
    else:
        print("MCU_QA_RESUME_ACTIVITY", flush=True)
    while not (root / "started").exists():
        time.sleep(0.01)
except KeyboardInterrupt:
    pass
finally:
    (root / "cleanup").write_text("protected child cleaned up")
''')
        self.write_executable(self.root / "bin/adb", r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
root = Path(os.environ["NATIVE_QA_FIXTURE"])
with (root / "adb-calls").open("a") as output:
    output.write(json.dumps(sys.argv[1:]) + "\n")
if "resolve-activity" in sys.argv:
    package = "com.github.khangnt.mcp" if os.environ["NATIVE_QA_SCENARIO"] == "wrong-launcher" else "io.sofluffy.mcu.nativeqa.t123p456"
    print("priority=0")
    print(package + "/io.sofluffy.mcu.MainActivity")
if "start" in sys.argv:
    (root / "started").write_text("started QA")
    print("Starting: Intent")
''')

    def tearDown(self):
        self.directory.cleanup()

    def write_executable(self, path, text):
        path.write_text(text)
        path.chmod(0o755)

    def run_helper(self, scenario):
        self.environment["NATIVE_QA_SCENARIO"] = scenario
        return subprocess.run(
            [str(self.helper), "pixel-fixture", "--no-pub"],
            env=self.environment, capture_output=True, text=True, timeout=10,
        )

    def calls(self):
        path = self.root / "adb-calls"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_resumes_only_the_confirmed_qa_launcher(self):
        result = self.run_helper("success")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = self.calls()
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0][-2:], ["-p", "io.sofluffy.mcu.nativeqa.t123p456"])
        self.assertEqual(calls[1][-2:], ["-n", "io.sofluffy.mcu.nativeqa.t123p456/io.sofluffy.mcu.MainActivity"])
        self.assertTrue((self.root / "cleanup").exists())

    def test_rejects_an_installed_app_id_before_any_adb_action(self):
        result = self.run_helper("invalid-id")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.root / "started").exists())
        self.assertTrue((self.root / "cleanup").exists())

    def test_rejects_a_launcher_belonging_to_another_package(self):
        result = self.run_helper("wrong-launcher")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.calls()), 1)
        self.assertFalse((self.root / "started").exists())
        self.assertTrue((self.root / "cleanup").exists())

    def test_preserves_failure_from_the_protected_child(self):
        result = self.run_helper("child-error")
        self.assertEqual(result.returncode, 9)
        self.assertEqual(self.calls(), [])
        self.assertTrue((self.root / "cleanup").exists())

    def test_interruption_allows_the_protected_child_to_clean_up(self):
        self.environment["NATIVE_QA_SCENARIO"] = "interrupt"
        child = subprocess.Popen(
            [str(self.helper), "pixel-fixture"], env=self.environment,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        try:
            self.assertIn("Testing temporary application:", child.stdout.readline())
            self.assertEqual(child.stdout.readline().strip(), "WAIT_FOR_INTERRUPT")
            child.send_signal(signal.SIGTERM)
            child.communicate(timeout=10)
            self.assertNotEqual(child.returncode, 0)
            self.assertTrue((self.root / "cleanup").exists())
            self.assertEqual(self.calls(), [])
        finally:
            if child.poll() is None:
                child.kill()
                child.wait()


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Run all Eldrath tests (unit, integration, e2e, smoke) via Godot --script.

Each test is a SceneTree script under tests/ or tools/smoke_*.
Exit code: 0 if ALL pass, 1 if any fail.
"""
import subprocess, sys, pathlib, glob, time

GODOT = (
	r"C:\Users\Domenico\AppData\Local\Microsoft\WinGet\Packages"
	r"\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
	r"\Godot_v4.7-stable_win64.exe"
)
PROJECT = r"C:\Users\Domenico\Desktop\Sacred"

def run(test_path: str, timeout: int = 180) -> tuple[bool, str]:
    start = time.time()
    try:
        proc = subprocess.run(
            [GODOT, "--headless", "--path", PROJECT, "--script", f"res://{test_path}"],
            capture_output=True, text=True, timeout=timeout,
        )
        elapsed = time.time() - start
        output = proc.stdout + proc.stderr
        ok = "OK" in output and "failures:" not in output and "Parse Error" not in output
        return ok, f"{elapsed:.0f}s"
    except subprocess.TimeoutExpired:
        return False, "TIMEOUT"
    except Exception as e:
        return False, str(e)[:30]

def main():
    # Collect all test scripts
    test_files = []
    for pattern in ["tests/unit/*.gd", "tests/integration/*.gd", "tests/e2e/*.gd", "tools/smoke_*.gd"]:
        for p in sorted(glob.glob(f"{PROJECT}\\{pattern}".replace("\\", "/"))):
            rel = pathlib.Path(p).relative_to(PROJECT).as_posix()
            test_files.append(rel)

    print(f"Running {len(test_files)} tests...\n")

    passed = 0; failed = []
    for tf in test_files:
        timeout = 300 if "e2e" in tf or "smoke_city" in tf or "smoke_infinite" in tf else 120
        ok, info = run(tf, timeout)
        status = "OK" if ok else "FAIL"
        name = tf.replace("tests/unit/","U/").replace("tests/integration/","I/").replace("tests/e2e/","E2E/").replace("tools/","")
        print(f"  [{status}] {name:40s} {info}")
        if ok:
            passed += 1
        else:
            failed.append(tf)

    print(f"\n{'='*50}")
    print(f"Results: {passed}/{len(test_files)} passed")
    if failed:
        print(f"Failed ({len(failed)}):")
        for f in failed:
            print(f"  {f}")
        return 1
    print("All tests passed!")
    return 0

if __name__ == "__main__":
    sys.exit(main())

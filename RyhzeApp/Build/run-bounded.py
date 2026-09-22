"""Bound a native CI command, including tool startup and child processes."""
import os
import signal
import subprocess
import sys

seconds = int(sys.argv[1])
command = sys.argv[2:]
process = subprocess.Popen(command, start_new_session=True)
try:
    sys.exit(process.wait(timeout=seconds))
except subprocess.TimeoutExpired:
    print(f"Timed out after {seconds}s: {command[0]}", flush=True)
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
    sys.exit(124)

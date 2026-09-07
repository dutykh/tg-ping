#!/usr/bin/env python3
#
# Helper for calling tg-ping from a research script.
#
# Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
#         Science and Technology, Abu Dhabi, UAE).

import shutil
import subprocess


def available() -> bool:
    """True when tg-ping is installed and on PATH."""
    return shutil.which("tg-ping") is not None


def ping(text: str = "", *, title: str = "", level: str = "", quiet: bool = True,
         **fields) -> int:
    """Send a notification. Never raises, so a broken notifier cannot stop a run."""
    if not available():
        return 127
    cmd = ["tg-ping", "--soft-fail"]
    if level:
        cmd += ["--level", level]
    if title:
        cmd += ["--title", title]
    for key, value in fields.items():
        cmd += ["--field", f"{key.replace('_', ' ')}={value}"]
    if text:
        cmd.append(text)
    if quiet:
        cmd.append("--silent")
    return subprocess.run(cmd, check=False).returncode


def send_figure(path: str, caption: str = "") -> int:
    if not available():
        return 127
    cmd = ["tg-ping", "--soft-fail", "photo", path]
    if caption:
        cmd += ["--caption", caption]
    return subprocess.run(cmd, check=False).returncode


def send_formula(latex: str, caption: str = "") -> int:
    if not available():
        return 127
    cmd = ["tg-ping", "--soft-fail", "math", latex]
    if caption:
        cmd += ["--caption", caption]
    return subprocess.run(cmd, check=False).returncode


if __name__ == "__main__":
    ping("Sweep finished", title="Run 42", level="ok",
         runs=512, best_error="1.4e-8", wall_time="3h 12m")
    send_figure("figures/convergence.png", "Second order confirmed")
    send_formula(r"\|u - u_h\| \leqslant C h^2", "Observed convergence rate")

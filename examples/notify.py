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


def _run(cmd: list) -> int:
    # Standard input is closed, so tg-ping never reads the input of the script.
    return subprocess.run(cmd, check=False, stdin=subprocess.DEVNULL).returncode


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
    if quiet:
        cmd.append("--silent")
    if text:
        # After "--" the text is never taken for a command or an option.
        cmd += ["--", text]
    return _run(cmd)


def send_figure(path: str, caption: str = "") -> int:
    """Send a figure; a PDF, SVG or EPS file is drawn as a picture first."""
    if not available():
        return 127
    cmd = ["tg-ping", "photo", path, "--soft-fail"]
    if caption:
        cmd += ["--caption", caption]
    return _run(cmd)


def send_formula(latex: str, caption: str = "") -> int:
    if not available():
        return 127
    cmd = ["tg-ping", "math", latex, "--soft-fail"]
    if caption:
        cmd += ["--caption", caption]
    return _run(cmd)


if __name__ == "__main__":
    ping("Sweep finished", title="Run 42", level="ok",
         runs=512, best_error="1.4e-8", wall_time="3h 12m")
    send_figure("figures/convergence.pdf", "Second order confirmed")
    send_formula(r"\|u - u_h\| \leqslant C h^2", "Observed convergence rate")

"""Start a program the way Git Bash would (D107).

On Windows, Python starts a program through CreateProcess. That call appends
only .exe to a name, cannot run a #! script, and looks in Python's own
folder, the current folder and System32 (where WSL puts its bash.exe) before
PATH. shutil.which looks in the current folder first, and finds a name with
no extension only from Python 3.12. So argv() walks PATH itself, and runs a
#! script through the bash it finds there. It never gives CreateProcess a
bare name, which would run a git.exe from the current folder (D118). Off
Windows it changes nothing.
"""
import errno
import os

PATHEXT = ".COM;.EXE;.BAT;.CMD"


def find(name, path, exts):
    """The first regular file in the folders of the PATH string `path`, in
    order: in each folder, `name` itself, then `name` with each of `exts`.
    None when there is none. An empty or relative PATH entry is skipped, so
    the current folder is never searched."""
    for folder in path.split(os.pathsep):
        if not os.path.isabs(folder):
            continue
        for candidate in [name] + [name + ext for ext in exts]:
            full = os.path.join(folder, candidate)
            if os.path.isfile(full):
                return full
    return None


def argv(args):
    """The argument list to start `args` with. Off Windows, `args` as they
    are. On Windows, the program found on PATH, after bash when the file
    starts with #!, with noglob added to MSYS in os.environ for that bash.
    A program or a bash that is not on PATH raises FileNotFoundError, as a
    missing program does on Linux, so the caller's own error path runs. A
    found file that cannot be read is started by its found path."""
    args = list(args)
    if os.name != "nt":
        return args
    path = os.environ.get("PATH", "")
    exts = [ext for ext in os.environ.get("PATHEXT", PATHEXT).split(";") if ext]
    found = find(args[0], path, exts)
    if found is None:
        raise FileNotFoundError(errno.ENOENT, "not found on PATH", args[0])
    try:
        with open(found, "rb") as handle:
            script = handle.read(2) == b"#!"
    except OSError:
        return [found] + args[1:]
    if not script:
        return [found] + args[1:]
    bash = find("bash", path, exts)
    if bash is None:
        raise FileNotFoundError(errno.ENOENT, "not found on PATH", "bash")
    # Git Bash expands {a}, * and [..] in the arguments that a native program
    # hands it; noglob keeps each argument as typed.
    options = os.environ.get("MSYS", "").split()
    if "noglob" not in options:
        os.environ["MSYS"] = " ".join(options + ["noglob"])
    return [bash, found] + args[1:]

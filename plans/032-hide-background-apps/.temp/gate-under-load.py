# Runs `make test` under deliberate CPU load, to prove the suite does not need a quiet machine. Arg 1: how many CPU hogs.
# Arg 2: the log path. The hogs are this script's children and always die with it.
import subprocess, sys

hogs = [
    subprocess.Popen(["/usr/bin/yes"], stdout=subprocess.DEVNULL)
    for _ in range(int(sys.argv[1]))
]
try:
    with open(sys.argv[2], "w") as log:
        code = subprocess.run(["make", "test"], stdout=log, stderr=subprocess.STDOUT).returncode
finally:
    for hog in hogs:
        hog.kill()
    for hog in hogs:
        hog.wait()
with open(sys.argv[2], "a") as log:
    log.write(f"exit={code}\n")

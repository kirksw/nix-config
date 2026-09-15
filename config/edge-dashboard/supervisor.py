#!/usr/bin/env python3
"""One launchd-owned process tree for the EDGE dashboard."""
from pathlib import Path
import signal
import subprocess
import sys
import time
import urllib.request

ROOT = Path(__file__).resolve().parent
HOME = Path.home()
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
PROFILE = str(HOME / 'Library/Application Support/edge-dashboard/chrome')
running = True


def stop_requested(*_):
    global running
    running = False


def command(*args):
    return subprocess.run(args, capture_output=True, text=True, timeout=8, check=True).stdout


def edge_connected():
    return any(line.split('|')[-1].strip() == 'XENEON EDGE'
               for line in command('aerospace', 'list-monitors').splitlines())


def stop(process):
    if process and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=8)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def start(args):
    return subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    signal.signal(signal.SIGTERM, stop_requested)
    signal.signal(signal.SIGINT, stop_requested)
    children = {}
    helpers = {
        'server': [sys.executable, str(ROOT / 'server.py')],
        'calendar': [str(HOME / 'Applications/EDGE Calendar.app/Contents/MacOS/edge-calendar')],
        'touch': [str(HOME / 'Applications/XeneonTouchSupport.app/Contents/MacOS/XeneonTouchSupport')],
    }
    placed = False
    try:
        while running:
            for name, args in helpers.items():
                if name not in children or children[name].poll() is not None:
                    if Path(args[0]).exists():
                        children[name] = start(args)
                    else:
                        print(f'EDGE prerequisite missing: {name}', flush=True)
            try:
                connected = edge_connected()
            except (OSError, subprocess.SubprocessError):
                # AeroSpace restarting does not mean the physical display was removed.
                time.sleep(2)
                continue
            if not connected:
                stop(children.pop('browser', None))
                placed = False
            else:
                browser = children.get('browser')
                if browser is None or browser.poll() is not None:
                    try:
                        with urllib.request.urlopen('http://127.0.0.1:8767/', timeout=2):
                            pass
                    except OSError:
                        time.sleep(2)
                        continue
                    children['browser'] = start([CHROME, f'--user-data-dir={PROFILE}',
                        '--no-first-run', '--no-default-browser-check',
                        '--app=http://127.0.0.1:8767/'])
                    placed = False
                if not placed:
                    try:
                        windows = command('aerospace', 'list-windows', '--all', '--format',
                                          '%{window-id}|%{app-bundle-id}|%{window-title}')
                        for line in windows.splitlines():
                            parts = line.split('|', 2)
                            if len(parts) == 3 and parts[1:] == ['com.google.Chrome', 'EDGE / Observatory']:
                                window = parts[0]
                                command('aerospace', 'macos-native-fullscreen', 'off', '--window-id', window)
                                time.sleep(1)
                                command('aerospace', 'move-node-to-workspace', 'dashboard', '--window-id', window)
                                command('aerospace', 'workspace', 'dashboard')
                                command('aerospace', 'focus', '--window-id', window)
                                time.sleep(1)
                                if edge_connected():
                                    command('aerospace', 'macos-native-fullscreen', 'on', '--window-id', window)
                                    placed = True
                                break
                    except (OSError, subprocess.SubprocessError):
                        pass
            time.sleep(2)
    finally:
        for process in reversed(list(children.values())):
            stop(process)


if __name__ == '__main__':
    main()

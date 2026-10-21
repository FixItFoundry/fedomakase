#!/bin/bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"
python3 - "$ROOT" <<'PY'
import json, os, pathlib, subprocess, sys, tempfile, time

root = pathlib.Path(sys.argv[1])
with tempfile.TemporaryDirectory() as directory:
    work = pathlib.Path(directory)
    mock = work / 'mock'
    mock.write_text('''#!/usr/bin/python3
import json, os, pathlib, sys, time
name = pathlib.Path(sys.argv[0]).name
if name == 'hyprctl':
    if sys.argv[1] == 'eval':
        with open(os.environ['CALLS'], 'a') as f: f.write(sys.argv[2] + '\\n')
    elif sys.argv[1] == 'devices':
        print(json.dumps({'keyboards': [{'name': n} for n in ['internal', 'keyd-virtual-keyboard', 'usb-keyboard']]}))
    else:
        print(json.dumps([{'name': 'eDP-1', 'width': 2880, 'height': 1800, 'refreshRate': 119.98, 'x': 10, 'y': 20, 'scale': 1.25}]))
elif name == 'busctl': print('s ' + json.dumps(os.environ.get('READING', 'undefined')))
elif name == 'omarchy-hw-keyboard': print('internal')
elif name == 'omarchy-hw-touchpad': print('touchpad')
elif name == 'omarchy-hyprland-monitor-laptop': print('eDP-1')
elif name == 'omarchy-2in1-mode': print(os.environ.get('MODE', 'tablet'))
elif name == 'monitor-sensor':
    pathlib.Path(os.environ['SENSOR_PID']).write_text(str(os.getpid()))
    print('Accelerometer orientation changed: left-up', flush=True)
    time.sleep(30)
''')
    mock.chmod(0o755)
    for command in ('hyprctl', 'busctl', 'omarchy-hw-keyboard', 'omarchy-hw-touchpad', 'omarchy-hyprland-monitor-laptop', 'omarchy-2in1-mode', 'monitor-sensor'):
        (work / command).symlink_to(mock)
    calls = work / 'calls'
    env = dict(os.environ, PATH=f'{work}:{root / "bin"}:' + os.environ['PATH'], CALLS=str(calls), SENSOR_PID=str(work / 'sensor.pid'))
    def run(command, *args, **values):
        calls.write_text('')
        result = subprocess.run([str(root / 'bin' / command), *args], env=dict(env, **values), capture_output=True, text=True)
        return result, calls.read_text()
    for mode, enabled in [('tablet', 'false'), ('laptop', 'true')]:
        result, log = run('omarchy-2in1-apply', mode, MODE=mode)
        assert result.returncode == 0, result.stderr
        for device in ('internal', 'keyd-virtual-keyboard', 'touchpad'):
            assert f'name = "{device}", enabled = {enabled}' in log, log
        assert 'usb-keyboard' not in log and 'kb_layout' not in log, log
    result, log = run('omarchy-2in1-apply', 'invalid')
    assert result.returncode != 0 and not log
    for reading, transform in [('normal', 0), ('left-up', 1), ('bottom-up', 2), ('right-up', 3)]:
        result, log = run('omarchy-2in1-rotate', 'auto', MODE='tablet', READING=reading)
        assert result.returncode == 0 and log.count(f'transform = {transform}') == 2, log
        assert '2880x1800@119.98' in log and '10x20' in log and 'scale = 1.25' in log, log
    _, log = run('omarchy-2in1-rotate', 'auto', MODE='laptop', READING='left-up')
    assert log.count('transform = 0') == 2, log
    for mode, reading in [('unknown', 'normal'), ('tablet', 'undefined')]:
        _, log = run('omarchy-2in1-rotate', 'auto', MODE=mode, READING=reading)
        assert not log, log
    calls.write_text('')
    watcher = subprocess.Popen([str(root / 'bin/omarchy-2in1-rotate'), 'watch'], env=dict(env, MODE='tablet', READING='left-up'))
    try:
        deadline = time.monotonic() + 3
        while calls.read_text().count('transform = 1') < 2 and time.monotonic() < deadline:
            time.sleep(0.02)
        assert calls.read_text().count('transform = 1') == 2, calls.read_text()
    finally:
        watcher.terminate()
        watcher.wait(timeout=3)
    sensor_pid = int((work / 'sensor.pid').read_text())
    try:
        os.kill(sensor_pid, 0)
    except ProcessLookupError:
        pass
    else:
        raise AssertionError('orientation watcher left monitor-sensor running')
print('PASS: keyboard devices, four rotations, laptop/unknown states, mode preservation, watcher cleanup')
PY

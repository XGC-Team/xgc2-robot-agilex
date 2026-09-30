#!/usr/bin/env python3
"""Exercise generated maintainer scripts without an operating system daemon."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
RETIRED = 'xgc2-field-panel.service'
PROTECTED = [
    'xgc2-agilex-chassis.service',
    'xgc2-agilex-roscore.service',
    'xgc2-agilex-swarm-ros-bridge.service',
    'xgc2-agilex-imu-hi226.service',
    'xgc2-agilex-onboard-teleop.service',
    'xgc2-ugv-controller.service',
]


class FieldPanelUpgrade(unittest.TestCase):
    def test_upgrade_stops_only_retired_service_and_removes_real_enable_link(self):
        source = (ROOT / '.xgc2/scripts/package_debs.sh').read_text()
        start = source.index('build_autostart_deb()')
        end = source.index('build_meta_deb()', start)
        scripts = dict(re.findall(
            r'cat > "\$\{pkg_root\}/DEBIAN/(\w+)" <<\'EOF\'\n(.*?)\nEOF',
            source[start:end], re.S))
        old_prerm = (ROOT / '.xgc2/tests/fixtures/old-autostart-prerm.sh').read_text()
        systemctl = shutil.which('systemctl')
        self.assertIsNotNone(systemctl)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            unit_dir = root / 'lib/systemd/system'
            unit_dir.mkdir(parents=True)
            units = PROTECTED + [RETIRED]
            for unit in units:
                (unit_dir / unit).write_text(
                    '[Unit]\nDescription=Isolated upgrade fixture\n'
                    '[Service]\nExecStart=/bin/true\n'
                    '[Install]\nWantedBy=multi-user.target\n')
                subprocess.run([systemctl, '--root', str(root), 'enable', unit],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
            state = root / 'state.json'
            state.write_text(json.dumps({'running': units, 'calls': []}))
            bin_dir = root / 'bin'
            bin_dir.mkdir()
            shim = bin_dir / 'systemctl'
            shim.write_text('''#!/usr/bin/python3
import json,os,subprocess,sys
from pathlib import Path
p=Path(os.environ['UPGRADE_STATE']);s=json.loads(p.read_text());args=sys.argv[1:]
s['calls'].append(args)
if args[0]=='stop':
 s['running']=[u for u in s['running'] if u not in args[1:]]
if args[0]=='disable':
 subprocess.run([os.environ['REAL_SYSTEMCTL'],'--root',os.environ['UPGRADE_ROOT'],*args],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
p.write_text(json.dumps(s))
''')
            shim.chmod(0o755)
            for name in ['id', 'udevadm']:
                p = bin_dir / name
                p.write_text('#!/bin/sh\nexit 1\n')
                p.chmod(0o755)
            env = dict(os.environ, PATH=str(bin_dir) + ':/usr/bin:/bin',
                       UPGRADE_STATE=str(state), UPGRADE_ROOT=str(root), REAL_SYSTEMCTL=systemctl)

            def run(body, *args):
                p = root / 'maintainer.sh'
                p.write_text(body + '\n')
                subprocess.run(['/bin/sh', str(p), *args], env=env, check=True)

            # dpkg calls the old prerm, then the new preinst before unpack.
            run(old_prerm, 'upgrade', '0.2.0-35')
            self.assertIn(RETIRED, json.loads(state.read_text())['running'])
            run(scripts['preinst'], 'upgrade', '0.2.0-34')
            self.assertNotIn(RETIRED, json.loads(state.read_text())['running'])
            self.assertFalse((root / 'etc/systemd/system/multi-user.target.wants' / RETIRED).is_symlink())
            (unit_dir / RETIRED).unlink()  # unpack removes the obsolete unit
            run(scripts['postinst'], 'configure', '0.2.0-34')
            result = json.loads(state.read_text())
            self.assertEqual(set(result['running']), set(PROTECTED))
            for unit in PROTECTED:
                self.assertTrue((root / 'etc/systemd/system/multi-user.target.wants' / unit).is_symlink())
            self.assertEqual({call[1] for call in result['calls'] if call[0]=='stop'}, {RETIRED})
            self.assertFalse(any(call[0] in ['start', 'restart', 'enable'] for call in result['calls']))
            # Retry configure after a partially completed upgrade is idempotent.
            run(scripts['postinst'], 'configure', '0.2.0-34')
            self.assertEqual(set(json.loads(state.read_text())['running']), set(PROTECTED))


if __name__ == '__main__':
    unittest.main()

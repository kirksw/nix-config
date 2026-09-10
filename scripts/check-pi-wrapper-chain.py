#!/usr/bin/env python3
"""Check built pix -> Pi routing -> library wrapper without credentials/model calls.

Usage: check-pi-wrapper-chain.py /nix/store/...-pi/bin/pi /nix/store/...-pix/bin/pix
The outer wrapper's credential/SSO setup is excluded. The complete inner wrapper
runs with an isolated HOME and a probe in place of the model executable.
"""

import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

outer = Path(sys.argv[1]).read_text()
pix = Path(sys.argv[2]).read_text()
start = outer.index('_nix_agents_extra_args=()')
end = outer.index('_pi_profile_env=', start)
routing = outer[start:end]
inner_paths = set(re.findall(r'/nix/store/[^"\s]+/bin/pi', routing))
assert inner_paths, 'No library wrapper found'

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory).resolve()
    probe = root / 'probe'
    probe.write_text('#!/bin/sh\nprintf "%s\\n" "$NIX_AGENTS_PROFILE" "$PI_CODING_AGENT_DIR" "$@"\n')
    probe.chmod(0o755)
    for index, path in enumerate(sorted(inner_paths)):
        inner = Path(path).read_text()
        instrumented, count = re.subn(
            r'(_nax_exec_tool )"/nix/store/[^"\n]+/bin/pi"',
            lambda match: match[1] + f'"{probe}"', inner,
        )
        assert count, f'No final Pi invocation in {path}'
        copy = root / f'inner-{index}'
        copy.write_text(instrumented)
        copy.chmod(0o755)
        routing = routing.replace(path, str(copy))
    wrapper = root / 'pi'
    wrapper.write_text(
        '#!/usr/bin/env bash\nset -euo pipefail\n'
        'is_lunar_project() { [[ "$PWD" == "$HOME/git/github.com/lunarway/"* ]]; }\n'
        + routing + '\nexec "${_nix_agents_exec[@]}" "$@"\n'
    )
    wrapper.chmod(0o755)
    # Start with no inherited credentials or profile state.
    env = {'PATH': f'{root}:{os.environ["PATH"]}', 'HOME': str(root),
           'XDG_CONFIG_HOME': str(root / 'config'),
           'XDG_DATA_HOME': str(root / 'data')}

    def check(command, profile, cwd=root, extra=None):
        result = subprocess.run(command, cwd=cwd, env=env | (extra or {}),
                                capture_output=True, text=True, check=True)
        base = profile.removesuffix('-fallback') if profile.endswith('-fallback') else profile
        expected = [profile, str(root / f'config/nix-agents/pi/bases/{base}/profiles/{profile}'),
                    'argument with spaces']
        assert result.stdout.splitlines() == expected, (result.stdout, result.stderr, expected)

    for scope, cli_scope in [('personal', 'home'), ('work', 'work')]:
        for kind in ['default', 'fallback', 'browser']:
            profile = f'{scope}-{kind}'
            # Explicit selection must beat both a conflicting project file and
            # an inherited configuration directory from another profile.
            (root / '.nix-agents-profile').write_text('personal-default\n')
            check(['bash', '-c', pix, 'pix', '--scope', cli_scope,
                   '--profile', kind, '--', 'argument with spaces'], profile,
                  extra={'PI_CODING_AGENT_DIR': str(root / 'config/nix-agents/pi/bases/personal-default/profiles/personal-default')})
            (root / '.nix-agents-profile').write_text(profile + '\n')
            check([str(wrapper), 'argument with spaces'], profile)
            (root / '.nix-agents-profile').unlink()
            base = scope if kind == 'fallback' else profile
            check([str(wrapper), 'argument with spaces'], profile,
                  extra={'PI_CODING_AGENT_DIR': str(root / f'config/nix-agents/pi/bases/{base}/profiles/{profile}')})
    check([str(wrapper), 'argument with spaces'], 'personal-default')
    work = root / 'git/github.com/lunarway/project'
    work.mkdir(parents=True)
    check([str(wrapper), 'argument with spaces'], 'work-default', cwd=work)
    print('Built wrapper chain: six profiles, explicit precedence, project/child routing, defaults, and arguments passed')

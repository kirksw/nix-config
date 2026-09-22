#!/usr/bin/env python3
"""Check built pix -> Pi routing -> launch target without credentials/model calls.

Usage: check-pi-wrapper-chain.py /nix/store/...-pi/bin/pi /nix/store/...-pix/bin/pix
The wrapper's credential/SSO setup is excluded. The routing block runs with an
isolated HOME and a probe in place of the Pi executable.
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
session_start = outer.index('export PI_CODING_AGENT_SESSION_DIR=', end)
session_end = outer.index('\n', session_start)
routing += '\n' + outer[session_start:session_end] + '\n'

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory).resolve()
    probe = root / 'probe'
    probe.write_text('#!/bin/sh\nprintf "%s\\n" "$NIX_AGENTS_PROFILE" "$PI_CODING_AGENT_DIR" "$PI_CODING_AGENT_SESSION_DIR" "$@"\n')
    probe.chmod(0o755)

    # Replace the Pi launch target with the probe so no model call happens.
    routing, count = re.subn(
        r'_nix_agents_exec=\("/nix/store/[^"]+/bin/pi"\)',
        f'_nix_agents_exec=("{probe}")',
        routing,
    )
    assert count == 1, 'No Pi launch target found in the wrapper'

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

    def check(command, profile, cwd=root, extra=None, config=None, sessions=None):
        result = subprocess.run(command, cwd=cwd, env=env | (extra or {}),
                                capture_output=True, text=True, check=True)
        base = profile.removesuffix('-fallback') if profile.endswith('-fallback') else profile
        expected = [profile, config or str(root / f'config/nix-agents/pi/bases/{base}/profiles/{profile}'),
                    sessions or str(root / f'data/nix-agents/pi/sessions/{profile}'),
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
    custom = str(root / "custom config with 'quotes")
    check([str(wrapper), 'argument with spaces'], 'work-browser',
          extra={'NIX_AGENTS_PROFILE': 'work-browser', 'PI_CODING_AGENT_DIR': custom,
                 'PI_CODING_AGENT_SESSION_DIR': custom + '/sessions'},
          config=custom, sessions=custom + '/sessions')
    print('Built wrapper chain: six profiles, explicit precedence, project/child routing, defaults, and arguments passed')

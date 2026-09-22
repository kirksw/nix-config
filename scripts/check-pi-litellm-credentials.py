#!/usr/bin/env python3
"""Exercise Pi credential initialization with fake secrets and a clean environment."""

import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'modules/home/programs/ai-agents.nix').read_text()
profiles = json.loads(subprocess.check_output(
    ['nix-instantiate', '--eval', '--strict', '--json', str(ROOT / 'agents/pi-profiles.nix')],
    text=True,
))
loader = source.split("  loadPersonalLitellmCredentials = ''\n", 1)[1].split("\n  '';", 1)[0]
start = source.index('                    mkdir -p "$PI_CODING_AGENT_DIR"')
end = source.index('                    # Commit identity', start)
initialization = source[start:end]

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    for name in ('api-key', 'cf-client-id', 'cf-client-secret'):
        (root / name).write_text('fake-' + name + '\n')
    loader = re.sub(
        r'\$\{config\.sops\.secrets\."api/litellm/([^"]+)"\.path\}',
        lambda match: str(root / match[1]), loader,
    )
    arms = []
    for base, config in profiles['bases'].items():
        exports = []
        for name in config['providers']:
            provider = profiles['providers'][name]
            ref, target = provider['credentialRef'], provider['envVar']
            exports.append(f'[ -n "${{{ref}:-}}" ] && export {target}="${{{ref}}}"')
        arms.append(base + ')\n' + '\n'.join(exports) + '\n;;')
    script = initialization.replace('${loadPersonalLitellmCredentials}', loader)
    script = script.replace('${piCredentialArms}', '\n'.join(arms)).replace("''${", '${')
    variables = ('LITELLM_API_KEY', 'LITELLM_CF_ACCESS_CLIENT_ID', 'LITELLM_CF_ACCESS_CLIENT_SECRET')
    for base in profiles['bases']:
        expected = ['fake-api-key', 'fake-cf-client-id', 'fake-cf-client-secret'] if base.startswith('personal') else ['', '', '']
        probe = script + '\nprintf "%s\\n" ' + ' '.join(f'"${{{key}:-}}"' for key in variables)
        env = {'PATH': os.environ['PATH'], 'HOME': directory,
               'PI_CODING_AGENT_DIR': str(root / 'agent'), '_pi_session_base': base,
               'LUNAR_OPENAI_API_KEY': 'fake-openai'}
        result = subprocess.run(['bash', '-eu', '-c', probe], env=env,
                                capture_output=True, text=True, check=True)
        assert result.stdout.splitlines() == expected, (base, result.stdout, expected)
    print('PASS: all six bases initialize credentials correctly without inherited LiteLLM variables')

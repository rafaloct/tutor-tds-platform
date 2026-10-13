import json
import os

import httpx
import pytest
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
import sys

from tds_account_mcp.server import Accounts, build_server


@pytest.fixture
def setup(tmp_path):
    inbox = tmp_path / 'inbox'
    inbox.mkdir(mode=0o700)
    token = tmp_path / 'token'
    token.write_text('synthetic-admin-token')
    token.chmod(0o600)
    item = inbox / 'person-1.json'
    item.write_text(json.dumps(dict(name='Synthetic Person', cpf='12345678909',
        phone='61999990000', password='Test-only-Password-123!', role='teacher', program_id='program-1')))
    item.chmod(0o600)
    return inbox, tmp_path / 'receipts', token


def adapter(setup, handler):
    return Accounts('staging', *setup, transport=httpx.MockTransport(handler))


def success(request):
    payload = json.loads(request.content)
    assert request.url.path == '/tutor-staging-api/admin/accounts'
    assert request.headers['authorization'] == 'Bearer synthetic-admin-token'
    assert payload['cpf'] == '12345678909'
    assert payload['password'] == 'Test-only-Password-123!'
    return httpx.Response(201, json=dict(id='new-user', name=payload['name'], role=payload['role'],
        program_id=payload['program_id'], membership_status='active', cpf='must-not-return', password='secret'))


async def test_create_uses_canonical_api_and_sanitizes_output(setup):
    accounts = adapter(setup, success)
    preview = accounts.preview('person-1')
    assert set(preview) == {'request_id', 'environment', 'name', 'role', 'program_id', 'approval_digest'}
    result = await accounts.create('person-1', preview['approval_digest'])
    assert result['id'] == 'new-user'
    assert 'cpf' not in result and 'password' not in result
    receipt = (setup[1] / 'person-1.json').read_text()
    assert 'synthetic-admin-token' not in receipt and '12345678909' not in receipt
    with pytest.raises(ValueError, match='já tentado'):
        await accounts.create('person-1', preview['approval_digest'])


@pytest.mark.parametrize('status', [401, 403, 409, 422, 500, 302, 307])
async def test_failure_never_leaks_body_or_retries(setup, status):
    calls = []
    def handler(request):
        calls.append(request)
        return httpx.Response(status, text='secret-password cpf', headers={'Location': 'https://example.org'})
    accounts = adapter(setup, handler)
    digest = accounts.preview('person-1')['approval_digest']
    with pytest.raises(ValueError, match=f'HTTP {status}') as error:
        await accounts.create('person-1', digest)
    assert 'secret-password' not in str(error.value)
    with pytest.raises(ValueError, match='já tentado'):
        await accounts.create('person-1', digest)
    assert len(calls) == 1


async def test_timeout_persists_unknown_across_restart(setup):
    def timeout(request):
        raise httpx.ReadTimeout('private upstream contents')
    first = adapter(setup, timeout)
    digest = first.preview('person-1')['approval_digest']
    with pytest.raises(ValueError, match='incerto'):
        await first.create('person-1', digest)
    second = adapter(setup, success)
    with pytest.raises(ValueError, match='já tentado'):
        await second.create('person-1', digest)
    assert json.loads((setup[1] / 'person-1.json').read_text())['state'] == 'unknown'


async def test_digest_binds_input_and_environment(setup):
    accounts = adapter(setup, success)
    digest = accounts.preview('person-1')['approval_digest']
    prod = Accounts('production', *setup, production_enabled=True)
    assert prod.preview('person-1')['approval_digest'] != digest
    item = setup[0] / 'person-1.json'
    item.write_text(item.read_text().replace('teacher', 'admin'))
    with pytest.raises(ValueError, match='mudou'):
        await accounts.create('person-1', digest)
    assert not list(setup[1].iterdir())


@pytest.mark.parametrize('request_id', ['../token', '/etc/passwd', 'a/b', 'a.b', ''])
def test_rejects_arbitrary_paths(setup, request_id):
    with pytest.raises(ValueError, match='inválido'):
        adapter(setup, success).preview(request_id)


def test_production_is_explicit_and_urls_not_model_controlled(setup):
    with pytest.raises(ValueError, match='Produção requer'):
        Accounts('production', *setup)
    with pytest.raises(ValueError, match='Ambiente'):
        Accounts('https://evil.test', *setup)


def test_validation_hides_input(setup):
    item = setup[0] / 'person-1.json'
    item.write_text('{"cpf":"private-value"}')
    with pytest.raises(ValueError) as error:
        adapter(setup, success).preview('person-1')
    assert 'private-value' not in str(error.value)


@pytest.mark.skipif(os.name != 'posix', reason='Windows ACLs are managed by host operator')
def test_rejects_world_readable_inputs(setup):
    (setup[0] / 'person-1.json').chmod(0o644)
    with pytest.raises(ValueError, match='proteção'):
        adapter(setup, success).preview('person-1')


async def test_mcp_tool_metadata_and_schema(setup):
    server = build_server(adapter(setup, success))
    tools = {tool.name: tool for tool in await server.list_tools()}
    assert set(tools) == {'preview_account', 'create_account'}
    assert tools['preview_account'].annotations.readOnlyHint
    assert tools['create_account'].annotations.destructiveHint
    assert not tools['create_account'].annotations.idempotentHint
    assert set(tools['create_account'].inputSchema['properties']) == {'request_id', 'approval_digest'}


async def test_real_stdio_protocol_handshake_and_preview(setup):
    inbox, receipts, token = setup
    env = dict(os.environ, TDS_MCP_ENVIRONMENT='staging', TDS_MCP_INBOX=str(inbox),
               TDS_MCP_RECEIPTS=str(receipts), TDS_MCP_TOKEN_FILE=str(token))
    params = StdioServerParameters(command=sys.executable, args=['-m', 'tds_account_mcp.server'], env=env)
    async with stdio_client(params) as (reader, writer):
        async with ClientSession(reader, writer) as client:
            await client.initialize()
            assert len((await client.list_tools()).tools) == 2
            result = await client.call_tool('preview_account', {'request_id': 'person-1'})
            assert not result.isError
            assert 'Synthetic Person' in result.content[0].text
            assert '12345678909' not in result.content[0].text
            assert 'Password' not in result.content[0].text

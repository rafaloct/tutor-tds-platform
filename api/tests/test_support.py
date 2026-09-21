from dataclasses import replace
import hashlib
import hmac

from test_classrooms import make_client, register, bearer


def test_support_identity_requires_auth_and_configuration():
    client, app = make_client()
    assert client.get('/support/identity').status_code == 401
    user = register(client, 'student')
    headers = bearer(user['access_token'])
    assert client.get('/support/identity', headers=headers).status_code == 503
    app.state.settings = replace(app.state.settings, chatwoot_identity_secret='synthetic-only', chatwoot_identity_namespace='tds-staging')
    response = client.get('/support/identity?user_id=someone-else', headers=headers)
    assert response.status_code == 200
    assert response.headers['cache-control'] == 'no-store'
    identity = response.json()
    assert set(identity) == {'identifier', 'identifier_hash'}
    assert identity['identifier'] == f"tds-staging:{user['user']['id']}"
    assert identity['identifier_hash'] == hmac.new(b'synthetic-only', identity['identifier'].encode(), hashlib.sha256).hexdigest()
    assert client.get('/support/identity', headers=headers).json() == identity
    other = register(client, 'outsider')
    assert client.get('/support/identity', headers=bearer(other['access_token'])).json()['identifier'] != identity['identifier']
    app.state.settings = replace(app.state.settings, chatwoot_identity_namespace='tds-production')
    assert client.get('/support/identity', headers=headers).json()['identifier'] != identity['identifier']

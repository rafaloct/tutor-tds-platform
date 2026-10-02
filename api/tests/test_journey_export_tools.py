from ops.export_tds_journey import csv_value, daily_activity, participants, read_pages
import pytest


def test_account_activity_is_deduplicated_across_cohorts_and_keeps_utc_day():
    event = {'event_id': 'one', 'pessoa_id': 'p', 'evento': 'screen_engagement',
        'alvo_tipo': 'page_id', 'alvo_id': 'home', 'segundos_tela': 15,
        'ocorreu_em': '2026-10-01T23:00:00-03:00'}
    assert daily_activity([event, event])[0] == {'pessoa_id': 'p', 'data_utc': '2026-10-02',
        'evento': 'screen_engagement', 'alvo_tipo': 'page_id', 'alvo_id': 'home',
        'eventos_qtd': 1, 'segundos_tela': 15, 'escopo': 'conta_autenticada'}
    with pytest.raises(ValueError, match='Conflicting'):
        daily_activity([event, event | {'segundos_tela': 16}])
    assert csv_value(None) == '' and csv_value(0) == 0 and csv_value('=private') == "'=private"


def test_pagination_rejects_mutating_source_and_pins_contract():
    calls = []
    def fetch(url):
        calls.append(url)
        return {'contract': 'tds-activity-v1', 'offset': (len(calls)-1)*100,
            'limit': 100, 'total': 101 if len(calls) == 1 else 102, 'items': []}
    with pytest.raises(ValueError, match='Source changed'):
        read_pages('https://synthetic.example', 'never-logged', 'c', 'journey-activity', fetch=fetch)
    assert len(calls) == 2


def test_missing_baseline_keeps_enrolled_identity_without_fabricating_inscription():
    rows = [{'pessoa_id': 'a', 'turma_id': 'c', 'registro_id': 'DIG-01'}]
    pending = [{'pessoa_id': 'b', 'turma_id': 'c', 'status': 'bi_link_pending'},
        {'pessoa_id': 'z', 'turma_id': 'c', 'status': 'inactive_or_inconsistent'}]
    assert participants(rows, pending) == [
        {'pessoa_id': 'a', 'turma_id': 'c', 'registro_id': 'DIG-01', 'status_vinculo': 'confirmed'},
        {'pessoa_id': 'b', 'turma_id': 'c', 'registro_id': None, 'status_vinculo': 'bi_link_pending'}]
    with pytest.raises(ValueError, match='Duplicate'):
        participants(rows + rows, [])

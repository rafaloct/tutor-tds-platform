from sqlalchemy.orm import Session

from app.classrooms import router, admin_router
from app.main import _serialize_course
from app.models import Course, Enrollment
from test_course_editor import editor, headers, publish, save, action


def test_class_keeps_snapshot_after_new_publication_and_archive(editor):
    client, engine = editor
    client.app.include_router(router)
    client.app.include_router(admin_router)
    first = publish(client)
    payload = {
        "program_id": "p1", "course_id": "course", "teacher_id": "teacher",
        "name": "Turma primeira", "start_date": "2026-01-01", "end_date": "2026-12-31",
    }
    created = client.post('/admin/classes', json=payload, headers=headers('admin'))
    assert created.status_code == 201, created.text
    classroom = created.json()
    assert classroom['course_version_id'] == first['version_id']
    with Session(engine) as session:
        session.add(Enrollment(id='enrolled', user_id='student', program_id='p1', course_id='course', status='active'))
        session.commit()
    assert client.put(f"/classes/{classroom['id']}/students/student", headers=headers('teacher')).status_code == 200
    path = f"/classes/{classroom['id']}/course"
    assert client.get(path, headers=headers('outsider')).status_code == 403
    assert client.get('/classes?enrolled_only=true', headers=headers('teacher')).json() == {'classes': []}
    assert len(client.get('/classes?enrolled_only=true', headers=headers('student')).json()['classes']) == 1
    original = client.get(path, headers=headers('student')).json()
    assert original['course_version_id'] == first['version_id']
    fork = client.post('/courses/course/versions', headers=headers('creator'), json={'source_version_id': first['version_id']}).json()
    second = save(client, fork, content='Nova edição').json()
    second = action(client, second, 'submit').json()
    second = action(client, second, 'publish', 'coordinator').json()
    assert second['version_id'] != first['version_id']
    assert client.get(path, headers=headers('student')).json() == original
    with Session(engine) as session:
        public = _serialize_course(session.get(Course, 'course'), session)
        assert public['course_version_id'] == second['version_id']
        assert public['sections'][0]['messages'][0]['content'] == 'Nova edição'
        assert public['legacy_progress_compatible'] is False
    new_class = client.post('/admin/classes', json=payload | {'name': 'Segunda turma'}, headers=headers('admin'))
    assert new_class.status_code == 201, new_class.text
    assert new_class.json()['course_version_id'] == second['version_id']
    assert action(client, second, 'archive', 'coordinator').status_code == 200
    assert client.get(path, headers=headers('student')).json() == original
    assert client.post('/admin/classes', json=payload, headers=headers('admin')).status_code == 422
    with Session(engine) as session:
        session.get(Enrollment, 'enrolled').status = 'inactive'
        session.commit()
    assert client.get(path, headers=headers('student')).status_code == 403
    assert client.get('/classes?enrolled_only=true', headers=headers('student')).json() == {'classes': []}

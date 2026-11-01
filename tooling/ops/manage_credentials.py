#!/usr/bin/env python3
"""Provisionamento e gestão de credenciais, responsáveis por cartilha e vínculos de turma."""
from __future__ import annotations

import argparse
import datetime
import json
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth import AuthService, password_hash
from app.config import Settings
from app.context_memberships import bind_membership, bind_student
from app.database import Database
from app.models import (
    ClassEnrollment,
    ClassMonitor,
    Classroom,
    Course,
    CourseVersion,
    Enrollment,
    Institution,
    Program,
    ProgramCourse,
    ProgramMembership,
    User,
)


def make_valid_cpf(base9: str) -> str:
    digits = [int(c) for c in base9]
    assert len(digits) == 9
    s1 = sum(d * w for d, w in zip(digits, range(10, 1, -1)))
    d1 = (s1 * 10) % 11
    if d1 == 10:
        d1 = 0
    digits.append(d1)
    s2 = sum(d * w for d, w in zip(digits, range(11, 1, -1)))
    d2 = (s2 * 10) % 11
    if d2 == 10:
        d2 = 0
    digits.append(d2)
    return "".join(str(d) for d in digits)


COURSE_OWNERS_SPEC = [
    ("agricultura-sustentavel", "310101001", "Prof. Resp. Agricultura Sustentável", "Turma 2026 Agricultura Sustentável"),
    ("aspectos-juridicos-startups", "310101002", "Prof. Resp. Aspectos Jurídicos (PEQUI-UFT/Finep)", "Turma 2026 Aspectos Jurídicos para Startups (PEQUI-UFT)"),
    ("atendimento-cliente", "310101003", "Prof. Resp. Atendimento ao Cliente", "Turma 2026 Atendimento ao Cliente"),
    ("audiovisual", "310101004", "Prof. Resp. Audiovisual para o Dia a Dia", "Turma 2026 Audiovisual para o Dia a Dia"),
    ("cooperativismo", "310101005", "Prof. Resp. Cooperativismo e Crédito", "Turma 2026 Cooperativismo e Crédito"),
    ("economia-lar", "310101006", "Prof. Resp. Economia do Lar", "Turma 2026 Economia do Lar"),
    ("educacao-financeira", "310101007", "Prof. Resp. Educação Financeira", "Turma 2026 Educação Financeira"),
    ("ia-cartilha", "310101008", "Prof. Resp. Inteligência Artificial e Inclusão Digital", "Turma 2026 Inteligência Artificial e Inclusão Digital"),
    ("politicas-publicas-agricultura-familiar", "310101009", "Prof. Resp. Agricultura Familiar e Políticas Públicas", "Turma 2026 Agricultura Familiar e Políticas Públicas"),
    ("saf", "310101010", "Prof. Resp. Sistemas Agroflorestais (SAF)", "Turma 2026 Sistemas Agroflorestais (SAF)"),
    ("sim-sima", "310101011", "Prof. Resp. Inspeção e Certificação (SIM/SIMA)", "Turma 2026 Inspeção e Certificação (SIM/SIMA)"),
]

ROLE_ACCOUNTS_SPEC = [
    ("student_demo", "320202001", "Aluno TDS Demonstração", "student", "student", "Tds@Aluno2026!"),
    ("monitor_geral", "320202002", "Monitor TDS Geral (Tutoria)", "monitor", "monitor", "Tds@Monitor2026!"),
    ("coordinator_geral", "320202003", "Coordenador Geral TDS (Revisão/Gestão)", "coordinator", "coordinator", "Tds@Coord2026!"),
    ("creator_geral", "320202004", "Editor de Conteúdo TDS (PEQUI-UFT)", "creator", "creator", "Tds@Creator2026!"),
    ("operator_geral", "320202005", "Operador de Programa TDS (Matrículas)", "program_operator", "program_operator", "Tds@Operador2026!"),
    ("finance_geral", "320202006", "Gestor Financeiro TDS", "finance", "finance", "Tds@Finance2026!"),
    ("admin_geral", "320202007", "Administrador Institucional TDS", "admin", "admin", "Tds@Admin2026!"),
]


def upsert_user(
    session: Session,
    auth: AuthService,
    *,
    cpf: str,
    name: str,
    phone: str,
    password: str,
    global_role: str,
) -> User:
    digest = auth._cpf_digest(cpf)
    user = session.scalar(select(User).where(User.cpf_digest == digest))
    if user is None:
        user = User(
            id=str(uuid4()),
            cpf_digest=digest,
            phone=phone,
            name=name,
            password_digest=password_hash.hash(password),
            role=global_role,
        )
        session.add(user)
        session.flush()
    else:
        user.name = name
        user.phone = phone
        user.password_digest = password_hash.hash(password)
        user.role = global_role
        session.flush()
    return user


def upsert_program_membership(
    session: Session, program_id: str, user_id: str, role: str
) -> ProgramMembership:
    pm = session.scalar(
        select(ProgramMembership).where(
            ProgramMembership.program_id == program_id,
            ProgramMembership.user_id == user_id,
        )
    )
    if pm is None:
        pm = ProgramMembership(
            user_id=user_id,
            program_id=program_id,
            role=role,
            status="active",
        )
        session.add(pm)
    else:
        pm.role = role
        pm.status = "active"
    session.flush()
    return pm


def ensure_student_enrolled(
    session: Session,
    program_id: str,
    classroom: Classroom,
    user_id: str,
) -> None:
    enrollment = session.scalar(
        select(Enrollment).where(
            Enrollment.user_id == user_id,
            Enrollment.program_id == program_id,
            Enrollment.course_id == classroom.course_id,
        )
    )
    if enrollment is None:
        enrollment = Enrollment(
            id=str(uuid4()),
            user_id=user_id,
            program_id=program_id,
            course_id=classroom.course_id,
            status="active",
        )
        session.add(enrollment)
        session.flush()
    else:
        enrollment.status = "active"
        session.flush()

    link = session.scalar(
        select(ClassEnrollment).where(
            ClassEnrollment.class_id == classroom.id,
            ClassEnrollment.user_id == user_id,
        )
    )
    if link is None:
        link = ClassEnrollment(
            class_id=classroom.id,
            user_id=user_id,
            enrollment_id=enrollment.id,
            program_id=program_id,
            course_id=classroom.course_id,
            status="active",
        )
        session.add(link)
        session.flush()
    else:
        link.enrollment_id = enrollment.id
        link.status = "active"
        session.flush()

    bind_student(session, classroom, link)


def cmd_provision_all(session: Session, settings: Settings) -> None:
    auth = AuthService(session, settings)
    program = session.scalars(select(Program)).first()
    if program is None:
        inst = session.scalars(select(Institution)).first()
        if inst is None:
            inst = Institution(id=str(uuid4()), name="Universidade Federal do Tocantins — PEQUI/UFT & IPEX")
            session.add(inst)
            session.flush()
        program = Program(id=str(uuid4()), institution_id=inst.id, name="Programa TDS 2026 — UFT/IPEX")
        session.add(program)
        session.flush()

    role_users = {}
    role_rows = []
    for key, base9, name, g_role, p_role, pwd in ROLE_ACCOUNTS_SPEC:
        cpf = make_valid_cpf(base9)
        user = upsert_user(
            session,
            auth,
            cpf=cpf,
            name=name,
            phone="63999000001",
            password=pwd,
            global_role=g_role,
        )
        upsert_program_membership(session, program.id, user.id, p_role)
        role_users[key] = (user, cpf, pwd)
        role_rows.append({
            "case": key,
            "name": name,
            "cpf": cpf,
            "password": pwd,
            "global_role": g_role,
            "program_role": p_role,
            "user_id": user.id,
        })

    rafael_cpf = "06081173151"
    rafael_digest = auth._cpf_digest(rafael_cpf)
    rafael = session.scalar(select(User).where(User.cpf_digest == rafael_digest))
    if rafael is not None:
        upsert_program_membership(session, program.id, rafael.id, "student")

    course_rows = []
    for idx, (course_id, base9, teacher_name, class_name) in enumerate(COURSE_OWNERS_SPEC, start=1):
        course = session.get(Course, course_id)
        if course is None:
            continue
        version = session.scalar(
            select(CourseVersion)
            .where(CourseVersion.course_id == course_id, CourseVersion.status == "published")
            .order_by(CourseVersion.version_number.desc())
        )
        if version is None:
            continue

        cpf = make_valid_cpf(base9)
        pwd = f"Tds@Prof{idx:02d}2026!"
        teacher = upsert_user(
            session,
            auth,
            cpf=cpf,
            name=teacher_name,
            phone=f"639991000{idx:02d}",
            password=pwd,
            global_role="teacher",
        )
        upsert_program_membership(session, program.id, teacher.id, "teacher")

        offering = session.scalar(
            select(ProgramCourse).where(
                ProgramCourse.program_id == program.id,
                ProgramCourse.course_id == course_id,
            )
        )
        if offering is None:
            offering = ProgramCourse(
                program_id=program.id,
                course_id=course_id,
                planned_seconds=7200,
            )
            session.add(offering)
        else:
            offering.planned_seconds = 7200
        session.flush()

        classroom = session.scalar(
            select(Classroom).where(
                Classroom.program_id == program.id,
                Classroom.course_id == course_id,
            )
        )
        if classroom is None:
            classroom = Classroom(
                id=str(uuid4()),
                program_id=program.id,
                course_id=course_id,
                course_version_id=version.id,
                teacher_id=teacher.id,
                name=class_name,
                offer_municipality="Palmas / Tocantins",
                offer_location="EAD / Híbrido (PEQUI-UFT / TDS)",
                start_date=datetime.date(2026, 1, 1),
                end_date=datetime.date(2026, 12, 31),
                status="active",
            )
            session.add(classroom)
            session.flush()
        else:
            classroom.course_version_id = version.id
            classroom.teacher_id = teacher.id
            classroom.name = class_name
            classroom.status = "active"
            session.flush()

        bind_membership(session, classroom.id, teacher.id, "teacher", "active")

        monitor_user = role_users["monitor_geral"][0]
        cm = session.scalar(
            select(ClassMonitor).where(
                ClassMonitor.class_id == classroom.id,
                ClassMonitor.user_id == monitor_user.id,
            )
        )
        if cm is None:
            session.add(
                ClassMonitor(
                    class_id=classroom.id,
                    user_id=monitor_user.id,
                    program_id=program.id,
                )
            )
            session.flush()
        bind_membership(session, classroom.id, monitor_user.id, "monitor", "active")

        ensure_student_enrolled(session, program.id, classroom, role_users["student_demo"][0].id)
        if rafael is not None:
            ensure_student_enrolled(session, program.id, classroom, rafael.id)

        course_rows.append({
            "course_id": course_id,
            "course_title": course.title,
            "version_id": version.id,
            "class_id": classroom.id,
            "class_name": classroom.name,
            "teacher_name": teacher.name,
            "teacher_cpf": cpf,
            "teacher_password": pwd,
            "teacher_user_id": teacher.id,
        })

    session.commit()
    print(json.dumps({"role_accounts": role_rows, "course_owners": course_rows}, ensure_ascii=False, indent=2))


def cmd_set_password(
    session: Session,
    settings: Settings,
    *,
    cpf: str,
    new_password: str,
    new_cpf: str | None = None,
    name: str | None = None,
    role: str | None = None,
) -> None:
    if len(new_password) < 12:
        raise SystemExit("Erro: a senha precisa ter pelo menos 12 caracteres.")
    auth = AuthService(session, settings)
    digest = auth._cpf_digest(cpf)
    user = session.scalar(select(User).where(User.cpf_digest == digest))
    if user is None:
        raise SystemExit(f"Erro: nenhum usuário encontrado para o CPF {cpf}.")
    user.password_digest = password_hash.hash(new_password)
    if new_cpf:
        user.cpf_digest = auth._cpf_digest(new_cpf)
    if name:
        user.name = name
    if role:
        user.role = role
        for pm in session.scalars(select(ProgramMembership).where(ProgramMembership.user_id == user.id)):
            pm.role = role
    session.commit()
    print(f"[OK] Credenciais atualizadas para {user.name} (id={user.id}, role={user.role}).")


def cmd_set_course_owner(
    session: Session,
    settings: Settings,
    *,
    course_id: str,
    cpf: str,
) -> None:
    auth = AuthService(session, settings)
    digest = auth._cpf_digest(cpf)
    user = session.scalar(select(User).where(User.cpf_digest == digest))
    if user is None:
        raise SystemExit(f"Erro: usuário com CPF {cpf} não encontrado.")
    user.role = "teacher"
    for classroom in session.scalars(select(Classroom).where(Classroom.course_id == course_id)):
        upsert_program_membership(session, classroom.program_id, user.id, "teacher")
        classroom.teacher_id = user.id
        bind_membership(session, classroom.id, user.id, "teacher", "active")
    session.commit()
    print(f"[OK] Responsável pela cartilha {course_id} atualizado para {user.name} (CPF {cpf}).")


def main() -> None:
    parser = argparse.ArgumentParser(description="Gestão de contas e responsáveis por cartilha no Tutor TDS.")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("provision-all", help="Provisiona contas por papel e 1 responsável para cada cartilha.")

    p_pwd = sub.add_parser("set-password", help="Altera senha (e opcionalmente CPF/nome/papel) de uma conta.")
    p_pwd.add_argument("--cpf", required=True, help="CPF atual da conta (somente números ou formatado)")
    p_pwd.add_argument("--new-password", required=True, help="Nova senha (mínimo 12 caracteres)")
    p_pwd.add_argument("--new-cpf", help="Novo CPF opcional")
    p_pwd.add_argument("--name", help="Novo nome opcional")
    p_pwd.add_argument("--role", help="Novo papel opcional (student, monitor, teacher, coordinator, creator, program_operator, finance, admin)")

    p_own = sub.add_parser("set-course-owner", help="Define o professor responsável por uma cartilha.")
    p_own.add_argument("--course-id", required=True, help="ID da cartilha (ex.: aspectos-juridicos-startups)")
    p_own.add_argument("--cpf", required=True, help="CPF do professor responsável")

    args = parser.parse_args()
    settings = Settings.from_environment()
    db = Database(settings.database_url)
    try:
        with Session(db.engine) as session:
            if args.cmd == "provision-all":
                cmd_provision_all(session, settings)
            elif args.cmd == "set-password":
                cmd_set_password(
                    session,
                    settings,
                    cpf=args.cpf,
                    new_password=args.new_password,
                    new_cpf=args.new_cpf,
                    name=args.name,
                    role=args.role,
                )
            elif args.cmd == "set-course-owner":
                cmd_set_course_owner(session, settings, course_id=args.course_id, cpf=args.cpf)
    finally:
        db.dispose()


if __name__ == "__main__":
    main()

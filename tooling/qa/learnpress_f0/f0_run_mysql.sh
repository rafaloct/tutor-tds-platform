#!/usr/bin/env bash
# F0b — mesma suíte do f0_run.sh, com ids remapeados para a instância MySQL
# (course 23→11, lesson 24→12, quiz 26→14, question 27→15).
# Uso: source f0_env.sh && BASE=http://127.0.0.1:18732 bash f0_run_mysql.sh
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sed 's/"course_id":23/"course_id":11/g; s/"id":24/"id":12/g; s/"id":26/"id":14/g; s/"question_id":27/"question_id":15/g; s/courses\/23/courses\/11/g; s/lessons\/24/lessons\/12/g; s/lessons\/25/lessons\/13/g' "$DIR/f0_run.sh" > /tmp/f0_run_mysql_gen.sh
exec bash /tmp/f0_run_mysql_gen.sh

# Preflight curricular offline do Tutor IA

Este preflight confere as nove cartilhas legadas antes de qualquer ingestão RAG.
Ele lê arquivos locais e produz um manifesto; não acessa Drive, AnythingLLM,
Worker, banco ou ambiente remoto.

## Fontes e estado da revisão

`curricular_source_map.json` une, por `course_id`, os nove JSONs Flutter em
`cartilhas_app/assets/data/lessons/` às URLs e aos originais locais registrados
em `docs/production/evidence/course-pdf-hosting-2026-10-01.json`. A junção é
explícita: as listas na evidência têm ordens diferentes e vários nomes de PDF
não são iguais aos títulos das aulas. O mapa fixa SHA-256 do JSON, nome,
tamanho e SHA-256 do **original histórico** de cada PDF, além do ID e URL do
visualizador do Drive. Nenhum PDF está versionado neste repositório.

A auditoria de hospedagem recebeu páginas HTML `200` do visualizador; ela não
validou os bytes de PDF servidos pelo Drive. A metadata autenticada de IA
registrou MIME e tamanho, sem SHA-256. O mapa foi reconciliado com essas
evidências, mas não registra aprovação editorial humana nem versão implantada
no banco atual.

## Entradas do operador

1. Exportar cada uma das nove CourseVersions **publicadas** da fonte
   autoritativa com `python -m app.course_promotion export`, em modo de leitura.
   Nomear cada saída `<course_id>.json` no diretório de exports. O export contém
   SHA-256 próprio e preserva `course_version_id` legado apenas quando coincide
   exatamente com `version_id`.
2. Fornecer os nove PDFs em um diretório local, com os nomes exatos do mapa.
   Registrar separadamente a custódia/proveniência desses arquivos. O preflight
   consegue conferir bytes locais contra o hash histórico; ele não sabe se os
   bytes foram baixados do Drive nem se o Drive ainda entrega o mesmo objeto.
3. Executar de dentro do repositório:

```bash
python tooling/ai_qa/curricular_rag_preflight.py \
  --exports-dir /caminho/exports-publicados \
  --pdf-root /caminho/pdfs-operador \
  --output /caminho/novo-manifesto-rag.json
```

O destino precisa ser um arquivo inexistente em diretório já existente. O
programa recusa sobrescrever evidência. O mesmo conjunto de entradas produz os
mesmos bytes de manifesto; não há timestamp nem caminho local na saída.

## O que é verificado

- Exatamente nove linhas distintas no mapa e nove exports esperados;
- hash da auditoria de hospedagem, hash de cada JSON de aulas, IDs, versão e URL
  canônica do Drive;
- formato e digest do export, `course_id`, `version_id`, `course_version_id`
  embutido, URL e equivalência do conteúdo curricular com o JSON revisado;
- nome, tamanho, assinatura `%PDF-`/`%%EOF` e SHA-256 dos PDFs locais;
- workspace **proposto** exclusivo por CourseVersion;
- ausência de travessia de caminho, links simbólicos, chaves JSON duplicadas e
  nomes/IDs/fontes duplicados.

O manifesto distingue `historical_original_pdf` de `operator_local_pdf` e
mantém `drive_bytes_provenance_verified=false`, `anythingllm_indexed=false` e
`editorial_approval_verified=false`. `verified_local_only` não autoriza usar
os workspaces propostos no Worker.

## O que falta para ingestão e aula real

Confirmar no banco autorizado que os exports representam as edições publicadas
que serão usadas pelas turmas; obter aprovação editorial de cada original;
provar a proveniência e hash dos bytes efetivamente entregues pelo Drive;
ingerir em workspaces isolados de staging; obter recibos de indexação e executar
sentinelas A/B. O registry RAG permanente, o isolamento por módulo/experiência
e a promoção para produção continuam fora deste preflight.

## Testes locais

```bash
python -m unittest discover -s tooling/ai_qa -p 'test_curricular_rag_preflight.py'
cd api && uv run --locked --extra test python -m pytest tests/test_course_promotion.py
```

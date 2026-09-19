# Validação da Linha de Base

Data: 2026-09-19

## Ambiente

- Flutter isolado: `C:\Users\Usuario\flutter-3.44.9`
- Dart: 3.12.2
- Junction curto: `C:\Dev\tutor-tds`
- Motivo do junction: o caminho original com espaços, acentos e parênteses interrompeu o protocolo LSP do analyzer.

## Resultados

| Verificação | Resultado |
|---|---|
| `flutter pub get` | OK |
| `flutter analyze` | OK, zero issues |
| `flutter test` | OK, 14 testes |
| Gateway `npm test` | OK, 14 testes |
| Web auxiliar `npm run lint` | OK |
| Web auxiliar `npm run build` | OK |
| Web auxiliar `npm audit --omit=dev` | zero vulnerabilidades de produção |
| Busca local por `deepseek` | nenhuma referência no código/configuração versionável |

As dependências não foram atualizadas. Pacotes com versões mais novas permanecem congelados para evitar regressão fora do escopo.

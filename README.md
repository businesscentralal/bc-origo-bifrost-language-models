# Evidence: language-models PR #122 at 6e7d36a59fd62c66d230d76935098fc781178002 (Nár / worker-26)
Environment: own local BC 29 tenant w129-36 (CRONUS International Ltd.), Foundation 28.0.13.0, Language Models dev build of 6e7d36a (tests/artifacts-sha256.txt).
- tests/full-6e7d36a.json: full 96000..96199 run 1, 507/1/0 (96028 baseline)
- tests/full2-6e7d36a.json: run 2 after fresh deploy of the same SHA, 506/2/0 (96028 baseline, 96037 tenant licence user cap)
- tests/main-96028.json: 96028 on unmodified main e267633, the same failure
- tests/t96067-4.json: new codeunit 96067, 19/0/0
- ui/: page 10035421 in 1033 (setup-en-*) and 1039 (setup-is-*), cap saved, 1000 refused
- mcp/: 01 help, 02 Help.Implementation.Get (cap 50), 03 seed model, 04-09 LLM.Prompt.Ask scenarios, 10 help after UI (cap 120), 11 cleanup

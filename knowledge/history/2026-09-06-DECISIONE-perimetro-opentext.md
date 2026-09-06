# 2026-09-06 — DECISIONE: il dominio riservato del datore di lavoro resta nel perimetro

## Domanda posta a Raf (AUDIT-001 / PLAN-001 §D-11)
Il dominio del datore di lavoro contiene informazione riservata aziendale. Nella nostra architettura vivrebbe su un
VPS Hostinger dove gira `monarx-agent` **come root**. Precisazione data a Raf: la cifratura a riposo **non protegge
da questo** — un processo root vede i dati in chiaro nel momento in cui la pipeline li elabora. Non è un difetto
correggibile, è una proprietà del luogo in cui abbiamo scelto di girare.

Domanda: la policy del datore di lavoro consente che quel materiale risieda su un VPS personale di un fornitore terzo?

## Decisione di Raf
**Nessun problema di policy.** Il dominio resta **dentro** il perimetro di WorkBrain.
Contestualmente Raf ha posto un requisito: *"in ogni caso facciamo in modo che la piattaforma che costruiamo sia sicura"*.

## Conseguenze operative
- **Nessun cambio di architettura**: classificazione, `sync-plaud` e modello del vault restano come progettati.
  La domanda era bloccante proprio perché una risposta negativa avrebbe cambiato l'architettura, non la configurazione.
- **`monarx-agent` resta** e non si tocca (è infrastruttura del fornitore; rimuoverlo potrebbe violare le condizioni
  di hosting). Resta documentato in `docs/05-infrastruttura-vps.md` come fatto noto e accettato, non come svista.
- **La segregazione fra domini resta inviolabile.** Questa decisione riguarda *dove vivono i dati*, non *se i domini
  si possono mescolare*: la risposta a quest'ultima resta no. Vedi `.claude/rules/domini-riservatezza.md`.
- Il requisito "sicura" non resta un aggettivo: si traduce nelle scelte già prese in PLAN-001 (D-01 rootless,
  D-03 confini per step, D-04 gate al commit) e nelle aggiunte di [[2026-09-06-DECISIONE-prodotto-futuro]].

## Riferimenti
`reports/PLAN-001-consolidamento-infrastruttura.md` §D-11 · `reports/AUDIT-001-infrastruttura-e-harness.md` R-06 ·
[[2026-09-06-DECISIONE-prodotto-futuro]]

# 2026-09-05 — DECISIONE: nessuna subscription Plaud, Plaud = solo trasporto

## Decisione (Raf, §2.1)
Nessuna subscription Plaud. Il piano gratuito dà 300 min/mese di trascrizione; non ci contiamo. **Plaud serve solo come
trasporto dell'audio**: device → cloud Plaud → `plaud audio <id>`. La trascrizione/summary Plaud, quando c'è, vale solo
come **benchmark** da battere.

## Perché
- I volumi e la qualità richiesti (diarizzazione, glossario, correzione termini) superano il piano gratuito.
- Test del 2026-09-05: Plaud sbaglia i termini tecnici ("Claude"→"Cloud", "npm"→"NMP", "Plaud me"→"PlanMe") e il summary
  propaga l'errore. Non è affidabile come sorgente di verità.

## Come si applica
- La skill `sync-plaud` scarica audio + `plaud-transcript` **come benchmark**, mai come sorgente finale.
- La verità la produce la nostra STT (BRIEF-001) con glossario di dominio + step di correzione (vedi `schema-kb.md`).
- Non attivare né suggerire subscription Plaud senza una nuova decisione di Raf.

## Riferimenti
[[2026-09-05-DECISIONE-stt-api-diarizzazione]] · [[2026-09-05-bootstrap-harness]] · `.claude/skills/sync-plaud/SKILL.md`

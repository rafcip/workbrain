# 2026-09-05 — DECISIONE: STT via API con diarizzazione (non self-hosted)

## Decisione (Raf, §2.2)
La trascrizione **speech-to-text con diarizzazione** si fa via **API di un provider**, non self-hosted sul VPS (troppo
piccolo). Il provider specifico si sceglie con **misure reali** in BRIEF-001. Preferenza: **residenza dati EU**, clausola
**no-training**, supporto a **glossario/keyterms**.

## Perché
- VPS piccolo, single-user: ospitare modelli STT+diarizzazione localmente non è proporzionato.
- La qualità sui termini tecnici e la diarizzazione affidabile richiedono provider maturi.
- Riservatezza: EU + no-training sono vincoli, non nice-to-have (domini `legal-agency`/`opentext`).

## Come si applica
- BRIEF-001 §0.4: prova 2-3 provider sugli stessi 3 campioni (IT/EN/mista) e misura costo/tempo/WER/diarizzazione/glossario.
- La scelta pesa **prima** i vincoli di riservatezza (EU/no-training), **poi** WER/costo.
- La configurazione del provider e il glossario per dominio vivono in `env.prod`/`/srv/workbrain` (fuori dal repo).

## Riferimenti
[[2026-09-05-DECISIONE-no-subscription-plaud]] · [[2026-09-05-DECISIONE-bilingue-no-traduzione]] · `reports/BRIEF-001-analisi-soluzione.md`

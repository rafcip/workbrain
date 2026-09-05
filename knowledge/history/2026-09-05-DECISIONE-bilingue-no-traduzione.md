# 2026-09-05 — DECISIONE: bilingue IT/EN senza traduzione

## Decisione (Raf, §2.3)
Le note restano **nella lingua della registrazione** (niente traduzione automatica). La **struttura** (chiavi di
frontmatter, sezioni, tassonomia) è in **inglese canonico**. La **ricerca cross-lingua** avviene via **embedding
multilingue** (una query in IT trova una nota in EN e viceversa) senza tradurre il contenuto.

## Perché
- Tradurre introduce errori e perdita di sfumature; il contenuto originale è la verità.
- Chiavi/struttura in inglese danno uno schema stabile e interoperabile; il contenuto resta autentico.
- L'embedding multilingue dà ricerca cross-lingua senza il costo/rischio della traduzione.

## Come si applica
- `schema-kb.md`: chiavi in inglese, `lang` nel frontmatter (it|en|mixed), valori/contenuto nella lingua originale.
- BRIEF-001 §0.5: misurare il recall@k cross-lingua del modello di embedding scelto.
- Non introdurre step di traduzione nella pipeline senza una nuova decisione di Raf.

## Riferimenti
[[2026-09-05-DECISIONE-stt-api-diarizzazione]] · `.claude/rules/schema-kb.md` · `docs/02-architettura-target.md`

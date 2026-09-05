# Regola: domini e riservatezza (INVIOLABILE)

La segregazione dei domini è **non negoziabile**, anche a costo di più lavoro (decisione di Raf, §2.4 del brief).
Ogni informazione ha **un solo** proprietario/dominio. Non si mescolano, non si travasano, non si citano a vicenda.

## Domini
| dominio | proprietario dell'informazione | note di riservatezza |
|---|---|---|
| `legal-agency` | Raf imprenditore (Legal Agency Srl) | può contenere **PII di clienti** dello studio → mai nei documenti di progetto |
| `opentext`     | Raf PM AI in OpenText | informazione **riservata di un datore di lavoro** → mai nei documenti di progetto, mai mescolata |
| `personal`     | Raf (formazione, idee trasversali) | riservatezza normale |
| `inbox`        | stato transitorio | ciò che la pipeline non classifica con sicurezza |

## Regole dure (le fa rispettare anche un hook — vedi .claude/hooks/)
1. **Mai** contenuti reali `opentext` (testo di meeting, nomi, progetti interni) in `docs/`, `reports/`, `tests/`, o in un commit.
   L'hook `block-opentext.sh` blocca la scrittura di marker di dominio `opentext` in quei percorsi.
2. **Mai** PII di clienti dello studio legale in alcun file del repo.
3. **Mai** mescolare `opentext` e `legal-agency` nello stesso artefatto, indice, o risultato di query.
4. Colonna `domain` **obbligatoria** in ogni riga del DB SSOT e in ogni frontmatter del vault; **filtrata in ogni query**.
5. I dati veri vivono **fuori dal repo** in `/srv/workbrain/{raw,vault,db}`, con separazione per dominio nei path.

## Classificazione (honest-act sopra honest-uncertainty)
- Con **segnali convergenti** (evidence multipla) → classifica nel dominio.
- In **dubbio** → `inbox` + notifica a Raf. **Mai** forzare un dominio per far passare un job.
- La classificazione la **propone** il modello con `confidence` + `evidence`; il filtro/segregazione è **codice** deterministico.

## Esempi ammessi vs vietati nei documenti di progetto
- ✅ Ammesso: "il dominio `opentext` esiste e ha regole X" (metadato, struttura).
- ❌ Vietato: riportare il contenuto di un meeting OpenText, un nome cliente dello studio, un progetto interno reale.

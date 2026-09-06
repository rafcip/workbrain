# 2026-09-06 — DECISIONE: WorkBrain nasce personale ma con fondamenta da prodotto

## Decisione di Raf
> *"Un'idea futura è di trasformarla in un prodotto da commercializzare, quindi dobbiamo cominciare a mettere le
> fondamenta anche se in questo momento abbiamo uno scopo solo di WorkBrain personale."*

Scopo **attuale**: strumento personale, utente singolo (Raf). Scopo **possibile**: prodotto commercializzato.
Nessun impegno di tempi, nessun requisito di prodotto da soddisfare oggi.

## Come la interpreto (e cosa NON faccio)

**Non costruisco un prodotto adesso.** Costruire multi-tenancy, autenticazione, billing e pannelli per un utente
solo sarebbe lavoro sprecato e contrario ai principi del progetto (misure prima delle opinioni; non ottimizzare
prima di avere numeri). Sarebbe anche il modo più veloce per non finire mai WorkBrain.

**Quello che faccio è distinguere le porte a senso unico da quelle a doppio senso.** Alcune scelte, se prese oggi
in modo "personale", costano poco a cambiare domani. Altre si infilano in ogni riga di codice e in ogni riga del
database, e cambiarle dopo significa riscrivere e migrare. Solo su queste ultime pago il piccolo prezzo di
progettarle già compatibili con un prodotto.

### Porte a senso unico — decido adesso in modo compatibile con un prodotto
1. **Identificatore di proprietario nel modello dati.** Ogni riga del DB SSOT e ogni frontmatter portano un `owner`
   (oggi: sempre lo stesso valore, uno). È una colonna in più oggi; è una migrazione di ogni tabella e la revisione
   di **ogni query** domani. Nota: `owner` è ortogonale a `domain` e **non lo sostituisce** — `domain` resta
   obbligatorio e filtrato in ogni query (`.claude/rules/domini-riservatezza.md`).
2. **Motore del DB.** Impatta direttamente `reports/BRIEF-001-analisi-soluzione.md` decisione #2, ancora aperta: il
   default "SQLite+sqlite-vec" era motivato **da utente singolo**. Con un prodotto all'orizzonte il criterio cambia
   e va ripesato con le misure, non per principio. Vedi §Impatto su BRIEF-001.
3. **Tassonomia dei domini configurabile, non cablata.** I quattro domini di Raf sono *dati di configurazione*, non
   un `enum` nel codice. Oggi non cambia nulla; domani evita di riscrivere il classificatore.
4. **Vincoli legali sui fornitori.** L'uso commerciale non è l'uso personale: servono *residenza EU*, *no-training*,
   **e** una licenza che consenta l'uso commerciale (vale anche per i pesi dei modelli, dove alcune licenze sono
   esplicitamente non-commerciali). Diventa un criterio **di esclusione** in BRIEF-001, non una preferenza.
5. **Segreti con ambito.** I segreti nascono già "appartenenti a qualcuno", anche se oggi il qualcuno è uno solo:
   niente chiavi globali sparse assunte come uniche.
6. **Registro degli accessi.** Chi/cosa ha letto quali dati, dal primo giorno. Costa poco scriverlo subito, è
   impossibile ricostruirlo a posteriori, ed è un requisito sia di sicurezza sia di conformità.

### Porte a doppio senso — restano semplici, si decidono quando serviranno
Interfaccia utente, superficie API, provider di identità, billing, topologia di deploy, orchestrazione multi-nodo.
Tutte rinviate senza rimpianti: cambiarle domani costa quanto costerebbe oggi.

## Conseguenza che va detta chiara: cambia il ruolo rispetto al GDPR
Oggi Raf tratta **i propri** dati: nessun obbligo verso terzi. Come prodotto, WorkBrain tratterebbe **registrazioni
di altre persone** — cioè diventerebbe *responsabile del trattamento* per conto dei clienti, con obblighi concreti:
accordo sul trattamento con ogni **sub-responsabile** (in primis il provider STT), residenza dei dati, cancellazione
su richiesta, politiche di conservazione, notifica delle violazioni.

Non si implementa nulla di tutto ciò adesso. Ma **la scelta del provider STT sì**: se un fornitore non offre
condizioni contrattuali adatte a un uso commerciale, sceglierlo oggi significa doverlo cambiare — e rifare le
misure — il giorno in cui la domanda diventa reale.

## Impatto su BRIEF-001 (da riprendere quando si eseguono le misure)
- **Decisione #1 (provider STT)**: aggiungere ai criteri *uso commerciale consentito* e *disponibilità di un accordo
  sul trattamento dati*. Da criterio preferenziale a criterio **eliminatorio**.
- **Decisione #2 (motore DB)**: il default motivato da utente singolo va ripesato. Non lo cambio per principio:
  lo si decide con le misure, aggiungendo però al confronto il costo di una migrazione futura.
- **Decisione #3 (embedding)**: verificare la licenza del modello per uso commerciale, non solo qualità e costo.
- **Schema KB** (`.claude/rules/schema-kb.md`): aggiungere `owner` fra le chiavi canoniche del frontmatter e come
  colonna del DB. Lo schema è BOZZA e si consolida in F3/F4: è il momento giusto, non ci sono ancora dati da migrare.

## Cosa NON cambia
Il piano di consolidamento (`PLAN-001`) resta valido così com'è: rootless, confini per step, gate al commit e
backup sono **le stesse fondamenta** che servono a uno strumento personale sicuro e a un prodotto. Nessuna fase va
riscritta; si aggiunge §D-12 al piano.

## Riferimenti
[[2026-09-06-DECISIONE-perimetro-opentext]] · `reports/PLAN-001-consolidamento-infrastruttura.md` §D-12 ·
`reports/BRIEF-001-analisi-soluzione.md` · `.claude/rules/schema-kb.md`

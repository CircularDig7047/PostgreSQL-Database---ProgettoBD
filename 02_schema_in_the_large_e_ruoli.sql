--- PARTE III 

/*************************************************************************************************************************************************************************/ 
--1b. Schema per popolamento in the large
/*************************************************************************************************************************************************************************/ 


/* per ogni relazione R coinvolta nel carico di lavoro, inserire qui i comandi SQL per creare una nuova relazione R_CL con schema equivalente a R ma senza vincoli di chiave primaria, secondaria o esterna e con eventuali attributi dummy */

BEGIN;

CREATE SCHEMA toogoodatuni_cl;
SET search_path TO toogoodatuni_cl;

CREATE TABLE utente_CL (
    username varchar(32), 
    email varchar(64), 
    nome varchar(16), 
    cognome varchar(16), 
    account_attivo boolean, 
    data_reg date, 
    num_telefono varchar(12), 
    ruolo varchar(20), 
    nome_esercizio_gestito varchar(32), 
    dummy char(2000)
);

CREATE TABLE ordine_CL (
    id_ordine smallint, 
    data_ora_prenot timestamp, 
    prezzo_pagato decimal(5,2), 
    quantita decimal(3), 
    stato varchar(24), 
    id_offerta smallint, 
    id_slot smallint, 
    username_studente varchar(32), 
    dummy char(2000)
);

CREATE TABLE sede_CL (
    id smallint, 
    nome varchar(32), 
    rif_amm varchar(24), 
    coord varchar(64), 
    via varchar(32), 
    cap varchar(8), 
    comune varchar(16), 
    dummy char(2000)
);

CREATE TABLE convenzione_CL (
    id_convenzione smallint, 
    data_inizio_val date, 
    data_fine_val date, 
    tipologia varchar(32), 
    mod_ritiro varchar(16), 
    stato_conv varchar(16), 
    perc_sconto_min decimal(5,2), 
    commissione_ateneo decimal(5,2), 
    soglia_pubb decimal(3), 
    id_sede smallint, 
    id_fornitore varchar(32), 
    username_collaboratore varchar(32), 
    dummy char(2000)
);

COMMIT;


/*************************************************************************************************************************************************************************/
--1c. Carico di lavoro
/*************************************************************************************************************************************************************************/ 

/* 
    Q1: Query con singola selezione e nessun join 
    Seleziona tutti gli username degli studenti registrati.
*/

/* 
    Q2: Query con condizione di selezione complessa e nessun join 
    Seleziona gli ordini dove il prezzo pagato e maggiore di 10, la quantita minore di 5 e lo stato e pagato, ritirato o prenotato.
*/

/* 
    Q3: Query con almeno un join e almeno una condizione di selezione 
    Seleziona le coordinate delle sedi con almeno una convenzione attiva.
*/

/*************************************************************************************************************************************************************************/ 
/* Q1: Query con singola selezione e nessun join */
/*************************************************************************************************************************************************************************/ 

/* inserire qui il comando SQL corrispondente alla query, in modo da visualizzarne piano di esecuzione e tempo di esecuzione */ 

EXPLAIN ANALYZE 
SELECT username FROM utente_CL WHERE ruolo='studente';


/*************************************************************************************************************************************************************************/ 
/* Q2: Query con condizione di selezione complessa e nessun join */
/*************************************************************************************************************************************************************************/ 

/* inserire qui il comando SQL corrispondente alla query, in modo da visualizzarne piano di esecuzione e tempo di esecuzione */ 

EXPLAIN ANALYZE 
SELECT id_ordine FROM ordine_CL 
WHERE prezzo_pagato > 10 AND quantita < 5 AND stato IN ('pagato', 'ritirato', 'prenotato');


/*************************************************************************************************************************************************************************/ 
/* Q3: Query con almeno un join e almeno una condizione di selezione */
/*************************************************************************************************************************************************************************/ 

/* inserire qui il comando SQL corrispondente alla query, in modo da visualizzarne piano di esecuzione e tempo di esecuzione */ 

EXPLAIN ANALYZE 
SELECT DISTINCT coord FROM sede_CL s JOIN convenzione_CL c ON c.id_sede=s.id 
WHERE c.stato_conv='attiva';


/*************************************************************************************************************************************************************************/
--1e. Schema fisico
/*************************************************************************************************************************************************************************/ 


/* inserire qui i comandi SQL per cancellare tutti gli indici gia esistenti per le tabelle coinvolte nel carico di lavoro */

DROP INDEX IF EXISTS idx_utente_ruolo;
DROP INDEX IF EXISTS idx_ordine_comp;
DROP INDEX IF EXISTS idx_conv_stato;
DROP INDEX IF EXISTS idx_conv_sede;
DROP INDEX IF EXISTS idx_sede_id;


/* inserire qui i comandi SQL per la creazione dello schema fisico della base di dati in accordo al risultato della fase di progettazione fisica per il carico di lavoro. */

CREATE INDEX idx_utente_ruolo ON utente_CL USING BTREE (ruolo);

CREATE INDEX idx_ordine_comp ON ordine_CL USING BTREE (stato, prezzo_pagato);
CLUSTER ordine_CL USING idx_ordine_comp; 

CREATE INDEX idx_conv_stato ON convenzione_CL USING HASH (stato_conv);
CREATE INDEX idx_conv_sede ON convenzione_CL USING BTREE (id_sede);
CREATE INDEX idx_sede_id ON sede_CL USING BTREE (id);


/*************************************************************************************************************************************************************************/ 
--2. Controllo dell'accesso 
/*************************************************************************************************************************************************************************/ 

/* inserire qui i comandi SQL per la definizione della politica di controllo dell'accesso della base di dati (definizione ruoli, gerarchia, definizione utenti, assegnazione privilegi) in modo che, dopo l'esecuzione di questi comandi, le operazioni corrispondenti ai privilegi delegati ai ruoli e agli utenti siano correttamente eseguibili. */

SET search_path TO toogoodatuni;

DROP OWNED BY utente_studente, utente_fornitore, utente_collaboratore, utente_admin CASCADE;
DROP ROLE IF EXISTS utente_studente, utente_fornitore, utente_collaboratore, utente_admin;

DROP OWNED BY ruolo_studente, ruolo_fornitore, ruolo_collaboratore, ruolo_amministratore CASCADE;
DROP ROLE IF EXISTS ruolo_studente, ruolo_fornitore, ruolo_collaboratore, ruolo_amministratore;

CREATE ROLE ruolo_studente;
CREATE ROLE ruolo_fornitore;
CREATE ROLE ruolo_collaboratore;
CREATE ROLE ruolo_amministratore;

GRANT ruolo_collaboratore TO ruolo_amministratore;

GRANT USAGE ON SCHEMA toogoodatuni TO ruolo_studente, ruolo_fornitore, ruolo_collaboratore, ruolo_amministratore;

GRANT SELECT ON Sede, Convenzione, Offerta, Punto_ritiro, Fornitore TO ruolo_studente;
GRANT INSERT, SELECT, UPDATE ON Ordine, Recensione, Pagamento TO ruolo_studente;

GRANT SELECT ON Sede, Convenzione, Offerta, Ordine TO ruolo_fornitore;
GRANT UPDATE ON Convenzione, Offerta TO ruolo_fornitore;

GRANT SELECT, INSERT, UPDATE ON Sede, Convenzione, Offerta, Fornitore, Punto_ritiro TO ruolo_collaboratore;
GRANT SELECT ON Utente, Ordine, Recensione TO ruolo_collaboratore;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA toogoodatuni TO ruolo_amministratore;

CREATE USER utente_studente PASSWORD 'pass123';
CREATE USER utente_fornitore PASSWORD 'pass123';
CREATE USER utente_collaboratore PASSWORD 'pass123';
CREATE USER utente_admin PASSWORD 'pass123';

GRANT ruolo_studente TO utente_studente;
GRANT ruolo_fornitore TO utente_fornitore;
GRANT ruolo_collaboratore TO utente_collaboratore;
GRANT ruolo_amministratore TO utente_admin;

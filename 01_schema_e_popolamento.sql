--- PARTE 2

/*************************************************************************************************************************************************************************/
--1a. Schema
/*************************************************************************************************************************************************************************/

/* inserire qui i comandi SQL per la creazione dello schema logico della base di dati in accordo allo schema relazionale ottenuto alla fine della fase di progettazione logica, per la porzione necessaria per i punti successivi
(cio� le tabelle coinvolte dalle interrogazioni nel carico di lavoro, nella definizione della vista, nelle interrogazioni, in funzioni, procedure e trigger).
Lo schema dovr� essere comprensivo dei vincoli esprimibili con check. */

BEGIN;

CREATE schema toogoodatuni;
set search_path to toogoodatuni;
set datestyle to 'DMY';

create table Fornitore(
    nome_esercizio varchar(32) primary key,
    via varchar(32) not null,
    cap varchar(8) not null,
    comune varchar(16) not null,
    unique (via, cap, comune),
    tipologia varchar(32) not null,
    recapiti_di_contatto varchar(128) not null
);

create table Utente(
    username varchar(32) primary key,
    email varchar(64) unique not null,
    nome varchar(16) not null,
    cognome varchar(16) not null,
    account_attivo boolean not null,
    data_reg date not null,
    num_telefono varchar(12),
    ruolo varchar(20) not null check (ruolo in('studente','referente_fornitore','collaboratore','amministratore')),
    nome_esercizio_gestito varchar(32) references Fornitore(nome_esercizio)
    check(
    (ruolo='referente_fornitore' and nome_esercizio_gestito is not null)
    or
    (ruolo <> 'referente_fornitore' and nome_esercizio_gestito is null)) --<> diverso
);

create table Sede(
    id smallserial primary key,
    nome varchar(32) not null,
    rif_amm varchar(24),
    coord varchar(64) not null check(coord like '%, %'),
    via varchar(32) not null,
    cap varchar(8) not null,
    comune varchar(16) not null,
    unique (via, cap, comune)
);

create table Opera(
    id_fornitore varchar(32) references Fornitore(nome_esercizio),
    id_sede smallint references Sede(id),
    primary key (id_fornitore, id_sede)
);

create table Convenzione(
    id_convenzione smallserial primary key,
    data_inizio_val date not null,
    data_fine_val date,
    tipologia varchar(32) not null,
    CONSTRAINT check_data check (data_inizio_val<=data_fine_val),
    mod_ritiro varchar(16) not null check(mod_ritiro in('prenotazione','libera')),
    stato_conv varchar(16) not null check(stato_conv in('attiva','sospesa','scaduta')),
    perc_sconto_min decimal(5,2) not null check(perc_sconto_min between 0 and 100),
    commissione_ateneo decimal(5,2) check(commissione_ateneo between  0 and 100),
    soglia_pubb decimal(3),
    id_sede smallint references Sede(id),
    id_fornitore varchar(32) references Fornitore(nome_esercizio),
    username_collaboratore varchar(32) references Utente(username)
);

create table Punto_ritiro(
    id smallserial primary key,
    edificio varchar(32) not null,
    piano varchar(16) not null,
    aula varchar(32) not null,
    unique (edificio,piano,aula),
    note_logistiche varchar(128),
    id_sede smallint references Sede(id)
);

create table Offerta(
    id smallserial primary key,
    titolo varchar(32) not null,
    descr varchar(64) not null,
    data_ora_pubb timestamp not null,
    data_ora_scad timestamp not null,
    CONSTRAINT check_date_coerenti CHECK (data_ora_scad > data_ora_pubb),
    restrizioni varchar(32),
    tipologia varchar(32) not null,
    prezzo_originale decimal(5,2) check(prezzo_originale>0) not null,
    prezzo_vendita decimal(5,2) check(prezzo_vendita>0) not null,
    CONSTRAINT check_prezzo check (prezzo_originale>prezzo_vendita),
    quantita decimal(3) not null check(quantita>=0),
    stato varchar(20) not null check(stato in ('attiva','esaurita','scaduta','annullata')),
    id_punto_ritiro smallint references Punto_ritiro(id),
    id_fornitore varchar(32) references Fornitore(nome_esercizio),
    id_convenzione smallint references Convenzione(id_convenzione)
);

create table Dispone(
    id_punto_ritiro smallint references Punto_ritiro(id),
    id_fornitore varchar(32) references Fornitore(nome_esercizio),
    primary key (id_fornitore, id_punto_ritiro)
);

create table Slot(
    id smallserial primary key,
    data date not null,
    ora_inizio time not null,
    ora_fine time not null,
    CONSTRAINT check_ora check (ora_fine>ora_inizio),
    n_max decimal(3) not null,
    id_punto_ritiro smallint references Punto_ritiro(id)
);

create table Ordine(
    id_ordine smallserial primary key,
    data_ora_prenot timestamp not null,
    prezzo_pagato decimal(5,2) not null check(prezzo_pagato>0),
    quantita decimal(3) not null check(quantita>0),
    stato varchar(24) not null check(stato in('prenotato','pagato','ritirato','annullato','no-show','rimborsato')),
    id_offerta smallint references Offerta(id),
    id_slot smallint references Slot(id),
    username_studente varchar(32) references Utente(username)
);

create table Pagamento(
    id_ordine smallint references Ordine(id_ordine) primary key,
    metodo varchar(12) not null check(metodo in('contanti','carta')),
    stato varchar(24) not null check(stato in('pagato','non_pagato','fallito')),
    importo decimal(5,2) not null check(importo>0),
    data_ora_trans timestamp not null
);

create table Recensione(
    id_ordine smallint references Ordine(id_ordine) primary key,
    punteggio decimal(1) not null check(punteggio between 1 and 5),
    data_inserimento timestamp not null,
    commento_testuale varchar(128),
    autore varchar(32) references Utente(username),
    id_fornitore varchar(32) references Fornitore(nome_esercizio)
);

CREATE VIEW Fornitore_con_valutazione AS
SELECT f.*, (SELECT AVG(r.punteggio) FROM Recensione r WHERE r.id_fornitore = f.nome_esercizio) AS valutazione
FROM Fornitore f;

-- controllo Fornitore a Convenzione
CREATE OR REPLACE FUNCTION check_convenzione_opera() RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM Opera
        WHERE id_fornitore = NEW.id_fornitore AND id_sede = NEW.id_sede
    ) THEN
        RAISE EXCEPTION 'Violazione: Il fornitore % non risulta operare nella sede %', NEW.id_fornitore, NEW.id_sede;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_convenzione_opera
BEFORE INSERT OR UPDATE ON Convenzione
FOR EACH ROW EXECUTE FUNCTION check_convenzione_opera();

-- controllo inserimento ordine (Slot e Stato Offerta)
CREATE OR REPLACE FUNCTION check_inserimento_ordine() RETURNS TRIGGER AS $$
DECLARE
    pr_slot SMALLINT;
    pr_offerta SMALLINT;
    stato_off VARCHAR(20);
BEGIN
    SELECT id_punto_ritiro INTO pr_slot FROM Slot WHERE id = NEW.id_slot;
    SELECT id_punto_ritiro, stato INTO pr_offerta, stato_off FROM Offerta WHERE id = NEW.id_offerta;

    IF pr_slot != pr_offerta THEN
        RAISE EXCEPTION 'Violazione: Lo slot orario scelto non appartiene al punto di ritiro dell''offerta.';
    END IF;

    IF stato_off IN ('scaduta', 'esaurita', 'annullata') THEN
        RAISE EXCEPTION 'Impossibile prenotare: l''offerta si trova nello stato %', stato_off;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_ordine
BEFORE INSERT OR UPDATE ON Ordine
FOR EACH ROW EXECUTE FUNCTION check_inserimento_ordine();

-- check ruoli
CREATE OR REPLACE FUNCTION check_ruoli_fk() RETURNS TRIGGER AS $$
DECLARE
    ruolo_utente VARCHAR(20);
BEGIN
    IF TG_TABLE_NAME = 'ordine' THEN
        SELECT ruolo INTO ruolo_utente FROM Utente WHERE username = NEW.username_studente;
        IF ruolo_utente != 'studente' THEN RAISE EXCEPTION 'L''utente non è uno studente.'; END IF;

    ELSIF TG_TABLE_NAME = 'convenzione' AND NEW.username_collaboratore IS NOT NULL THEN
        SELECT ruolo INTO ruolo_utente FROM Utente WHERE username = NEW.username_collaboratore;
        IF ruolo_utente != 'collaboratore' THEN RAISE EXCEPTION 'L''utente non è un collaboratore.'; END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ruolo_studente BEFORE INSERT OR UPDATE ON Ordine FOR EACH ROW EXECUTE FUNCTION check_ruoli_fk();
CREATE TRIGGER trg_ruolo_collaboratore BEFORE INSERT OR UPDATE ON Convenzione FOR EACH ROW EXECUTE FUNCTION check_ruoli_fk();

-- validazione recensione
CREATE OR REPLACE FUNCTION check_recensione_valida() RETURNS TRIGGER AS $$
DECLARE
    stato_ord VARCHAR(24);
    studente_ord VARCHAR(32);
BEGIN
    SELECT stato, username_studente INTO stato_ord, studente_ord FROM Ordine WHERE id_ordine = NEW.id_ordine;

    IF stato_ord != 'ritirato' THEN
        RAISE EXCEPTION 'Violazione: È possibile recensire solo gli ordini nello stato "ritirato".';
    END IF;
    IF NEW.autore != studente_ord THEN
        RAISE EXCEPTION 'Violazione: L''autore della recensione non coincide con l''utente che ha effettuato l''ordine.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recensione_valida
BEFORE INSERT OR UPDATE ON Recensione
FOR EACH ROW EXECUTE FUNCTION check_recensione_valida();

-- controlla disponibilità prima dell'inserimento
CREATE OR REPLACE FUNCTION check_quantita_offerta() RETURNS TRIGGER AS $$
DECLARE
    qta_disponibile DECIMAL(3);
BEGIN
    SELECT quantita INTO qta_disponibile FROM Offerta WHERE id = NEW.id_offerta;
    IF NEW.quantita > qta_disponibile THEN
        RAISE EXCEPTION 'Errore: Quantità richiesta (%) superiore a quella disponibile (%)', NEW.quantita, qta_disponibile;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_quantita_prima_ordine
BEFORE INSERT ON Ordine FOR EACH ROW EXECUTE FUNCTION check_quantita_offerta();

-- scala disponibilità dopo l'inserimento
CREATE OR REPLACE FUNCTION scala_quantita_offerta() RETURNS TRIGGER AS $$
BEGIN
    UPDATE Offerta SET quantita = quantita - NEW.quantita WHERE id = NEW.id_offerta;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_scala_quantita_dopo_ordine
AFTER INSERT ON Ordine FOR EACH ROW EXECUTE FUNCTION scala_quantita_offerta();

-- ripristina disponibilità se annullato
CREATE OR REPLACE FUNCTION ripristina_quantita_offerta() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.stato IN ('annullato', 'rimborsato') AND OLD.stato NOT IN ('annullato', 'rimborsato') THEN
        UPDATE Offerta SET quantita = quantita + NEW.quantita WHERE id = NEW.id_offerta;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ripristina_quantita_annullamento
AFTER UPDATE ON Ordine FOR EACH ROW EXECUTE FUNCTION ripristina_quantita_offerta();

COMMIT;

/*************************************************************************************************************************************************************************/
--1b. Popolamento
/*************************************************************************************************************************************************************************/

/* inserire qui i comandi SQL per il popolamento 'in piccolo' di tale base di dati (utile per il test dei vincoli e delle operazioni in parte 2.) */
/*************************************************************************************************************************************************************************/

BEGIN;

-- 1. Inserimento Fornitori
INSERT INTO Fornitore (nome_esercizio, via, cap, comune, tipologia, recapiti_di_contatto) VALUES
('Mensa Darsena', 'Via Darsena 1', '16126', 'Genova', 'Mensa Universitaria', 'darsena@mensa.unige.it'),
('Bar Ingegneria', 'Via all''Opera Pia 15', '16145', 'Genova', 'Bar', 'bar.ingegneria@gmail.com');

-- 2. Inserimento Utenti
INSERT INTO Utente (username, email, nome, cognome, account_attivo, data_reg, num_telefono, ruolo, nome_esercizio_gestito) VALUES
('studente_mario', 'mario.rossi@studenti.unige.it', 'Mario', 'Rossi', true, '2023-09-01', '3331112222', 'studente', NULL),
('ref_darsena', 'luigi@mensa.unige.it', 'Luigi', 'Bianchi', true, '2023-01-15', '3334445555', 'referente_fornitore', 'Mensa Darsena'),
('ref_ing', 'anna@baring.it', 'Anna', 'Verdi', true, '2023-02-20', '3337778888', 'referente_fornitore', 'Bar Ingegneria'),
('collab_unige', 'giulia.neri@unige.it', 'Giulia', 'Neri', true, '2022-11-10', '3339990000', 'collaboratore', NULL),
('admin_boss', 'admin@toogoodatuni.it', 'Paolo', 'Gialli', true, '2022-01-01', NULL, 'amministratore', NULL);

-- 3. Inserimento Sedi (FORZIAMO GLI ID A 1 E 2 PER EVITARE DISALLINEAMENTI)
INSERT INTO Sede (id, nome, rif_amm, coord, via, cap, comune) VALUES
(1, 'Polo Darsena', 'Dip. Economia', '44.4140, 8.9280', 'Via Darsena 1', '16126', 'Genova'),
(2, 'Polo Valletta Puggia', 'DIBRIS', '44.4030, 8.9660', 'Via Dodecaneso 35', '16146', 'Genova');

-- 4. Operatività Fornitori nelle Sedi
INSERT INTO Opera (id_fornitore, id_sede) VALUES
('Mensa Darsena', 1),
('Bar Ingegneria', 2);

-- 5. Inserimento Convenzioni
INSERT INTO Convenzione (data_inizio_val, data_fine_val, tipologia, mod_ritiro, stato_conv, perc_sconto_min, commissione_ateneo, soglia_pubb, id_sede, id_fornitore, username_collaboratore) VALUES
('2023-01-01', '2030-12-31', 'Pasto Completo', 'prenotazione', 'attiva', 50.00, 5.00, 20, 1, 'Mensa Darsena', 'collab_unige'),
('2023-01-01', '2030-12-31', 'Snack/Colazione', 'libera', 'attiva', 30.00, 2.00, 10, 2, 'Bar Ingegneria', 'collab_unige');

-- 6. Punti di Ritiro (EDIFICIO CORRETTO < 16 CHARS)
INSERT INTO Punto_ritiro (edificio, piano, aula, note_logistiche, id_sede) VALUES
('Edificio A', 'Terra', 'Ingresso Mensa', 'Ritirare al bancone dedicato saltando la coda', 1),
('Padiglione B', 'Terra', 'Atrio', 'Chiedere direttamente in cassa', 2);

-- 7. Collegamento Dispone
INSERT INTO Dispone (id_punto_ritiro, id_fornitore) VALUES
(1, 'Mensa Darsena'),
(2, 'Bar Ingegneria');

-- 8. Creazione Offerte
INSERT INTO Offerta (titolo, descr, data_ora_pubb, data_ora_scad, restrizioni, tipologia, prezzo_originale, prezzo_vendita, quantita, stato, id_punto_ritiro, id_fornitore, id_convenzione) VALUES
('Magic Box Mensa', 'Avanzi del turno pranzo (primi e contorni)', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '1 day', 'Solo iscritti', 'Pasto Completo', 10.00, 3.50, 10, 'attiva', 1, 'Mensa Darsena', 1),
('Brioches Miste', 'Brioches avanzate dalla mattina', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '1 day', NULL, 'Snack/Colazione', 5.00, 2.00, 10, 'attiva', 2, 'Bar Ingegneria', 2);

-- 9. Creazione Slot Orari per il ritiro
INSERT INTO Slot (data, ora_inizio, ora_fine, n_max, id_punto_ritiro) VALUES
(CURRENT_DATE, '14:30:00', '23:00:00', 5, 1),
(CURRENT_DATE, '15:00:00', '23:30:00', 5, 1),
(CURRENT_DATE, '12:30:00', '23:00:00', 10, 2);

-- 10. Creazione Ordini (CORRETTO RUOLO UTENTE E SLOT COERENTE)
INSERT INTO Ordine (data_ora_prenot, prezzo_pagato, quantita, stato, id_offerta, id_slot, username_studente) VALUES
(CURRENT_TIMESTAMP, 3.50, 1, 'ritirato', 1, 1, 'studente_mario'),
(CURRENT_TIMESTAMP, 10.00, 2, 'ritirato', 2, 3, 'studente_mario');

-- 11. Registrazione Pagamenti
INSERT INTO Pagamento (id_ordine, metodo, stato, importo, data_ora_trans) VALUES
(1, 'carta', 'pagato', 3.50, CURRENT_TIMESTAMP),
(2, 'carta', 'pagato', 10.00, CURRENT_TIMESTAMP);

-- 12. Inserimento Recensioni (CORRETTO AUTORE)
INSERT INTO Recensione (id_ordine, punteggio, data_inserimento, commento_testuale, autore) VALUES
(1, 5, CURRENT_TIMESTAMP, 'Ottimo cibo e quantità generosa!', 'studente_mario'),
(2, 1, CURRENT_TIMESTAMP, 'Pessima esperienza', 'studente_mario');

COMMIT;

/*************************************************************************************************************************************************************************/
--2. Vista
/* Inserire qui la specifica il linguaggio naturale di una vista che si ritiene utile per visualizzare alcune informazioni aggregate di interesse per il dominio, che
include accesso ad informazioni contenute in almeno tre tabelle diverse, un'operazione di raggruppamento e il calcolo di almeno tre diverse informazioni aggregate       */
/*************************************************************************************************************************************************************************/

/* Specifica: Vista che mostra, per ogni fornitore, il numero totale di ordini ricevuti,
l'incasso totale generato dagli ordini pagati e la media dei punteggi delle recensioni ricevute. */

/* inserire qui i comandi SQL per la creazione della vista corrispondente alla specifica indicata nel commento precedente */

CREATE VIEW Statistiche_Fornitori AS
SELECT
    f.nome_esercizio,
    COUNT(o.id_ordine) AS numero_totale_ordini,
    COALESCE(SUM(p.importo), 0) AS incasso_totale,
    f.valutazione
FROM Fornitore_con_valutazione f
JOIN Offerta off ON f.nome_esercizio = off.id_fornitore
LEFT JOIN Ordine o ON off.id = o.id_offerta
LEFT JOIN Pagamento p ON o.id_ordine = p.id_ordine AND p.stato = 'pagato'
LEFT JOIN Recensione r ON o.id_ordine = r.id_ordine
GROUP BY f.nome_esercizio, f.valutazione;


/*************************************************************************************************************************************************************************/
--3. Interrogazioni
/*************************************************************************************************************************************************************************/

/*************************************************************************************************************************************************************************/
/* 3a (interrogazione con operazione insiemistica)															 */
/* Inserire qui la specifica in linguaggio naturale di un'interrogazione che si ritiene significativa                                                                    */
/*************************************************************************************************************************************************************************/

/*
    Specifica (Operazione insiemistica): trovare username degli utenti che sono studenti, che hanno effettuato almeno un ordine per la tipologia 'Pasto completo' oppure
    sono collaboratori che gestiscono convenzioni attive per 'Pasto completo'
*/

/* inserire qui i comandi SQL per la creazione della query corrispondente alla specifica indicata nel commento precedente */
select u.username from utente u join ordine o on u.username = o.username_studente join offerta off on o.id_offerta = off.id
where off.tipologia = 'Pasto Completo'
union
select u.username from utente u join convenzione c on u.username = c.username_collaboratore
where c.tipologia = 'Pasto Completo' and c.stato_conv = 'attiva';


/*************************************************************************************************************************************************************************/
/* 3b (interrogazione di divisione)                                                                                                                                      */
/* Inserire qui la specifica in linguaggio naturale di un'interrogazione che si ritiene significativa                                                                    */
/*************************************************************************************************************************************************************************/

/*
    Specifica: seleziona tutti gli utenti che hanno effettuato un ordine con prezzo minore di 10 euro.
*/

/* inserire qui i comandi SQL per la creazione della query corrispondente alla specifica indicata nel commento precedente */

select u.username from utente u join ordine o on u.username = o.username_studente join offerta off on o.id_offerta = off.id
EXCEPT
select u.username from utente u join ordine o on u.username = o.username_studente join offerta off on o.id_offerta = off.id where o.prezzo_pagato>10;


/*************************************************************************************************************************************************************************/
/* 3b (interrogazione con sottointerrogazione correlata)                                                                                                                 */
/* Inserire qui la specifica in linguaggio naturale di un'interrogazione che si ritiene significativa                                                                    */
/*************************************************************************************************************************************************************************/

/*
    Specifica: seleziona il nome del fornitore che ha venduto l'ordine più costoso.
*/

/* inserire qui i comandi SQL per la creazione della query corrispondente alla specifica indicata nel commento precedente */

select f.nome_esercizio
from fornitore f join offerta off on f.nome_esercizio = off.id_fornitore join ordine o on o.id_offerta = off.id
where o.prezzo_pagato = (select MAX(o2.prezzo_pagato) from ordine o2);


/*************************************************************************************************************************************************************************/
--4. Funzioni
/*************************************************************************************************************************************************************************/

/*************************************************************************************************************************************************************************/
/* 4a: operazione di inserimento non banale, effettuando tutti gli opportuni controlli e calcoli di dati derivati.                                                       */
/* Inserire qui la specifica in linguaggio naturale di un'operazione che si ritiene significativa                                                                        */
/*************************************************************************************************************************************************************************/

/*
    Specifica: Funzione per la creazione di una nuova prenotazione (Ordine).
    La funzione riceve in input lo username dello studente, l'ID dell'offerta, l'ID dello slot orario e la quantità desiderata.
    Calcola automaticamente il "prezzo pagato" leggendo il "prezzo di vendita" dell'offerta e moltiplicandolo per la quantità, per poi inserire il record.
*/

/* inserire qui i comandi SQL per la creazione della funzione corrispondente alla specifica indicata nel commento precedente */

CREATE OR REPLACE FUNCTION crea_prenotazione(
    p_username VARCHAR(32),
    p_id_offerta SMALLINT,
    p_id_slot SMALLINT,
    p_quantita DECIMAL(3)
) RETURNS VOID AS $$
DECLARE
    v_prezzo_unitario DECIMAL(5,2);
    v_prezzo_totale DECIMAL(5,2);
BEGIN
    -- recupera prezzo vendita offerta
    SELECT prezzo_vendita INTO v_prezzo_unitario
    FROM Offerta
    WHERE id = p_id_offerta;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Offerta inesistente';
    END IF;

    v_prezzo_totale := v_prezzo_unitario * p_quantita;

    INSERT INTO Ordine (data_ora_prenot, prezzo_pagato, quantita, stato, id_offerta, id_slot, username_studente)
    VALUES (CURRENT_TIMESTAMP, v_prezzo_totale, p_quantita, 'prenotato', p_id_offerta, p_id_slot, p_username);

    RAISE NOTICE 'Prenotazione creata con successo. Totale calcolato: %', v_prezzo_totale;
END;
$$ LANGUAGE plpgsql;


/* inserire qui i comandi SQL per la validazione della funzione */

SELECT crea_prenotazione('studente_mario', 1::SMALLINT, 1::SMALLINT, 2::DECIMAL);

SELECT * FROM Ordine WHERE username_studente = 'studente_mario' ORDER BY data_ora_prenot DESC;




/*************************************************************************************************************************************************************************/
/* 4b: calcolo di un�informazione derivata rilevante e non banale, che richieda l�accesso a diverse tabelle e un�aggregazione                                            */
/* Inserire qui la specifica in linguaggio naturale di un'operazione che si ritiene significativa                                                                        */
/*************************************************************************************************************************************************************************/

/*
    Specifica: Funzione per calcolare il risparmio economico totale accumulato da uno studente.
    La funzione prende in input lo username, accede alle tabelle Ordine e Offerta, e somma la differenza tra "prezzo originale" e "prezzo di vendita"
    moltiplicata per le quantità acquistate. Vengono considerati esclusivamente gli ordini andati a buon fine (stato 'ritirato').
*/

/* inserire qui i comandi SQL per la creazione della funzione corrispondente alla specifica indicata nel commento precedente */

CREATE OR REPLACE FUNCTION calcola_risparmio_studente(p_username VARCHAR(32)) RETURNS DECIMAL(7,2) AS $$
DECLARE
    v_risparmio_totale DECIMAL(7,2);
BEGIN
    SELECT COALESCE(SUM((off.prezzo_originale - off.prezzo_vendita) * ord.quantita), 0)
    INTO v_risparmio_totale
    FROM Ordine ord
    JOIN Offerta off ON ord.id_offerta = off.id
    WHERE ord.username_studente = p_username
      AND ord.stato = 'ritirato';

    RETURN v_risparmio_totale;
END;
$$ LANGUAGE plpgsql;

/* inserire qui i comandi SQL per la validazione della funzione */

SELECT calcola_risparmio_studente('studente_mario') AS risparmio_totale_euro;



/*************************************************************************************************************************************************************************/
--5. Trigger
/*************************************************************************************************************************************************************************/

/*************************************************************************************************************************************************************************/
/* 5a: trigger per la verifica di un vincolo che non sia implementabile come vincolo CHECK                                                                               */
/* Inserire qui la specifica in linguaggio naturale di un vincolo che si ritiene significativo                                                                           */
/*************************************************************************************************************************************************************************/

/*
    Specifica: Non è ammessa la pubblicazione di offerte in una sede in assenza di una convenzione attiva e temporalmente valida tra il fornitore e la sede del punto di ritiro
    per la relativa tipologia di offerta. Inoltre, l'offerta deve rispettare la percentuale di sconto minima pattuita nella convenzione.
*/

/* inserire qui i comandi SQL per la creazione del trigger corrispondente alla specifica indicata nel commento precedente */

CREATE OR REPLACE FUNCTION check_convenzione_offerta() RETURNS trigger AS $$
DECLARE
    v_id_sede smallint;
    v_conv    Convenzione%ROWTYPE;
BEGIN
    SELECT id_sede INTO v_id_sede FROM Punto_ritiro WHERE id = NEW.id_punto_ritiro;
    SELECT * INTO v_conv FROM Convenzione WHERE id_convenzione = NEW.id_convenzione;

    -- controlli

    -- coerenza Fornitore
    IF v_conv.id_fornitore IS DISTINCT FROM NEW.id_fornitore THEN
        RAISE EXCEPTION 'La convenzione % non appartiene al fornitore %', NEW.id_convenzione, NEW.id_fornitore;
    END IF;

    -- coerenza Sede
    IF v_conv.id_sede IS DISTINCT FROM v_id_sede THEN
        RAISE EXCEPTION 'La convenzione % non copre la sede del punto di ritiro %', NEW.id_convenzione, NEW.id_punto_ritiro;
    END IF;

    -- coerenza Tipologia
    IF v_conv.tipologia IS DISTINCT FROM NEW.tipologia THEN
        RAISE EXCEPTION 'La convenzione % non copre la tipologia %', NEW.id_convenzione, NEW.tipologia;
    END IF;

    -- validità Stato
    IF v_conv.stato_conv <> 'attiva' THEN
        RAISE EXCEPTION 'La convenzione % non è attiva', NEW.id_convenzione;
    END IF;

    -- date di validità
    IF CURRENT_DATE < v_conv.data_inizio_val OR (v_conv.data_fine_val IS NOT NULL AND CURRENT_DATE > v_conv.data_fine_val) THEN
        RAISE EXCEPTION 'La convenzione % non è valida in data odierna', NEW.id_convenzione;
    END IF;

    -- Sconto Minimo
    IF (1 - NEW.prezzo_vendita / NEW.prezzo_originale) * 100 < v_conv.perc_sconto_min THEN
        RAISE EXCEPTION 'Lo sconto applicato non rispetta la percentuale minima della convenzione';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_convenzione_offerta
BEFORE INSERT OR UPDATE ON Offerta
FOR EACH ROW EXECUTE FUNCTION check_convenzione_offerta();


/* inserire qui i comandi SQL per la validazione del trigger */

/*************************************************************************************************************************************************************************/
/* 5b: trigger per il mantenimento di informazione derivata o per l'implementazione di una regola di dominio                                                             */
/* Inserire qui la specifica in linguaggio naturale del trigger                                                                                                          */
/*************************************************************************************************************************************************************************/

/*
    Specifica: La piattaforma prevede meccanismi di penalizzazione per utenti con ripetuti no-show.
    Nello specifico, quando lo stato di un ordine viene aggiornato a "no-show", il sistema verifica il numero totale di no-show accumulati dallo studente;
    se tale conteggio raggiunge o supera la soglia di 3, l'account dell'utente viene automaticamente disattivato impostando account_attivo=false
*/

/* inserire qui i comandi SQL per la creazione del trigger corrispondente alla specifica indicata nel commento precedente */

CREATE OR REPLACE FUNCTION penalizza_no_show() RETURNS TRIGGER AS $$
DECLARE
    conteggio_noshow INT;
BEGIN
    -- se lo stato diventa no-show
    IF NEW.stato = 'no-show' AND OLD.stato != 'no-show' THEN

        -- conta i no-show
        SELECT COUNT(*) INTO conteggio_noshow
        FROM Ordine
        WHERE username_studente = NEW.username_studente AND stato = 'no-show';

        -- se 3, disattiva l'account
        IF conteggio_noshow >= 3 THEN
            UPDATE Utente SET account_attivo = false WHERE username = NEW.username_studente;
            RAISE NOTICE 'Regola di Dominio applicata: Account dello studente % sospeso per aver raggiunto 3 no-show.', NEW.username_studente;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_penalizza_noshow
AFTER UPDATE ON Ordine
FOR EACH ROW EXECUTE FUNCTION penalizza_no_show();

INSERT INTO Ordine (data_ora_prenot, prezzo_pagato, quantita, stato, id_offerta, id_slot, username_studente) VALUES
(CURRENT_TIMESTAMP, 3.50, 1, 'prenotato', 1, 1, 'studente_mario'),
(CURRENT_TIMESTAMP, 3.50, 1, 'prenotato', 1, 1, 'studente_mario'),
(CURRENT_TIMESTAMP, 3.50, 1, 'prenotato', 1, 1, 'studente_mario');

/* inserire qui i comandi SQL per la validazione del trigger */

UPDATE Ordine SET stato = 'no-show' WHERE username_studente = 'studente_mario' AND stato = 'prenotato';

SELECT username, account_attivo FROM Utente WHERE username = 'studente_mario';
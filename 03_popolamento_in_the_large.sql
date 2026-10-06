--- PARTE III 

/*************************************************************************************************************************************************************************/ 
--1f. Popolamento in the large
/*************************************************************************************************************************************************************************/ 

/* inserire qui i comandi SQL per il popolamento 'in the large' delle relazioni coinvolte nel carico di lavoro  */

SET search_path TO toogoodatuni_cl;

-- Inserisce 10.000 Utenti (90% studenti)
INSERT INTO utente_CL 
SELECT 'user'||x, 'user'||x||'@mail.com', 'Nome', 'Cognome', true, current_date, '1234567890', 
       CASE WHEN random() < 0.9 THEN 'studente' ELSE 'collaboratore' END, NULL, 'dummy'
FROM generate_series(1, 10000) AS x;

-- Inserisce 30.000 Ordini
INSERT INTO ordine_CL 
SELECT x::smallint, current_timestamp, (random() * 50 + 1)::decimal(5,2), (random() * 10 + 1)::decimal(3), 
       (ARRAY['prenotato','pagato','ritirato','annullato','no-show','rimborsato'])[floor(random()*6)+1], 
       1, 1, 'user1', 'dummy'
FROM generate_series(1, 30000) AS x;

-- Inserisce 5.000 Sedi 
INSERT INTO sede_CL 
SELECT x::smallint, 'Sede'||x, 'Amm', (random()*90)::text || ', ' || (random()*180)::text, 
       'Via Roma', '00100', 'Roma', 'dummy'
FROM generate_series(1, 5000) AS x;

-- Inserisce 10.000 Convenzioni (50% attive)
INSERT INTO convenzione_CL 
SELECT x::smallint, current_date, current_date+30, 'Cibo', 'libera', 
       CASE WHEN random() < 0.5 THEN 'attiva' ELSE 'scaduta' END, 
       10.00, 5.00, 10, (random()*4999+1)::smallint, 'Fornitore1', 'user2', 'dummy'
FROM generate_series(1, 10000) AS x;

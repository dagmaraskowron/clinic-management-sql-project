create schema przychodnia;
set search_path to przychodnia;

create table pacjent(
	id_pacjenta SERIAL primary key,
	imie TEXT not null,
	nazwisko TEXT not null,
	telefon TEXT not null,
	email TEXT not null,
	pesel CHAR(11) unique,
	data_urodzenia DATE not null);

create table lekarze (
	id_lekarza SERIAL primary key,
	imie TEXT not null,
	nazwisko TEXT not null,
	telefon TEXT not null,
	email TEXT not null,
	numer_pwz TEXT unique);


create table gabinety ( 
	id_gabinetu SERIAL primary key, 
	numer TEXT unique,
	pietro INT);


CREATE TABLE specjalizacje (
    id_specjalizacji SERIAL PRIMARY KEY,
    nazwa TEXT UNIQUE NOT NULL,
    opis TEXT);

CREATE TABLE lekarz_specjalizacja (
    id_lekarza INT NOT NULL,
    id_specjalizacji INT NOT NULL,
    PRIMARY KEY (id_lekarza, id_specjalizacji),
    FOREIGN KEY (id_lekarza) REFERENCES lekarze(id_lekarza) ON DELETE CASCADE,
    FOREIGN KEY (id_specjalizacji) REFERENCES specjalizacje(id_specjalizacji) ON DELETE CASCADE);

create table terminarz_lekarzy (
    id_terminarza SERIAL PRIMARY KEY,
    id_lekarza INT NOT NULL REFERENCES lekarze(id_lekarza) ON DELETE CASCADE,
    id_gabinetu INT NOT NULL REFERENCES gabinety(id_gabinetu) ON DELETE RESTRICT,
    dzien_tygodnia INT NOT NULL CHECK (dzien_tygodnia BETWEEN 1 AND 7),
    godzina_od TIME NOT NULL,
    godzina_do TIME NOT NULL,
    CHECK (godzina_od < godzina_do));

create table wizyta (
	id_wizyty SERIAL primary key,
	data DATE not null,
	godzina TIME not null,
	opis TEXT,
	status TEXT not null check (status in ('zaplanowana', 'odbyta', 'anulowana')),
	id_pacjenta INT not null references pacjent(id_pacjenta) on delete cascade,
	id_lekarza INT not null references lekarze(id_lekarza) on delete cascade,
	id_gabinetu INT not null references gabinety(id_gabinetu) on delete restrict);
    
ALTER TABLE wizyta
ADD COLUMN id_gabinetu INT
REFERENCES gabinety(id_gabinetu)
ON DELETE RESTRICT;

create table recepty(
	id_recepty SERIAL primary key,
	data_wydania DATE not null,
	id_wizyty INT not null references wizyta(id_wizyty) on delete cascade);
	

create table leki (
	id_leku SERIAL primary key,
	nazwa  TEXT not null,
	producent TEXT,
	unique (nazwa, producent));

create table recepta_lek (
	id_recepty INT not null references recepty(id_recepty) on delete cascade,
	id_leku INT not null references leki(id_leku) on delete RESTRICT,
	dawkowanie TEXT not null, 
	primary key (id_recepty, id_leku));


create table skierowania (
	 id_skierowania SERIAL primary key,
	 id_wizyty INT not null references wizyta(id_wizyty) on delete cascade,
	 typ TEXT not NULL check (typ in ('badania', 'specjalista')),
	 opis TEXT);

CREATE TABLE forma_platnosci (
    id_formy SERIAL PRIMARY KEY,
    nazwa TEXT UNIQUE NOT NULL
);

INSERT INTO forma_platnosci (nazwa) VALUES
('gotowka'),
('karta'),
('blik');

CREATE TABLE status_platnosci (
    id_statusu SERIAL PRIMARY KEY,
    nazwa TEXT UNIQUE NOT NULL
);

INSERT INTO status_platnosci (nazwa) VALUES
('oplacona'),
('nieoplacona');



CREATE TABLE platnosci (
    id_platnosci SERIAL PRIMARY KEY,
    id_wizyty INT NOT NULL
        REFERENCES wizyta(id_wizyty) ON DELETE CASCADE,

    kwota NUMERIC(10,2) NOT NULL CHECK (kwota > 0),

    id_formy INT NOT NULL
        REFERENCES forma_platnosci(id_formy),

    id_statusu INT NOT NULL
        REFERENCES status_platnosci(id_statusu),

    data_platnosci DATE
);


CREATE OR REPLACE VIEW kalendarz_wizyt AS
SELECT
  w.id_wizyty,
  w.data,
  w.godzina,
  w.status,
  w.opis,
  p.id_pacjenta,
  p.imie     AS pacjent_imie,
  p.nazwisko AS pacjent_nazwisko,
  l.id_lekarza,
  l.imie     AS lekarz_imie,
  l.nazwisko AS lekarz_nazwisko
FROM wizyta w
JOIN pacjent p ON p.id_pacjenta = w.id_pacjenta
JOIN lekarze l ON l.id_lekarza = w.id_lekarza;

CREATE OR REPLACE VIEW szczegoly_platnosci AS
SELECT
  pl.id_platnosci,
  pl.id_wizyty,
  pl.kwota,
  fp.nazwa AS forma_platnosci,
  sp.nazwa AS status_platnosci,
  pl.data_platnosci
FROM platnosci pl
JOIN forma_platnosci fp ON fp.id_formy = pl.id_formy
JOIN status_platnosci sp ON sp.id_statusu = pl.id_statusu;

CREATE OR REPLACE VIEW zawartosc_recepty AS
SELECT
  r.id_recepty,
  r.data_wydania,
  r.id_wizyty,
  lk.id_leku,
  lk.nazwa AS lek_nazwa,
  lk.producent,
  rl.dawkowanie
FROM recepty r
JOIN recepta_lek rl ON rl.id_recepty = r.id_recepty
JOIN leki lk ON lk.id_leku = rl.id_leku;

CREATE OR REPLACE VIEW terminarz_info AS
SELECT
  t.id_terminarza,
  l.id_lekarza,
  l.imie AS lekarz_imie, l.nazwisko AS lekarz_nazwisko,
  g.numer AS gabinet_numer, g.pietro,
  t.dzien_tygodnia, t.godzina_od, t.godzina_do
FROM terminarz_lekarzy t
JOIN lekarze l ON l.id_lekarza = t.id_lekarza
JOIN gabinety g ON g.id_gabinetu = t.id_gabinetu;

CREATE OR REPLACE VIEW historia_pacjenta AS
SELECT
  p.id_pacjenta,
  p.imie AS pacjent_imie,
  p.nazwisko AS pacjent_nazwisko,
  w.id_wizyty,
  w.data,
  w.godzina,
  w.status,
  l.imie AS lekarz_imie,
  l.nazwisko AS lekarz_nazwisko,
  w.opis
FROM pacjent p
JOIN wizyta w ON w.id_pacjenta = p.id_pacjenta
JOIN lekarze l ON l.id_lekarza = w.id_lekarza
ORDER BY p.id_pacjenta, w.data DESC, w.godzina DESC;


CREATE OR REPLACE VIEW specjalizacje_lekarzy AS
SELECT
  l.id_lekarza,
  l.imie,
  l.nazwisko,
  string_agg(s.nazwa, ', ' ORDER BY s.nazwa) AS specjalizacje
FROM lekarze l
LEFT JOIN lekarz_specjalizacja ls ON ls.id_lekarza = l.id_lekarza
LEFT JOIN specjalizacje s ON s.id_specjalizacji = ls.id_specjalizacji
GROUP BY l.id_lekarza, l.imie, l.nazwisko;


DROP TRIGGER IF EXISTS sprawdzenie_terminarza_trigger ON przychodnia.wizyta;
DROP FUNCTION IF EXISTS przychodnia.sprawdzenie_terminarza();

CREATE OR REPLACE FUNCTION sprawdzenie_terminarza()
RETURNS trigger AS $$
DECLARE
  dzien INT;
  czy_istnieje_taki_termin_w_terminarzu BOOLEAN;
begin
	dzien := EXTRACT(ISODOW FROM NEW.data);
	SELECT EXISTS (
    SELECT 1
    FROM terminarz_lekarzy t
    WHERE t.id_lekarza = NEW.id_lekarza
	  AND t.id_gabinetu = NEW.id_gabinetu
      AND t.dzien_tygodnia = dzien
      AND NEW.godzina >= t.godzina_od
      AND NEW.godzina <  t.godzina_do
  ) INTO czy_istnieje_taki_termin_w_terminarzu;

  IF NOT czy_istnieje_taki_termin_w_terminarzu THEN
    RAISE EXCEPTION
      'Lekarz % nie przyjmuje w tym terminie (data %, godzina %).',
      NEW.id_lekarza, NEW.data, NEW.godzina;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sprawdzenie_terminarza_trigger ON wizyta;

CREATE TRIGGER sprawdzenie_terminarza_trigger
BEFORE INSERT OR UPDATE OF data, godzina, id_lekarza, id_gabinetu ON wizyta
FOR EACH ROW
EXECUTE FUNCTION sprawdzenie_terminarza();

CREATE OR REPLACE FUNCTION podwojna_wizyta()
RETURNS trigger AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM wizyta w
    WHERE w.id_lekarza = NEW.id_lekarza
      AND w.data = NEW.data
      AND w.godzina = NEW.godzina
      AND w.id_wizyty <> COALESCE(NEW.id_wizyty, -1)
  ) THEN
    RAISE EXCEPTION
      'Podwójna rezerwacja: lekarz % ma już wizytę w dniu % o godz. %.',
      NEW.id_lekarza, NEW.data, NEW.godzina;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS podwojna_wizyta_trigger ON wizyta;

CREATE TRIGGER podwojna_wizyta_trigger
BEFORE INSERT OR UPDATE OF id_lekarza, data, godzina ON wizyta
FOR EACH ROW
EXECUTE FUNCTION podwojna_wizyta();




CREATE OR REPLACE FUNCTION daty_platnosci()
RETURNS trigger AS $$
DECLARE
  status_oplacona_id INT;
begin
	SELECT id_statusu
  INTO status_oplacona_id
  FROM status_platnosci
  WHERE nazwa = 'oplacona';

IF NEW.id_statusu = status_oplacona_id
     AND NEW.data_platnosci IS NULL THEN
    NEW.data_platnosci := CURRENT_DATE;
  END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS daty_platnosci_trigger ON platnosci;

CREATE TRIGGER daty_platnosci_trigger
BEFORE INSERT OR UPDATE OF id_statusu ON platnosci
FOR EACH ROW
EXECUTE FUNCTION daty_platnosci();


INSERT INTO pacjent (imie, nazwisko, telefon, email, pesel, data_urodzenia) VALUES
('Kamil','Trawa','123456789','kamil.tr@gmail.com','12345678901','1980-10-05'),
('Daria','Komin','987654321','daria.kom@gmail.com','23456789012','2000-04-11'),
('Piotr', 'Lampa', '447888223', 'piotr.lam@gmail.com', '34572519271', '1998-01-01'),
('Aneta', 'Chmura', '985348222', 'aneta.chm@gmail.com', '67321786346', '2002-10-20'),
('Barbara', 'Kot', '888333555', 'barbara.kot@gmail.com', '87914682648', '1987-12-30'),
('Aleksander', 'Drzewo', '666777111', 'aleksander.drz@gmail.com', '92367485967', '1992-05-02'),
('Daria', 'Pies', '222123567', 'daria.pies@gmail.com', '04285673232', '2004-05-13'),
('Patryk', 'Kol', '111666777', 'patryk.kol@gmail.com', '89235556131', '1989-04-02'),
('Ola', 'Lipa', '321654876', 'ola.lip@gmail.com', '06234432456', '2006-11-28'),
('Adam', 'Stolik', '121212121', 'adam.stol@gmail.com', '05176534278', '2005-09-04')
ON CONFLICT (pesel) DO NOTHING;

INSERT INTO lekarze (imie, nazwisko, telefon, email, numer_pwz) VALUES
('Paweł','Okno','462284934','pawel.okn@gmail.com','PWZ111'),
('Antoni','Cegła','488222354','antoni.ceg@gmail.com','PWZ222'),
('Barbara', 'Ziarno', '783254789', 'barbara.zia@gmail.com', 'PWZ333'),
('Alicja', 'Patyk', '489777231', 'alicja.pat@gmail.com', 'PWZ444'),
('Nikola', 'Kowalska', '676545232', 'nikola.kow@gmail.com', 'PWZ555'),
('Gabriel', 'Pieczarka', '787989323', 'gabriel.piecz@gmail.com', 'PWZ666')
ON CONFLICT (numer_pwz) DO NOTHING;

INSERT INTO gabinety (numer, pietro) VALUES
('101',1), ('201',2), ('102', 1), ('202', 2), ('103', 1), ('203', 2)
ON CONFLICT (numer) DO NOTHING;

INSERT INTO specjalizacje (nazwa, opis) VALUES
('internista','Choroby wewnętrzne'),
('dermatologia','Skóra'),
('endokrynologia', 'Hormony'),
('psychiatria', 'Problemy psychologiczne'),
('ginekologia', 'Kobiety'),
('chirurgia', 'Zabiegi')
ON CONFLICT (nazwa) DO NOTHING;

INSERT INTO lekarz_specjalizacja (id_lekarza, id_specjalizacji)
SELECT l.id_lekarza, s.id_specjalizacji
FROM lekarze l, specjalizacje s
WHERE (l.numer_pwz='PWZ111' AND s.nazwa='internista')
   OR (l.numer_pwz='PWZ222' AND s.nazwa='dermatologia')
   or (l.numer_pwz='PWZ333' AND s.nazwa='endokrynologia')
   or (l.numer_pwz='PWZ444' AND s.nazwa='psychiatria')
   or (l.numer_pwz='PWZ555' and s.nazwa='ginekologia')
   or (l.numer_pwz='PWZ666' and s.nazwa='chirurgia')
ON CONFLICT DO NOTHING;

INSERT INTO terminarz_lekarzy (id_lekarza, id_gabinetu, dzien_tygodnia, godzina_od, godzina_do)
SELECT l.id_lekarza, g.id_gabinetu, 1, '09:00', '12:00'
FROM lekarze l, gabinety g
WHERE l.numer_pwz='PWZ111' AND g.numer='101';

INSERT INTO terminarz_lekarzy (id_lekarza, id_gabinetu, dzien_tygodnia, godzina_od, godzina_do)
SELECT l.id_lekarza, g.id_gabinetu, 1, '10:00', '15:00'
FROM lekarze l, gabinety g
WHERE l.numer_pwz='PWZ222' AND g.numer='201';

INSERT INTO terminarz_lekarzy (id_lekarza, id_gabinetu, dzien_tygodnia, godzina_od, godzina_do)
SELECT l.id_lekarza, g.id_gabinetu, 1, '8:00', '14:00'
FROM lekarze l, gabinety g
WHERE l.numer_pwz='PWZ333' AND g.numer='102';

INSERT INTO terminarz_lekarzy (id_lekarza, id_gabinetu, dzien_tygodnia, godzina_od, godzina_do)
SELECT l.id_lekarza, g.id_gabinetu, 1, '12:00', '18:00'
FROM lekarze l, gabinety g
WHERE l.numer_pwz='PWZ444' AND g.numer='202';

INSERT INTO terminarz_lekarzy (id_lekarza, id_gabinetu, dzien_tygodnia, godzina_od, godzina_do)
SELECT l.id_lekarza, g.id_gabinetu, 2, '10:00', '16:00'
FROM lekarze l, gabinety g
WHERE l.numer_pwz='PWZ555' AND g.numer='103';

INSERT INTO terminarz_lekarzy (id_lekarza, id_gabinetu, dzien_tygodnia, godzina_od, godzina_do)
SELECT l.id_lekarza, g.id_gabinetu, 3, '08:00', '16:00'
FROM lekarze l, gabinety g
WHERE l.numer_pwz='PWZ666' AND g.numer='203';


INSERT INTO wizyta (data, godzina, opis, status, id_pacjenta, id_lekarza, id_gabinetu)
SELECT '2026-01-12', '10:00', 'Kontrola', 'zaplanowana',
       p.id_pacjenta, l.id_lekarza, g.id_gabinetu
FROM pacjent p
JOIN lekarze l ON l.numer_pwz='PWZ111'
JOIN gabinety g ON g.numer='101'
WHERE p.pesel='12345678901';

INSERT INTO recepty (data_wydania, id_wizyty)
SELECT CURRENT_DATE, w.id_wizyty
FROM wizyta w
WHERE w.data='2026-01-12' AND w.godzina='10:00'
ON CONFLICT DO NOTHING;

INSERT INTO leki (nazwa, producent) VALUES
('Ibuprofen','Aflofarm'), ('Izotek', 'Egis'), ('Euthyrox', 'Merck'), ('Asentra', 'Krka'), ('Dostinex', 'Pfizer'), ('Nimesil', 'Berlin Chemie'), ('Kelzy', 'Exeltis'), ('EstazolaM', 'Polfarmex')
ON CONFLICT (nazwa, producent) DO NOTHING;

INSERT INTO recepta_lek (id_recepty, id_leku, dawkowanie)
SELECT r.id_recepty, lk.id_leku, '1 tabletka co 8h przez 2 dni'
FROM recepty r, leki lk
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO platnosci (id_wizyty, kwota, id_formy, id_statusu)
SELECT w.id_wizyty, 300.00,
       (SELECT id_formy FROM forma_platnosci WHERE nazwa='karta'),
       (SELECT id_statusu FROM status_platnosci WHERE nazwa='oplacona')
FROM wizyta w
WHERE w.data='2026-01-12' AND w.godzina='10:00'
LIMIT 1;

SELECT w.*
FROM wizyta w
JOIN lekarze l ON l.id_lekarza = w.id_lekarza
WHERE l.numer_pwz='PWZ111'
  AND w.data='2026-01-12'
  AND w.godzina='10:00';





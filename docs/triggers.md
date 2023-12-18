# Les triggers

Les **triggers**, aussi appelés en français **déclencheurs**, permettent de lancer des actions avant ou après ajout, modification ou suppression de données sur des tables (ou des vues).

Les triggers peuvent par exemple être utilisés

* pour lancer le calcul de certains champs de manière automatique: date de dernière modification, utilisateur à l'origine d'un ajout
* pour contrôler certaines données avant enregistrement
* pour lancer des requêtes après certaines actions (historiques de modifications)

Des **fonctions trigger** sont associées aux triggers. Elles peuvent être écrites en **PL/pgSQL** ou d'autres languages (p. ex. PL/Python).
Une fonction trigger doit renvoyer soit NULL soit une valeur record ayant exactement la structure de la table pour laquelle le trigger a été lancé.
Lire les derniers paragraphes [ici pour en savoir plus](https://docs.postgresql.fr/16/plpgsql-trigger.html#PLPGSQL-DML-TRIGGER).

## Calcul automatique de certains champs

On crée une table `borne_incendie` pour pouvoir tester cette fonctionnalité:

```sql

CREATE TABLE z_formation.borne_incendie (
    id_borne serial primary key,
    code text NOT NULL,
    debit integer,
    geom geometry(point, 2154)
);
CREATE INDEX ON z_formation.borne_incendie USING GIST (geom);
```

On y ajoute des champs à renseigner de manière automatique

```sql
-- TRIGGERS
-- Modification de certains champs après ajout ou modification
-- Créer les champs dans la table
ALTER TABLE z_formation.borne_incendie ADD COLUMN modif_date date;
ALTER TABLE z_formation.borne_incendie ADD COLUMN modif_user text;
ALTER TABLE z_formation.borne_incendie ADD COLUMN longitude real;
ALTER TABLE z_formation.borne_incendie ADD COLUMN latitude real;
ALTER TABLE z_formation.borne_incendie ADD COLUMN donnee_validee boolean;
ALTER TABLE z_formation.borne_incendie ADD COLUMN last_action text;

```

On crée la fonction trigger qui ajoutera les métadonnées dans la table

```sql
-- Créer la fonction qui sera lancée sur modif ou ajout de données
CREATE OR REPLACE FUNCTION z_formation.ajout_metadonnees_modification()
RETURNS TRIGGER
AS $limite$
DECLARE newjsonb jsonb;
BEGIN

    -- on transforme l'enregistrement NEW (la ligne modifiée ou ajoutée) en JSON
    -- pour connaître la liste des champs
    newjsonb = to_jsonb(NEW);

    -- on peut ainsi tester si chaque champ existe dans la table
    -- avant de modifier sa valeur
    -- Par exemple, on teste si le champ modif_date est bien dans l'enregistrement courant
    IF newjsonb ? 'modif_date' THEN
        NEW.modif_date = now();
        RAISE NOTICE 'Date modifiée %', NEW.modif_date;
    END IF;

    IF newjsonb ? 'modif_user' THEN
        NEW.modif_user = CURRENT_USER;
    END IF;

    -- longitude et latitude
    IF newjsonb ? 'longitude' AND newjsonb ? 'latitude'
    THEN
        -- Soit on fait un UPDATE et les géométries sont différentes
        -- Soit on fait un INSERT
        -- Sinon pas besoin de calculer les coordonnées
        IF
            (TG_OP = 'UPDATE' AND NOT ST_Equals(OLD.geom, NEW.geom))
            OR (TG_OP = 'INSERT')
        THEN
            NEW.longitude = ST_X(ST_Centroid(NEW.geom));
            NEW.latitude = ST_Y(ST_Centroid(NEW.geom));
        END IF;
    END IF;

    -- Si je trouve un champ donnee_validee, je le mets à False pour revue par l'administrateur
    -- Je peux faire une symbologie dans QGIS qui montre les données modifiées depuis dernière validation
    IF newjsonb ? 'donnee_validee' THEN
        NEW.donnee_validee = False;
    END IF;

    -- Si je trouve un champ last_action, je peux y mettre UPDATE ou INSERT
    -- Pour savoir quelle est la dernière opération utilisée
    IF newjsonb ? 'last_action' THEN
        NEW.last_action = TG_OP;
    END IF;

    RETURN NEW;
END;
$limite$
LANGUAGE plpgsql
;
```

On crée enfin le déclencheur pour la ou les tables souhaitées, ce qui active le lancement de la fonction trigger précédente sur certaines actions:

```sql
-- Dire à PostgreSQL d'écouter les modifications et ajouts sur la table
CREATE TRIGGER trg_ajout_metadonnees_modification
BEFORE INSERT OR UPDATE ON z_formation.borne_incendie
FOR EACH ROW EXECUTE PROCEDURE z_formation.ajout_metadonnees_modification();
```

## Contrôles de conformité

Il est aussi possible d'utiliser les triggers pour lancer des contrôles sur les valeurs de certains champs. Par exemple, on peut ajouter un contrôle sur la géométrie lors de l'ajout ou de la modification de données: on vérifie si la géométrie est bien en intersection avec les objets de la table des communes

```sql
-- Contrôle de la géométrie
-- qui doit être dans la zone d'intérêt
-- On crée une fonction générique qui pourra s'appliquer pour toutes les couches
CREATE OR REPLACE FUNCTION z_formation.validation_geometrie_dans_zone_interet()
RETURNS TRIGGER  AS $limite$
BEGIN
    -- On vérifie l'intersection avec les communes, on renvoie une erreur si souci
    IF NOT ST_Intersects(
        NEW.geom,
        st_collectionextract((SELECT ST_Collect(geom) FROM z_formation.commune), 3)::geometry(multipolygon, 2154)
    ) THEN
        -- On renvoie une erreur
        RAISE EXCEPTION 'La géométrie doit se trouver dans les communes';
    END IF;

    RETURN NEW;
END;
$limite$
LANGUAGE plpgsql;

-- On l'applique sur la couches de test
DROP TRIGGER IF EXISTS trg_validation_geometrie_dans_zone_interet ON z_formation.borne_incendie;
CREATE TRIGGER trg_validation_geometrie_dans_zone_interet
BEFORE INSERT OR UPDATE ON z_formation.borne_incendie
FOR EACH ROW EXECUTE PROCEDURE z_formation.validation_geometrie_dans_zone_interet();
```

Si on essaye de créer un point dans la table `z_formation.borne_incendie` en dehors des communes, la base renverra une erreur.


## Écrire les actions produites sur une table

On crée d'abord une table qui permettra de stocker les actions

```sql

CREATE TABLE IF NOT EXISTS z_formation.log (
    id serial primary key,
    log_date timestamp,
    log_user text,
    log_action text,
    log_data jsonb
);
```

On peut maintenant créer un trigger qui stocke dans cette table les actions effectuées. Dans cet exemple, toutes les données sont stockées, mais on pourrait bien sûr choisir de simplifier cela.

```sql
CREATE OR REPLACE FUNCTION z_formation.log_actions()
RETURNS TRIGGER  AS $limite$
DECLARE
    row_data jsonb;
BEGIN
    -- We keep data
    IF TG_OP = 'INSERT' THEN
        -- for insert, we take the new data
        row_data = to_jsonb(NEW);
    ELSE
        -- for UPDATE and DELETE, we keep data before changes
        row_data = to_jsonb(OLD);
    END IF;

    -- We insert a new log item
    INSERT INTO z_formation.log (
        log_date,
        log_user,
        log_action,
        log_data
    )
    VALUES (
        now(),
        CURRENT_USER,
        TG_OP,
        row_data
    );
    IF TG_OP != 'DELETE' THEN
        RETURN NEW;
    ELSE
        RETURN OLD;
    END IF;
END;
$limite$
LANGUAGE plpgsql;

-- On l'applique sur la couches de test
-- On écoute après l'action, d'où l'utilisation de `AFTER`
-- On écoute pour INSERT, UPDATE ou DELETE
DROP TRIGGER IF EXISTS trg_log_actions ON z_formation.borne_incendie;
CREATE TRIGGER trg_log_actions
AFTER INSERT OR UPDATE OR DELETE ON z_formation.borne_incendie
FOR EACH ROW EXECUTE PROCEDURE z_formation.log_actions();

```

NB:

* Attention, ce type de tables de log peut vite devenir très grosse !
* pour un log d'audit plus évolué réalisé à partir de triggers, vous pouvez consulter [le dépôt audit_trigger](https://github.com/Oslandia/audit_trigger/blob/master/audit.sql)


Continuer vers [Correction des géométries invalides](./validate_geometries.md)

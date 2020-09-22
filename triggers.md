## Les triggers

Les **triggers**, aussi appelés en français **déclencheurs**, permettent de lancer des actions avant ou après ajout, modification ou suppression de données sur des tables (ou des vues).

Les triggers peuvent par exemple être utilisés

* pour lancer le calcul de certains champs de manière automatique: date de dernière modification, utilisateur à l'origine d'un ajout
* pour contrôler certaines données avant enregistrement
* pour lancer des requêtes après certaines actions (historiques de modifications)

### Calcul automatique de certains champs

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

```

On crée la fonction trigger qui ajoutera les métadonnées dans la table

```sql
-- Créer la fonction qui sera lancée sur modif ou ajout de données
CREATE OR REPLACE FUNCTION z_formation.ajout_metadonnees_modification()
RETURNS TRIGGER
AS $limite$
DECLARE newjsonb jsonb;
BEGIN

    -- on transforme l'enregistrement en JSON
    -- pour connaître la liste des champs
    newjsonb = to_jsonb(NEW);

    -- on peut ainsi tester si chaque champ existe dans la table
    -- avant de modifier sa valeur
    IF newjsonb ? 'modif_date'THEN
        NEW.modif_date = now();
        RAISE NOTICE 'Date modifiée %', NEW.modif_date;
    END IF;

    IF newjsonb ? 'modif_user' THEN
        NEW.modif_user = CURRENT_USER;
    END IF;

    -- Ne modifier longitude et latitude que si la géométrie a été modifiée
    IF NOT ST_Equals(OLD.geom, NEW.geom)
        AND newjsonb ? 'longitude'
        AND newjsonb ? 'latitude'
    THEN
        NEW.longitude = ST_X(NEW.geom);
        NEW.latitude = ST_Y(NEW.geom);
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
    -- On vérifie l'intersection avec les départements, on renvoit une erreur si souci
    IF NOT ST_Intersects(
        NEW.geom,
        (SELECT ST_Collect(geom) FROM z_formation.commune)
    ) THEN
        -- On renvoit une erreur
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

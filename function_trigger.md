---
Title: Mise à jour automatique
Favicon: logo.svg
Sibling: yes
...

[TOC]

## Mise à jour automatique de champs

Création de la fonction trigger de mise à jour du champs longueur
```sql
- longueur_geom()
CREATE FUNCTION z_formation.longueur_geom() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
    NEW.longueur = ST_Length(NEW.geom);

    RETURN NEW;
END;
$$;
```

Utilisation du trigger de mise à jour du champs longueur avant chaque insert
```sql
-- voie trigger_insert
CREATE TRIGGER trigger_insertz_formation_chemin_longueur_geom 
    BEFORE INSERT ON z_formation.chemin 
    FOR EACH ROW 
    EXECUTE PROCEDURE z_formation.longueur_geom();
```

Utilisation du trigger de mise à jour du champs longueur avant chaque update si le champs geom ou longueur ont été modifié
```sql
-- voie trigger_update
CREATE TRIGGER trigger_update_z_formation_chemin_longueur_geom 
    BEFORE UPDATE ON z_formation.chemin 
    FOR EACH ROW 
    WHEN (OLD.geom IS DISTINCT FROM NEW.geom OR OLD.longueur IS DISTINCT FROM NEW.longueur)
    EXECUTE PROCEDURE z_formation.longueur_geom();
```

# Fusionner des géométries

On souhaite créer une seule géométrie qui est issue de la **fusion de toutes les géométries** regroupées par un critère (nature, code, etc.)

Par exemple un polygone fusionnant les zonages qui partagent le même type

```sql
SELECT count(id_zone_urba) AS nb_objets, typezone,
ST_Union(geom) AS geom
FROM z_formation.zone_urba
GROUP BY typezone
```

On souhaite parfois **fusionner toutes les géométries qui sont jointives**.
Par exemple, on veut fusionner **toutes les parcelles jointives** pour créer des blocs.

```sql
DROP TABLE IF EXISTS z_formation.bloc_parcelle_havre;
CREATE TABLE z_formation.bloc_parcelle_havre AS
SELECT
row_number() OVER() AS id,
string_agg(id::text, ', ') AS ids, t.geom::geometry(polygon, 2154) AS geom
FROM (
        SELECT
        (St_Dump(ST_Union(a.geom))).geom AS geom
        FROM z_formation.parcelle_havre AS a
        WHERE ST_IsValid(a.geom)
) t
JOIN z_formation.parcelle_havre AS p
    ON ST_Intersects(p.geom, t.geom)
GROUP BY t.geom
;
ALTER TABLE z_formation.bloc_parcelle_havre ADD PRIMARY KEY (id);
CREATE INDEX ON z_formation.bloc_parcelle_havre USING GIST (geom);
```

Continuer vers [Les triggers](./triggers.md)

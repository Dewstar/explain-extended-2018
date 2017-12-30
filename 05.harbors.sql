WITH	RECURSIVE
        resources AS
	(
	SELECT	'////####^^^' || CHR(34) || CHR(34) || CHR(34) || CHR(34) || '... '::TEXT tile_resources,
		'/#^' || CHR(34) || '.????'::TEXT harbor_resources
	),
        harbors (rn, x, y, pier1, pier2) AS
	(
	VALUES
	        (1, -1, -1, 0, 1),
	        (2, 1, -1, 1, 2),
	        (3, 3, 0, 1, 2),
	        (4, 5, 2, 2, 3),
	        (5, 5, 4, 3, 4),
	        (6, 4, 5, 3, 4),
	        (7, 2, 5, 4, 5),
	        (8, 0, 3, 5, 0),
	        (9, -1, 1, 5, 0)
	),
	harbor_resources AS
	(
	SELECT  '/#>".????'::TEXT harbor_resources
	)
SELECT  resource, rn, x, y, pier1, pier2
FROM    harbors
CROSS JOIN
        resources
JOIN    LATERAL
        (
        SELECT  resource, ROW_NUMBER() OVER (ORDER BY RANDOM()) rn
        FROM    REGEXP_SPLIT_TO_TABLE(harbor_resources, '') q (resource)
        ) q
USING   (rn)
ORDER BY
        RANDOM()
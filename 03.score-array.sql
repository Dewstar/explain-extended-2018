SELECT  SETSEED(0.201703);

WITH	RECURSIVE
	resources AS
	(
	SELECT	'////####^^^' || CHR(34) || CHR(34) || CHR(34) || CHR(34) || '... '::TEXT tile_resources
	),
	tiles (rn, x, y) AS
	(
	VALUES
		(1, 0, 0),
		(2, 1, 0),
		(3, 2, 0),
		(4, 3, 1),
		(5, 4, 2),
		(6, 4, 3),
		(7, 4, 4),
		(8, 3, 4),
		(9, 2, 4),
		(10, 1, 3),
		(11, 0, 2),
		(12, 0, 1),
		(13, 1, 1),
		(14, 2, 1),
		(15, 3, 2),
		(16, 3, 3),
		(17, 2, 3),
		(18, 1, 2),
		(19, 2, 2)
	),
	layout AS
	(
        SELECT	*,
                CASE resource
                WHEN ' ' THEN
                        NULL
                ELSE
                        rn + SUM(CASE resource WHEN ' ' THEN -1 ELSE 0 END) OVER (ORDER BY rn)
                END score_rn
        FROM	tiles
        JOIN	(
                SELECT	ROW_NUMBER() OVER (ORDER BY RANDOM()) rn,
                        resource
                FROM	resources
                CROSS JOIN
                        LATERAL
                        REGEXP_SPLIT_TO_TABLE(tile_resources, '') q (resource)
                ) tr
        USING	(rn)
	),
	score AS
	(
	SELECT	1 attempt,
		ARRAY_AGG(s ORDER BY RANDOM()) score_array,
		NULL::BIGINT desert
	FROM	generate_series(2, 12) s
	CROSS JOIN
		generate_series(1, 2) r
	WHERE	s <> 7
		AND NOT (r = 2 AND s IN (2, 12))
	UNION ALL
	SELECT	attempt + 1 attempt,
		sa.score_array,
		(
		SELECT  rn
		FROM    layout
		WHERE   score_rn IS NULL
		) desert
	FROM	(
		SELECT	*
		FROM	score
		WHERE	EXISTS
			(
			SELECT	NULL
			FROM	(
				SELECT	*
				FROM	UNNEST(score_array) WITH ORDINALITY q(s1, score_rn)
				JOIN	layout
				USING	(score_rn)
				) sc1
			JOIN	(
				SELECT	*
				FROM	UNNEST(score_array) WITH ORDINALITY q(s2, score_rn)
				JOIN	layout
				USING	(score_rn)
				) sc2
			ON	s1 IN (6, 8)
				AND s2 IN (6, 8)
				AND ((sc1.x - sc2.x), (sc1.y - sc2.y)) IN ((-1, -1), (-1, 0), (0, -1), (0, 1), (1, 0), (1, 1))
			)
		) s
	CROSS JOIN
		LATERAL
		(
		SELECT	ARRAY_AGG(score ORDER BY RANDOM()) score_array
		FROM	UNNEST(score_array) WITH ORDINALITY q(score, score_rn)
		) sa
	),
	score_good AS
	(
	SELECT	score, score_rn
	FROM	(
		SELECT	*
		FROM	score
		ORDER BY
			attempt DESC
		LIMIT 1
		) s
	CROSS JOIN
		LATERAL
		UNNEST(score_array) WITH ORDINALITY q (score, score_rn)
	)
SELECT	*
FROM	score_good

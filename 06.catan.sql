SELECT  SETSEED(0.201704);

WITH	RECURSIVE
	resources AS
	(
	SELECT	'////####^^^' || CHR(34) || CHR(34) || CHR(34) || CHR(34) || '... '::TEXT tile_resources,
		'/#^' || CHR(34) || '.????'::TEXT harbor_resources
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
	score AS
	(
	SELECT	1 attempt,
		ARRAY_AGG(s ORDER BY RANDOM()) score_array
	FROM	generate_series(2, 12) s
	CROSS JOIN
		generate_series(1, 2) r
	WHERE	s <> 7
		AND NOT (r = 2 AND s IN (2, 12))
	UNION ALL
	SELECT	attempt + 1 attempt,
		sa.score_array
	FROM	(
		SELECT	*
		FROM	score
		WHERE	EXISTS
			(
			SELECT	NULL
			FROM	(
				SELECT	*
				FROM	UNNEST(score_array) WITH ORDINALITY q(s1, rn)
				JOIN	tiles
				USING	(rn)
				) sc1
			JOIN	(
				SELECT	*
				FROM	UNNEST(score_array) WITH ORDINALITY q(s2, rn)
				JOIN	tiles t
				USING	(rn)
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
	),
	layout AS
	(
	SELECT	*
	FROM	(
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
		) t
	LEFT JOIN
		score_good
	USING	(score_rn)
	ORDER BY
		rn
	)
SELECT	row
FROM	(
	SELECT	r,
		STRING_AGG(COALESCE(letter, ' '), '' ORDER BY c) AS row
	FROM	generate_series(0, 70) r
	CROSS JOIN
		generate_series(0, 89) c
	LEFT JOIN
		(
		SELECT	*
		FROM    (
		        SELECT  *,
		                ROW_NUMBER() OVER (PARTITION BY r, c ORDER BY layer DESC) rn
		        FROM    (
                                SELECT	10 height,
                                        16 width
                                ) d
                        CROSS JOIN
                                LATERAL
                                (
                                SELECT  letter, r, c, layer
                                FROM	layout
                                CROSS JOIN
                                        LATERAL
                                        (
                                        SELECT	height * x + 15 center_r,
                                                width * y - (width / 2)::INT * x + 24 center_c
                                        ) c
                                CROSS JOIN
                                        LATERAL
                                        (
                                        SELECT	*
                                        FROM	(
                                                SELECT	1 layer, resource letter, center_r + rs r, center_c + cs c
                                                FROM	(
                                                        SELECT	height * 1.5 * 0.8 th, width * 0.9 tw
                                                        ) t
                                                CROSS JOIN
                                                        generate_series(-(th / 2)::INT, (th / 2)::INT) rs
                                                CROSS JOIN
                                                        generate_series(-(tw / 2)::INT, (tw / 2)::INT ) cs
                                                CROSS JOIN
                                                        LATERAL
                                                        (
                                                        SELECT	rs::FLOAT / th rsf, cs::FLOAT / tw csf
                                                        ) f
                                                WHERE	rsf BETWEEN -0.25 AND 0.25
                                                        OR
                                                        ABS(csf) BETWEEN 0 AND 1 - ABS(rsf * 2)
                                                UNION ALL
                                                SELECT	2 layer, ' ', center_r + rs r, center_c + cs c
                                                FROM	(
                                                        SELECT	height * 1.5 * 0.35 th, width * 0.35 tw
                                                        ) t
                                                CROSS JOIN
                                                        generate_series(-(th / 2)::INT, (th / 2)::INT) rs
                                                CROSS JOIN
                                                        generate_series(-(tw / 2)::INT, (tw / 2)::INT ) cs
                                                CROSS JOIN
                                                        LATERAL
                                                        (
                                                        SELECT	rs::FLOAT / th rsf, cs::FLOAT / tw csf
                                                        ) f
                                                WHERE	rsf BETWEEN -0.25 AND 0.25
                                                        OR
                                                        ABS(csf) BETWEEN 0 AND 1 - ABS(rsf * 2)
                                                UNION ALL
                                                SELECT	3 layer, score_letter letter, center_r r, center_c + pos - 1 c
                                                FROM	REGEXP_SPLIT_TO_TABLE(score::TEXT, '') WITH ORDINALITY l(score_letter, pos)
                                                ) q
                                        ) q2
                                UNION ALL
                                SELECT  letter, r, c, 4 layer
                                FROM    harbors
                                JOIN    LATERAL
                                        (
                                        SELECT  resource, ROW_NUMBER() OVER (ORDER BY RANDOM()) rn
                                        FROM    resources
                                        CROSS JOIN
                                                LATERAL
                                                REGEXP_SPLIT_TO_TABLE(harbor_resources, '') q (resource)
                                        ) q2
                                USING   (rn)
                                CROSS JOIN
                                        LATERAL
                                        (
                                        SELECT	height * x + 15 center_r,
                                                width * y - (width / 2)::INT * x + 25 center_c
                                        ) c
                                CROSS JOIN
                                        LATERAL
                                        (
                                        SELECT  resource letter, center_r r, center_c c
                                        UNION ALL
                                        SELECT  letter, r, c
                                        FROM    (
                                                SELECT  pier1
                                                UNION ALL
                                                SELECT  pier2
                                                ) p (pier)
                                        CROSS JOIN
                                                LATERAL
                                                (
                                                SELECT  SUBSTRING('|\/|\/', (pier + 1), 1) letter,
                                                        center_r + ((ARRAY[0.4, 0.2, -0.2, -0.4, -0.2, 0.2])[pier + 1] * height * 1.5 * 0.8)::INT r,
                                                        center_c + ((ARRAY[0, 0.3, 0.3, 0, -0.3, -0.3])[pier + 1] * width * 0.9)::INT c
                                                ) pl
                                        ) p2
                                ) q3
			) l
			WHERE	rn = 1
		) t
	USING	(r, c)
	GROUP BY
		r
	) q
ORDER BY
	r

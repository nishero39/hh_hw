-- ============================================================
-- Домашнее задание к лекции «SQL. Продвинутый»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Новиков Григорий Андреевич
-- ============================================================

SET search_path TO hh_school;

-- ============================================================
-- БЛОК А. Качество и подготовка данных
-- ============================================================

-- ЗАДАНИЕ А1

-- Проблема 1: звонки без привязки к отклику. То есть сама запись звонка есть но она не привязана к конкретному отклику.

SELECT count(*) AS nulls_calls
FROM calls
WHERE response_id IS NULL 

SELECT count(*) AS nulls_messages
FROM messages
WHERE response_id IS NULL 

SELECT
    call_id,
    response_id,
    employer_id,
    applicant_id,
    vacancy_id,
    call_at
FROM calls
WHERE response_id IS NULL
ORDER BY call_id

-- В данном случае мы имеем 8 записей где мы не можем связать звонок с откликом(response_id is NULL). 
-- Айдишники звонков: от 700244 до 700251 включительно. То есть звонок есть, но без привязки
--  к конкретному отклику. Учитывая что мы анализируем коммуникацию с работодателем уже после отклика, нам такие записи не помешают.
-- В таблице с сообщениями нет случаев где response_id is NULL.


-- Проблема 2: несовпадения у отдельного отлика кандидата/работодателя/id вакансии. Со звонками.

SELECT
    c.call_id,
    c.response_id,
    c.vacancy_id AS call_vacancy_id,
    r.vacancy_id AS response_vacancy_id,
    c.employer_id AS call_employer_id,
    v.employer_id AS vacancy_employer_id,
    c.applicant_id,
    r.resume_id
FROM calls AS c
LEFT JOIN responses AS r
    ON c.response_id = r.response_id
LEFT JOIN vacancies AS v
    ON r.vacancy_id = v.vacancy_id
WHERE c.response_id IS NOT NULL
  AND (
      c.vacancy_id <> r.vacancy_id
      OR c.employer_id <> v.employer_id
      OR c.applicant_id <> r.resume_id
  )
ORDER BY c.call_id

-- Ничего не вывело. Значит нет ситуаций где возникли несостыковки.

-- Аналогично но уже с сообщениями

SELECT
    m.message_id,
    m.response_id,
    m.vacancy_id AS message_vacancy_id,
    r.vacancy_id AS response_vacancy_id,
    m.employer_id AS message_employer_id,
    v.employer_id AS vacancy_employer_id,
    m.applicant_id,
    r.resume_id
FROM messages AS m
JOIN responses AS r
    ON m.response_id = r.response_id
JOIN vacancies AS v
    ON r.vacancy_id = v.vacancy_id
WHERE m.vacancy_id <> r.vacancy_id
   OR m.employer_id <> v.employer_id
   OR m.applicant_id <> r.resume_id
ORDER BY m.message_id

-- Также не вывело ни одной записи.
-- Проверяем несоответствие id работодателя / id соискателя в таблицах звонков и сообщений
SELECT 
	c.response_id,
	c.employer_id AS calls_employer_id,
	c.applicant_id AS calls_applicant_id,
	m.employer_id AS message_employer_id,
	m.applicant_id AS message_applicant_id
FROM calls AS c
LEFT JOIN messages AS m
	ON c.response_id = m.response_id
WHERE c.employer_id <> m.employer_id
	OR c.applicant_id <> m.applicant_id
ORDER BY c.response_id

-- Ни со звонками ни с сообщениями проблем нет. В связанных таблицах идентификаторы успешно согласуются.
-- Также отдельно проверка на несоответствие идентификаторов id работодателя и id соискателя в таблицах сообщений и звонков не дала
-- результатов. Все успешно согласуется.

-- Проблема 3: время события относительно отклика. А вдруг коммуникация произошла раньше отлика. Такую коммуникацию нам учитывать не следует.
-- Т.к. когда мы будем смотреть насколько быстро отвечает работодатель - такие случаи дадут нам отрицательное значения и могут
-- исказить расчеты. Если такие случаи будут найдены их необходимо будет исключить в рамках нашего иследования.
-- Хотя в целом сам факт коммуникации есть и возможно при решении других задач можно было бы оставить.
SELECT
    c.call_id,
    c.response_id,
    r.created_at,
    c.call_at,
    r.created_at - c.call_at AS time_difference
FROM calls AS c
JOIN responses AS r
    ON c.response_id = r.response_id
WHERE c.call_at < r.created_at
ORDER BY c.call_id

-- Случаев когда звонок произошел раньше отклика не нашлось

-- Аналогично для сообщений:

SELECT
    m.message_id,
    m.response_id,
    r.created_at,
    m.sent_at,
    r.created_at - m.sent_at AS time_difference
FROM messages AS m
JOIN responses AS r
    ON m.response_id = r.response_id
WHERE m.sent_at < r.created_at
ORDER BY m.message_id

-- таких случаев не обнаружено в таблице. Ни в звонках ни в сообщениях. Поэтому нет необходимости исключать что-либо на данном этапе.

-- Проблема 4: согласованность значений внутри одной строки между собой. Вдруг получится так что статус звонка "successful" но при этом
-- duration NULL, это было бы странно. Либо статус unsuccessful но при этом duration какое то конкретное число.


SELECT
    call_id,
    status,
    call_duration
FROM calls
WHERE (status = 'successful' AND (call_duration IS NULL OR call_duration <= 0))
	OR (status IN ('unsuccessful', 'error') AND call_duration IS NOT NULL)

-- Несоотвествия описанные в проблеме не обнаружились. Значит на данном этапе мы тоже ничего не убираем.

-- Проблема 5: вдруг поле message_text в таблице messages будет NULL, то есть пустым. Это было бы достаточно странно.
-- Такие случаи не стоит учитывать как полноценная коммуникация т.к. содержательного смысла они в себе не несут.
-- Аналогично и в таблице звонков где duration = 0 или NULL но мы это уже проверили в прошлом запросе.

SELECT count(*)
FROM messages
WHERE message_text IS NULL OR message_text = ''

-- Количество таких случаев = 0. Значит они отсутствуют в таблице и все сообщения имеют хоть какое то содержание.


-- Исследуем call_duration успешных звонков. 

WITH percentile_info AS (
	SELECT 
	PERCENTILE_CONT(0.99) WITHIN GROUP (
		ORDER BY call_duration
	) AS p99,
	PERCENTILE_CONT(0.5) WITHIN GROUP (
		ORDER BY call_duration 
	) AS p50
	FROM calls
)
SELECT 
	ROUND(AVG(c.call_duration), 2) AS average_duration,
	ROUND(pc.p50::numeric, 2) AS median_call_duration,
	ROUND(pc.p99::numeric, 2) AS p99_call_duration,
	COUNT(c.call_id) FILTER (WHERE c.call_duration > pc.p99) AS cnt_over_p99,
	ROUND(COUNT(c.call_id) FILTER (WHERE c.call_duration > pc.p99) * 100.0 / NULLIF(count(*), 0), 1) AS percent_over_p99,
	ROUND(AVG(c.call_duration) FILTER (WHERE c.call_duration <= pc.p99), 2) AS avg_without_p99
FROM calls AS c
CROSS JOIN percentile_info AS pc
WHERE status = 'successful'
GROUP BY pc.p99, pc.p50

-- Средняя длительность звонка: 467.28 сек. Медианное значение = 438 сек. 99-перцентиль = 890.4 сек.
-- Количество звонков выше 99-перцентиля = 2. В процентном соотношении от всех звонков это 1.1%. 
-- После исключения значений выше 99-перцентиля средняя длительность стала 462.49 сек.
-- Учитывая что среднее значение всего в 2 раза меньше 99-перцентиля а также то, что разница средних значений длительности звонка
-- с учетом и без учета 99-перцентиля не такая большая(где-то 1%), я считаю это допустимыми выбросами.

-- Ахахаа, я только сейчас понял что зря посчитал процентное соотношение количества звонков выше 99-перцентиля от всех звонков)
-- Тут и так понятно что 99 процентов значений меньше, а остальной процент больше. Ну ладно, оставлю)


-- ============================================================
-- БЛОК Б. История коммуникаций
-- ============================================================


WITH calls_7d AS (
	SELECT 
		r.response_id AS response_id,
		c.call_id AS event_id,
		c.employer_id AS employer_id,
		c.call_at AS event_at,
		'call' AS event_type
	FROM responses AS r
	JOIN calls AS c
		ON r.response_id = c.response_id
	WHERE r.created_at <= c.call_at
		AND r.created_at + INTERVAL '7 days' > c.call_at
		AND c.caller_role = 'employer'
),
messages_7d AS (
	SELECT 
		r.response_id AS response_id,
		m.message_id AS event_id,
		m.employer_id AS employer_id,
		m.sent_at AS event_at,
		'message' AS event_type
	FROM responses AS r
	JOIN messages AS m
		ON r.response_id = m.response_id
	WHERE r.created_at <= m.sent_at
		AND r.created_at + INTERVAL '7 days' > m.sent_at
		AND m.sender_role = 'employer'
),
events AS (
	SELECT
		response_id,
		event_id,
		employer_id,
		event_at,
		event_type
	FROM calls_7d
	UNION ALL
	SELECT 
		response_id,
		event_id,
		employer_id,
		event_at,
		event_type
	FROM messages_7d
),
timeline AS (
	SELECT response_id, event_id, employer_id, event_at, event_type,
		ROW_NUMBER() OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS events_so_far,
		LAG(event_at) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS previous_pred_event,
		LEAD(event_type) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS next_type_event,
		COUNT(*) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
			ROWS BETWEEN UNBOUNDED PRECEDING
				AND CURRENT ROW
		) AS cnt_at_begin,
		FIRST_VALUE(event_type) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS type_first_event,
		LAST_VALUE(event_type) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
			ROWS BETWEEN UNBOUNDED PRECEDING
         		AND UNBOUNDED FOLLOWING
		) AS type_last_event
	FROM events
)
		
SELECT 
	COUNT(*) AS cnt,
	COUNT(DISTINCT response_id) AS uniq_responses,
	COUNT(response_id) FILTER (WHERE event_type = 'call') AS cnt_calls, 
	COUNT(response_id) FILTER (WHERE event_type = 'message') AS cnt_messages
FROM events
		

-- Итого мы получили: 1096 событий, из них 382 различных отклика с коммуникацией, 108 звонков и 988 сообщений.
-- Сообщений как мы видим гораздо больше в коммуникации.

-- 3 пункт задания

WITH calls_7d AS (
	SELECT 
		r.response_id AS response_id,
		c.call_id AS event_id,
		c.employer_id AS employer_id,
		c.call_at AS event_at,
		'call' AS event_type
	FROM responses AS r
	JOIN calls AS c
		ON r.response_id = c.response_id
	WHERE r.created_at <= c.call_at
		AND r.created_at + INTERVAL '7 days' > c.call_at
		AND c.caller_role = 'employer'
),
messages_7d AS (
	SELECT 
		r.response_id AS response_id,
		m.message_id AS event_id,
		m.employer_id AS employer_id,
		m.sent_at AS event_at,
		'message' AS event_type
	FROM responses AS r
	JOIN messages AS m
		ON r.response_id = m.response_id
	WHERE r.created_at <= m.sent_at
		AND r.created_at + INTERVAL '7 days' > m.sent_at
		AND m.sender_role = 'employer'
),
events AS (
	SELECT
		response_id,
		event_id,
		employer_id,
		event_at,
		event_type
	FROM calls_7d
	UNION ALL
	SELECT 
		response_id,
		event_id,
		employer_id,
		event_at,
		event_type
	FROM messages_7d
),
timeline AS (
	SELECT response_id, event_id, employer_id, event_at, event_type,
		ROW_NUMBER() OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS events_so_far,
		LAG(event_at) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS previous_pred_event,
		LEAD(event_type) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS next_type_event,
		COUNT(*) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
			ROWS BETWEEN UNBOUNDED PRECEDING
				AND CURRENT ROW
		) AS cnt_at_begin,
		FIRST_VALUE(event_type) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS type_first_event,
		LAST_VALUE(event_type) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
			ROWS BETWEEN UNBOUNDED PRECEDING
         		AND UNBOUNDED FOLLOWING
		) AS type_last_event
	FROM events
),
vitrine AS (
	SELECT r.response_id, v.employer_id, v.professional_role, r.status,
		COUNT(t.event_id) AS cnt_events,
		COUNT(t.event_id) FILTER (WHERE t.event_type = 'call') AS cnt_calls,
        COUNT(t.event_id) FILTER (WHERE t.event_type = 'message') AS cnt_messages,
		MAX(t.event_at) FILTER (WHERE t.events_so_far = 1) AS first_event_at,
		MAX(t.type_first_event) AS type_first_event,
		MAX(t.event_type) FILTER (WHERE events_so_far = 2) AS type_second_event,
		MAX(t.type_last_event) AS type_last_event,
		MAX(EXTRACT(EPOCH FROM (t.event_at - r.created_at)) / 3600.0) FILTER (WHERE t.events_so_far = 1) AS cnt_hours_first_event,
		MAX(EXTRACT(EPOCH FROM (t.event_at - t.previous_pred_event)) / 3600.0) AS max_hours_between_events
	FROM responses AS r
	JOIN vacancies AS v
		ON r.vacancy_id = v.vacancy_id
	LEFT JOIN timeline t
		ON r.response_id = t.response_id
	GROUP BY r.response_id,
			v.employer_id,
        	v.professional_role,
        	r.status
)
SELECT 
	COUNT(response_id) AS cnt_rows,
	COUNT(response_id) FILTER (WHERE cnt_events > 0) AS cnt_responses_events,
	COUNT(response_id) FILTER (WHERE cnt_events = 0) AS cnt_responses_without_events,
	COUNT(response_id) FILTER (WHERE type_first_event = 'message') AS cnt_first_message,
	COUNT(response_id) FILTER (WHERE type_first_event = 'call') AS cnt_first_call
FROM vitrine

-- Количество строк получилось - 628. При это количество откликов с коммуникацией - 382. 
-- Без коммуникации соотвественно 246. Отликов где первой коммуникацией было сообщение - 314.
-- Откликов где был звонок первой коммуникацией - 68. 
-- Мы видим что сообщения как метод первой коммуникации встречается гораздо чаше. Также заметно что в большой части всех откликов
-- коммуникация в целом отсуствует.

-- events - одна строка - одна коммуникация
-- timeline - те же строки + 6 столбцов с результатами партиций
-- vitrine - одна строка - один отклик 



-- ============================================================
-- БЛОК В. Сравнение работодателей
-- ============================================================

WITH calls_7d AS (
	SELECT 
		r.response_id AS response_id,
		c.call_id AS event_id,
		c.employer_id AS employer_id,
		c.call_at AS event_at,
		'call' AS event_type
	FROM responses AS r
	JOIN calls AS c
		ON r.response_id = c.response_id
	WHERE r.created_at <= c.call_at
		AND r.created_at + INTERVAL '7 days' > c.call_at
		AND c.caller_role = 'employer'
),
messages_7d AS (
	SELECT 
		r.response_id AS response_id,
		m.message_id AS event_id,
		m.employer_id AS employer_id,
		m.sent_at AS event_at,
		'message' AS event_type
	FROM responses AS r
	JOIN messages AS m
		ON r.response_id = m.response_id
	WHERE r.created_at <= m.sent_at
		AND r.created_at + INTERVAL '7 days' > m.sent_at
		AND m.sender_role = 'employer'
),
events AS (
	SELECT
		response_id,
		event_id,
		employer_id,
		event_at,
		event_type
	FROM calls_7d
	UNION ALL
	SELECT 
		response_id,
		event_id,
		employer_id,
		event_at,
		event_type
	FROM messages_7d
),
timeline AS (
	SELECT response_id, event_id, employer_id, event_at, event_type,
		ROW_NUMBER() OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS events_so_far,
		LAG(event_at) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS previous_pred_event,
		LEAD(event_type) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS next_type_event,
		COUNT(*) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
			ROWS BETWEEN UNBOUNDED PRECEDING
				AND CURRENT ROW
		) AS cnt_at_begin,
		FIRST_VALUE(event_type) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS type_first_event,
		LAST_VALUE(event_type) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
			ROWS BETWEEN UNBOUNDED PRECEDING
         		AND UNBOUNDED FOLLOWING
		) AS type_last_event
	FROM events
),
vitrine AS (
	SELECT r.response_id, v.employer_id, v.professional_role, r.status,
		COUNT(t.event_id) AS cnt_events,
		COUNT(t.event_id) FILTER (WHERE t.event_type = 'call') AS cnt_calls,
        COUNT(t.event_id) FILTER (WHERE t.event_type = 'message') AS cnt_messages,
		MAX(t.event_at) FILTER (WHERE t.events_so_far = 1) AS first_event_at,
		MAX(t.type_first_event) AS type_first_event,
		MAX(t.event_type) FILTER (WHERE events_so_far = 2) AS type_second_event,
		MAX(t.type_last_event) AS type_last_event,
		MAX(EXTRACT(EPOCH FROM (t.event_at - r.created_at)) / 3600.0) FILTER (WHERE t.events_so_far = 1) AS cnt_hours_first_event,
		MAX(EXTRACT(EPOCH FROM (t.event_at - t.previous_pred_event)) / 3600.0) AS max_hours_between_events
	FROM responses AS r
	JOIN vacancies AS v
		ON r.vacancy_id = v.vacancy_id
	LEFT JOIN timeline t
		ON r.response_id = t.response_id
	GROUP BY r.response_id,
			v.employer_id,
        	v.professional_role,
        	r.status
),
ranked_employers AS (
	SELECT professional_role, employer_id,
	COUNT(response_id) AS cnt_responses,
	COUNT(response_id) FILTER (WHERE cnt_events > 0) AS cnt_responses_7d,
	ROUND(100.0 * COUNT(response_id) FILTER (WHERE cnt_events > 0) / NULLIF(COUNT(response_id), 0), 2) AS dolya_7d,
	ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cnt_hours_first_event)::numeric, 2) AS p50_first_event,
	ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY cnt_hours_first_event)::numeric, 2) AS p90_first_event,
	ROUND(100.0 * COUNT(response_id) FILTER (WHERE status = 'invited') / NULLIF(COUNT(response_id), 0), 2) AS ctr_invited,
	DENSE_RANK() OVER (
		PARTITION BY professional_role
		ORDER BY 
			100.0 * COUNT(response_id) FILTER (WHERE cnt_events > 0) / NULLIF(COUNT(response_id), 0) DESC,
			PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cnt_hours_first_event)
	) AS rank_within_role
	FROM vitrine 
	GROUP BY professional_role, employer_id
	HAVING COUNT(response_id) >= 8
)
SELECT professional_role, rank_within_role, employer_id
FROM ranked_employers
WHERE rank_within_role IN (1, 2)
ORDER BY professional_role, rank_within_role, employer_id

--Аналитик данных	1	110
--Аналитик данных	2	101
--Дата-инженер	1	106
--Дата-инженер	2	101
--Продуктовый аналитик	1	110
--Продуктовый аналитик	2	103
--Разработчик	1	104
--Разработчик	2	112
--Тестировщик	1	108
--Тестировщик	2	107	

--Можем увидеть что в направлении аналитики работодатель 110 определенно самый активный. При этом 101 также старается не уступать.
-- По остальным направлениям работодатели встречаются единожды - полагаю каждому важна конкретная роль в данный момент.

WITH all_messages_7d AS (
	SELECT 
		r.response_id AS response_id,
		m.message_id AS event_id,
		m.employer_id AS employer_id,
		m.sent_at AS event_at,
		m.sender_role AS sender_role
	FROM responses AS r
	JOIN messages AS m
		ON r.response_id = m.response_id
	WHERE r.created_at <= m.sent_at
		AND r.created_at + INTERVAL '7 days' > m.sent_at
),
all_messages_timeline AS (
	SELECT response_id, event_id, employer_id, event_at, sender_role,
		LAG(sender_role) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_id
		) AS previous_sender_role,
		LAG(event_at) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_id
		) AS previous_message_at
	FROM all_messages_7d
),
employers_events_info AS (
	SELECT 
		employer_id,
		COUNT(*) AS cnt_replies,
		ROUND(AVG(response_hours), 3) AS avg_time_replies,
		PERCENTILE_CONT(0.5) WITHIN GROUP (
			ORDER BY response_hours
		) AS median_time_replies,
		PERCENTILE_CONT(0.9) WITHIN GROUP (
			ORDER BY response_hours
		) AS p90_time_replies
	FROM (
		SELECT 
			employer_id,
			EXTRACT(EPOCH FROM (event_at - previous_message_at)) / 3600.0
	            AS response_hours
	    FROM all_messages_timeline
	    WHERE sender_role = 'employer' AND previous_sender_role = 'applicant'
	) AS replies
	GROUP BY employer_id
	ORDER BY median_time_replies
)
SELECT 
	SUM(cnt_replies) OVER () AS  total_cnt,
	employer_id,
	median_time_replies AS min_median,
	p90_time_replies AS p90_replie
FROM employers_events_info
LIMIT 1
-- ORDER BY по median_time_replies не прописываю в SELECT так как в CTE employers_events_info 
-- уже отсортировал по median_time_replies

-- Общее количество найденных ответов: 749
-- employer_id работодателя с минимальной медианой: 107
-- значение его медианы: 3.9(3), то есть около 4 часов, то есть в целом отвечает достаточно быстро.
-- при этом 90-перцентиль это 20 часов. Значит в целом данный работодатель практически точно ответит в течение суток.


-- ============================================================
-- БЛОК Г
-- ============================================================


WITH calls_7d AS (
	SELECT 
		r.response_id AS response_id,
		c.call_id AS event_id,
		c.employer_id AS employer_id,
		c.call_at AS event_at,
		c.status AS status,
		c.call_tags AS tags
	FROM responses AS r
	JOIN calls AS c
		ON r.response_id = c.response_id
	WHERE r.created_at <= c.call_at
		AND r.created_at + INTERVAL '7 days' > c.call_at
		AND c.caller_role = 'employer'
),
valid_calls AS (
    SELECT
        event_id,
        status,
        tags
    FROM calls_7d
    WHERE (status = 'successful' AND 'connected' = ANY(tags) AND NOT ('no_answer' = ANY(tags) OR 'technical_error' = ANY(tags)))
        OR (status = 'unsuccessful' AND 'no_answer' = ANY(tags) AND NOT ('connected' = ANY(tags) OR 'technical_error' = ANY(tags)))
        OR (status = 'error' AND 'technical_error' = ANY(tags) AND NOT ('connected' = ANY(tags) OR 'no_answer' = ANY(tags)))
)
SELECT
    COUNT(*) FILTER (WHERE 'screening' = ANY(tags)) AS screening_count,
    COUNT(*) FILTER (WHERE 'interview' = ANY(tags)) AS interview_count,
    COUNT(*) FILTER (WHERE 'follow_up' = ANY(tags)) AS follow_up_count,
    COUNT(*) FILTER (WHERE 'details' = ANY(tags)) AS details_count,
    COUNT(*) FILTER (WHERE 'screening' = ANY(tags) OR 'interview' = ANY(tags) 
    	OR 'follow_up' = ANY(tags) OR 'details' = ANY(tags)) AS business_tag_calls,
    ROUND(AVG(CARDINALITY(tags)), 2) AS avg_tags
FROM valid_calls
--SELECT DISTINCT
--    status,
--    tag
--FROM calls_7d
--CROSS JOIN LATERAL UNNEST(tags) AS tag
--ORDER BY status, tag;

-- По результатам мы получили следующие значения:
-- Количество звонков для тега screening = 25
-- Количество звонков для тега interview = 31
-- Количество звонков для тега follow_up = 29
-- Количество звонков для тега details = 23
-- Всего 108 валидных звонков содержащих хотя бы один из перечисленных бизнес-тегов.
-- Среднее количество тегов на один звонок = 4.
-- Чаще всего звонят с тегом interview, и реже всего соотвественно с тегом details.
-- Доп проверка показала что количество валидных звонков равно количеству исходных звонков в промежутке в 7 дней.
-- Значит технические теги каждого звонка согласуются с его status.


--6.2 Метаданные сообщений

WITH messages_7d AS (
	SELECT 
		r.response_id AS response_id,
		m.message_id AS event_id,
		m.employer_id AS employer_id,
		m.sent_at AS event_at,
		m.message_meta AS meta
	FROM responses AS r
	JOIN messages AS m
		ON r.response_id = m.response_id
	WHERE r.created_at <= m.sent_at
		AND r.created_at + INTERVAL '7 days' > m.sent_at
		AND m.sender_role = 'employer'
),
info_meta_messages AS (
    SELECT
        event_id,
        COALESCE(meta ->> 'channel', 'unknown') AS channel,
        (meta ->> 'is_read')::boolean AS is_read,
        JSONB_ARRAY_LENGTH(meta -> 'attachments') AS attachments_count
    FROM messages_7d
)
SELECT
    channel,
    COUNT(*) AS messages_count,
    COUNT(*) FILTER (WHERE is_read IS NOT NULL) AS check_read_count,
    COUNT(*) FILTER (WHERE is_read = FALSE) AS unread_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_read = FALSE) / NULLIF(COUNT(*) FILTER (WHERE is_read IS NOT NULL), 0), 2) AS unread_dolya,
    COUNT(*) FILTER (WHERE attachments_count > 0) AS not_null_attachment,
    ROUND(100.0 * COUNT(*) FILTER (WHERE attachments_count > 0) /NULLIF(COUNT(*), 0), 2) AS dolya_attachments
FROM info_meta_messages
GROUP BY channel
ORDER BY channel

-- По каналу мобильного приложения: 360 сообщений, во всех присуствует признак прочтения, 36 непрочитанных что составляет 10% от общего числа,
-- 14 сообщений хотя бы с 1 вложением что составляет чуть меньше 4% от общего количества(3.89%)
-- По каналу веб сервиса: 628 сообщений, во всех присуствует признак прочтения, 52 непрочитанных что составляет 8.28% от общего числа,
-- 25 сообщений хотя бы с 1 вложением что составляет чуть меньше 4% от общего количества(3.98%)
-- Мы видим что веб сервисом пользуются почти в 2 раза чаще. При этого сообщения с вложениями имеют примерно одну и ту же долю у
-- обоих каналов отправки.


-- ============================================================
-- БЛОК Д
-- ============================================================

-- Гипотеза 1: Допустим что по откликам со статусом invited работодатель быстрее выходит на первый контакт (неважно какой) 
-- и чаще выходит на связь хотя бы 1 раз в первые 7 дней после отклика.

-- Гипотеза 2: Допустим что по откликам со статусом invited работодатель совершает в сумме больше коммуникаций и 
-- чаще использует оба канала связи одновременно

WITH calls_7d AS (
    SELECT
        r.response_id AS response_id,
        c.call_id AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM responses AS r
    JOIN calls AS c
        ON r.response_id = c.response_id
    WHERE r.created_at <= c.call_at
        AND r.created_at + INTERVAL '7 days' > c.call_at
        AND c.caller_role = 'employer'
),
messages_7d AS (
    SELECT
        r.response_id AS response_id,
        m.message_id AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM responses AS r
    JOIN messages AS m
        ON r.response_id = m.response_id
    WHERE r.created_at <= m.sent_at
        AND r.created_at + INTERVAL '7 days' > m.sent_at
        AND m.sender_role = 'employer'
),
events AS (
    SELECT
        response_id,
        event_id,
        event_at,
        event_type
    FROM calls_7d
    UNION ALL
    SELECT
        response_id,
        event_id,
        event_at,
        event_type
    FROM messages_7d
),
vitrine AS (
    SELECT
        r.response_id,
        r.status,
        COUNT(e.event_id) AS cnt_events,
        COUNT(e.event_id) FILTER (WHERE e.event_type = 'call') AS cnt_calls,
        COUNT(e.event_id) FILTER (WHERE e.event_type = 'message') AS cnt_messages,
        MIN(e.event_at) AS first_event_at,
        EXTRACT(EPOCH FROM (MAX(e.event_at) - MIN(e.event_at))) / 3600.0 AS hours_communication,
        EXTRACT(EPOCH FROM (MIN(e.event_at) - r.created_at)) / 3600.0 AS hours_first_event
    FROM responses AS r
    LEFT JOIN events AS e
        ON r.response_id = e.response_id
    GROUP BY r.response_id, r.status, r.created_at
)
SELECT
    status,
    COUNT(response_id) AS cnt_responses,
    COUNT(response_id) FILTER (WHERE cnt_events > 0) AS cnt_with_events,
    ROUND(100.0 * COUNT(response_id) FILTER (WHERE cnt_events > 0) / NULLIF(COUNT(response_id), 0), 2) AS dolya_with_events,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_first_event)::numeric, 2) AS p50_first_event,
    ROUND(AVG(cnt_events), 2) AS avg_events,
    ROUND(AVG(cnt_events) FILTER (WHERE cnt_events > 0), 2) AS avg_events_only_not_empty,
    ROUND(AVG(hours_communication) FILTER (WHERE cnt_events >= 2), 2) AS avg_hours_communication,
    COUNT(response_id) FILTER (WHERE cnt_calls > 0 AND cnt_messages > 0) AS cnt_both_channels,
    ROUND(100.0 * COUNT(response_id) FILTER (WHERE cnt_calls > 0 AND cnt_messages > 0) / 
    	NULLIF(COUNT(response_id), 0), 2) AS dolya_both_channels
FROM vitrine
WHERE status IN ('invited', 'rejected', 'viewed')
GROUP BY status
ORDER BY status

-- Результаты по гипотезам
-- Гипотеза 1: По откликам со статусом invited коммуникация начинается в 58.70% случаев, по отклонненым откликам в 60.38% случаев
-- По просмотренным - 62.09%. При этом медианное время до первого контакта у invited составляет чуть больше 51 часа, 
-- у отклоненных откликов 54.33 часа, а у просмотренных 57.17 часов.
-- В целом можно сказать что в случае с invited работодатели немного быстрее выходят на связь(примерно на 7-12%)
-- но я бы не стал это учитывать как значимое отличие, т.к. разница не такая большая.
-- При этом в invited доля отликов с коммуникацией в первые 7 дней даже чуть меньше чем в остальных группах.
-- Также я добавил еще показатель с среднем количеством часов общения и у nvited это 32.25 часов, против
-- 36.36 ч и 36.93 у отклоненных и просмотренных откликов соотвественно. То есть с invited "возились"
-- в среднемм на 13% меньше. Вероятно потому что кандидаты имели хорошие навыки и не требовались дополнительные
-- коммуникации чтобы принять окончательное решение.
-- Думаю можно сказать что гипотеза все-таки не подтвердилась, т.к. каких серьезных расхождений я не нашел.
--
-- Гипотеза 2: У откликов с invited среднее количество коммуникаций 1.63, у отклоенненых 1.76 и у просмотренных 1.81.
-- При этом оба канала связи в invited используются в 8.70% откликов, у отклоненных в 10.38%(доля на 20% больше чем у invited) откликов, 
-- у просмотренных в 13.74%.
-- У просмотренных больше в полтора раза аж, думаю это связано опять же с тем что вопрос о навыках и компетенциях с invited
-- закрывался быстрее, а у просмотренных требует больше коммуникаций чтобы понять подходит/не подходит кандидат.
-- Забавно получается, и если, например, не учитывать отклики без коммуникаций в первые 7 дней
-- мы имеем у invited 2.78 среднее количество коммуникаций, у отклоненных и просмотренных: 2.92.
-- Получается что все пошло немного даже против нашей гипотезы. Приглашенные кандидаты имеют в среднем меньше
-- коммуникаций и использование двух каналов связи одновременно тоже встречается реже.
-- В целом можно предположить что ситуация противоположна нашей гипотезе))
-- Видно что другим группа требуется больше коммуникаций и они чаще переходят на оба канала связи.
-- Как я и сказал это вероятно связано с тем что работодатель дольше принимал решение насчет кандидата
-- и ему требовалось соотвественно для этого больше общения, в отличие от invited где у кандидата видимо все в порядке с навыками и скиллами.
-- Поэтому и вторая гипотеза тоже не подтверждается. А точнее скорее даже подтверждается обратная ей гипотеза)

--SELECT DISTINCT status
--FROM responses


-- Итог исследования

-- Итак, что мы получили в результате нашей работы... Мы получили 628 откликов, из них в 382 работодатель выходил на связь
-- в первые 7 дней, а по оставшимся 246 коммуникации не было. Всего получилось 1096 событий: из них 988 сообщений и 108 звонков
-- то есть работодатели гораздо чаще именно пишут чем звонят. Также это подтверждает, что сообщение было
-- первой коммуникацией в 314 откликах, а звонок только в 68
-- Если сравнивать активность работодателей внутри профессиональных направлений, то можем заметить, что работодатель 110 
-- занимает первое место в обоих направлениях связанных с аналитикой: аналитик данных и продуктовый аналитик
-- В остальном активность работодателей различается по направлениям
-- Также мы нашли 749 ответов работодателей на сообщения кандидатов, а у работодателя 107 оказалась минимальная медиана времени ответа, 
-- которая составила чуть меньше 4 часов.
-- В задании Д7 мы выяснили что по приглашенным кандидатам медианное время до первого контакта
-- составляет около 51 часа, против 54.33 у отклоненных и 57.17 у просмотренных откликов соотвествено,
-- то есть с приглашенными действительно связываются немного быстрее.
-- Однако доля откликов с коммуникацией у invited составляет 58.70%, а среднее количество
-- коммуникаций 1.63, что даже меньше чем у rejected и viewed, поэтому обе наши гипотезы
-- в целом не подтвердились. А проверка второй гипотезы вообще привела к противоположным выводам.
-- А именно что по откликам со статусом invited работодатель совершает в сумме МЕНЬШЕ коммуникаций и 
-- РЕЖЕ использует оба канала связи одновременно.
-- Можно предположить что работодателям требуется меньше общения с подходящими кандидатами,
-- но утверждать что именно количество или скорость коммуникаций влияет на приглашение
-- мы также не можем, тк на решение могут влиять скиллы, опыт и другие качества кандидата
-- Также стоит учитывать что мы анализировали только первые 7 дней после отклика,
-- поэтому более поздние коммуникации в исследование не попали.
-- В целом было бы конечно интересно посмотреть и проверить как опыт кандидата и требования конкретной
-- вакансии связаны с количеством коммуникации и вероятностью приглашения,
-- чтобы понять действительно ли подходящим кандидатам требуется меньше общения.
-- Мне кажется это достаточно содержательная часть и на основе нее можно делать уже более точные и объективные выводы.



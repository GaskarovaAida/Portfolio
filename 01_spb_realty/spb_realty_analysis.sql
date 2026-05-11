--Задача 1. Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
    ),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--Разбиваем объявления на категории:
groop_of AS (
	SELECT  
	(CASE WHEN city='Санкт-Петербург' THEN 'Санкт-Петербург'
	     ELSE 'ЛенОбл'
	     END) AS Регион,
	 (CASE WHEN days_exposition IS NULL THEN 'активное'
		 WHEN days_exposition BETWEEN 1 and 30 THEN 'до месяца'
	     WHEN days_exposition BETWEEN 31 and 90 THEN 'до трех месяцев'
	     WHEN days_exposition BETWEEN 91 and 180 THEN 'до полугода'
	     ELSE 'более полугода'
	     END) AS Сегмент_Активности,
	     a.last_price*1.0/f.total_area AS metr_cost, -- считаем стоимость 1 м2 (в рублях)
         f.living_area AS living_area, -- жилая площадь, в кв. метрах
         f.rooms AS rooms, -- число комнат,
         f.ceiling_height AS ceiling_height, -- высота потолка, в метрах
         f.balcony AS balcony, -- количество балконов в квартире
         f.kitchen_area AS kitchen_area, -- площадь кухни, в кв. метрах
         f.floors_total AS floors_total, -- этажность дома, в котором находится квартира
         f.parks_around3000 AS parks_around3000, -- число парков в радиусе трёх километров
         f.ponds_around3000 AS ponds_around3000, -- число водоёмов в радиусе трёх километров
         t.type AS type,
         f.id AS id
	FROM real_estate.flats AS f
	JOIN real_estate.advertisement AS a ON f.id=a.id
	JOIN real_estate.type AS t ON f.type_id=t.type_id
	JOIN real_estate.city AS c ON f.city_id=c.city_id
	JOIN filtered_id AS fl_id ON a.id=fl_id.id
	WHERE a.id IN (SELECT * FROM filtered_id) AND type='город'
	),
groop_of_2 AS(
	SELECT *,
	COUNT(id) OVER (PARTITION BY Регион, Сегмент_Активности) AS Кол_во_объявлений,
    COUNT(id) OVER (PARTITION BY Регион) AS Кол_во_объявлений_по_регионам
    FROM groop_of)
--Итоговая таблица
SELECT Регион, Сегмент_Активности,
Кол_во_объявлений,
100*Кол_во_объявлений/Кол_во_объявлений_по_регионам AS Доля_объявлений,--Доля объявлений от суммы по регионам
ROUND(AVG(metr_cost::numeric), 2) AS средняя_стоимость_м2,
ROUND(AVG(living_area::numeric), 2) AS средняя_жил_площ,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms) AS медиана_кол_ва_комнат,
ROUND(AVG(ceiling_height::numeric), 2) AS средняя_высота_потолка,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS медиана_кол_ва_балконов,
ROUND(AVG(kitchen_area::numeric), 2) AS средняя_площ_кухни,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floors_total) AS медиана_этажности,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY parks_around3000) AS медианное_число_парков_рад300_м,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ponds_around3000) AS медианное_число_водоемов_рад3_км
FROM groop_of_2
GROUP BY  Регион, Сегмент_Активности, Кол_во_объявлений, Кол_во_объявлений_по_регионам
ORDER BY Регион DESC, Сегмент_Активности

--Задача 2. Время активности объявлений
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
    ),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
 total_1 AS (
 	SELECT 	f.id AS id_1,
			EXTRACT(MONTH FROM a.first_day_exposition) AS month_adv, -- выделяем номер месяца 
			a.last_price*1.0/f.total_area AS metr_cost_adv, -- считаем стоимость 1 м2 (в рублях)
			f.total_area AS total_area_adv -- общая площадь квартиры, в м2
			FROM real_estate.flats AS f 
			JOIN real_estate.advertisement AS a ON f.id = a.id
			JOIN real_estate.type AS t ON f.type_id = t.type_id
			JOIN real_estate.city AS c ON f.city_id = c.city_id
			WHERE f.id IN (SELECT * FROM filtered_id)
			AND t.type = 'город' 
			AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018), -- данные за период с 2015 по 2018
total_2 AS(
	SELECT (CASE WHEN month_adv = 1 THEN 'Январь'
	           	WHEN month_adv = 2 THEN 'Февраль'
			 	WHEN month_adv = 3 THEN 'Март'
				WHEN month_adv = 4 THEN 'Апрель'
				WHEN month_adv = 5 THEN 'Май'
				WHEN month_adv = 6 THEN 'Июнь'
				WHEN month_adv = 7 THEN 'Июль'
				WHEN month_adv = 8 THEN 'Август'
				WHEN month_adv = 9 THEN 'Сентябрь'
				WHEN month_adv = 10 THEN 'Октябрь'
	           	WHEN month_adv = 11 THEN 'Ноябрь'
	           	WHEN month_adv = 12 THEN 'Декабрь'
       			END) AS month_adv_name,
       			COUNT(id_1) AS count_adv_by_month,
       			ROUND(AVG(metr_cost_adv::numeric), 2) AS avg_metr_cost_adv, -- средняя стоимость 1 м2 в опубликованных объявлениях
       			ROUND(AVG(total_area_adv::numeric), 2) AS avg_total_area_adv, -- средняя площадь квартир в опубликованных объявлениях
				month_adv
       			FROM total_1
			    GROUP BY month_adv),
total_sell_1 AS (	
	SELECT 	f.id AS id_2,
	        EXTRACT(MONTH FROM (a.first_day_exposition + days_exposition::integer)) AS month_sell, -- выделяем номер месяца
			a.last_price*1.0/f.total_area AS metr_cost_sell, -- считаем стоимость 1 м2 (в рублях)
			f.total_area AS total_area_sell -- общая площадь квартиры, в м2
			FROM real_estate.flats AS f 
			JOIN real_estate.advertisement AS a ON f.id = a.id
			JOIN real_estate.type AS t ON f.type_id = t.type_id
			JOIN real_estate.city AS c ON f.city_id = c.city_id
			WHERE f.id IN (SELECT * FROM filtered_id)
			AND t.type = 'город'
			AND days_exposition IS NOT NULL 
			AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018), -- период с 2015 по 2018
total_sell_2 AS (
 	SELECT 	(CASE WHEN month_sell = 1 THEN 'Январь'
	           	 WHEN month_sell = 2 THEN 'Февраль'
			     WHEN month_sell = 3 THEN 'Март'
				 WHEN month_sell = 4 THEN 'Апрель'
				 WHEN month_sell = 5 THEN 'Май'
			     WHEN month_sell = 6 THEN 'Июнь'
				 WHEN month_sell = 7 THEN 'Июль'
				 WHEN month_sell = 8 THEN 'Август'
			     WHEN month_sell = 9 THEN 'Сентябрь'
			     WHEN month_sell = 10 THEN 'Октябрь'
	           	 WHEN month_sell = 11 THEN 'Ноябрь'
	           	 WHEN month_sell = 12 THEN 'Декабрь'
       			 END) AS month_name_sell,
       			 COUNT(id_2) AS count_sell_by_month,
       			 ROUND(AVG(metr_cost_sell::numeric), 2) AS avg_metr_cost_sell, -- средняя стоимость 1 м2 в проданных объявлениях
       			 ROUND(AVG(total_area_sell::numeric), 2) AS avg_total_area_sell, -- средняя площадь квартир в проданных объявлениях
				 month_sell
     FROM total_sell_1
	 GROUP BY month_sell)	
SELECT 	t2.month_adv_name,
		count_adv_by_month,
		count_sell_by_month,
		count_sell_by_month - count_adv_by_month AS delta_sell,-- продажа минус новые объявления 
		t2.avg_metr_cost_adv,-- средняя стоимость 1 м2 в опубликованных объявлениях
		s2.avg_metr_cost_sell, -- средняя стоимость 1 м2 в проданных объявлениях
		t2.avg_total_area_adv, -- средняя площадь квартир в опубликованных объявлениях
		s2.avg_total_area_sell, -- средняя площадь квартир в проданных объявлениях
		t2.month_adv
FROM total_2 AS t2
JOIN total_sell_2 AS s2 ON t2.month_adv = s2.month_sell
ORDER BY t2.month_adv; 

--Задача 3.Анализ рынка недвижимости Ленобласти
WITH limits AS ( 
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 	total_area < (SELECT total_area_limit FROM limits)
        	AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        	AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        	AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)),
release AS (SELECT 	c.city AS city_L,
					a.id AS id_rl 
			FROM real_estate.flats AS f 
			JOIN real_estate.advertisement AS a ON f.id = a.id
			JOIN real_estate.type AS t ON f.type_id = t.type_id
			JOIN real_estate.city AS c ON f.city_id = c.city_id
			JOIN filtered_id AS f_id ON f_id.id = a.id
			WHERE c.city <> 'Санкт-Петербург' AND a.id IN (SELECT * FROM filtered_id)), -- выбираем города ЛО и отбираем id, соотв. условиям
release_1 AS (
			SELECT city_L,
					 COUNT(id_rl) AS count_id_rl_L -- количество объявлений по городам ЛО
			  FROM release
			  GROUP BY city_L), -- группировка по городам ЛО
sell AS 
			(SELECT c.city AS city_L, 
					a.id  AS id_sell,
					a.days_exposition AS sell_days_exposition, -- кол-во дней, в течении которых квартира продалась
					f.total_area AS total_area, -- площадь квартиры
					a.last_price*1.0/f.total_area AS metr_cost -- стоимость 1 м2
			FROM real_estate.flats AS f 
			JOIN real_estate.advertisement AS a ON f.id = a.id
			JOIN real_estate.type AS t ON f.type_id = t.type_id
			JOIN real_estate.city AS c ON f.city_id = c.city_id
			JOIN filtered_id AS f_id ON f_id.id = a.id
			WHERE c.city <> 'Санкт-Петербург' AND (a.id IN (SELECT * FROM filtered_id)) AND a.days_exposition IS NOT NULL),	-- выбираем города ЛО и отбираем id, соотв. условиям, а также выбираем только те записи, где квартира уже продалась	
sell_1 AS (SELECT city_L,
					  COUNT(id_sell) AS count_id_sell_L, 
					  AVG(total_area)::numeric AS avg_total_area, -- средняя площадь проданных квартир
					  AVG(sell_days_exposition)::numeric AS avg_sell_days_exposition, -- среднее кол-во дней, в течение которых квартира продавалась
					  AVG(metr_cost)::NUMERIC AS avg_metr_cost -- средняя стоимость 1 м2
			   FROM sell
			   GROUP BY city_L) 
SELECT 	rl_1.city_L, -- наименования городов ЛО
		count_id_rl_L, -- количество объявлений по городам ЛО
		count_id_sell_L, -- количество продаж по городам
		ROUND(count_id_sell_L*100.0/count_id_rl_L, 2) AS dl_of_sell, -- доля снятых с публикаций объявлений (от количества опубликованных)
		ROUND(avg_total_area, 2) AS avg_total_area, -- средняя площадь квартир
		ROUND(avg_metr_cost, 2) AS avg_metr_cost, -- средняя стоимость 1 м2
		ROUND(avg_sell_days_exposition, 2) AS avg_sell_days_exposition -- среднее кол-во дней, в течение которых квартира продавалась
FROM release_1 AS rl_1 JOIN sell_1 AS sl_1 ON rl_1.city_L = sl_1.city_L -- собираем данные и группируем показатели по городам ЛО
WHERE count_id_rl_L >=50 -- отсекаем выбросы по малому количеству объявлений в населенном пункте
ORDER BY avg_sell_days_exposition   --  результат запроса отсортирован по среднему кол-ву дней, в течение которых квартира продавалась
LIMIT 15;


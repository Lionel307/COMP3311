-- COMP3311 21T3 Assignment 1
--
-- Fill in the gaps ("...") below with your code
-- You can add any auxiliary views/function that you like
-- The code in this file MUST load into a database in one pass
-- It will be tested as follows:
-- createdb test; psql test -f ass1.dump; psql test -f ass1.sql
-- Make sure it can load without errorunder these conditions


-- Q1: oldest brewery

create or replace view Q1(brewery)
as
SELECT name FROM Breweries WHERE founded = (SELECT min(founded) FROM Breweries)
;

-- Q2: collaboration beers

create or replace view Q2(beer)
as
SELECT b2.name
FROM Brewed_by b1 
		JOIN Beers b2 ON (b1.beer = b2.id)
		JOIN Brewed_by b3 ON (b1.beer = b3.beer)
WHERE b1.brewery < b3.brewery
;

-- Q3: worst beer

create or replace view Q3(worst)
as
SELECT name FROM Beers WHERE rating = (SELECT min(rating) FROM Beers) 
;

-- Q4: too strong beer

create or replace view Q4(beer,abv,style,max_abv)
as
SELECT b.name, b.abv, s.name, s.max_abv
FROM Styles s JOIN Beers b ON (b.style = s.id and b.abv > s.max_abv)
;

-- Q5: most common style

create or replace view most_common_style
as
SELECT s.name as style_name, count(s.name) as nstyle
FROM Styles s JOIN Beers b ON (b.style = s.id)
GROUP BY s.name
;

create or replace view Q5(style)
as
SELECT style_name
FROM most_common_style
WHERE nstyle = (SELECT max(nstyle) FROM most_common_style)
;

-- Q6: duplicated style names


create or replace view Q6(style1,style2)
as
SELECT s1.name, s2.name
FROM Styles s1 
		JOIN Styles s2 ON (lower(s1.name) = lower(s2.name) AND s1.id != s2.id)
WHERE s1.name < s2.name
;

-- Q7: breweries that make no beers

create or replace view Beer_count 
as
select r.name as brewery, count(b1.beer) as nbeers
from  Brewed_by b1
		LEFT join Beers b on (b1.beer = b.id)
		RIGHT join Breweries r on (b1.brewery = r.id)
group by r.name
;

create or replace view Q7(brewery)
as
SELECT brewery
FROM Beer_count
WHERE nbeers = 0
ORDER BY brewery
;

-- Q8: city with the most breweries

create or replace view most_common_city
as
SELECT count(l.metro) as ncity, l.metro as city, l.country as country 
FROM Locations l JOIN Breweries b ON (l.id = b.located_in)
GROUP BY l.country, l.metro
;

create or replace view Q8(city, country)
as
SELECT city, country
FROM most_common_city
WHERE ncity = (SELECT max(ncity) FROM most_common_city)
;

-- Q9: breweries that make more than 5 styles
-- get what beers are brewed at each brewery and then the number of different styles
create or replace view num_styles
as
SELECT b1.name as beer, s.name as style, b1.id as beer_id
FROM Styles s
		JOIN Beers b1 ON (s.id = b1.style)
;

create or replace view styles_at_brewery
as
SELECT br.name as brewery, count(DISTINCT n.style) as num
FROM num_styles n
		JOIN Brewed_by b ON (n.beer_id = b.beer)
		JOIN Breweries br ON (br.id = b.brewery)
GROUP BY br.name
;

create or replace view Q9(brewery,nstyles)
as
SELECT brewery, num
FROM styles_at_brewery
WHERE num > 5
;

-- Q10: beers of a certain style

create type BeerInfo as (beer text, brewery text, style text, year YearValue, abv ABVvalue);

create or replace function
	q10(_style text) returns setof BeerInfo 
as $$

declare
	b BeerInfo;
begin
	for b in
		SELECT be.name, string_agg(br.name, ' + ' ORDER BY br.name), s.name, be.brewed, be.abv
		FROM Styles s
				JOIN Beers be ON (s.id = be.style)
				JOIN Brewed_by b1 ON (be.id = b1.beer)
				JOIN Breweries br ON (br.id = b1.brewery)
		WHERE s.name LIKE _style
		GROUP BY be.name, s.name, be.brewed, be.abv
		ORDER BY be.name asc
	loop
		return next b;
	end loop;
end;
$$
language plpgsql;

-- Q11: beers with names matching a pattern

create or replace function
	Q11(partial_name text) returns setof text
as $$
declare
	beer text;
	brewery text;
	style text;
	abv ABVvalue;
	rec record;

begin
	for rec in
		SELECT distinct b.id, b.name as beer, string_agg(br.name, ' + ' ORDER BY br.name) as brewery, s.name as style, b.abv as abv
		FROM Beers b
				JOIN Styles s ON (s.id = b.style)
				JOIN Brewed_by b1 ON (b.id = b1.beer)
				JOIN Breweries br ON (br.id = b1.brewery)
		WHERE lower(b.name) LIKE ('%'||lower(partial_name)||'%')
		GROUP BY b.name, s.name, b.abv, b.id
		ORDER BY b.name asc
	loop
		beer := rec.beer;
		brewery := rec.brewery;
		style := rec.style;
		abv := rec.abv;
		return next '"'||beer||'"'||', '||brewery||', '||style||', '||abv|| '% ABV';
	end loop;
end;
$$
language plpgsql;

-- Q12: breweries and the beers they make


-- Count number of beers found the in the given brewery
create or replace function
	count_beers(partial_brewery text) returns setof integer
as $$
declare
	n integer := 0;
begin
	SELECT count(b.name) INTO n
	FROM Beers b 
		JOIN Brewed_by b1 ON (b.id = b1.beer)
		JOIN Breweries br ON (br.id = b1.brewery)
	WHERE lower(br.name) LIKE ('%'||lower(partial_brewery)||'%')
	;
	return next n;
end;
$$ language plpgsql;

create or replace function
	Q12(partial_name text) returns setof text
as $$
declare
	brewery text;
	founded YearValue;
	country text;
	region text;	
	metro text;
	town text;
	beer text;
	style text;
	brewed YearValue;
	abv ABVvalue;
	rec record;
	rec2 record;
	beer_found integer;
begin
	for rec in
		SELECT l.country as country, l.region as region, l.metro as metro, l.town as town, br.founded as founded, br.name as brewery
		FROM Breweries br
				JOIN Locations l ON (br.located_in = l.id)
		WHERE lower(br.name) LIKE ('%'||lower(partial_name)||'%')
		GROUP BY l.country, l.region, l.metro, l.town, br.founded, br.name
		ORDER BY br.name asc
	loop
		country := rec.country;
		region := rec.region;
		metro := rec.metro;
		town := rec.town;
		brewery := rec.brewery;
		founded := rec.founded;
		return next brewery||', founded '||founded;

		if metro is not NULL and town is not NULL and region is not NULL
		then
			return next 'located in '||town||', '||region||', '||country;
		elsif metro is not NULL and town is NULL and region is not NULL
		then
			return next 'located in '||metro||', '||region||', '||country;
		elsif metro is NULL and town is not NULL and region is not NULL
		then
			return next 'located in '||town||', '||region||', '||country;
		elsif metro is NULL and town is NULL and region is not NULL
		then
			return next 'located in '||region||', '||country;
		elsif metro is not NULL and town is NULL and region is NULL
		then
			return next 'located in '||metro||', '||country;
		elsif metro is NULL and town is not NULL and region is NULL
		then
			return next 'located in '||town||', '||country;
		else
			return next 'located in '||country;
		end if;

		for rec2 in
			SELECT distinct b.id, b.name as beer, br.name as brewery, s.name as style, b.abv as abv, b.brewed as brewed
			FROM Beers b
					JOIN Styles s ON (s.id = b.style)
					JOIN Brewed_by b1 ON (b.id = b1.beer)
					JOIN Breweries br ON (br.id = b1.brewery)
			WHERE lower(br.name) LIKE lower(rec.brewery)
			GROUP BY b.name, s.name, b.abv, br.name, b.brewed, b.id 
			ORDER BY b.brewed asc, b.name, s.name, b.abv
		loop
			beer := rec2.beer;
			brewed := rec2.brewed;
			style := rec2.style;
			abv := rec2.abv;
			return next '  "'||beer||'"'||', '||style||', '||brewed||', '||abv|| '% ABV';
		end loop;
		beer_found := count_beers(partial_name);
		if beer_found = 0
		then
			return next '  No known beers';
		end if;
	end loop;
end;
$$
language plpgsql;

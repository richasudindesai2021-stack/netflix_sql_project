-- 15 Business Probelms

--1.Count the number of movies vs tv shows
select type,count(*) as total_content
from netflix
group by type;



--2.Find the most common rating for movies and TV Shows
select type,rating from(
select type,rating,count(*) as frequency, 
rank() over(partition by type order by count(*) desc) as ranking
from netflix
group by type,rating
) as t1
where ranking=1 ;


--3.List all movies released in a specific year (e.g., 2020)
select *
from netflix
where type = 'Movie' and release_year = 2020;



--4.Find the top 5 countries with the most content on Netflix
select unnest(string_to_array(country,','))new_country, count(show_id) as total_content
from netflix
group by 1
order by total_content desc
limit 5;


--5.Identify the longest movie?
select * 
from netflix
where (type = 'Movie') 
and (duration = (select max(duration) from netflix))



--6.Find content added in the last 5 years
select *
from netflix
where TO_DATE(date_added,'DD-Mon-YY') >= CURRENT_DATE - interval '5 years'


--7.Find all the movies/TV shows by director 'Rajiv Chilaka':

select *
from netflix
where director ilike '%Rajiv Chilaka%'


--8.List all TV shows with more than 5 seasons
--SPLIT_PART(duration,1) where 1 is the first part before the split
select *
from netflix
where type = 'TV Show' and SPLIT_PART(duration,' ',1)::numeric > 5 


--9.count the number of content items in each genre
--converting the string in listed_in to array so that we can unnest it and split it
select 
unnest(string_to_array(listed_in,','))genre,
count(show_id)total_content
from netflix
group by 1


--10.Find each year and the average numbers of content release in India on netflix.
SELECT 
    EXTRACT(YEAR FROM TO_DATE(date_added, 'DD-Mon-YY')) AS year,count(*)yearly_content
   ,round(count(*)::numeric/(select count(*) from netflix where country = 'India')::numeric * 100,2) as avg_content_per_year 
FROM netflix
WHERE country = 'India'
  AND date_added ~ '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{2}$'
GROUP BY year
ORDER BY year;


--11.list all the movies that are documentaries
select * 
from netflix
where type = 'Movie' and listed_in ilike '%Documentaries%'


--12.Find all content without a director
SELECT *
FROM netflix
WHERE director IS NULL
   OR director = ''
   OR TRIM(director) = '';


--13.Find how many movies actor 'Salman Khan' appeared in last 10 years!
select *
from netflix
where casts ilike '%Salman Khan%'
and release_year > extract(year from CURRENT_DATE) - 10

--14.Find the top 10 actors who have appeared in the highest number of movies produces in India
select unnest(string_to_array(casts,','))actors,count(*) as total_content
from netflix
where country ilike '%India%'
group by 1
order by 2 desc
limit 10


--15.Categorize the content based on the presence of the keywords 'Kill' and 'violence'
--in the description field.Labbel content containing these keywords as 'Bad' and all other content as 'Good'
--.Count how many fall into each category
with new_table as (
select *,
	case
		when description ilike '%kill%' or description ilike '%violence%' 
		then 'Bad'
		else 'Good'
	end category
from netflix  
	)
	select category,count(*) as total_content
	from new_table 
	group by 1
 
 --16.Yearly Trend of Genre Popularity Using a Genre Lookup Table
	-- Create a derived genre table and join it back
with genre_table as (
    select 
        show_id,
        trim(unnest(string_to_array(listed_in, ','))) as genre
    from netflix
),

content_by_year as (
    select
        n.show_id,
        extract(year from to_date(n.date_added, 'dd-mon-yy')) as year,
        g.genre
    from netflix n
    join genre_table g 
        on n.show_id = g.show_id
    where n.date_added ~ '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{2}$'
)

select 
    year,
    genre,
    count(*) as total_releases
from content_by_year
group by year, genre
order by year, total_releases desc;



--17.find the top 5 actor pairs on netflix by identifying which actors frequently appear together in the same titles, using a self join on the cast list to count the number 
--of collaborations between each pair. visualize the strongest actor partnerships
with cast_table as (
    select 
        show_id,
        trim(unnest(string_to_array(casts, ','))) as actor
    from netflix
    where casts is not null
      and trim(casts) <> ''
),

pairings as (
    select 
        c1.actor as actor1,
        c2.actor as actor2
    from cast_table c1
    join cast_table c2
        on c1.show_id = c2.show_id
       and c1.actor < c2.actor     -- prevents duplicates (a,b) and (b,a)
)

select 
    actor1,
    actor2,
    count(*) as collaborations
from pairings
group by actor1, actor2
having count(*) > 1    -- you can change to > 0 if dataset is small
order by collaborations desc
limit 5;


--18.analyze genre coverage across countries by generating a complete country × genre matrix and using left join, 
--right join, and inner join to identify which countries have the widest and narrowest genre diversity. 
--compute completeness percentages using window functions, and visualize the genre coverage of the top 10 producing countries
-- get all distinct genres
-- 1. get all distinct genres
with all_genres as (
    select distinct trim(unnest(string_to_array(listed_in, ','))) as genre
    from netflix
    where listed_in is not null
),

-- 2. get all distinct countries
all_countries as (
    select distinct trim(unnest(string_to_array(country, ','))) as country
    from netflix
    where country is not null
),

-- 3. full country × genre matrix
country_genre_matrix as (
    select 
        c.country,
        g.genre
    from all_countries c
    cross join all_genres g
),

-- 4. explode netflix rows
netflix_country_genre as (
    select
        trim(unnest(string_to_array(n.country, ','))) as country,
        trim(unnest(string_to_array(n.listed_in, ','))) as genre,
        n.show_id
    from netflix n
    where country is not null
      and listed_in is not null
),

-- 5. left join to identify coverage
coverage as (
    select 
        m.country,
        m.genre,
        count(n.show_id) as total_titles,
        case when count(n.show_id) > 0 then 1 else 0 end as genre_present
    from country_genre_matrix m
    left join netflix_country_genre n
        on m.country = n.country
       and m.genre = n.genre
    group by m.country, m.genre
),

-- 6. compute country-level genre counts (needed for ranking)
country_stats as (
    select
        country,
        sum(genre_present) as genres_covered,
        count(*) as total_genres,
        round(sum(genre_present)::numeric / count(*) * 100, 2) as coverage_pct
    from coverage
    group by country
),

-- 7. final join to attach stats to each row
final as (
    select
        c.country,
        c.genre,
        c.total_titles,
        c.genre_present,
        s.coverage_pct,
        dense_rank() over (order by s.genres_covered desc) as diversity_rank
    from coverage c
    join country_stats s
        on c.country = s.country
)

select *
from final
order by diversity_rank, country, genre;





--*****View Dependency script: extract tables from schema views*****
--note: comments are not stored in information_schema.views
with a as (
select
	table_catalog
	,table_schema
	,table_name
	,lower(view_definition) view
FROM table
WHERE table_schema = 'edit'
),
  
--remove line breaks and some unnecceassary characters
clean as (
select 
	table_catalog
	,table_schema
	,table_name
	,regexp_replace(replace(replace(replace(replace(view,'(', ''),')',''),'*'),','), '\n', ' ') view	
from a 
),

--remove white space >1
clean2 as (
select 
	table_catalog
	,table_schema
	,table_name
	,regexp_replace(view, '/^\s+|\s+(?=\s)', '') view2
from clean
),

--create array with the string following 'from' or 'join'  
tbl_array as (
select 
	table_catalog
	,table_schema
	,table_name
	,array_distinct(regexp_extract_all(view2, '(?<=\bfrom | join\s)(\S+)' )) tables	
from clean2
),

--filter out aliased cte, cannot contain '.' which tables always have
fltr_array as (
select 
	table_catalog
	,table_schema
	,table_name
	,filter(tables, x -> x like '%.%') tables 
from tbl_array
),

unnested_array as
(
select table_catalog, table_schema, table_name, replace(tbl, 'hive.') tbl_FullName
from
(
	select 	table_catalog, table_schema, table_name, tables
	from fltr_array
) as X (table_catalog, table_schema, table_name, tables)
cross join unnest(tables) as t(tbl)
)

select 
	distinct
	table_catalog
	,table_schema
	,table_name
	,tbl_FullName
	,regexp_extract(tbl_FullName, '^([^.]*)') dependency_schema
	,regexp_replace(tbl_FullName, '^([^.]*).') dependency_table_name
from unnested_array

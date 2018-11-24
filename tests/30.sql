--Test 30
--If an individual has two records that are 30 days apart and not combinable, and max_gap_to_fill is set to 30, 
--the first record is extended to the day before the end of the previous record.




--2) Run the procedure
call fnc.drop_if_exists ('sailx0286v.test30')
call sail0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx286v.test30',
	log_table=>'sailx286v.log', 	--Use this log for all.
	gp_data_extract=>'SAILWLGPV.GP_EVENT_CLEANSED_20170314',
	max_gap_to_fill=>30, 
	threshold=>.1,
	--medication_only=>0,
	group_on_sail_data=>0,
	group_on_practice=>1,
	keep_non_sail_recs=>1
)!

--3) Test the results and insert the test outcome into the test table.
--   You can add extra queries here if you need some preparatory steps.

declare global temporary table session.gptest30table
(aPERS_ID_E integer, 
aFROM_DT date,
aTO_DT date,
bPERS_ID_E integer, 
bFROM_DT date,
bTO_DT date, 
alf_e bigint)with replace on commit preserve rows! 

Insert Into session.gptest30table
select a.PERS_ID_E, 
a.FROM_DT,
a.TO_DT,
b.PERS_ID_E, 
b.FROM_DT,
b.TO_DT, 
p.alf_e
from 
	(select row_number() over () as rrn, pers_id_e, from_dt, to_dt, prac_cd_e 
	from sailhnarv.ar_pers_gp a order by pers_id_e, from_dt, to_dt) as a 
join
	(select row_number() over () as rrn, pers_id_e, from_dt, to_dt, prac_cd_e 
	from sailhnarv.ar_pers_gp a order by pers_id_e, from_dt, to_dt) as b 
on a.pers_id_e = b.pers_id_e
join
sailhnarv.ar_pers p
on a.pers_id_e = p.pers_id_e and a.rrn = b.rrn+1
where a.from_dt = b.to_dt + 30 days
and a.prac_cd_e<>b.prac_cd_e
order by p.alf_e, a.from_dt!

insert into sailx286v.test_results
	with test_query as (
		--Test query here.
		select count(*) as num_not_exteneded from session.gptest30table a
		join
		sailx286v.test30 b
		on a.alf_e = b.alf_e
		and a.bfrom_dt = start_date
		where afrom_dt<>end_date + 1 day
	)
	select 
		--Enter the number of the test according to the spreadsheet here.
		30 as test_num,
		'If an individual has two records that are 30 days apart and not combinable, and max_gap_to_fill is set to 30, the first record is extended to the day before the end of the previous record.' as description,
		--test condition that proves whether the test passed here
		case when num_not_exteneded = 0 	
			then 'pass' else 'fail'
		end as result,
		--Always include these
		SAILX286V.TEST_VERSION,
		current user,
		current timestamp
		from test_query!

--Clean up: drop the table the procedure created, as well as any other tables
--you created for the test.
drop table sailx286v.test30!


--Test 7
--When max_gap_to_fill is set to 100, a gap of 101 days between registrations is not closed.

--2) Run the procedure

call sail0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx286v.test10',
	log_table=>'sailx286v.log', 	--Use this log for all.
	gp_data_extract=>'SAILWLGPV.GP_EVENT_CLEANSED_20170314',
	max_gap_to_fill=>100, 
	threshold=>.1,
	--medication_only=>0,
	group_on_sail_data=>0,
	group_on_practice=>0,
	keep_non_sail_recs=>0
)!

--3) Test the results and insert the test outcome into the test table.
--   You can add extra queries here if you need some preparatory steps.

--create a temp table to hold identified registrations with gap of one day
declare global temporary table session.gptest10table
(aPERS_ID_E integer, 
aFROM_DT date,
aTO_DT date,
bPERS_ID_E integer, 
bFROM_DT date,
bTO_DT date, 
alf_e bigint)with replace on commit preserve rows! 

Insert Into session.gptest10table
select a.PERS_ID_E, 
a.FROM_DT,
a.TO_DT,
b.PERS_ID_E, 
b.FROM_DT,
b.TO_DT, 
p.alf_e
from 
	(select row_number() over () as rrn, pers_id_e, from_dt, to_dt 
	from sailhnarv.ar_pers_gp a order by pers_id_e, from_dt, to_dt) as a 
join
	(select row_number() over () as rrn, pers_id_e, from_dt, to_dt 
	from sailhnarv.ar_pers_gp a order by pers_id_e, from_dt, to_dt) as b 
on a.pers_id_e = b.pers_id_e
join
sailhnarv.ar_pers p
on a.pers_id_e = p.pers_id_e and a.rrn = b.rrn+1
where a.from_dt = b.to_dt + 101 days
order by p.alf_e, a.from_dt!


insert into sailx286v.test_results
	with test_query as (
		--Test query here.
		select count(*) as num_gap_101_days from session.gptest10table t
			join sailx286v.test10 t10
			on t.alf_e = t10.alf_e and t.afrom_dt = t10.start_date
	)
	select 
		--Enter the number of the test according to the spreadsheet here.
		10 as test_num,
		'When max_gap_to_fill is set to 100, a gap of 101 days between registrations is not closed.' as description,
		--test condition that proves whether the test passed here
		case when num_gap_101_days > 0 	
			then 'pass' else 'fail'
		end as result,
		--Always include these
		SAILX286V.TEST_VERSION,
		current user,
		current timestamp
		from test_query!

--Clean up: drop the table the procedure created, as well as any other tables
--you created for the test.
drop table sailx286v.test10!


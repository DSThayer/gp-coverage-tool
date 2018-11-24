--Test 7

--When max_gap_to_fill is set to 1, a gap of two days between registrations is not closed.
--2) Run the procedure

call sail0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx286v.test7',
	log_table=>'sailx286v.log', 	--Use this log for all.
	gp_data_extract=>'SAILWLGPV.GP_EVENT_CLEANSED_20170314',
	max_gap_to_fill=>1, 
	threshold=>.1,
	--medication_only=>0,
	group_on_sail_data=>0,
	group_on_practice=>0,
	keep_non_sail_recs=>0
)!

--3) Test the results and insert the test outcome into the test table.
--   You can add extra queries here if you need some preparatory steps.

insert into sailx286v.test_results
	with test_query as (
		--Test query here.
		select count(*) as num_gap_2_days from 
		(select count(*), alf_e from sailx286v.test7
			where alf_e in (
				select p.alf_e 
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
				where a.from_dt = b.to_dt + 2 days
				and p.dod>a.from_dt
				and p.pers_id_e not in (
						select e.pers_id_e 
						from sailhnarv.ar_pers_gp e 
						join sailhnarv.ar_pers_gp d 
						on e.pers_id_e = d.pers_id_e and e.to_dt = d.from_dt)
				order by a.from_dt
			)
			group by alf_e
			having count(*)=1
		)
	)
	select 
		--Enter the number of the test according to the spreadsheet here.
		7 as test_num,
		'When max_gap_to_fill is set to 1, a gap of two days between registrations is not closed.' as description,
		--test condition that proves whether the test passed here
		case when num_gap_2_days = 0 	
			then 'pass' else 'fail'
		end as result,
		--Always include these
		SAILX286V.TEST_VERSION,
		current user,
		current timestamp
		from test_query!

--Clean up: drop the table the procedure created, as well as any other tables
--you created for the test.
drop table sailx286v.test7!



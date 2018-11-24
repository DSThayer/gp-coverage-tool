--Test 4
--2) Run the procedure
call fnc.drop_if_exists ('sailx0286v.test4')!


call sailx0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx0286v.test4',
	log_table=>'sailx0286v.log', 	--Use this log for all.
	max_gap_to_fill=>1, 
	threshold=>.0001,
	--medication_only=>0,
	group_on_sail_data=>1,
	group_on_practice=>0,
	keep_non_sail_recs=>1,
	birth_correction =>0
)!

--3) Test the results and insert the test outcome into the test table.
--   You can add extra queries here if you need some preparatory steps.

insert into sailx286v.test_results
	with test_query as (
		--Test query here.
		
	   select count(*) as unmatched_records
			   from (	
		        --gets alf with min and max start and end date
		        select alf_e,
					   min(start_date) as start_date, 
					   max(end_date) as end_date 
				from sailx0286v.test4
				group by alf_e,start_date,end_date
			  ) as test1
			LEFT join 
			(	select alf_e, 
						min(calc_from_dt) as from_dt, 
						max(calc_to_dt) as to_dt
				from (	select alf_e, 
								dod,
								wob,
								from_dt,
								to_dt,
								case 
									when from_dt<wob then wob
									else from_dt 
								end as calc_from_dt,
								--max(min(from_dt),wob) as from_dt 
								case
									when to_dt>dod then dod
									when to_dt<=dod then to_dt
									when dod is null then to_dt
									else dod
								end as calc_to_dt
								--min(max(to_dt),coalesce(dod,'9999-01-01')) as to_dt 
						from SAILWDSDV.AR_PERS_GP_20170711 gp2
						join SAILWDSDV.AR_PERS_20170711 person2 on
						person2.pers_id_e = gp2.pers_id_e 
						where (dod>=from_dt or dod is null)
						and (wob<=from_dt) -- or wob<=to_dt) this constraint did not make sense 
		   			 )
				group by alf_e
			) as sail_data

		on
		test1.alf_e = sail_data.alf_e and
		from_dt = test1.start_date and 
		to_dt = test1.end_date
		where sail_data.alf_e is null
	)
	
	select 
		--Enter the number of the test according to the spreadsheet here.
		4 as test_num,
		'When an alf_e table is not specified, and keep_non_sail_recs is 1, all GP registrations are included within the output.' as description,
		--test condition that proves whether the test passed here
		case when unmatched_records = 0 	
			then 'pass' else 'fail'
		end as result,
		--Always include these
		SAILX0286V.TEST_VERSION,
		current user,
		current timestamp
		from test_query!

--Clean up: drop the table the procedure created, as well as any other tables
--you created for the test.
drop table sailx0286v.test4!
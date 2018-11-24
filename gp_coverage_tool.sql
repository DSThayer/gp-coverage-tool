---------------------------------------------------------------------------------------------------
--gp_coverage_tool.sql
--
--Dan Thayer
--
--Copyright 2018 Swansea University
--
--Licensed under the Apache License, Version 2.0 (the "License");
--you may not use this file except in compliance with the License.
--You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
--Unless required by applicable law or agreed to in writing, software
--distributed under the License is distributed on an "AS IS" BASIS,
--WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--See the License for the specific language governing permissions and
--limitations under the License.
--
---------------------------------------------------------------------------------------------------
--
--A procedure for measuring individual follow-up within the GP dataset in the SAIL Databank 
--(www.saildatabank.com), based on event volumes in the data, and individual registration records
--in the Welsh Demographic Service dataset.
--
--This procedure uses DB2 logging utilities I have developed, which can be found in
--https://github.com/DSThayer/DB2-Utility-Procedures




set schema fnc! --production
--set schema sailx0286v!     --development

declare global temporary table session.cleaned_gp_regs (
	alf_e					integer,
	reg_start_date			date, 
	reg_end_date			date,
	start_date 				date,
	end_date 				date,
	data_start              date,
	comparison_field		integer,	--the value used for combining records.
	gp_data_flag			integer,
	prac_cd_e				integer,
	wob                     date,
	available_from			timestamp
) with replace on commit preserve rows!

declare global temporary table session.temp_cleaned_gp_regs like session.cleaned_gp_regs
	with replace on commit preserve rows!

call fnc.drop_specific_proc_if_exists(current schema||'.clean_gp_regs')!
create procedure clean_gp_regs(
	target_table 		varchar(200) default '',
	log_table	 		varchar(200),
	alf_e_table			varchar(200) default '',
	gp_data_extract		varchar(1000) default '',
	max_gap_to_fill 	integer	default 30, 
	threshold 			float	default .1,
	group_on_sail_data	integer	default 1,
	group_on_practice	integer default 0,
	keep_non_sail_recs	integer	default 0,
	ignore_practices_with_missing_data integer default 1,
	birth_correction integer default 1,
	use_median_event_rates integer default 1
)
specific fnc.clean_gp_regs
MODIFIES SQL DATA
language SQL
begin
	declare updated_rows, deleted_rows INTEGER default 1;
	declare num_rows INTEGER default 0;
	declare pass INTEGER default 1;
	declare event_rate_table varchar(1000);
	declare mean_table   varchar(1000);
	declare median_table varchar(1000);
	declare missing_data_table varchar(1000);
	declare patient_table varchar(1000);
	declare table_existed integer default 0;
    declare table_already_exists condition for sqlstate '42710';
    declare continue handler for table_already_exists set table_existed = 1;    

	declare global temporary table session.cleaned_gp_regs (
		alf_e					integer,
		reg_start_date			date, 
		reg_end_date			date,
		start_date 				date,
		end_date 				date,
		data_start              date,
		comparison_field		integer,	--the value used for combining records.
		gp_data_flag			integer,
		prac_cd_e				integer,
		wob						date, 
		available_from			timestamp
	) with replace on commit preserve rows;

	declare global temporary table session.temp_cleaned_gp_regs like session.cleaned_gp_regs
		with replace on commit preserve rows;
    
		call fnc.log_start('clean_gp_regs',log_table);

    call fnc.log_msg('v2.02 (201800831)');
    call fnc.log_msg(
        'Call params: ' ||
        target_table        || ', ' || 
        log_table           || ', ' ||
        alf_e_table         || ', ' ||
        gp_data_extract     || ', ' ||
        max_gap_to_fill     || ', ' ||
        threshold           || ', ' ||
        group_on_sail_data  || ', ' ||
        group_on_practice   || ', ' ||
        keep_non_sail_recs
    );

		
		
	--If the target table is left blank, then the procedure will still run, but it
	--will go into session.cleaned_gp_recs.
	if target_table <> '' then
	
	   --dynamically create an SQL statement to create target table.  Do this first 
		--so the user knows right away if they forgot to delete the table.
		execute immediate 'create table ' || target_table || 
			' (alf_e integer, start_date date, end_date date, gp_data_flag integer,' ||
			'prac_cd_e integer, available_from timestamp)';
		
	   commit;
	   if table_existed = 1 then
	       execute immediate 'delete from '||target_table;
            call fnc.log_msg('Table already existed; emptying');
	   end if;
	end if;


	--Error handling: stop with error if incorrect parameters were given.
	if threshold <= 0 or threshold > 1 then
		call fnc.log_die('threshold must be > 0 and <= 1');
	end if;

	if group_on_sail_data not in (0,1) then
		call fnc.log_die('group_on_sail_data must be 0 or 1');
	end if;

	if group_on_practice  not in (0,1) then
		call fnc.log_die('group_on_practice must be 0 or 1');
	end if;

	if keep_non_sail_recs not in (0,1) then
		call fnc.log_die('keep_non_sail_recs must be 0 or 1');
	end if;

	declare global temporary table session.gp_data_present_alf_e (
		alf_e integer, pers_id_e integer
	) with replace on commit preserve rows;
	
	--Dynamically execute query to get the list of alf_e's.
	--If no alf_e table was given, get all alf_e's from ar_pers
	if alf_e_table = '' then
		execute immediate 'insert into session.gp_data_present_alf_e select distinct alf_e,pers_id_e from ' ||
			'sailwdsdv.ar_pers where alf_e is not null';
	else
		execute immediate 'insert into session.gp_data_present_alf_e select distinct a.alf_e,p.pers_id_e from ' ||
		alf_e_table || ' a join sailwdsdv.ar_pers p on p.alf_e = a.alf_e and p.alf_e is not null';
	end if;
	
	call fnc.log_msg('ALF table insert completed.');
	commit;

	--Use the default event rate table if the extract is not specified, or is
	--specified as the latest view.
	if lower(gp_data_extract) in ('','sailwlgpv.gp_event') then
		set (patient_table,mean_table,missing_data_table,median_table) = (
			select patient_alf_table,rate_table,missing_data_table,median_rate_table from sail0286v.gp_extract
				where is_default = 1
				fetch first 1 rows only
		);
	else 
		if (select count(*) from sail0286v.gp_extract where event_table=lower(gp_data_extract)) = 0 then		
			call fnc.log_die('Event table '||gp_data_extract||' does not exist.  Check sail0286v.gp_extract.');
		end if;
	
	
		set (patient_table,mean_table,missing_data_table,median_table) = (
			select patient_alf_table,rate_table,coalesce(missing_data_table,'NONE'),median_rate_table from sail0286v.gp_extract
				where event_table = lower(gp_data_extract)
				fetch first 1 rows only
		);
	end if;

	if use_median_event_rates = 1 then
	   if median_table is null then
	       call fnc.log_die('No median event table for selected extract. Set use_median_event_rates=>0 to use mean instead.');
	   end if;
	
	   set event_rate_table = median_table;
	else
	   set event_rate_table = mean_table;
	end if;
	
	call fnc.log_msg('Event rate table: '||event_rate_table||'; Missing data table: '||missing_data_table);
	commit;

	declare global temporary table session.sail_gp_data (
		prac_cd_e 	integer,
		data_start 	date,
		data_end	date
	) with replace on commit preserve rows;
	
	execute immediate 'insert into session.sail_gp_data
		select prac_cd_e, data_start, data_end from (
			select 	prac_cd_e, 
					min(month_start) as data_start, 
					max(month_end) as data_end,
					--Number by length of good data period.
					row_number() over (
						partition by prac_cd_e,case when year(max(month_end)) >= 2008 then 1 else 0 end
						order by days(max(month_end)) - days(min(month_start)) desc
					) as period_length_rank
					
				from (
				select 	prac_cd_e,
						relative_event_rate as event_rate,
						date(event_yr || ''-'' || event_mo || ''-'' || ''01'') as month_start,
						date(event_yr || ''-'' || event_mo || ''-'' || ''01'') + 
							1 month - 1 day as month_end,
						(
							row_number() over (
								partition by prac_cd_e 
								order by prac_cd_e, event_yr, event_mo
							)
						) - 
						(
							row_number() over (
								partition by 
									prac_cd_e, 
									case when relative_event_rate >= '||threshold||'
										then 1 
										else 0 
									end
								order by prac_cd_e, event_yr, event_mo
							)
						) as data_group,
						case when relative_event_rate >= '||threshold||'
							then 1 
							else 0 
						end as good_data
					from '||event_rate_table||'
				)
				where good_data = 1
				group by prac_cd_e, data_group
			)
			--Select the longest period for each practice only. The goal is to get a
			--single period of good data, not to get a bunch of little periods.
			where period_length_rank = 1 and year(data_end)>=2008';

    get diagnostics num_rows = row_count;
	call fnc.log_msg('Identified good data period for each practice (n='||num_rows||')');
	commit;

	execute immediate '
    	merge into session.sail_gp_data periods
    	using (
    	   select prac_cd_e,max(create_dt) extract_dt from '||patient_table||' group by prac_cd_E
    	) extract_dates
        on 
            periods.prac_cd_e = extract_dates.prac_cd_e and
            abs(days(periods.data_end)-(days(extract_dt) - 1)) <= 30
        when matched then update set
            data_end = extract_dt - 1 day
    ';

    get diagnostics num_rows = row_count;
    call fnc.log_msg(
        'Updated end date to day before extract date when within 30 days of good data period (n='||
        num_rows||')'
    );
    commit;
	
	--If a practice has missing data and the appropriate flag is set, handle it here.
	if ignore_practices_with_missing_data = 1 and missing_data_table <> 'NONE' then
		execute immediate '
			merge into session.sail_gp_data gp
			using (
				select distinct prac_cd_e from '||missing_data_table||'
 			) missing
 			on missing.prac_cd_e = gp.prac_cd_e
			when matched then delete';
		--TBD: missing data practice should be EMIS and not have a prev_extract_date before X date.

		call fnc.log_msg('Missing data practices.');
		commit;


	end if;


	--Find all of the gp registration records for which we have gp data in SAIL.
	--This statement will create some duplicates due to duplicate pers_id_e's existing in ar_pers.
	--However, these will all be removed in the logic below.
	insert into session.temp_cleaned_gp_regs
		--Get all the practices that have gp data available, with the first and last 
		--events for that practice.  Exclude event dates that are after the data period.
		select	alf_e_list.alf_e,
				max(gp_registration.from_dt,coalesce(person.wob   ,'0001-01-01')),
				min(gp_registration.to_dt,coalesce(person.dod   ,'9999-12-31')),
				--The period where there is actually good gp data, if this is a record with
				--gp data. Otherwise, the entire registration period.  These will be the 
				--final dates used.
				max(
					coalesce(gp.data_start,'0001-01-01'),
					coalesce(person.wob   ,'0001-01-01'),
					gp_registration.from_dt),
				min(
					coalesce(gp.data_end  ,'9999-12-31'),
					coalesce(person.dod   ,'9999-12-31'),
					gp_registration.to_dt 
				),
				coalesce(gp.data_start,'0001-01-01'),
				--Comparison field for grouping logic
				0,
				--GP data flag.
				case when gp.data_start is not null then 1 else 0 end,
				gp_registration.prac_cd_e,
				person.wob,
				current timestamp
			from sailwdsdv.ar_pers_gp gp_registration
			join session.gp_data_present_alf_e alf_e_list on
				gp_registration.pers_id_e = alf_e_list.pers_id_e
			join sailwdsdv.ar_pers person on
				person.alf_e = alf_e_list.alf_e
			left join session.sail_gp_data gp on
				group_on_sail_data = 1 and
				gp_registration.prac_cd_e =  gp.prac_cd_e  and
				gp_registration.to_dt   >= max(gp.data_start,coalesce(person.wob,'0001-01-01')) and
				gp_registration.from_dt <= min(gp.data_end,coalesce(person.dod,'9999-12-31'));

	get diagnostics num_rows = row_count;
	call fnc.log_msg('Found ' || num_rows || ' registrations for GPs.');
	commit;

	if birth_correction = 1 then

	   update (
           select wob, start_date,reg_start_date,data_start,row_number() over (partition by alf_e order by start_date) rown
               from session.temp_cleaned_gp_regs
	   ) first_recs
       set reg_start_date = wob,
            start_date = max(wob,data_start)
       where   rown = 1 and
               reg_start_date > wob and
	           reg_start_date < (wob + 42 days);
	           
       get diagnostics num_rows = row_count;
       call fnc.log_msg('Updated ' || num_rows || ' records within 6 weeks of birth to indicate date until birth');
       commit;
	           
	end if;
	
	delete from session.temp_cleaned_gp_regs where
		reg_end_date < reg_start_date;

	get diagnostics num_rows = row_count;
	call fnc.log_msg('Deleted ' || num_rows || 
		' erroneous records (before birth or after death).');
	commit;

	--Remove registrations with duplicate time periods
	delete from (
			select	lead(prac_cd_e) over (
						partition by alf_e,reg_start_date,reg_end_date
						--Always select the record with GP data.
						order by gp_data_flag desc, prac_cd_e asc
					) as duplicate
				from session.temp_cleaned_gp_regs
		)
		where duplicate is not null;

	get diagnostics num_rows = row_count;
	call fnc.log_msg('Deleted ' || num_rows || 
		' records that covered exact duplicate periods.');
	commit;

	--If there is a registration for which we partially have SAIL data, we need
	--to split this into multiple records for periods with and without data.
	--Do this by inserting new records for the non-GP-data period.
	--Don't do this at all if grouping all records.
	insert into session.temp_cleaned_gp_regs
		select	alf_e,
				null, 
				null, --these fields are not needed from this point on.
				reg_start_date,
				start_date - 1 day,
				null,
				0,
				0, --GP data flag
				prac_cd_e,
				wob,
				available_from
			from session.temp_cleaned_gp_regs where
				group_on_sail_data <> 0 and
				reg_start_date < start_date
		union all 
		select	alf_e,
				null, 
				null,
				end_date + 1 day,
				reg_end_date,
				null,
				0,
				0, --GP data flag
				prac_cd_e,
				wob,
				available_from
			from session.temp_cleaned_gp_regs where
				group_on_sail_data <> 0 and
				reg_end_date > end_date;

	get diagnostics num_rows = row_count;
	call fnc.log_msg('Added ' || num_rows || ' new records due to splitting ' ||
		'registrations that span SAIL and non-SAIL periods.');
	commit;

	--Empty the fields that are not relevant to the requested output.  
	if group_on_sail_data = 0 then
		update session.temp_cleaned_gp_regs
			set gp_data_flag = null;
		
		insert into session.cleaned_gp_regs
			select * from session.temp_cleaned_gp_regs;
	--If there is a table of missing data, update the records to apply these gaps.
	elseif missing_data_table <> 'NONE' then
	
       execute immediate '
           insert into session.cleaned_gp_regs
                select regs.* from session.temp_cleaned_gp_regs regs
                    left join '||missing_data_table||' missing on
                        missing.alf_e = regs.alf_e and
                        missing.prac_cd_e = regs.prac_cd_e and
                        missing.start_date <= regs.end_date and
                        missing.end_date >= regs.start_date and
                        gp_data_flag = 1
                    where missing.alf_e is null
        ';

		get diagnostics num_rows = row_count;
		call fnc.log_msg('Added ' || num_rows || ' records with no missing data issue');
		commit;
		
        --Now use insert statements to split records that overlap the missing data.
        --The overlapping portion does not have GP data.
        execute immediate '
        insert into session.cleaned_gp_regs
            select  regs.alf_e,
                    null,null,
                    max(regs.start_date,missing.start_date),
                    min(regs.end_date,missing.end_date),
                    null,
                    comparison_field,
                    0,  --No GP data for the portion that overlaps
                    regs.prac_cd_e,
                    wob,
                    available_from
                from session.temp_cleaned_gp_regs regs
                join '||missing_data_table||' missing on
                    missing.alf_e = regs.alf_e and
                    missing.prac_cd_e = regs.prac_cd_e and
                    missing.start_date <= regs.end_date and
                    missing.end_date >= regs.start_date and
                    gp_data_flag = 1';
                    
		get diagnostics num_rows = row_count;
		call fnc.log_msg('Added ' || num_rows || ' records covering missing GP data');
		commit;

        --The non-overlapping portions have GP data.
        execute immediate 'insert into session.cleaned_gp_regs
            select  regs.alf_e,
                    null,null,
                    regs.start_date,
                    missing.start_date - 1 day,
                    null,
                    comparison_field,
                    1,  --GP data for the portion that does not overlap
                    regs.prac_cd_e,
                    wob,
                    available_from
                from session.temp_cleaned_gp_regs regs
                join '||missing_data_table||' missing on
                    missing.alf_e = regs.alf_e and
                    missing.prac_cd_e = regs.prac_cd_e and
                    missing.start_date <= regs.end_date and
                    missing.start_date > regs.start_date and 
                    gp_data_flag = 1';
                    
		get diagnostics num_rows = row_count;
		call fnc.log_msg('Added ' || num_rows || ' truncated records preceding missing GP data');
		commit;
		
        execute immediate '
        insert into session.cleaned_gp_regs
            select  regs.alf_e      ,
                    null, 
                    null,
                    regs.end_date + 1 day,
                    missing.end_date,
                    null,
                    comparison_field,
                    1,  --GP data for the portion that does not overlap
                    regs.prac_cd_e      ,
                    wob,
                    available_from
                from session.temp_cleaned_gp_regs regs
                join '||missing_data_table||' missing on
                    missing.alf_e = regs.alf_e and
                    missing.prac_cd_e = regs.prac_cd_e and
                    missing.end_date >= regs.start_date and
                    missing.end_date < regs.end_date and
                    gp_data_flag = 1';

		get diagnostics num_rows = row_count;
		call fnc.log_msg('Added ' || num_rows || ' truncated records following missing GP data');
		commit;
	else
		insert into session.cleaned_gp_regs
			select * from session.temp_cleaned_gp_regs;
	end if;


	if group_on_practice = 0 then
		update session.cleaned_gp_regs
			set prac_cd_e = null;
	end if;




	--Set the comparison field for considering records combinable.
	update session.cleaned_gp_regs 
		set comparison_field = coalesce(prac_cd_e,0) * 10 + coalesce(gp_data_flag,0);

	--This loop processes adjacent records, fixing and combining them, until there
	--are no more records to correct. 
	while updated_rows + deleted_rows > 0 do
		--Find any adjacent records (gap between registrations that is less than
		--max_gap_to_fill).  Combine if combinable; otherwise, just remove overlaps and gaps.
		update (
				select 	comparison_field,
						lead(comparison_field) over (
							partition by alf_e order by alf_e,start_date
						) as next_comparison_field,
						end_date,
						lead(start_date)	over (
							partition by alf_e order by alf_e,start_date
						) as next_start_date,
						lead(end_date)		over (
							partition by alf_e order by alf_e,start_date
						) as next_end_date
					from session.cleaned_gp_regs
			) gp_record
			set gp_record.end_date = 
				--If the two records are not combinable, expand the first to fill small gaps.
				--This also shrinks the first record in the case of an overlap.
				case when next_comparison_field <> comparison_field  
					then next_start_date - 1 day
					--If the two records are combinable, grow the first to encompass the 
					--second. The second will be deleted in the delete statement below.
					else next_end_date 
				end
			where
				days(next_start_date) - days(end_date) <= max_gap_to_fill and
				--ignore cases where the second record is nested in the first.  These cases
				--are deleted below. 
				days(next_end_date) > days(end_date) and
				--Ignore the noncombinable cases that are already correct. Otherwise, 
				--this update loops forever.
				(
					days(next_start_date) - days(end_date) <> 1 or
					comparison_field = next_comparison_field
				); 
				
		get diagnostics updated_rows = row_count;

		--If two registration records are nested, delete the inner one. This removes
		--problem cases and also cleans up after the update statement above.
		delete from (
				select 	start_date,
						end_date,
						lag(end_date) over (
							partition by alf_e order by alf_e,start_date
						) as prev_end_date
					from session.cleaned_gp_regs gp 
			) 
			where (
				prev_end_date is not null and
				end_date <= prev_end_date) or
				--handle a special case where 1 day long records get an end_date set before start_date in the
				--update query above.
				end_date < start_date;	

		get diagnostics deleted_rows = row_count;

		call fnc.log_msg('Simplify GP records (pass ' || pass || '): modified ' || 
			updated_rows || ', deleted ' || deleted_rows || '.');

		set pass = pass + 1;
		if pass = 101 then
			call fnc.log_die('Error: Looped 100x over gp records! Breaking out of procedure.');
		end if;
	end while;
		   
    if group_on_sail_data = 1 and keep_non_sail_recs = 0 then
		delete from session.cleaned_gp_regs where gp_data_flag = 0;

		get diagnostics num_rows = row_count;
		call fnc.log_msg('Deleted ' || num_rows || ' records without GP data.');
		commit;
	end if;
	
	if target_table <> '' then
		--dynamically create SQL statement to populate target table.
		execute immediate 'insert into ' || target_table || 
	   		' select alf_e, start_date, end_date, gp_data_flag, prac_cd_e, available_from ' ||
	   		'from session.cleaned_gp_regs';
		commit;
	end if;
	
	call fnc.log_finish();
end!
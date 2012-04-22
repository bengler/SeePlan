
# longest case delays

select substr(title, 1, 40), document_id, avg_time from (
  select e1.case_document_id as case_id, avg(e2.document_date - e1.document_date) as avg_time from exchanges e1 
  join exchanges e2 
    on e1.case_document_id = e2.case_document_id and e2.document_date > e1.document_date and e2.description != 'Komplett elektronisk sak' and
      not exists (
        select true from exchanges e3 where 
          e1.case_document_id = e3.case_document_id and e3.document_date < e2.document_date and e3.document_date > e1.document_date
        )
  where e1.incoming = true and e2.incoming = false group by e1.case_document_id order by avg_time desc
) as q join cases on cases.document_id = case_id limit 100;


# shortest case worker delay

select parties.name, parties.id, time from 
  (select case_worker_id, avg(avg_time) as time from (
    select e1.case_document_id as case_id, avg(e2.document_date - e1.document_date) as avg_time from exchanges e1 
    join exchanges e2 
      on e1.case_document_id = e2.case_document_id and e2.document_date > e1.document_date and e2.description != 'Komplett elektronisk sak' and
        not exists (
          select true from exchanges e3 where 
            e1.case_document_id = e3.case_document_id and e3.document_date < e2.document_date and e3.document_date > e1.document_date
          )
    where e1.incoming = true and e2.incoming = false group by e1.case_document_id
  ) as q join cases on cases.document_id = case_id group by case_worker_id)q2 
join parties on case_worker_id = parties.id order by time asc;
  
  
# department delay by month

drop table if exists tmp_case_dept_time;
create table tmp_case_dept_time (
  unit  text,
  month date,
  delay float
);

insert into tmp_case_dept_time 
  select cases.processing_unit as unit, date_trunc('month', e2.document_date) as trunc_month, avg(e2.document_date - e1.document_date) as avg_time from exchanges e1 
  join exchanges e2 
    on e1.case_document_id = e2.case_document_id and e2.document_date > e1.document_date and e2.description != 'Komplett elektronisk sak' and
      not exists (
        select true from exchanges e3 where 
          e1.case_document_id = e3.case_document_id and e3.document_date < e2.document_date and e3.document_date > e1.document_date
        )
  join cases on cases.document_id = e1.case_document_id
  where e1.incoming = true and e2.incoming = false group by cases.processing_unit, trunc_month;

copy tmp_case_dept_time to '/tmp/case_dept_time.csv' with csv header;

#in 'r'

foo <- read.csv("/Users/even/projects/visuals/planar/tmp/case_dept_time.csv", head=TRUE, sep=",")


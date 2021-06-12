create or replace type RecordFormatter as object
(
  output_writer Writer,
  member procedure write_record(p_record in sys.odcivarchar2list)
)
not instantiable not final
/

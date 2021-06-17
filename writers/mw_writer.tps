create or replace type mw_writer as object
(
  dummy integer,
  member procedure put_line(str varchar2),
  member function get_result return anydata
)
not instantiable not final;
/

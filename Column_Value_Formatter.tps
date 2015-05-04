create or replace type Column_Value_Formatter as object
(
  c            integer,
  column_index integer,
  member function format return varchar2
)
not instantiable not final
/

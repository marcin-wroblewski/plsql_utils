create or replace type Writer as object
(
  i integer,
  member procedure append_line(p_line in varchar2),
  member procedure close
)
not instantiable not final
/

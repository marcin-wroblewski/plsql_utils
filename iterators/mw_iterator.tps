create or replace type mw_iterator as object
(
  datatype integer,
  member function next(self in out mw_iterator) return anydata,
  member function has_next return boolean
)
not instantiable not final;
/

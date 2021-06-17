create or replace type mw_clob_lines_iterator under mw_iterator
(
  priv$clob     clob,
  priv$curr_pos integer,
  priv$next_nl  integer,
  constructor function mw_clob_lines_iterator(c in clob)
    return self as result,
  overriding member function next(self in out mw_clob_lines_iterator)
    return anydata,
  overriding member function has_next return boolean
)
/
create or replace type body mw_clob_lines_iterator is
  constructor function mw_clob_lines_iterator(c in clob)
    return self as result is
  begin
    priv$clob := c;
    datatype  := dbms_types.TYPECODE_VARCHAR2;
  
    priv$curr_pos := 0;
    priv$next_nl  := dbms_lob.instr(priv$clob, chr(10), priv$curr_pos + 1);
    if priv$next_nl = 0 then
      priv$next_nl := dbms_lob.getlength(priv$clob) + 1;
    end if;
    return;
  end;

  overriding member function next(self in out mw_clob_lines_iterator)
    return anydata is
    l_data  anydata;
    l_value varchar2(32767);
  begin
    l_value       := dbms_lob.substr(priv$clob,
                                     priv$next_nl - priv$curr_pos - 1,
                                     priv$curr_pos + 1);
    priv$curr_pos := priv$next_nl;
    priv$next_nl  := dbms_lob.instr(priv$clob, chr(10), priv$curr_pos + 1);
    if priv$next_nl = 0 then
      priv$next_nl := dbms_lob.getlength(priv$clob) + 1;
    end if;
    l_data := anydata.ConvertVarchar2(l_value);
    return l_data;
  end;

  overriding member function has_next return boolean is
  begin
    return priv$curr_pos < dbms_lob.getlength(priv$clob);
  end;
end;
/

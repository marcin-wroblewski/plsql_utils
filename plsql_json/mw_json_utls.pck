create or replace package mw_json_utls is
  function to_pretty_clob(p_json in json_element_t) return clob;

end;
/
create or replace package body mw_json_utls is
  function to_pretty_clob(p_json in json_element_t) return clob is
    l_clob clob;
  begin
  
    l_clob := p_json.to_Clob();
    select json_serialize(l_clob returning clob pretty)
      into l_clob
      from dual;
    return l_clob;
  end;

end;
/

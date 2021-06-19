create or replace type mw_clob_writer under mw_writer
(
  priv$clob clob,
  constructor function mw_clob_writer return self as result,
  constructor function mw_clob_writer(c in clob) return self as result,
  overriding member procedure put_line(str varchar2),
  overriding member function get_result return anydata
)
/
create or replace type body mw_clob_writer is

  constructor function mw_clob_writer return self as result is
  begin
    dbms_lob.createtemporary(priv$clob, true, dbms_lob.session);
    return;
  end;

  constructor function mw_clob_writer(self in out mw_clob_writer,
                                      c    in clob) return self as result is
  begin
    priv$clob := c;
    return;
  end;

  overriding member procedure put_line(self in out mw_clob_writer,
                                       str  varchar2) is
  begin
    dbms_lob.writeappend(self.priv$clob, length(str) + 1, str || chr(10));
  end;

  overriding member function get_result return anydata is
    l_data anydata;
  begin
    l_data := anydata.ConvertClob(priv$clob);
    return l_data;
  end;
end;
/

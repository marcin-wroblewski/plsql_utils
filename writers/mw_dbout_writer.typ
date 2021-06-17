create or replace type mw_dbout_writer under mw_writer
(
  constructor function mw_dbout_writer return self as result,
  overriding member procedure put_line(str varchar2),
  overriding member function get_result return anydata
)
/
create or replace type body mw_dbout_writer is
  constructor function mw_dbout_writer return self as result is
  begin
    return;
  end;

  overriding member procedure put_line(str varchar2) is
  begin
    dbms_output.put_line(str);
  end;

  overriding member function get_result return anydata is
  begin
    return null;
  end;
end;
/

create or replace type DbmsOutputWriter under Writer
(
  constructor function DbmsOutputWriter return self as result,
  overriding member procedure append_line(p_line in varchar2),
  overriding member procedure close
)
/
create or replace type body DbmsOutputWriter as

  constructor function DbmsOutputWriter return self as result is
  begin
    self.i := 0;
    dbms_output.enable(1000000);
    return;
  end;

  overriding member procedure append_line(p_line in varchar2) is
  begin
    dbms_output.put_line(p_line);
  end;

  overriding member procedure close is
  begin
    null;
  end;

end;
/

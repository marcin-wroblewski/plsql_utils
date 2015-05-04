create or replace type ClobWriter under Writer
(
  c clob,
  constructor function ClobWriter(c in clob) return self as result,
  overriding member procedure append_line(p_line in varchar2),
  overriding member procedure close
)
/
create or replace type body ClobWriter as

  constructor function ClobWriter(c in clob) return self as result is
  begin
    self.c := c;
    return;
  end;

  overriding member procedure append_line(p_line in varchar2) is
    l_clob clob;
  begin
    l_clob := self.c;
    dbms_lob.writeappend(l_clob, length(p_line), p_line);
  end;

  overriding member procedure close is
  begin
    null;
    --dbms_lob.close(self.c);
  end;

end;
/

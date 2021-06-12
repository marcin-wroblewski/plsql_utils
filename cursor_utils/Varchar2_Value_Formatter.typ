create or replace type Varchar2_Value_Formatter under Column_Value_Formatter
(
  constructor function Varchar2_Value_Formatter(c            in integer,
                                                column_index in integer,
                                                length       in integer)
    return self as result,
  overriding member function format return varchar2
)
/
create or replace type body Varchar2_Value_Formatter as

  constructor function Varchar2_Value_Formatter(c            in integer,
                                                column_index in integer,
                                                length       in integer)
    return self as result is
    l_value varchar2(1);
  begin
    self.c            := c;
    self.column_index := column_index;
    dbms_sql.define_column(self.c, self.column_index, l_value, length);
    return;
  end;

  overriding member function format return varchar2 is
    l_value varchar2(32767);
  begin
    dbms_sql.column_value(self.c, self.column_index, l_value);
    return l_value;
  end;

end;
/

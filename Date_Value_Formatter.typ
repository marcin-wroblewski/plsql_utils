create or replace type Date_Value_Formatter under Column_Value_Formatter
(
  format_string varchar2(100),
  constructor function Date_Value_Formatter(c        in integer,
                                            column_index  in integer,
                                            format_string in varchar2)
    return self as result,
  overriding member function format return varchar2
)
/
create or replace type body Date_Value_Formatter as

  constructor function Date_Value_Formatter(c        in integer,
                                            column_index  in integer,
                                            format_string in varchar2)
    return self as result is
    l_date date;
  begin
    self.c             := c;
    self.column_index  := column_index;
    self.format_string := format_string;
    dbms_sql.define_column(self.c, self.column_index, l_date);
    return;
  end;

  overriding member function format return varchar2 is
    l_value date;
  begin
    dbms_sql.column_value(self.c, self.column_index, l_value);
    return to_char(l_value, self.format_string);
  end;

end;
/

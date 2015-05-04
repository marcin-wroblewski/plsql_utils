create or replace type Number_Value_Formatter under Column_Value_Formatter
(
  constructor function Number_Value_Formatter(c            in integer,
                                              column_index in integer)
    return self as result,
  overriding member function format return varchar2
)
/
create or replace type body Number_Value_Formatter as

  constructor function Number_Value_Formatter(c            in integer,
                                              column_index in integer)
    return self as result is
    l_value number;
  begin
    self.c            := c;
    self.column_index := column_index;
    dbms_sql.define_column(self.c, self.column_index, l_value);
    return;
  end;

  overriding member function format return varchar2 is
    l_value number;
  begin
    dbms_sql.column_value(self.c, self.column_index, l_value);
    return to_char(l_value);
  end;

end;
/

create or replace type CSVRecordFormatter under RecordFormatter
(
  separator      varchar2(10),
  enclosing_char varchar2(10),
  overriding member procedure write_record(p_record in sys.odcivarchar2list),
  overriding member procedure finish_writing
)
/
create or replace type body CSVRecordFormatter as

  overriding member procedure write_record(p_record in sys.odcivarchar2list) is
    i      binary_integer;
    l_line varchar2(32767);
  begin
    i := p_record.first();
    while i is not null loop
      --TODO take enclosing_char into account
      l_line := l_line || p_record(i);
      i      := p_record.next(i);
      if i is not null then
        l_line := l_line || self.separator;
      end if;
    end loop;
    self.output_writer.append_line(l_line);
  end;

  overriding member procedure finish_writing is
  begin
    self.output_writer.close();
  end;

end;
/

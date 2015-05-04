create or replace type FixedWidthRecordFormatter under RecordFormatter
(
  fields_width sys.odcinumberlist,
  constructor function FixedWidthRecordFormatter(output_writer in Writer,
                                                 fields_count  in integer)
    return self as result,
  member procedure set_field_width(self           in out FixedWidthRecordFormatter,
                                   p_field_number in integer,
                                   p_width        in integer),
  overriding member procedure write_record(p_record in sys.odcivarchar2list),
  overriding member procedure finish_writing
)
/
create or replace type body FixedWidthRecordFormatter as

  constructor function FixedWidthRecordFormatter(output_writer in Writer,
                                                 fields_count  in integer)
    return self as result is
  begin
    self.output_writer := output_writer;
    self.fields_width  := new sys.odcinumberlist();
    self.fields_width.extend(fields_count);
    return;
  end;

  member procedure set_field_width(self           in out FixedWidthRecordFormatter,
                                   p_field_number in integer,
                                   p_width        in integer) is
  begin
    self.fields_width(p_field_number) := p_width;
  end;

  overriding member procedure write_record(p_record in sys.odcivarchar2list) is
    l_line varchar2(32767);
  begin
    for i in 1 .. p_record.count() loop
      l_line := l_line || rpad(p_record(i), self.fields_width(i));
    end loop;
    self.output_writer.append_line(l_line);
  end;

  overriding member procedure finish_writing is
  begin
    self.output_writer.close();
  end;

end;
/

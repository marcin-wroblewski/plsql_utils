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
    function contains(p_text in varchar2, p_substr in varchar2)
      return boolean is
    begin
      return instr(p_text, p_substr) > 0;
    end;
  
    --Fields with embedded commas or double-quote characters must be quoted.
    --Fields with embedded line breaks must be quoted
    function must_enclose(p_text in varchar2) return boolean is
      NEW_LINE constant varchar2(1) := chr(10);
    begin
      return contains(p_text, self.separator) --
      or contains(p_text, self.enclosing_char) --
      or contains(p_text, NEW_LINE);
    end;
  
    function optionally_enclose(p_text in varchar2) return varchar2 is
      l_result varchar2(32767);
    begin
      if self.enclosing_char is not null and must_enclose(p_text) then
        return self.enclosing_char ||
        --Each of the embedded double-quote characters must be represented by a pair of double-quote characters.
        replace(p_text,
                self.enclosing_char,
                self.enclosing_char || self.enclosing_char) --
        || self.enclosing_char;
      end if;
      return p_text;
    end;
  
  begin
    i := p_record.first();
    while i is not null loop
      l_line := l_line || optionally_enclose(p_record(i));
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

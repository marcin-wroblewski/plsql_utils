create or replace type FileWriter under Writer
(
  directory_name varchar2(30),
  file_name      varchar2(100),
  file_handle    integer,
  is_open        integer,
  constructor function FileWriter(directory_name in varchar2,
                                  file_name      in varchar2)
    return self as result,
  member procedure open_file_if_needed,
  overriding member procedure append_line(p_line in varchar2),
  overriding member procedure close
)
/
create or replace type body FileWriter as

  constructor function FileWriter(directory_name in varchar2,
                                  file_name      in varchar2)
    return self as result is
  begin
    self.directory_name := directory_name;
    self.file_name      := file_name;
    self.is_open        := 0;
    self.file_handle    := 0;
    return;
  end;

  member procedure open_file_if_needed is
  begin
    if self.is_open = 0 then
      self.file_handle := File_Writer_Helper.open_file(self.directory_name,
                                                       self.file_name,
                                                       File_Writer_Helper.C_APPEND_TEXT_MODE);
      self.is_open     := 1;
    end if;
  end;

  overriding member procedure append_line(p_line in varchar2) is
  begin
    open_file_if_needed();
    File_Writer_Helper.append_line(self.file_handle, p_line);
  end;

  overriding member procedure close is
  begin
    if self.is_open <> 0 then
      File_Writer_Helper.close(self.file_handle);
      self.is_open := 0;
    end if;
  end;

end;
/

create or replace package File_Writer_Helper as

  C_READ_TEXT_MODE constant varchar2(2) := 'r';

  C_WRITE_TEXT_MODE constant varchar2(2) := 'w';

  C_APPEND_TEXT_MODE constant varchar2(2) := 'a';

  C_READ_BYTE_MODE constant varchar2(2) := 'rb';

  C_WRITE_BYTE_MODE constant varchar2(2) := 'wb';

  C_APPEND_BYTE_MODE constant varchar2(2) := 'ab';

  function open_file(p_directory_name in varchar2,
                     p_file_name      in varchar2,
                     p_open_mode      in varchar2,
                     p_max_linesize   in binary_integer default null)
    return integer;

  procedure append_line(p_file_handle in integer, p_line in varchar2);

  procedure close(p_file_handle in integer);

end;
/
create or replace package body File_Writer_Helper as

  g_max_handle binary_integer := 1;

  type t_opened_files is table of utl_file.file_type index by binary_integer;

  g_opened_files t_opened_files;

  function open_file(p_directory_name in varchar2,
                     p_file_name      in varchar2,
                     p_open_mode      in varchar2,
                     p_max_linesize   in binary_integer default null)
    return integer is
    l_file_handle binary_integer;
    l_file_type   utl_file.file_type;
  begin
    l_file_handle := g_max_handle;
    l_file_type := utl_file.fopen(p_directory_name,
                                  p_file_name,
                                  p_open_mode);
    g_opened_files(l_file_handle) := l_file_type;
    g_max_handle := g_max_handle + 1;
    return l_file_handle;
  end;

  procedure append_line(p_file_handle in integer, p_line in varchar2) is
    l_file_type utl_file.file_type;
  begin
    l_file_type := g_opened_files(p_file_handle);
    utl_file.put_line(l_file_type, p_line);
  end;

  procedure close(p_file_handle in integer) is
    l_file_type utl_file.file_type;
  begin
    l_file_type := g_opened_files(p_file_handle);
    utl_file.fflush(l_file_type);
    utl_file.fclose(l_file_type);
    g_opened_files.delete(p_file_handle);
  end;

end;
/

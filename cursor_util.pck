create or replace package cursor_util as

  C_DEFAULT_SEPARATOR varchar2(1) := ';';

  E_COLUMN_TYPE_NOT_SUPPORTED exception;

  subtype t_column_name is varchar2(30);

  subtype t_format_string is varchar2(30);

  type t_column_info is record(
    column_name  t_column_name,
    is_date_time boolean default false,
    format       t_format_string);

  type t_column_info_tab is table of t_column_info;

  type t_csv_format is record(
    separator      varchar2(10),
    enclosing_char varchar2(10));

  type t_file_spec is record(
    directory_name varchar2(30),
    file_name      varchar2(100));

  function column_info(p_column_name  in t_column_name,
                       p_is_date_time in boolean default false,
                       p_format       in t_format_string default null)
    return t_column_info;

  function no_specific_column_info return t_column_info_tab;

  function csv_format(p_separator      in varchar2 default C_DEFAULT_SEPARATOR,
                      p_enclosing_char in varchar2 default null)
    return t_csv_format;

  function file_spec(p_directory_name in varchar2, p_file_name in varchar2)
    return t_file_spec;

  function get_dbms_output_writer return Writer;

  function get_file_writer(p_directory_name in varchar2,
                           p_file_name      in varchar2) return Writer;

  function get_clob_writer(p_clob in out clob) return Writer;

  --by default date format is yyyy-mm-dd.
  procedure set_date_format(p_format in t_format_string);

  procedure set_date_time_format(p_format in t_format_string);

  procedure write_as_csv(p_cursor               in out sys_refcursor,
                         p_output_writer        in Writer default get_dbms_output_writer(),
                         p_csv_format           in t_csv_format default csv_format(),
                         p_headers              in sys.odcivarchar2list default null,
                         p_specific_column_info in t_column_info_tab default no_specific_column_info());

  procedure write_as_fixed_width(p_cursor               in out sys_refcursor,
                                 p_output_writer        in Writer default get_dbms_output_writer(),
                                 p_csv_format           in t_csv_format default csv_format(),
                                 p_specific_column_info in t_column_info_tab default no_specific_column_info());

end;
/
create or replace package body cursor_util as

  subtype t_dbms_sql_cursor is integer;

  type t_data_formats is record(
    date_format      t_format_string := 'yyyy-mm-dd',
    date_time_format t_format_string := 'yyyy-mm-dd hh24:mi:ss',
    number_format    t_format_string := 'tm9');

  type t_column_handler is record(
    formatter Column_Value_Formatter);

  type t_column_handlers_tab is table of t_column_handler;

  g_data_formats t_data_formats;

  function no_specific_column_info return t_column_info_tab is
    l_col_info t_column_info_tab := t_column_info_tab();
  begin
    return l_col_info;
  end;

  /*
    Varchar2_Type                         constant pls_integer :=   1;
    Number_Type                           constant pls_integer :=   2;
    Long_Type                             constant pls_integer :=   8;
    Rowid_Type                            constant pls_integer :=  11;
    Date_Type                             constant pls_integer :=  12;
    Raw_Type                              constant pls_integer :=  23;
    Long_Raw_Type                         constant pls_integer :=  24;
    Char_Type                             constant pls_integer :=  96;
    Binary_Float_Type                     constant pls_integer := 100;
    Binary_Bouble_Type                    constant pls_integer := 101;
    MLSLabel_Type                         constant pls_integer := 106;
    User_Defined_Type                     constant pls_integer := 109;
    Ref_Type                              constant pls_integer := 111;
    Clob_Type                             constant pls_integer := 112;
    Blob_Type                             constant pls_integer := 113;
    Bfile_Type                            constant pls_integer := 114;
    Timestamp_Type                        constant pls_integer := 180;
    Timestamp_With_TZ_Type                constant pls_integer := 181;
    Interval_Year_to_Month_Type           constant pls_integer := 182;
    Interval_Day_To_Second_Type           constant pls_integer := 183;
    Urowid_Type                           constant pls_integer := 208;
    Timestamp_With_Local_TZ_type          constant pls_integer := 231;
  */
  function column_info(p_column_name  in t_column_name,
                       p_is_date_time in boolean default false,
                       p_format       in t_format_string default null)
    return t_column_info is
    l_column_info t_column_info;
  begin
    l_column_info.column_name  := p_column_name;
    l_column_info.is_date_time := p_is_date_time;
    l_column_info.format       := p_format;
    return l_column_info;
  end;

  function csv_format(p_separator      in varchar2 default C_DEFAULT_SEPARATOR,
                      p_enclosing_char in varchar2 default null)
    return t_csv_format is
    l_csv_format t_csv_format;
  begin
    l_csv_format.separator      := p_separator;
    l_csv_format.enclosing_char := p_enclosing_char;
    return l_csv_format;
  end;

  function file_spec(p_directory_name in varchar2, p_file_name in varchar2)
    return t_file_spec is
    l_file t_file_spec;
  begin
    l_file.directory_name := p_directory_name;
    l_file.file_name      := p_file_name;
    return l_file;
  end;

  function get_dbms_output_writer return Writer is
  begin
    return new DbmsOutputWriter();
  end;

  function get_file_writer(p_directory_name in varchar2,
                           p_file_name      in varchar2) return Writer is
  begin
    return new FileWriter(p_directory_name, p_file_name);
  end;

  function get_clob_writer(p_clob in out clob) return Writer is
  begin
    return new ClobWriter(p_clob);
  end;

  function find_column_info(p_column_info_tab in t_column_info_tab,
                            p_column_desc     in dbms_sql.desc_rec3)
    return t_column_info is
    i             binary_integer;
    l_column_info t_column_info;
  begin
    i := p_column_info_tab.first();
    while i is not null loop
      l_column_info := p_column_info_tab(i);
      if upper(l_column_info.column_name) = p_column_desc.col_name then
        return l_column_info;
      end if;
      i := p_column_info_tab.next(i);
    end loop;
    return null;
  end;

  procedure set_date_format(p_format in t_format_string) is
  begin
    g_data_formats.date_format := p_format;
  end;

  procedure set_date_time_format(p_format in t_format_string) is
  begin
    g_data_formats.date_time_format := p_format;
  end;

  function get_column_handler(p_cursor       in t_dbms_sql_cursor,
                              p_column_index in integer,
                              p_desc_rec     in dbms_sql.desc_rec3,
                              p_column_info  t_column_info)
    return t_column_handler is
    l_column_handler t_column_handler;
    l_format_string  t_format_string;
  begin
    case p_desc_rec.col_type
      when dbms_sql.Varchar2_Type then
        l_column_handler.formatter := Varchar2_Value_Formatter(c            => p_cursor,
                                                               column_index => p_column_index,
                                                               length       => p_desc_rec.col_max_len);
      when dbms_sql.Number_Type then
        l_format_string            := nvl(p_column_info.format,
                                          g_data_formats.number_format);
        l_column_handler.formatter := Number_Value_Formatter(c            => p_cursor,
                                                             column_index => p_column_index);
      when dbms_sql.Date_Type then
        if p_column_info.is_date_time then
          l_format_string := nvl(p_column_info.format,
                                 g_data_formats.date_time_format);
        else
          l_format_string := nvl(p_column_info.format,
                                 g_data_formats.date_format);
        end if;
        l_column_handler.formatter := Date_Value_Formatter(c             => p_cursor,
                                                           column_index  => p_column_index,
                                                           format_string => l_format_string);
      else
        raise E_COLUMN_TYPE_NOT_SUPPORTED;
    end case;
    return l_column_handler;
  end;

  function get_column_handlers(p_cursor       in t_dbms_sql_cursor,
                               p_col_metadata in t_column_info_tab)
    return t_column_handlers_tab is
    l_col_cnt         integer;
    l_desc_tab        dbms_sql.desc_tab3;
    l_desc_rec        dbms_sql.desc_rec3;
    l_column_info     t_column_info;
    l_column_handlers t_column_handlers_tab;
  begin
    dbms_sql.describe_columns3(p_cursor, l_col_cnt, l_desc_tab);
    l_column_handlers := t_column_handlers_tab();
    l_column_handlers.extend(l_col_cnt);
    for i in 1 .. l_col_cnt loop
      l_desc_rec := l_desc_tab(i);
      l_column_info := find_column_info(p_col_metadata, l_desc_rec);
      l_column_handlers(i) := get_column_handler(p_cursor       => p_cursor,
                                                 p_column_index => i,
                                                 p_desc_rec     => l_desc_rec,
                                                 p_column_info  => l_column_info);
    end loop;
    return l_column_handlers;
  end;

  procedure fill_record(p_cursor          in t_dbms_sql_cursor,
                        p_column_handlers in t_column_handlers_tab,
                        p_record          in out nocopy sys.odcivarchar2list) is
  begin
    for i in 1 .. p_column_handlers.count() loop
      p_record(i) := p_column_handlers(i).formatter.format();
    end loop;
  end;

  procedure write_rows(p_writer           in Writer,
                       p_cursor           in t_dbms_sql_cursor,
                       p_column_handlers  in t_column_handlers_tab,
                       p_record_formatter in out RecordFormatter) is
    l_record sys.odcivarchar2list := sys.odcivarchar2list();
  begin
    l_record.extend(p_column_handlers.count());
    while dbms_sql.fetch_rows(p_cursor) > 0 loop
      fill_record(p_cursor, p_column_handlers, l_record);
      p_record_formatter.write_record(l_record);
    end loop;
    p_record_formatter.finish_writing();
  end;

  procedure write_results(p_cursor       in out sys_refcursor,
                          p_writer       in out Writer,
                          p_col_metadata in t_column_info_tab) is
    l_cursor           t_dbms_sql_cursor;
    l_column_handlers  t_column_handlers_tab;
    l_output_formatter RecordFormatter;
  begin
    l_cursor           := dbms_sql.to_cursor_number(p_cursor);
    l_column_handlers  := get_column_handlers(l_cursor, p_col_metadata);
    l_output_formatter := new CSVRecordFormatter(p_writer, ',', null);
    write_rows(p_writer, l_cursor, l_column_handlers, l_output_formatter);
    dbms_sql.close_cursor(l_cursor);
  end;

  procedure write_as_csv(p_cursor               in out sys_refcursor,
                         p_output_writer        in Writer default get_dbms_output_writer(),
                         p_csv_format           in t_csv_format default csv_format(),
                         p_headers              in sys.odcivarchar2list default null,
                         p_specific_column_info in t_column_info_tab default no_specific_column_info()) is
    l_cursor           t_dbms_sql_cursor;
    l_column_handlers  t_column_handlers_tab;
    l_output_formatter RecordFormatter;
  begin
    l_cursor           := dbms_sql.to_cursor_number(p_cursor);
    l_column_handlers  := get_column_handlers(l_cursor,
                                              p_specific_column_info);
    l_output_formatter := CSVRecordFormatter(p_output_writer,
                                             p_csv_format.separator,
                                             p_csv_format.enclosing_char);
    if p_headers is not null then
      l_output_formatter.write_record(p_headers);
    end if;
    write_rows(p_output_writer,
               l_cursor,
               l_column_handlers,
               l_output_formatter);
    dbms_sql.close_cursor(l_cursor);
  end;

  function get_fixed_width_formatter(p_output_writer   in Writer,
                                     p_column_handlers in t_column_handlers_tab)
    return RecordFormatter is
    l_formatter FixedWidthRecordFormatter;
  begin
    l_formatter := FixedWidthRecordFormatter(p_output_writer,
                                             p_column_handlers.count());
    for i in 1 .. p_column_handlers.count() loop
      l_formatter.set_field_width(i, 30);
    end loop;
    return l_formatter;
  end;

  procedure write_as_fixed_width(p_cursor               in out sys_refcursor,
                                 p_output_writer        in Writer default get_dbms_output_writer(),
                                 p_csv_format           in t_csv_format default csv_format(),
                                 p_specific_column_info in t_column_info_tab default no_specific_column_info()) is
    l_cursor           t_dbms_sql_cursor;
    l_column_handlers  t_column_handlers_tab;
    l_output_formatter RecordFormatter;
  begin
    l_cursor           := dbms_sql.to_cursor_number(p_cursor);
    l_column_handlers  := get_column_handlers(l_cursor,
                                              p_specific_column_info);
    l_output_formatter := get_fixed_width_formatter(p_output_writer,
                                                    l_column_handlers);
    write_rows(p_output_writer,
               l_cursor,
               l_column_handlers,
               l_output_formatter);
    dbms_sql.close_cursor(l_cursor);
  end;

end;
/

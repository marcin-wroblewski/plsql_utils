create or replace package dev_plsql_json_pk as
  procedure output_procedures(p_type_name in varchar2);
end;
/
create or replace package body dev_plsql_json_pk as
  /*
  <<js_for_record_type>> ::=
  function js(p_val in <<record_type>>) return json_object_t is
    l_obj json_object_t := json_object_t();
  begin
    <<put_record_field_stmts>>
  end;
  
  <<put_record_field_stmts>> ::=
  l_obj.put('<<field_name>>', js(p_val.<<field_name>>);
  <<put_record_field_stmts>>
  |
  <<empty>>
  
  <<js_for_collection_type>> ::=
  function js(p_val in <<collection_type>>) return json_array_t is
    l_arr json_array_t := json_array_t();
  begin
    if p_val is null then
      return l_arr;
    end if;
  
    for i in 1 .. p_val.count() loop
      l_arr.append(js(p_val(i)));
    end loop;
    return l_arr;
  end;
  /
  */
  c_record_code     constant all_plsql_types.typecode%type := 'PL/SQL RECORD';
  c_collection_code constant all_plsql_types.typecode%type := 'COLLECTION';
  c_primitive_code  constant all_plsql_types.typecode%type := 'PRIMITIVE';

  subtype t_string is varchar2(4000);

  type t_pkg_src is record(
    spc sys.odcivarchar2list := sys.odcivarchar2list(),
    bdy sys.odcivarchar2list := sys.odcivarchar2list());

  type t_type_info is record(
    owner        all_plsql_types.owner%type,
    package_name all_plsql_types.package_name%type,
    type_name    all_plsql_types.type_name%type,
    typecode     all_plsql_types.typecode%type);

  type t_processed_types is table of t_type_info index by t_string;

  procedure add_procedures(p_type_name       in varchar2,
                           p_pkg_src         in out t_pkg_src,
                           p_processed_types in out t_processed_types);

  procedure add_line(p_lines in out sys.odcivarchar2list,
                     p_line  in varchar2) is
    l_index integer;
  begin
    l_index := p_lines.count() + 1;
    p_lines.extend();
    p_lines(l_index) := p_line;
  end;

  function primitive_base(p_type_name in varchar2) return varchar2 is
  begin
    if lower(p_type_name) in ('number', 'integer') then
      return 'number';
      --todo timestamp
    elsif lower(p_type_name) in ('date', 'timestamp') then
      return 'date';
    else
      return 'varchar2';
    end if;
  end;

  function is_numeric_primitive(p_fullname in varchar2) return boolean is
  begin
    --todo consider other numeric types: float, real, etc.
    -- #see sys.standard package NUMBER_BASE
    return primitive_base(p_fullname) = 'number';
  end;

  function is_date_primitive(p_fullname in varchar2) return boolean is
  begin
    --todo consider other date types: time, time with time zone
    -- #see sys.standard package DATE_BASE 
    return primitive_base(p_fullname) = 'date';
  end;

  function deserializer_name(p_type_info in t_type_info) return varchar2 is
  begin
    if p_type_info.typecode = c_primitive_code then
      if is_numeric_primitive(p_type_info.type_name) then
        return 'num';
      elsif is_date_primitive(p_type_info.type_name) then
        return 'dt';
      else
        return 'str';
      end if;
    end if;
  
    --todo resolve potential name clash; e.g. keep track of already generated names  
    return 'to_' || lower(p_type_info.type_name);
  end;

  function get_fullname(p_owner        in varchar2,
                        p_package_name in varchar2,
                        p_type_name    in varchar2) return varchar2 is
  begin
    -- simply converting to lowercase names here, because it's my personal preference
    -- but it would be safer to use dbms_utility.canonicalize 
    if p_owner is null and p_package_name is null then
      return lower(p_type_name);
    elsif nvl(p_owner, user) = user then
      return lower(p_package_name || '.' || p_type_name);
    else
      return lower(p_owner || '.' || p_package_name || '.' || p_type_name);
    end if;
  end;

  function get_fullname(p_type in t_type_info) return varchar2 is
  begin
    return get_fullname(p_type.owner,
                        p_type.package_name,
                        p_type.type_name);
  end;

  function get_type_info(p_type_name in varchar2) return t_type_info is
    l_info          t_type_info;
    l_dblink        t_string;
    l_part1_type    number;
    l_object_number number;
  
    c_context_plsql constant number := 1;
  begin
    if instr(p_type_name, '.') = 0 then
      l_info.type_name := upper(p_type_name);
      l_info.typecode  := c_primitive_code;
    else
      -- for now we only resolver pl/sql types; to be extended to e.g. schema collections and object types
      dbms_utility.name_resolve(name          => p_type_name,
                                context       => c_context_plsql,
                                schema        => l_info.owner,
                                part1         => l_info.package_name,
                                part2         => l_info.type_name,
                                dblink        => l_dblink,
                                part1_type    => l_part1_type,
                                object_number => l_object_number);
    
      select t.typecode
        into l_info.typecode
        from all_plsql_types t
       where t.owner = l_info.owner
         and t.package_name = l_info.package_name
         and t.type_name = l_info.type_name;
    end if;
  
    return l_info;
  end;

  procedure add_record_serializer(p_fullname in varchar2,
                                  p_fields   sys.odcivarchar2list,
                                  p_pkg_src  in out t_pkg_src) is
  
    c_hdr constant t_string := '  function js(p_val in <<record_type>>) return json_object_t';
    l_hdr t_string;
    c_put_field_stmt constant t_string := '    l_obj.put(''<<field_name>>'', js(p_val.<<field_name>>));';
    l_put_field_stmt t_string;
  begin
  
    l_hdr := replace(c_hdr, '<<record_type>>', p_fullname);
  
    add_line(p_pkg_src.spc, l_hdr || ';');
    add_line(p_pkg_src.bdy, l_hdr);
    add_line(p_pkg_src.bdy, '  is');
  
    add_line(p_pkg_src.bdy, '    l_obj json_object_t := json_object_t();');
    add_line(p_pkg_src.bdy, '  begin');
  
    for i in 1 .. p_fields.count() loop
      l_put_field_stmt := replace(c_put_field_stmt,
                                  '<<field_name>>',
                                  p_fields(i));
      add_line(p_pkg_src.bdy, l_put_field_stmt);
    end loop;
    add_line(p_pkg_src.bdy, '    return l_obj;');
    add_line(p_pkg_src.bdy, '  end;');
  end;

  function get_getter(p_type_info in t_type_info) return varchar2 is
  begin
    if p_type_info.typecode = c_primitive_code then
      if is_numeric_primitive(p_type_info.type_name) then
        return 'get_Number';
      else
        return 'get_String';
      end if;
    elsif p_type_info.typecode = c_collection_code then
      return 'get_Array';
    elsif p_type_info.typecode = c_record_code then
      return 'get_Object';
    end if;
  end;

  function generate_get_field_stmt(p_field           in varchar2,
                                   p_field_type      in varchar2,
                                   p_processed_types in t_processed_types)
    return varchar2 is
    c_get_field_stmt constant t_string := '    l_rec.<<field_name>> := <<field_deserializer>>(p_obj.<<getter>>(''<<field_name>>''));';
    l_get_field_stmt     t_string;
    l_field_deserializer t_string;
    l_getter             t_string;
    l_type_info          t_type_info;
  begin
    l_type_info          := p_processed_types(p_field_type);
    l_field_deserializer := deserializer_name(l_type_info);
  
    l_getter := get_getter(l_type_info);
  
    l_get_field_stmt := replace(c_get_field_stmt, '<<field_name>>', p_field);
    l_get_field_stmt := replace(l_get_field_stmt,
                                '<<field_deserializer>>',
                                l_field_deserializer);
  
    l_get_field_stmt := replace(l_get_field_stmt, '<<getter>>', l_getter);
    return l_get_field_stmt;
  end;

  procedure add_record_deserializer(p_fullname        in varchar2,
                                    p_fields          sys.odcivarchar2list,
                                    p_field_types     sys.odcivarchar2list,
                                    p_pkg_src         in out t_pkg_src,
                                    p_processed_types in t_processed_types) is
  
    c_hdr constant t_string := '  function <<deserializer_name>>(p_obj in json_object_t) return <<record_type>>';
    l_hdr               t_string;
    l_get_field_stmt    t_string;
    l_deserializer_name t_string;
  begin
    l_deserializer_name := deserializer_name(p_processed_types(p_fullname));
    l_hdr               := replace(c_hdr, '<<record_type>>', p_fullname);
    l_hdr               := replace(l_hdr,
                                   '<<deserializer_name>>',
                                   l_deserializer_name);
  
    add_line(p_pkg_src.spc, l_hdr || ';');
    add_line(p_pkg_src.bdy, l_hdr);
    add_line(p_pkg_src.bdy, '  is');
  
    add_line(p_pkg_src.bdy,
             replace('    l_rec <<record_type>>;',
                     '<<record_type>>',
                     p_fullname));
    add_line(p_pkg_src.bdy, '  begin');
  
    for i in 1 .. p_fields.count() loop
      l_get_field_stmt := generate_get_field_stmt(p_fields(i),
                                                  p_field_types(i),
                                                  p_processed_types);
    
      add_line(p_pkg_src.bdy, l_get_field_stmt);
    end loop;
    add_line(p_pkg_src.bdy, '    return l_rec;');
    add_line(p_pkg_src.bdy, '  end;');
  end;

  procedure add_record_type_proc(p_type_info       in t_type_info,
                                 p_pkg_src         in out t_pkg_src,
                                 p_processed_types in out t_processed_types) is
    l_field_type  t_string;
    l_fields      sys.odcivarchar2list := sys.odcivarchar2list();
    l_field_types sys.odcivarchar2list := sys.odcivarchar2list();
  
    l_record_type t_string;
  begin
    for r in (select t.*
                from all_plsql_type_attrs t
               where t.owner = p_type_info.owner
                 and t.package_name = p_type_info.package_name
                 and t.type_name = p_type_info.type_name
               order by t.attr_no) loop
      l_field_type := get_fullname(r.attr_type_owner,
                                   r.attr_type_package,
                                   r.attr_type_name);
      add_procedures(l_field_type, p_pkg_src, p_processed_types);
      add_line(l_fields, lower(r.attr_name));
      add_line(l_field_types, l_field_type);
    end loop;
  
    l_record_type := get_fullname(p_type_info);
  
    add_record_serializer(l_record_type, l_fields, p_pkg_src);
    add_record_deserializer(l_record_type,
                            l_fields,
                            l_field_types,
                            p_pkg_src,
                            p_processed_types);
  end;

  procedure add_collection_serializer(p_fullname in varchar2,
                                      p_pkg_src  in out t_pkg_src) is
    c_hdr constant t_string := '  function js(p_val in <<collection_type>>) return json_array_t';
    l_hdr t_string;
  begin
    l_hdr := replace(c_hdr, '<<collection_type>>', p_fullname);
  
    add_line(p_pkg_src.spc, l_hdr || ';');
    add_line(p_pkg_src.bdy, l_hdr);
    add_line(p_pkg_src.bdy, '  is');
    add_line(p_pkg_src.bdy, '    l_arr json_array_t := json_array_t();');
    add_line(p_pkg_src.bdy, '  begin');
    add_line(p_pkg_src.bdy, '    if p_val is null then');
    add_line(p_pkg_src.bdy, '      return l_arr;');
    add_line(p_pkg_src.bdy, '    end if;');
    add_line(p_pkg_src.bdy, '  ');
    add_line(p_pkg_src.bdy, '    for i in 1 .. p_val.count() loop');
    add_line(p_pkg_src.bdy, '      l_arr.append(js(p_val(i)));');
    add_line(p_pkg_src.bdy, '    end loop;');
    add_line(p_pkg_src.bdy, '    return l_arr;  ');
    add_line(p_pkg_src.bdy, '  end;');
  end;

  procedure add_collection_deserializer(p_fullname        in varchar2,
                                        p_elem_type       in varchar2,
                                        p_pkg_src         in out t_pkg_src,
                                        p_processed_types t_processed_types) is
    c_hdr constant t_string := '  function <<deserializer_name>>(p_arr in json_array_t) return <<collection_type>>';
    l_hdr t_string;
    c_tab_var constant t_string := '    l_tab <<collection_type>> := <<collection_type>>();';
    l_tab_var           t_string;
    l_elem_deserializer t_string;
    l_deserializer_name t_string;
  begin
    l_deserializer_name := deserializer_name(p_processed_types(p_fullname));
    l_hdr               := replace(c_hdr, '<<collection_type>>', p_fullname);
    l_hdr               := replace(l_hdr,
                                   '<<deserializer_name>>',
                                   l_deserializer_name);
    l_tab_var           := replace(c_tab_var,
                                   '<<collection_type>>',
                                   p_fullname);
  
    add_line(p_pkg_src.spc, l_hdr || ';');
    add_line(p_pkg_src.bdy, l_hdr);
    add_line(p_pkg_src.bdy, '  is');
    add_line(p_pkg_src.bdy, l_tab_var);
    add_line(p_pkg_src.bdy, '  begin');
    add_line(p_pkg_src.bdy, '    l_tab.extend(p_arr.get_size());');
    add_line(p_pkg_src.bdy, '    for i in 1 .. p_arr.get_size() loop');
  
    l_elem_deserializer := deserializer_name(p_processed_types(p_elem_type));
  
    add_line(p_pkg_src.bdy,
             replace('      l_tab(i) := <<elem_deserializer_name>>(json_object_t(p_arr.get(i-1)));',
                     '<<elem_deserializer_name>>',
                     l_elem_deserializer));
  
    add_line(p_pkg_src.bdy, '    end loop;');
    add_line(p_pkg_src.bdy, '    return l_tab;');
    add_line(p_pkg_src.bdy, '  end;');
  end;

  procedure add_coll_type_proc(p_type_info       in t_type_info,
                               p_pkg_src         in out t_pkg_src,
                               p_processed_types in out t_processed_types) is
    l_coll_info all_plsql_coll_types%rowtype;
    l_elem_type t_string;
    c_hdr constant t_string := '  function js(p_val in <<collection_type>>) return json_array_t';
    l_hdr       t_string;
    l_coll_type t_string;
  
    l_deserializer_name t_string;
  begin
    select t.*
      into l_coll_info
      from all_plsql_coll_types t
     where t.owner = p_type_info.owner
       and t.package_name = p_type_info.package_name
       and t.type_name = p_type_info.type_name;
    l_coll_type := get_fullname(p_type_info);
  
    l_elem_type := get_fullname(l_coll_info.elem_type_owner,
                                l_coll_info.elem_type_package,
                                l_coll_info.elem_type_name);
    add_procedures(l_elem_type, p_pkg_src, p_processed_types);
  
    add_collection_serializer(l_coll_type, p_pkg_src);
  
    l_deserializer_name := deserializer_name(p_type_info);
    add_collection_deserializer(l_coll_type,
                                l_elem_type,
                                p_pkg_src,
                                p_processed_types);
  end;

  procedure add_primitive_serializer(p_fullname in varchar2,
                                     p_pkg_src  in out t_pkg_src) is
    c_js_primitive_header constant t_string := '  function js(p_val in <<primitive_type>>) return varchar2';
    l_hdr t_string;
  
    procedure add_varchar2_js_proc_body(p_pkg_src in out t_pkg_src) is
    begin
      add_line(p_pkg_src.bdy, '    return p_val;');
    end;
    procedure add_number_js_proc_body(p_pkg_src in out t_pkg_src) is
    begin
      --todo number format
      add_line(p_pkg_src.bdy, '    return p_val;');
    end;
    procedure add_date_js_proc_body(p_pkg_src in out t_pkg_src) is
    begin
      add_line(p_pkg_src.bdy, '    return to_char(p_val, g_date_format);');
    end;
  begin
    l_hdr := replace(c_js_primitive_header,
                     '<<primitive_type>>',
                     p_fullname);
    add_line(p_pkg_src.spc, l_hdr || ';');
    add_line(p_pkg_src.bdy, l_hdr);
    add_line(p_pkg_src.bdy, '  is');
    add_line(p_pkg_src.bdy, '  begin');
  
    if is_numeric_primitive(p_fullname) then
      add_number_js_proc_body(p_pkg_src);
    elsif is_date_primitive(p_fullname) then
      add_date_js_proc_body(p_pkg_src);
    else
      add_varchar2_js_proc_body(p_pkg_src);
    end if;
  
    add_line(p_pkg_src.bdy, '  end;');
  end;

  /*
    function dt(p_str in varchar2) return date is
    begin
      if p_str like '%T%Z' then
        return to_date(p_str, 'yyyy-mm-dd"T"hh24:mi"Z"');
      else
        return to_date(p_str, 'yyyy-mm-dd"T"hh24:mi:ss');
      end if;
    end;
  */

  procedure add_primitive_deserializer(p_deserializer_name in varchar2,
                                       p_value_type        in varchar2,
                                       p_fullname          in varchar2,
                                       p_pkg_src           in out t_pkg_src) is
    c_hdr constant t_string := '  function <<deserializer_name>>(p_val in <<value_type>>) return <<primitive_type>>';
    l_hdr t_string;
  
    procedure add_varchar2_proc_body(p_pkg_src in out t_pkg_src) is
    begin
      add_line(p_pkg_src.bdy, '    return p_val;');
    end;
    procedure add_number_proc_body(p_pkg_src in out t_pkg_src) is
    begin
      --todo number format
      add_line(p_pkg_src.bdy, '    return p_val;');
    end;
    procedure add_date_proc_body(p_pkg_src in out t_pkg_src) is
    begin
      add_line(p_pkg_src.bdy, '    return to_date(p_val, g_date_format);');
    end;
  begin
    l_hdr := replace(c_hdr, '<<deserializer_name>>', p_deserializer_name);
    l_hdr := replace(l_hdr, '<<value_type>>', p_value_type);
    l_hdr := replace(l_hdr, '<<primitive_type>>', p_fullname);
  
    add_line(p_pkg_src.spc, l_hdr || ';');
    add_line(p_pkg_src.bdy, l_hdr);
    add_line(p_pkg_src.bdy, '  is');
    add_line(p_pkg_src.bdy, '  begin');
  
    if is_numeric_primitive(p_fullname) then
      add_number_proc_body(p_pkg_src);
    elsif is_date_primitive(p_fullname) then
      add_date_proc_body(p_pkg_src);
    else
      add_varchar2_proc_body(p_pkg_src);
    end if;
  
    add_line(p_pkg_src.bdy, '  end;');
  end;

  procedure add_primitive_proc(p_type_info in t_type_info,
                               p_pkg_src   in out t_pkg_src) is
    l_fullname     t_string;
    l_value_type   t_string;
    l_deserializer t_string;
  begin
    l_fullname := get_fullname(p_type_info);
    add_primitive_serializer(l_fullname, p_pkg_src);
  
    if is_numeric_primitive(l_fullname) then
      l_value_type := 'number';
    elsif is_date_primitive(l_fullname) then
      l_value_type := 'varchar2';
    else
      l_value_type := 'varchar2';
    end if;
  
    l_deserializer := deserializer_name(p_type_info);
  
    add_primitive_deserializer(l_deserializer,
                               l_value_type,
                               l_fullname,
                               p_pkg_src);
  end;

  procedure add_procedures(p_type_name       in varchar2,
                           p_pkg_src         in out t_pkg_src,
                           p_processed_types in out t_processed_types) is
    l_type_info t_type_info := get_type_info(p_type_name);
    l_fullname  t_string;
  begin
    l_fullname := get_fullname(l_type_info);
    if p_processed_types.exists(l_fullname) then
      return;
    elsif l_type_info.typecode = c_primitive_code and
          p_processed_types.exists(primitive_base(l_fullname)) then
      p_processed_types(l_fullname) := p_processed_types(primitive_base(l_fullname));
      return;
    else
      p_processed_types(l_fullname) := l_type_info;
    end if;
  
    if l_type_info.typecode = c_record_code then
      add_record_type_proc(l_type_info, p_pkg_src, p_processed_types);
    elsif l_type_info.typecode = c_collection_code then
      add_coll_type_proc(l_type_info, p_pkg_src, p_processed_types);
    elsif l_type_info.typecode = c_primitive_code then
      add_primitive_proc(l_type_info, p_pkg_src);
    end if;
    add_line(p_pkg_src.bdy, '');
  end;

  procedure init_pkg(p_pkg_src         in out t_pkg_src,
                     p_pkg_name        in varchar2,
                     p_processed_types in out t_processed_types) is
  begin
    add_line(p_pkg_src.spc,
             'create or replace package ' || p_pkg_name || ' as');
    add_line(p_pkg_src.bdy,
             'create or replace package body ' || p_pkg_name || ' as');
    add_line(p_pkg_src.bdy,
             '  g_date_format varchar2(30) := ''yyyy-mm-dd"T"hh24:mi:ss'';');
  
    add_procedures('DATE', p_pkg_src, p_processed_types);
    add_procedures('NUMBER', p_pkg_src, p_processed_types);
    add_procedures('VARCHAR2', p_pkg_src, p_processed_types);
  end;

  procedure finalize_pkg(p_pkg_src  in out t_pkg_src,
                         p_pkg_name in varchar2) is
  begin
    add_line(p_pkg_src.spc, 'end;');
    add_line(p_pkg_src.bdy, 'end;');
  end;

  function generate_pkg(p_type_name in varchar2,
                        p_pkg_name  in varchar2 default 'PLSQL_JSON')
    return t_pkg_src is
    l_pkg_src         t_pkg_src;
    l_processed_types t_processed_types;
  begin
    init_pkg(l_pkg_src, p_pkg_name, l_processed_types);
    add_procedures(p_type_name, l_pkg_src, l_processed_types);
    finalize_pkg(l_pkg_src, p_pkg_name);
    return l_pkg_src;
  end;

  procedure output_procedures(p_type_name in varchar2) is
    l_pkg_src t_pkg_src;
  begin
    l_pkg_src := generate_pkg(p_type_name);
    for i in 1 .. l_pkg_src.spc.count() loop
      dbms_output.put_line(l_pkg_src.spc(i));
    end loop;
    dbms_output.put_line('/');
    for i in 1 .. l_pkg_src.bdy.count() loop
      dbms_output.put_line(l_pkg_src.bdy(i));
    end loop;
    dbms_output.put_line('/');
  end;
end;
/

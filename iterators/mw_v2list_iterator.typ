create or replace type mw_v2list_iterator under mw_iterator
(
  priv$list      sys.odcivarchar2list,
  priv$cur_index integer,
  constructor function mw_v2list_iterator(list in sys.odcivarchar2list)
    return self as result,
  overriding member function next(self in out mw_v2list_iterator)
    return anydata,
  overriding member function has_next return boolean
)
/
create or replace type body mw_v2list_iterator is
  constructor function mw_v2list_iterator(list in sys.odcivarchar2list)
    return self as result is
  begin
    priv$list      := list;
    priv$cur_index := 0;
    datatype       := dbms_types.TYPECODE_VARCHAR2;
    return;
  end;

  overriding member function next(self in out mw_v2list_iterator) return anydata is
    l_data  anydata;
    l_value varchar2(32767);
  begin
    if priv$cur_index >= priv$list.count() then
      raise_application_error(-20001, 'Cannot get next element');
    end if;
    priv$cur_index := priv$cur_index + 1;
  
    l_value := priv$list(priv$cur_index);
    l_data  := anydata.ConvertVarchar2(l_value);
    return l_data;
  end;

  overriding member function has_next return boolean is
  begin
    return priv$cur_index < priv$list.count();
  end;
end;
/

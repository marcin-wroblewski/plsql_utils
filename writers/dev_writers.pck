create or replace package dev_writers is
  function get_dbout_writer return dev_writer;
end dev_writers;
/
create or replace package body dev_writers is

  function get_dbout_writer return dev_writer is
  begin
    return new dev_dbout_writer();
  end;
  
  
end dev_writers;
/

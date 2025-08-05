{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2005 by Free Pascal development team

    Low level file functions
    Nintendo DS does not have any drive, so no file handling is needed.
    Copyright (c) 2006 by Francesco Lombardi

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}



{****************************************************************************
                        Low level File Routines
               All these functions can set InOutRes on errors
****************************************************************************}

procedure NDS2PASErr(Err: longint);
begin
  if Err = 0 then { Else it will go through all the cases }
   exit;
  case Err of
   Sys_ENFILE,
   Sys_EMFILE,
   Sys_ENOSYS : Inoutres := 4;
   Sys_ENOENT : Inoutres := 2;
    Sys_EBADF : Inoutres := 6;
   Sys_ENOMEM,
   Sys_EFAULT : Inoutres := 217;
   Sys_EINVAL : Inoutres := 218;
    Sys_EPIPE,
    Sys_EINTR,
      Sys_EIO,
   Sys_EAGAIN,
   Sys_ENOSPC : Inoutres := 101;
 Sys_ENAMETOOLONG,
    Sys_ELOOP,
  Sys_ENOTDIR : Inoutres := 3;
    Sys_EROFS,
   Sys_EEXIST,
   Sys_EACCES : Inoutres := 5;
  Sys_EBUSY   : Inoutres := 162
  else begin
    Writeln(stderr, 'NDS2PASErr: unknown error ', err);
    flush(stderr);
    Inoutres := Err;
  end;
  end;
END;


procedure Errno2Inoutres;
begin
  NDS2PASErr(errno);
end;

procedure SetFileError(var Err: longint);
begin
  if Err >= 0 then
    InOutRes := 0
  else begin
    Err := errno;
    NDS2PASErr(Err);
    Err := 0;
  end;
end;




{ close a file from the handle value }
procedure do_close(handle: THandle);
var
  res: longint;
begin
  res := fclose(P_FILE(Handle));
  if res <> 0 then
    SetFileError(res)
  else
    InOutRes := 0;
end;

procedure do_erase(p: PAnsiChar; pchangeable: boolean);
var
  res: longint;
begin
  res := _unlink(p);
  if res <> 0 then
    SetFileError(res)
  else
    InOutRes := 0;
end;

procedure do_rename(p1, p2: PAnsiChar; p1changeable, p2changeable: boolean);
var
  res: longint;
begin
  res := _rename(p1, p2);
  if res <> 0 then
    SetFileError(res)
  else
    InOutRes := 0;
end;

function do_write(h: THandle; addr: pointer; len: longint) : longint;
var
  res: longint;
begin
  res := fwrite(addr, 1, len, P_FILE(h));
  if res > 0 then
    InOutRes := 0
  else
    SetFileError(res);
  do_write := res;
end;

function do_read(h: THandle; addr: pointer; len: longint) : longint;
var
  res: longint;
begin
  res := fread(addr, 1, len, P_FILE(h));
  if res > 0 then
    InOutRes := 0
  else
    SetFileError(res);
  do_read := res;
end;

function do_filepos(handle: THandle): longint;
var
  res: longint;
begin
  InOutRes := 0;

  res := ftell(P_FILE(handle));
  if res < 0 then
    SetFileError(res)
  else
    InOutRes := 0;
  do_filepos := res;
end;

procedure do_seek(handle: THandle; pos: longint);
var
  res: longint;
begin
  fseek(P_FILE(handle), pos, SEEK_SET);
  if res < 0 then
    SetFileError(res)
  else
    InOutRes := 0;
end;

function do_seekend(handle: THandle): longint;
var
  res: longint;
begin
  res := fseek(P_FILE(handle), 0, SEEK_END);
  if res < 0 then
    SetFileError(res)
  else
    InOutRes := 0;
  do_seekend := res;
end;

function do_filesize(handle: THandle): longint;
var
  res     : longint;
  statbuf : TStat;
begin
  res := fstat(fileno(P_FILE(handle)), statbuf);
  if res = 0 then
  begin
    InOutRes := 0;
    result := statbuf.st_size
  end else
  begin
    SetFileError(Res);
    do_filesize := -1;
  end;
end;

{ truncate at a given position }
procedure do_truncate(handle: THandle; pos: longint);
var
  res     : longint;
begin
  res := ftruncate(fileno(P_FILE(handle)), pos);
  if res <> 0 then
    SetFileError(res)
  else
    InOutRes := 0;
end;

procedure do_open(var f;p:PAnsiChar;flags:longint; pchangeable: boolean);
{
  filerec and textrec have both handle and mode as the first items so
  they could use the same routine for opening/creating.
  when (flags and $10)   the file will be append
  when (flags and $100)  the file will be truncate/rewritten
  when (flags and $1000) there is no check for close (needed for textfiles)
}
var
  oflags: string[10];
begin
{ close first if opened }
  if ((flags and $10000)=0) then
   begin
     case FileRec(f).mode of
      fminput,fmoutput,fminout : Do_Close(FileRec(f).Handle);
      fmclosed : ;
     else
      begin
        inoutres:=102; {not assigned}
        exit;
      end;
     end;
   end;
{ reset file Handle }
  FileRec(f).Handle:=UnusedHandle;

{ We do the conversion of filemodes here, concentrated on 1 place }
  case (flags and 3) of
   0 : begin
         oflags := 'rb'#0;
         filerec(f).mode := fminput;
       end;
   1 : begin
         if (flags and $1000)=$1000 then
           oflags := 'w+b' else
           oflags := 'wb';
         filerec(f).mode := fmoutput;
       end;
   2 : begin
         if (flags and $1000)=$1000 then
           oflags := 'w+' else
           oflags := 'r+';
         filerec(f).mode := fminout;
       end;
  end;
{ empty name is special }
  if p[0] = #0 then
   begin
     case FileRec(f).mode of
       fminput:
         FileRec(f).Handle := StdInputHandle;
       fminout, { this is set by rewrite }
       fmoutput :
         FileRec(f).Handle := StdOutputHandle;
       fmappend :
         begin
           FileRec(f).Handle := StdOutputHandle;
           FileRec(f).mode := fmoutput; {fool fmappend}
         end;
     end;
     exit;
   end;
{ real open call }
  errno := 0;
  FileRec(f).Handle := THandle(fopen(p, @oflags[1]));
  { open somtimes returns > -1 but errno was set }
  if FileRec(f).Handle = 0 then
    begin
      Errno2Inoutres;
      FileRec(f).mode:=fmclosed;
    end
  else
    InOutRes := 0;
end;




function do_isdevice(handle: THandle): boolean;
var
  StatRec: TStat;
begin
  Do_IsDevice := (handle >= 0) and (handle <= 2);
end;



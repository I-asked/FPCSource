{
    This file is part of the Free Component Library (FCL)
    Copyright (c) 1999-2002 by the Free Pascal development team

    BIOS functions unit for Nintendo DS
    Copyright (c) 2006 by Francesco Lombardi

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 *****************************************************************************}

function S_ISBLK(m: longint): boolean; inline;
begin
  result := (m and _IFMT) = _IFBLK;
end;

function S_ISCHR(m: longint): boolean; inline;
begin
  result := (m and _IFMT) = _IFCHR;
end;

function S_ISDIR(m: longint): boolean; inline;
begin
  result := (m and _IFMT) = _IFDIR;
end;

function S_ISFIFO(m: longint): boolean; inline;
begin
  result := (m and _IFMT) = _IFIFO;
end;

function S_ISREG(m: longint): boolean; inline;
begin
  result := (m and _IFMT) = _IFREG;
end;

function S_ISLNK(m: longint): boolean; inline;
begin
  result := (m and _IFMT) = _IFLNK;
end;

function S_ISSOCK(m: longint): boolean; inline;
begin
  result := (m and _IFMT) = _IFSOCK;
end;

function aeabi_read_tp : pointer; cdecl; external name '__aeabi_read_tp';

procedure _errno_tpoff; cdecl; external name 'errno(gottpoff)';

function myfpgeterrno : longint; [public, alias: 'FPC_SYS_GETERRNO'];
type
  plongint = ^longint;
begin
  Result := plongint(longword(aeabi_read_tp) + longword(@_errno_tpoff))^;
end;

procedure myfpseterrno(err : longint); [public, alias: 'FPC_SYS_SETERRNO'];
type
  plongint = ^longint;
begin
  plongint(longword(aeabi_read_tp) + longword(@_errno_tpoff))^ := err;
end;

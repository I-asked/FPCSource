{$ifdef NDS_INTERFACE}
//  Math coprocessor register definitions
const
  REG_DIVCNT          : pcuint16 = pointer($04000280);
  REG_DIV_NUMER       : pcint64 = pointer($04000290);
  REG_DIV_NUMER_L     : pcint32 = pointer($04000290);
  REG_DIV_NUMER_H     : pcint32 = pointer($04000294);
  REG_DIV_DENOM       : pcint64 = pointer($04000298);
  REG_DIV_DENOM_L     : pcint32 = pointer($04000298);
  REG_DIV_DENOM_H     : pcint32 = pointer($0400029C);
  REG_DIV_RESULT      : pcint64 = pointer($040002A0);
  REG_DIV_RESULT_L    : pcint32 = pointer($040002A0);
  REG_DIV_RESULT_H    : pcint32 = pointer($040002A4);
  REG_DIVREM_RESULT   : pcint64 = pointer($040002A8);
  REG_DIVREM_RESULT_L : pcint32 = pointer($040002A8);
  REG_DIVREM_RESULT_H : pcint32 = pointer($040002AC);
  REG_SQRTCNT         : pcuint16 = pointer($040002B0);
  REG_SQRT_PARAM      : pcuint64 = pointer($040002B8);
  REG_SQRT_PARAM_L    : pcuint32 = pointer($040002B8);
  REG_SQRT_PARAM_H    : pcuint32 = pointer($040002BC);
  REG_SQRT_RESULT     : pcuint32 = pointer($040002B4);

//  Math coprocessor modes

  DIV_64_64     = 2;
  DIV_64_32     = 1;
  DIV_32_32     = 0;
  DIV_BUSY      = (1 shl 15);
  DIV_MODE_MASK = 3;

  SQRT_64        = 1;
  SQRT_32        = 0;
  SQRT_BUSY      = (1 shl 15);
  SQRT_MODE_MASK = 1;

function inttof32(n: cint): cint32; inline;
function f32toint(n: cint32): cint; inline;
function floattof32(n: cfloat): cint32; inline;
function f32tofloat(n: cint32): cfloat; inline;
  
function divf32(num: cint32; den: cint32): cint32; inline;
function mulf32(a, b: cint32): cint32; inline;
function sqrtf32(a: cint32): cint32; inline;
function div32(num, den: cint32): cint32; inline;
function mod32(num, den: cint32): cint32; inline;
function div64(num: cint64; den: cint32): cint32; inline;
function mod64(num: cint64; den: cint32): cint32; inline;
function sqrt32(a: cint32): cuint32; inline;
function sqrt64(a: cint64): cuint32; inline;
procedure crossf32(a: pcint32; b: pcint32; res: pcint32); inline;
function dotf32(a, b: pcint32): cint32; inline;
procedure normalizef32(a: pcint32);
{$endif NDS_INTERFACE}

{$ifdef NDS_IMPLEMENTATION}
function inttof32(n: cint): cint32; inline;
begin
  inttof32 := n * (1 shl 12);
end;

function f32toint(n: cint32): cint; inline;
begin
  f32toint := n div (1 shl 12);
end;

function floattof32(n: cfloat): cint32; inline;
begin
  floattof32 := trunc((n) * (1 shl 12));
end;

function f32tofloat(n: cint32): cfloat; inline;
begin
  f32tofloat := cfloat(n * 1.0) / cfloat((1 shl 12) * 1.0);
end;

function divf32(num: cint32; den: cint32): cint32; inline;
begin
  REG_DIV_NUMER^ := cint64(num) shl 12;
  REG_DIV_DENOM_L^ := den;

  if (REG_DIVCNT^ and DIV_MODE_MASK) <> DIV_64_32 then
    REG_DIVCNT^ := DIV_64_32;

  while (REG_DIVCNT^ and DIV_BUSY) <> 0 do;

  divf32 := REG_DIV_RESULT_L^;
end;

function mulf32(a, b: cint32): cint32; inline;
var
  rslt: clonglong;
begin
  rslt := clonglong(a) * clonglong(b);
  mulf32 := cint32(rslt shr 12);
end;

//  Fixed point square root
//  Takes 20.12 fixed point value and
//  returns the fixed point result
function sqrtf32(a: cint32): cint32; inline;
begin
  REG_SQRT_PARAM^ := cuint64(a) shl 12;

  if (REG_SQRTCNT^ and SQRT_MODE_MASK) <> SQRT_64 then
    REG_SQRTCNT^ := SQRT_64;

  while (REG_SQRTCNT^ and SQRT_BUSY) <> 0 do;

  sqrtf32 := REG_SQRT_RESULT^;
end;

//  Integer versions

//  Integer divide
//  Takes a 32 bit numerator and 32 bit
//  denominator and returns 32 bit result
function div32(num, den: cint32): cint32; inline;
begin
  REG_DIV_NUMER_L^ := num;
  REG_DIV_DENOM_L^ := den;

  if (REG_DIVCNT^ and DIV_MODE_MASK) <> DIV_32_32 then
    REG_DIVCNT^ := DIV_32_32;

  while (REG_DIVCNT^ and DIV_BUSY) <> 0 do;

  div32 := REG_DIV_RESULT_L^;
end;

//  Integer divide
//  Takes a 32 bit numerator and 32 bit
//  denominator and returns 32 bit result
function mod32(num, den: cint32): cint32; inline;
begin
  REG_DIV_NUMER_L^ := num;
  REG_DIV_DENOM_L^ := den;

  if (REG_DIVCNT^ and DIV_MODE_MASK) <> DIV_32_32 then
    REG_DIVCNT^ := DIV_32_32;

  while (REG_DIVCNT^ and DIV_BUSY) <> 0 do;

  mod32 := REG_DIVREM_RESULT_L^;
end;

//  Integer divide
//  Takes a 64 bit numerator and 32 bit
//  denominator are returns 32 bit result
function div64(num: cint64; den: cint32): cint32; inline;
begin
  REG_DIV_NUMER^ := num;
  REG_DIV_DENOM_L^ := den;

  if (REG_DIVCNT^ and DIV_MODE_MASK) <> DIV_64_32 then
    REG_DIVCNT^ := DIV_64_32;

  while (REG_DIVCNT^ and DIV_BUSY) <> 0 do;

  div64 := REG_DIV_RESULT_L^;
end;

//  Integer divide
//  Takes a 64 bit numerator and 32 bit
//  denominator are returns 32 bit result
function mod64(num: cint64; den: cint32): cint32; inline;
begin
  REG_DIV_NUMER^ := num;
  REG_DIV_DENOM_L^ := den;

  if (REG_DIVCNT^ and DIV_MODE_MASK) <> DIV_64_32 then
    REG_DIVCNT^ := DIV_64_32;

  while (REG_DIVCNT^ and DIV_BUSY) <> 0 do;

  mod64 := REG_DIVREM_RESULT_L^;
end;

//  Integer square root
//  takes a 32 bit integer and returns
//  32 bit result
function sqrt32(a: cint32): cuint32; inline;
begin
  REG_SQRT_PARAM_L^ := a;

  if (REG_SQRTCNT^ and SQRT_MODE_MASK) <> SQRT_32 then
    REG_SQRTCNT^ := SQRT_32;

  while (REG_SQRTCNT^ and SQRT_BUSY) <> 0 do;

  sqrt32 := REG_SQRT_RESULT^;
end;

function sqrt64(a: cint64): cuint32; inline;
begin
  REG_SQRT_PARAM^ := a;

  if (REG_SQRTCNT^ and SQRT_MODE_MASK) <> SQRT_64 then
    REG_SQRTCNT^ := SQRT_64;

  while (REG_SQRTCNT^ and SQRT_BUSY) <> 0 do;

  sqrt64 := REG_SQRT_RESULT^;
end;

procedure crossf32(a: pcint32; b: pcint32; res: pcint32); inline;
begin
  res[0] := mulf32(a[1], b[2]) - mulf32(b[1], a[2]);
  res[1] := mulf32(a[2], b[0]) - mulf32(b[2], a[0]);
  res[2] := mulf32(a[0], b[1]) - mulf32(b[0], a[1]);
end;

function dotf32(a, b: pcint32): cint32; inline;
begin
  dotf32 := mulf32(a[0], b[0]) + mulf32(a[1], b[1]) + mulf32(a[2], b[2]);
end;

function _clz(a: uint32): uint32; assembler; nostackframe;
asm
  clz r0,a
  bx  lr
end;

function _clzll(a: uint64): uint32; inline;
begin
  Result := _clz(a shr 32);
  if Result = 32 then
    Result := 32 + _clz(uint32(a));
end;

function _dotv3lh(a: pcint32): uint64; assembler; nostackframe;
asm
  ldm   a,{a3,a4,ip}
  smull a1,a2,a3,a3
  smlal a1,a2,a4,a4
  smlal a1,a2,ip,ip
  bx    lr
end;

procedure normalizef32(a: pcint32);
var
  t, st, prod, i, totsh, sh, zc: cint32;
  root, mh: cuint32;
  msq: cuint64;
  rcp: cint64;
  rms: cuint32 absolute rcp;
begin
  msq := _dotv3lh(a);
  if msq <> 0 then
  begin
    zc := 33 - _clzll(msq);
    inc(zc);
    zc := zc and not(1);
    if zc >= 0 then
      msq := msq shr zc
    else
      msq := msq shl -zc;

    REG_DIV_NUMER^ := 1 shl 62;
    REG_DIV_DENOM_L^ := msq;
    if (REG_DIVCNT^ and DIV_MODE_MASK) <> DIV_64_32 then
      REG_DIVCNT^ := DIV_64_32;

    REG_SQRT_PARAM^ := msq shl 32;
    if (REG_SQRTCNT^ and SQRT_MODE_MASK) <> SQRT_64 then
      REG_SQRTCNT^ := SQRT_64;

    totsh := 32 + 8 - 6 + (zc shr 1);
    while (REG_SQRTCNT^ and SQRT_BUSY) <> 0 do;
    root := REG_SQRT_RESULT^;

    while (REG_DIVCNT^ and DIV_BUSY) <> 0 do;
    rcp := REG_DIV_RESULT^;

    sh := 32 - _clz(rms);
    dec(totsh, sh);
    rcp := rcp shr sh;
    mh := (cuint64(rcp) * root) shr 32;

    for i := 0 to 2 do
    begin
      t := a[i];
      st := t;
      if t < 0 then
        st := -st;

      prod := (cuint64(cuint32(st)) * mh) shr totsh;
      if t < 0 then
        prod := -prod;

      a[i] := prod;
    end;
  end;
end;
{$endif NDS_IMPLEMENTATION}

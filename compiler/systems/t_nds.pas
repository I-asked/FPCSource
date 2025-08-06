{
    This unit implements support import,export,link routines
    for the (arm) Nintendo DS target

    Copyright (c) 2001-2002 by Peter Vreman

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************
}
unit t_nds;

{$i fpcdefs.inc}

interface


implementation

    uses
       aasmbase,
       SysUtils,
       cutils,cfileutl,cclasses,
       globtype,globals,systems,verbose,cscript,fmodule,i_nds,link;

    type
       TlinkerNDS=class(texternallinker)
       private
          Function  WriteResponseFile: Boolean;
       public
          constructor Create; override;
          procedure SetDefaultInfo; override;
          function  MakeExecutable:boolean; override;
          procedure InitSysInitUnitName; override;
       end;



{*****************************************************************************
                                  TLINKERNDS
*****************************************************************************}

Constructor TLinkerNDS.Create;
begin
  Inherited Create;
  SharedLibFiles.doubles:=true;
  StaticLibFiles.doubles:=true;
end;


procedure TLinkerNDS.InitSysInitUnitName;
begin
  if not(apptype in [app_arm9,app_arm7]) then
    if current_module.islibrary then
      apptype:=app_arm7
    else
      apptype:=app_arm9;
end;


procedure TLinkerNDS.SetDefaultInfo;
begin
  with Info do
   begin
     ExeCmd[1]:='ld -g $OPT $DYNLINK $STATIC $GCSECTIONS $STRIP -L. -o $EXE -T $RES';
   end;
end;


Function TLinkerNDS.WriteResponseFile: Boolean;
Var
  linkres  : TLinkRes;
  i        : longint;
  HPath    : TCmdStrListItem;
  s,s1,s2  : TCmdStr;
  linklibc,
  linklibgcc : boolean;
  crtobj   : string[80];
  found1,
  found2   : boolean;
begin
  s:='';
  WriteResponseFile:=False;
  linklibc:=(SharedLibFiles.Find('c')<>nil);
  linklibgcc:=(SharedLibFiles.Find('gcc')<>nil);

	{ Open link.res file }
  LinkRes:=TLinkRes.Create(outputexedir+Info.ResName,true);

  { Write path to search libraries }
  HPath:=TCmdStrListItem(current_module.locallibrarysearchpath.First);
  while assigned(HPath) do
   begin
    s:=HPath.Str;
    if (cs_link_on_target in current_settings.globalswitches) then
     s:=ScriptFixFileName(s);
    LinkRes.Add('-L'+s);
    HPath:=TCmdStrListItem(HPath.Next);
   end;
  HPath:=TCmdStrListItem(LibrarySearchPath.First);
  while assigned(HPath) do
   begin
    s:=HPath.Str;
    if s<>'' then
     LinkRes.Add('SEARCH_DIR("'+s+'")');
    HPath:=TCmdStrListItem(HPath.Next);
   end;

  case apptype of
    app_arm9: crtobj:='ds_arm9_crt0.o';
    app_arm7: crtobj:='ds_arm7_crt0.o';
    else
      internalerror(2019050935);
  end;

  LinkRes.Add('INPUT (');

  { add objectfiles, start with crt0 always }
  if librarysearchpath.FindFile(crtobj,false,s) then
    LinkRes.AddFileName(s);

  { try to add crti and crtbegin if linking to C }
  if linklibc then
   begin
     if librarysearchpath.FindFile('crti.o',false,s) then
      LinkRes.AddFileName(s);
   end;
  if linklibgcc then
   begin
     if librarysearchpath.FindFile('crtbegin.o',false,s) then
       LinkRes.AddFileName(s);
   end;
  while not ObjectFiles.Empty do
   begin
    s:=ObjectFiles.GetFirst;
    if s<>'' then
     begin
      { vlink doesn't use SEARCH_DIR for object files }
      if not(cs_link_on_target in current_settings.globalswitches) then
       s:=FindObjectFile(s,'',false);
      LinkRes.AddFileName((maybequoted(s)));
     end;
   end;

  { Write staticlibraries }
  if not StaticLibFiles.Empty then
   begin
    { vlink doesn't need, and doesn't support GROUP }
    if (cs_link_on_target in current_settings.globalswitches) then
     begin
      LinkRes.Add(')');
      LinkRes.Add('GROUP(');
     end;
    while not StaticLibFiles.Empty do
     begin
      S:=StaticLibFiles.GetFirst;
      LinkRes.AddFileName((maybequoted(s)));
     end;
   end;

  if (cs_link_on_target in current_settings.globalswitches) then
   begin
    LinkRes.Add(')');

    { Write sharedlibraries like -l<lib>, also add the needed dynamic linker
      here to be sure that it gets linked this is needed for glibc2 systems (PFV) }
    linklibc:=false;
    linklibgcc:=false;
    while not SharedLibFiles.Empty do
     begin
      S:=SharedLibFiles.GetFirst;
      if s<>'c' then
       begin
        i:=Pos(target_info.sharedlibext,S);
        if i>0 then
         Delete(S,i,255);
        LinkRes.Add('-l'+s);
       end
      else
       begin
        LinkRes.Add('-l'+s);
        linklibc:=true;
        linklibgcc:=true;
       end;
     end;
    { be sure that libc&libgcc is the last lib }
    if linklibgcc then
     begin
      LinkRes.Add('-lgcc');
     end;
    if linklibc then
     begin
      LinkRes.Add('-lc');
     end;
   end
  else
   begin
    while not SharedLibFiles.Empty do
     begin
      S:=SharedLibFiles.GetFirst;
      LinkRes.Add('lib'+s+target_info.staticlibext);
     end;
    LinkRes.Add(')');
   end;

  { objects which must be at the end }
  if linklibgcc then
   begin
     found1:=librarysearchpath.FindFile('crtend.o',false,s1);
     if found1 then
      begin
        LinkRes.Add('INPUT(');
        if found1 then
         LinkRes.AddFileName(s1);
        LinkRes.Add(')');
      end;
   end;   
  if linklibc then
   begin
     found2:=librarysearchpath.FindFile('crtn.o',false,s2);
     if found2 then
      begin
        LinkRes.Add('INPUT(');
        if found2 then
         LinkRes.AddFileName(s2);
        LinkRes.Add(')');
      end;
   end;   
   
  with linkres do
    begin
      if apptype=app_arm9 then //ARM9
      begin
        add('/* SPDX-License-Identifier: MPL-2.0 */');
        add('');
        add('MEMORY {');
        add('	ewram	: ORIGIN = 0x02000000, LENGTH = 4M - 512k');
        add('	dtcm	: ORIGIN = 0x02ff0000, LENGTH = 16K');
        add('	itcm	: ORIGIN = 0x01000000, LENGTH = 32K');
        add('}');
        add('/* Copyright (C) 2014-2024 Free Software Foundation, Inc.');
        add('   Copying and distribution of this script, with or without modification,');
        add('   are permitted in any medium without royalty provided the copyright');
        add('   notice and this notice are preserved.  */');
        add('');
        add('/* SPDX-License-Identifier: MPL-2.0 AND FSFAP */');
        add('');
        add('OUTPUT_FORMAT("elf32-littlearm", "elf32-bigarm", "elf32-littlearm")');
        add('OUTPUT_ARCH(arm)');
        add('ENTRY(_start)');
        add('');
        add('/* User-configurable symbols. */');
        add('');
        add('/* DTCM data area size. */');
        add('/* If zero, DTCM data is placed at the beginning of the DTCM block, rather than the end. */');
        add('PROVIDE(__dtcm_data_size = 0);');
        add('ASSERT((__dtcm_data_size & 3) == 0, "__dtcm_data_size must be a multiple of 4");');
        add('');
        add('/* DLDI driver area size. */');
        add('PROVIDE(__dldi_size = 16384);');
        add('');
        add('/* The size, in bytes, of the reserved section at the end of DTCM. */');
        add('/* Traditionally, ARM9 reserves 0x40 bytes here. */');
        add('PROVIDE(__dtcm_reserved_size = 0x40);');
        add('ASSERT((__dtcm_reserved_size & 3) == 0, "__dtcm_reserved_size must be a multiple of 4");');
        add('');
        add('/* ARM supervisor (SWI calls) stack size. */');
        add('PROVIDE(__svc_stack_size = 0x100);');
        add('ASSERT((__svc_stack_size & 3) == 0, "__svc_stack_size must be a multiple of 4");');
        add('');
        add('/* ARM interrupt handler stack size. */');
        add('PROVIDE(__irq_stack_size = 0x100);');
        add('ASSERT((__irq_stack_size & 3) == 0, "__irq_stack_size must be a multiple of 4");');
        add('');
        add('/* ARM user stack size. Used only for stack smash validation at link time. */');
        add('PROVIDE(__usr_stack_size = 0);');
        add('ASSERT((__usr_stack_size & 3) == 0, "__usr_stack_size must be a multiple of 4");');
        add('');
        add('__ewram_end	=	ORIGIN(ewram) + LENGTH(ewram);');
        add('__eheap_end	=	ORIGIN(ewram) + LENGTH(ewram);');
        add('');
        add('__dtcm_start	=	ORIGIN(dtcm); /* Start of DTCM area. Must point to the beginning of DTCM memory. */');
        add('__dtcm_top	=	ORIGIN(dtcm) + LENGTH(dtcm); /* Top of DTCM area. */');
        add('__irq_flags	=	__dtcm_top - 0x08;');
        add('__irq_vector	=	__dtcm_top - 0x04;');
        add('');
        add('__sp_svc	=	__dtcm_top - __dtcm_reserved_size; /* Top of SVC mode stack. */');
        add('__sp_irq	=	__sp_svc - __svc_stack_size; /* Top of IRQ mode stack. */');
        add('__sp_usr	=	__sp_irq - __irq_stack_size - __dtcm_data_size; /* Top of user stack. */');
        add('');
        add('__dtcm_data_start = __dtcm_data_size > 0 ? __sp_usr : ORIGIN(dtcm); /* Start of DTCM data section. */');
        add('__dtcm_data_top = __dtcm_data_size > 0 ? __sp_irq - __irq_stack_size : __sp_usr - __usr_stack_size; /* Top of DTCM data section. */');
        add('');
        add('__dldi_log2_size = LOG2CEIL(__dldi_size + 1) - 1;');
        add('');
        add('PHDRS {');
        add('    main    PT_LOAD FLAGS(7);');
        add('    dtcm    PT_LOAD FLAGS(7);');
        add('    itcm    PT_LOAD FLAGS(7);');
        add('    twl     PT_LOAD FLAGS(0x100007); /* (DSi flag for ndstool | 7) */');
        add('}');
        add('');
        add('SECTIONS');
        add('{');
        add('    /* Secure area reserved space */');
        add('    .secure : { *(.secure) } >ewram :main = 0');
        add('');
        add('    .crt0	:');
        add('    {');
        add('        __text_start = . ;');
        add('        KEEP (*(.crt0))');
        add('        . = ALIGN(4);  /* REQUIRED. LD is flaky without it. */');
        add('    } >ewram :main = 0x00');
        add('');
        add('    /* Create DLDI driver area. It should be zero-byte if DLDI code');
        add('       is not present, but set to an user-provided size if it is');
        add('           present. */');
        add('    .dldi :');
        add('    {');
        add('        __dldi_start = .;');
        add('        *(.dldi)');
        add('        . = ALIGN(4);');
        add('');
        add('        __dldi_data_end = .;');
        add('        __dldi_end = __dldi_data_end > __dldi_start ? __dldi_start + __dldi_size : __dldi_start;');
        add('        . = __dldi_end;');
        add('        . = ALIGN(4);');
        add('    } >ewram :main = 0x00');
        add('');
        add('    .plt : { *(.plt) } >ewram :main = 0xff');
        add('');
        add('    .init :');
        add('    {');
        add('        KEEP (*(SORT_NONE(.init)))');
        add('    } >ewram :main');
        add('');
        add('    .text :   /* ALIGN (4): */');
        add('    {');
        add('        *(EXCLUDE_FILE(*.itcm* *.twl*) .text)');
        add('        *(EXCLUDE_FILE(*.itcm* *.twl*) .stub)');
        add('        *(EXCLUDE_FILE(*.itcm* *.twl*) .text.*)');
        add('        /* .gnu.warning sections are handled specially by elf32.em.  */');
        add('        *(EXCLUDE_FILE(*.twl*) .gnu.warning)');
        add('        *(EXCLUDE_FILE(*.twl*) .gnu.linkonce.t*)');
        add('        *(.glue_7)');
        add('        *(.glue_7t)');
        add('        . = ALIGN(4);  /* REQUIRED. LD is flaky without it. */');
        add('    } >ewram :main = 0xff');
        add('');
        add('    .fini           :');
        add('    {');
        add('        KEEP (*(.fini))');
        add('    } >ewram :main =0xff');
        add('');
        add('    __text_end = . ;');
        add('');
        add('    .rodata :');
        add('    {');
        add('        *(EXCLUDE_FILE(*.twl*) .rodata)');
        add('        *all.rodata*(*)');
        add('        *(EXCLUDE_FILE(*.twl*) .roda)');
        add('        *(EXCLUDE_FILE(*.twl*) .rodata.*)');
        add('        *(EXCLUDE_FILE(*.twl*) .gnu.linkonce.r*)');
        add('        SORT(CONSTRUCTORS)');
        add('        . = ALIGN(4);   /* REQUIRED. LD is flaky without it. */');
        add('    } >ewram :main = 0xff');
        add('');
        add('    .ARM.extab   : { *(.ARM.extab* .gnu.linkonce.armextab.*) } >ewram :main');
        add('     __exidx_start = .;');
        add('    ARM.exidx   : { *(.ARM.exidx* .gnu.linkonce.armexidx.*) } >ewram :main');
        add('     __exidx_end = .;');
        add('');
        add('    /* Ensure the __preinit_array_start label is properly aligned.  We');
        add('       could instead move the label definition inside the section, but');
        add('       the linker would then create the section even if it turns out to');
        add('       be empty, which isn''t pretty.  */');
        add('    . = ALIGN(32 / 8);');
        add('    .init_array :');
        add('    {');
        add('        PROVIDE (__preinit_array_start = .);');
        add('        PROVIDE (__bothinit_array_start = .);');
        add('        KEEP (*(.preinit_array))');
        add('        PROVIDE (__preinit_array_end = .);');
        add('');
        add('        PROVIDE (__init_array_start = .);');
        add('        KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))');
        add('        KEEP (*(.init_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .ctors))');
        add('        PROVIDE (__init_array_end = .);');
        add('        PROVIDE (__bothinit_array_end = .);');
        add('    } >ewram :main = 0xff');
        add('    .fini_array :');
        add('    {');
        add('        PROVIDE (__fini_array_start = .);');
        add('        KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))');
        add('        KEEP (*(.fini_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .dtors))');
        add('        /* Required by pico-exitprocs.c. */');
        add('        KEEP (*(.fini_array*))');
        add('        PROVIDE (__fini_array_end = .);');
        add('    } >ewram :main = 0xff');
        add('');
        add('    .ctors :');
        add('    {');
        add('        /* gcc uses crtbegin.o to find the start of');
        add('           the constructors, so we make sure it is');
        add('           first.  Because this is a wildcard, it');
        add('           doesn''t matter if the user does not');
        add('           actually link against crtbegin.o; the');
        add('           linker won''t look for a file to match a');
        add('           wildcard.  The wildcard also means that it');
        add('           doesn''t matter which directory crtbegin.o');
        add('           is in.  */');
        add('        KEEP (*crtbegin.o(.ctors))');
        add('        KEEP (*crtbegin?.o(.ctors))');
        add('        /* We don''t want to include the .ctor section from');
        add('           the crtend.o file until after the sorted ctors.');
        add('           The .ctor section from the crtend file contains the');
        add('           end of ctors marker and it must be last */');
        add('        KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .ctors))');
        add('        KEEP (*(SORT(.ctors.*)))');
        add('        KEEP (*(.ctors))');
        add('        . = ALIGN(4);   /* REQUIRED. LD is flaky without it. */');
        add('    } >ewram :main = 0xff');
        add('');
        add('    .dtors :');
        add('    {');
        add('        KEEP (*crtbegin.o(.dtors))');
        add('        KEEP (*crtbegin?.o(.dtors))');
        add('        KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .dtors))');
        add('        KEEP (*(SORT(.dtors.*)))');
        add('        KEEP (*(.dtors))');
        add('        . = ALIGN(4);   /* REQUIRED. LD is flaky without it. */');
        add('    } >ewram :main = 0xff');
        add('');
        add('    .eh_frame :');
        add('    {');
        add('        KEEP (*(.eh_frame))');
        add('        . = ALIGN(4);   /* REQUIRED. LD is flaky without it. */');
        add('    } >ewram :main = 0xff');
        add('');
        add('    .gcc_except_table :');
        add('    {');
        add('        *(.gcc_except_table .gcc_except_table.*)');
        add('        . = ALIGN(4);   /* REQUIRED. LD is flaky without it. */');
        add('    } >ewram :main = 0xff');
        add('    .got            : { *(.got.plt) *(.got) *(.rel.got) } >ewram :main = 0');
        add('');
        add('    .ewram ALIGN(4) : ');
        add('    {');
        add('        __ewram_start = ABSOLUTE(.);');
        add('        *(.ewram)');
        add('        *ewram.*(.text)');
        add('        . = ALIGN(4);   /* REQUIRED. LD is flaky without it. */');
        add('    } >ewram :main = 0xff');
        add('');
        add('    .data ALIGN(4) :');
        add('    {');
        add('        __data_start = ABSOLUTE(.);');
        add('        *(EXCLUDE_FILE(*.twl*) .data)');
        add('        *(EXCLUDE_FILE(*.twl*) .data.*)');
        add('        *(EXCLUDE_FILE(*.twl*) .gnu.linkonce.d*)');
        add('        CONSTRUCTORS');
        add('        . = ALIGN(4);');
        add('    } >ewram :main = 0xff');
        add('');
        add('    .tdata ALIGN(4) :');
        add('    {');
        add('        __tdata_start = ABSOLUTE(.);');
        add('        *(.tdata .tdata.* .gnu.linkonce.td.*)');
        add('        . = ALIGN(4);    /* REQUIRED. LD is flaky without it. */');
        add('        __tdata_end = ABSOLUTE(.);');
        add('        __data_end = . ;');
        add('    } >ewram :main = 0xff');
        add('');
        add('    __data_size = __data_end - __data_start;');
        add('    __data_source_size = __data_end - __data_start;');
        add('');
        add('    __tdata_size = __tdata_end - __tdata_start ;');
        add('');
        add('    .tbss ALIGN(4) :');
        add('    {');
        add('         __tbss_start = ABSOLUTE(.);');
        add('        *(.tbss .tbss.* .gnu.linkonce.tb.*)');
        add('        *(.tcommon)');
        add('        . = ALIGN(4);    /* REQUIRED. LD is flaky without it. */');
        add('         __tbss_end = ABSOLUTE(.);');
        add('    } >ewram :main = 0');
        add('');
        add('    __tbss_size = __tbss_end - __tbss_start ;');
        add('');
        add('    __bss_vma = . ;');
        add('');
        add('    .dtcm __dtcm_data_start :');
        add('    {');
        add('        __dtcm_lma = LOADADDR(.dtcm);');
        add('        *(.dtcm)');
        add('        *(.dtcm.*)');
        add('        . = ALIGN(4);');
        add('        __dtcm_end = ABSOLUTE(.);');
        add('    } >dtcm AT>ewram :dtcm = 0xff');
        add('');
        add('    .itcm :');
        add('    {');
        add('        __itcm_lma = LOADADDR(.itcm);');
        add('        __itcm_start = ABSOLUTE(.);');
        add('');
        add('        /* Vectors must be placed at the beginning of ITCM. */');
        add('        KEEP(*(.vectors .vectors.*))');
        add('');
        add('        *(.itcm)');
        add('        *(.itcm.*)');
        add('        *.itcm*(.text .stub .text.*)');
        add('        . = ALIGN(4);');
        add('        __itcm_end = ABSOLUTE(.);');
        add('    } >itcm AT>ewram :itcm = 0xff');
        add('');
        add('    .sbss __dtcm_end (NOLOAD): ');
        add('    {');
        add('        __sbss_start = ABSOLUTE(.);');
        add('        __sbss_start__ = ABSOLUTE(.);');
        add('        *(.sbss)');
        add('        *(.sbss.*)');
        add('        . = ALIGN(4);    /* REQUIRED. LD is flaky without it. */');
        add('        __sbss_end = ABSOLUTE(.);');
        add('    } >dtcm :NONE');
        add('');
        add('    .bss __bss_vma (NOLOAD): ');
        add('    {');
        add('        __bss_start = ABSOLUTE(.);');
        add('        __bss_start__ = ABSOLUTE(.);');
        add('        *(EXCLUDE_FILE(*.twl*) .dynbss)');
        add('        *(EXCLUDE_FILE(*.twl*) .gnu.linkonce.b*)');
        add('        *(EXCLUDE_FILE(*.twl*) .bss*)');
        add('        *(EXCLUDE_FILE(*.twl*) COMMON)');
        add('        . = ALIGN(4);    /* REQUIRED. LD is flaky without it. */');
        add('        __bss_end__ = ABSOLUTE(.);');
        add('    } >ewram :NONE');
        add('');
        add('    .noinit (NOLOAD):');
        add('    {');
        add('        __noinit_start = ABSOLUTE(.);');
        add('        *(EXCLUDE_FILE(*.twl*) .noinit)');
        add('        *(EXCLUDE_FILE(*.twl*) .noinit.*)');
        add('        *(EXCLUDE_FILE(*.twl*) .gnu.linkonce.n.*)');
        add('        . = ALIGN(4);    /* REQUIRED. LD is flaky without it. */');
        add('        __noinit_end = ABSOLUTE(.);');
        add('    } >ewram :NONE');
        add('');
        add('    /* Space reserved for the thread local storage of main() */');
        add('    .tls ALIGN(4) (NOLOAD) :');
        add('    {');
        add('        __tls_start = ABSOLUTE(.);');
        add('        . = . + __tdata_size + __tbss_size;');
        add('         __tls_end = ABSOLUTE(.);');
        add('        __end__ = ABSOLUTE(.);');
        add('    } >ewram :NONE');
        add('');
        add('    __tls_size = __tls_end - __tls_start ;');
        add('');
        add('    .twl __end__ : AT(MAX(0x2400000,__end__))');
        add('    {');
        add('        __arm9i_lma__ = LOADADDR(.twl);');
        add('        __arm9i_start__ = ABSOLUTE(.);');
        add('        *(.twl)');
        add('        *(.twl.text .twl.text.*)');
        add('        *(.twl.rodata .twl.rodata.*)');
        add('        *(.twl.data .twl.data.*)');
        add('        *.twl*(.text .stub .text.* .gnu.linkonce.t.*)');
        add('        *.twl*(.rodata)');
        add('        *.twl*(.roda)');
        add('        *.twl*(.rodata.*)');
        add('        *.twl*(.data)');
        add('        *.twl*(.data.*)');
        add('        *.twl*(.gnu.linkonce.d*)');
        add('        __arm9i_end__ = ABSOLUTE(.);');
        add('    } :twl');
        add('');
        add('    .twl_bss __arm9i_end__ (NOLOAD):');
        add('    {');
        add('        __twl_bss_start__ = ABSOLUTE(.);');
        add('        *(.twl_bss .twl_bss.*)');
        add('        *(.twl.bss .twl.bss.*)');
        add('        *.twl*(.dynbss)');
        add('        *.twl*(.gnu.linkonce.b*)');
        add('        *.twl*(.bss*)');
        add('        *.twl*(COMMON)');
        add('        . = ALIGN(4);    /* REQUIRED. LD is flaky without it. */');
        add('        __twl_bss_end__ = ABSOLUTE(.);');
        add('    } :NONE');
        add('');
        add('    .twl_noinit __twl_bss_end__ (NOLOAD):');
        add('    {');
        add('        __twl_noinit_start__ = ABSOLUTE(.);');
        add('        *(.twl_noinit .twl_noinit.*)');
        add('        *(.twl.noinit .twl.noinit.*)');
        add('        *.twl*(.noinit)');
        add('        *.twl*(.noinit.*)');
        add('        *.twl*(.gnu.linkonce.n.*)');
        add('        . = ALIGN(4);    /* REQUIRED. LD is flaky without it. */');
        add('        __twl_noinit_end__ = ABSOLUTE(.);');
        add('        __twl_end__ = ABSOLUTE(.);');
        add('    } :NONE');
        add('');
        add('    HIDDEN(__itcm_size = __itcm_end - __itcm_start);');
        add('    HIDDEN(__dtcm_size = __dtcm_end - __dtcm_data_start);');
        add('    HIDDEN(__arm9i_size__ = __arm9i_end__ - __arm9i_start__);');
        add('    HIDDEN(__bss_size__ = __bss_end__ - __bss_start__);');
        add('    HIDDEN(__sbss_size = __sbss_end - __sbss_start);');
        add('    HIDDEN(__twl_bss_size__ = __twl_bss_end__ - __twl_bss_start__);');
        add('');
        add('    /* Stabs debugging sections.  */');
        add('    .stab          0 : { *(.stab) }');
        add('    .stabstr       0 : { *(.stabstr) }');
        add('    .stab.excl     0 : { *(.stab.excl) }');
        add('    .stab.exclstr  0 : { *(.stab.exclstr) }');
        add('    .stab.index    0 : { *(.stab.index) }');
        add('    .stab.indexstr 0 : { *(.stab.indexstr) }');
        add('    .comment 0 (INFO) : { *(.comment); LINKER_VERSION; }');
        add('    .gnu.build.attributes : { *(.gnu.build.attributes .gnu.build.attributes.*) }');
        add('    /* DWARF debug sections.');
        add('       Symbols in the DWARF debugging sections are relative to the beginning');
        add('       of the section so we begin them at 0.  */');
        add('    /* DWARF 1.  */');
        add('    .debug          0 : { *(.debug) }');
        add('    .line           0 : { *(.line) }');
        add('    /* GNU DWARF 1 extensions.  */');
        add('    .debug_srcinfo  0 : { *(.debug_srcinfo) }');
        add('    .debug_sfnames  0 : { *(.debug_sfnames) }');
        add('    /* DWARF 1.1 and DWARF 2.  */');
        add('    .debug_aranges  0 : { *(.debug_aranges) }');
        add('    .debug_pubnames 0 : { *(.debug_pubnames) }');
        add('    /* DWARF 2.  */');
        add('    .debug_info     0 : { *(.debug_info .gnu.linkonce.wi.*) }');
        add('    .debug_abbrev   0 : { *(.debug_abbrev) }');
        add('    .debug_line     0 : { *(.debug_line .debug_line.* .debug_line_end) }');
        add('    .debug_frame    0 : { *(.debug_frame) }');
        add('    .debug_str      0 : { *(.debug_str) }');
        add('    .debug_loc      0 : { *(.debug_loc) }');
        add('    .debug_macinfo  0 : { *(.debug_macinfo) }');
        add('    /* SGI/MIPS DWARF 2 extensions.  */');
        add('    .debug_weaknames 0 : { *(.debug_weaknames) }');
        add('    .debug_funcnames 0 : { *(.debug_funcnames) }');
        add('    .debug_typenames 0 : { *(.debug_typenames) }');
        add('    .debug_varnames  0 : { *(.debug_varnames) }');
        add('    /* DWARF 3.  */');
        add('    .debug_pubtypes 0 : { *(.debug_pubtypes) }');
        add('    .debug_ranges   0 : { *(.debug_ranges) }');
        add('    /* DWARF 5.  */');
        add('    .debug_addr     0 : { *(.debug_addr) }');
        add('    .debug_line_str 0 : { *(.debug_line_str) }');
        add('    .debug_loclists 0 : { *(.debug_loclists) }');
        add('    .debug_macro    0 : { *(.debug_macro) }');
        add('    .debug_names    0 : { *(.debug_names) }');
        add('    .debug_rnglists 0 : { *(.debug_rnglists) }');
        add('    .debug_str_offsets 0 : { *(.debug_str_offsets) }');
        add('    .debug_sup      0 : { *(.debug_sup) }');
        add('    .ARM.attributes 0 : { KEEP (*(.ARM.attributes)) KEEP (*(.gnu.attributes)) }');
        add('    .note.gnu.arm.ident 0 : { KEEP (*(.note.gnu.arm.ident)) }');
        add('    /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu.lto_*) }');
        add('}');
        add('');
        add('ASSERT(__sbss_end <= __dtcm_data_top, "DTCM data overflow; increase __dtcm_data_size or move data out of DTCM");');
      end
      else if apptype=app_arm7 then
      begin
        add('/* Copyright (C) 2014-2024 Free Software Foundation, Inc.');
        add('   Copying and distribution of this script, with or without modification,');
        add('   are permitted in any medium without royalty provided the copyright');
        add('   notice and this notice are preserved.  */');
        add('');
        add('/* SPDX-License-Identifier: MPL-2.0 AND FSFAP */');
        add('');
        add('OUTPUT_FORMAT("elf32-littlearm", "elf32-bigarm", "elf32-littlearm")');
        add('OUTPUT_ARCH(arm)');
        add('ENTRY(_start)');
        add('');
        add('/* User-configurable symbols. */');
        add('');
        add('/* The size, in bytes, of the amount of shared WRAM used by ARM7 code. */');
        add('/* Only 0 and 32768 are valid values. */');
        add('PROVIDE(__shared_wram_size = 32768);');
        add('ASSERT(__shared_wram_size == 0 || __shared_wram_size == 32768, "ARM7 shared WRAM size must be 0 KB or 32 KB");');
        add('');
        add('/* The size, in bytes, of the reserved section at the end of IWRAM. */');
        add('/* Traditionally, ARM7 reserves 0x40 bytes here. */');
        add('PROVIDE(__iwram_reserved_size = 0x40);');
        add('ASSERT((__iwram_reserved_size & 3) == 0, "__iwram_reserved_size must be a multiple of 4");');
        add('');
        add('/* ARM supervisor (SWI calls) stack size. */');
        add('PROVIDE(__svc_stack_size = 0x100);');
        add('ASSERT((__svc_stack_size & 3) == 0, "__svc_stack_size must be a multiple of 4");');
        add('');
        add('/* ARM interrupt handler stack size. */');
        add('PROVIDE(__irq_stack_size = 0x100);');
        add('ASSERT((__irq_stack_size & 3) == 0, "__irq_stack_size must be a multiple of 4");');
        add('');
        add('PHDRS {');
        add('    crt0  PT_LOAD FLAGS(7);');
        add('    arm7  PT_LOAD FLAGS(7);');
        add('    arm7i PT_LOAD FLAGS(0x100007); /* (DSi flag for ndstool | 7) */');
        add('}');
        add('');
        add('MEMORY {');
        add('    ewram : ORIGIN = 0x02380000, LENGTH = 12M - 512K');
        add('    iwram : ORIGIN = 0x03800000 - __shared_wram_size, LENGTH = 65536 + __shared_wram_size');
        add('');
        add('    twl_ewram : ORIGIN = 0x02e80000, LENGTH = 512K - 64K');
        add('    twl_iwram : ORIGIN = 0x03000000, LENGTH = 256K');
        add('}');
        add('');
        add('__iwram_start	=	ORIGIN(iwram);');
        add('__iwram_top	=	ORIGIN(iwram) + LENGTH(iwram);');
        add('');
        add('__sp_irq	=	__iwram_top - __iwram_reserved_size;');
        add('__sp_svc	=	__sp_irq - __irq_stack_size;');
        add('__sp_usr	=	__sp_svc - __svc_stack_size;');
        add('');
        add('__irq_flags	=	0x04000000 - 8;');
        add('__irq_flagsaux	=	0x04000000 - 0x40;');
        add('__irq_vector	=	0x04000000 - 4;');
        add('');
        add('SECTIONS');
        add('{');
        add('');
        add('    .twl :');
        add('    {');
        add('        __arm7i_lma__ = LOADADDR(.twl);');
        add('        __arm7i_start__ = .;');
        add('        *(.twl)');
        add('        *(.twl.text .twl.text.*)');
        add('        *(.twl.rodata .twl.rodata.*)');
        add('        *(.twl.data .twl.data.*)');
        add('        *.twl*(.text .stub .text.* .gnu.linkonce.t.*)');
        add('        *.twl*(.rodata)');
        add('        *.twl*(.roda)');
        add('        *.twl*(.rodata.*)');
        add('        *.twl*(.data)');
        add('        *.twl*(.data.*)');
        add('        *.twl*(.gnu.linkonce.d*)');
        add('        . = ALIGN(4);');
        add('        __arm7i_end__ = .;');
        add('    } >twl_iwram AT>twl_ewram :arm7i');
        add('');
        add('    .twl_bss ALIGN(4) (NOLOAD) :');
        add('    {');
        add('        __twl_bss_start__ = .;');
        add('        *(.twl_bss .twl_bss.*)');
        add('        *(.twl.bss .twl.bss.*)');
        add('        *.twl.*(.dynbss)');
        add('        *.twl.*(.gnu.linkonce.b*)');
        add('        *.twl.*(.bss*)');
        add('        *.twl.*(COMMON)');
        add('        . = ALIGN(4);');
        add('        __twl_bss_end__ = .;');
        add('    } >twl_iwram :NONE');
        add('');
        add('    .twl_noinit ALIGN(4) (NOLOAD):');
        add('    {');
        add('        __twl_noinit_start__ = ABSOLUTE(.);');
        add('        *(.twl_noinit .twl_noinit.*)');
        add('        *(.twl.noinit .twl.noinit.*)');
        add('        *.twl*(.noinit)');
        add('        *.twl*(.noinit.*)');
        add('        *.twl*(.gnu.linkonce.n.*)');
        add('        . = ALIGN(4);    /* REQUIRED. LD is flaky without it. */');
        add('        __twl_noinit_end__ = ABSOLUTE(.);');
        add('        __twl_end__ = ABSOLUTE(.);');
        add('    } >twl_iwram :NONE');
        add('');
        add('    .crt0	:');
        add('    {');
        add('        KEEP (*(.crt0))');
        add('        . = ALIGN(4);  /* REQUIRED. LD is flaky without it. */');
        add('    } >ewram :crt0');
        add('');
        add('    .text :');
        add('    {');
        add('        __arm7_lma__ = LOADADDR(.text);');
        add('        __arm7_start__ = .;');
        add('        KEEP (*(SORT_NONE(.init)))');
        add('        *(.plt)');
        add('        *(.text .stub .text.* .gnu.linkonce.t.*)');
        add('        KEEP (*(.text.*personality*))');
        add('        /* .gnu.warning sections are handled specially by elf32.em.  */');
        add('        *(.gnu.warning)');
        add('        *(.glue_7t) *(.glue_7) *(.v4_bx)');
        add('        . = ALIGN(4);  /* REQUIRED. LD is flaky without it. */');
        add('    } >iwram AT>ewram :arm7');
        add('');
        add('    .fini           :');
        add('    {');
        add('        KEEP (*(.fini))');
        add('    } >iwram AT>ewram');
        add('');
        add('    .rodata :');
        add('    {');
        add('        *(.rodata)');
        add('        *all.rodata*(*)');
        add('        *(.roda)');
        add('        *(.rodata.*)');
        add('        *(.gnu.linkonce.r*)');
        add('        SORT(CONSTRUCTORS)');
        add('        . = ALIGN(4);   /* REQUIRED. LD is flaky without it. */');
        add('    } >iwram AT>ewram');
        add('');
        add('    .ARM.extab   : { *(.ARM.extab* .gnu.linkonce.armextab.*) } >iwram AT>ewram');
        add('');
        add('    .ARM.exidx   : {');
        add('        __exidx_start = .;');
        add('        *(.ARM.exidx* .gnu.linkonce.armexidx.*)');
        add('        __exidx_end = .;');
        add('     } >iwram AT>ewram');
        add('');
        add('    /* Ensure the __preinit_array_start label is properly aligned.  We');
        add('       could instead move the label definition inside the section, but');
        add('       the linker would then create the section even if it turns out to');
        add('       be empty, which isn''t pretty.  */');
        add('    . = ALIGN(32 / 8);');
        add('    .init_array :');
        add('    {');
        add('        PROVIDE (__preinit_array_start = .);');
        add('        PROVIDE (__bothinit_array_start = .);');
        add('        KEEP (*(.preinit_array))');
        add('        PROVIDE (__preinit_array_end = .);');
        add('');
        add('        PROVIDE (__init_array_start = .);');
        add('        KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))');
        add('        KEEP (*(.init_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .ctors))');
        add('        PROVIDE (__init_array_end = .);');
        add('        PROVIDE (__bothinit_array_end = .);');
        add('    } >iwram AT>ewram');
        add('    .fini_array :');
        add('    {');
        add('        PROVIDE (__fini_array_start = .);');
        add('        KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))');
        add('        KEEP (*(.fini_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .dtors))');
        add('        /* Required by pico-exitprocs.c. */');
        add('        KEEP (*(.fini_array*))');
        add('        PROVIDE (__fini_array_end = .);');
        add('    } >iwram AT>ewram');
        add('');
        add('    .ctors :');
        add('    {');
        add('        /* gcc uses crtbegin.o to find the start of');
        add('           the constructors, so we make sure it is');
        add('           first.  Because this is a wildcard, it');
        add('           doesn''t matter if the user does not');
        add('           actually link against crtbegin.o; the');
        add('           linker won''t look for a file to match a');
        add('           wildcard.  The wildcard also means that it');
        add('           doesn''t matter which directory crtbegin.o');
        add('           is in.  */');
        add('        KEEP (*crtbegin.o(.ctors))');
        add('        KEEP (*crtbegin?.o(.ctors))');
        add('        /* We don''t want to include the .ctor section from');
        add('           the crtend.o file until after the sorted ctors.');
        add('           The .ctor section from the crtend file contains the');
        add('           end of ctors marker and it must be last */');
        add('        KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .ctors))');
        add('        KEEP (*(SORT(.ctors.*)))');
        add('        KEEP (*(.ctors))');
        add('        . = ALIGN(4);   /* REQUIRED. LD is flaky without it. */');
        add('    } >iwram AT>ewram');
        add('');
        add('    .dtors :');
        add('    {');
        add('        KEEP (*crtbegin.o(.dtors))');
        add('        KEEP (*crtbegin?.o(.dtors))');
        add('        KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .dtors))');
        add('        KEEP (*(SORT(.dtors.*)))');
        add('        KEEP (*(.dtors))');
        add('        . = ALIGN(4);   /* REQUIRED. LD is flaky without it. */');
        add('    } >iwram AT>ewram');
        add('');
        add('    .eh_frame :');
        add('    {');
        add('        KEEP (*(.eh_frame))');
        add('        . = ALIGN(4);   /* REQUIRED. LD is flaky without it. */');
        add('    } >iwram AT>ewram');
        add('');
        add('    .gcc_except_table :');
        add('    {');
        add('        *(.gcc_except_table .gcc_except_table.*)');
        add('        . = ALIGN(4);   /* REQUIRED. LD is flaky without it. */');
        add('    } >iwram AT>ewram');
        add('    .got            : { *(.got.plt) *(.got) } >iwram AT>ewram');
        add('');
        add('    .data ALIGN(4) : 	{');
        add('        __data_start = ABSOLUTE(.);');
        add('        *(.data)');
        add('        *(.data.*)');
        add('        *(.gnu.linkonce.d*)');
        add('        CONSTRUCTORS');
        add('        . = ALIGN(4);');
        add('    } >iwram AT>ewram');
        add('');
        add('    .tdata ALIGN(4) :');
        add('    {');
        add('        __tdata_start = ABSOLUTE(.);');
        add('        *(.tdata .tdata.* .gnu.linkonce.td.*)');
        add('        . = ALIGN(4);    /* REQUIRED. LD is flaky without it. */');
        add('        __tdata_end = ABSOLUTE(.);');
        add('        __data_end = . ;');
        add('    } >iwram AT>ewram');
        add('');
        add('    __data_size = __data_end - __data_start;');
        add('    __data_source_size = __data_end - __data_start;');
        add('');
        add('    __data_size = __data_end - __data_start ;');
        add('    __data_source_size = __data_end - __data_start ;');
        add('    __tdata_size = __tdata_end - __tdata_start ;');
        add('');
        add('    .tbss ALIGN(4) (NOLOAD) :');
        add('    {');
        add('         __tbss_start = ABSOLUTE(.);');
        add('        *(.tbss .tbss.* .gnu.linkonce.tb.*)');
        add('        *(.tcommon)');
        add('        . = ALIGN(4);    /* REQUIRED. LD is flaky without it. */');
        add('         __tbss_end = ABSOLUTE(.);');
        add('    } >iwram AT>ewram');
        add('');
        add('    __tbss_size = __tbss_end - __tbss_start ;');
        add('');
        add('    .bss ALIGN(4) (NOLOAD) :');
        add('    {');
        add('        __arm7_end__ = .;');
        add('        __bss_start = ABSOLUTE(.);');
        add('        __bss_start__ = ABSOLUTE(.);');
        add('        *(.dynbss)');
        add('        *(.gnu.linkonce.b*)');
        add('        *(.bss*)');
        add('        *(COMMON)');
        add('        . = ALIGN(4);    /* REQUIRED. LD is flaky without it. */');
        add('        __bss_end__ = ABSOLUTE(.);');
        add('    } >iwram');
        add('');
        add('    .noinit (NOLOAD):');
        add('    {');
        add('        __noinit_start = ABSOLUTE(.);');
        add('        *(.noinit .noinit.* .gnu.linkonce.n.*)');
        add('        . = ALIGN(4);    /* REQUIRED. LD is flaky without it. */');
        add('        __noinit_end = ABSOLUTE(.);');
        add('    } >iwram');
        add('');
        add('    /* Space reserved for the thread local storage of main() */');
        add('    .tls ALIGN(4) (NOLOAD) :');
        add('    {');
        add('        __tls_start = ABSOLUTE(.);');
        add('        . = . + __tdata_size + __tbss_size;');
        add('         __tls_end = ABSOLUTE(.);');
        add('        __end__ = ABSOLUTE(.);');
        add('    } >iwram');
        add('');
        add('    __tls_size = __tls_end - __tls_start;');
        add('    ');
        add('    HIDDEN(__arm7_size__ = __arm7_end__ - __arm7_start__);');
        add('    HIDDEN(__arm7i_size__ = __arm7i_end__ - __arm7i_start__);');
        add('    HIDDEN(__bss_size__ = __bss_end__ - __bss_start__);');
        add('    HIDDEN(__twl_bss_size__ = __twl_bss_end__ - __twl_bss_start__);');
        add('');
        add('    /* Stabs debugging sections.  */');
        add('    .stab          0 : { *(.stab) }');
        add('    .stabstr       0 : { *(.stabstr) }');
        add('    .stab.excl     0 : { *(.stab.excl) }');
        add('    .stab.exclstr  0 : { *(.stab.exclstr) }');
        add('    .stab.index    0 : { *(.stab.index) }');
        add('    .stab.indexstr 0 : { *(.stab.indexstr) }');
        add('    .comment 0 (INFO) : { *(.comment); LINKER_VERSION; }');
        add('    .gnu.build.attributes : { *(.gnu.build.attributes .gnu.build.attributes.*) }');
        add('    /* DWARF debug sections.');
        add('       Symbols in the DWARF debugging sections are relative to the beginning');
        add('       of the section so we begin them at 0.  */');
        add('    /* DWARF 1.  */');
        add('    .debug          0 : { *(.debug) }');
        add('    .line           0 : { *(.line) }');
        add('    /* GNU DWARF 1 extensions.  */');
        add('    .debug_srcinfo  0 : { *(.debug_srcinfo) }');
        add('    .debug_sfnames  0 : { *(.debug_sfnames) }');
        add('    /* DWARF 1.1 and DWARF 2.  */');
        add('    .debug_aranges  0 : { *(.debug_aranges) }');
        add('    .debug_pubnames 0 : { *(.debug_pubnames) }');
        add('    /* DWARF 2.  */');
        add('    .debug_info     0 : { *(.debug_info .gnu.linkonce.wi.*) }');
        add('    .debug_abbrev   0 : { *(.debug_abbrev) }');
        add('    .debug_line     0 : { *(.debug_line .debug_line.* .debug_line_end) }');
        add('    .debug_frame    0 : { *(.debug_frame) }');
        add('    .debug_str      0 : { *(.debug_str) }');
        add('    .debug_loc      0 : { *(.debug_loc) }');
        add('    .debug_macinfo  0 : { *(.debug_macinfo) }');
        add('    /* SGI/MIPS DWARF 2 extensions.  */');
        add('    .debug_weaknames 0 : { *(.debug_weaknames) }');
        add('    .debug_funcnames 0 : { *(.debug_funcnames) }');
        add('    .debug_typenames 0 : { *(.debug_typenames) }');
        add('    .debug_varnames  0 : { *(.debug_varnames) }');
        add('    /* DWARF 3.  */');
        add('    .debug_pubtypes 0 : { *(.debug_pubtypes) }');
        add('    .debug_ranges   0 : { *(.debug_ranges) }');
        add('    /* DWARF 5.  */');
        add('    .debug_addr     0 : { *(.debug_addr) }');
        add('    .debug_line_str 0 : { *(.debug_line_str) }');
        add('    .debug_loclists 0 : { *(.debug_loclists) }');
        add('    .debug_macro    0 : { *(.debug_macro) }');
        add('    .debug_names    0 : { *(.debug_names) }');
        add('    .debug_rnglists 0 : { *(.debug_rnglists) }');
        add('    .debug_str_offsets 0 : { *(.debug_str_offsets) }');
        add('    .debug_sup      0 : { *(.debug_sup) }');
        add('    .ARM.attributes 0 : { KEEP (*(.ARM.attributes)) KEEP (*(.gnu.attributes)) }');
        add('    .note.gnu.arm.ident 0 : { KEEP (*(.note.gnu.arm.ident)) }');
        add('    /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu.lto_*) }');
        add('}');
      end;
    end;

{ Write and Close response }
  linkres.writetodisk;
  linkres.free;

  WriteResponseFile:=True;

end;


function TLinkerNDS.MakeExecutable:boolean;
var
  binstr,
  cmdstr  : TCmdStr;
  success : boolean;
  StaticStr,
  GCSectionsStr,
  DynLinkStr,
  MapStr,
  StripStr: string;
begin
  { for future use }
  StaticStr:='';
  StripStr:='';
  MapStr:='';
  DynLinkStr:='';
  GCSectionsStr:='';

  if (cs_link_strip in current_settings.globalswitches) and
     not(cs_link_separate_dbg_file in current_settings.globalswitches) then
   StripStr:='-s';
  if (cs_link_map in current_settings.globalswitches) then
   StripStr:='-Map '+maybequoted(ChangeFileExt(current_module.exefilename,'.map'));
  if create_smartlink_sections then
   GCSectionsStr:='--gc-sections';
  if not(cs_link_nolink in current_settings.globalswitches) then
   Message1(exec_i_linking,current_module.exefilename);

{ Write used files and libraries }
  WriteResponseFile();

{ Call linker }
  SplitBinCmd(Info.ExeCmd[1],binstr,cmdstr);
  Replace(cmdstr,'$OPT',Info.ExtraOptions);

  Replace(cmdstr,'$EXE',(maybequoted(ScriptFixFileName(ChangeFileExt(current_module.exefilename,'.elf')))));
  Replace(cmdstr,'$RES',(maybequoted(ScriptFixFileName(outputexedir+Info.ResName))));
  Replace(cmdstr,'$STATIC',StaticStr);
  Replace(cmdstr,'$STRIP',StripStr);
  Replace(cmdstr,'$GCSECTIONS',GCSectionsStr);
  Replace(cmdstr,'$MAP',MapStr);
  Replace(cmdstr,'$DYNLINK',DynLinkStr);

  success:=DoExec(FindUtil(utilsprefix+BinStr),cmdstr,true,false);

{ Remove ReponseFile }
  if (success) and not(cs_link_nolink in current_settings.globalswitches) then
   DeleteFile(outputexedir+Info.ResName);

{ Post process }
  if success and (apptype=app_arm9) then
    begin
      success:=DoExec(FindUtil('ndstool'), '-c ' + 
        ChangeFileExt(current_module.exefilename,'.nds') + ' -9 ' + 
        ChangeFileExt(current_module.exefilename,'.elf'),
        true,false);
    end;
  MakeExecutable:=success;   { otherwise a recursive call to link method }
end;


{*****************************************************************************
                                     Initialize
*****************************************************************************}

initialization
  RegisterLinker(ld_nds,TLinkerNDS);
  RegisterTarget(system_arm_nds_info);
end.

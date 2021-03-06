/**
 * This module tells the garbage collector about the static data and bss segments,
 * so the GC can scan them for roots. It does not deal with thread local static data.
 *
 * Copyright: Copyright Digital Mars 2000 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC src/rt/_memory.d)
 */

/*          Copyright Digital Mars 2000 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

/* NOTE: This file has been patched from the original DMD distribution to
   work with the GDC compiler.
*/
module rt.memory;


private
{
    version( GNU )
    {
        import gcc.builtins;

        version( GC_Use_Data_Proc_Maps )
        {
            import rt.gccmemory;
        }
    }
    extern (C) void gc_addRange( void* p, size_t sz );
    extern (C) void gc_removeRange( void* p );

    version( MinGW )
    {
        extern (C)
        {
            extern __gshared
            {
                version (X86_64)
                {
                    /* These symbols are defined in the linker script and have
                       not been updated to use Win64 ABI. So alias to the 
                       correct symbol.*/
                    int __data_start__;
                    int __data_end__;
                    int __bss_start__;
                    int __bss_end__;

                    alias __data_start__ _data_start__;
                    alias __data_end__   _data_end__;
                    alias __bss_start__  _bss_start__;
                    alias __bss_end__    _bss_end__;
                } else {
                    int _data_start__;
                    int _data_end__;
                    int _bss_start__;
                    int _bss_end__;
                }        
            }
        }
    }
    else version( Win32 )
    {
        extern (C)
        {
            extern __gshared
            {
                int _xi_a;   // &_xi_a just happens to be start of data segment
                int _edata;  // &_edata is start of BSS segment
                int _end;    // &_end is past end of BSS
            }
        }
    }
    else version( Win64 )
    {
        extern (C)
        {
            extern __gshared
            {
                int __xc_a;      // &__xc_a just happens to be start of data segment
                //int _edata;    // &_edata is start of BSS segment
                void* _deh_beg;  // &_deh_beg is past end of BSS
            }
        }
    }
    else version( linux )
    {
        extern (C)
        {
            extern __gshared
            {
                int __data_start;
                int end;
            }
        }
    }
    else version( OSX )
    {
        extern (C) void _d_osx_image_init();
    }
    else version( FreeBSD )
    {
        extern (C)
        {
            extern __gshared
            {
                size_t etext;
                size_t _end;
            }
        }
        version (X86_64)
        {
            extern (C)
            {
                extern __gshared
                {
                    size_t _deh_end;
                    size_t __progname;
                }
            }
        }
    }
    else version( Solaris )
    {
        extern (C)
        {
            extern __gshared
            {
                int __dso_handle;
                int _end;
            }
        }
    }
}


void initStaticDataGC()
{
    version( MinGW )
    {
        gc_addRange( &_data_start__, cast(size_t) &_bss_end__ - cast(size_t) &_data_start__ );
    }
    else version( Win32 )
    {
        gc_addRange( &_xi_a, cast(size_t) &_end - cast(size_t) &_xi_a );
    }
    else version( Win64 )
    {
        gc_addRange( &__xc_a, cast(size_t) &_deh_beg - cast(size_t) &__xc_a );
    }
    else version( linux )
    {
        gc_addRange( &__data_start, cast(size_t) &end - cast(size_t) &__data_start );
    }
    else version( OSX )
    {
        _d_osx_image_init();
    }
    else version( FreeBSD )
    {
        version (X86_64)
        {
            gc_addRange( &etext, cast(size_t) &_deh_end - cast(size_t) &etext );
            gc_addRange( &__progname, cast(size_t) &_end - cast(size_t) &__progname );
        }
        else
        {
            gc_addRange( &etext, cast(size_t) &_end - cast(size_t) &etext );
        }
    }
    else version( Solaris )
    {
        gc_addRange(&__dso_handle, cast(size_t)&_end - cast(size_t)&__dso_handle);
    }
    else
    {
        static assert( false, "Operating system not supported." );
    }

    version( GC_Use_Data_Proc_Maps )
    {
        version( linux )
        {
            scanDataProcMaps( &__data_start, &_end );
        }
        else version( FreeBSD )
        {
            version (X86_64)
            {
                scanDataProcMaps( &etext, &_deh_end );
                scanDataProcMaps( &__progname, &_end );
            }
            else
            {
                scanDataProcMaps( &etext, &_end );
            }
        }
        else version( Solaris )
        {
            scanDataProcMaps( &etext, &_end );
        }
        else
        {
            static assert( false, "Operating system not supported." );
        }
    }
}

/**
 * TypeInfo support code.
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.typeinfo.ti_ubyte;

// ubyte

class TypeInfo_h : TypeInfo
{
    override to_string_t toString() 
    {
      version(NOGCSAFE)
        return to_string_t("ubyte");
      else
        return "ubyte"; 
    }
    @trusted:
    const:
    pure:
    nothrow:

    override size_t getHash(in void* p)
    {
        return *cast(ubyte *)p;
    }

    override bool equals(in void* p1, in void* p2)
    {
        return *cast(ubyte *)p1 == *cast(ubyte *)p2;
    }

    override int compare(in void* p1, in void* p2)
    {
        return *cast(ubyte *)p1 - *cast(ubyte *)p2;
    }

    override @property size_t tsize() nothrow pure
    {
        return ubyte.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        ubyte t;

        t = *cast(ubyte *)p1;
        *cast(ubyte *)p1 = *cast(ubyte *)p2;
        *cast(ubyte *)p2 = t;
    }

    @property override Type type() nothrow pure { return Type.UByte; }
}

class TypeInfo_b : TypeInfo_h
{
    override to_string_t toString() 
    {
      version(NOGCSAFE)
        return to_string_t("bool");
      else
        return "bool"; 
    }

    @property override Type type() nothrow pure { return Type.Bool; }
}

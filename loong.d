import std.stdio;

version (unittest) void main()
{
}
else void main()
{
    auto z = ulonger!2(2, 1); z.writeln();
    auto zz = ulonger!3(z, ulonger!2(1, 2)); zz.writeln();
    auto zzz = ulonger!4(zz, ulonger!3(ulonger!2(1, 2), z)); zzz.writeln();
    writeln();
    auto x = ulonger!2(0x4000_8000_3000_6000, 0xFFFF_FFFF_FFFF_FFFF);
    "%s + %s = %s".writefln(x, z, x + z);
    "%s * %s = %s".writefln(x, z, x * z);
    writeln();
    auto y = ulonger!2(0x0000_0000_0001_0001, 0x0000_0000_0000_0000);
    "%s * %s = ".writef(y, y);
    y = y * y; y.writeln();
    "%s * %s = ".writef(y, y);
    y = y * y; y.writeln();
    "%s * %s = ".writef(y, y);
    y = y * y; y.writeln();
}


/** fixed size unsigned integer

ulonger!i is the unsigned integer type with 1 << (i + 5) bit.
*/
struct ulonger(size_t n) if (1 < n)
{
    enum mbits = 32 << n;
    enum hbits = 16 << n;
    enum qbits = 8 << n;
    
    alias ulonger!n ul;
    static if (n == 2)
    {
        alias ulong ui;
        alias uint us;
    }
    else static if (n == 3)
    {
        alias ulonger!2 ui;
        alias ulong us;
    }
    else
    {
        alias ulonger!(n-1) ui;
        alias ulonger!(n-2) us;
    }

    private ui[2] w;
    this (ui[2]w)
    {
        this.w = w;
    }
    this (ui x, ui y)
    {
        this.w = [x, y];
    }
    this (ui x)
    {
        this.w[0] = x;
    }
    static if (n > 2) this (ulong x)
    {
        this.w[0] = ui(x);
    }
    ui[4] half()
    {
        ui[4] ret;
        foreach (i; 0..2)
        {
            static if (n > 2)
                foreach (j; 0..2)
                    ret[i << 1 | j] = ui(w[i].w[j]);
            else
            {
                ret[i << 1] = w[i] & 0xFFFF_FFFFUL;
                ret[i << 1 | 1] = w[i] >> 32;
            }
        }
        return ret;
    }
    CarryOverFlag carryover(ul other)
    {
        auto upper = w[1].carryover(other.w[1]);
        if (upper != CarryOverFlag.Full)
            return upper;
        return w[0].carryover(other.w[0]);
    }
    ul opUnary(string op)() if (op == "++")
    {
        ++w[0];
        return this;
    }
    ul opBinary(string op)(size_t amount)
    {
        if (mbits <= amount)
        {
            return ul(0);
        }
        if (hbits <= amount)
        {
            static if (op == "<<")
            {
                static if (n == 2)
                    return ul(0, w[0] << (amount - hbits));
                else
                    return ul(ui(0), w[0] << (amount - hbits));
            }
            static if (op == ">>")
                return ul(w[1] >> (amount - hbits));
        }
        if (amount == 0)
            return this;
        static if (op == "<<")
            return ul(w[0] << amount, w[1] << amount | w[0] >> (hbits - amount));
        static if (op == ">>")
            return ul(w[0] >> amount | w[1] << (hbits - amount), w[1] >> amount);
    }
    ul opBinary(string op)(ul other)
    {
        static if (op == "+")
        {
            ui[2] nw;
            nw[0] = w[0] + other.w[0];
            nw[1] = w[1] + other.w[1];
            if (w[0].carryover(other.w[0]) == CarryOverFlag.CarryOver)
                ++nw[1];
            return ul(nw);
        }
        static if (op == "-"){}
        static if (op == "*")
        {
            auto
                tw = this.half(),
                ow = other.half();
            ul ret;
            ret.w[0] += tw[0] * ow[0];
            foreach (i; 0..2)
            {
                ret = ret + (ul(tw[i] * ow[1-i]) << qbits);
            }
            foreach (i; 0..3)
            {
                ret.w[1] += tw[i] * ow[2-i];
            }
            foreach (i; 0..4)
            {
                ret.w[1] += (tw[i] * ow[3-i]) << qbits;
            }
            return ret;
        }
        static if (op == "/"){}
        static if (op == "%"){}
        static if (op == "|")
            return ulonger([content[0]|other.content[0], content[1]|other.content[1]]);
        static if (op == "&")
            return ulonger([content[0]&other.content[0], content[1]&other.content[1]]);
        static if (op == "^")
            return ulonger([content[0]^other.content[0], content[1]^other.content[1]]);
    }
}

enum CarryOverFlag { No, Full, CarryOver }
import std.traits : isUnsigned;
CarryOverFlag carryover(T)(T self, T other) if (isUnsigned!T)
{
    bool full = true;
    auto and = self & other;
    auto nor = ~(self | other);
    foreach_reverse (i; 0..(T.sizeof << 3))
    {
        if (and >> i & 1)
        {
            return CarryOverFlag.CarryOver;
        }
        if (nor >> i & 1)
            return CarryOverFlag.No;
    }
    return CarryOverFlag.Full;
}

unittest
{
    ulong
        full = 0xFFFF_FFFF_FFFF_FFFF,
        lower = 0x4000_0000_0000_0000,
        upper = 0x8000_0000_0000_0000,
        zero = 0x0000_0000_0000_0000,
        odd = 0xaaaa_aaaa_aaaa_aaaa,
        even = 0x5555_5555_5555_5555;
    assert (full.carryover(zero) == CarryOverFlag.Full);
    assert (full.carryover(lower) == CarryOverFlag.CarryOver);
    assert (full.carryover(upper) == CarryOverFlag.CarryOver);
    assert (lower.carryover(zero) == CarryOverFlag.No);
    assert (upper.carryover(zero) == CarryOverFlag.No);
    assert (lower.carryover(upper) == CarryOverFlag.No);
    assert (odd.carryover(even) == CarryOverFlag.Full);
    assert (odd.carryover(upper) == CarryOverFlag.CarryOver);
    assert (even.carryover(even) == CarryOverFlag.No);
    "unittest passed: carryover!ulong".writeln();
}

unittest
{
    uint
        full = 0xFFFF_FFFF,
        lower = 0x4000_0000,
        upper = 0x8000_0000,
        zero = 0x0000_0000,
        odd = 0xaaaa_aaaa,
        even = 0x5555_5555;
    assert (full.carryover(zero) == CarryOverFlag.Full);
    assert (full.carryover(lower) == CarryOverFlag.CarryOver);
    assert (full.carryover(upper) == CarryOverFlag.CarryOver);
    assert (lower.carryover(zero) == CarryOverFlag.No);
    assert (upper.carryover(zero) == CarryOverFlag.No);
    assert (lower.carryover(upper) == CarryOverFlag.No);
    assert (odd.carryover(even) == CarryOverFlag.Full);
    assert (odd.carryover(upper) == CarryOverFlag.CarryOver);
    assert (even.carryover(even) == CarryOverFlag.No);
    "unittest passed: carryover!uint".writeln();
}

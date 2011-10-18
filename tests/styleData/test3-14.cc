// -*- LSST-C++ -*-
// 3-14   7   Object name should not appear in a method name.
class Foo {
public:
    int const x = 1.0;
    float getX() { return x; } // ok
    float getFooX() { return x; } // fail
}


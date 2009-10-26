// -*- LSST-C++ -*-
// 5-27   5    One-argument constructors must be declared explicit.
class Foo {
public:
    Foo(int const a) : _a(a) {}           // fail
    explicit Foo(int const a) : _a(a) {}  // ok
};

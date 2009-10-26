// -*- LSST-C++ -*-
// 5-29  6     Destructors should be virtual
class Foo {
public:
    explicit Foo(int const a) : _a(a) {}
    ~Foo() {
        del _a;
    }
private:
    int _a;
};


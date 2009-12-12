// -*- LSST-C++ -*-
// 5-29  19     Destructors should be virtual

// should pass ... not a base class
class Foo {
public:
    explicit Foo(int const a) : _a(a) {}
    ~Foo() {
        del _a;
    }
private:
    int _a;
};

// should fail ... non-virtual destructor in a base class
class BooBase {
public:
    explicit BooBase(int const b) : _b(b) {}
    ~Boo() {
        del _b;
    }
private:
    int _b;
};

// should pass ... virtual destructor in a base class.
class HooBase {
public:
    explicit HooBase(int const c) : _c(c) {}
    virtual ~Hoo() {
        del _c;
    }
private:
    int _c;
};

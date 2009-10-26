// -*- LSST-C++ -*-
// 3-10 8  Private variables must be prefixed with leading underscore.
class Foo {
public:
    int const x = 1.0;
private:
    int _x = 1.0; // ok
    float q = 2.0; // fail
}

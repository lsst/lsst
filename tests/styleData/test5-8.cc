// -*- LSST-C++ -*-
// 5-8   7,8     Public variables must const or static.
template<typename MyType>
class Foo {                                     
public:
    explicit Foo(int const a) : _a(a) {}
    float x = 0.0;      // fail
    float q(0.0);       // fail
    float dog(int i, int j) {
        float x = 1.0;
        double y = 2.0;
        return x*y;
    }
    float const y = 1.0;
    static float r(1.0);
};


// -*- LSST-C++ -*-
// 4-5   22     Inline functions prohibited except for get/set.
template<typename MyType> 
class Foo {                                     
public:
    typedef float MyFloat;
    explicit Foo(int const a) : _a(a) {}
    float const z = 0.0;
    float static r = 0.0;
    int getA() { return _a; }
private:

    int _a;

    int _getValue() {                           
        return _a;
    }
    inline float _getA() {      // ok
        return _a;
    }

    inline float _getStuff() {   // fail
        float _b = _a*_a;
        float _c = b*b;
        return _c;
    }
};


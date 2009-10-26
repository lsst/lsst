// -*- LSST-C++ -*-
// 5-2 13,21      Class declaration order public/protected/private: ('public' repeated)
class Foo : public Bar {
public:
    typedef float MyFloat;
    explicit Foo(int const a) : _a(a) {}
    int const okVar = 5;
    int const okDecl = 4;

protected:
    double x;

public:
    float const q = 1.0;
    
private:

    int _a, _b;
    int getB() { return _b; }
    
};


// -*- LSST-C++ -*-
// 6-5    8    class/public/protected/private should be left justified.
template<typename MyType>
class Foo {                                     
public:
    explicit Foo(int const a) : _a(a) {}
    int getA() { return _a; }
    protected:   // fail
    int c;
    
private:
    int _a;
};

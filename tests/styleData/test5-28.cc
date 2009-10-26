// -*- LSST-C++ -*-
// 5-28   7,16    Do not throw exceptions in a destructor.
class Foo {
public:
    explicit Foo(int const a) : _a(a) {}
    virtual ~Foo() {
        throw "foo foo";
    }
};

Foo::~Foo() {

    for (int i = 0; i < 10; ++i) {
        printf("%d\n", i);
    }
    throw "foo foo";
}

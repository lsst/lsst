// -*- LSST-C++ -*-
// 5-24  6     Pass non-primitives as 'const &'.
template<MyType>
MyType okFunc(MyType const &a); // ok

float badArgs(float a, MyType foo) { // fail
    return a*foo;
}

// call a function!
x = myFunction(foo, bar);  // ok

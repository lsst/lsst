// -*- LSST-C++ -*-
// 3-7  8   Templates start upper case, 1 letter ok
template<MyType>          // ok
float Foo (MyType mt) {
    return mt;
}

template<myType>          // fail
float Foo (myType mt) {
    return mt;
}

template<T>                // ok
float Foo (T mt) {
    return mt;
}
